// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
// import "hardhat/console.sol";

/* Errors */
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
error Raffle__TransferFailed();
error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleNotOpen();
error Raffle__NotEnoughRandomWordsForLottery();

/**@title A sample Raffle Contract
 * @author Patrick Collins
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */
contract Raffle is VRFConsumerBaseV2 /*, AutomationCompatibleInterface */ {
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
    RaffleState private s_raffleState; 
    /*solhint-enable var-name-mixedcase*/

    ///@notice requestId of vrf request on the pool
    mapping(uint256 => address[]) public requestIdToMembers;
    mapping(uint256 => uint256) public requestIdToWinnersCount;
    mapping(uint256 => address[]) public requestIdToLotteryWinners;

    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnersPicked(uint256 requestId, address[] winners);

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
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;//solhint-disable-line not-rely-on-time
        i_callbackGasLimit = callbackGasLimit;
        i_requestVRFPerWinner = requestVRFPerWinner;
    }

   
    
    /**
     * @dev it kicks off a Chainlink VRF call to get random winners.
     */
    function _draw(
        uint32 winnersCount,
        address[] memory members
    ) internal returns (uint requestId){
        s_raffleState = RaffleState.CALCULATING;
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            i_requestVRFPerWinner ? winnersCount : 1
        );
        requestIdToWinnersCount[requestId]=winnersCount;
        requestIdToMembers[requestId]=members;
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override{
        uint256 winnersCount=requestIdToWinnersCount[requestId];
        address[] memory lotteryMembers=requestIdToMembers[requestId];
        address[] storage lotteryWinners=requestIdToLotteryWinners[requestId];
        if(i_requestVRFPerWinner){
            if (randomWords.length!=winnersCount) 
                revert Raffle__NotEnoughRandomWordsForLottery();
            
            for (uint i=0;i<winnersCount;i++){
                uint256 indexOfWinner = randomWords[i] % lotteryMembers.length;
                lotteryWinners[i]=lotteryMembers[indexOfWinner];
            }
        }else{ //just get one word and calculate other random values off of it
            uint256 rand=randomWords[0];
            for (uint32 i=0;i<winnersCount;i++){
                lotteryWinners[i]=lotteryMembers[rand % lotteryMembers.length];
                rand=uint256(keccak256(abi.encodePacked(rand,block.prevrandao,block.chainid,i)));
            }
        }
        requestIdToLotteryWinners[requestId]=lotteryWinners;

        emit WinnersPicked(requestId, lotteryWinners);
    }

    /** Getter Functions */
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
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