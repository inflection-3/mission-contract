// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUSDC.sol";
import "./IdentityLayer.sol";
import "./INXRewardManager.sol";
import "./StablecoinSettlement.sol";

/**
 * @title MinerIncentive
 * @dev Manages incentives for miners who onboard new people in different geographies
 * Tracks miner onboarding contributions by geography and distributes rewards
 */
contract MinerIncentive is Ownable, ReentrancyGuard {
    IUSDC public immutable usdcToken;
    IdentityLayer public identityLayer;
    INXRewardManager public rewardManager;
    StablecoinSettlement public settlement;
    
    // Reward type enum
    enum RewardType {
        INX_POINTS,
        USDC
    }
    
    struct Miner {
        address minerAddress;
        uint256 totalContributions;
        uint256 totalPeopleOnboarded; // Total number of people onboarded
        uint256 totalRewardsEarned;
        uint256 lastRewardClaim;
        bool isActive;
        uint256 registeredAt;
        string[] geographies; // Geographies where miner operates
    }
    
    struct Contribution {
        uint256 contributionId;
        address miner;
        uint256 amount; // Contribution value/weight
        uint256 peopleOnboarded; // Number of people onboarded in this contribution
        string geography; // Geography code (e.g., "US", "EU", "ASIA", "AFRICA")
        string contributionType; // e.g., "onboarding", "referral", "community_building"
        bytes32 proofHash; // Hash of proof of contribution (e.g., list of onboarded addresses)
        uint256 timestamp;
        bool isVerified;
    }
    
    struct IncentivePool {
        uint256 poolId;
        string poolName;
        uint256 totalAllocated;
        uint256 totalDistributed;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }
    
    mapping(address => Miner) public miners;
    mapping(uint256 => Contribution) public contributions;
    mapping(uint256 => IncentivePool) public incentivePools;
    
    // Track contributions by miner
    mapping(address => uint256[]) public minerContributions;
    // Track contributions by pool
    mapping(uint256 => uint256[]) public poolContributions;
    // Track contributions by geography
    mapping(string => uint256[]) public geographyContributions;
    // Track miners by geography
    mapping(string => address[]) public geographyMiners;
    
    // Miner addresses for iteration
    address[] public minerList;
    
    uint256 public totalContributions;
    uint256 public totalPools;
    uint256 public totalRewardsDistributed;
    
    // Configuration
    uint256 public minContributionAmount;
    uint256 public rewardMultiplier; // Basis points (10000 = 100%)
    
    event MinerRegistered(address indexed miner, uint256 timestamp);
    event MinerDeactivated(address indexed miner);
    event ContributionRecorded(
        uint256 indexed contributionId,
        address indexed miner,
        uint256 amount,
        uint256 peopleOnboarded,
        string geography,
        string contributionType
    );
    event ContributionVerified(uint256 indexed contributionId);
    event IncentivePoolCreated(
        uint256 indexed poolId,
        string poolName,
        uint256 totalAllocated,
        uint256 startTime,
        uint256 endTime
    );
    event RewardsDistributed(
        address indexed miner,
        uint256 amount,
        uint256 poolId
    );
    event RewardsClaimed(address indexed miner, uint256 amount);
    event PoolFunded(uint256 indexed poolId, uint256 amount);
    
    modifier onlyActiveMiner(address miner) {
        require(miners[miner].isActive, "Miner not active");
        _;
    }
    
    modifier validPool(uint256 poolId) {
        require(incentivePools[poolId].poolId != 0, "Invalid pool");
        _;
    }
    
    modifier onlyActivePool(uint256 poolId) {
        require(incentivePools[poolId].isActive, "Pool not active");
        require(
            block.timestamp >= incentivePools[poolId].startTime &&
            block.timestamp <= incentivePools[poolId].endTime,
            "Pool not in active period"
        );
        _;
    }
    
    constructor(
        address _usdcToken,
        address _identityLayer,
        address _rewardManager,
        address _settlement
    ) Ownable(msg.sender) {
        require(_usdcToken != address(0), "Invalid USDC address");
        require(_identityLayer != address(0), "Invalid IdentityLayer address");
        require(_rewardManager != address(0), "Invalid RewardManager address");
        require(_settlement != address(0), "Invalid Settlement address");
        
        usdcToken = IUSDC(_usdcToken);
        identityLayer = IdentityLayer(_identityLayer);
        rewardManager = INXRewardManager(_rewardManager);
        settlement = StablecoinSettlement(_settlement);
        
        minContributionAmount = 1; // Minimum contribution amount
        rewardMultiplier = 10000; // 100% default multiplier
    }
    
    /**
     * @dev Set the IdentityLayer contract address
     */
    function setIdentityLayer(address _identityLayer) external onlyOwner {
        require(_identityLayer != address(0), "Invalid address");
        identityLayer = IdentityLayer(_identityLayer);
    }
    
    /**
     * @dev Set the RewardManager contract address
     */
    function setRewardManager(address _rewardManager) external onlyOwner {
        require(_rewardManager != address(0), "Invalid address");
        rewardManager = INXRewardManager(_rewardManager);
    }
    
    /**
     * @dev Set the Settlement contract address
     */
    function setSettlement(address _settlement) external onlyOwner {
        require(_settlement != address(0), "Invalid address");
        settlement = StablecoinSettlement(_settlement);
    }
    
    /**
     * @dev Register a new miner
     * @param minerAddress Address of the miner
     */
    function registerMiner(address minerAddress) external onlyOwner {
        require(minerAddress != address(0), "Invalid miner address");
        require(miners[minerAddress].registeredAt == 0, "Miner already registered");
        
        miners[minerAddress] = Miner({
            minerAddress: minerAddress,
            totalContributions: 0,
            totalPeopleOnboarded: 0,
            totalRewardsEarned: 0,
            lastRewardClaim: 0,
            isActive: true,
            registeredAt: block.timestamp,
            geographies: new string[](0)
        });
        
        minerList.push(minerAddress);
        
        emit MinerRegistered(minerAddress, block.timestamp);
    }
    
    /**
     * @dev Deactivate a miner
     * @param minerAddress Address of the miner
     */
    function deactivateMiner(address minerAddress) external onlyOwner {
        require(miners[minerAddress].registeredAt != 0, "Miner not registered");
        miners[minerAddress].isActive = false;
        
        emit MinerDeactivated(minerAddress);
    }
    
    /**
     * @dev Record a contribution from a miner for onboarding people in a geography
     * @param miner Address of the miner
     * @param amount Contribution amount/value (based on number of people onboarded)
     * @param peopleOnboarded Number of people onboarded in this contribution
     * @param geography Geography code where onboarding occurred (e.g., "US", "EU", "ASIA")
     * @param contributionType Type of contribution (e.g., "onboarding", "referral")
     * @param proofHash Hash of proof of contribution (e.g., hash of onboarded addresses list)
     * @param poolId Pool ID this contribution belongs to
     */
    function recordContribution(
        address miner,
        uint256 amount,
        uint256 peopleOnboarded,
        string memory geography,
        string memory contributionType,
        bytes32 proofHash,
        uint256 poolId
    ) external onlyOwner onlyActiveMiner(miner) validPool(poolId) onlyActivePool(poolId) {
        require(amount >= minContributionAmount, "Contribution too small");
        require(peopleOnboarded > 0, "Must onboard at least one person");
        require(bytes(geography).length > 0, "Invalid geography");
        require(bytes(contributionType).length > 0, "Invalid contribution type");
        require(proofHash != bytes32(0), "Invalid proof hash");
        
        totalContributions++;
        
        contributions[totalContributions] = Contribution({
            contributionId: totalContributions,
            miner: miner,
            amount: amount,
            peopleOnboarded: peopleOnboarded,
            geography: geography,
            contributionType: contributionType,
            proofHash: proofHash,
            timestamp: block.timestamp,
            isVerified: false
        });
        
        miners[miner].totalContributions += amount;
        miners[miner].totalPeopleOnboarded += peopleOnboarded;
        minerContributions[miner].push(totalContributions);
        poolContributions[poolId].push(totalContributions);
        geographyContributions[geography].push(totalContributions);
        
        // Track miner in geography if not already tracked
        bool geographyExists = false;
        for (uint256 i = 0; i < miners[miner].geographies.length; i++) {
            if (keccak256(bytes(miners[miner].geographies[i])) == keccak256(bytes(geography))) {
                geographyExists = true;
                break;
            }
        }
        if (!geographyExists) {
            miners[miner].geographies.push(geography);
            geographyMiners[geography].push(miner);
        }
        
        // Update IdentityLayer reputation metrics
        if (address(identityLayer) != address(0)) {
            identityLayer.updateOnboardingCount(miner, peopleOnboarded);
            identityLayer.updateContributionsCount(miner, 1);
        }
        
        emit ContributionRecorded(
            totalContributions, 
            miner, 
            amount, 
            peopleOnboarded, 
            geography, 
            contributionType
        );
    }
    
    /**
     * @dev Verify a contribution
     * @param contributionId The contribution ID
     */
    function verifyContribution(uint256 contributionId) external onlyOwner {
        Contribution storage contribution = contributions[contributionId];
        require(contribution.contributionId != 0, "Contribution does not exist");
        require(!contribution.isVerified, "Contribution already verified");
        
        contribution.isVerified = true;
        
        emit ContributionVerified(contributionId);
    }
    
    /**
     * @dev Create a new incentive pool
     * @param poolName Name of the pool
     * @param totalAllocated Total amount allocated for this pool
     * @param startTime Start time of the pool
     * @param endTime End time of the pool
     */
    function createIncentivePool(
        string memory poolName,
        uint256 totalAllocated,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner returns (uint256 poolId) {
        require(bytes(poolName).length > 0, "Invalid pool name");
        require(totalAllocated > 0, "Invalid allocation amount");
        require(startTime < endTime, "Invalid time range");
        require(endTime > block.timestamp, "End time must be in future");
        
        totalPools++;
        poolId = totalPools;
        
        incentivePools[poolId] = IncentivePool({
            poolId: poolId,
            poolName: poolName,
            totalAllocated: totalAllocated,
            totalDistributed: 0,
            startTime: startTime,
            endTime: endTime,
            isActive: true
        });
        
        emit IncentivePoolCreated(poolId, poolName, totalAllocated, startTime, endTime);
    }
    
    /**
     * @dev Fund an incentive pool with USDC
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
        
        incentivePools[poolId].totalAllocated += amount;
        
        emit PoolFunded(poolId, amount);
    }
    
    /**
     * @dev Distribute rewards to miners based on their contributions
     * @param poolId The pool ID
     * @param minerAddresses Array of miner addresses
     * @param rewardAmounts Array of reward amounts for each miner
     * @param rewardType Type of reward (INX_POINTS or USDC)
     * @param rewardPoolId Reward pool ID from INXRewardManager (if using INX points)
     */
    function distributeRewards(
        uint256 poolId,
        address[] calldata minerAddresses,
        uint256[] calldata rewardAmounts,
        RewardType rewardType,
        uint256 rewardPoolId
    ) external onlyOwner validPool(poolId) nonReentrant {
        require(minerAddresses.length == rewardAmounts.length, "Array length mismatch");
        
        IncentivePool storage pool = incentivePools[poolId];
        require(pool.isActive, "Pool not active");
        
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < rewardAmounts.length; i++) {
            totalRewards += rewardAmounts[i];
        }
        
        require(
            pool.totalDistributed + totalRewards <= pool.totalAllocated,
            "Exceeds pool allocation"
        );
        
        if (rewardType == RewardType.USDC) {
            // Use StablecoinSettlement for USDC rewards
            require(
                usdcToken.balanceOf(address(this)) >= totalRewards,
                "Insufficient USDC balance"
            );
            
            // Create settlement for batch distribution
            bytes32 metadataHash = keccak256(abi.encodePacked("miner_rewards", poolId, block.timestamp));
            uint256 settlementId = settlement.createSettlement(
                minerAddresses,
                rewardAmounts,
                "miner_rewards",
                metadataHash
            );
            
            // Execute settlement immediately
            settlement.executeSettlement(settlementId);
            
            // Update miner stats and IdentityLayer
            for (uint256 i = 0; i < minerAddresses.length; i++) {
                address miner = minerAddresses[i];
                uint256 amount = rewardAmounts[i];
                
                if (amount > 0 && miners[miner].isActive) {
                    miners[miner].totalRewardsEarned += amount;
                    miners[miner].lastRewardClaim = block.timestamp;
                    
                    // Update IdentityLayer
                    if (address(identityLayer) != address(0)) {
                        identityLayer.updateRewardsEarned(miner, amount);
                        identityLayer.recordTransaction(miner, amount, true);
                    }
                    
                    emit RewardsDistributed(miner, amount, poolId);
                }
            }
            
            pool.totalDistributed += totalRewards;
            totalRewardsDistributed += totalRewards;
        } else {
            // Use INXRewardManager for INX points
            require(address(rewardManager) != address(0), "RewardManager not set");
            
            // Distribute through reward manager
            rewardManager.distributeRewards(
                rewardPoolId,
                minerAddresses,
                rewardAmounts
            );
            
            // Update miner stats and IdentityLayer
            for (uint256 i = 0; i < minerAddresses.length; i++) {
                address miner = minerAddresses[i];
                uint256 amount = rewardAmounts[i];
                
                if (amount > 0 && miners[miner].isActive) {
                    miners[miner].totalRewardsEarned += amount;
                    miners[miner].lastRewardClaim = block.timestamp;
                    
                    // Update IdentityLayer (treat INX points as rewards)
                    if (address(identityLayer) != address(0)) {
                        identityLayer.updateRewardsEarned(miner, amount);
                    }
                    
                    emit RewardsDistributed(miner, amount, poolId);
                }
            }
            
            pool.totalDistributed += totalRewards;
            totalRewardsDistributed += totalRewards;
        }
    }
    
    /**
     * @dev Allow miners to claim their rewards
     * @param amount Amount to claim
     */
    function claimRewards(uint256 amount) external onlyActiveMiner(msg.sender) nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            usdcToken.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        
        Miner storage miner = miners[msg.sender];
        require(miner.totalRewardsEarned >= amount, "Insufficient rewards");
        
        require(usdcToken.transfer(msg.sender, amount), "Transfer failed");
        
        miner.totalRewardsEarned -= amount;
        miner.lastRewardClaim = block.timestamp;
        totalRewardsDistributed += amount;
        
        emit RewardsClaimed(msg.sender, amount);
    }
    
    /**
     * @dev Update minimum contribution amount
     * @param newMinAmount New minimum contribution amount
     */
    function setMinContributionAmount(uint256 newMinAmount) external onlyOwner {
        require(newMinAmount > 0, "Invalid amount");
        minContributionAmount = newMinAmount;
    }
    
    /**
     * @dev Update reward multiplier
     * @param newMultiplier New multiplier in basis points
     */
    function setRewardMultiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier > 0 && newMultiplier <= 100000, "Invalid multiplier");
        rewardMultiplier = newMultiplier;
    }
    
    /**
     * @dev Deactivate a pool
     * @param poolId The pool ID
     */
    function deactivatePool(uint256 poolId) external onlyOwner validPool(poolId) {
        incentivePools[poolId].isActive = false;
    }
    
    // View functions
    
    /**
     * @dev Get miner information
     * @param minerAddress Address of the miner
     * @return Miner struct
     */
    function getMiner(address minerAddress) external view returns (Miner memory) {
        require(miners[minerAddress].registeredAt != 0, "Miner not registered");
        return miners[minerAddress];
    }
    
    /**
     * @dev Get contribution information
     * @param contributionId The contribution ID
     * @return Contribution struct
     */
    function getContribution(uint256 contributionId) external view returns (Contribution memory) {
        require(contributions[contributionId].contributionId != 0, "Contribution does not exist");
        return contributions[contributionId];
    }
    
    /**
     * @dev Get pool information
     * @param poolId The pool ID
     * @return IncentivePool struct
     */
    function getPool(uint256 poolId) external view returns (IncentivePool memory) {
        require(incentivePools[poolId].poolId != 0, "Pool does not exist");
        return incentivePools[poolId];
    }
    
    /**
     * @dev Get contributions for a miner
     * @param minerAddress Address of the miner
     * @return Array of contribution IDs
     */
    function getMinerContributions(address minerAddress) external view returns (uint256[] memory) {
        return minerContributions[minerAddress];
    }
    
    /**
     * @dev Get contributions for a pool
     * @param poolId The pool ID
     * @return Array of contribution IDs
     */
    function getPoolContributions(uint256 poolId) external view returns (uint256[] memory) {
        return poolContributions[poolId];
    }
    
    /**
     * @dev Get contributions for a geography
     * @param geography Geography code
     * @return Array of contribution IDs
     */
    function getGeographyContributions(string memory geography) external view returns (uint256[] memory) {
        return geographyContributions[geography];
    }
    
    /**
     * @dev Get miners operating in a geography
     * @param geography Geography code
     * @return Array of miner addresses
     */
    function getGeographyMiners(string memory geography) external view returns (address[] memory) {
        return geographyMiners[geography];
    }
    
    /**
     * @dev Get geographies where a miner operates
     * @param minerAddress Address of the miner
     * @return Array of geography codes
     */
    function getMinerGeographies(address minerAddress) external view returns (string[] memory) {
        require(miners[minerAddress].registeredAt != 0, "Miner not registered");
        return miners[minerAddress].geographies;
    }
    
    /**
     * @dev Get total number of people onboarded by a miner
     * @param minerAddress Address of the miner
     * @return Total people onboarded
     */
    function getMinerOnboardedCount(address minerAddress) external view returns (uint256) {
        require(miners[minerAddress].registeredAt != 0, "Miner not registered");
        return miners[minerAddress].totalPeopleOnboarded;
    }
    
    /**
     * @dev Get total number of registered miners
     * @return Total miners count
     */
    function getTotalMiners() external view returns (uint256) {
        return minerList.length;
    }
    
    /**
     * @dev Get statistics for a geography
     * @param geography Geography code
     * @return totalContributions Total contributions in this geography
     * @return totalPeopleOnboarded Total people onboarded in this geography
     * @return minerCount Number of miners operating in this geography
     */
    function getGeographyStats(string memory geography) 
        external 
        view 
        returns (
            uint256 totalContributions,
            uint256 totalPeopleOnboarded,
            uint256 minerCount
        ) 
    {
        uint256[] memory contribs = geographyContributions[geography];
        totalContributions = contribs.length;
        minerCount = geographyMiners[geography].length;
        
        for (uint256 i = 0; i < contribs.length; i++) {
            if (contributions[contribs[i]].isVerified) {
                totalPeopleOnboarded += contributions[contribs[i]].peopleOnboarded;
            }
        }
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

