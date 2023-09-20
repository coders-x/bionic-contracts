// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Raffle} from "./Raffle.sol";

error Claim__InvalidProject(); //"Project token not registered. Contact admin to add project tokens"
error Claim__ClaimingIsNotAllowedYet(uint startAfter); //"Not in the time window for claiming rewards"
error Claim__NothingToClaim();
error Claim__NotEligible(); //"User is not assigned claims for this project."
error Claim__NotEnoughTokenLeft(uint pid, address token); //"Not enough tokens available for claiming. Please try Again"

contract ClaimFunding is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    struct UserClaim {
        uint256 lastClaim; // Month when the user last claimed tokens
        uint256 totalTokensClaimed; // Total tokens claimed by the user
    }

    struct ProjectToken {
        IERC20 token; // The token that users can claim
        uint256 monthlyAmount; // Amount of tokens users can claim per month
        uint256 startMonth; // firstMonth token is claimable
        uint256 endMonth; // number of months allocation will go on
    }

    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MONTH_IN_SECONDS = 30 days; // Approx 1 month (assuming 15 seconds per block)

    // User's claim history for each project token useraddress => pid => UserClaim
    mapping(address => mapping(uint256 => UserClaim)) public s_userClaims; //solhint-disable-line var-name-mixedcase
    // pid to Project Reward pool
    mapping(uint256 => ProjectToken) public s_projectTokens; //solhint-disable-line var-name-mixedcase
    //User's Active Projects
    mapping(address => EnumerableSet.UintSet) internal s_userProjects; // solhint-disable-line var-name-mixedcase

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    event ProjectAdded(
        uint256 indexed pid,
        IERC20 indexed token,
        uint256 monthlyAmount,
        uint256 startMonth,
        uint256 endMonth
    );
    event TokensClaimed(
        address indexed user,
        uint256 indexed pid,
        uint256 month,
        uint256 amount
    );

    /*///////////////////////////////////////////////////////////////
                            Constructors
    //////////////////////////////////////////////////////////////*/
    constructor() {}

    /*///////////////////////////////////////////////////////////////
                        Public/External Functions
    //////////////////////////////////////////////////////////////*/
    // Owner can register a new project token with claim parameters
    function registerProjectToken(
        uint256 pid,
        address projectTokenAddress,
        uint256 claimAmount,
        uint256 startMonth,
        uint256 totalMonths
    ) external onlyOwner {
        s_projectTokens[pid] = ProjectToken(
            IERC20(projectTokenAddress),
            claimAmount,
            startMonth,
            startMonth.add(totalMonths.mul(MONTH_IN_SECONDS))
        );
        emit ProjectAdded(
            pid,
            IERC20(projectTokenAddress),
            claimAmount,
            startMonth,
            totalMonths
        );
    }

    // Owner can add winning investors
    function addWinningInvestors(uint256 pid) external {
        address[] memory investors = Raffle(owner()).getRaffleWinners(pid);
        if (investors.length == 0) {
            revert Claim__InvalidProject();
        }
        for (uint i = 0; i < investors.length; i++) {
            s_userProjects[investors[i]].add(pid);
            s_userClaims[investors[i]][pid] = UserClaim(block.timestamp, 0); // solhint-disable-line not-rely-on-time
        }
    }

    // Users can claim tokens for the current month for a specific project token
    function claimTokens(uint256 pid) external {
        _claim(pid);
    }

    // Users can claim tokens for all projects they are signed up for
    function batchClaim() external {
        // Loop through all projects the user is signed up for and calculate claimable tokens
        for (uint256 i = 0; i < s_userProjects[_msgSender()].length(); i++) {
            //todo find a way to not fail
            _claim(s_userProjects[_msgSender()].at(i));
        }
    }

    /// @notice Get the amount of token you can claim before sending claim request.
    /// @dev it's replica of checks on claimToken but just to let users know how much they owe
    /// @param pid pool Id you are trying to claim from
    /// @return amount to token you will be claiming when calling "claimToken"
    function claimableAmount(
        uint256 pid,
        address user
    ) external view returns (uint256 amount) {
        ProjectToken memory project = s_projectTokens[pid];
        if (address(project.token) == address(0)) {
            revert Claim__InvalidProject();
        }
        UserClaim storage userClaim = s_userClaims[user][pid];
        if (
            userClaim.lastClaim == 0 || userClaim.lastClaim >= project.endMonth
        ) {
            revert Claim__NotEligible();
        }
        if (project.startMonth > block.timestamp) {
            // solhint-disable-line not-rely-on-time
            revert Claim__ClaimingIsNotAllowedYet(project.startMonth);
        }

        // Calculate the amount to claim for the current month
        uint256 claimableMonthCount = getClaimableMonthsCount(
            userClaim.lastClaim,
            project.endMonth
        );
        if (claimableMonthCount == 0) {
            revert Claim__NothingToClaim();
        }
        amount = project.monthlyAmount.mul(claimableMonthCount);
        // Ensure we have enough tokens available for claiming
        if (project.token.balanceOf(address(this)) < amount) {
            revert Claim__NotEnoughTokenLeft(pid, address(project.token));
        }
        return amount;
    }

    /*///////////////////////////////////////////////////////////////
                        Private/Internal Functions
    //////////////////////////////////////////////////////////////*/
    function getClaimableMonthsCount(
        uint256 lastClaimedMonth,
        uint256 endMonth
    ) internal view returns (uint256) {
        if (endMonth > block.timestamp) {
            // solhint-disable-line not-rely-on-time
            return (
                (block.timestamp.sub(lastClaimedMonth)).div(MONTH_IN_SECONDS)
            ); // solhint-disable-line not-rely-on-time
        } else {
            return ((endMonth.sub(lastClaimedMonth)).div(MONTH_IN_SECONDS)); // solhint-disable-line not-rely-on-time
        }
    }

    /// @dev will claim the tokens user owed.
    /// @param pid poolId to claim tokens for.
    function _claim(uint256 pid) internal {
        ProjectToken memory project = s_projectTokens[pid];
        if (address(project.token) == address(0)) {
            revert Claim__InvalidProject();
        }
        UserClaim storage userClaim = s_userClaims[_msgSender()][pid];
        if (
            userClaim.lastClaim == 0 || userClaim.lastClaim >= project.endMonth
        ) {
            s_userProjects[_msgSender()].remove(pid);
            revert Claim__NotEligible();
        }
        if (project.startMonth > block.timestamp) {
            // solhint-disable-line not-rely-on-time
            revert Claim__ClaimingIsNotAllowedYet(project.startMonth);
        }

        // Calculate the amount to claim for the current month
        uint256 claimableMonthCount = getClaimableMonthsCount(
            userClaim.lastClaim,
            project.endMonth
        );
        if (claimableMonthCount == 0) {
            revert Claim__NothingToClaim();
        }
        uint256 tokensToClaim = project.monthlyAmount.mul(claimableMonthCount);
        // Ensure we have enough tokens available for claiming
        if (project.token.balanceOf(address(this)) < tokensToClaim) {
            revert Claim__NotEnoughTokenLeft(pid, address(project.token));
        }

        // Update user's claim data
        userClaim.lastClaim = userClaim.lastClaim.add(
            MONTH_IN_SECONDS.mul(claimableMonthCount)
        );
        userClaim.totalTokensClaimed = userClaim.totalTokensClaimed.add(
            tokensToClaim
        );

        // Transfer tokens to the user
        project.token.transfer(_msgSender(), tokensToClaim);

        emit TokensClaimed(
            _msgSender(),
            pid,
            claimableMonthCount,
            tokensToClaim
        );
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    modifier exsitingProject(uint256 pid) {
        if (address(s_projectTokens[pid].token) == address(0)) {
            revert Claim__InvalidProject();
        }
        _;
    }
    modifier projectDoesNotExists(uint256 pid) {
        if (address(s_projectTokens[pid].token) == address(0)) {
            revert Claim__InvalidProject();
        }
        _;
    }
}
