// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MissionManager.sol";
import "../src/MissionFactory.sol";
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

contract MissionManagerTest is Test {
    MissionManager public missionManager;
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
        missionManager = new MissionManager(address(usdcToken), address(factory));
        
        // Transfer factory ownership to MissionManager so it can manage missions
        factory.transferOwnership(address(missionManager));
        
        // Mint some USDC to owner for testing
        usdcToken.mint(owner, 1000000 * 10**6); // 1M USDC (6 decimals)
        usdcToken.approve(address(missionManager), type(uint256).max);
        vm.stopPrank();
    }
    
    function testCreateMission() public {
        vm.startPrank(owner);
        
        (uint256 missionId, address missionAddress) = missionManager.createMission("Test Mission", "Test Description");
        
        assertEq(missionId, 1);
        assertTrue(missionAddress != address(0));
        assertEq(missionManager.getTotalMissions(), 1);
        
        MissionManager.MissionInfo memory missionInfo = missionManager.getMissionInfo(1);
        assertEq(missionInfo.name, "Test Mission");
        assertEq(missionInfo.description, "Test Description");
        assertTrue(missionInfo.isActive);
        
        vm.stopPrank();
    }
    
    function testAddApplicationToMission() public {
        vm.startPrank(owner);
        
        // Create mission first
        missionManager.createMission("Test Mission", "Test Description");
        
        // Add application to mission
        missionManager.addApplicationToMission(
            1,
            "Test App",
            "Test App Description",
            "https://testapp.com",
            "banner.jpg",
            "logo.jpg"
        );
        
        // Get the mission contract and check application
        MissionManager.MissionInfo memory missionInfo = missionManager.getMissionInfo(1);
        Mission mission = Mission(missionInfo.missionAddress);
        
        assertEq(mission.getApplicationCount(), 1);
        
        IMission.Application memory app = mission.getApplication(1);
        assertEq(app.name, "Test App");
        assertEq(app.description, "Test App Description");
        
        vm.stopPrank();
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        missionManager.createMission("Test", "Test");
        
        vm.expectRevert();
        missionManager.addApplicationToMission(1, "Test", "Test", "https://test.com", "banner.jpg", "logo.jpg");
        
        vm.stopPrank();
    }
}