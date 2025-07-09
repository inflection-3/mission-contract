// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MissionContract} from "../src/MissionContract.sol";

contract MissionContractTest is Test {
    MissionContract public missionContract;
    address public admin;
    address public org1;
    address public org2;
    address public user1;
    address public user2;

    function setUp() public {
        admin = address(this);
        org1 = address(0x1);
        org2 = address(0x2);
        user1 = address(0x3);
        user2 = address(0x4);
        
        missionContract = new MissionContract();
    }

    function test_Constructor() public {
        assertEq(missionContract.admin(), admin);
        assertEq(missionContract.missionCount(), 0);
        assertEq(missionContract.getOrganizationCount(), 0);
        assertEq(missionContract.getCompletionCount(), 0);
    }

    function test_AddOrganization() public {
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        
        (string memory name, string memory description, address wallet) = missionContract.getOrganization(org1);
        assertEq(name, "Test Org 1");
        assertEq(description, "Description 1");
        assertEq(wallet, org1);
        
        assertEq(missionContract.getOrganizationCount(), 1);
        assertEq(missionContract.getOrganizationByIndex(0), org1);
    }

    function test_AddOrganization_OnlyAdmin() public {
        vm.prank(org1);
        vm.expectRevert("Only admin");
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
    }

    function test_AddOrganization_AlreadyExists() public {
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        
        vm.expectRevert("Organization already exists");
        missionContract.addOrganization(org1, "Test Org 1 Updated", "Description 1 Updated");
    }

    function test_AddMission_ByAdmin() public {
        // First add organization
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        
        // Admin can add mission
        missionContract.addMission("Test Mission 1", org1);
        
        assertEq(missionContract.missionCount(), 1);
        
        (uint id, string memory description, address organization) = missionContract.getMission(1);
        assertEq(id, 1);
        assertEq(description, "Test Mission 1");
        assertEq(organization, org1);
    }

    function test_AddMission_ByOrganization() public {
        // First add organization
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        
        // Organization can add mission
        vm.prank(org1);
        missionContract.addMission("Test Mission 1", org1);
        
        assertEq(missionContract.missionCount(), 1);
        
        (uint id, string memory description, address organization) = missionContract.getMission(1);
        assertEq(id, 1);
        assertEq(description, "Test Mission 1");
        assertEq(organization, org1);
    }

    function test_AddMission_NotAuthorized() public {
        // First add organization
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        
        // Random user cannot add mission
        vm.prank(user1);
        vm.expectRevert("Not authorized");
        missionContract.addMission("Test Mission 1", org1);
    }

    function test_AddMission_OrganizationNotExists() public {
        vm.expectRevert("Organization does not exist");
        missionContract.addMission("Test Mission 1", org1);
    }

    function test_CompleteMission_ByAdmin() public {
        // Setup
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        missionContract.addMission("Test Mission 1", org1);
        
        uint timestamp = block.timestamp;
        missionContract.completeMission(1, user1, timestamp);
        
        assertEq(missionContract.getCompletionCount(), 1);
        
        (address user, uint missionId, uint completionTime, address organization) = missionContract.getCompletion(0);
        assertEq(user, user1);
        assertEq(missionId, 1);
        assertEq(completionTime, timestamp);
        assertEq(organization, org1);
    }

    function test_CompleteMission_ByOrganization() public {
        // Setup
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        missionContract.addMission("Test Mission 1", org1);
        
        uint timestamp = block.timestamp;
        vm.prank(org1);
        missionContract.completeMission(1, user1, timestamp);
        
        assertEq(missionContract.getCompletionCount(), 1);
        
        (address user, uint missionId, uint completionTime, address organization) = missionContract.getCompletion(0);
        assertEq(user, user1);
        assertEq(missionId, 1);
        assertEq(completionTime, timestamp);
        assertEq(organization, org1);
    }

    function test_CompleteMission_NotAuthorized() public {
        // Setup
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        missionContract.addMission("Test Mission 1", org1);
        
        uint timestamp = block.timestamp;
        vm.prank(user1);
        vm.expectRevert("Not authorized");
        missionContract.completeMission(1, user1, timestamp);
    }

    function test_CompleteMission_MissionNotExists() public {
        vm.expectRevert("Mission does not exist");
        missionContract.completeMission(999, user1, block.timestamp);
    }

    function test_GetOrganization_NotExists() public {
        vm.expectRevert("Organization does not exist");
        missionContract.getOrganization(org1);
    }

    function test_GetMission_NotExists() public {
        vm.expectRevert("Mission does not exist");
        missionContract.getMission(999);
    }

    function test_GetCompletion_IndexOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        missionContract.getCompletion(0);
    }

    function test_GetOrganizationByIndex_IndexOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        missionContract.getOrganizationByIndex(0);
    }

    function test_MultipleOrganizations() public {
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        missionContract.addOrganization(org2, "Test Org 2", "Description 2");
        
        assertEq(missionContract.getOrganizationCount(), 2);
        assertEq(missionContract.getOrganizationByIndex(0), org1);
        assertEq(missionContract.getOrganizationByIndex(1), org2);
    }

    function test_MultipleMissions() public {
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        missionContract.addOrganization(org2, "Test Org 2", "Description 2");
        
        missionContract.addMission("Mission 1", org1);
        missionContract.addMission("Mission 2", org2);
        
        assertEq(missionContract.missionCount(), 2);
        
        (uint id1, string memory desc1, address org1Addr) = missionContract.getMission(1);
        (uint id2, string memory desc2, address org2Addr) = missionContract.getMission(2);
        
        assertEq(id1, 1);
        assertEq(desc1, "Mission 1");
        assertEq(org1Addr, org1);
        
        assertEq(id2, 2);
        assertEq(desc2, "Mission 2");
        assertEq(org2Addr, org2);
    }

    function test_MultipleCompletions() public {
        missionContract.addOrganization(org1, "Test Org 1", "Description 1");
        missionContract.addMission("Mission 1", org1);
        missionContract.addMission("Mission 2", org1);
        
        uint timestamp1 = block.timestamp;
        uint timestamp2 = block.timestamp + 1;
        
        missionContract.completeMission(1, user1, timestamp1);
        missionContract.completeMission(2, user2, timestamp2);
        
        assertEq(missionContract.getCompletionCount(), 2);
        
        (address user_1, uint missionId1, uint time1, address org_1) = missionContract.getCompletion(0);
        (address user_2, uint missionId2, uint time2, address org_2) = missionContract.getCompletion(1);
        
        assertEq(user_1, user1);
        assertEq(missionId1, 1);
        assertEq(time1, timestamp1);
        assertEq(org_1, org1);
        
        assertEq(user_2, user2);
        assertEq(missionId2, 2);
        assertEq(time2, timestamp2);
        assertEq(org_2, org1);
    }
} 