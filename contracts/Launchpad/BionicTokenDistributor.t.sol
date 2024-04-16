//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BionicPoolRegistry} from "./BionicPoolRegistry.sol";
import {Merkle} from "murky/src/Merkle.sol";
import "./BionicTokenDistributor.sol";
// import "forge-std/console.sol";

contract DistributorContractTest is DSTest, Test {
    uint256 public constant CYCLE_IN_SECONDS = 30 days; // Approx 1 month

    BionicTokenDistributor private distributorContract;
    ERC20Mock private rewardToken;
    ERC20Mock private rewardToken2;
    address private owner = address(this);
    address[] private winners = [address(1), address(2), address(3)];
    Merkle m = new Merkle();
    function setUp() public {
        distributorContract = BionicTokenDistributor(
            address(new UUPSProxy(address(new BionicTokenDistributor()), ""))
        );
        distributorContract.initialize();
        rewardToken = new ERC20Mock("REWARD TOKEN", "RWRD");
        rewardToken2 = new ERC20Mock("REWARD2 TOKEN", "RWRD2");
    }

    function registerProject(uint256 pid, bytes32 merkleRoot) public {
        distributorContract.registerProjectToken(
            pid,
            address(rewardToken),
            1e2,
            100,
            12, // a year
            merkleRoot
        );
    }

    function testRegisterProject() public {
        uint256 pledged = 1e3;
        uint256 pid = 1;
        bytes32[] memory data = new bytes32[](4);
        data[0] = keccak256(
            bytes.concat(keccak256(abi.encode(pid, winners[0], pledged)))
        );
        data[1] = keccak256(
            bytes.concat(keccak256(abi.encode(pid, winners[1], pledged)))
        );
        bytes32 merkleRoot = m.getRoot(data);
        registerProject(pid, merkleRoot);

        (
            IERC20 token,
            uint256 monthQuota,
            uint256 startAt,
            uint256 totalCycles,
            bytes32 root
        ) = distributorContract.s_projectTokens(pid);
        assertEq(address(token), address(rewardToken));
        assertEq(monthQuota, 1e2);
        assertEq(startAt, 100);
        assertEq(totalCycles, 12);
        assertEq(root, merkleRoot);
    }

    function testAddUserAndClaim() public {
        uint256 pid = 0;
        uint256 pledged = 1e3;
        bytes32[] memory data = new bytes32[](4);
        data[0] = keccak256(
            bytes.concat(keccak256(abi.encode(pid, winners[0], pledged)))
        );
        data[1] = keccak256(
            bytes.concat(keccak256(abi.encode(pid, winners[1], pledged)))
        );
        data[2] = keccak256(
            bytes.concat(keccak256(abi.encode(pid, winners[2], pledged)))
        );
        bytes32 merkleRoot = m.getRoot(data);

        registerProject(pid, merkleRoot);
        uint256 time = 200;
        bytes32[] memory proof = m.getProof(data, 0); // will get proof for 0x2 value
        //invalid project
        vm.expectRevert(Distributor__InvalidProject.selector);
        distributorContract.claim(1000, address(100), 0, proof);

        // nothing to claim not winner of project
        vm.expectRevert(
            abi.encodePacked(
                Distributor__ClaimingIsNotAllowedYet.selector,
                uint256(100)
            )
        );
        distributorContract.claim(pid, winners[0], pledged, proof);

        vm.startPrank(winners[0]);
        vm.clearMockedCalls();

        // //nothing to claim not in the window
        vm.expectRevert(Distributor__NotEligible.selector);
        distributorContract.claim(pid, winners[0], 0, proof);
        vm.warp(time);

        vm.expectRevert(Distributor__NothingToClaim.selector);
        distributorContract.claim(pid, winners[0], pledged, proof);

        time += CYCLE_IN_SECONDS;
        vm.warp(time);

        vm.expectRevert(
            abi.encodeWithSelector(
                Distributor__NotEnoughTokenLeft.selector,
                pid,
                address(rewardToken)
            )
        );
        distributorContract.claim(pid, winners[0], pledged, proof);
        vm.stopPrank();

        //Fund The Claiming Contract
        (uint claimable, ) = distributorContract.calcClaimableAmount(
            pid,
            winners[0],
            pledged
        );
        uint totalBalance = claimable * 8;
        rewardToken.mint(address(distributorContract), totalBalance);

        //claim for a month
        vm.startPrank(winners[0]);

        vm.expectEmit(address(distributorContract));
        emit BionicTokenDistributor.Claimed(pid, winners[0], 1, claimable);
        distributorContract.claim(pid, winners[0], pledged, proof);
        assertEq(rewardToken.balanceOf(winners[0]), claimable);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= claimable
        );

        (uint256 amount, uint256 claimableMonthCount) = distributorContract
            .calcClaimableAmount(pid, winners[0], pledged);
        assertEq(amount, 0);
        assertEq(claimableMonthCount, 0);

        assertEq(distributorContract.s_userClaims(winners[0], pid), 1);
        assertEq(distributorContract.s_userClaims(winners[1], pid), 0);

        //claim for 3 months
        time += CYCLE_IN_SECONDS * 3;
        vm.warp(time);

        vm.expectEmit(address(distributorContract));
        emit BionicTokenDistributor.Claimed(pid, winners[0], 3, claimable * 3);
        distributorContract.claim(pid, winners[0], pledged, proof);

        assertEq(distributorContract.s_userClaims(winners[0], pid), 4);
        assertEq(distributorContract.s_userClaims(winners[1], pid), 0);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= claimable * 3
        );
        assertEq(rewardToken.balanceOf(address(winners[0])), claimable * 4);

        vm.expectRevert(Distributor__NothingToClaim.selector);
        distributorContract.claim(pid, winners[0], pledged, proof);

        //claim for other winner 4 month claim
        vm.startPrank(winners[1]);
        proof = m.getProof(data, 1);
        distributorContract.claim(pid, winners[1], pledged, proof);

        assertEq(distributorContract.s_userClaims(winners[0], pid), 4);
        assertEq(distributorContract.s_userClaims(winners[1], pid), 4);
        assertEq(rewardToken.balanceOf(address(winners[1])), claimable * 4);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= claimable * 4
        );
        //claim for remaining months 4-12=8
        // time+=CYCLE_IN_SECONDS*12;
        vm.warp(time + (CYCLE_IN_SECONDS * 12));
        vm.expectRevert(
            abi.encodeWithSelector(
                Distributor__NotEnoughTokenLeft.selector,
                pid,
                address(rewardToken)
            )
        );
        distributorContract.claim(pid, winners[1], pledged, proof);

        //Fund The Claiming Contract
        totalBalance += claimable * 10;
        rewardToken.mint(address(distributorContract), claimable * 10);
        distributorContract.claim(pid, winners[1], pledged, proof);
        assertEq(rewardToken.balanceOf(address(winners[1])), claimable * 12);
        assertEq(
            rewardToken.balanceOf(address(distributorContract)),
            totalBalance -= claimable * 8
        );

        vm.expectRevert(Distributor__Done.selector);
        distributorContract.claim(pid, winners[1], pledged, proof);
    }

    /*     function testBatchClaim() public {
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
        // vm.mockCall(
        //     address(distributorContract.owner()),
        //     abi.encodeWithSelector(
        //         BionicPoolRegistry.getProjectInvestors.selector,
        //         1
        //     ),
        //     abi.encode(1e6, winners)
        // );
        // vm.mockCall(
        //     address(distributorContract.owner()),
        //     abi.encodeWithSelector(
        //         BionicPoolRegistry.getProjectInvestors.selector,
        //         2
        //     ),
        //     abi.encode(1e6, winners)
        // );
        distributorContract.addWinningInvestors(1,1e6, winners);
        distributorContract.addWinningInvestors(2,1e6, winners);
        vm.clearMockedCalls();

        vm.startPrank(winners[0]);

        vm.expectRevert(
            abi.encodePacked(Distributor__ClaimingIsNotAllowedYet.selector, uint(200))
        );
        distributorContract.batchClaim();

        uint256 time = CYCLE_IN_SECONDS * 3;
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
    } */
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

contract UUPSProxy is ERC1967Proxy {
    constructor(
        address _implementation,
        bytes memory _data
    ) ERC1967Proxy(_implementation, _data) {}
}
