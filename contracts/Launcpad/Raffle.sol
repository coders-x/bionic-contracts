// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {BionicStructs} from "../libs/BionicStructs.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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
abstract contract Raffle is VRFConsumerBaseV2 {
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
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // Lottery Variables
    bool private immutable i_requestVRFPerWinner;

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
    constructor(
        address vrfCoordinatorV2,
        bytes32 gasLane,
        uint64 subscriptionId,
        bool requestVRFPerWinner
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_requestVRFPerWinner = requestVRFPerWinner;
    }

    /*///////////////////////////////////////////////////////////////
                            Public/External Functions
    //////////////////////////////////////////////////////////////*/
    /// @notice Get Winners for a particular poolId
    /// @param pid id for the pool winners are requested from
    /// @return address[] array of winners for the raffle
    function getRaffleWinners(uint pid) public view returns (address[] memory) {
        return poolLotteryWinners[pid].values();
    }

    /*///////////////////////////////////////////////////////////////
                        Private/Internal Functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Add Users who pledged to their tiers for the raffle
    /// @param pid PoolId for the raffle
    /// @param tierId id of tier user will be belong to
    /// @param newMember address of the user
    function __addTierMember(
        uint256 pid,
        uint256 tierId,
        address newMember
    ) private {
        require(
            BionicStructs.poolIdToTiers[pid].length > tierId,
            "Invalid Tier Id"
        );
        uint256 tierIndex = tierId;
        require(
            !EnumerableSet.contains(
                BionicStructs.poolIdToTiers[pid][tierIndex].tierMembers,
                newMember
            ),
            "Address already part of the Tier"
        );
        EnumerableSet.add(
            BionicStructs.poolIdToTiers[pid][tierIndex].tierMembers,
            newMember
        );
        emit RaffleEnter(newMember);
    }

    /// @dev Function to check if members belong to only one tier for raffle
    /// @param poolId poolId for raffle
    /// @param newTier TierId user wants to belong to
    function __checkIfMembersBelongsToOneTier(
        uint256 poolId,
        uint256 newTier,
        address newMember
    ) private {
        for (uint256 tierIndex = 0; tierIndex < newTier; tierIndex++) {
            require(
                !EnumerableSet.contains(
                    BionicStructs.poolIdToTiers[poolId][tierIndex]
                        .tierMembers,
                    newMember
                ),
                "Address already part of another Tier"
            );
        }
    }

    /// @dev This function is used to Initiate Tier at the time of pledging
    /// @param pid PoolId for the raffle
    /// @param tierId id of tier user will be belong to
    /// @param numberOfMembers address of the user
    function __initiateTier(
        uint256 pid,
        uint256 tierId,
        uint256 numberOfMembers,
        uint256 winningMemberCount
    ) private {
        require(
            BionicStructs.poolIdToTiers[pid].length > tierId,
            "Invalid Tier Id"
        );
        uint256 tierIndex = tierId;
        EnumerableSet.AddressSet storage tierMembers =
            BionicStructs.poolIdToTiers[pid][tierIndex].tierMembers;
        for (uint256 i = 0; i < numberOfMembers; i++) {
            tierMembers.add(msg.sender);
            emit RaffleEnter(msg.sender);
            if (tierMembers.length() == winningMemberCount) {
                __requestRaffleWinner(pid);
            }
        }
        emit TierInitiated(pid, tierId, tierMembers.values());
    }

    /// @dev This function is used to request raffle winner
    /// @param pid PoolId for the raffle
    function __requestRaffleWinner(uint256 pid) internal {
        uint256 seed = __getRandomSeed(pid);
        // Sends a request to Chainlink VRF Coordinator to get a random number
        uint256 requestId = i_vrfCoordinator.requestRandomWords(i_gasLane, seed, REQUEST_CONFIRMATIONS);
        poolIdToRequestId[pid] = requestId;
        requestIdToPoolId[requestId] = pid;
        emit RequestedRaffleWinner(requestId);
    }

    /// @dev Get Random Seed for Chainlink VRF Request
    /// @param pid PoolId for the raffle
    /// @return uint256 Random seed
    function __getRandomSeed(uint256 pid) internal view returns (uint256) {
        // Use poolId and the current block details as a seed for randomness
        uint256 seed =
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        block.timestamp,
                        pid
                    )
                )
            );
        return seed;
    }

    /// @dev Function to calculate winners
    /// @param pid PoolId for the raffle
    /// @param tierId id of tier user will be belong to
    /// @param numberOfMembers number of members in the tier
    function __calculateRaffleWinners(
        uint256 pid,
        uint256 tierId,
        uint256 numberOfMembers
    ) internal {
        require(
            BionicStructs.poolIdToTiers[pid].length > tierId,
            "Invalid Tier Id"
        );
        uint256 tierIndex = tierId;
        EnumerableSet.AddressSet storage tierMembers =
            BionicStructs.poolIdToTiers[pid][tierIndex].tierMembers;
        uint256 totalMembers = tierMembers.length();
        uint256 winnersCount = BionicStructs.poolInfo[pid].winnersCount;
        require(
            winnersCount <= numberOfMembers && winnersCount <= totalMembers,
            "Winners count cannot be more than total members count"
        );

        address[] memory winners = new address[](winnersCount);

        for (uint256 i = 0; i < winnersCount; i++) {
            winners[i] = tierMembers.at(i);
        }

        emit WinnersPicked(pid, winners);
        // Store the winners for the raffle
        for (uint256 i = 0; i < winnersCount; i++) {
            EnumerableSet.add(poolLotteryWinners[pid], winners[i]);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Chainlink VRF Callbacks
    //////////////////////////////////////////////////////////////*/

    /** @dev Callback function called by VRF Coordinator when random words are generated.
     *  @param requestId Id of the VRF request
     *  @param randomWords The random words generated by Chainlink VRF
     */
    function __fulfillRandomness(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 pid = requestIdToPoolId[requestId];
        uint256 tierId = __getTierIdForRequest(requestId, pid);
        uint256 numberOfMembers = BionicStructs.poolIdToTiers[pid][tierId]
            .tierMembers
            .length();

        if (randomWords.length < numberOfMembers) {
            revert Raffle__NotEnoughRandomWordsForLottery();
        }

        // Calculate winners
        __calculateRaffleWinners(pid, tierId, numberOfMembers);

        // If requestVRFPerWinner is true, initiate the next raffle for the same pool
        if (i_requestVRFPerWinner) {
            __requestRaffleWinner(pid);
        }
    }

    /** @dev Function to get TierId for the given request.
     *  It uses the requestId and the number of tiers to calculate the TierId.
     *  @param requestId Id of the VRF request
     *  @param pid Id of the pool
     *  @return uint256 TierId for the request
     */
    function __getTierIdForRequest(uint256 requestId, uint256 pid) internal view returns (uint256) {
        return (requestId % BionicStructs.poolIdToTiers[pid].length);
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    modifier __onlyValidTierMembers(
        uint256 pid,
        uint256 tierId,
        address[] memory members
    ) {
        // Check that the correct number of members are provided
        require(
            BionicStructs.poolIdToTiers[pid][tierId].tierMembers.length() ==
                members.length,
            "Raffle__TierMembersCountInvalid"
        );

        // Check that each member
