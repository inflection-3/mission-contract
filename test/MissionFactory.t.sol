// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MissionFactory.sol";
import "../src/Mission.sol";
import "../src/interfaces/IUSDC.sol";

// Mock USDC contract for testing
contract MockUSDC is IUSDC {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 private _totalSupply;
    
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) external override returns (bool) {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");
        
        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract MissionFactoryTest is Test {
    MissionFactory public factory;
    MockUSDC public usdcToken;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        usdcToken = new MockUSDC();
        
        // Deploy Mission implementation
        Mission implementation = new Mission();
        
        // Deploy factory with implementation address
        factory = new MissionFactory(address(usdcToken), address(implementation));
        vm.stopPrank();
    }
    
    function testCreateMission() public {
        vm.startPrank(owner);
        
        address missionAddress = factory.createMission();
        
        assertTrue(missionAddress != address(0));
        assertTrue(factory.isValidMission(missionAddress));
        assertEq(factory.getMissionCount(), 1);
        assertEq(factory.getMission(1), missionAddress);
        
        vm.stopPrank();
    }
    
    function testCreateMultipleMissions() public {
        vm.startPrank(owner);
        
        address[] memory missionAddresses = factory.createMultipleMissions(3);
        
        assertEq(missionAddresses.length, 3);
        assertEq(factory.getMissionCount(), 3);
        
        for (uint256 i = 0; i < 3; i++) {
            assertTrue(missionAddresses[i] != address(0));
            assertTrue(factory.isValidMission(missionAddresses[i]));
        }
        
        vm.stopPrank();
    }
    
    function testCreateMissionOnlyOwner() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        factory.createMission();
        
        vm.stopPrank();
    }
    
    function testCreateMultipleMissionsInvalidCount() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Invalid count (1-50)");
        factory.createMultipleMissions(0);
        
        vm.expectRevert("Invalid count (1-50)");
        factory.createMultipleMissions(51);
        
        vm.stopPrank();
    }
    
    function testTransferMissionOwnership() public {
        vm.startPrank(owner);
        
        address missionAddress = factory.createMission();
        
        // Transfer ownership of the mission contract directly
        Mission mission = Mission(missionAddress);
        mission.transferOwnership(user1);
        
        assertEq(mission.owner(), user1);
        
        vm.stopPrank();
    }
    
    function testTransferMissionOwnershipInvalidMission() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Invalid mission ID");
        factory.transferMissionOwnership(0, user1);
        
        vm.expectRevert("Invalid mission ID");
        factory.transferMissionOwnership(2, user1);
        
        vm.stopPrank();
    }
    
    function testGetAllMissions() public {
        vm.startPrank(owner);
        
        factory.createMission();
        factory.createMission();
        factory.createMission();
        
        address[] memory allMissions = factory.getAllMissions();
        assertEq(allMissions.length, 3);
        
        vm.stopPrank();
    }
    
    function testGetMissionStats() public {
        vm.startPrank(owner);
        
        factory.createMission();
        factory.createMission();
        
        (uint256 totalMissions, uint256 activeMissions) = factory.getMissionStats();
        
        assertEq(totalMissions, 2);
        assertEq(activeMissions, 2);
        
        vm.stopPrank();
    }
    
    function testIsValidMission() public {
        vm.startPrank(owner);
        
        address missionAddress = factory.createMission();
        
        assertTrue(factory.isValidMission(missionAddress));
        assertFalse(factory.isValidMission(address(0x123)));
        
        vm.stopPrank();
    }
}
