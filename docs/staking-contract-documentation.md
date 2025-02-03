# MultiPoolStaking Smart Contract Documentation

## Overview
The MultiPoolStaking contract is a flexible and secure staking system that enables multiple staking pools with different tokens and reward configurations. It implements features like staking, rewards distribution, vesting periods, and emergency withdrawals, all while maintaining security through reentrancy protection and access controls.

## Key Features
- Multiple staking pools support
- Configurable reward rates and vesting periods
- Compound rewards functionality
- Emergency withdrawal mechanism
- Governance controls for pool management
- Secure token transfers using OpenZeppelin's SafeERC20

## Contract Dependencies
- **@openzeppelin/contracts/token/ERC20/IERC20.sol**: Interface for ERC20 token interactions
- **@openzeppelin/contracts/security/ReentrancyGuard.sol**: Protection against reentrancy attacks
- **@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol**: Safe token transfer utilities
- **@openzeppelin/contracts/access/Ownable.sol**: Access control functionality

## Error Definitions
```solidity
error TransferFailed();           // Token transfer operation failed
error NeedsMoreThanZero();       // Amount must be greater than zero
error InsufficientBalance();      // User has insufficient balance
error VestingPeriodNotMet();     // Vesting period requirements not met
error Unauthorized();            // Caller lacks required permissions
error PoolDoesNotExist();        // Referenced pool is invalid or inactive
error InsufficientRewardTokens(); // Contract lacks sufficient rewards
```

## Data Structures

### StakingPool Struct
```solidity
struct StakingPool {
    IERC20 stakingToken;         // Token that users stake
    IERC20 rewardsToken;         // Token given as rewards
    uint256 rewardRate;          // Rewards per second
    uint256 lastUpdateTime;      // Last reward calculation timestamp
    uint256 rewardPerTokenStored;// Accumulated rewards per token
    uint256 totalSupply;         // Total staked tokens
    uint256 vestingPeriod;       // Required time before claiming rewards
    bool isActive;               // Pool activation status
    mapping(address => uint256) balances;  // User staked balances
    mapping(address => uint256) rewards;   // User earned rewards
    mapping(address => uint256) userRewardPerTokenPaid;  // User reward checkpoints
    mapping(address => uint256) lastClaimedTime;  // User's last reward claim
}
```

## Events
1. **PoolCreated**: Emitted when a new staking pool is created
2. **Staked**: Emitted when tokens are staked
3. **Withdrawn**: Emitted when staked tokens are withdrawn
4. **RewardsClaimed**: Emitted when rewards are claimed
5. **Compounded**: Emitted when rewards are compounded
6. **RewardRateUpdated**: Emitted when pool reward rate is modified
7. **VestingPeriodUpdated**: Emitted when vesting period is changed
8. **PoolDeactivated**: Emitted when a pool is deactivated
9. **RewardsFunded**: Emitted when rewards are added to a pool
10. **EmergencyWithdrawn**: Emitted during emergency withdrawals

## Core Functions

### Pool Management
1. **createPool**
   - Creates a new staking pool
   - Parameters: staking token, rewards token, reward rate, vesting period
   - Restricted to contract owner
   - Initializes pool parameters and sets active status

2. **fundRewards**
   - Adds reward tokens to a specific pool
   - Parameters: pool ID, amount
   - Restricted to contract owner
   - Transfers rewards from owner to contract

3. **deactivatePool**
   - Deactivates a staking pool
   - Parameter: pool ID
   - Restricted to contract owner
   - Prevents new stakes while allowing withdrawals

### User Operations
1. **stake**
   - Stakes tokens in a specified pool
   - Parameters: pool ID, amount
   - Validates pool status and amount
   - Updates rewards and transfers tokens

2. **withdraw**
   - Withdraws staked tokens
   - Parameters: pool ID, amount
   - Verifies balance and updates rewards
   - Returns staked tokens to user

3. **claimReward**
   - Claims accumulated rewards
   - Parameter: pool ID
   - Checks vesting period
   - Transfers reward tokens to user

4. **compoundReward**
   - Reinvests rewards as stake
   - Parameter: pool ID
   - Adds earned rewards to stake
   - Updates pool total supply

5. **emergencyWithdraw**
   - Emergency withdrawal of staked tokens
   - Parameter: pool ID
   - Bypasses reward calculations
   - Returns only staked tokens

### Governance Functions
1. **updateRewardRate**
   - Modifies pool reward rate
   - Parameters: pool ID, new rate
   - Restricted to owner
   - Updates rewards distribution

2. **updateVestingPeriod**
   - Changes pool vesting period
   - Parameters: pool ID, new period
   - Restricted to owner
   - Affects future reward claims

### View Functions
1. **rewardPerToken**
   - Calculates current reward per staked token
   - Parameter: pool ID
   - Considers time elapsed and total supply

2. **earned**
   - Calculates user's earned rewards
   - Parameters: pool ID, user address
   - Based on stake amount and reward rate

3. **getUserInfo**
   - Retrieves user's staking information
   - Parameters: pool ID, user address
   - Returns stake balance and earned rewards

## Security Features
1. **ReentrancyGuard**: Prevents reentrant calls in critical functions
2. **Ownable**: Restricts administrative functions to contract owner
3. **SafeERC20**: Ensures safe token transfers
4. **Pool Validation**: Checks pool existence and status
5. **Balance Verification**: Validates user balances before operations
6. **Amount Validation**: Ensures non-zero amounts for operations

## Modifiers
1. **updateReward**
   - Updates reward calculations before operations
   - Parameters: pool ID, user address
   - Updates stored values and user rewards

2. **moreThanZero**
   - Validates amount is greater than zero
   - Parameter: amount
   - Prevents zero-value operations

3. **poolExists**
   - Validates pool existence and status
   - Parameter: pool ID
   - Checks pool count and active status

## Usage Considerations
1. Pool creation requires careful parameter selection
2. Reward rates should align with token decimals
3. Vesting periods affect user reward claiming
4. Emergency withdrawal forfeits pending rewards
5. Pool deactivation prevents new stakes
