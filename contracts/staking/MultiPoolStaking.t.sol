// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "./MultiPoolStaking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MultiPoolStakingTest is Test {
    MultiPoolStaking stakingContract;
    ERC20 stakingToken;
    ERC20 rewardsToken;
    address owner = address(0x123);
    address user = address(0x456);
    uint256 poolId;
    
    function setUp() public {
        vm.startPrank(owner);
        stakingToken = new ERC20("Staking Token", "STK");
        rewardsToken = new ERC20("Rewards Token", "RWD");
        stakingContract = new MultiPoolStaking();
        
        stakingToken.mint(owner, 1_000_000 ether);
        rewardsToken.mint(owner, 1_000_000 ether);
        
        stakingContract.createPool(address(stakingToken), address(rewardsToken), 1 ether, 3600);
        stakingContract.fundRewards(0, 100_000 ether);
        vm.stopPrank();
        
        poolId = 0;
    }

    function testStakeTokens() public {
        vm.startPrank(user);
        stakingToken.mint(user, 1000 ether);
        stakingToken.approve(address(stakingContract), 1000 ether);
        stakingContract.stake(poolId, 100 ether);
        assertEq(stakingContract.getUserInfo(poolId, user).stakedBalance, 100 ether);
        vm.stopPrank();
    }
    
    function testWithdrawTokens() public {
        vm.startPrank(user);
        stakingToken.mint(user, 1000 ether);
        stakingToken.approve(address(stakingContract), 1000 ether);
        stakingContract.stake(poolId, 100 ether);
        stakingContract.withdraw(poolId, 50 ether);
        assertEq(stakingContract.getUserInfo(poolId, user).stakedBalance, 50 ether);
        vm.stopPrank();
    }
    
    function testClaimRewards() public {
        vm.startPrank(user);
        stakingToken.mint(user, 1000 ether);
        stakingToken.approve(address(stakingContract), 1000 ether);
        stakingContract.stake(poolId, 100 ether);
        vm.warp(block.timestamp + 4000);
        stakingContract.claimReward(poolId);
        assertGt(rewardsToken.balanceOf(user), 0);
        vm.stopPrank();
    }
    
    function testCompoundRewards() public {
        vm.startPrank(user);
        stakingToken.mint(user, 1000 ether);
        stakingToken.approve(address(stakingContract), 1000 ether);
        stakingContract.stake(poolId, 100 ether);
        vm.warp(block.timestamp + 4000);
        stakingContract.compoundReward(poolId);
        assertGt(stakingContract.getUserInfo(poolId, user).stakedBalance, 100 ether);
        vm.stopPrank();
    }
    
    function testGovernanceUpdateRewardRate() public {
        vm.startPrank(owner);
        stakingContract.updateRewardRate(poolId, 2 ether);
        assertEq(stakingContract.stakingPools(poolId).rewardRate, 2 ether);
        vm.stopPrank();
    }
}
