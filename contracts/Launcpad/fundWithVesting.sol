// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {SafeERC20,IERC20,Address} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl,IERC165} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC6551Account} from "../reference/src/interfaces/IERC6551Account.sol";


import {IterableMapping} from  "../libs/IterableMapping.sol";
import {ICurrencyPermit,ICurrencyPermit__NoReason} from "../libs/ICurrencyPermit.sol";
import {BionicStructs} from "../libs/BionicStructs.sol";
import {TokenBoundAccount} from "../TBA.sol";

import {Treasury} from "./Treasury.sol";


/* Errors */
error LPFRWV__NotDefinedError();
error LPFRWV__InvalidPool();
error LPFRWV__PoolIsOnPledgingPhase(uint retryAgainAt);
error LPFRWV__DrawForThePoolHasAlreadyStarted(uint requestId);
error LPFRWV__NotEnoughRandomWordsForLottery();
error LPFRWV__FundingPledgeFailed(address user, uint pid);

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
contract LaunchPoolFundRaisingWithVesting is ReentrancyGuard,VRFConsumerBaseV2, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    using IterableMapping for BionicStructs.Map;

    bytes32 public constant BROKER_ROLE = keccak256("BROKER_ROLE");
    bytes32 public constant SORTER_ROLE = keccak256("SORTER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY");

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    bool private immutable i_requestVRFPerWinner; // whether should request diffrent random number per winner or just one and calculate all winners off of it.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;


    /// @notice staking token is fixed for all pools
    IERC20 public stakingToken;
    /// @notice investing token is fixed for all pools (e.g. USDT)
    IERC20 public investingToken;
    /// @notice investing token is fixed for all pools (e.g. USDT)
    address public bionicInvestorPass;

    /// @notice Container for holding all rewards
    Treasury public treasury;

    /// @notice List of pools that users can stake into
    BionicStructs.PoolInfo[] public poolInfo;
    mapping(uint256 => BionicStructs.Tier[]) public poolIdToTiers;

    // Pool to accumulated share counters
    mapping(uint256 => uint256) public poolIdToAccPercentagePerShare;
    mapping(uint256 => uint256) public poolIdToLastPercentageAllocTime;

    // Number of reward tokens distributed per block for this pool
    mapping(uint256 => uint256) public poolIdToRewardPerBlock;

    // Last block number that reward token distribution took place
    mapping(uint256 => uint256) public poolIdToLastRewardBlock;

    // Block number when rewards start
    mapping(uint256 => uint256) public poolIdToRewardStartBlock;

    // Block number when cliff ends
    mapping(uint256 => uint256) public poolIdToRewardCliffEndBlock;

    // Block number when rewards end
    mapping(uint256 => uint256) public poolIdToRewardEndBlock;

    // Per LPOOL token staked, how much reward token earned in pool that users will get
    mapping(uint256 => uint256) public poolIdToAccRewardPerShareVesting;

    // Total rewards being distributed up to rewardEndBlock
    mapping(uint256 => uint256)
        public poolIdToMaxRewardTokensAvailableForVesting;

    // Total amount staked into the pool
    mapping(uint256 => uint256) public poolIdToTotalStaked;

    // Total amount of funding received by stakers after stakingEndBlock and before pledgeFundingEndBlock
    mapping(uint256 => uint256) public poolIdToTotalRaised;

    // For every staker that funded their pledge, the sum of all of their allocated percentages
    mapping(uint256 => uint256)
        public poolIdToTotalFundedPercentageOfTargetRaise;

    // True when funds have been claimed
    mapping(uint256 => bool) public poolIdToFundsClaimed;

    /// @notice Per pool, info of each user that stakes ERC20 tokens.
    /// @notice Pool ID => User Address => User Info
    mapping(uint256 => BionicStructs.Map) public userInfo;
    // mapping(uint256 => mapping(address => BionicStructs.UserInfo)) public userInfo;

    ///@notice user's total pledge accross diffrent pools and programs.
    mapping(address => uint256) public userTotalPledge;

    ///@notice requestId of vrf request on the pool
    mapping(uint256 => uint256) public poolIdToRequestId;
    mapping(uint256 => uint256) public requestIdToPoolId;

    // Available before staking ends for any given project. Essentitally 100% to 18 dp
    uint256 public constant TOTAL_TOKEN_ALLOCATION_POINTS = (100 * (10 ** 18));

    event ContractDeployed(address indexed treasury);
    event PoolAdded(uint256 indexed pid);
    event Pledge(address indexed user, uint256 indexed pid, uint256 amount);
    event DrawInitiated(uint256 indexed pid, uint256 requestId);
    event PledgeFunded(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event RewardsSetUp(
        uint256 indexed pid,
        uint256 amount,
        uint256 rewardEndBlock
    );
    event RewardClaimed(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event FundRaisingClaimed(
        uint256 indexed pid,
        address indexed recipient,
        uint256 amount
    );

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
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        require(
            address(_stakingToken) != address(0),
            "constructor: _stakingToken must not be zero address"
        );
        require(
            address(_investingToken) != address(0),
            "constructor: _investingToken must not be zero address"
        );
        require(
            _bionicInvestorPass != address(0),
            "constructor: _investingToken must not be zero address"
        );

        bionicInvestorPass = _bionicInvestorPass;
        stakingToken = _stakingToken;
        investingToken = _investingToken;
        treasury = new Treasury(address(this));

        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_requestVRFPerWinner = requestVRFPerWinner;


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
        uint256 _maxPledgingAmountPerUser, // Max. amount of tokens that can be staked per account/user
        uint256 _tokenAllocationPerBlock, // the amount of token will be released to lottary winners per month
        uint256 _tokenAllocationStartTime, // when users can start claiming their first reward
        uint256 _tokenAllocationPerShare, // amount of token will be allocated per investers share(usdt) per month.
        uint256 _targetRaise, // Amount that the project wishes to raise
        uint32[] calldata _tiers,
        bool _withUpdate
    ) public onlyRole(BROKER_ROLE) returns (uint256 pid) {
        address rewardTokenAddress = address(_rewardToken);
        require(
            rewardTokenAddress != address(0),
            "add: _rewardToken is zero address"
        );
        require(
            _tokenAllocationStartTime < _pledgingEndTime,
            "add: _tokenAllocationStartTime must be before pledging end"
        );
        require(
            _pledgingStartTime < _pledgingEndTime,
            "add: _pledgingStartTime should be before _pledgingEndTime"
        );
        require(_targetRaise > 0, "add: Invalid raise amount");

        if (_withUpdate) {
            massUpdatePools();
        }



        poolInfo.push(
            BionicStructs.PoolInfo({
                rewardToken: _rewardToken,
                pledgingStartTime: _pledgingStartTime,
                pledgingEndTime: _pledgingEndTime,
                maxPledgingAmountPerUser: _maxPledgingAmountPerUser,
                tokenAllocationPerBlock: _tokenAllocationPerBlock,
                tokenAllocationStartTime: _tokenAllocationStartTime,
                tokenAllocationPerShare: _tokenAllocationPerShare,
                targetRaise: _targetRaise
            })
        );



        pid=poolInfo.length.sub(1);
        BionicStructs.Tier[] memory tiers=new BionicStructs.Tier[](_tiers.length);
        for (uint i=0;i<_tiers.length;i++){
            tiers[i]=BionicStructs.Tier({
                count:_tiers[i],
                members: new address[](_tiers[i])
            });
        }
        poolIdToTiers[pid]=tiers;



        poolIdToLastPercentageAllocTime[
            pid
        ] = _tokenAllocationStartTime;

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
        require(_pid < poolInfo.length, "pledge: Invalid PID");



        BionicStructs.PoolInfo storage pool = poolInfo[_pid];
        BionicStructs.UserInfo storage user = userInfo[_pid].get(_msgSender());

        require(_amount > 0, "pledge: No pledge specified");

        require(
            user.amount.add(_amount) <= pool.maxPledgingAmountPerUser,
            "pledge: can not exceed max staking amount per user"
        );
        
        require(
            block.timestamp >= pool.pledgingEndTime,   // solhint-disable-line not-rely-on-time
            "pledge: time window of pledging for this pool has passed"
        );

        updatePool(_pid);

        user.amount = user.amount.add(_amount);
        userTotalPledge[_msgSender()] = userTotalPledge[_msgSender()].add(
            _amount
        );
        user.tokenAllocDebt = user.tokenAllocDebt.add(
            _amount.mul(poolIdToAccPercentagePerShare[_pid]).div(1e18)
        );

        poolIdToTotalStaked[_pid] = poolIdToTotalStaked[_pid].add(_amount);


        try
            ICurrencyPermit(_msgSender()).permit(
                address(investingToken),
                address(this),
                userTotalPledge[_msgSender()],
                deadline,
                v,
                r,
                s
            )
        {
            userInfo[_pid].set(_msgSender(), user);
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
        // stakingToken.safeTransferFrom(address(_msgSender()), address(this), _amount);
    }

    function getPledgeFundingAmount(
        uint256 _pid
    ) public view returns (uint256) {
        require(_pid < poolInfo.length, "getPledgeFundingAmount: Invalid PID");
        BionicStructs.PoolInfo memory pool = poolInfo[_pid];
        BionicStructs.UserInfo memory user = userInfo[_pid].get(_msgSender());

        (
            uint256 accPercentPerShare,

        ) = getAccPercentagePerShareAndLastAllocBlock(_pid);

        uint256 userPercentageAllocated = user
            .amount
            .mul(accPercentPerShare)
            .div(1e18)
            .sub(user.tokenAllocDebt);
        return
            userPercentageAllocated.mul(pool.targetRaise).div(
                TOTAL_TOKEN_ALLOCATION_POINTS
            );
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
        if(pool.tokenAllocationStartTime > block.timestamp) //solhint-disable-line not-rely-on-time
            revert LPFRWV__PoolIsOnPledgingPhase(pool.tokenAllocationStartTime);
        if(poolIdToRequestId[_pid]!=0)
            revert LPFRWV__DrawForThePoolHasAlreadyStarted(poolIdToRequestId[_pid]);

        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            i_requestVRFPerWinner ? poolIdToTiers[_pid][0].count : 1
        );
        poolIdToRequestId[_pid]=requestId;
        requestIdToPoolId[requestId]=_pid;

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
        uint pid=requestIdToPoolId[requestId];

        BionicStructs.PoolInfo memory pool = poolInfo[pid];
        address[] memory winners;

        if(poolIdToTiers[pid][0].count>=userInfo[pid].size()){
            winners=userInfo[pid].keys;
        }else{
            if(i_requestVRFPerWinner){
                if (randomWords.length!=poolIdToTiers[pid][0].count) 
                    revert LPFRWV__NotEnoughRandomWordsForLottery();
                
                for (uint i=0;i<poolIdToTiers[pid][0].count;i++){
                    winners[i]=userInfo[pid].getKeyAtIndex(randomWords[i] % userInfo[pid].size());
                }
            }else{ //just get one word and calculate other random values off of it
                uint256 rand=randomWords[0];
                for (uint32 i=0;i<poolIdToTiers[pid][0].count;i++){
                    winners[i]=userInfo[pid].getKeyAtIndex(rand % userInfo[pid].size());
                    rand=uint256(keccak256(abi.encodePacked(rand,block.prevrandao,block.chainid,i)));
                }
            }
        }

        fundUserPledge(pid,winners);
    }

    // // step 2
    // function fundPledge(uint256 _pid) external payable nonReentrant {
    //     require(_pid < poolInfo.length, "fundPledge: Invalid PID");

    //     updatePool(_pid);

    //     BionicStructs.PoolInfo storage pool = poolInfo[_pid];
    //     BionicStructs.UserInfo storage user = userInfo[_pid][_msgSender()];

    //     require(user.pledgeFundingAmount == 0, "fundPledge: Pledge has already been funded");

    //     require(block.number > pool.stakingEndBlock, "fundPledge: Staking is still taking place");
    //     require(block.number <= pool.pledgeFundingEndBlock, "fundPledge: Deadline has passed to fund your pledge");

    //     require(user.amount > 0, "fundPledge: Must have staked");

    //     require(getPledgeFundingAmount(_pid) > 0, "fundPledge: must have positive pledge amount");
    //     require(msg.value == getPledgeFundingAmount(_pid), "fundPledge: Required ETH amount not satisfied");

    //     poolIdToTotalRaised[_pid] = poolIdToTotalRaised[_pid].add(msg.value);

    //     (uint256 accPercentPerShare,) = getAccPercentagePerShareAndLastAllocBlock(_pid);
    //     uint256 userPercentageAllocated = user.amount.mul(accPercentPerShare).div(1e18).sub(user.tokenAllocDebt);
    //     poolIdToTotalFundedPercentageOfTargetRaise[_pid] = poolIdToTotalFundedPercentageOfTargetRaise[_pid].add(userPercentageAllocated);

    //     user.pledgeFundingAmount = msg.value; // ensures pledges can only be done once

    //     stakingToken.safeTransfer(address(_msgSender()), user.amount);

    //     emit PledgeFunded(_msgSender(), _pid, msg.value);
    // }

    // // pre-step 3 for project
    // function getTotalRaisedVsTarget(uint256 _pid) external view returns (uint256 raised, uint256 target) {
    //     return (poolIdToTotalRaised[_pid], poolInfo[_pid].targetRaise);
    // }

    // // step 3
    // function setupVestingRewards(uint256 _pid, uint256 _rewardAmount,  uint256 _rewardStartBlock, uint256 _rewardCliffEndBlock, uint256 _rewardEndBlock)
    // external nonReentrant onlyOwner {
    //     require(_pid < poolInfo.length, "setupVestingRewards: Invalid PID");
    //     require(_rewardStartBlock > block.number, "setupVestingRewards: start block in the past");
    //     require(_rewardCliffEndBlock >= _rewardStartBlock, "setupVestingRewards: Cliff must be after or equal to start block");
    //     require(_rewardEndBlock > _rewardCliffEndBlock, "setupVestingRewards: end block must be after cliff block");

    //     BionicStructs.PoolInfo storage pool = poolInfo[_pid];

    //     require(block.number > pool.pledgeFundingEndBlock, "setupVestingRewards: Stakers are still pledging");

    //     uint256 vestingLength = _rewardEndBlock.sub(_rewardStartBlock);

    //     poolIdToMaxRewardTokensAvailableForVesting[_pid] = _rewardAmount;
    //     poolIdToRewardPerBlock[_pid] = _rewardAmount.div(vestingLength);

    //     poolIdToRewardStartBlock[_pid] = _rewardStartBlock;
    //     poolIdToLastRewardBlock[_pid] = _rewardStartBlock;

    //     poolIdToRewardCliffEndBlock[_pid] = _rewardCliffEndBlock;

    //     poolIdToRewardEndBlock[_pid] = _rewardEndBlock;

    //     pool.rewardToken.safeTransferFrom(_msgSender(), address(rewardGuildBank), _rewardAmount);

    //     emit RewardsSetUp(_pid, _rewardAmount, _rewardEndBlock);
    // }

    function pendingRewards(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        require(_pid < poolInfo.length, "pendingRewards: invalid _pid");

        BionicStructs.UserInfo memory user = userInfo[_pid].get(_user);

        // If they have staked but have not funded their pledge, they are not entitled to rewards
        if (user.pledgeFundingAmount == 0) {
            return 0;
        }

        uint256 accRewardPerShare = poolIdToAccRewardPerShareVesting[_pid];
        uint256 rewardEndBlock = poolIdToRewardEndBlock[_pid];
        uint256 lastRewardBlock = poolIdToLastRewardBlock[_pid];
        uint256 rewardPerBlock = poolIdToRewardPerBlock[_pid];
        if (
            block.number > lastRewardBlock &&
            rewardEndBlock != 0 &&
            poolIdToTotalStaked[_pid] != 0
        ) {
            uint256 maxEndBlock = block.number <= rewardEndBlock
                ? block.number
                : rewardEndBlock;
            uint256 multiplier = getMultiplier(lastRewardBlock, maxEndBlock);
            uint256 reward = multiplier.mul(rewardPerBlock);
            accRewardPerShare = accRewardPerShare.add(
                reward.mul(1e18).div(
                    poolIdToTotalFundedPercentageOfTargetRaise[_pid]
                )
            );
        }

        (
            uint256 accPercentPerShare,

        ) = getAccPercentagePerShareAndLastAllocBlock(_pid);
        uint256 userPercentageAllocated = user
            .amount
            .mul(accPercentPerShare)
            .div(1e18)
            .sub(user.tokenAllocDebt);
        return
            userPercentageAllocated.mul(accRewardPerShare).div(1e18).sub(
                user.rewardDebtRewards
            );
    }

    function massUpdatePools() public {
        for (uint256 pid = 0; pid < poolInfo.length; pid++) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        require(_pid < poolInfo.length, "updatePool: invalid _pid");

        // staking not started
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp < poolInfo[_pid].tokenAllocationStartTime) {
            return;
        }

        // if no one staked, nothing to do
        if (poolIdToTotalStaked[_pid] == 0) {
            poolIdToLastPercentageAllocTime[_pid] = block.number;
            return;
        }

        // token allocation not finished
        uint256 maxEndBlockForPercentAlloc = block.number <=
            poolInfo[_pid].pledgingEndTime
            ? block.timestamp // solhint-disable-line not-rely-on-time
            : poolInfo[_pid].pledgingEndTime;
        uint256 blocksSinceLastPercentAlloc = getMultiplier(
            poolIdToLastPercentageAllocTime[_pid],
            maxEndBlockForPercentAlloc
        );

        if (
            poolIdToRewardEndBlock[_pid] == 0 && blocksSinceLastPercentAlloc > 0
        ) {
            (
                uint256 accPercentPerShare,
                uint256 lastAllocBlock
            ) = getAccPercentagePerShareAndLastAllocBlock(_pid);
            poolIdToAccPercentagePerShare[_pid] = accPercentPerShare;
            poolIdToLastPercentageAllocTime[_pid] = lastAllocBlock;
        }

        // project has not sent rewards
        if (poolIdToRewardEndBlock[_pid] == 0) {
            return;
        }

        // cliff has not passed for pool
        if (block.number < poolIdToRewardCliffEndBlock[_pid]) {
            return;
        }

        uint256 rewardEndBlock = poolIdToRewardEndBlock[_pid];
        uint256 lastRewardBlock = poolIdToLastRewardBlock[_pid];
        uint256 maxEndBlock = block.number <= rewardEndBlock
            ? block.number
            : rewardEndBlock;
        uint256 multiplier = getMultiplier(lastRewardBlock, maxEndBlock);

        // No point in doing any more logic as the rewards have ended
        if (multiplier == 0) {
            return;
        }

        uint256 rewardPerBlock = poolIdToRewardPerBlock[_pid];
        uint256 reward = multiplier.mul(rewardPerBlock);

        poolIdToAccRewardPerShareVesting[
            _pid
        ] = poolIdToAccRewardPerShareVesting[_pid].add(
            reward.mul(1e18).div(
                poolIdToTotalFundedPercentageOfTargetRaise[_pid]
            )
        );
        poolIdToLastRewardBlock[_pid] = maxEndBlock;
    }

    function getAccPercentagePerShareAndLastAllocBlock(
        uint256 _pid
    )
        internal
        view
        returns (uint256 accPercentPerShare, uint256 lastAllocBlock)
    {
        uint256 tokenAllocationPeriodInBlocks = poolInfo[_pid]
            .pledgingEndTime
            .sub(poolInfo[_pid].tokenAllocationStartTime);

        uint256 allocationAvailablePerBlock = TOTAL_TOKEN_ALLOCATION_POINTS.div(
            tokenAllocationPeriodInBlocks
        );

        uint256 maxEndBlockForPercentAlloc = block.number <=
            poolInfo[_pid].pledgingEndTime
            ? block.number
            : poolInfo[_pid].pledgingEndTime;
        uint256 multiplier = getMultiplier(
            poolIdToLastPercentageAllocTime[_pid],
            maxEndBlockForPercentAlloc
        );
        uint256 totalPercentageUnlocked = multiplier.mul(
            allocationAvailablePerBlock
        );

        return (
            poolIdToAccPercentagePerShare[_pid].add(
                totalPercentageUnlocked.mul(1e18).div(poolIdToTotalStaked[_pid])
            ),
            maxEndBlockForPercentAlloc
        );
    }

    function claimReward(uint256 _pid) public nonReentrant {
        updatePool(_pid);

        require(
            block.number >= poolIdToRewardCliffEndBlock[_pid],
            "claimReward: Not past cliff"
        );

        BionicStructs.UserInfo storage user = userInfo[_pid].get(_msgSender());
        require(user.pledgeFundingAmount > 0, "claimReward: Nice try pal");

        BionicStructs.PoolInfo storage pool = poolInfo[_pid];

        uint256 accRewardPerShare = poolIdToAccRewardPerShareVesting[_pid];

        (
            uint256 accPercentPerShare,

        ) = getAccPercentagePerShareAndLastAllocBlock(_pid);
        uint256 userPercentageAllocated = user
            .amount
            .mul(accPercentPerShare)
            .div(1e18)
            .sub(user.tokenAllocDebt);
        uint256 pending = userPercentageAllocated
            .mul(accRewardPerShare)
            .div(1e18)
            .sub(user.rewardDebtRewards);

        if (pending > 0) {
            user.rewardDebtRewards = userPercentageAllocated
                .mul(accRewardPerShare)
                .div(1e18);
            safeRewardTransfer(pool.rewardToken, _msgSender(), pending);

            emit RewardClaimed(_msgSender(), _pid, pending);
        }
    }

    // withdraw only permitted post `pledgeFundingEndBlock` and you can only take out full amount if you did not fund the pledge
    // functions like the old emergency withdraw as it does not concern itself with claiming rewards
    function withdraw(uint256 _pid) external nonReentrant {
        require(_pid < poolInfo.length, "withdraw: invalid _pid");

        BionicStructs.PoolInfo storage pool = poolInfo[_pid];
        BionicStructs.UserInfo storage user = userInfo[_pid].get(_msgSender());

        require(user.amount > 0, "withdraw: No stake to withdraw");
        require(
            user.pledgeFundingAmount == 0,
            "withdraw: Only allow non-funders to withdraw"
        );
        require(
            block.number > pool.pledgingEndTime,
            "withdraw: Not yet permitted"
        );

        uint256 withdrawAmount = user.amount;

        // remove the record for this user
        userInfo[_pid].remove(_msgSender());

        stakingToken.safeTransfer(_msgSender(), withdrawAmount);

        emit Withdraw(_msgSender(), _pid, withdrawAmount);
    }

    function claimFundRaising(
        uint256 _pid
    ) external nonReentrant onlyRole("TREASURY_ROLE") {
        require(_pid < poolInfo.length, "claimFundRaising: invalid _pid");

        uint256 rewardPerBlock = poolIdToRewardPerBlock[_pid];
        require(rewardPerBlock != 0, "claimFundRaising: rewards not yet sent");
        require(
            poolIdToFundsClaimed[_pid] == false,
            "claimFundRaising: Already claimed funds"
        );

        poolIdToFundsClaimed[_pid] = true;
        address payable msgSender = payable(_msgSender());
        if (!msgSender.send(poolIdToTotalRaised[_pid])) revert();

        emit FundRaisingClaimed(_pid, msgSender, poolIdToTotalRaised[_pid]);
    }

    ////////////
    // Private /
    ////////////

    /// @dev Safe reward transfer function, just in case if rounding error causes pool to not have enough rewards.
    function safeRewardTransfer(
        IERC20 _rewardToken,
        address _to,
        uint256 _amount
    ) private {
        uint256 bal = treasury.tokenBalance(_rewardToken);
        if (_amount > bal) {
            treasury.withdrawTo(_rewardToken, _to, bal);
        } else {
            treasury.withdrawTo(_rewardToken, _to, _amount);
        }
    }
    /// @dev invest on the pool via already pledged amount of investing token provided by user.
    /// @dev todo maybe instead of reverting on onunsuccessfull transfer emit an event?
    function fundUserPledge(
        uint256 _pid,
        address[] memory winners
    ) private {
        for (uint256 i = 0; i < winners.length; i++) {
            address payable userAddress = payable(
                winners[i]
            );
            TokenBoundAccount userAccount = TokenBoundAccount(userAddress);
            BionicStructs.UserInfo memory user = userInfo[_pid].get(
                userAddress
            );

            if (user.pledgeFundingAmount == 0 && user.amount > 0) {
                try
                    userAccount.transferCurrency(
                        address(investingToken),
                        address(this),
                        user.amount) 
                        returns (bool res)
                    {
                        if(res)
                            emit PledgeFunded(userAddress, _pid, user.amount);
                        else 
                            revert LPFRWV__FundingPledgeFailed(userAddress,_pid);
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
        }

    }

    /// @notice Return reward multiplier over the given _from to _to block.
    /// @param _from Block number
    /// @param _to Block number
    /// @return Number of blocks that have passed
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) private pure returns (uint256) {
        return _to.sub(_from);
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
            );
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
