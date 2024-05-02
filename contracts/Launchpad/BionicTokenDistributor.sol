// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// import "forge-std/console.sol";
// import "hardhat/console.sol";

error Distributor__InvalidProject(); //"Project token not registered. Contact admin to add project tokens"
error Distributor__ClaimingIsNotAllowedYet(uint256 startAfter); //"Not in the time window for claiming rewards"
error Distributor__NothingToClaim();
error Distributor__Done(); // all claims have been made
error Distributor__NotEligible(); //"User is not assigned claims for this project."
error Distributor__NotEnoughTokenLeft(uint256 pid, address token); //"Not enough tokens available for claiming. Please try Again"

contract BionicTokenDistributor is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }
    // struct UserClaim {
    //     uint256 lastClaim; // Month when the user last claimed tokens
    //     uint256 totalTokensClaimed; // Total tokens claimed by the user
    // }

    struct ProjectToken {
        IERC20 token; // The token that users can claim
        uint256 monthQuota; // Amount of tokens users can claim per month per share
        uint256 startAt; // time stamp of starting Token distribution
        uint64 totalCycles; // number of months allocation will go on
        bytes32 merkleRoot; //use openzappline merkle tree to verify claims
        bool isActive; //the claim is active or not
    }

    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    uint256 public constant CYCLE_IN_SECONDS = 30 days; // Approx 1 month (assuming 15 seconds per block)

    // User's claim history for each project token useraddress => pid => DistributionHeight
    // by DistributionHeight we mean the time when user claimed tokens last time(numbers of cycles of claimed tokens)
    mapping(address => mapping(uint256 => uint256)) public s_userClaims; //solhint-disable-line var-name-mixedcase
    // pid to Project Reward pool
    mapping(uint256 => ProjectToken) public s_projectTokens; //solhint-disable-line var-name-mixedcase
    //User's Active Projects
    // mapping(address => EnumerableSet.UintSet) internal s_userProjects; // solhint-disable-line var-name-mixedcase

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    // This event is triggered whenever New Project has been added to distribute.
    event ProjectAdded(
        uint256 indexed pid,
        IERC20 indexed token,
        uint256 monthQuota,
        uint256 startAt,
        uint64 totalCycles,
        bytes32 merkleRoot
    );
    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(
        uint256 indexed pid,
        address indexed user,
        uint256 month,
        uint256 amount
    );

    event DistrbutionStatusChanged(uint256 indexed pid, bool status);

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    modifier isValidProject(uint256 pid) {
        if (address(s_projectTokens[pid].token) == address(0)) {
            revert Distributor__InvalidProject();
        }
        if (!s_projectTokens[pid].isActive) {
            revert Distributor__InvalidProject();
        }
        _;
    }
    /*///////////////////////////////////////////////////////////////
                            Constructors
    //////////////////////////////////////////////////////////////*/
    // constructor() {}

    /*///////////////////////////////////////////////////////////////
                        Public/External Functions
    //////////////////////////////////////////////////////////////*/
    // Owner can register a new project token with claim parameters
    function registerProjectToken(
        uint256 pid,
        address projectTokenAddress,
        uint256 monthQuota,
        uint256 startAt,
        uint32 totalCycles,
        bytes32 merkleRoot
    ) external onlyOwner {
        if (address(projectTokenAddress) == address(0)) {
            //@audit-todo: check for IERC20
            revert Distributor__InvalidProject();
        }
        s_projectTokens[pid] = ProjectToken(
            IERC20(projectTokenAddress),
            monthQuota,
            startAt,
            totalCycles,
            merkleRoot,
            true
        );
        emit ProjectAdded(
            pid,
            IERC20(projectTokenAddress),
            monthQuota,
            startAt,
            totalCycles,
            merkleRoot
        );
    }
    function updateDistributionStatus(
        uint256 pid,
        bool status
    ) external onlyOwner {
        s_projectTokens[pid].isActive = status;
        emit DistrbutionStatusChanged(pid, status);
    }

    // Claim the given amount of pledge user made to the token to the given address. Reverts if the inputs are invalid.
    function claim(
        uint256 pid,
        address account,
        uint256 pledged,
        bytes32[] calldata merkleProof
    ) external nonReentrant isValidProject(pid) {
        if (
            !MerkleProof.verify(
                merkleProof,
                s_projectTokens[pid].merkleRoot,
                keccak256(
                    bytes.concat(keccak256(abi.encode(pid, account, pledged)))
                )
            )
        ) {
            revert Distributor__NotEligible();
        }
        if (s_projectTokens[pid].startAt > block.timestamp) {
            // solhint-disable-line not-rely-on-time
            revert Distributor__ClaimingIsNotAllowedYet(
                s_projectTokens[pid].startAt
            );
        }
        if (s_userClaims[account][pid] >= s_projectTokens[pid].totalCycles) {
            revert Distributor__Done();
        }
        (uint256 amount, uint256 cyclesClaimable) = calcClaimableAmount(
            pid,
            account,
            pledged
        );
        if (cyclesClaimable == 0 || amount == 0) {
            revert Distributor__NothingToClaim();
        }
        // Ensure we have enough tokens available for claiming
        if (s_projectTokens[pid].token.balanceOf(address(this)) < amount) {
            revert Distributor__NotEnoughTokenLeft(
                pid,
                address(s_projectTokens[pid].token)
            );
        }

        s_userClaims[account][pid] += cyclesClaimable;
        s_projectTokens[pid].token.safeTransfer(account, amount);
        emit Claimed(pid, account, cyclesClaimable, amount);
    }

    /// @notice Get the amount of token you can claim before sending claim request.
    /// @dev it's replica of checks on claimToken but just to let users know how much they owe
    /// @param pid pool Id you are trying to claim from
    /// @return amount to token you will be claiming when calling "claimToken"
    function calcClaimableAmount(
        uint256 pid,
        address account,
        uint256 pledged
    ) public view returns (uint256 amount, uint256 cyclesClaimable) {
        // Calculate the amount to claim for the current month
        cyclesClaimable = _getProjectClaimableCyclesCount(pid);
        cyclesClaimable = cyclesClaimable - s_userClaims[account][pid];
        // math to calculate tokens of user to be cliamed
        // monthCount*(projectMonthlyAllocation/totalInvestment)*userInvestment
        amount = s_projectTokens[pid]
            .monthQuota
            // .div(s_projectTokens[pid].totalRaised)
            .mul(pledged)
            .mul(cyclesClaimable);

        return (amount, cyclesClaimable);
    }

    /*///////////////////////////////////////////////////////////////
                        Private/Internal Functions
    //////////////////////////////////////////////////////////////*/
    function _getProjectClaimableCyclesCount(
        uint256 pid
    ) internal view returns (uint256) {
        if (block.timestamp < s_projectTokens[pid].startAt) {
            return 0;
        }
        uint256 claimableMonthCount = block
            .timestamp
            .sub(s_projectTokens[pid].startAt)
            .div(CYCLE_IN_SECONDS);
        if (claimableMonthCount > s_projectTokens[pid].totalCycles) {
            return s_projectTokens[pid].totalCycles;
        }
        return claimableMonthCount;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
