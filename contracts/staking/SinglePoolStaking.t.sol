// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./SinglePoolStaking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
/*
    Mock Tokens:
        The MockERC20 contract is used to simulate staking and reward tokens.

    Setup:
        The setUp function deploys the staking contract and mocks tokens for testing.

    Test Cases:
        Staking: Tests the stake function and verifies balances.
        Withdrawing: Tests the withdraw function and ensures correct token transfers.
        Claiming Rewards: Tests the claimReward function after the vesting period.
        Compounding Rewards: Tests the compoundReward function to ensure rewards are staked back.
        Governance Features: Tests updating the reward rate and vesting period.
        Reverts: Ensures the contract reverts correctly for invalid operations.

    Time Manipulation:
        Uses vm.warp to simulate the passage of time for testing vesting and rewards.
*/
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract SinglePoolStakingTest is Test {
    SinglePoolStaking public staking;
    MockERC20 public stakingToken;
    MockERC20 public rewardsToken;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    uint256 public constant REWARD_RATE = 1e18; // 1 token per second
    uint256 public constant VESTING_PERIOD = 7 days;

    function setUp() public {
        // Deploy mock ERC20 tokens
        stakingToken = new MockERC20("Staking Token", "STK");
        rewardsToken = new MockERC20("Rewards Token", "RWD");

        // Deploy the staking contract
        vm.prank(owner);
        staking = new SinglePoolStaking(
            address(stakingToken),
            address(rewardsToken),
            REWARD_RATE,
            VESTING_PERIOD
        );

        // Mint tokens to users
        stakingToken.mint(user1, 1000e18);
        stakingToken.mint(user2, 1000e18);
        rewardsToken.mint(address(staking), 10000e18); // Fund the staking contract with rewards
    }

    // Test staking functionality
    function testStake() public {
        vm.prank(user1);
        stakingToken.approve(address(staking), 100e18);

        vm.prank(user1);
        staking.stake(100e18);

        assertEq(staking.balances(user1), 100e18);
        assertEq(staking.totalSupply(), 100e18);
        assertEq(stakingToken.balanceOf(address(staking)), 100e18);
    }

    // Test withdrawing staked tokens
    function testWithdraw() public {
        // Stake first
        vm.prank(user1);
        stakingToken.approve(address(staking), 100e18);
        vm.prank(user1);
        staking.stake(100e18);

        // Withdraw
        vm.prank(user1);
        staking.withdraw(50e18);

        assertEq(staking.balances(user1), 50e18);
        assertEq(staking.totalSupply(), 50e18);
        assertEq(stakingToken.balanceOf(user1), 950e18);
    }

    // Test claiming rewards after vesting period
    function testClaimReward() public {
        // Stake first
        vm.prank(user1);
        stakingToken.approve(address(staking), 100e18);
        vm.prank(user1);
        staking.stake(100e18);

        // Fast-forward time to accrue rewards
        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // Claim rewards
        vm.prank(user1);
        staking.claimReward();

        uint256 expectedRewards = REWARD_RATE * (VESTING_PERIOD + 1);
        assertEq(rewardsToken.balanceOf(user1), expectedRewards);
        assertEq(staking.rewards(user1), 0);
    }

    // Test compounding rewards
    function testCompoundReward() public {
        // Stake first
        vm.prank(user1);
        stakingToken.approve(address(staking), 100e18);
        vm.prank(user1);
        staking.stake(100e18);

        // Fast-forward time to accrue rewards
        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // Compound rewards
        vm.prank(user1);
        staking.compoundReward();

        uint256 expectedRewards = REWARD_RATE * (VESTING_PERIOD + 1);
        assertEq(staking.balances(user1), 100e18 + expectedRewards);
        assertEq(staking.totalSupply(), 100e18 + expectedRewards);
    }

    // Test updating reward rate (governance feature)
    function testUpdateRewardRate() public {
        uint256 newRate = 2e18; // 2 tokens per second

        vm.prank(owner);
        staking.updateRewardRate(newRate);

        assertEq(staking.rewardRate(), newRate);
    }

    // Test updating vesting period (governance feature)
    function testUpdateVestingPeriod() public {
        uint256 newVestingPeriod = 14 days;

        vm.prank(owner);
        staking.updateVestingPeriod(newVestingPeriod);

        assertEq(staking.vestingPeriod(), newVestingPeriod);
    }

    // Test reverts
    function testStakeRevertsIfAmountIsZero() public {
        vm.prank(user1);
        stakingToken.approve(address(staking), 100e18);

        vm.expectRevert(abi.encodeWithSelector(NeedsMoreThanZero.selector));
        vm.prank(user1);
        staking.stake(0);
    }

    function testWithdrawRevertsIfInsufficientBalance() public {
        vm.prank(user1);
        stakingToken.approve(address(staking), 100e18);
        vm.prank(user1);
        staking.stake(100e18);

        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector));
        vm.prank(user1);
        staking.withdraw(200e18);
    }

    function testClaimRewardRevertsIfVestingPeriodNotMet() public {
        vm.prank(user1);
        stakingToken.approve(address(staking), 100e18);
        vm.prank(user1);
        staking.stake(100e18);

        vm.expectRevert(abi.encodeWithSelector(VestingPeriodNotMet.selector));
        vm.prank(user1);
        staking.claimReward();
    }
}