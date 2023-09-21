//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/Launcpad/BionicFundRaising.sol";
import {VRFCoordinatorV2Mock} from "../contracts/libs/VRFCoordinatorV2Mock.sol";
import {ERC6551Registry} from "../contracts/libs/ERC6551Registry.sol";
import {AccountGuardian} from "../contracts/libs/AccountGuardian.sol";
import {BionicInvestorPass} from "../contracts/BIP.sol";
import {TokenBoundAccount, ECDSA} from "../contracts/TBA.sol";
import "../contracts/Launcpad/Claim.sol";
import {Bionic} from "../contracts/Bionic.sol";
import "forge-std/console.sol";

contract BionicFundRaisingTest is DSTest, Test {
    address public constant ENTRY_POINT =
        0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    ERC6551Registry public constant erc6551_Registry =
        ERC6551Registry(0x02101dfB77FDE026414827Fdc604ddAF224F0921);

    uint256 public constant MONTH_IN_SECONDS = 30 days; // Approx 1 month
    bytes32 public constant GAS_LANE =
        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    bool public constant REQ_PER_WINNER = false;
    string constant MNEMONIC =
        "announce room limb pattern dry unit scale effort smooth jazz weasel alcohol";

    BionicFundRaising private _bionicFundRaising;
    Bionic private _bionicToken;
    ERC20Mock private _investingToken;
    BionicInvestorPass private _bipContract;
    VRFCoordinatorV2Mock private _vrfCoordinatorV2;
    uint64 private _subId;
    TokenBoundAccount private _accountImplementation;

    ClaimFunding private _claimContract;

    ERC20Mock private _rewardToken;
    ERC20Mock private _rewardToken2;
    address private _owner = address(this);
    address[] private _winners = [address(1), address(2), address(3)];

    function getPrivateKeys(
        uint256 startIndex,
        uint256 count
    ) internal returns (uint256[] memory prvKeys) {
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
        string memory MUMBAI_RPC_URL = vm.envString("MUMBAI_RPC"); //solint-disable-line
        uint256 mumbaiFork = vm.createFork(MUMBAI_RPC_URL);
        vm.selectFork(mumbaiFork);

        _bionicToken = Bionic(
            address(new UUPSProxy(address(new Bionic()), ""))
        );
        _bionicToken.initialize();
        _bipContract = BionicInvestorPass(
            address(new UUPSProxy(address(new BionicInvestorPass()), ""))
        );
        _bipContract.initialize();
        _investingToken = new ERC20Mock("USD TETHER", "USDT");
        _vrfCoordinatorV2 = new VRFCoordinatorV2Mock(
            100000000000000000,
            1000000000
        );
        _subId = _vrfCoordinatorV2.createSubscription();
        _vrfCoordinatorV2.fundSubscription(_subId, 10e18);

        _rewardToken = new ERC20Mock("REWARD TOKEN", "RWRD");
        _rewardToken2 = new ERC20Mock("REWARD2 TOKEN", "RWRD2");

        _bionicFundRaising = new BionicFundRaising(
            IERC20(address(_bionicToken)),
            _investingToken,
            address(_bipContract),
            address(_vrfCoordinatorV2),
            GAS_LANE,
            _subId,
            REQ_PER_WINNER
        );
        _vrfCoordinatorV2.addConsumer(_subId, address(_bionicFundRaising));

        _claimContract = ClaimFunding(_bionicFundRaising.claimFund());

        _accountImplementation = new TokenBoundAccount(
            address(new AccountGuardian()),
            ENTRY_POINT
        );
    }

    function registerProject() public returns (uint256 pid, uint32[] memory t) {
        t = new uint32[](3);
        t[0] = 300;
        t[1] = 100;
        t[2] = 100;
        pid = _bionicFundRaising.add(
            _rewardToken,
            block.timestamp,
            block.timestamp + 10 minutes,
            1000,
            100,
            block.timestamp + 20 minutes,
            10,
            10e18,
            t
        );

        return (pid, t);
    }

    function testAddProject() public {
        (uint256 pid, ) = registerProject();
        (
            IERC20 poolToken,
            ,
            ,
            ,
            uint256 tokenAllocationPerMonth,
            uint256 tokenAllocationStartTime,
            uint256 tokenAllocationMonthCount,
            ,

        ) = _bionicFundRaising.poolInfo(pid);
        (
            IERC20 token,
            uint256 amount,
            uint256 start,
            uint256 end
        ) = _claimContract.s_projectTokens(pid);
        assertEq(address(token), address(_rewardToken));
        assertEq(address(token), address(poolToken));
        assertEq(amount, tokenAllocationPerMonth);
        assertEq(start, tokenAllocationStartTime);
        assertEq(end, start + (tokenAllocationMonthCount * MONTH_IN_SECONDS));
    }

    function testPerformLotteryAndClaim() public {
        //0. add project
        (uint256 pid, uint32[] memory tiers) = registerProject();
        uint256 deadline = block.timestamp + 7 days;
        uint256 count = 1025;
        uint256 winnersCount = 500;
        uint256[] memory privateKeys = getPrivateKeys(25, count);
        TokenBoundAccount[] memory accs = new TokenBoundAccount[](count);
        //1. pledge
        console.log("length %s", privateKeys.length);
        for (uint256 i = 0; i < privateKeys.length; i++) {
            uint256 privateKey = privateKeys[i];
            address user = vm.addr(privateKey);

            _bipContract.safeMint(user, "");
            address accountAddress = erc6551_Registry.createAccount(
                address(_accountImplementation),
                block.chainid,
                address(_bipContract),
                i,
                0,
                ""
            );
            _bionicToken.transfer(
                accountAddress,
                _bionicFundRaising.MINIMUM_BIONIC_STAKE()
            );
            uint256 amount = 1000;
            _investingToken.mint(accountAddress, amount ** 5);
            TokenBoundAccount acc = TokenBoundAccount(payable(accountAddress));
            accs[i] = acc;
            bytes32 structHash = ECDSA.toTypedDataHash(
                acc.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        acc.CURRENCY_PERMIT_TYPEHASH(),
                        _investingToken,
                        address(_bionicFundRaising),
                        amount,
                        acc.nonce(),
                        deadline
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, structHash);

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
            acc.executeCall(address(_bionicFundRaising), 0, data);
        }

        //2. accounts pledged lets add them to tiers
        uint256 k = 0; //index of account
        uint256 userPerWinner = accs.length / winnersCount;
        for (uint256 i = 0; i < tiers.length - 1; i++) {
            address[] memory accounts = new address[](tiers[i] * userPerWinner);
            for (uint256 j = 0; j < tiers[i] * userPerWinner; j++) {
                accounts[j] = address(accs[k++]);
            }
            _bionicFundRaising.addToTier(pid, i, accounts);
        }

        //3. move time and do draw get the winners
        (, , , , , uint256 tokenAllocationStartTime, , , ) = _bionicFundRaising
            .poolInfo(pid);
        vm.warp(tokenAllocationStartTime - 5 minutes);
        uint256 requestId = _bionicFundRaising.draw(pid, 1000000);

        _vrfCoordinatorV2.fulfillRandomWords(
            requestId,
            address(_bionicFundRaising)
        );

        address[] memory winners = _bionicFundRaising.getRaffleWinners(pid);
        assertEq(winners.length, winnersCount);

        //4. add winners to claim
        uint totalBalance = 30 * 10e18;
        _rewardToken.mint(address(_claimContract), totalBalance);
        assertEq(_rewardToken.balanceOf(address(_claimContract)), totalBalance);

        _claimContract.addWinningInvestors(pid);
        (IERC20 token, uint256 amount, uint256 start, ) = _claimContract
            .s_projectTokens(pid);
        assertEq(address(token), address(_rewardToken));

        uint256 time = start + MONTH_IN_SECONDS * 3;
        vm.warp(time);
        uint256 claimable = 3 * amount;
        for (uint256 i = 0; i < winners.length; i++) {
            assertEq(
                _claimContract.claimableAmount(pid, winners[i]),
                claimable
            );
            vm.prank(winners[i]);
            _claimContract.claimTokens(pid);
            totalBalance -= claimable;
            assertEq(_rewardToken.balanceOf(winners[i]), claimable);
            assertEq(
                _rewardToken.balanceOf(address(_claimContract)),
                totalBalance
            );

            vm.prank(winners[i]);
            vm.expectRevert(Claim__NothingToClaim.selector);
            _claimContract.claimTokens(pid);
        }
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
