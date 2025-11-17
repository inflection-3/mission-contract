// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./MissionFactory.sol";
import "./Mission.sol";
import "./interfaces/IUSDC.sol";
import "./interfaces/IMission.sol";

/**
 * @title MissionManager
 * @dev Main contract that manages the Mission Factory system
 * This contract acts as a central hub for managing missions and their lifecycle
 */
contract MissionManager is Ownable {
    MissionFactory public immutable missionFactory;
    IUSDC public immutable usdcToken;
    
    struct MissionInfo {
        uint256 missionId;
        address missionAddress;
        string name;
        string description;
        bool isActive;
        uint256 totalRewards;
    }
    
    mapping(uint256 => MissionInfo) public missionInfo;
    mapping(address => uint256[]) public userMissions;
    uint256 public totalMissions;
    
    event MissionRegistered(uint256 indexed missionId, address indexed missionAddress, string name);
    event MissionDeactivated(uint256 indexed missionId);
    event UserJoinedMission(address indexed user, uint256 indexed missionId);
    
    constructor(address _usdcToken, address _missionFactory) Ownable(msg.sender) {
        usdcToken = IUSDC(_usdcToken);
        missionFactory = MissionFactory(_missionFactory);
    }
    
    /**
     * @dev Create a new mission and register it
     */
    function createMission(string memory name, string memory description) external onlyOwner returns (uint256 missionId, address missionAddress) {
        // Create mission through factory (factory owner will be the owner initially)
        missionAddress = missionFactory.createMission();
        missionId = missionFactory.getMissionCount();
        
        // Transfer ownership of the mission to this contract
        Mission mission = Mission(missionAddress);
        mission.transferOwnership(address(this));
        
        missionInfo[missionId] = MissionInfo({
            missionId: missionId,
            missionAddress: missionAddress,
            name: name,
            description: description,
            isActive: true,
            totalRewards: 0
        });
        
        totalMissions++;
        
        emit MissionRegistered(missionId, missionAddress, name);
        
        return (missionId, missionAddress);
    }
    
    /**
     * @dev Add an application to a mission
     */
    function addApplicationToMission(
        uint256 missionId,
        string memory appName,
        string memory appDescription,
        string memory appUrl,
        string memory bannerImage,
        string memory appLogo
    ) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        // Use delegatecall or direct call since this contract owns the mission
        mission.addApplication(appName, appDescription, appUrl, bannerImage, appLogo);
    }
    
    /**
     * @dev Add an interaction to a mission application
     */
    function addInteractionToMission(
        uint256 missionId,
        uint256 applicationId,
        string memory title,
        string memory description,
        string memory actionTitle,
        string memory interactionUrl,
        uint256 rewardAmount
    ) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        mission.addInteraction(applicationId, title, description, actionTitle, interactionUrl, rewardAmount);
    }
    
    /**
     * @dev Update the Merkle root for a mission's participants
     */
    function updateMissionParticipantsMerkleRoot(
        uint256 missionId,
        bytes32 merkleRoot
    ) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        mission.updateParticipantsMerkleRoot(merkleRoot);
    }
    
    /**
     * @dev Deposit USDC rewards into a mission
     */
    function depositRewardsToMission(uint256 missionId, uint256 amount) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        require(amount > 0, "Amount must be greater than 0");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        
        // Transfer USDC from this contract to the mission
        require(usdcToken.transfer(missionInfo[missionId].missionAddress, amount), "Transfer failed");
        
        // Update mission info
        missionInfo[missionId].totalRewards += amount;
    }
    
    /**
     * @dev Distribute rewards for a mission
     */
    function distributeRewardsForMission(uint256 missionId) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        mission.distributeRewards();
    }
    
    /**
     * @dev Batch distribute rewards for a mission
     * @param missionId The mission ID
     * @param recipients Array of recipient addresses
     * @param amounts Array of reward amounts
     */
    function batchDistributeRewardsForMission(
        uint256 missionId,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        mission.batchDistributeRewards(recipients, amounts);
    }
    
    /**
     * @dev Set reward contracts for a mission
     * @param missionId The mission ID
     * @param rewardManager Address of INXRewardManager
     * @param settlement Address of StablecoinSettlement
     * @param identityLayer Address of IdentityLayer
     */
    function setMissionRewardContracts(
        uint256 missionId,
        address rewardManager,
        address settlement,
        address identityLayer
    ) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        mission.setRewardContracts(rewardManager, settlement, identityLayer);
    }
    
    /**
     * @dev Set reward type for a mission
     * @param missionId The mission ID
     * @param rewardType Reward type (0 = INX_POINTS, 1 = USDC)
     * @param rewardPoolId Reward pool ID from INXRewardManager (if using INX points)
     */
    function setMissionRewardType(
        uint256 missionId,
        uint8 rewardType,
        uint256 rewardPoolId
    ) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        Mission.RewardType rewardTypeEnum = rewardType == 0 
            ? Mission.RewardType.INX_POINTS 
            : Mission.RewardType.USDC;
        mission.setRewardType(rewardTypeEnum, rewardPoolId);
    }
    
    /**
     * @dev Deactivate a mission
     */
    function deactivateMission(uint256 missionId) external onlyOwner {
        require(missionInfo[missionId].isActive, "Mission already inactive");
        
        missionInfo[missionId].isActive = false;
        
        emit MissionDeactivated(missionId);
    }
    
    /**
     * @dev Allow users to claim rewards from a mission using Merkle proof
     */
    function claimRewardFromMission(
        uint256 missionId,
        uint256 missionExecutionId,
        uint256 rewardAmount,
        bytes32[] calldata proof
    ) external {
        require(missionInfo[missionId].isActive, "Mission not active");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        mission.claimReward(missionExecutionId, rewardAmount, proof);
    }
    
    // View functions
    
    /**
     * @dev Get mission information
     */
    function getMissionInfo(uint256 missionId) external view returns (MissionInfo memory) {
        require(missionId > 0 && missionId <= totalMissions, "Invalid mission ID");
        return missionInfo[missionId];
    }
    
    /**
     * @dev Get all missions for a user
     */
    function getUserMissions(address user) external view returns (uint256[] memory) {
        return userMissions[user];
    }
    
    /**
     * @dev Get total number of missions
     */
    function getTotalMissions() external view returns (uint256) {
        return totalMissions;
    }
    
    /**
     * @dev Get mission statistics
     */
    function getMissionStats(uint256 missionId) external view returns (
        uint256 totalRewards,
        uint256 remainingRewards,
        bytes32 merkleRoot,
        bool isActive
    ) {
        require(missionId > 0 && missionId <= totalMissions, "Invalid mission ID");
        
        MissionInfo memory info = missionInfo[missionId];
        Mission mission = Mission(info.missionAddress);
        
        return (
            mission.getTotalRewardPool(),
            mission.getRemainingRewardPool(),
            mission.getParticipantsMerkleRoot(),
            info.isActive
        );
    }
    
    /**
     * @dev Verify if user is participant in mission using Merkle proof
     */
    function verifyUserParticipant(
        uint256 missionId,
        address user,
        uint256 missionExecutionId,
        bytes32[] calldata proof
    ) external view returns (bool) {
        require(missionId > 0 && missionId <= totalMissions, "Invalid mission ID");
        
        Mission mission = Mission(missionInfo[missionId].missionAddress);
        return mission.verifyParticipant(user, missionExecutionId, proof);
    }
    
    /**
     * @dev Get all active missions
     */
    function getActiveMissions() external view returns (uint256[] memory activeMissionIds) {
        uint256 activeCount = 0;
        
        // Count active missions
        for (uint256 i = 1; i <= totalMissions; i++) {
            if (missionInfo[i].isActive) {
                activeCount++;
            }
        }
        
        // Create array with active mission IDs
        activeMissionIds = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= totalMissions; i++) {
            if (missionInfo[i].isActive) {
                activeMissionIds[index] = i;
                index++;
            }
        }
        
        return activeMissionIds;
    }
    
    /**
     * @dev Emergency function to recover USDC sent to this contract
     */
    function emergencyRecoverUSDC(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(usdcToken.balanceOf(address(this)) >= amount, "Insufficient balance");
        
        require(usdcToken.transfer(owner(), amount), "Transfer failed");
    }
}