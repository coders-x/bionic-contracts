// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {SafeERC20,IERC20,Address} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl,IERC165} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC6551Account} from "erc6551/src/interfaces/IERC6551Account.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";


import {ICurrencyPermit,ICurrencyPermit__NoReason} from "../libs/ICurrencyPermit.sol";
import {BionicStructs} from "../libs/BionicStructs.sol";
import {Utils} from "../libs/Utils.sol";
import {TokenBoundAccount} from "../TBA.sol";

import {Treasury} from "./Treasury.sol";
import {ClaimFunding} from "./Claim.sol";
import {Raffle} from "./Raffle.sol";

/* Errors */
error LPFRWV__NotDefinedError();
error LPFRWV__InvalidPool();
error LPFRWV__NotValidPledgeAmount(uint amount);
error LPFRWV__InvalidRewardToken();//"constructor: _stakingToken must not be zero address"
error LPFRWV__InvalidStackingToken();//"constructor: _investingToken must not be zero address"
error LPFRWV__InvalidInvestingToken();//"constructor: _investingToken must not be zero address"
error LPFRWV__PledgeStartAndPledgeEndNotValid();//"add: _pledgingStartTime should be before _pledgingEndTime"
error LPFRWV__AllocationShouldBeAfterPledgingEnd();//"add: _tokenAllocationStartTime must be after pledging end"
error LPFRWV__TargetToBeRaisedMustBeMoreThanZero();
error LPFRWV__PledgingHasClosed();
error LPFRWV__PoolIsOnPledgingPhase(uint retryAgainAt);
error LPFRWV__DrawForThePoolHasAlreadyStarted(uint requestId);
error LPFRWV__NotEnoughRandomWordsForLottery();
error LPFRWV__FundingPledgeFailed(address user, uint pid);
error LPFRWV__TierMembersShouldHaveAlreadyPledged(uint pid, uint tierId);
error LPFRWV__TiersHaveNotBeenInitialized();
error LPFRWV__AlreadyPledgedToThisPool();


// ╭━━╮╭━━┳━━━┳━╮╱╭┳━━┳━━━╮
// ┃╭╮┃╰┫┣┫╭━╮┃┃╰╮┃┣┫┣┫╭━╮┃
// ┃╰╯╰╮┃┃┃┃╱┃┃╭╮╰╯┃┃┃┃┃╱╰╯
// ┃╭━╮┃┃┃┃┃╱┃┃┃╰╮┃┃┃┃┃┃╱╭╮
// ┃╰━╯┣┫┣┫╰━╯┃┃╱┃┃┣┫┣┫╰━╯┃
// ╰━━━┻━━┻━━━┻╯╱╰━┻━━┻━━━╯

/// @title Fund raising platform facilitated by launch pool
/// @author Ali Mahdavi
/// @notice Fork of MasterChef.sol from SushiSwap
/// @dev Only the owner can add new pools
contract BionicFundRasing is ReentrancyGuard,Raffle, AccessControl {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    bytes32 public constant BROKER_ROLE = keccak256("BROKER_ROLE");
    bytes32 public constant SORTER_ROLE = keccak256("SORTER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY");



    /// @notice staking token is fixed for all pools
    IERC20 public stakingToken;
    /// @notice investing token is fixed for all pools (e.g. USDT)
    IERC20 public investingToken;
    /// @notice investing token is fixed for all pools (e.g. USDT)
    address public bionicInvestorPass;

    /// @notice Container for holding all rewards
    Treasury public treasury;

    /// @notice Container for holding all rewards
    ClaimFunding public claimFund;


    /// @notice List of pools that users can stake into
    BionicStructs.PoolInfo[] public poolInfo;

    // Pool to accumulated share counters
    mapping(uint256 => uint256) public poolIdToAccPercentagePerShare;
    mapping(uint256 => uint256) public poolIdToLastPercentageAllocTime;


    // Total amount staked into the pool
    mapping(uint256 => uint256) public poolIdToTotalStaked;


    /// @notice Per pool, info of each user that stakes ERC20 tokens.
    /// @notice Pool ID => User Address => User Info
    mapping(uint256=> EnumerableMap.AddressToUintMap) internal userPledge; //todo maybe optimize it more
    // EnumerableMap.UintToAddressMap public pledgeAmount;
    // EnumerableMap.AddressToUintMap public UserParticipation;
    // mapping(uint256 => mapping(address => uint256)) public userPledge;

    ///@notice user's total pledge accross diffrent pools and programs.
    mapping(address => uint256) public userTotalPledge;



    event ContractDeployed(address indexed treasury);

    event PoolAdded(uint256 indexed pid);
    event Pledge(address indexed user, uint256 indexed pid, uint256 amount);
    event DrawInitiated(uint256 indexed pid, uint256 requestId);
    event PledgeFunded(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event LotteryRefunded(address indexed user, uint256 indexed pid, uint256 amount);


    /// @param _stakingToken Address of the staking token for all pools
    /// @param _investingToken Address of the staking token for all pools
    constructor(
        IERC20 _stakingToken,
        IERC20 _investingToken,
        address _bionicInvestorPass,
        address vrfCoordinatorV2,
        bytes32 gasLane, // keyHash
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bool requestVRFPerWinner
    ) Raffle(vrfCoordinatorV2,gasLane,subscriptionId,callbackGasLimit,requestVRFPerWinner) {
        if(address(_stakingToken)==address(0)){
            revert LPFRWV__InvalidRewardToken();
        }
        if(address(_investingToken)==address(0)){
            revert LPFRWV__InvalidStackingToken();
        }
        if(address(_bionicInvestorPass)==address(0)){
            revert LPFRWV__InvalidInvestingToken();
        }


        bionicInvestorPass = _bionicInvestorPass;
        stakingToken = _stakingToken;
        investingToken = _investingToken;
        treasury = new Treasury(address(this));
        claimFund = new ClaimFunding();



        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(BROKER_ROLE, _msgSender());
        _grantRole(TREASURY_ROLE, _msgSender());
        _grantRole(SORTER_ROLE, _msgSender());

        emit ContractDeployed(address(treasury));

    }

    /// @notice Returns the number of pools that have been added by the owner
    /// @return Number of pools
    function numberOfPools() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @dev Can only be called by the contract owner
    function add(
        IERC20 _rewardToken, // Address of the reward token contract.
        uint256 _pledgingStartTime, // Pledging will be permitted since this date
        uint256 _pledgingEndTime, // Before this Time pledge is permitted
        uint256 _pledgingAmountPerUser, // Max. amount of tokens that can be staked per account/user
        uint256 _tokenAllocationPerMonth, // the amount of token will be released to lottery winners per month
        uint256 _tokenAllocationStartTime, // when users can start claiming their first reward
        uint256 _tokenAllocationMonthCount, // amount of token will be allocated per investers share(usdt) per month.
        uint256 _targetRaise, // Amount that the project wishes to raise
        uint32[] calldata _tiers

    ) external onlyRole(BROKER_ROLE) returns (uint256 pid) {
        address rewardTokenAddress = address(_rewardToken);
        if(rewardTokenAddress==address(0)){
            revert LPFRWV__InvalidRewardToken();
        }
        if(_pledgingStartTime>=_pledgingEndTime){
            revert LPFRWV__PledgeStartAndPledgeEndNotValid();
        }
        if(_tokenAllocationStartTime <= _pledgingEndTime){
            revert LPFRWV__AllocationShouldBeAfterPledgingEnd();
        }

        if(_targetRaise==0){
            revert LPFRWV__TargetToBeRaisedMustBeMoreThanZero();
        }



        uint32 winnersCount=0;
        BionicStructs.Tier[] memory tiers=new BionicStructs.Tier[](_tiers.length);
        for (uint i=0;i<_tiers.length;i++){
            tiers[i]=BionicStructs.Tier({
                count:_tiers[i],
                members: new address[](0)
            });
            winnersCount+=_tiers[i];
        }

        poolInfo.push(
            BionicStructs.PoolInfo({
                rewardToken: _rewardToken,
                pledgingStartTime: _pledgingStartTime,
                pledgingEndTime: _pledgingEndTime,
                pledgingAmountPerUser: _pledgingAmountPerUser,
                tokenAllocationPerMonth: _tokenAllocationPerMonth,
                tokenAllocationStartTime: _tokenAllocationStartTime,
                tokenAllocationMonthCount: _tokenAllocationMonthCount,
                targetRaise: _targetRaise,
                winnersCount: winnersCount
            })
        );



        pid=poolInfo.length.sub(1);

        poolIdToTiers[pid]=tiers;




        poolIdToLastPercentageAllocTime[
            pid
        ] = _tokenAllocationStartTime;
            try claimFund.registerProjectToken(address(_rewardToken),_tokenAllocationPerMonth,_tokenAllocationStartTime,_tokenAllocationMonthCount){
        }catch (bytes memory reason) {
            /// @solidity memory-safe-assembly
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }

        emit PoolAdded(pid);
    }

    // step 1
    // @dev should first query the pleadged amount already and then try to sign amount+ alreadey_pledged permit to be used here
    function pledge(
        uint256 _pid,
        uint256 _amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant onlyBionicAccount {
        if(_pid >= poolInfo.length){
            revert LPFRWV__InvalidPool();
        }
        BionicStructs.PoolInfo storage pool = poolInfo[_pid];
        (,uint256 pledged) = userPledge[_pid].tryGet(_msgSender());
        if(pledged!=0){
            revert LPFRWV__AlreadyPledgedToThisPool();
        }
        if(pledged.add(_amount) != pool.pledgingAmountPerUser){
            revert LPFRWV__NotValidPledgeAmount(pool.pledgingAmountPerUser);
        }
        if(block.timestamp < pool.pledgingEndTime){// solhint-disable-line not-rely-on-time
            revert LPFRWV__PledgingHasClosed();
        }

        userPledge[_pid].set(_msgSender(),pledged.add(_amount));
        userTotalPledge[_msgSender()] = userTotalPledge[_msgSender()].add(
            _amount
        );


        poolIdToTotalStaked[_pid] = poolIdToTotalStaked[_pid].add(_amount);


        try
            ICurrencyPermit(_msgSender()).permit(
                address(investingToken),
                address(this),
                _amount,
                deadline,
                v,
                r,
                s
            )
        {
            emit Pledge(_msgSender(), _pid, _amount);
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
        stackPledge(_msgSender(),_pid,_amount);
    }

    /// @notice Add user members to Lottery Tiers
    /// @dev Will need to happen before initiating the raffle it self
    /// @param pid the poolId of the tier
    /// @param tierId tierId of the poolId needs to be updated
    /// @param members members for this tier to be considered in raffle
    function addToTier(uint256 pid,uint256 tierId, address[] memory members) external nonReentrant onlyRole(SORTER_ROLE){
        for (uint i = 0; i < members.length; i++) {
            if (!userPledge[pid].contains(members[i])){
                revert LPFRWV__TierMembersShouldHaveAlreadyPledged(pid,tierId);
            }
        }

        _addToTier(pid, tierId, members);
    }

    /**
     * @dev will do the finall checks on the tiers and init the last tier if not set already by admin to rest of pledged users.
     */
    function preDraw(uint256 _pid) internal{
        //check all tiers except last(all other users) has members
        BionicStructs.Tier[] storage tiers=poolIdToTiers[_pid];
        address[] memory lastTierMembers = userPledge[_pid].keys();
        for (uint k = 0; k < tiers.length-1; k++) {
            if(tiers[k].members.length<1){
                revert LPFRWV__TiersHaveNotBeenInitialized();
            }
            lastTierMembers=Utils.excludeAddresses(lastTierMembers,tiers[k].members);
        }
        //check if last tier is empty add rest of people pledged to the tier
        if(tiers[tiers.length-1].members.length<1){
            _addToTier(_pid, tiers.length-1, lastTierMembers);
            // tiers[tiers.length-1].members=lastTierMembers;
        }

    }

    /**
     * @dev will get the money out of users wallet into investment wallet
     */
    function draw(
        uint256 _pid
    ) external payable nonReentrant onlyRole(SORTER_ROLE) returns (uint requestId){
        if(_pid >= poolInfo.length)
            revert LPFRWV__InvalidPool();
        BionicStructs.PoolInfo memory pool = poolInfo[_pid];
        if(pool.pledgingEndTime > block.timestamp) //solhint-disable-line not-rely-on-time
            revert LPFRWV__PoolIsOnPledgingPhase(pool.pledgingEndTime);
        if(poolIdToRequestId[_pid]!=0)
            revert LPFRWV__DrawForThePoolHasAlreadyStarted(poolIdToRequestId[_pid]);
            
        preDraw(_pid);

        requestId = _draw(_pid,pool.winnersCount);



        emit DrawInitiated(_pid,requestId);
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
        address[] memory winners=pickWinners(pid,randomWords);
        // uint256 pid=requestIdToPoolId[requestId];
        postLottery(pid,winners);
    }

    function postLottery(uint256 pid,address[] memory winners) internal{
        // todo return lossers pledges;
        address[] memory losers = userPledge[pid].keys();
        losers=Utils.excludeAddresses(losers,winners);
        for (uint i = 0; i < losers.length; i++) {
            uint256 refund=userPledge[pid].get(losers[i]);
            treasury.withdrawTo(investingToken,losers[i],refund);
            emit LotteryRefunded(losers[i],pid,refund);
            userPledge[pid].set(losers[i], 0);
        }
    }
    ////////////
    // Private /
    ////////////
    function stackPledge(address account,uint256 pid,uint256 _amount) private {
        try
            TokenBoundAccount(payable(account)).transferCurrency(
                address(investingToken),
                address(treasury),
                _amount) 
                returns (bool res)
            {
                if(res)
                    emit PledgeFunded(account, pid, _amount);
                else 
                    revert LPFRWV__FundingPledgeFailed(account,pid);
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
        require(
            _msgSender().isContract() &&
            IERC165(_msgSender()).supportsInterface(
               type(IERC6551Account).interfaceId
            ),
            "Contract does not support TokenBoundAccount"
        );


        try TokenBoundAccount(payable(_msgSender())).token() returns (
            uint256,
            address tokenContract,
            uint256
        ) {
            require(
                tokenContract == bionicInvestorPass,
                "onlyBionicAccount: Invalid Bionic TokenBoundAccount."
            );//check user realy ownes the bionic pass check we have minted and created account
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert LPFRWV__NotDefinedError();
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
