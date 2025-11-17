// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MissionFactory.sol";
import "../src/MissionManager.sol";
import "../src/interfaces/IUSDC.sol";

/**
 * @title DeployMissionSystem
 * @dev Deployment script for the Mission Factory system
 */
contract DeployMissionSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Mission implementation contract
        Mission missionImplementation = new Mission();
        console.log("Mission implementation deployed at:", address(missionImplementation));
        
        // Deploy MissionFactory with implementation address
        MissionFactory factory = new MissionFactory(usdcAddress, address(missionImplementation));
        console.log("MissionFactory deployed at:", address(factory));
        
        // Deploy MissionManager (main hub)
        MissionManager missionManager = new MissionManager(usdcAddress, address(factory));
        console.log("MissionManager deployed at:", address(missionManager));
        
        // Transfer factory ownership to mission manager if needed
        // factory.transferOwnership(address(missionManager));
        
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("=== Deployment Complete ===");
        console.log("USDC Address:", usdcAddress);
        console.log("Mission Implementation:", address(missionImplementation));
        console.log("MissionFactory:", address(factory));
        console.log("MissionManager:", address(missionManager));
        console.log("Deployer:", vm.addr(deployerPrivateKey));
    }
}
