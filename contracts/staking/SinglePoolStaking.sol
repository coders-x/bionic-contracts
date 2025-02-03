// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Allows governance functionality

error TransferFailed();
error NeedsMoreThanZero();
error InsufficientBalance();
error VestingPeriodNotMet();
error Unauthorized();
error PoolDoesNotExist();

contract SinglePoolStaking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public stakingToken;
    IERC20 public rewardsToken;
    uint256 public rewardRate; // Reward per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;
    uint256 public vestingPeriod;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public lastClaimedTime;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event Compounded(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event VestingPeriodUpdated(uint256 newVestingPeriod);

    /**
     * @dev Constructor initializes staking and reward tokens.
     * @param _stakingToken Address of the staking token.
     * @param _rewardsToken Address of the rewards token.
     * @param _rewardRate Reward rate per second.
     * @param _vestingPeriod Vesting time in seconds before rewards can be withdrawn.
     */
    constructor(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardRate,
        uint256 _vestingPeriod
    ) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        rewardRate = _rewardRate;
        vestingPeriod = _vestingPeriod;
        lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Calculates the latest reward per token.
     * @return Updated reward per token.
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply;
    }

    /**
     * @dev Calculates the earned rewards of a user.
     * @param account The address of the user.
     * @return The amount of rewards earned.
     */
    function earned(address account) public view returns (uint256) {
        return ((balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    /**
     * @dev Allows a user to stake tokens.
     * @param amount The amount to stake.
     */
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) moreThanZero(amount) {
        balances[msg.sender] += amount;
        totalSupply += amount;
        emit Staked(msg.sender, amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Allows a user to withdraw staked tokens.
     * @param amount The amount to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount > balances[msg.sender]) {
            revert InsufficientBalance();
        }
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        emit Withdrawn(msg.sender, amount);
        stakingToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Allows a user to claim their rewards after the vesting period.
     */
    function claimReward() external nonReentrant updateReward(msg.sender) {
        if (block.timestamp < lastClaimedTime[msg.sender] + vestingPeriod) {
            revert VestingPeriodNotMet();
        }
        uint256 reward = rewards[msg.sender];
        if (reward == 0) return;
        rewards[msg.sender] = 0;
        lastClaimedTime[msg.sender] = block.timestamp;
        emit RewardsClaimed(msg.sender, reward);
        rewardsToken.safeTransfer(msg.sender, reward);
    }

    /**
     * @dev Allows a user to compound their rewards by staking them back into the pool.
     */
    function compoundReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) return;
        rewards[msg.sender] = 0;
        balances[msg.sender] += reward;
        totalSupply += reward;
        emit Compounded(msg.sender, reward);
    }

    /**
     * @dev Updates the reward rate (Governance feature).
     * Only callable by the contract owner.
     * @param newRate The new reward rate.
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    /**
     * @dev Updates the vesting period (Governance feature).
     * Only callable by the contract owner.
     * @param newVestingPeriod The new vesting period in seconds.
     */
    function updateVestingPeriod(uint256 newVestingPeriod) external onlyOwner {
        vestingPeriod = newVestingPeriod;
        emit VestingPeriodUpdated(newVestingPeriod);
    }

    // Modifiers
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }
}
