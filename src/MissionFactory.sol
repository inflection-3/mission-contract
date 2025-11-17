// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Mission.sol";
import "./interfaces/IMission.sol";

/**
 * @title MissionFactory
 * @dev Factory contract that deploys and manages Mission contracts
 */
contract MissionFactory is Ownable, ReentrancyGuard {
    address public immutable usdcToken;
    address public immutable missionImplementation;
    
    uint256 public missionCount;
    mapping(uint256 => address) public missions;
    mapping(address => bool) public isMission;
    address[] public missionList;
    
    event MissionCreated(uint256 indexed missionId, address indexed missionAddress, address indexed creator);
    event MissionDeactivated(uint256 indexed missionId, address indexed missionAddress);
    event ImplementationUpgraded(address indexed newImplementation);
    
    constructor(address _usdcToken, address _missionImplementation) Ownable(msg.sender) {
        usdcToken = _usdcToken;
        missionImplementation = _missionImplementation;
    }
    
    /**
     * @dev Create a new mission contract using ERC1967Proxy
     * @return missionAddress The address of the newly created mission proxy contract
     */
    function createMission() external onlyOwner returns (address missionAddress) {
        // Encode the initialize function call
        bytes memory initData = abi.encodeWithSelector(
            Mission.initialize.selector,
            usdcToken
        );
        
        // Deploy the proxy
        ERC1967Proxy proxy = new ERC1967Proxy(missionImplementation, initData);
        missionAddress = address(proxy);
        
        missionCount++;
        missions[missionCount] = missionAddress;
        isMission[missionAddress] = true;
        missionList.push(missionAddress);
        
        // Transfer ownership to the factory owner (can be changed later)
        Mission(missionAddress).transferOwnership(owner());
        
        emit MissionCreated(missionCount, missionAddress, msg.sender);
        
        return missionAddress;
    }
    
    /**
     * @dev Create multiple missions at once using ERC1967Proxy
     * @param count Number of missions to create
     * @return missionAddresses Array of mission proxy contract addresses
     */
    function createMultipleMissions(uint256 count) external onlyOwner returns (address[] memory missionAddresses) {
        require(count > 0 && count <= 50, "Invalid count (1-50)");
        
        missionAddresses = new address[](count);
        
        // Encode the initialize function call once
        bytes memory initData = abi.encodeWithSelector(
            Mission.initialize.selector,
            usdcToken
        );
        
        for (uint256 i = 0; i < count; i++) {
            // Deploy the proxy
            ERC1967Proxy proxy = new ERC1967Proxy(missionImplementation, initData);
            address missionAddress = address(proxy);
            
            missionCount++;
            missions[missionCount] = missionAddress;
            isMission[missionAddress] = true;
            missionList.push(missionAddress);
            missionAddresses[i] = missionAddress;
            
            // Transfer ownership to the factory owner
            Mission(missionAddress).transferOwnership(owner());
            
            emit MissionCreated(missionCount, missionAddress, msg.sender);
        }
        
        return missionAddresses;
    }
    
    /**
     * @dev Transfer ownership of a specific mission
     * @param missionId The ID of the mission
     * @param newOwner The new owner address
     */
    function transferMissionOwnership(uint256 missionId, address newOwner) external onlyOwner {
        require(missionId > 0 && missionId <= missionCount, "Invalid mission ID");
        require(newOwner != address(0), "Invalid new owner");
        
        address missionAddress = missions[missionId];
        require(missionAddress != address(0), "Mission does not exist");
        
        Mission mission = Mission(missionAddress);
        mission.transferOwnership(newOwner);
    }
    
    /**
     * @dev Get mission address by ID
     * @param missionId The ID of the mission
     * @return The mission contract address
     */
    function getMission(uint256 missionId) external view returns (address) {
        require(missionId > 0 && missionId <= missionCount, "Invalid mission ID");
        return missions[missionId];
    }
    
    /**
     * @dev Get all mission addresses
     * @return Array of all mission contract addresses
     */
    function getAllMissions() external view returns (address[] memory) {
        return missionList;
    }
    
    /**
     * @dev Get total number of missions
     * @return The total count of missions
     */
    function getMissionCount() external view returns (uint256) {
        return missionCount;
    }
    
    /**
     * @dev Check if an address is a valid mission contract
     * @param missionAddress The address to check
     * @return True if the address is a valid mission contract
     */
    function isValidMission(address missionAddress) external view returns (bool) {
        return isMission[missionAddress];
    }
    
    /**
     * @dev Get mission statistics
     * @return totalMissions Total number of missions created
     * @return activeMissions Number of active missions (all missions are considered active)
     */
    function getMissionStats() external view returns (uint256 totalMissions, uint256 activeMissions) {
        totalMissions = missionCount;
        activeMissions = missionList.length; // All created missions are active
    }
    
    /**
     * @dev Get missions created by a specific address (if tracking is needed)
     * @param creator The creator address
     * @return missionIds Array of mission IDs created by the address
     */
    function getMissionsByCreator(address creator) external view returns (uint256[] memory missionIds) {
        // This would require additional tracking if needed
        // For now, return empty array as all missions are created by owner
        missionIds = new uint256[](0);
    }
    
    /**
     * @dev Emergency function to recover USDC sent to factory
     * @param amount Amount of USDC to recover
     */
    function emergencyRecoverUSDC(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        // This would require USDC interface implementation
        // For now, this is a placeholder
    }
}
