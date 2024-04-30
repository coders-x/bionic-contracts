//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/Launchpad/BionicPoolRegistry.sol";
import {ERC6551Registry} from "tokenbound/lib/erc6551/src/ERC6551Registry.sol";
import {AccountGuardian} from "../contracts/libs/AccountGuardian.sol";
import {BionicInvestorPass, BIP__Deprecated, BIP__InvalidSigniture} from "../contracts/BIP.sol";
import {BionicAccount, ECDSA} from "../contracts/BTBA.sol";
import "../contracts/Launchpad/BionicTokenDistributor.sol";
import {Treasury} from "../contracts/Launchpad/Treasury.sol";

import {Bionic} from "../contracts/Bionic.sol";
import {BionicStructs} from "../contracts/libs/BionicStructs.sol";
import {Merkle} from "murky/src/Merkle.sol";

// import "forge-std/console.sol";

contract BionicPoolRegistryTest is DSTest, Test {
    address public constant ENTRY_POINT =
        0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    ERC6551Registry public constant erc6551_Registry =
        ERC6551Registry(0x000000006551c19487814612e58FE06813775758);

    uint256 public constant CYCLE_IN_SECONDS = 30 days; // Approx 1 month
    bytes32 public constant GAS_LANE =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    bool public constant REQ_PER_WINNER = false;
    string constant MNEMONIC =
        "announce room limb pattern dry unit scale effort smooth jazz weasel alcohol";

    BionicPoolRegistry private _bionicFundRaising;
    Bionic private _bionicToken;
    ERC20Mock private _investingToken;
    BionicInvestorPass private _bipContract;
    uint64 private _subId;
    BionicAccount private _accountImplementation;
    Treasury private _treasuryContract;

    BionicTokenDistributor private _distrbutorContract;

    ERC20Mock private _rewardToken;
    ERC20Mock private _rewardToken2;
    address private _owner = address(this);
    address[] private _winners = [address(1), address(2), address(3)];
    Merkle m;

    function getPrivateKeys(
        uint256 startIndex,
        uint256 count
    ) internal pure returns (uint256[] memory prvKeys) {
        prvKeys = new uint256[](count);
        for (uint256 i = startIndex; i < count + startIndex; i++) {
            // uint256 privateKey = vm.deriveKey(MNEMONIC, i);
            uint256 privateKey = i;
            prvKeys[i - startIndex] = privateKey;
        }
        return prvKeys;
    }

    function setUp() public {
        /**
         * set up fork
         */
        string memory RPC_ENDPOINT = vm.envString("ARB_RPC"); //solint-disable-line
        uint256 mumbaiFork = vm.createFork(RPC_ENDPOINT);
        vm.selectFork(mumbaiFork);
        m = new Merkle();
        _bionicToken = Bionic(
            address(new UUPSProxy(address(new Bionic()), ""))
        );
        _bionicToken.initialize();
        _bipContract = BionicInvestorPass(
            address(new UUPSProxy(address(new BionicInvestorPass()), ""))
        );
        _bipContract.initialize();
        _investingToken = new ERC20Mock("USD TETHER", "USDT");

        _rewardToken = new ERC20Mock("REWARD TOKEN", "RWRD");
        _rewardToken2 = new ERC20Mock("REWARD2 TOKEN", "RWRD2");

        _bionicFundRaising = BionicPoolRegistry(
            address(new UUPSProxy(address(new BionicPoolRegistry()), ""))
        );
        _bionicFundRaising.initialize(
            IERC20(address(_bionicToken)),
            _investingToken,
            address(_bipContract)
        );
        _treasuryContract = Treasury(_bionicFundRaising.treasury());

        _distrbutorContract = BionicTokenDistributor(
            address(new UUPSProxy(address(new BionicTokenDistributor()), ""))
        );
        _distrbutorContract.initialize();

        _accountImplementation = new BionicAccount(
            ENTRY_POINT,
            address(1),
            address(erc6551_Registry),
            address(new AccountGuardian())
        );
    }

    function registerProject(bool useRaffle) public returns (uint256 pid) {
        BionicStructs.PledgeTier[] memory pt = new BionicStructs.PledgeTier[](
            3
        );
        pt[0] = BionicStructs.PledgeTier(1, 1000, 1000);
        pt[1] = BionicStructs.PledgeTier(2, 3000, 3000);
        pt[2] = BionicStructs.PledgeTier(3, 5000, 5000);
        _bionicFundRaising.add(
            pid,
            block.timestamp + 1 minutes,
            block.timestamp + 10 minutes,
            10e18,
            useRaffle,
            pt
        );

        // try
        //     _distrbutorContract.registerProjectToken(
        //         pid,
        //         address(_rewardToken),
        //         allocatedTokenPerMonth,
        //         block.timestamp + 20 minutes,
        //         10,
        //         merkleRoot
        //     )
        // {} catch (bytes memory reason) {
        //     /// @solidity memory-safe-assembly
        //     assembly {
        //         revert(add(32, reason), mload(reason))
        //     }
        // }

        return (pid);
    }

    function testAddProject() public {
        uint256 pid = registerProject(false);
        (, , , , bool useRaffle) = _bionicFundRaising.poolInfo(pid);

        assertEq(false, useRaffle);
    }

    function testPerformInvestmentAndClaim() public {
        //0. add project
        uint256 allocatedTokenPerMonth = 1e10;
        uint256 deadline = block.timestamp + 7 days;
        uint256 count = 10;
        // uint256 winnersCount = 500;
        uint256 pid = registerProject(false);
        uint256[] memory privateKeys = getPrivateKeys(50, count * 2);
        BionicAccount[] memory accs = new BionicAccount[](count);
        BionicStructs.PledgeTier[] memory pledgeTiers = _bionicFundRaising
            .pledgeTiers(pid);

        vm.warp(block.timestamp + 2 minutes);

        //1. pledge
        for (uint256 i = 0; i < count; i++) {
            address user = vm.addr(privateKeys[i * 2]);
            address guardian = vm.addr(privateKeys[(i * 2) + 1]);
            _bipContract.safeMint(user, guardian, "");
            address accountAddress = erc6551_Registry.createAccount(
                address(_accountImplementation),
                "",
                block.chainid,
                address(_bipContract),
                i
            );
            _bionicToken.transfer(
                accountAddress,
                _bionicFundRaising.MINIMUM_BIONIC_STAKE()
            );
            uint256 amount = pledgeTiers[i % 3].minimumPledge;
            _investingToken.mint(accountAddress, amount ** 5);
            BionicAccount acc = BionicAccount(payable(accountAddress));
            accs[i] = acc;
            bytes32 structHash = ECDSA.toTypedDataHash(
                acc.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        acc.CURRENCY_PERMIT_TYPEHASH(),
                        _investingToken,
                        address(_bionicFundRaising),
                        amount,
                        acc.getNonce(),
                        deadline
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                privateKeys[i * 2],
                structHash
            );

            vm.prank(user);
            bytes memory data = abi.encodeWithSelector(
                _bionicFundRaising.pledge.selector,
                pid,
                amount,
                deadline,
                v,
                r,
                s
            );
            // will call _bionicContract.pledge(pid, amount, deadline, v, r, s).;
            acc.execute(address(_bionicFundRaising), 0, data, 0);
        }

        //2. move time and do draw get the winners
        vm.warp(15 minutes);

        (, address[] memory winners) = _bionicFundRaising.getProjectInvestors(
            pid
        );
        assertEq(winners.length, count);

        //4. add winners to claim
        uint256 totalBalance = 30 * 10 ether;
        _rewardToken.mint(address(_distrbutorContract), totalBalance);
        assertEq(
            _rewardToken.balanceOf(address(_distrbutorContract)),
            totalBalance
        );

        uint256 totalInvested = 0;
        bytes32[] memory merkleTree = new bytes32[](winners.length);
        for (uint256 i = 0; i < winners.length; i++) {
            merkleTree[i] = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            pid,
                            winners[i],
                            _bionicFundRaising.userPledgeOnPool(pid, winners[i])
                        )
                    )
                )
            );

            totalInvested += _bionicFundRaising.userPledgeOnPool(
                pid,
                winners[i]
            );
        }
        assertEq(_bionicFundRaising.treasuryWithdrawable(), totalInvested);

        bytes32 merkleRoot = m.getRoot(merkleTree);
        _distrbutorContract.registerProjectToken(
            pid,
            address(_rewardToken),
            allocatedTokenPerMonth,
            block.timestamp + 20 minutes,
            10,
            merkleRoot
        );

        (
            IERC20 token,
            uint256 monthShare,
            uint256 start,
            ,
            bytes32 root
        ) = _distrbutorContract.s_projectTokens(pid);
        assertEq(address(token), address(_rewardToken));
        assertEq(start, block.timestamp + 20 minutes);
        assertEq(merkleRoot, root);

        uint256 time = start + CYCLE_IN_SECONDS * 3;
        vm.warp(time);

        for (uint256 i = 0; i < winners.length; i++) {
            uint256 claimable = 3 *
                (monthShare * pledgeTiers[i % 3].minimumPledge);

            (uint256 userClaim, ) = _distrbutorContract.calcClaimableAmount(
                pid,
                winners[i],
                _bionicFundRaising.userPledgeOnPool(pid, winners[i])
            );

            assertEq(userClaim, claimable);
            vm.prank(winners[i]);
            bytes32[] memory proof = m.getProof(merkleTree, i);
            _distrbutorContract.claim(
                pid,
                winners[i],
                pledgeTiers[i % 3].minimumPledge,
                proof
            );
            totalBalance -= claimable;
            assertEq(_rewardToken.balanceOf(winners[i]), claimable);
            assertEq(
                _rewardToken.balanceOf(address(_distrbutorContract)),
                totalBalance
            );

            vm.expectRevert(Distributor__NothingToClaim.selector);
            _distrbutorContract.claim(
                pid,
                winners[i],
                pledgeTiers[i % 3].minimumPledge,
                proof
            );
        }
    }

    function testTransferNFT() public {
        uint256[] memory privateKeys = getPrivateKeys(5, 3);
        address user = vm.addr(privateKeys[0]);
        address guardian = vm.addr(privateKeys[1]);
        address rescue = vm.addr(privateKeys[2]);
        uint256 tokenId = 0;
        uint256 deadline = block.timestamp + 7 days;

        _bipContract.safeMint(user, guardian, "");
        assertEq(_bipContract.ownerOf(0), user);
        assertEq(_bipContract.guardianOf(0), guardian);

        vm.expectRevert(BIP__Deprecated.selector);
        _bipContract.transferFrom(user, guardian, tokenId);
        vm.expectRevert(BIP__Deprecated.selector);
        _bipContract.safeTransferFrom(user, guardian, tokenId);

        bytes32 structHash = ECDSA.toTypedDataHash(
            _bipContract.DOMAIN_SEPARATOR(),
            keccak256(
                abi.encode(
                    _bipContract.ACCOUNT_RESCUE_TYPEHASH(),
                    rescue,
                    tokenId,
                    deadline
                )
            )
        );

        //privatekey[0] belongs to owner
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[0], structHash);
        vm.expectRevert(BIP__InvalidSigniture.selector);
        _bipContract.accountRescueApprove(rescue, tokenId, deadline, v, r, s);

        //privatekey[0] belongs to guardian
        (v, r, s) = vm.sign(privateKeys[1], structHash);
        _bipContract.accountRescueApprove(rescue, tokenId, deadline, v, r, s);

        assertEq(_bipContract.ownerOf(0), rescue);
        assertEq(_bipContract.guardianOf(0), guardian);
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

contract UUPSProxy is ERC1967Proxy {
    constructor(
        address _implementation,
        bytes memory _data
    ) ERC1967Proxy(_implementation, _data) {}
}
