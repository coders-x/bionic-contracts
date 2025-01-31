// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {SafeERC20, IERC20, Address} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import  "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

error TransferFailed();
error NeedsMoreThanZero();
error InsufficientBalance();
error VestingPeriodNotMet();
error Unauthorized();
error PoolDoesNotExist();
error InsufficientRewardTokens();

contract MultiPoolStaking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct StakingPool {
        IERC20 stakingToken;
        IERC20 rewardsToken;
        uint256 rewardRate; // Reward per second
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 totalSupply;
        uint256 vestingPeriod;
        bool isActive;
        mapping(address => uint256) balances;
        mapping(address => uint256) rewards;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) lastClaimedTime;
    }

    uint256 public poolCount;
    mapping(uint256 => StakingPool) public stakingPools; // poolId -> StakingPool

    event PoolCreated(uint256 indexed poolId, address stakingToken, address rewardsToken, uint256 rewardRate, uint256 vestingPeriod);
    event Staked(uint256 indexed poolId, address indexed user, uint256 amount);
    event Withdrawn(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardsClaimed(uint256 indexed poolId, address indexed user, uint256 amount);
    event Compounded(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 indexed poolId, uint256 newRate);
    event VestingPeriodUpdated(uint256 indexed poolId, uint256 newVestingPeriod);
    event PoolDeactivated(uint256 indexed poolId);
    event RewardsFunded(uint256 indexed poolId, uint256 amount);
    event EmergencyWithdrawn(uint256 indexed poolId, address indexed user, uint256 amount);

    constructor() {}

    /**
     * @dev Creates a new staking pool.
     * @param _stakingToken Address of the staking token.
     * @param _rewardsToken Address of the rewards token.
     * @param _rewardRate Reward rate per second.
     * @param _vestingPeriod Time in seconds before rewards can be withdrawn.
     */
    function createPool(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardRate,
        uint256 _vestingPeriod
    ) external onlyOwner {
        uint256 poolId = poolCount++;
        StakingPool storage pool = stakingPools[poolId];

        pool.stakingToken = IERC20(_stakingToken);
        pool.rewardsToken = IERC20(_rewardsToken);
        pool.rewardRate = _rewardRate;
        pool.vestingPeriod = _vestingPeriod;
        pool.lastUpdateTime = block.timestamp;
        pool.isActive = true;

        emit PoolCreated(poolId, _stakingToken, _rewardsToken, _rewardRate, _vestingPeriod);
    }

    /**
     * @dev Funds the contract with reward tokens for a specific pool.
     * @param poolId ID of the pool.
     * @param amount Amount of reward tokens to fund.
     */
    function fundRewards(uint256 poolId, uint256 amount) external onlyOwner poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        pool.rewardsToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardsFunded(poolId, amount);
    }

    /**
     * @dev Deactivates a staking pool.
     * @param poolId ID of the pool.
     */
    function deactivatePool(uint256 poolId) external onlyOwner poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        pool.isActive = false;
        emit PoolDeactivated(poolId);
    }

    /**
     * @dev Calculates the latest reward per token for a given pool.
     */
    function rewardPerToken(uint256 poolId) public view poolExists(poolId) returns (uint256) {
        StakingPool storage pool = stakingPools[poolId];
        if (pool.totalSupply == 0) {
            return pool.rewardPerTokenStored;
        }
        return pool.rewardPerTokenStored + ((block.timestamp - pool.lastUpdateTime) * pool.rewardRate * 1e18) / pool.totalSupply;
    }

    /**
     * @dev Calculates the earned rewards of a user in a given pool.
     */
    function earned(uint256 poolId, address account) public view poolExists(poolId) returns (uint256) {
        StakingPool storage pool = stakingPools[poolId];
        return ((pool.balances[account] * (rewardPerToken(poolId) - pool.userRewardPerTokenPaid[account])) / 1e18) + pool.rewards[account];
    }

    /**
     * @dev Allows a user to stake tokens in a specific pool.
     */
    function stake(uint256 poolId, uint256 amount) external nonReentrant updateReward(poolId, msg.sender) moreThanZero(amount) poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        if (!pool.isActive) revert PoolDoesNotExist();

        if (pool.lastClaimedTime[msg.sender] == 0) {
            pool.lastClaimedTime[msg.sender] = block.timestamp;
        }

        pool.balances[msg.sender] += amount;
        pool.totalSupply += amount;

        emit Staked(poolId, msg.sender, amount);
        pool.stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Allows a user to withdraw staked tokens from a specific pool.
     */
    function withdraw(uint256 poolId, uint256 amount) external nonReentrant updateReward(poolId, msg.sender) poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        if (amount > pool.balances[msg.sender]) {
            revert InsufficientBalance();
        }

        pool.balances[msg.sender] -= amount;
        pool.totalSupply -= amount;

        emit Withdrawn(poolId, msg.sender, amount);
        pool.stakingToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Allows a user to claim their rewards after the vesting period.
     */
    function claimReward(uint256 poolId) external nonReentrant updateReward(poolId, msg.sender) poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        if (block.timestamp < pool.lastClaimedTime[msg.sender] + pool.vestingPeriod) {
            revert VestingPeriodNotMet();
        }

        uint256 reward = pool.rewards[msg.sender];
        if (reward == 0) return;

        if (pool.rewardsToken.balanceOf(address(this)) < reward) {
            revert InsufficientRewardTokens();
        }

        pool.rewards[msg.sender] = 0;
        pool.lastClaimedTime[msg.sender] = block.timestamp;

        emit RewardsClaimed(poolId, msg.sender, reward);
        pool.rewardsToken.safeTransfer(msg.sender, reward);
    }

    /**
     * @dev Allows a user to compound their rewards by staking them back into the pool.
     */
    function compoundReward(uint256 poolId) external nonReentrant updateReward(poolId, msg.sender) poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        uint256 reward = pool.rewards[msg.sender];
        if (reward == 0) return;

        pool.rewards[msg.sender] = 0;
        pool.balances[msg.sender] += reward;
        pool.totalSupply += reward;

        emit Compounded(poolId, msg.sender, reward);
    }

    /**
     * @dev Allows a user to withdraw their staked tokens in an emergency without claiming rewards.
     */
    function emergencyWithdraw(uint256 poolId) external nonReentrant poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        uint256 amount = pool.balances[msg.sender];
        if (amount == 0) revert InsufficientBalance();

        pool.balances[msg.sender] = 0;
        pool.totalSupply -= amount;

        emit EmergencyWithdrawn(poolId, msg.sender, amount);
        pool.stakingToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Updates the reward rate for a given pool (Governance feature).
     * Only callable by the contract owner.
     */
    function updateRewardRate(uint256 poolId, uint256 newRate) external onlyOwner poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        pool.rewardRate = newRate;
        emit RewardRateUpdated(poolId, newRate);
    }

    /**
     * @dev Updates the vesting period for a given pool (Governance feature).
     * Only callable by the contract owner.
     */
    function updateVestingPeriod(uint256 poolId, uint256 newVestingPeriod) external onlyOwner poolExists(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        pool.vestingPeriod = newVestingPeriod;
        emit VestingPeriodUpdated(poolId, newVestingPeriod);
    }

    /**
     * @dev Returns user information for a specific pool.
     */
    function getUserInfo(uint256 poolId, address user) external view poolExists(poolId) returns (uint256 stakedBalance, uint256 earnedRewards) {
        StakingPool storage pool = stakingPools[poolId];
        stakedBalance = pool.balances[user];
        earnedRewards = earned(poolId, user);
    }

    // Modifiers
    modifier updateReward(uint256 poolId, address account) {
        StakingPool storage pool = stakingPools[poolId];
        pool.rewardPerTokenStored = rewardPerToken(poolId);
        pool.lastUpdateTime = block.timestamp;

        pool.rewards[account] = earned(poolId, account);
        pool.userRewardPerTokenPaid[account] = pool.rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }

    modifier poolExists(uint256 poolId) {
        if (poolId >= poolCount || !stakingPools[poolId].isActive) {
            revert PoolDoesNotExist();
        }
        _;
    }
}