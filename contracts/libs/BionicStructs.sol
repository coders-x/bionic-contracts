// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library BionicStructs {
    /// @dev Details about each user in a pool
    struct UserInfo {
        uint256 amount; // How many tokens are staked in a pool
        uint256 pledgeFundingAmount; // Based on staked tokens, the funding that has come from the user (or not if they choose to pull out)
        uint256 rewardDebtRewards; // Reward debt. See explanation below.
        uint256 tokenAllocDebt;
        //
        // We do some fancy math here. Basically, once vesting has started in a pool (if they have deposited), the amount of reward tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebtRewards
        //
        // The amount can never change once the staking period has ended
    }

    /// @dev Info of each pool.
    struct PoolInfo {
        IERC20 rewardToken; // Address of the reward token contract.
        uint256 pledgingStartTime; // Pledging will be permitted since this date
        uint256 pledgingEndTime; // Before this Time pledge is permitted
        uint256 maxPledgingAmountPerUser; // Max. amount of tokens that can be staked per account/user
        uint256 tokenAllocationPerBlock; // the amount of token will be released to lottary winners per month
        uint256 tokenAllocationStartTime; // when users can start claiming their first reward
        uint256 tokenAllocationPerShare; // amount of token will be allocated per investers share(usdt) per month.
        uint256 targetRaise; // Amount that the project wishes to raise
        uint32 winnersCount;
    }

    /// @dev Info of each TierInPool.
    struct Tier {
        uint32 count;
        address[] members;
    }

    // Iterable mapping from address to uint;
    struct Map {
        bool isTrue;
        address[] keys;
        mapping(address => UserInfo) values;
        mapping(address => uint) indexOf;
        mapping(address => bool) inserted;
    }
}
