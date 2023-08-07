// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../reference/src/interfaces/IERC6551Account.sol";


import "hardhat/console.sol";
import "../libs/IterableMapping.sol";
import "../libs/ICurrencyPermit.sol";
import "../libs/BionicStructs.sol";
import {TokenBoundAccount} from "../TBA.sol";

import {FundRaisingGuild} from "./FundRaisingGuild.sol";

/// @title Fund raising platform facilitated by launch pool
/// @author BlockRocket.tech
/// @notice Fork of MasterChef.sol from SushiSwap
/// @dev Only the owner can add new pools
contract LaunchPoolFundRaisingWithVesting is ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    using IterableMapping for BionicStructs.Map;

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
    FundRaisingGuild public rewardGuildBank;

    /// @notice List of pools that users can stake into
    BionicStructs.PoolInfo[] public poolInfo;

    // Pool to accumulated share counters
    mapping(uint256 => uint256) public poolIdToAccPercentagePerShare;
    mapping(uint256 => uint256) public poolIdToLastPercentageAllocBlock;

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

    // Available before staking ends for any given project. Essentitally 100% to 18 dp
    uint256 public constant TOTAL_TOKEN_ALLOCATION_POINTS = (100 * (10 ** 18));

    event ContractDeployed(address indexed guildBank);
    event PoolAdded(uint256 indexed pid);
    event Pledge(address indexed user, uint256 indexed pid, uint256 amount);
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
        address _bionicInvestorPass
    ) {
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
        rewardGuildBank = new FundRaisingGuild(address(this));


        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(BROKER_ROLE, _msgSender());
        _grantRole(TREASURY_ROLE, _msgSender());
        _grantRole(SORTER_ROLE, _msgSender());

        emit ContractDeployed(address(rewardGuildBank));
    }

    /// @notice Returns the number of pools that have been added by the owner
    /// @return Number of pools
    function numberOfPools() external view returns (uint256) {
        return poolInfo.length;
    }

    /// @dev Can only be called by the contract owner
    function add(
        IERC20 _rewardToken,
        uint256 _tokenAllocationStartBlock,
        uint256 _pledgeingEndBlock,
        uint256 _targetRaise,
        uint256 _maxPledgingAmountPerUser,
        bool _withUpdate
    ) public onlyRole(BROKER_ROLE) {
        address rewardTokenAddress = address(_rewardToken);
        require(
            rewardTokenAddress != address(0),
            "add: _rewardToken is zero address"
        );
        require(
            _tokenAllocationStartBlock < _pledgeingEndBlock,
            "add: _tokenAllocationStartBlock must be before pledging end"
        );
        require(_targetRaise > 0, "add: Invalid raise amount");

        if (_withUpdate) {
            massUpdatePools();
        }

        poolInfo.push(
            BionicStructs.PoolInfo({
                rewardToken: _rewardToken,
                tokenAllocationStartBlock: _tokenAllocationStartBlock,
                pledgingEndBlock: _pledgeingEndBlock,
                targetRaise: _targetRaise,
                maxPledgingAmountPerUser: _maxPledgingAmountPerUser
            })
        );

        poolIdToLastPercentageAllocBlock[
            poolInfo.length.sub(1)
        ] = _tokenAllocationStartBlock;

        emit PoolAdded(poolInfo.length.sub(1));
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
                revert("ICurrencyPermit: no reason");
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
    function raffle(
        uint256 _pid
    ) external payable nonReentrant onlyRole(SORTER_ROLE) {
        require(_pid < poolInfo.length, "fundPledge: Invalid PID");

        for (uint256 i = 0; i < userInfo[_pid].size(); i++) {
            address payable userAddress = payable(
                userInfo[_pid].getKeyAtIndex(i)
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
                        emit PledgeFunded(userAddress, _pid, user.amount);
                    } catch (bytes memory reason) {
                        if (reason.length == 0) {
                            revert("ICurrencyPermit: no reason");
                        } else {
                            /// @solidity memory-safe-assembly
                            assembly {
                                revert(add(32, reason), mload(reason))
                            }
                        }
                    }
                // poolIdToTotalRaised[_pid] = poolIdToTotalRaised[_pid].add(
                //     msg.value
                // );
                // UserOperation memory op = UserOperation({
                //     sender: address(_userAddress),
                //     nonce: _userAddress.nonce(),
                //     callGasLimit: 0,
                //     verificationGasLimit: 100000,
                //     preVerificationGas: 21000,
                //     maxFeePerGas: BigNumber{value: "1541441108"},
                //     maxPriorityFeePerGas: 1000000000
                // });
            }

            // poolIdToTotalRaised[_pid] = poolIdToTotalRaised[_pid].add(
            //     msg.value
            // );

            // (
            //     uint256 accPercentPerShare,

            // ) = getAccPercentagePerShareAndLastAllocBlock(_pid);
            // uint256 userPercentageAllocated = user
            //     .amount
            //     .mul(accPercentPerShare)
            //     .div(1e18)
            //     .sub(user.tokenAllocDebt);
            // poolIdToTotalFundedPercentageOfTargetRaise[
            //     _pid
            // ] = poolIdToTotalFundedPercentageOfTargetRaise[_pid].add(
            //     userPercentageAllocated
            // );

            // user.pledgeFundingAmount = msg.value; // ensures pledges can only be done once

            // stakingToken.safeTransfer(address(_msgSender()), user.amount);

            // emit PledgeFunded(_msgSender(), _pid, msg.value);
        }
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
        if (block.number < poolInfo[_pid].tokenAllocationStartBlock) {
            return;
        }

        // if no one staked, nothing to do
        if (poolIdToTotalStaked[_pid] == 0) {
            poolIdToLastPercentageAllocBlock[_pid] = block.number;
            return;
        }

        // token allocation not finished
        uint256 maxEndBlockForPercentAlloc = block.number <=
            poolInfo[_pid].pledgingEndBlock
            ? block.number
            : poolInfo[_pid].pledgingEndBlock;
        uint256 blocksSinceLastPercentAlloc = getMultiplier(
            poolIdToLastPercentageAllocBlock[_pid],
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
            poolIdToLastPercentageAllocBlock[_pid] = lastAllocBlock;
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
            .pledgingEndBlock
            .sub(poolInfo[_pid].tokenAllocationStartBlock);

        uint256 allocationAvailablePerBlock = TOTAL_TOKEN_ALLOCATION_POINTS.div(
            tokenAllocationPeriodInBlocks
        );

        uint256 maxEndBlockForPercentAlloc = block.number <=
            poolInfo[_pid].pledgingEndBlock
            ? block.number
            : poolInfo[_pid].pledgingEndBlock;
        uint256 multiplier = getMultiplier(
            poolIdToLastPercentageAllocBlock[_pid],
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
            block.number > pool.pledgingEndBlock,
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
        uint256 bal = rewardGuildBank.tokenBalance(_rewardToken);
        if (_amount > bal) {
            rewardGuildBank.withdrawTo(_rewardToken, _to, bal);
        } else {
            rewardGuildBank.withdrawTo(_rewardToken, _to, _amount);
        }
    }

    /// @notice Return reward multiplier over the given _from to _to block.
    /// @param _from Block number
    /// @param _to Block number
    /// @return Number of blocks that have passed
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) private view returns (uint256) {
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
                revert("onlyBionicAccount: Invalid Bionic TokenBoundAccount.");
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }

        (, address tokenContract, ) = TokenBoundAccount(payable(_msgSender()))
            .token();

        _;
    }
}
