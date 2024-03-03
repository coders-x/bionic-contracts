//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BionicPoolRegistry} from "./BionicPoolRegistry.sol";

import "./BionicTokenDistributor.sol";

contract DistributorContractTest is DSTest, Test {
    uint256 public constant MONTH_IN_SECONDS = 30 days; // Approx 1 month

    BionicTokenDistributor private distributorContract;
    ERC20Mock private rewardToken;
    ERC20Mock private rewardToken2;
    address private owner = address(this);
    address[] private winners = [address(1), address(2), address(3)];

    function setUp() public {
        distributorContract = new BionicTokenDistributor();
        rewardToken = new ERC20Mock("REWARD TOKEN", "RWRD");
        rewardToken2 = new ERC20Mock("REWARD2 TOKEN", "RWRD2");
    }

    function registerProject() public {
        distributorContract.registerProjectToken(
            1,
            address(rewardToken),
            1e6,
            100,
            12 // a year
        );
    }

    function testRegisterProject() public {
        registerProject();

        (
            IERC20 token,
            uint256 amount,
            uint256 start,
            uint256 end,

        ) = distributorContract.s_projectTokens(1);
        assertEq(address(token), address(rewardToken));
        assertEq(amount, 1e6);
        assertEq(start, 100);
        assertEq(end, start + (12 * MONTH_IN_SECONDS));
    }

    function testAddUserAndClaim() public {
        registerProject();
        uint256 time = 200;
        uint256 pid = 1;

        //invalid project
        vm.expectRevert(Distributor__InvalidProject.selector);
        distributorContract.claimTokens(0);

        // nothing to claim not winner of project
        vm.expectRevert(
            abi.encodePacked(
                Distributor__ClaimingIsNotAllowedYet.selector,
                uint256(100)
            )
        );
        distributorContract.claimTokens(pid);

        //mock raffle
        vm.mockCall(
            address(distributorContract.owner()),
            abi.encodeWithSelector(
                BionicPoolRegistry.getProjectInvestors.selector,
                pid
            ),
            abi.encode(1e6, winners)
        );

        vm.startPrank(winners[0]);
        //add winners and send transactions as winner0
        distributorContract.addWinningInvestors(pid);
        vm.clearMockedCalls();

        //nothing to claim not in the window
        vm.expectRevert(
            abi.encodePacked(Distributor__ClaimingIsNotAllowedYet.selector, uint(100))
        );
        distributorContract.claimTokens(pid);
        vm.warp(time);

        vm.mockCall(
            address(distributorContract.owner()),
            abi.encodeWithSelector(
                BionicPoolRegistry.userPledgeOnPool.selector,
                pid,
                winners[0]
            ),
            abi.encode(1e3)
        );

        vm.expectRevert(Distributor__NothingToClaim.selector);
        distributorContract.claimTokens(pid);

        time += MONTH_IN_SECONDS;
        vm.warp(time);

        vm.expectRevert(
            abi.encodeWithSelector(
                Distributor__NotEnoughTokenLeft.selector,
                pid,
                address(rewardToken)
            )
        );
        distributorContract.claimTokens(pid);
        vm.stopPrank();

        //Fund The Claiming Contract
        uint totalBalance = 10000;
        rewardToken.mint(address(distributorContract), totalBalance);

        //claim for a month
        vm.startPrank(winners[0]);
        (uint claimable, ) = distributorContract.claimableAmount(pid, winners[0]);
        distributorContract.claimTokens(pid);

        (uint256 amount, uint256 claimableMonthCount) = distributorContract
            .claimableAmount(pid, winners[0]);
        assertEq(amount, 0);
        assertEq(claimableMonthCount, 0);

        (uint256 lastMonth, uint256 totalTokenClaimed) = distributorContract
            .s_userClaims(winners[0], pid);
        assertEq(lastMonth, time - 199);
        assertEq(totalTokenClaimed, 1000);
        assertEq(totalTokenClaimed, claimable);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= totalTokenClaimed
        );
        assertEq(rewardToken.balanceOf(address(winners[0])), totalTokenClaimed);

        //claim for 3 months
        time += MONTH_IN_SECONDS * 3;
        vm.warp(time);
        distributorContract.claimTokens(pid);

        (lastMonth, totalTokenClaimed) = distributorContract.s_userClaims(
            winners[0],
            pid
        );
        assertEq(lastMonth, time - 199);
        assertEq(totalTokenClaimed, 4000);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= totalTokenClaimed - 1000
        );
        assertEq(rewardToken.balanceOf(address(winners[0])), totalTokenClaimed);

        vm.expectRevert(Distributor__NothingToClaim.selector);
        distributorContract.claimTokens(pid);

        // //claim for other winner 4 month claim
        vm.mockCall(
            address(distributorContract.owner()),
            abi.encodeWithSelector(
                BionicPoolRegistry.userPledgeOnPool.selector,
                pid,
                winners[1]
            ),
            abi.encode(1e3)
        );
        vm.startPrank(winners[1]);
        distributorContract.claimTokens(pid);

        (lastMonth, totalTokenClaimed) = distributorContract.s_userClaims(
            winners[1],
            pid
        );
        assertEq(lastMonth, time - 199);
        assertEq(totalTokenClaimed, 4e3);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= totalTokenClaimed
        );
        assertEq(rewardToken.balanceOf(address(winners[1])), totalTokenClaimed);

        //claim for remaining months 4-12=8
        // time+=MONTH_IN_SECONDS*12;
        vm.warp(time + (MONTH_IN_SECONDS * 12));
        vm.startPrank(winners[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Distributor__NotEnoughTokenLeft.selector,
                pid,
                address(rewardToken)
            )
        );
        distributorContract.claimTokens(pid);

        //Fund The Claiming Contract
        totalBalance += 1e10;
        rewardToken.mint(address(distributorContract), 1e10);
        distributorContract.claimTokens(pid);

        (lastMonth, totalTokenClaimed) = distributorContract.s_userClaims(
            winners[1],
            pid
        );
        assertEq(lastMonth, (time + (MONTH_IN_SECONDS * 8)) - 199);
        assertEq(totalTokenClaimed, 12e3);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= 8e3
        );
        assertEq(rewardToken.balanceOf(address(winners[1])), totalTokenClaimed);

        vm.expectRevert(Distributor__NothingToClaim.selector);
        distributorContract.claimTokens(pid);
    }

    function testBatchClaim() public {
        // vm.warp(100);
        distributorContract.registerProjectToken(
            1,
            address(rewardToken),
            1e6,
            200,
            12 // a year
        );
        distributorContract.registerProjectToken(
            2,
            address(rewardToken2),
            2e6,
            400,
            6 //6 month
        );
        //Fund The Claiming Contract
        uint totalBalance = 10000;
        rewardToken.mint(address(distributorContract), totalBalance);
        rewardToken2.mint(address(distributorContract), totalBalance);

        //add winners and send transactions as winner0
        vm.mockCall(
            address(distributorContract.owner()),
            abi.encodeWithSelector(
                BionicPoolRegistry.getProjectInvestors.selector,
                1
            ),
            abi.encode(1e6, winners)
        );
        vm.mockCall(
            address(distributorContract.owner()),
            abi.encodeWithSelector(
                BionicPoolRegistry.getProjectInvestors.selector,
                2
            ),
            abi.encode(1e6, winners)
        );
        distributorContract.addWinningInvestors(1);
        distributorContract.addWinningInvestors(2);
        vm.clearMockedCalls();

        vm.startPrank(winners[0]);

        vm.expectRevert(
            abi.encodePacked(Distributor__ClaimingIsNotAllowedYet.selector, uint(200))
        );
        distributorContract.batchClaim();

        uint256 time = MONTH_IN_SECONDS * 3;
        vm.warp(time);

        vm.mockCall(
            address(distributorContract.owner()),
            abi.encodeWithSelector(
                BionicPoolRegistry.userPledgeOnPool.selector,
                1,
                winners[0]
            ),
            abi.encode(1e3)
        );

        vm.mockCall(
            address(distributorContract.owner()),
            abi.encodeWithSelector(
                BionicPoolRegistry.userPledgeOnPool.selector,
                2,
                winners[0]
            ),
            abi.encode(1e3)
        );

        (uint256[] memory total, uint256[] memory poolIds) = distributorContract
            .aggregateClaimsForAddress(winners[0]);
        assertEq(total.length, 2);
        assertEq(total[0], 2e3);
        assertEq(total[1], 4e3);
        assertEq(poolIds.length, 2);
        assertEq(poolIds[0], 1);
        assertEq(poolIds[1], 2);

        distributorContract.batchClaim();

        (total, poolIds) = distributorContract.aggregateClaimsForAddress(
            winners[0]
        );
        assertEq(total.length, 2);
        assertEq(total[0], 0);
        assertEq(total[1], 0);
        assertEq(poolIds.length, 2);
        assertEq(poolIds[0], 1);
        assertEq(poolIds[1], 2);

        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance - 2e3
        );
        assertEq(rewardToken.balanceOf(address(winners[0])), 2e3);
        assertEq(
            rewardToken2.balanceOf(address(distributorContract)),
            totalBalance - 2e3 * 2
        );
        assertEq(rewardToken2.balanceOf(address(winners[0])), 2e3 * 2);
    }
}

contract ERC20Mock is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
