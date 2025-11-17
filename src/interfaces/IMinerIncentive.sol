// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMinerIncentive
 * @dev Interface for MinerIncentive contract
 */
interface IMinerIncentive {
    struct Miner {
        address minerAddress;
        uint256 totalContributions;
        uint256 totalPeopleOnboarded;
        uint256 totalRewardsEarned;
        uint256 lastRewardClaim;
        bool isActive;
        uint256 registeredAt;
        string[] geographies;
    }

    struct Contribution {
        uint256 contributionId;
        address miner;
        uint256 amount;
        uint256 peopleOnboarded;
        string geography;
        string contributionType;
        bytes32 proofHash;
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

    function registerMiner(address minerAddress) external;
    
    function recordContribution(
        address miner,
        uint256 amount,
        uint256 peopleOnboarded,
        string memory geography,
        string memory contributionType,
        bytes32 proofHash,
        uint256 poolId
    ) external;
    
    function verifyContribution(uint256 contributionId) external;
    
    function createIncentivePool(
        string memory poolName,
        uint256 totalAllocated,
        uint256 startTime,
        uint256 endTime
    ) external returns (uint256 poolId);
    
    function fundPool(uint256 poolId, uint256 amount) external;
    
    function distributeRewards(
        uint256 poolId,
        address[] calldata minerAddresses,
        uint256[] calldata rewardAmounts
    ) external;
    
    function claimRewards(uint256 amount) external;
    
    function getMiner(address minerAddress) external view returns (Miner memory);
    
    function getContribution(uint256 contributionId) external view returns (Contribution memory);
    
    function getPool(uint256 poolId) external view returns (IncentivePool memory);
    
    function getGeographyContributions(string memory geography) external view returns (uint256[] memory);
    
    function getGeographyMiners(string memory geography) external view returns (address[] memory);
    
    function getMinerGeographies(address minerAddress) external view returns (string[] memory);
    
    function getMinerOnboardedCount(address minerAddress) external view returns (uint256);
    
    function getGeographyStats(string memory geography) 
        external 
        view 
        returns (
            uint256 totalContributions,
            uint256 totalPeopleOnboarded,
            uint256 minerCount
        );
}

