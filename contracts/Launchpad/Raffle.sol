// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BionicStructs} from "../libs/BionicStructs.sol";
import {VRFConsumerBaseV2Upgradeable} from "../libs/VRFConsumerBaseV2Upgradable.sol";

/* Errors */
error Raffle__TransferFailed();
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleAlreadyInProgressOrDone();
error Raffle__TierMembersCountInvalid(
    uint256 expectedMemberCount,
    uint256 receivedMemberCount
);
error Raffle__NotEnoughRandomWordsForLottery();
error Raffle__MembersOnlyPermittedInOneTier(
    address member,
    uint256 existingTier,
    uint256 newTier
);

/** @title A sample Raffle Contract
 *  @author Ali Mahdavi
 *  @notice This contract performs raffles for a lottery and keeps track of the tiering system.
 *  @dev This contract implements Chainlink VRF Version 2.
 */
///@custom:oz-upgrades-unsafe-allow state-variable-immutable
abstract contract Raffle is Initializable, VRFConsumerBaseV2Upgradeable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum RaffleState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    /*solhint-disable var-name-mixedcase*/
    /* State variables */
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private _vrfCoordinator;
    uint64 private _subscriptionId;
    bytes32 private _gasLane;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // Lottery Variables
    bool private _requestVRFPerWinner;

    ///@notice requestId of vrf request on the pool
    mapping(uint256 => uint256) public poolIdToRequestId;
    mapping(uint256 => uint256) public requestIdToPoolId;
    /// @notice poolId to Tiers information of the pool
    mapping(uint256 => BionicStructs.Tier[]) public poolIdToTiers;

    ///@notice winners per raffle
    mapping(uint256 => EnumerableSet.AddressSet) internal poolLotteryWinners;

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event TierInitiated(uint256 pid, uint256 tierId, address[] members);
    event WinnersPicked(uint256 pid, address[] winners);

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Sets the values for {vrfCorrdinator}, {gasLane}, {subId}, and {perWinnerRequest}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __Raffle_init(
        address vrfCoordinatorV2_,
        bytes32 gasLane_,
        uint64 subscriptionId_,
        bool requestVRFPerWinner_
    ) internal onlyInitializing {
        __Raffle_init_unchained(
            vrfCoordinatorV2_,
            gasLane_,
            subscriptionId_,
            requestVRFPerWinner_
        );
    }

    function __Raffle_init_unchained(
        address vrfCoordinatorV2_,
        bytes32 gasLane_,
        uint64 subscriptionId_,
        bool requestVRFPerWinner_
    ) internal onlyInitializing {
        __VRFConsumerBaseV2Upgradeable_init(vrfCoordinatorV2_);
        _vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2_);
        _gasLane = gasLane_;
        _subscriptionId = subscriptionId_;
        _requestVRFPerWinner = requestVRFPerWinner_;
    }

    /*///////////////////////////////////////////////////////////////
                            Public/External Functions
    //////////////////////////////////////////////////////////////*/
    /// @notice Get Winners for a particular poolId
    /// @param pid id for the pool winners are requested from
    /// @return address[] array of winners for the raffle
    function getRaffleWinners(
        uint pid
    ) external view returns (address[] memory) {
        return poolLotteryWinners[pid].values();
    }

    /*///////////////////////////////////////////////////////////////
                        Private/Internal Functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Add Users who pledged to their tiers for the raffle
    /// @param pid PoolId for the raffle
    /// @param tierId id of tier user will be belong to
    /// @param members members for this tier (they must have pledged and don't be a member of pervous tiers).
    function _addToTier(
        uint256 pid,
        uint256 tierId,
        address[] memory members
    ) internal {
        BionicStructs.Tier[] storage tiers = poolIdToTiers[pid];

        for (uint k = 0; k < tiers.length; k++) {
            for (uint i = 0; i < tiers[k].members.length; i++) {
                for (uint j = 0; j < members.length; j++) {
                    if (tiers[k].members[i] == members[j]) {
                        revert Raffle__MembersOnlyPermittedInOneTier(
                            members[j],
                            k,
                            tierId
                        );
                    }
                }
            }
        }

        tiers[tierId].members = members;
        emit TierInitiated(pid, tierId, members);
    }

    /// @dev Request randomw words from VRF to perform raffle
    /// @param pid PoolId for the Raffle to be performed on
    /// @param winnersCount total count of winners for this pool, (sum of all tiers winners count).
    /// @param callbackGasPerUser gas limit per winner for the VRF callback
    /// @return requestId for the VRF Requested.
    function _draw(
        uint pid,
        uint32 winnersCount,
        uint32 callbackGasPerUser
    ) internal returns (uint requestId) {
        if (poolIdToRequestId[pid] != 0) {
            revert Raffle__RaffleAlreadyInProgressOrDone();
        }
        requestId = _vrfCoordinator.requestRandomWords(
            _gasLane,
            _subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasPerUser * winnersCount,
            _requestVRFPerWinner
                ? winnersCount
                : uint32(poolIdToTiers[pid].length)
        );

        poolIdToRequestId[pid] = requestId;
        requestIdToPoolId[requestId] = pid;
        emit RequestedRaffleWinner(requestId);
    }

    /// @dev This is the function in charge of actual raffle after recieving vrf random words
    /// @param pid pool Id for the raffle
    /// @param randomWords array of random words that will be used to pick the numbers
    /// @return winners address[] the return variables of a contract’s function state variable
    function _pickWinners(
        uint256 pid,
        uint256[] memory randomWords
    ) internal returns (address[] memory) {
        BionicStructs.Tier[] memory tiers = poolIdToTiers[pid];
        for (uint i = 0; i < tiers.length; i++) {
            uint256 rand = randomWords[i];
            address[] memory tierMembers = tiers[i].members;
            uint memberCount = tierMembers.length;
            for (uint j = 0; j < tiers[i].count; ) {
                if (_requestVRFPerWinner) {
                    rand = randomWords[poolLotteryWinners[pid].length()];
                } else {
                    rand = uint256(
                        keccak256(
                            abi.encodePacked(
                                rand,
                                block.prevrandao,
                                block.chainid,
                                i
                            )
                        )
                    );
                }
                address w = tierMembers[rand % memberCount];
                if (poolLotteryWinners[pid].contains(w)) {
                    continue;
                }
                poolLotteryWinners[pid].add(w);
                j++;
            }
        }

        emit WinnersPicked(pid, poolLotteryWinners[pid].values());
        return poolLotteryWinners[pid].values();
    }

    /*///////////////////////////////////////////////////////////////
                            
    //////////////////////////////////////////////////////////////*/
}
