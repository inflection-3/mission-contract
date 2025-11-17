// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IUSDC.sol";
import "./interfaces/IMission.sol";
import "./INXRewardManager.sol";
import "./StablecoinSettlement.sol";
import "./IdentityLayer.sol";

/**
 * @title Mission
 * @dev Individual mission contract that manages applications, interactions, and rewards
 */
contract Mission is IMission, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    IUSDC public usdcToken;
    INXRewardManager public rewardManager;
    StablecoinSettlement public settlement;
    IdentityLayer public identityLayer;
    
    // Reward type enum
    enum RewardType {
        INX_POINTS,
        USDC
    }
    
    RewardType public rewardType; // Default reward type for this mission
    uint256 public rewardPoolId; // Reward pool ID from INXRewardManager (if using INX points)
    
    uint256 public applicationCount;
    uint256 public interactionCount;
    uint256 public totalRewardPool;
    uint256 public distributedRewards;
    bool public rewardsDistributed;
    
    // Merkle tree for participant verification
    bytes32 public participantsMerkleRoot;
    mapping(address => bool) public hasClaimedReward;
    
    mapping(uint256 => Application) public applications;
    mapping(uint256 => Interaction) public interactions;
    
    event ApplicationAdded(uint256 indexed applicationId, string name, address owner);
    event InteractionAdded(uint256 indexed interactionId, uint256 applicationId, string title);
    event ParticipantsMerkleRootUpdated(bytes32 indexed newMerkleRoot);
    event RewardsDeposited(uint256 amount, uint256 totalPool);
    event RewardsDistributed(uint256 totalRewardPool, RewardType rewardType);
    event RewardClaimed(address indexed user, uint256 amount, uint256 missionExecutionId, RewardType rewardType);
    event RewardContractsSet(address indexed rewardManager, address indexed settlement, address indexed identityLayer);
    event RewardTypeSet(RewardType rewardType, uint256 rewardPoolId);
    
    modifier onlyValidApplication(uint256 applicationId) {
        require(applications[applicationId].id != 0, "Application does not exist");
        require(applications[applicationId].isActive, "Application is not active");
        _;
    }
    
    modifier onlyValidInteraction(uint256 interactionId) {
        require(interactions[interactionId].id != 0, "Interaction does not exist");
        require(interactions[interactionId].isActive, "Interaction is not active");
        _;
    }
    
    modifier validMerkleRoot() {
        require(participantsMerkleRoot != bytes32(0), "Merkle root not set");
        _;
    }
    
    modifier rewardsNotDistributed() {
        require(!rewardsDistributed, "Rewards already distributed");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _usdcToken) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        usdcToken = IUSDC(_usdcToken);
        rewardType = RewardType.USDC; // Default to USDC
    }
    
    /**
     * @dev Set reward manager, settlement, and identity layer contracts
     * @param _rewardManager Address of INXRewardManager
     * @param _settlement Address of StablecoinSettlement
     * @param _identityLayer Address of IdentityLayer
     */
    function setRewardContracts(
        address _rewardManager,
        address _settlement,
        address _identityLayer
    ) external onlyOwner {
        if (_rewardManager != address(0)) {
            rewardManager = INXRewardManager(_rewardManager);
        }
        if (_settlement != address(0)) {
            settlement = StablecoinSettlement(_settlement);
        }
        if (_identityLayer != address(0)) {
            identityLayer = IdentityLayer(_identityLayer);
        }
        
        emit RewardContractsSet(_rewardManager, _settlement, _identityLayer);
    }
    
    /**
     * @dev Set reward type and pool ID for this mission
     * @param _rewardType Type of reward (INX_POINTS or USDC)
     * @param _rewardPoolId Reward pool ID from INXRewardManager (if using INX points)
     */
    function setRewardType(RewardType _rewardType, uint256 _rewardPoolId) external onlyOwner {
        if (_rewardType == RewardType.INX_POINTS) {
            require(address(rewardManager) != address(0), "RewardManager not set");
            require(_rewardPoolId > 0, "Invalid reward pool ID");
        }
        rewardType = _rewardType;
        rewardPoolId = _rewardPoolId;
        
        emit RewardTypeSet(_rewardType, _rewardPoolId);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    /**
     * @dev Add a new application to the mission
     */
    function addApplication(
        string memory name,
        string memory description,
        string memory appUrl,
        string memory bannerImage,
        string memory appLogo
    ) external onlyOwner {
        applicationCount++;
        applications[applicationCount] = Application({
            id: applicationCount,
            name: name,
            description: description,
            appUrl: appUrl,
            bannerImage: bannerImage,
            appLogo: appLogo,
            isActive: true,
            owner: msg.sender
        });
        
        emit ApplicationAdded(applicationCount, name, msg.sender);
    }
    
    /**
     * @dev Add a new interaction to an application
     */
    function addInteraction(
        uint256 applicationId,
        string memory title,
        string memory description,
        string memory actionTitle,
        string memory interactionUrl,
        uint256 rewardAmount
    ) external onlyOwner onlyValidApplication(applicationId) {
        interactionCount++;
        interactions[interactionCount] = Interaction({
            id: interactionCount,
            applicationId: applicationId,
            title: title,
            description: description,
            actionTitle: actionTitle,
            interactionUrl: interactionUrl,
            isActive: true,
            rewardAmount: rewardAmount
        });
        
        emit InteractionAdded(interactionCount, applicationId, title);
    }
    
    /**
     * @dev Update the Merkle root for participants verification
     * @param newMerkleRoot The new Merkle root containing participant data
     */
    function updateParticipantsMerkleRoot(bytes32 newMerkleRoot) external onlyOwner {
        require(newMerkleRoot != bytes32(0), "Invalid Merkle root");
        participantsMerkleRoot = newMerkleRoot;
        emit ParticipantsMerkleRootUpdated(newMerkleRoot);
    }
    
    /**
     * @dev Verify if a participant is included in the Merkle tree
     * @param participant The participant's address
     * @param missionExecutionId The mission execution ID from your server
     * @param proof The Merkle proof for verification
     * @return bool True if the participant is verified, false otherwise
     */
    function verifyParticipant(
        address participant,
        uint256 missionExecutionId,
        bytes32[] calldata proof
    ) public view validMerkleRoot returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(participant, missionExecutionId));
        return MerkleProof.verify(proof, participantsMerkleRoot, leaf);
    }
    
    /**
     * @dev Deposit USDC rewards into the mission contract
     */
    function depositRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        totalRewardPool += amount;
        
        emit RewardsDeposited(amount, totalRewardPool);
    }
    
    /**
     * @dev Mark rewards as distributed and ready for claiming
     * For USDC: Creates a settlement batch for all participants
     * For INX: Uses reward manager to distribute points
     */
    function distributeRewards() external onlyOwner rewardsNotDistributed validMerkleRoot {
        require(totalRewardPool > 0, "No rewards to distribute");
        
        if (rewardType == RewardType.USDC) {
            require(
                usdcToken.balanceOf(address(this)) >= totalRewardPool,
                "Insufficient USDC balance"
            );
            // Note: Individual claims will be handled via claimReward
            // This just marks rewards as ready
        } else {
            require(address(rewardManager) != address(0), "RewardManager not set");
            require(rewardPoolId > 0, "Reward pool ID not set");
            // INX rewards will be distributed via batch distribution
        }
        
        distributedRewards = totalRewardPool;
        rewardsDistributed = true;
        
        emit RewardsDistributed(totalRewardPool, rewardType);
    }
    
    /**
     * @dev Batch distribute rewards to multiple participants
     * @param recipients Array of participant addresses
     * @param amounts Array of reward amounts
     */
    function batchDistributeRewards(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner rewardsNotDistributed validMerkleRoot {
        require(recipients.length == amounts.length, "Array length mismatch");
        require(totalRewardPool > 0, "No rewards to distribute");
        
        uint256 totalAmount = _calculateTotal(amounts);
        require(totalAmount <= totalRewardPool, "Exceeds total reward pool");
        
        if (rewardType == RewardType.USDC) {
            _distributeUSDC(recipients, amounts, totalAmount);
        } else {
            _distributeINX(recipients, amounts);
        }
        
        distributedRewards = totalAmount;
        rewardsDistributed = true;
        
        emit RewardsDistributed(totalAmount, rewardType);
    }
    
    /**
     * @dev Internal function to calculate total amount
     */
    function _calculateTotal(uint256[] calldata amounts) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }
    
    /**
     * @dev Internal function to distribute USDC rewards
     */
    function _distributeUSDC(
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256 totalAmount
    ) internal {
        require(address(settlement) != address(0), "Settlement not set");
        require(
            usdcToken.balanceOf(address(this)) >= totalAmount,
            "Insufficient USDC balance"
        );
        
        bytes32 metadataHash = keccak256(abi.encodePacked("mission_rewards", block.timestamp));
        uint256 settlementId = settlement.createSettlement(
            recipients,
            amounts,
            "mission_rewards",
            metadataHash
        );
        settlement.executeSettlement(settlementId);
        
        _updateIdentityLayer(recipients, amounts, true);
    }
    
    /**
     * @dev Internal function to distribute INX rewards
     */
    function _distributeINX(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) internal {
        require(address(rewardManager) != address(0), "RewardManager not set");
        require(rewardPoolId > 0, "Reward pool ID not set");
        
        rewardManager.distributeRewards(rewardPoolId, recipients, amounts);
        _updateIdentityLayer(recipients, amounts, false);
    }
    
    /**
     * @dev Internal function to update IdentityLayer
     */
    function _updateIdentityLayer(
        address[] calldata recipients,
        uint256[] calldata amounts,
        bool recordTransaction
    ) internal {
        if (address(identityLayer) == address(0)) return;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            identityLayer.updateRewardsEarned(recipients[i], amounts[i]);
            if (recordTransaction) {
                identityLayer.recordTransaction(recipients[i], amounts[i], true);
            }
        }
    }
    
    /**
     * @dev Allow participants to claim their rewards using Merkle proof
     * @param missionExecutionId The mission execution ID from your server
     * @param rewardAmount The reward amount for this participant
     * @param proof The Merkle proof for verification
     */
    function claimReward(
        uint256 missionExecutionId,
        uint256 rewardAmount,
        bytes32[] calldata proof
    ) external nonReentrant {
        require(rewardsDistributed, "Rewards not yet distributed");
        require(!hasClaimedReward[msg.sender], "Already claimed");
        require(rewardAmount > 0, "No reward to claim");
        
        // Verify the participant using Merkle proof
        require(
            verifyParticipant(msg.sender, missionExecutionId, proof),
            "Invalid Merkle proof"
        );
        
        hasClaimedReward[msg.sender] = true;
        
        if (rewardType == RewardType.USDC) {
            require(
                usdcToken.balanceOf(address(this)) >= rewardAmount,
                "Insufficient USDC balance"
            );
            require(usdcToken.transfer(msg.sender, rewardAmount), "Transfer failed");
            
            // Update IdentityLayer
            if (address(identityLayer) != address(0)) {
                identityLayer.updateRewardsEarned(msg.sender, rewardAmount);
                identityLayer.recordTransaction(msg.sender, rewardAmount, true);
            }
        } else {
            // For INX points, claim from reward manager
            require(address(rewardManager) != address(0), "RewardManager not set");
            require(rewardPoolId > 0, "Reward pool ID not set");
            
            // Claim from reward manager
            rewardManager.claimRewards(rewardPoolId, rewardAmount);
            
            // Update IdentityLayer
            if (address(identityLayer) != address(0)) {
                identityLayer.updateRewardsEarned(msg.sender, rewardAmount);
            }
        }
        
        emit RewardClaimed(msg.sender, rewardAmount, missionExecutionId, rewardType);
    }
    
    /**
     * @dev Deactivate an application
     */
    function deactivateApplication(uint256 applicationId) external onlyOwner onlyValidApplication(applicationId) {
        applications[applicationId].isActive = false;
    }
    
    /**
     * @dev Deactivate an interaction
     */
    function deactivateInteraction(uint256 interactionId) external onlyOwner onlyValidInteraction(interactionId) {
        interactions[interactionId].isActive = false;
    }
    
    // View functions
    
    function getApplication(uint256 id) external view returns (Application memory) {
        require(applications[id].id != 0, "Application does not exist");
        return applications[id];
    }
    
    function getInteraction(uint256 id) external view returns (Interaction memory) {
        require(interactions[id].id != 0, "Interaction does not exist");
        return interactions[id];
    }
    
    function getTotalRewardPool() external view returns (uint256) {
        return totalRewardPool;
    }
    
    function getRemainingRewardPool() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }
    
    function getApplicationCount() external view returns (uint256) {
        return applicationCount;
    }
    
    function getInteractionCount() external view returns (uint256) {
        return interactionCount;
    }
    
    function getParticipantsMerkleRoot() external view returns (bytes32) {
        return participantsMerkleRoot;
    }
    
    function hasUserClaimedReward(address user) external view returns (bool) {
        return hasClaimedReward[user];
    }
}
