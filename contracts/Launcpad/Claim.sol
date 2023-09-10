// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";



error ErrInvalidProject();  //"Project token not registered. Contact admin to add project tokens"
error ErrClaimingIsNotAllowedYet(uint startAfter); //"Not in the time window for claiming rewards"
error ErrNothingToClaim();
error ErrNotEligible(); //"User is not assigned claims for this project."
error ErrNotEnoughTokenLeft(address token); //"Not enough tokens available for claiming. Please try Again"

contract ClaimFunding is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant MONTH_IN_SECONDS = 2629746; // Approx 1 month (assuming 15 seconds per block)

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

    // User's claim history for each project token useraddress => tokenAddress => UserClaim
    mapping(address => mapping(address => UserClaim)) public s_userClaims; //solhint-disable-line var-name-mixedcase
    // Add more project tokens here
    mapping(address => ProjectToken) public s_projectTokens; //solhint-disable-line var-name-mixedcase
    //User's Active Projects 
    mapping(address=>EnumerableSet.AddressSet)s_userProjects;


    event ProjectAdded(IERC20 token, uint256 monthlyAmount, uint256 startMonth, uint256 endMonth);
    event TokensClaimed(address indexed user, address indexed projectToken, uint256 month, uint256 amount);

    modifier projectExists(address projectToken) {
        if (s_projectTokens[projectToken].monthlyAmount == 0) {
            revert ErrInvalidProject();
        }
        _;
    }

    constructor() {}

    // Owner can register a new project token with claim parameters
    function registerProjectToken(
        address projectTokenAddress,
        uint256 claimAmount,
        uint256 startMonth,
        uint256 totalMonths
    ) external onlyOwner {
        s_projectTokens[projectTokenAddress] = ProjectToken(IERC20(projectTokenAddress), claimAmount, startMonth, startMonth.add(totalMonths.mul(MONTH_IN_SECONDS)));
        emit ProjectAdded(IERC20(projectTokenAddress), claimAmount, startMonth, totalMonths);
    }

    // Owner can add winning investors
    function addWinningInvestors(address projectToken, address[] calldata investors) external onlyOwner {
        for (uint i = 0; i < investors.length; i++) {
            s_userProjects[investors[i]].add(projectToken);
            s_userClaims[investors[i]][projectToken] = UserClaim(block.timestamp, 0); // solhint-disable-line not-rely-on-time
        }
    }

    // Users can claim tokens for the current month for a specific project token
    function claimTokens(address projectToken) external{
       _claim(projectToken);
    }


    // Users can claim tokens for all projects they are signed up for
    function batchClaim() external {
        // Loop through all projects the user is signed up for and calculate claimable tokens
        for (uint256 i = 0; i < s_userProjects[_msgSender()].length(); i++) {
            //todo find a way to not fail
            _claim(s_userProjects[_msgSender()].at(i));
        }
    }

    function getClaimableMonthsCount(uint256 lastClaimedMonth, uint256 endMonth) public view returns (uint256) {
        if (endMonth > block.timestamp) {
            return ((block.timestamp.sub(lastClaimedMonth)).div(MONTH_IN_SECONDS)); // solhint-disable-line not-rely-on-time
        } else {
            return ((endMonth.sub(lastClaimedMonth)).div(MONTH_IN_SECONDS)); // solhint-disable-line not-rely-on-time
        }
    }

    /// @dev will claim the tokens user owed.
    /// @param projectToken address for the projects token contract
    function _claim(address projectToken) internal projectExists(projectToken) {
        UserClaim storage userClaim = s_userClaims[_msgSender()][projectToken];
        ProjectToken memory project = s_projectTokens[projectToken];
        if (userClaim.lastClaim == 0 || userClaim.lastClaim >= project.endMonth) {
            s_userProjects[_msgSender()].remove(projectToken);
            revert ErrNotEligible();
        }
        if (project.startMonth > block.timestamp) {
            revert ErrClaimingIsNotAllowedYet(project.startMonth);
        }

        // Calculate the amount to claim for the current month
        uint256 claimableMonthCount = getClaimableMonthsCount(userClaim.lastClaim, project.endMonth);
        if (claimableMonthCount == 0) {
            revert ErrNothingToClaim();
        }
        uint256 tokensToClaim = project.monthlyAmount.mul(claimableMonthCount);
        // Ensure we have enough tokens available for claiming
        if (project.token.balanceOf(address(this)) < tokensToClaim) {
            revert ErrNotEnoughTokenLeft(projectToken);
        }

        // Update user's claim data
        userClaim.lastClaim = userClaim.lastClaim.add(MONTH_IN_SECONDS.mul(claimableMonthCount));
        userClaim.totalTokensClaimed = userClaim.totalTokensClaimed.add(tokensToClaim);


        // Transfer tokens to the user
        project.token.transfer(_msgSender(), tokensToClaim);

        emit TokensClaimed(_msgSender(), projectToken, claimableMonthCount, tokensToClaim);
    }
}
