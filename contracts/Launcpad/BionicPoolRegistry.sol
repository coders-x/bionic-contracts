// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {SafeERC20, IERC20, Address} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ICurrencyPermit, ICurrencyPermit__NoReason} from "../libs/ICurrencyPermit.sol";
import {BionicStructs} from "../libs/BionicStructs.sol";
import {BionicAccount} from "../BTBA.sol";

import {Treasury} from "./Treasury.sol";
import {Raffle} from "./Raffle.sol";

// import "hardhat/console.sol";
// import "forge-std/console.sol";

/* Errors */
error BPR__NotDefinedError();
error BPR__PoolRaffleDisabled();
error BPR__InvalidPool();
error BPR__NotValidPledgeAmount(uint amount);
error BPR__InvalidRewardToken(); //"constructor: _stakingToken must not be zero address"
error BPR__InvalidStackingToken(); //"constructor: _investingToken must not be zero address"
error BPR__InvalidInvestingToken(); //"constructor: _investingToken must not be zero address"
error BPR__PledgeStartAndPledgeEndNotValid(); //"add: _pledgingStartTime should be before _pledgingEndTime"
error BPR__AllocationShouldBeAfterPledgingEnd(); //"add: _tokenAllocationStartTime must be after pledging end"
error BPR__TargetToBeRaisedMustBeMoreThanZero();
error BPR__PledgingHasClosed();
error BPR__NotEnoughStake();
error BPR__PoolIsOnPledgingPhase(uint retryAgainAt);
error BPR__DrawForThePoolHasAlreadyStarted(uint requestId);
error BPR__NotEnoughRandomWordsForLottery();
error BPR__FundingPledgeFailed(address user, uint pid);
error BPR__TierMembersShouldHaveAlreadyPledged(uint pid, uint tierId);
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
contract BionicPoolRegistry is ReentrancyGuard, Raffle, AccessControl {
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
    uint256 public constant MINIMUM_BIONIC_STAKE = 10e18;

    /// @notice staking token is fixed for all pools
    IERC20 public stakingToken;
    /// @notice investing token is fixed for all pools (e.g. USDT)
    IERC20 public investingToken;
    /// @notice investing token is fixed for all pools (e.g. USDT)
    address public bionicInvestorPass;

    /// @notice Container for holding all rewards
    Treasury public treasury;


    /// @notice List of pools that users can stake into
    mapping(uint256 => BionicStructs.PoolInfo) public poolInfo;

    // Pool to accumulated share counters
    mapping(uint256 => uint256) public poolIdToLastPercentageAllocTime;
    // Total amount staked into the pool
    mapping(uint256 => uint256) public poolIdToTotalStaked;
    /// @notice Per pool, info of each user that stakes ERC20 tokens.
    /// @notice Pool ID => User Address => User Info
    mapping(uint256 => EnumerableMap.AddressToUintMap) internal userPledge; //todo maybe optimize it more
    ///@notice user's total pledge accross diffrent pools and programs.
    mapping(address => uint256) public userTotalPledge;

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
    event Invested(uint256 pid, address winner);

    /*///////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////*/
    /// @param _stakingToken Address of the staking token for all pools
    /// @param _investingToken Address of the staking token for all pools
    constructor(
        IERC20 _stakingToken,
        IERC20 _investingToken,
        address _bionicInvestorPass,
        address vrfCoordinatorV2,
        bytes32 gasLane, // keyHash
        uint64 subscriptionId,
        bool requestVRFPerWinner
    ) Raffle(vrfCoordinatorV2, gasLane, subscriptionId, requestVRFPerWinner) {
        if (address(_stakingToken) == address(0)) {
            revert BPR__InvalidRewardToken();
        }
        if (address(_investingToken) == address(0)) {
            revert BPR__InvalidStackingToken();
        }
        if (address(_bionicInvestorPass) == address(0)) {
            revert BPR__InvalidInvestingToken();
        }

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

    /*///////////////////////////////////////////////////////////////
                        Public/External Functions
    //////////////////////////////////////////////////////////////*/
    /// @dev Can only be called by the contract owner
    function add(
        uint256 pid,
        IERC20 _rewardToken, // Address of the reward token contract.
        uint256 _pledgingStartTime, // Pledging will be permitted since this date
        uint256 _pledgingEndTime, // Before this Time pledge is permitted
        uint256 _tokenAllocationPerMonth, // the total amount of token will be released to lottery winners per month
        uint256 _tokenAllocationStartTime, // when users can start claiming their first reward
        uint256 _tokenAllocationMonthCount, // amount of token will be allocated per investers share(usdt) per month.
        uint256 _targetRaise, // Amount that the project wishes to raise
        bool _useRaffle,
        uint32[] calldata _tiers,
        BionicStructs.PledgeTier[] memory _pledgeTiers
    ) external onlyRole(BROKER_ROLE) {
        address rewardTokenAddress = address(_rewardToken);
        if (rewardTokenAddress == address(0)) {
            revert BPR__InvalidRewardToken();
        }
        if (_pledgingStartTime >= _pledgingEndTime) {
            revert BPR__PledgeStartAndPledgeEndNotValid();
        }
        if (_tokenAllocationStartTime <= _pledgingEndTime) {
            revert BPR__AllocationShouldBeAfterPledgingEnd();
        }

        if (_targetRaise == 0) {
            revert BPR__TargetToBeRaisedMustBeMoreThanZero();
        }

        uint32 winnersCount = 0;
        BionicStructs.Tier[] memory tiers = new BionicStructs.Tier[](
            _tiers.length
        );
        for (uint i = 0; i < _tiers.length; i++) {
            tiers[i] = BionicStructs.Tier({
                count: _tiers[i],
                members: new address[](0)
            });
            winnersCount += _tiers[i];
        }
        BionicStructs.PoolInfo memory pool = BionicStructs.PoolInfo({
            rewardToken: _rewardToken,
            pledgingStartTime: _pledgingStartTime,
            pledgingEndTime: _pledgingEndTime,
            // pledgingAmountPerUser: _pledgingAmountPerUser,
            tokenAllocationPerMonth: _tokenAllocationPerMonth,
            tokenAllocationStartTime: _tokenAllocationStartTime,
            tokenAllocationMonthCount: _tokenAllocationMonthCount,
            targetRaise: _targetRaise,
            pledgeTiers: _pledgeTiers,
            winnersCount: winnersCount,
            useRaffle: _useRaffle
        });
        poolInfo[pid] = pool;

        poolIdToTiers[pid] = tiers;


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
        if (pool.targetRaise == 0) {
            revert BPR__InvalidPool();
        }
        (, uint256 pledged) = userPledge[pid].tryGet(_msgSender());
        if (pledged != 0) {
            revert BPR__AlreadyPledgedToThisPool();
        }
        if (!_isValidPledge(pledged.add(amount), pool.pledgeTiers)) {
            revert BPR__NotValidPledgeAmount(amount);
        }
        if (
            IERC20(stakingToken).balanceOf(_msgSender()) < MINIMUM_BIONIC_STAKE
        ) {
            revert BPR__NotEnoughStake();
        }
        if (block.timestamp > pool.pledgingEndTime) {
            // solhint-disable-line not-rely-on-time
            revert BPR__PledgingHasClosed();
        }

        userPledge[pid].set(_msgSender(), pledged.add(amount));
        userTotalPledge[_msgSender()] = userTotalPledge[_msgSender()].add(
            amount
        );

        poolIdToTotalStaked[pid] = poolIdToTotalStaked[pid].add(amount);

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
            emit Pledge(_msgSender(), pid, amount);
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
        _stackPledge(_msgSender(), pid, amount);
        if (!pool.useRaffle) {
            poolLotteryWinners[pid].add(_msgSender());
            emit Invested(pid, _msgSender());
        }
    }

    /// @notice Add user members to Lottery Tiers
    /// @dev Will need to happen before initiating the raffle it self
    /// @param pid the poolId of the tier
    /// @param tierId tierId of the poolId needs to be updated
    /// @param members members for this tier to be considered in raffle
    function addToTier(
        uint256 pid,
        uint256 tierId,
        address[] memory members
    ) external nonReentrant onlyRole(SORTER_ROLE) {
        if (poolInfo[pid].useRaffle) {
            for (uint i = 0; i < members.length; i++) {
                if (!userPledge[pid].contains(members[i])) {
                    revert BPR__TierMembersShouldHaveAlreadyPledged(
                        pid,
                        tierId
                    );
                }
            }

            _addToTier(pid, tierId, members);
        } else {
            revert BPR__PoolRaffleDisabled();
        }
    }

    /**
     * @dev will get the money out of users wallet into investment wallet
     */
    function draw(
        uint256 pid,
        uint32 callbackGasPerUser
    )
        external
        payable
        nonReentrant
        onlyRole(SORTER_ROLE)
        returns (uint requestId)
    {
        BionicStructs.PoolInfo memory pool = poolInfo[pid];
        if (pool.targetRaise == 0) {
            revert BPR__InvalidPool();
        }
        if (!pool.useRaffle) revert BPR__PoolRaffleDisabled();
        //solhint-disable-next-line not-rely-on-time
        if (pool.pledgingEndTime > block.timestamp)
            revert BPR__PoolIsOnPledgingPhase(pool.pledgingEndTime);
        if (poolIdToRequestId[pid] != 0)
            revert BPR__DrawForThePoolHasAlreadyStarted(
                poolIdToRequestId[pid]
            );

        _preDraw(pid);

        requestId = _draw(pid, pool.winnersCount, callbackGasPerUser);

        emit DrawInitiated(pid, requestId);
    }

    // /// @notice Returns the number of pools that have been added by the owner
    // /// @return Number of pools
    // function numberOfPools() external view returns (uint256) {
    //     return poolInfo.length;
    // }

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

    /*///////////////////////////////////////////////////////////////
                            Public/External Functions
    //////////////////////////////////////////////////////////////*/
    /// @notice Get Winners for a particular poolId
    /// @param pid id for the pool winners are requested from
    /// @return address[] array of winners for the raffle
    function getProjectInvestors(
        uint pid
    ) public view returns (uint256, address[] memory) {
        return (poolIdToTotalStaked[pid], poolLotteryWinners[pid].values());
    }

    /*///////////////////////////////////////////////////////////////
                        Private/Internal Functions
    //////////////////////////////////////////////////////////////*/

    function _isValidPledge(
        uint256 amount,
        BionicStructs.PledgeTier[] memory tiers
    ) internal pure returns (bool) {
        for (uint i = 0; i < tiers.length; i++) {
            if (
                tiers[i].minimumPledge <= amount &&
                amount <= tiers[i].maximumPledge
            ) return true;
        }
        return false;
    }

    /**
     * @dev will do the finall checks on the tiers and init the last tier if not set already by admin to rest of pledged users.
     */
    function _preDraw(uint256 pid) internal {
        if (poolInfo[pid].useRaffle) {
            BionicStructs.Tier[] storage tiers = poolIdToTiers[pid];
            //check if last tier is empty add rest of people pledged to the tier
            if (tiers[tiers.length - 1].members.length < 1) {
                //check all tiers except last(all other users) has members
                address[] memory lastTierMembers = userPledge[pid].keys();
                for (uint k = 0; k < tiers.length - 1; k++) {
                    if (tiers[k].members.length < 1) {
                        revert BPR__TiersHaveNotBeenInitialized();
                    }
                    lastTierMembers = excludeAddresses(
                        lastTierMembers,
                        tiers[k].members
                    );
                }

                _addToTier(pid, tiers.length - 1, lastTierMembers);
            }
        }
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint pid = requestIdToPoolId[requestId];
        _pickWinners(pid, randomWords);
    }

    function refundLosers(uint256 pid) external {
        address[] memory winners = poolLotteryWinners[pid].values();
        if (winners.length == 0) {
            revert BPR__LotteryIsPending();
        }
        ///@dev find losers and refund them their pledge.
        ///@notice post lottery refund non-winners
        ///@audit-info gas maybe for gasoptimization move it to dedicated function
        address[] memory losers = userPledge[pid].keys();
        losers = excludeAddresses(losers, winners);
        for (uint i = 0; i < losers.length; i++) {
            uint256 refund = userPledge[pid].get(losers[i]);
            treasury.withdrawTo(investingToken, losers[i], refund);
            emit LotteryRefunded(losers[i], pid, refund);
            userPledge[pid].set(losers[i], 0);
        }
    }

    function _stackPledge(
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

    function excludeAddresses(
        address[] memory array1,
        address[] memory array2
    ) private pure returns (address[] memory) {
        // Store addresses from array1 that are not in array2
        address[] memory exclusionArray = new address[](array1.length);
        uint count = 0;

        for (uint i = 0; i < array1.length; i++) {
            address element = array1[i];
            bool found = false;
            for (uint j = 0; j < array2.length; j++) {
                if (element == array2[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                exclusionArray[count] = element;
                count++;
            }
        }

        // Copy exclusionArray into new array of correct length
        address[] memory result = new address[](count);
        for (uint i = 0; i < count; i++) {
            result[i] = exclusionArray[i];
        }

        return result;
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
}
