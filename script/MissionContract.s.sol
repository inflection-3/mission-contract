// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {MissionContract} from "../src/MissionContract.sol";

contract MissionContractScript is Script {
    MissionContract public missionContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the MissionContract
        missionContract = new MissionContract();
        
        console.log("MissionContract deployed at:", address(missionContract));
        console.log("Admin address:", missionContract.admin());

        vm.stopBroadcast();
    }

    // Helper function to deploy and setup with sample data
    function runWithSampleData() public {
        vm.startBroadcast();

        // Deploy the MissionContract
        missionContract = new MissionContract();
        
        console.log("MissionContract deployed at:", address(missionContract));
        console.log("Admin address:", missionContract.admin());

        // Add sample organizations
        address org1 = address(0x1234567890123456789012345678901234567890);
        address org2 = address(0x2345678901234567890123456789012345678901);
        
        missionContract.addOrganization(org1, "Green Initiative", "Environmental conservation organization");
        missionContract.addOrganization(org2, "Tech for Good", "Technology solutions for social impact");
        
        console.log("Added organization 1:", org1);
        console.log("Added organization 2:", org2);

        // Add sample missions
        missionContract.addMission("Plant 100 trees in local park", org1);
        missionContract.addMission("Organize beach cleanup event", org1);
        missionContract.addMission("Develop mobile app for seniors", org2);
        
        console.log("Added 3 sample missions");
        console.log("Mission count:", missionContract.missionCount());

        vm.stopBroadcast();
    }
} 