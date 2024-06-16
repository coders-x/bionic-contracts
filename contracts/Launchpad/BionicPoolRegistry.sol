// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ICurrencyPermit, ICurrencyPermit__NoReason} from "../libs/ICurrencyPermit.sol";
import {BionicStructs} from "../libs/BionicStructs.sol";
import {BionicAccount} from "../BTBA.sol";

import {Treasury} from "./Treasury.sol";

// import "hardhat/console.sol";
// import "forge-std/console.sol";

/* Errors */
error BPR__NotDefinedError();
error BPR__PoolRaffleDisabled();
error BPR__InvalidPool();
error BPR__NotValidPledgeAmount(uint256 amount);
error BPR__InvalidStakingToken(); //"constructor: _investingToken must not be zero address"
error BPR__InvalidInvestingToken(); //"constructor: _investingToken must not be zero address"
error BPR__PledgeStartAndPledgeEndNotValid(); //"add: _pledgingStartTime should be before _pledgingEndTime"
error BPR__TargetToBeRaisedMustBeMoreThanZero();
error BPR__PledgingHasClosed();
error BPR__TargetRaisedHasSurpassed();
error BPR__NotEnoughStake();
error BPR__PledgingIsNotOpenYet(uint256 retryAgainAt);
error BPR__PoolIsOnPledgingPhase(uint256 retryAgainAt);
error BPR__DrawForThePoolHasAlreadyStarted(uint256 requestId);
error BPR__NotEnoughRandomWordsForLottery();
error BPR__FundingPledgeFailed(address user, uint256 pid);
error BPR__TierMembersShouldHaveAlreadyPledged(uint256 pid, uint256 tierId);
error BPR__TiersHaveNotBeenInitialized();
error BPR__AlreadyPledgedToThisPool();
error BPR__LotteryIsPending();

// ╭━━╮╭━━┳━━━┳━╮╱╭┳━━┳━━━╮
// ┃╭╮┃╰┫┣┫╭━╮┃┃╰╮┃┣┫┣┫╭━╮┃
// ┃╰╯╰╮┃┃┃┃╱┃┃╭╮╰╯┃┃┃┃┃╱╰╯
// ┃╭━╮┃┃┃┃┃╱┃┃┃╰╮┃┃┃┃┃┃╱╭╮
// ┃╰━╯┣┫┣┫╰━╯┃┃╱┃┃┣┫┣┫╰━╯┃
// ╰━━━┻━━┻━━━┻╯╱╰━┻━━┻━━━╯

/// @title Bionic Pool Registry Contract for Bionic DAO
/// @author Coders-x
/// @dev Only the owner can add new pools
contract BionicPoolRegistry is
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*///////////////////////////////////////////////////////////////
                                States
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant BROKER_ROLE = keccak256("BROKER_ROLE");
    bytes32 public constant SORTER_ROLE = keccak256("SORTER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY");

    /// @notice staking token is fixed for all pools
    IERC20 public stakingToken;
    /// @notice investing token is fixed for all pools (e.g. USDT)
    IERC20 public investingToken;
    /// @notice BIP Contract Address to allow owners to pledge and invest
    address public bionicInvestorPass;

    /// @notice Container for holding all rewards
    Treasury public treasury;
    uint256 public treasuryWithdrawable;

    /// @notice List of pools that users can stake into
    mapping(uint256 => BionicStructs.PoolInfo) public poolInfo;

    // Total amount pledged by users in a pool
    mapping(uint256 => uint256) public poolIdToTotalPledged;
    /// @notice Per pool, info of each user that stakes ERC20 tokens.
    /// @notice Pool ID => User Address => amount user has pledged
    mapping(uint256 => EnumerableMap.AddressToUintMap) internal userPledge; //todo maybe optimize it more
    ///@notice user's total pledge accross diffrent pools and programs.
    mapping(address => uint256) public userTotalPledge;
    ///@notice winners per raffle
    mapping(uint256 => EnumerableSet.AddressSet) internal poolLotteryWinners;

    ///@notice Mininmal amount of Bionic to be Staked on account required to pledge
    /// @custom:oz-renamed-from minimumBionicStack
    uint256 public minimumBionicStake;

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/
    event ContractDeployed(address indexed treasury);
    event PoolAdded(uint256 indexed pid);
    event Pledge(address indexed user, uint256 indexed pid, uint256 amount);
    event DrawInitiated(uint256 indexed pid, uint256 requestId);
    event PledgeFunded(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event LotteryRefunded(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event Invested(uint256 pid, address winner, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////*/

    /// @param _stakingToken Address of the staking token for all pools
    /// @param _investingToken Address of the invesment token for all pools
    function initialize(
        IERC20 _stakingToken,
        IERC20 _investingToken,
        address _bionicInvestorPass
    ) public initializer {
        if (address(_stakingToken) == address(0)) {
            revert BPR__InvalidStakingToken();
        }
        if (address(_investingToken) == address(0)) {
            revert BPR__InvalidInvestingToken();
        }
        if (address(_bionicInvestorPass) == address(0)) {
            revert BPR__InvalidInvestingToken();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        minimumBionicStake = 10e24; //1 BCNX
        bionicInvestorPass = _bionicInvestorPass;
        stakingToken = _stakingToken;
        investingToken = _investingToken;
        treasury = new Treasury(address(this));
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(BROKER_ROLE, _msgSender());
        _grantRole(TREASURY_ROLE, _msgSender());
        _grantRole(SORTER_ROLE, _msgSender());

        emit ContractDeployed(address(treasury));
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*///////////////////////////////////////////////////////////////
                        Public/External Functions
    //////////////////////////////////////////////////////////////*/
    /// @dev Can only be called by the contract owner
    function add(
        uint256 pid,
        uint256 _pledgingStartTime, // Pledging will be permitted since this date
        uint256 _pledgingEndTime, // Before this Time pledge is permitted
        uint256 _targetRaise, // Amount that the project wishes to raise
        bool _useRaffle,
        BionicStructs.PledgeTier[] memory _pledgeTiers
    ) external onlyRole(BROKER_ROLE) {
        if (_pledgingStartTime <= block.timestamp) {
            revert BPR__PledgeStartAndPledgeEndNotValid();
        }
        if (_pledgingStartTime >= _pledgingEndTime) {
            revert BPR__PledgeStartAndPledgeEndNotValid();
        }

        if (_targetRaise == 0) {
            revert BPR__TargetToBeRaisedMustBeMoreThanZero();
        }
        // if (poolInfo[pid].pledgingStartTime != 0) {
        //     revert BPR__InvalidPool();
        // }

        uint32 winnersCount = 0;
        BionicStructs.PoolInfo memory pool = BionicStructs.PoolInfo({
            pledgingStartTime: _pledgingStartTime,
            pledgingEndTime: _pledgingEndTime,
            targetRaise: _targetRaise,
            pledgeTiers: _pledgeTiers,
            winnersCount: winnersCount,
            isActive: true,
            useRaffle: _useRaffle
        });
        poolInfo[pid] = pool;

        emit PoolAdded(pid);
    }

    // step 1
    // @dev should first query the pleadged amount already and then try to sign amount+ alreadey_pledged permit to be used here
    function pledge(
        uint256 pid,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant onlyBionicAccount {
        BionicStructs.PoolInfo storage pool = poolInfo[pid];
        if (!pool.isActive || pool.targetRaise == 0) {
            revert BPR__InvalidPool();
        }
        if (block.timestamp < pool.pledgingStartTime) {
            // solhint-disable-line not-rely-on-time
            revert BPR__PledgingIsNotOpenYet(pool.pledgingStartTime);
        }
        if (block.timestamp > pool.pledgingEndTime) {
            // solhint-disable-line not-rely-on-time
            revert BPR__PledgingHasClosed();
        }
        (bool found, uint256 pledged) = userPledge[pid].tryGet(_msgSender());
        if (found || pledged != 0) {
            revert BPR__AlreadyPledgedToThisPool();
        }
        if (!_isValidPledge(pledged.add(amount), pool.pledgeTiers)) {
            revert BPR__NotValidPledgeAmount(amount);
        }
        if (IERC20(stakingToken).balanceOf(_msgSender()) < minimumBionicStake) {
            revert BPR__NotEnoughStake();
        }

        if (!userPledge[pid].set(_msgSender(), pledged.add(amount))) {
            revert();
        }
        userTotalPledge[_msgSender()] = userTotalPledge[_msgSender()].add(
            amount
        );

        poolIdToTotalPledged[pid] = poolIdToTotalPledged[pid].add(amount);
        if (!pool.useRaffle && pool.targetRaise <= poolIdToTotalPledged[pid]) {
            revert BPR__TargetRaisedHasSurpassed();
        }

        try
            ICurrencyPermit(_msgSender()).permit(
                address(investingToken),
                address(this),
                amount,
                deadline,
                v,
                r,
                s
            )
        {
            _stakePledge(_msgSender(), pid, amount);
            if (!pool.useRaffle && poolLotteryWinners[pid].add(_msgSender())) {
                treasuryWithdrawable += amount;
                emit Invested(pid, _msgSender(), amount);
            } else {
                emit Pledge(_msgSender(), pid, amount);
            }
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert ICurrencyPermit__NoReason();
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }
    function setMinimumBionicStake(
        uint256 _minimumBionicStake
    ) external onlyRole(BROKER_ROLE) {
        minimumBionicStake = _minimumBionicStake;
    }

    /**
     * @dev Withdraws a specified amount of tokens from the treasury to the specified address.
     * Only the address with the `TREASURY_ROLE` can call this function.
     * If the specified amount is greater than the available treasury withdrawable balance,
     * it reverts with a `BPR__NotEnoughStake` error.
     * @param to The address to which the tokens will be withdrawn.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(
        address to,
        uint256 amount
    ) external nonReentrant onlyRole(TREASURY_ROLE) {
        if (amount > treasuryWithdrawable) {
            revert BPR__NotEnoughStake();
        }
        treasuryWithdrawable -= amount;
        treasury.withdrawTo(investingToken, to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            Public/External View Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the number of pools that have been added by the owner
    /// @return Number of pools
    function pledgeTiers(
        uint256 poolId
    ) external view returns (BionicStructs.PledgeTier[] memory) {
        return poolInfo[poolId].pledgeTiers;
    }

    /// @notice Returns the number of pools that have been added by the owner
    /// @return Number of pools
    function userPledgeOnPool(
        uint256 poolId,
        address user
    ) external view returns (uint256) {
        return userPledge[poolId].get(user);
    }

    /// @notice Get Winners for a particular poolId
    /// @param pid id for the pool winners are requested from
    /// @return address[] array of winners for the raffle
    function getProjectInvestors(
        uint256 pid
    ) public view returns (uint256, address[] memory) {
        return (poolIdToTotalPledged[pid], poolLotteryWinners[pid].values());
    }

    /*///////////////////////////////////////////////////////////////
                        Private/Internal Functions
    //////////////////////////////////////////////////////////////*/

    function _isValidPledge(
        uint256 amount,
        BionicStructs.PledgeTier[] memory tiers
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < tiers.length; i++) {
            if (
                tiers[i].minimumPledge <= amount &&
                amount <= tiers[i].maximumPledge
            ) return true;
        }
        return false;
    }

    function _stakePledge(
        address account,
        uint256 pid,
        uint256 _amount
    ) private {
        try
            BionicAccount(payable(account)).transferCurrency(
                address(investingToken),
                address(treasury),
                _amount
            )
        returns (bool res) {
            if (res) emit PledgeFunded(account, pid, _amount);
            else revert BPR__FundingPledgeFailed(account, pid);
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert ICurrencyPermit__NoReason();
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    modifier onlyBionicAccount() virtual {
        // require(
        //     _msgSender().isContract() &&
        //     IERC165(_msgSender()).supportsInterface(
        //        type(IERC6551Account).interfaceId
        //     ),
        //     "Contract does not support BionicAccount"
        // );

        try BionicAccount(payable(_msgSender())).token() returns (
            uint256,
            address tokenContract,
            uint256
        ) {
            require(
                tokenContract == bionicInvestorPass,
                "onlyBionicAccount: Invalid Bionic BionicAccount."
            ); //check user realy ownes the bionic pass check we have minted and created account
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert BPR__NotDefinedError();
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }

        _;
    }

    /*///////////////////////////////////////////////////////////////
                            UPGRADABILITY
    //////////////////////////////////////////////////////////////*/
    // Upgradeability-related functions
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
