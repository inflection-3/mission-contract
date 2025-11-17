// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMission
 * @dev Interface for Mission contracts
 */
interface IMission {
    struct Application {
        uint256 id;
        string name;
        string description;
        string appUrl;
        string bannerImage;
        string appLogo;
        bool isActive;
        address owner;
    }

    struct Interaction {
        uint256 id;
        uint256 applicationId;
        string title;
        string description;
        string actionTitle;
        string interactionUrl;
        bool isActive;
        uint256 rewardAmount;
    }

    struct Participant {
        address user;
        uint256[] completedInteractions;
        uint256 totalReward;
        bool hasClaimed;
    }

    function addApplication(
        string memory name,
        string memory description,
        string memory appUrl,
        string memory bannerImage,
        string memory appLogo
    ) external;

    function addInteraction(
        uint256 applicationId,
        string memory title,
        string memory description,
        string memory actionTitle,
        string memory interactionUrl,
        uint256 rewardAmount
    ) external;

    function updateParticipantsMerkleRoot(bytes32 newMerkleRoot) external;

    function verifyParticipant(
        address participant,
        uint256 missionExecutionId,
        bytes32[] calldata proof
    ) external view returns (bool);

    function depositRewards(uint256 amount) external;

    function distributeRewards() external;

    function claimReward(
        uint256 missionExecutionId,
        uint256 rewardAmount,
        bytes32[] calldata proof
    ) external;

    function getApplication(uint256 id) external view returns (Application memory);

    function getInteraction(uint256 id) external view returns (Interaction memory);

    function getParticipantsMerkleRoot() external view returns (bytes32);

    function getTotalRewardPool() external view returns (uint256);

    function getRemainingRewardPool() external view returns (uint256);
}
