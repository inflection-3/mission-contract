// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Mission.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeMission
 * @dev Script to upgrade Mission implementation contracts
 */
contract UpgradeMission is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("MISSION_PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new implementation
        Mission newImplementation = new Mission();
        console.log("New Mission implementation deployed at:", address(newImplementation));
        
        // Upgrade the proxy to point to new implementation
        Mission proxy = Mission(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        console.log("Mission proxy upgraded to new implementation");
        
        vm.stopBroadcast();
        
        // Log upgrade information
        console.log("=== Upgrade Complete ===");
        console.log("Proxy Address:", proxyAddress);
        console.log("New Implementation:", address(newImplementation));
        console.log("Upgrader:", vm.addr(deployerPrivateKey));
    }
    
    /**
     * @dev Upgrade with initialization data
     */
    function upgradeWithInit(bytes memory initData) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("MISSION_PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new implementation
        Mission newImplementation = new Mission();
        console.log("New Mission implementation deployed at:", address(newImplementation));
        
        // Upgrade the proxy with initialization data
        Mission proxy = Mission(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), initData);
        console.log("Mission proxy upgraded with initialization data");
        
        vm.stopBroadcast();
        
        // Log upgrade information
        console.log("=== Upgrade with Init Complete ===");
        console.log("Proxy Address:", proxyAddress);
        console.log("New Implementation:", address(newImplementation));
        console.log("Init Data Length:", initData.length);
        console.log("Upgrader:", vm.addr(deployerPrivateKey));
    }
}
