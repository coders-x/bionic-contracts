//SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./BionicFundRaising.sol";
import {VRFCoordinatorV2Mock} from "../libs/VRFCoordinatorV2Mock.sol";
import {ERC6551Registry} from "../libs/ERC6551Registry.sol";
import {AccountGuardian} from "../libs/AccountGuardian.sol";
import {BionicInvestorPass} from "../BIP.sol";
import {TokenBoundAccount, ECDSA} from "../TBA.sol";
import {ClaimFunding} from "./Claim.sol";
import {Bionic} from "../Bionic.sol";
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

        _claimContract = ClaimFunding(_bionicFundRaising.claimFund());

        _accountImplementation = new TokenBoundAccount(
            address(new AccountGuardian()),
            ENTRY_POINT
        );
    }

    function registerProject() public returns (uint256 pid) {
        uint32[] memory t = new uint32[](3);
        t[0] = 3;
        t[1] = 2;
        t[2] = 1;
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

        return pid;
    }

    function testAddProject() public {
        uint256 pid = registerProject();
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
        uint256 pid = registerProject();
        uint256 deadline = block.timestamp + 7 days;
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(privateKey);
        _bipContract.safeMint(user, "");
        address accountAddress = erc6551_Registry.createAccount(
            address(_accountImplementation),
            block.chainid,
            address(_bipContract),
            0,
            0,
            ""
        );
        uint256 amount = 1000;
        _investingToken.mint(accountAddress, amount ** 5);
        TokenBoundAccount acc = TokenBoundAccount(payable(accountAddress));
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

        vm.startPrank(user);

        bytes memory data = abi.encodeWithSelector(
            _bionicFundRaising.pledge.selector,
            pid,
            amount,
            deadline,
            v,
            r,
            s
        );
        acc.executeCall(address(_bionicFundRaising), 0, data);
        // _bionicContract.pledge(pid, amount, deadline, v, r, s).;
    }

    //   function testBatchClaim() public {
    //     // vm.warp(100);
    //     bionicContract.registerProjectToken(
    //       1,
    //       address(rewardToken),
    //       10,
    //       200,
    //       12 // a year
    //     );
    //     bionicContract.registerProjectToken(
    //       2,
    //       address(rewardToken2),
    //       20,
    //       400,
    //       6 //6 month
    //     );
    //     //Fund The Claiming Contract
    //     uint totalBalance=10000;
    //     rewardToken.mint(address(bionicContract), totalBalance);
    //     rewardToken2.mint(address(bionicContract), totalBalance);

    //     //add winners and send transactions as winner0
    //     bionicContract.addWinningInvestors(1,winners);
    //     bionicContract.addWinningInvestors(2,winners);
    //     vm.startPrank(winners[0]);

    //     vm.expectRevert(abi.encodePacked(ErrClaimingIsNotAllowedYet.selector, uint(200)));
    //     bionicContract.batchClaim();

    //     uint256 time=MONTH_IN_SECONDS*3;
    //     vm.warp(time);

    //     // vm.expectRevert(ErrNothingToClaim.selector);
    //     bionicContract.batchClaim();

    //     assertEq(rewardToken.balanceOf(address(bionicContract)), totalBalance-10*2);
    //     assertEq(rewardToken.balanceOf(address(winners[0])), 10*2);
    //     assertEq(rewardToken2.balanceOf(address(bionicContract)), totalBalance-20*2);
    //     assertEq(rewardToken2.balanceOf(address(winners[0])), 20*2);

    //   }
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
