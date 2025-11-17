// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUSDC.sol";

/**
 * @title INXRewardManager
 * @dev Manages INX token rewards distribution
 * Handles reward pools, staking, and reward claims
 */
contract INXRewardManager is Ownable, ReentrancyGuard {
    IUSDC public immutable usdcToken;
    IERC20 public inxToken; // INX token contract (can be set later)
    
    struct RewardPool {
        uint256 poolId;
        string poolName;
        uint256 totalRewards;
        uint256 distributedRewards;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardRate; // Rewards per second
        bool isActive;
    }
    
    struct Stake {
        address staker;
        uint256 amount;
        uint256 stakedAt;
        uint256 lastRewardClaim;
        uint256 totalRewardsClaimed;
    }
    
    struct RewardClaim {
        address recipient;
        uint256 amount;
        uint256 poolId;
        uint256 claimedAt;
    }
    
    mapping(uint256 => RewardPool) public rewardPools;
    mapping(address => Stake) public stakes;
    mapping(address => uint256[]) public userRewardClaims;
    mapping(uint256 => RewardClaim) public rewardClaims;
    
    // Track stakers
    address[] public stakerList;
    
    uint256 public totalPools;
    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    uint256 public totalRewardClaims;
    
    // Configuration
    uint256 public minStakeAmount;
    uint256 public stakingLockPeriod; // Lock period in seconds
    
    event RewardPoolCreated(
        uint256 indexed poolId,
        string poolName,
        uint256 totalRewards,
        uint256 startTime,
        uint256 endTime
    );
    event PoolFunded(uint256 indexed poolId, uint256 amount);
    event Staked(address indexed staker, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed staker, uint256 amount, uint256 timestamp);
    event RewardsClaimed(
        address indexed recipient,
        uint256 amount,
        uint256 indexed poolId
    );
    event RewardDistributed(
        address indexed recipient,
        uint256 amount,
        uint256 indexed poolId
    );
    event PoolDeactivated(uint256 indexed poolId);
    event INXTokenSet(address indexed inxToken);
    
    modifier validPool(uint256 poolId) {
        require(rewardPools[poolId].poolId != 0, "Invalid pool");
        _;
    }
    
    modifier onlyActivePool(uint256 poolId) {
        require(rewardPools[poolId].isActive, "Pool not active");
        require(
            block.timestamp >= rewardPools[poolId].startTime &&
            block.timestamp <= rewardPools[poolId].endTime,
            "Pool not in active period"
        );
        _;
    }
    
    constructor(address _usdcToken) Ownable(msg.sender) {
        require(_usdcToken != address(0), "Invalid USDC address");
        usdcToken = IUSDC(_usdcToken);
        minStakeAmount = 1; // Minimum stake amount
        stakingLockPeriod = 7 days; // 7 days lock period
    }
    
    /**
     * @dev Set the INX token address
     * @param _inxToken Address of the INX token contract
     */
    function setINXToken(address _inxToken) external onlyOwner {
        require(_inxToken != address(0), "Invalid INX token address");
        inxToken = IERC20(_inxToken);
        
        emit INXTokenSet(_inxToken);
    }
    
    /**
     * @dev Create a new reward pool
     * @param poolName Name of the pool
     * @param totalRewards Total rewards allocated for this pool
     * @param startTime Start time of the pool
     * @param endTime End time of the pool
     * @param rewardRate Rewards per second
     */
    function createRewardPool(
        string memory poolName,
        uint256 totalRewards,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardRate
    ) external onlyOwner returns (uint256 poolId) {
        require(bytes(poolName).length > 0, "Invalid pool name");
        require(totalRewards > 0, "Invalid rewards amount");
        require(startTime < endTime, "Invalid time range");
        require(endTime > block.timestamp, "End time must be in future");
        require(rewardRate > 0, "Invalid reward rate");
        
        totalPools++;
        poolId = totalPools;
        
        rewardPools[poolId] = RewardPool({
            poolId: poolId,
            poolName: poolName,
            totalRewards: totalRewards,
            distributedRewards: 0,
            startTime: startTime,
            endTime: endTime,
            rewardRate: rewardRate,
            isActive: true
        });
        
        emit RewardPoolCreated(poolId, poolName, totalRewards, startTime, endTime);
    }
    
    /**
     * @dev Fund a reward pool with USDC
     * @param poolId The pool ID
     * @param amount Amount of USDC to fund
     */
    function fundPool(uint256 poolId, uint256 amount) 
        external 
        onlyOwner 
        validPool(poolId) 
        nonReentrant 
    {
        require(amount > 0, "Amount must be greater than 0");
        require(
            usdcToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        rewardPools[poolId].totalRewards += amount;
        
        emit PoolFunded(poolId, amount);
    }
    
    /**
     * @dev Stake INX tokens to earn rewards
     * @param amount Amount of INX tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(address(inxToken) != address(0), "INX token not set");
        require(amount >= minStakeAmount, "Amount below minimum");
        require(inxToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(
            inxToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        if (stakes[msg.sender].staker == address(0)) {
            stakes[msg.sender] = Stake({
                staker: msg.sender,
                amount: amount,
                stakedAt: block.timestamp,
                lastRewardClaim: block.timestamp,
                totalRewardsClaimed: 0
            });
            stakerList.push(msg.sender);
        } else {
            stakes[msg.sender].amount += amount;
        }
        
        totalStaked += amount;
        
        emit Staked(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Unstake INX tokens
     * @param amount Amount of INX tokens to unstake
     */
    function unstake(uint256 amount) external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.staker != address(0), "No stake found");
        require(userStake.amount >= amount, "Insufficient staked amount");
        require(
            block.timestamp >= userStake.stakedAt + stakingLockPeriod,
            "Stake still locked"
        );
        
        userStake.amount -= amount;
        totalStaked -= amount;
        
        if (userStake.amount == 0) {
            delete stakes[msg.sender];
        }
        
        require(inxToken.transfer(msg.sender, amount), "Transfer failed");
        
        emit Unstaked(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Distribute rewards to recipients
     * @param poolId The pool ID
     * @param recipients Array of recipient addresses
     * @param amounts Array of reward amounts
     */
    function distributeRewards(
        uint256 poolId,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner validPool(poolId) onlyActivePool(poolId) nonReentrant {
        require(recipients.length == amounts.length, "Array length mismatch");
        
        RewardPool storage pool = rewardPools[poolId];
        require(pool.isActive, "Pool not active");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(
            pool.distributedRewards + totalAmount <= pool.totalRewards,
            "Exceeds pool rewards"
        );
        require(
            usdcToken.balanceOf(address(this)) >= totalAmount,
            "Insufficient USDC balance"
        );
        
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];
            
            if (amount > 0) {
                require(usdcToken.transfer(recipient, amount), "Transfer failed");
                
                pool.distributedRewards += amount;
                totalRewardsDistributed += amount;
                
                emit RewardDistributed(recipient, amount, poolId);
            }
        }
    }
    
    /**
     * @dev Claim rewards for a specific pool
     * @param poolId The pool ID
     * @param amount Amount to claim
     */
    function claimRewards(uint256 poolId, uint256 amount) 
        external 
        validPool(poolId) 
        onlyActivePool(poolId) 
        nonReentrant 
    {
        require(amount > 0, "Amount must be greater than 0");
        
        RewardPool storage pool = rewardPools[poolId];
        require(
            pool.distributedRewards + amount <= pool.totalRewards,
            "Exceeds pool rewards"
        );
        require(
            usdcToken.balanceOf(address(this)) >= amount,
            "Insufficient USDC balance"
        );
        
        // Calculate rewards based on stake if staking is enabled
        if (stakes[msg.sender].staker != address(0)) {
            uint256 stakedAmount = stakes[msg.sender].amount;
            uint256 timeStaked = block.timestamp - stakes[msg.sender].lastRewardClaim;
            uint256 calculatedRewards = (stakedAmount * pool.rewardRate * timeStaked) / 1e18;
            
            if (amount > calculatedRewards) {
                amount = calculatedRewards;
            }
        }
        
        require(usdcToken.transfer(msg.sender, amount), "Transfer failed");
        
        pool.distributedRewards += amount;
        totalRewardsDistributed += amount;
        totalRewardClaims++;
        
        if (stakes[msg.sender].staker != address(0)) {
            stakes[msg.sender].lastRewardClaim = block.timestamp;
            stakes[msg.sender].totalRewardsClaimed += amount;
        }
        
        rewardClaims[totalRewardClaims] = RewardClaim({
            recipient: msg.sender,
            amount: amount,
            poolId: poolId,
            claimedAt: block.timestamp
        });
        
        userRewardClaims[msg.sender].push(totalRewardClaims);
        
        emit RewardsClaimed(msg.sender, amount, poolId);
    }
    
    /**
     * @dev Calculate pending rewards for a staker
     * @param staker Address of the staker
     * @param poolId The pool ID
     * @return Pending rewards amount
     */
    function calculatePendingRewards(address staker, uint256 poolId) 
        external 
        view 
        validPool(poolId) 
        returns (uint256) 
    {
        if (stakes[staker].staker == address(0)) {
            return 0;
        }
        
        RewardPool memory pool = rewardPools[poolId];
        if (!pool.isActive || block.timestamp < pool.startTime || block.timestamp > pool.endTime) {
            return 0;
        }
        
        uint256 stakedAmount = stakes[staker].amount;
        uint256 timeStaked = block.timestamp - stakes[staker].lastRewardClaim;
        uint256 pendingRewards = (stakedAmount * pool.rewardRate * timeStaked) / 1e18;
        
        // Ensure we don't exceed pool limits
        uint256 availableRewards = pool.totalRewards - pool.distributedRewards;
        if (pendingRewards > availableRewards) {
            pendingRewards = availableRewards;
        }
        
        return pendingRewards;
    }
    
    /**
     * @dev Deactivate a reward pool
     * @param poolId The pool ID
     */
    function deactivatePool(uint256 poolId) external onlyOwner validPool(poolId) {
        rewardPools[poolId].isActive = false;
        
        emit PoolDeactivated(poolId);
    }
    
    /**
     * @dev Update minimum stake amount
     * @param newMinAmount New minimum stake amount
     */
    function setMinStakeAmount(uint256 newMinAmount) external onlyOwner {
        require(newMinAmount > 0, "Invalid amount");
        minStakeAmount = newMinAmount;
    }
    
    /**
     * @dev Update staking lock period
     * @param newLockPeriod New lock period in seconds
     */
    function setStakingLockPeriod(uint256 newLockPeriod) external onlyOwner {
        stakingLockPeriod = newLockPeriod;
    }
    
    // View functions
    
    /**
     * @dev Get pool information
     * @param poolId The pool ID
     * @return RewardPool struct
     */
    function getPool(uint256 poolId) external view returns (RewardPool memory) {
        require(rewardPools[poolId].poolId != 0, "Pool does not exist");
        return rewardPools[poolId];
    }
    
    /**
     * @dev Get stake information
     * @param staker Address of the staker
     * @return Stake struct
     */
    function getStake(address staker) external view returns (Stake memory) {
        return stakes[staker];
    }
    
    /**
     * @dev Get reward claim information
     * @param claimId The claim ID
     * @return RewardClaim struct
     */
    function getRewardClaim(uint256 claimId) external view returns (RewardClaim memory) {
        require(rewardClaims[claimId].recipient != address(0), "Claim does not exist");
        return rewardClaims[claimId];
    }
    
    /**
     * @dev Get reward claims for a user
     * @param user Address of the user
     * @return Array of claim IDs
     */
    function getUserRewardClaims(address user) external view returns (uint256[] memory) {
        return userRewardClaims[user];
    }
    
    /**
     * @dev Get total number of pools
     * @return Total pools count
     */
    function getTotalPools() external view returns (uint256) {
        return totalPools;
    }
    
    /**
     * @dev Get total number of stakers
     * @return Total stakers count
     */
    function getTotalStakers() external view returns (uint256) {
        return stakerList.length;
    }
    
    /**
     * @dev Emergency function to recover USDC
     * @param amount Amount to recover
     */
    function emergencyRecoverUSDC(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            usdcToken.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        require(usdcToken.transfer(owner(), amount), "Transfer failed");
    }
}

