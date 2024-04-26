// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BionicStructs {
    /// @dev Details about each user in a pool
    struct UserInfo {
        uint256 amount; // How many tokens are staked in a pool
        // uint256 pledgeFundingAmount; // Based on staked tokens, the funding that has come from the user (or not if they choose to pull out)
        // uint256 rewardDebtRewards; // Reward debt. See explanation below.
        // uint256 tokenAllocDebt;
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
        uint256 pledgingStartTime; // Pledging will be permitted since this date
        uint256 pledgingEndTime; // Before this Time pledge is permitted
        uint256 tokenAllocationPerMonth; // the amount of token will be released to lottery winners per month
        uint256 tokenAllocationMonthCount; // number of months tokens will be allocated
        uint256 targetRaise; // Amount that the project wishes to raise
        uint32 winnersCount;
        bool useRaffle; // New field to indicate whether the pool uses a raffle or not
        PledgeTier[] pledgeTiers; // Information about each tier
    }

    // Add new struct for TierInfo
    struct PledgeTier {
        uint256 tierId;
        uint256 minimumPledge; // Minimum pledge amount for this tier
        uint256 maximumPledge; // Maximum pledge amount for this tier
    }
}
