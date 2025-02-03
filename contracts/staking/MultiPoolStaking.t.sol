// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "./MultiPoolStaking.sol";

contract MultiPoolStakingTest is Test {
    MultiPoolStaking public stakingContract;
    ERC20PresetMinterPauser public stakingToken;
    ERC20PresetMinterPauser public rewardsToken;
    address public owner = address(this);
    address public user = address(0x1);
    uint256 public poolId;

    function setUp() public {
        stakingToken = new ERC20PresetMinterPauser("Staking Token", "STK");
        rewardsToken = new ERC20PresetMinterPauser("Rewards Token", "RWD");
        stakingContract = new MultiPoolStaking();
        
        // Create pool
        stakingContract.createPool(address(stakingToken), address(rewardsToken), 1e18, 1 days);
        poolId = 0;
        
        // Mint and distribute tokens
        stakingToken.mint(user, 1000 ether);
        rewardsToken.mint(owner, 1000 ether);

        vm.prank(owner);
        rewardsToken.approve(address(stakingContract), 1000 ether);
        stakingContract.fundRewards(poolId, 1000 ether);
    }

    function testStake() public {
        vm.prank(user);
        stakingToken.approve(address(stakingContract), 100 ether);
        vm.prank(user);
        stakingContract.stake(poolId, 100 ether);

        (uint256 stakedBalance, ) = stakingContract.getUserInfo(poolId, user);
        assertEq(stakedBalance, 100 ether);
    }

    function testWithdraw() public {
        testStake();
        vm.prank(user);
        stakingContract.withdraw(poolId, 50 ether);
        (uint256 stakedBalance, ) = stakingContract.getUserInfo(poolId, user);
        assertEq(stakedBalance, 50 ether);
    }

    function testClaimReward() public {
        testStake();
        vm.warp(block.timestamp + 2 days);
        vm.prank(user);
        stakingContract.claimReward(poolId);
        ( , uint256 earnedRewards) = stakingContract.getUserInfo(poolId, user);
        assertGt(earnedRewards, 0);
    }

    function testEmergencyWithdraw() public {
        testStake();
        vm.prank(user);
        stakingContract.emergencyWithdraw(poolId);
        (uint256 stakedBalance, ) = stakingContract.getUserInfo(poolId, user);
        assertEq(stakedBalance, 0);
    }

    function testUpdateRewardRate() public {
        vm.prank(owner);
        stakingContract.updateRewardRate(poolId, 2e18);
        uint256 newRate = stakingContract.rewardPerToken(poolId);
        assertEq(newRate, 2e18);
    }

    function testDeactivatePool() public {
        vm.prank(owner);
        stakingContract.deactivatePool(poolId);
        vm.expectRevert("PoolDoesNotExist()");
        stakingContract.stake(poolId, 100 ether);
    }
}
