//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {BionicFundRaising} from "./BionicFundRaising.sol";

import "./Claim.sol";

contract ClaimingContractTest is DSTest, Test {
    uint256 public constant MONTH_IN_SECONDS = 30 days; // Approx 1 month

    ClaimFunding private claimingContract;
    ERC20Mock private rewardToken;
    ERC20Mock private rewardToken2;
    address private owner = address(this);
    address[] private winners = [address(1), address(2), address(3)];

    function setUp() public {
        claimingContract = new ClaimFunding();
        rewardToken = new ERC20Mock("REWARD TOKEN", "RWRD");
        rewardToken2 = new ERC20Mock("REWARD2 TOKEN", "RWRD2");
    }

    function registerProject() public {
        claimingContract.registerProjectToken(
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

        ) = claimingContract.s_projectTokens(1);
        assertEq(address(token), address(rewardToken));
        assertEq(amount, 1e6);
        assertEq(start, 100);
        assertEq(end, start + (12 * MONTH_IN_SECONDS));
    }

    function testAddUserAndClaim() public {
        registerProject();
        uint256 time = 200;
        uint pid = 1;

        //invalid project
        vm.expectRevert(Claim__InvalidProject.selector);
        claimingContract.claimTokens(0);

        //nothing to claim not winner of project
        vm.expectRevert(
            abi.encodePacked(
                Claim__ClaimingIsNotAllowedYet.selector,
                uint256(100)
            )
        );
        claimingContract.claimTokens(pid);

        //mock raffle
        vm.mockCall(
            address(claimingContract.owner()),
            abi.encodeWithSelector(
                BionicFundRaising.getProjectInvestors.selector,
                pid
            ),
            abi.encode(1e6, winners)
        );

        vm.startPrank(winners[0]);
        //add winners and send transactions as winner0
        claimingContract.addWinningInvestors(pid);
        vm.clearMockedCalls();

        //nothing to claim not in the window
        vm.expectRevert(
            abi.encodePacked(Claim__ClaimingIsNotAllowedYet.selector, uint(100))
        );
        claimingContract.claimTokens(pid);
        vm.warp(time);

        vm.expectRevert(Claim__NothingToClaim.selector);
        claimingContract.claimTokens(pid);

        time += MONTH_IN_SECONDS;
        vm.warp(time);

        // //arrange
        // // vm.mockCall(
        // //     address(claimingContract.owner()),
        // //     abi.encodeWithSelector(
        // //         BionicFundRaising.getProjectInvestors.selector,
        // //         pid
        // //     ),
        // //     abi.encode(1e6)
        // // );
        vm.mockCall(
            address(claimingContract.owner()),
            abi.encodeWithSelector(
                BionicFundRaising.userPledgeOnPool.selector,
                pid,
                winners[0]
            ),
            abi.encode(1e3)
        );

        // // vm.expectRevert(abi.encodePacked(Claim__NotEnoughTokenLeft.selector, pid, address(rewardToken)));
        // vm.expectRevert(
        //     abi.encodePacked(
        //         hex"f02941ee00000000000000000000000000000000000000000000000000000000000000010000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b"
        //     )
        // );
        // claimingContract.claimTokens(pid);
        vm.stopPrank();

        //Fund The Claiming Contract
        uint totalBalance = 10000;
        rewardToken.mint(address(claimingContract), totalBalance);

        //claim for a month
        vm.startPrank(winners[0]);
        (uint claimable, ) = claimingContract.claimableAmount(pid, winners[0]);
        claimingContract.claimTokens(pid);

        vm.expectRevert(Claim__NothingToClaim.selector);
        claimingContract.claimableAmount(pid, winners[0]);

        (uint256 lastMonth, uint256 totalTokenClaimed) = claimingContract
            .s_userClaims(winners[0], pid);
        assertEq(lastMonth, time - 199);
        assertEq(totalTokenClaimed, 1000);
        assertEq(totalTokenClaimed, claimable);
        assertEq(
            rewardToken.balanceOf(address(claimingContract)),
            totalBalance -= totalTokenClaimed
        );
        assertEq(rewardToken.balanceOf(address(winners[0])), totalTokenClaimed);

        //claim for 3 months
        time += MONTH_IN_SECONDS * 3;
        vm.warp(time);
        claimingContract.claimTokens(pid);

        (lastMonth, totalTokenClaimed) = claimingContract.s_userClaims(
            winners[0],
            pid
        );
        assertEq(lastMonth, time - 199);
        assertEq(totalTokenClaimed, 4000);
        assertEq(
            rewardToken.balanceOf(address(claimingContract)),
            totalBalance -= totalTokenClaimed - 1000
        );
        assertEq(rewardToken.balanceOf(address(winners[0])), totalTokenClaimed);

        vm.expectRevert(Claim__NothingToClaim.selector);
        claimingContract.claimTokens(pid);

        // //claim for other winner 4 month claim
        console.log("*****************");
        vm.mockCall(
            address(claimingContract.owner()),
            abi.encodeWithSelector(
                BionicFundRaising.userPledgeOnPool.selector,
                pid,
                winners[1]
            ),
            abi.encode(1e3)
        );
        vm.startPrank(winners[1]);
        claimingContract.claimTokens(pid);

        (lastMonth, totalTokenClaimed) = claimingContract.s_userClaims(
            winners[1],
            pid
        );
        assertEq(lastMonth, time - 199);
        assertEq(totalTokenClaimed, 4e3);
        assertEq(
            rewardToken.balanceOf(address(claimingContract)),
            totalBalance -= totalTokenClaimed
        );
        assertEq(rewardToken.balanceOf(address(winners[1])), totalTokenClaimed);

        //claim for remaining months 4-12=8
        // time+=MONTH_IN_SECONDS*12;
        vm.warp(time + (MONTH_IN_SECONDS * 12));
        vm.startPrank(winners[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Claim__NotEnoughTokenLeft.selector,
                pid,
                address(rewardToken)
            )
        );
        claimingContract.claimTokens(pid);

        //Fund The Claiming Contract
        totalBalance += 1e10;
        rewardToken.mint(address(claimingContract), 1e10);
        claimingContract.claimTokens(pid);

        (lastMonth, totalTokenClaimed) = claimingContract.s_userClaims(
            winners[1],
            pid
        );
        assertEq(lastMonth, (time + (MONTH_IN_SECONDS * 8)) - 199);
        assertEq(totalTokenClaimed, 12e3);
        assertEq(
            rewardToken.balanceOf(address(claimingContract)),
            totalBalance -= 8e3
        );
        assertEq(rewardToken.balanceOf(address(winners[1])), totalTokenClaimed);

        vm.expectRevert(Claim__NothingToClaim.selector);
        claimingContract.claimTokens(pid);
    }

    function testBatchClaim() public {
        // vm.warp(100);
        claimingContract.registerProjectToken(
            1,
            address(rewardToken),
            1e6,
            200,
            12 // a year
        );
        claimingContract.registerProjectToken(
            2,
            address(rewardToken2),
            2e6,
            400,
            6 //6 month
        );
        //Fund The Claiming Contract
        uint totalBalance = 10000;
        rewardToken.mint(address(claimingContract), totalBalance);
        rewardToken2.mint(address(claimingContract), totalBalance);

        //add winners and send transactions as winner0
        vm.mockCall(
            address(claimingContract.owner()),
            abi.encodeWithSelector(
                BionicFundRaising.getProjectInvestors.selector,
                1
            ),
            abi.encode(1e6, winners)
        );
        vm.mockCall(
            address(claimingContract.owner()),
            abi.encodeWithSelector(
                BionicFundRaising.getProjectInvestors.selector,
                2
            ),
            abi.encode(1e6, winners)
        );
        claimingContract.addWinningInvestors(1);
        claimingContract.addWinningInvestors(2);
        vm.clearMockedCalls();

        vm.startPrank(winners[0]);

        vm.expectRevert(
            abi.encodePacked(Claim__ClaimingIsNotAllowedYet.selector, uint(200))
        );
        claimingContract.batchClaim();

        uint256 time = MONTH_IN_SECONDS * 3;
        vm.warp(time);

        vm.mockCall(
            address(claimingContract.owner()),
            abi.encodeWithSelector(
                BionicFundRaising.userPledgeOnPool.selector,
                1,
                winners[0]
            ),
            abi.encode(1e3)
        );

        vm.mockCall(
            address(claimingContract.owner()),
            abi.encodeWithSelector(
                BionicFundRaising.userPledgeOnPool.selector,
                2,
                winners[0]
            ),
            abi.encode(1e3)
        );
        // vm.expectRevert(Claim__NothingToClaim.selector);
        claimingContract.batchClaim();

        assertEq(
            rewardToken.balanceOf(address(claimingContract)),
            totalBalance -2e3
        );
        assertEq(rewardToken.balanceOf(address(winners[0])), 2e3);
        assertEq(
            rewardToken2.balanceOf(address(claimingContract)),
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
