// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import { BionicStructs } from "../libs/BionicStructs.sol";
import "hardhat/console.sol";

/* Errors */
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
error Raffle__TransferFailed();
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleAlreadyInProgressOrDone();
error Raffle__TierMembersCountInvalid(uint256 expectedMemberCount, uint256 receivedMemberCount);
error Raffle__NotEnoughRandomWordsForLottery();
error Raffle__MembersOnlyPermittedInOneTier(address member, uint256 existingTier, uint256 newTier);

/** @title A sample Raffle Contract
 *  @author Ali Mahdavi
 *  @notice This contract performs raffles for a lottery and keeps track of the tiering system.
 *  @dev This contract implements Chainlink VRF Version 2.
 */
abstract contract Raffle is VRFConsumerBaseV2 {
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    /*solhint-disable var-name-mixedcase*/
    /* State variables */
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    // Lottery Variables
    bool private immutable i_requestVRFPerWinner;

    ///@notice winners per raffle
    mapping(uint256 => address[]) public poolTolotteryWinners;
    ///@notice requestId of vrf request on the pool
    mapping(uint256 => uint256) public poolIdToRequestId;
    mapping(uint256 => uint256) public requestIdToPoolId;
    /// @notice poolId to Tiers information of the pool
    mapping(uint256 => BionicStructs.Tier[]) public poolIdToTiers;


    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event TierInitiated(uint256 pid, uint256 tierId, address[] members);
    event WinnersPicked(uint256 pid, address[] winners);


    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bool requestVRFPerWinner
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_requestVRFPerWinner = requestVRFPerWinner;
    }

    function _addToTier(uint256 pid, uint256 tierId, address[] memory members) internal {
        BionicStructs.Tier[] storage tiers = poolIdToTiers[pid];

        for (uint k = 0; k < tiers.length; k++) {
            for (uint i = 0; i < tiers[k].members.length; i++) {
                for (uint j = 0; j < members.length; j++) {
                    if (tiers[k].members[i] == members[j]) {
                        revert Raffle__MembersOnlyPermittedInOneTier(members[j], k, tierId);
                    }
                }
            }
        }

        tiers[tierId].members = members;
        emit TierInitiated(pid, tierId, members);
    }

    function _draw(uint pid, uint32 winnersCount) internal returns (uint requestId) {
        if (poolIdToRequestId[pid] != 0) {
            revert Raffle__RaffleAlreadyInProgressOrDone();
        }
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            i_requestVRFPerWinner ? winnersCount : uint32(poolIdToTiers[pid].length)
        );

        poolIdToRequestId[pid] = requestId;
        requestIdToPoolId[requestId] = pid;
        emit RequestedRaffleWinner(requestId);
    }
    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function _fulfillRandomWords(uint256 pid, uint256[] memory randomWords) internal returns (address[] memory winners) {
        BionicStructs.Tier[] memory tiers = poolIdToTiers[pid];
        uint totalWinners = getRaffleTotalWinners(pid);
        winners = new address[](totalWinners);
        uint winnerId = 0;

        if (i_requestVRFPerWinner) {
            for (uint i = 0; i < tiers.length; i++) {
                address[] memory lotteryMembers = tiers[i].members;
                uint memberCount = lotteryMembers.length;

                for (uint j = 0; j < tiers[i].count; j++) {
                    winners[winnerId] = lotteryMembers[randomWords[winnerId] % memberCount];
                    winnerId++;
                }
            }
        } else {
            for (uint i = 0; i < tiers.length; i++) {
                uint256 rand = randomWords[i];
                address[] memory lotteryMembers = tiers[i].members;
                uint memberCount = lotteryMembers.length;

                for (uint j = 0; j < tiers[i].count; j++) {
                    winners[winnerId] = lotteryMembers[rand % memberCount];
                    rand = uint256(keccak256(abi.encodePacked(rand, block.prevrandao, block.chainid, i)));
                    winnerId++;
                }
            }
        }

        emit WinnersPicked(pid, winners);
        return winners;
    }

    // /** Getter Functions */

    // Calculate the total number of winners to determine the length of the lotteryWinners array

    function getRaffleTotalWinners(uint pid) public view returns (uint32 totalWinners) {
        BionicStructs.Tier[] storage tiers = poolIdToTiers[pid];
        for (uint i = 0; i < tiers.length; i++) {
            totalWinners += tiers[i].count;
        }
    }
}
