// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IINXRewardManager
 * @dev Interface for INXRewardManager contract
 */
interface IINXRewardManager {
    struct RewardPool {
        uint256 poolId;
        string poolName;
        uint256 totalRewards;
        uint256 distributedRewards;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardRate;
        bool isActive;
    }

    struct Stake {
        address staker;
        uint256 amount;
        uint256 stakedAt;
        uint256 lastRewardClaim;
        uint256 totalRewardsClaimed;
    }

    function setINXToken(address _inxToken) external;
    
    function createRewardPool(
        string memory poolName,
        uint256 totalRewards,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardRate
    ) external returns (uint256 poolId);
    
    function fundPool(uint256 poolId, uint256 amount) external;
    
    function stake(uint256 amount) external;
    
    function unstake(uint256 amount) external;
    
    function distributeRewards(
        uint256 poolId,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;
    
    function claimRewards(uint256 poolId, uint256 amount) external;
    
    function calculatePendingRewards(address staker, uint256 poolId) 
        external 
        view 
        returns (uint256);
    
    function getPool(uint256 poolId) external view returns (RewardPool memory);
    
    function getStake(address staker) external view returns (Stake memory);
}

