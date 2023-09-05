// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {BionicStructs} from "../libs/BionicStructs.sol";

// import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "hardhat/console.sol";

/* Errors */
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
error Raffle__TransferFailed();
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleAlreadyInProgressOrDone();
error Raffle__TierMembersCountInvalid(uint256 expectedMemberCount, uint256 receivedMemberCount);
error Raffle__NotEnoughRandomWordsForLottery();
error Raffle__MembersOnlyPermittedInOneTier(address member,uint256 existingTier, uint256 newTier);

/**@title A sample Raffle Contract
 * @author Ali Mahdavi
 * @notice This contract will do the raffles for lottary and keep track of the tiering system for that
 * @dev This implements the Chainlink VRF Version 2
 */
abstract contract Raffle is VRFConsumerBaseV2 /*, AutomationCompatibleInterface */ {
    /* Type declarations */
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
    bool private immutable i_requestVRFPerWinner; // whether should request diffrent random number per winner or just one and calculate all winners off of it.
    uint256 private s_lastTimeStamp;
    /*solhint-enable var-name-mixedcase*/

    ///@notice requestId of vrf request on the pool
    mapping(uint256 => RaffleState) public poolIdToRaffleStatus;

    ///@notice requestId of vrf request on the pool
    mapping(uint256 => uint256) public poolIdToRequestId;
    mapping(uint256 => uint256) public requestIdToPoolId;

    /// @notice poolId to Tiers information of the pool
    mapping(uint256 => BionicStructs.Tier[]) public poolIdToTiers;

    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event TierInitiated(uint256 pid,uint256 tierId, address[] members);
    event WinnersPicked(uint256 requestId,uint256 pid, address[] winners);

    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        bytes32 gasLane, // keyHash
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bool requestVRFPerWinner
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        s_lastTimeStamp = block.timestamp;//solhint-disable-line not-rely-on-time
        i_callbackGasLimit = callbackGasLimit;
        i_requestVRFPerWinner = requestVRFPerWinner;
    }

    function _addToTier(uint256 pid,uint256 tierId, address[] memory members) internal {
        //check if raffle is in valid state
        BionicStructs.Tier[] storage tiers=poolIdToTiers[pid];
        for (uint k = 0; k < tiers.length; k++) {
            for (uint i = 0; i < tiers[k].members.length; i++) {
                for (uint j=0;j<members.length;j++){
                    if (tiers[k].members[i]==members[j])
                        revert Raffle__MembersOnlyPermittedInOneTier(members[j],k,tierId);
                }
            }
        }
        tiers[tierId].members=members;

        emit TierInitiated(pid,tierId,members);
        // poolIdToTiers[pid][tierId]=tier;
    }

   
    
    /**
     * @dev it kicks off a Chainlink VRF call to get random winners.
     */
    function _draw(
        uint pid,
        uint32 winnersCount
    ) internal returns (uint requestId){
        if(poolIdToRequestId[pid]!=0){
            revert Raffle__RaffleAlreadyInProgressOrDone();
        }

        BionicStructs.Tier[] storage tiers=poolIdToTiers[pid];
        // s_raffleState = RaffleState.CALCULATING;
        // todo replace with poolIdToRaffleStatus
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            i_requestVRFPerWinner ? winnersCount : uint32(tiers.length)
        );



        poolIdToRequestId[pid]=requestId;
        requestIdToPoolId[requestId]=pid;
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function _fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal returns (address[] memory lotteryWinners){
        uint pid=requestIdToPoolId[requestId];
        BionicStructs.Tier[] storage tiers=poolIdToTiers[pid];
        // Initialize the lotteryWinners array with the correct length
        lotteryWinners = new address[](getRaffleTotalWinners(pid));
        if(i_requestVRFPerWinner){
            uint wordIdx=0;
            for (uint i = 0; i < tiers.length; i++) {
                address[] memory lotteryMembers=tiers[i].members;
                for (uint j = 0; j < tiers[i].count; j++) {
                    lotteryWinners[wordIdx]=lotteryMembers[randomWords[wordIdx] % lotteryMembers.length];
                    wordIdx++;
                }
            }
        }else{
            for (uint i = 0; i < tiers.length; i++) {
                uint256 rand=randomWords[i];
                for (uint j = 0; j < tiers[i].count; j++) {
                    address[] memory lotteryMembers=tiers[i].members;
                    lotteryWinners[i]=lotteryMembers[rand % lotteryMembers.length];
                    rand=uint256(keccak256(abi.encodePacked(rand,block.prevrandao,block.chainid,i)));
                }
            }
        }

        emit WinnersPicked(requestId,pid, lotteryWinners);
        return lotteryWinners;
    }

    // /** Getter Functions */
    // function getRaffleState(pid) public view returns (RaffleState) {
    //     return s_raffleState;
    // }

    // /** Getter Functions */
    // Calculate the total number of winners to determine the length of the lotteryWinners array
    function getRaffleTotalWinners(uint pid) public view returns (uint32 totalWinners) {
        BionicStructs.Tier[] storage tiers=poolIdToTiers[pid];
        for (uint i = 0; i < tiers.length; i++) {
            totalWinners += tiers[i].count;
        }
    }


    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }


    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}





    // /**
    //  * @dev This is the function that the Chainlink Keeper nodes call
    //  * they look for `upkeepNeeded` to return True.
    //  * the following should be true for this to return true:
    //  * 1. The time interval has passed between raffle runs.
    //  * 2. The lottery is open.
    //  * 3. The contract has ETH.
    //  * 4. Implicity, your subscription is funded with LINK.
    //  */
    // function checkUpkeep(
    //     bytes memory /* checkData */
    // )
    //     public
    //     view
    //     override
    //     returns (
    //         bool upkeepNeeded,
    //         bytes memory /* performData */
    //     )
    // {
    //     bool isOpen = RaffleState.OPEN == s_raffleState;
    //     bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
    //     bool hasPlayers = s_players.length > 0;
    //     bool hasBalance = address(this).balance > 0;
    //     upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
    //     return (upkeepNeeded, "0x0"); // can we comment this out?
    // }

    // /**
    //  * @dev Once `checkUpkeep` is returning `true`, this function is called
    //  * and it kicks off a Chainlink VRF call to get a random winner.
    //  */
    // function performUpkeep(
    //     bytes calldata /* performData */
    // ) external override {
    //     (bool upkeepNeeded, ) = checkUpkeep("");
    //     // require(upkeepNeeded, "Upkeep not needed");
    //     if (!upkeepNeeded) {
    //         revert Raffle__UpkeepNotNeeded(
    //             address(this).balance,
    //             s_players.length,
    //             uint256(s_raffleState)
    //         );
    //     }
    //     s_raffleState = RaffleState.CALCULATING;
    //     uint256 requestId = i_vrfCoordinator.requestRandomWords(
    //         i_gasLane,
    //         i_subscriptionId,
    //         REQUEST_CONFIRMATIONS,
    //         i_callbackGasLimit,
    //         i_winnersCount
    //     );
    //     emit RequestedRaffleWinner(requestId);
    // } 