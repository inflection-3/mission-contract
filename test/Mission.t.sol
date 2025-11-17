// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
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

contract MissionTest is Test {
    Mission public mission;
    MockUSDC public usdcToken;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    
    // Merkle tree data
    bytes32[] public leaves;
    bytes32 public merkleRoot;
    
    // Participant data for Merkle tree
    struct ParticipantData {
        address user;
        uint256 missionExecutionId;
        uint256 rewardAmount;
    }
    
    ParticipantData[] public participants;
    
    function setUp() public {
        vm.startPrank(owner);
        usdcToken = new MockUSDC();
        
        // Deploy implementation
        Mission implementation = new Mission();
        
        // Encode initialize call
        bytes memory initData = abi.encodeWithSelector(
            Mission.initialize.selector,
            address(usdcToken)
        );
        
        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        mission = Mission(address(proxy));
        
        // Mint some USDC to owner for testing
        usdcToken.mint(owner, 1000000 * 10**6); // 1M USDC (6 decimals)
        usdcToken.approve(address(mission), type(uint256).max);
        
        // Setup participant data for Merkle tree
        setupParticipantData();
        
        vm.stopPrank();
    }
    
    function setupParticipantData() internal {
        // Add participant data
        participants.push(ParticipantData(user1, 1001, 500 * 10**6));
        participants.push(ParticipantData(user2, 1002, 300 * 10**6));
        participants.push(ParticipantData(user3, 1003, 200 * 10**6));
        
        // Generate leaves
        for (uint256 i = 0; i < participants.length; i++) {
            bytes32 leaf = keccak256(abi.encodePacked(
                participants[i].user,
                participants[i].missionExecutionId
            ));
            leaves.push(leaf);
        }
        
        // Generate Merkle root (simple implementation for testing)
        merkleRoot = generateMerkleRoot(leaves);
    }
    
    function generateMerkleRoot(bytes32[] memory _leaves) internal pure returns (bytes32) {
        if (_leaves.length == 0) return bytes32(0);
        if (_leaves.length == 1) return _leaves[0];
        
        bytes32[] memory currentLevel = new bytes32[](_leaves.length);
        for (uint256 i = 0; i < _leaves.length; i++) {
            currentLevel[i] = _leaves[i];
        }
        
        while (currentLevel.length > 1) {
            uint256 nextLevelLength = (currentLevel.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelLength);
            
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    // Sort the pair before hashing
                    bytes32 left = currentLevel[i];
                    bytes32 right = currentLevel[i + 1];
                    if (left > right) {
                        (left, right) = (right, left);
                    }
                    nextLevel[i / 2] = keccak256(abi.encodePacked(left, right));
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            
            currentLevel = nextLevel;
        }
        
        return currentLevel[0];
    }
    
    function generateMerkleProof(uint256 index) internal view returns (bytes32[] memory) {
        require(index < leaves.length, "Invalid index");
        
        if (leaves.length == 1) {
            return new bytes32[](0);
        }
        
        bytes32[] memory proof = new bytes32[](0);
        bytes32[] memory currentLevel = new bytes32[](leaves.length);
        
        // Copy leaves to current level
        for (uint256 i = 0; i < leaves.length; i++) {
            currentLevel[i] = leaves[i];
        }
        
        uint256 currentIndex = index;
        
        while (currentLevel.length > 1) {
            uint256 nextLevelLength = (currentLevel.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelLength);
            
            // Expand proof array
            bytes32[] memory newProof = new bytes32[](proof.length + 1);
            for (uint256 i = 0; i < proof.length; i++) {
                newProof[i] = proof[i];
            }
            
            // Add sibling to proof if it exists
            if (currentIndex % 2 == 0) {
                // Current node is left child, add right sibling if exists
                if (currentIndex + 1 < currentLevel.length) {
                    newProof[proof.length] = currentLevel[currentIndex + 1];
                }
            } else {
                // Current node is right child, add left sibling
                newProof[proof.length] = currentLevel[currentIndex - 1];
            }
            
            proof = newProof;
            
            // Build next level
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    // Sort the pair before hashing
                    bytes32 left = currentLevel[i];
                    bytes32 right = currentLevel[i + 1];
                    if (left > right) {
                        (left, right) = (right, left);
                    }
                    nextLevel[i / 2] = keccak256(abi.encodePacked(left, right));
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            
            currentLevel = nextLevel;
            currentIndex = currentIndex / 2;
        }
        
        // Remove empty elements from proof
        uint256 actualLength = 0;
        for (uint256 i = 0; i < proof.length; i++) {
            if (proof[i] != bytes32(0)) {
                actualLength++;
            }
        }
        
        bytes32[] memory finalProof = new bytes32[](actualLength);
        uint256 finalIndex = 0;
        for (uint256 i = 0; i < proof.length; i++) {
            if (proof[i] != bytes32(0)) {
                finalProof[finalIndex] = proof[i];
                finalIndex++;
            }
        }
        
        return finalProof;
    }
    
    function testAddApplication() public {
        vm.startPrank(owner);
        
        mission.addApplication(
            "Test App",
            "Test Description",
            "https://test.com",
            "banner.jpg",
            "logo.jpg"
        );
        
        assertEq(mission.getApplicationCount(), 1);
        
        IMission.Application memory app = mission.getApplication(1);
        assertEq(app.name, "Test App");
        assertEq(app.description, "Test Description");
        assertEq(app.appUrl, "https://test.com");
        assertTrue(app.isActive);
        
        vm.stopPrank();
    }
    
    function testAddInteraction() public {
        vm.startPrank(owner);
        
        // First add an application
        mission.addApplication("Test App", "Test Description", "https://test.com", "banner.jpg", "logo.jpg");
        
        // Then add an interaction
        mission.addInteraction(
            1,
            "Test Interaction",
            "Test Interaction Description",
            "Click Here",
            "https://interaction.com",
            100 * 10**6 // 100 USDC
        );
        
        assertEq(mission.getInteractionCount(), 1);
        
        IMission.Interaction memory interaction = mission.getInteraction(1);
        assertEq(interaction.title, "Test Interaction");
        assertEq(interaction.applicationId, 1);
        assertEq(interaction.rewardAmount, 100 * 10**6);
        assertTrue(interaction.isActive);
        
        vm.stopPrank();
    }
    
    function testUpdateParticipantsMerkleRoot() public {
        vm.startPrank(owner);
        
        // Update Merkle root
        mission.updateParticipantsMerkleRoot(merkleRoot);
        
        assertEq(mission.getParticipantsMerkleRoot(), merkleRoot);
        
        vm.stopPrank();
    }
    
    function testUpdateParticipantsMerkleRootOnlyOwner() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        mission.updateParticipantsMerkleRoot(merkleRoot);
        
        vm.stopPrank();
    }
    
    function testUpdateParticipantsMerkleRootInvalidRoot() public {
        vm.startPrank(owner);
        
        vm.expectRevert("Invalid Merkle root");
        mission.updateParticipantsMerkleRoot(bytes32(0));
        
        vm.stopPrank();
    }
    
    function testVerifyParticipant() public {
        vm.startPrank(owner);
        
        // Set Merkle root
        mission.updateParticipantsMerkleRoot(merkleRoot);
        
        vm.stopPrank();
        
        // Test valid participant verification
        bytes32[] memory proof = generateMerkleProof(0); // user1
        bool isValid = mission.verifyParticipant(user1, 1001, proof);
        assertTrue(isValid);
        
        // Test invalid participant
        proof = generateMerkleProof(0);
        isValid = mission.verifyParticipant(user1, 9999, proof); // wrong mission execution ID
        assertFalse(isValid);
        
        // Test with wrong user
        isValid = mission.verifyParticipant(address(0x999), 1001, proof);
        assertFalse(isValid);
    }
    
    function testVerifyParticipantWithoutMerkleRoot() public {
        // Try to verify without setting Merkle root
        bytes32[] memory proof = new bytes32[](0);
        
        vm.expectRevert("Merkle root not set");
        mission.verifyParticipant(user1, 1001, proof);
    }
    
    function testDepositRewards() public {
        vm.startPrank(owner);
        
        uint256 depositAmount = 1000 * 10**6; // 1000 USDC
        
        mission.depositRewards(depositAmount);
        
        assertEq(mission.getTotalRewardPool(), depositAmount);
        assertEq(usdcToken.balanceOf(address(mission)), depositAmount);
        
        vm.stopPrank();
    }
    
    function testDistributeRewards() public {
        vm.startPrank(owner);
        
        // Set Merkle root
        mission.updateParticipantsMerkleRoot(merkleRoot);
        
        // Deposit rewards
        uint256 depositAmount = 1000 * 10**6; // 1000 USDC
        mission.depositRewards(depositAmount);
        
        // Distribute rewards
        mission.distributeRewards();
        
        assertTrue(mission.rewardsDistributed());
        assertEq(mission.distributedRewards(), depositAmount);
        
        vm.stopPrank();
    }
    
    function testDistributeRewardsWithoutMerkleRoot() public {
        vm.startPrank(owner);
        
        // Deposit rewards
        mission.depositRewards(1000 * 10**6);
        
        // Try to distribute without Merkle root
        vm.expectRevert("Merkle root not set");
        mission.distributeRewards();
        
        vm.stopPrank();
    }
    
    function testClaimReward() public {
        vm.startPrank(owner);
        
        // Set Merkle root and deposit rewards
        mission.updateParticipantsMerkleRoot(merkleRoot);
        mission.depositRewards(1000 * 10**6);
        mission.distributeRewards();
        
        vm.stopPrank();
        
        // User1 claims reward
        vm.startPrank(user1);
        
        uint256 balanceBefore = usdcToken.balanceOf(user1);
        bytes32[] memory proof = generateMerkleProof(0); // user1 is at index 0
        uint256 rewardAmount = participants[0].rewardAmount; // 500 * 10**6
        
        mission.claimReward(participants[0].missionExecutionId, rewardAmount, proof);
        
        uint256 balanceAfter = usdcToken.balanceOf(user1);
        
        assertEq(balanceAfter - balanceBefore, rewardAmount);
        assertTrue(mission.hasUserClaimedReward(user1));
        
        // Try to claim again (should fail)
        vm.expectRevert("Already claimed");
        mission.claimReward(participants[0].missionExecutionId, rewardAmount, proof);
        
        vm.stopPrank();
    }
    
    function testClaimRewardInvalidProof() public {
        vm.startPrank(owner);
        
        // Set Merkle root and deposit rewards
        mission.updateParticipantsMerkleRoot(merkleRoot);
        mission.depositRewards(1000 * 10**6);
        mission.distributeRewards();
        
        vm.stopPrank();
        
        // User tries to claim with invalid proof
        vm.startPrank(user1);
        
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(123)); // Invalid proof
        
        vm.expectRevert("Invalid Merkle proof");
        mission.claimReward(1001, 500 * 10**6, invalidProof);
        
        vm.stopPrank();
    }
    
    function testClaimRewardWrongMissionExecutionId() public {
        vm.startPrank(owner);
        
        // Set Merkle root and deposit rewards
        mission.updateParticipantsMerkleRoot(merkleRoot);
        mission.depositRewards(1000 * 10**6);
        mission.distributeRewards();
        
        vm.stopPrank();
        
        // User tries to claim with wrong mission execution ID
        vm.startPrank(user1);
        
        bytes32[] memory proof = generateMerkleProof(0);
        
        vm.expectRevert("Invalid Merkle proof");
        mission.claimReward(9999, 500 * 10**6, proof); // Wrong mission execution ID
        
        vm.stopPrank();
    }
    
    function testMultipleParticipantsClaim() public {
        vm.startPrank(owner);
        
        // Set Merkle root and deposit rewards
        mission.updateParticipantsMerkleRoot(merkleRoot);
        mission.depositRewards(1000 * 10**6);
        mission.distributeRewards();
        
        vm.stopPrank();
        
        // User1 claims
        vm.startPrank(user1);
        bytes32[] memory proof1 = generateMerkleProof(0);
        mission.claimReward(participants[0].missionExecutionId, participants[0].rewardAmount, proof1);
        assertTrue(mission.hasUserClaimedReward(user1));
        vm.stopPrank();
        
        // User2 claims
        vm.startPrank(user2);
        bytes32[] memory proof2 = generateMerkleProof(1);
        mission.claimReward(participants[1].missionExecutionId, participants[1].rewardAmount, proof2);
        assertTrue(mission.hasUserClaimedReward(user2));
        vm.stopPrank();
        
        // User3 claims
        vm.startPrank(user3);
        bytes32[] memory proof3 = generateMerkleProof(2);
        mission.claimReward(participants[2].missionExecutionId, participants[2].rewardAmount, proof3);
        assertTrue(mission.hasUserClaimedReward(user3));
        vm.stopPrank();
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        mission.addApplication("Test", "Test", "https://test.com", "banner.jpg", "logo.jpg");
        
        vm.expectRevert();
        mission.addInteraction(1, "Test", "Test", "Test", "https://test.com", 100);
        
        vm.expectRevert();
        mission.updateParticipantsMerkleRoot(merkleRoot);
        
        vm.expectRevert();
        mission.depositRewards(100);
        
        vm.expectRevert();
        mission.distributeRewards();
        
        vm.stopPrank();
    }
    
    function testNonParticipantCannotClaim() public {
        vm.startPrank(owner);
        
        // Set Merkle root and deposit rewards
        mission.updateParticipantsMerkleRoot(merkleRoot);
        mission.depositRewards(1000 * 10**6);
        mission.distributeRewards();
        
        vm.stopPrank();
        
        // Non-participant (address not in Merkle tree) tries to claim
        address nonParticipant = address(0x999);
        vm.startPrank(nonParticipant);
        
        bytes32[] memory invalidProof = generateMerkleProof(0); // This proof is for user1, not nonParticipant
        
        vm.expectRevert("Invalid Merkle proof");
        mission.claimReward(1001, 500 * 10**6, invalidProof);
        
        vm.stopPrank();
    }
    
    function testRewardsNotDistributed() public {
        vm.startPrank(owner);
        
        // Set Merkle root and deposit rewards but don't distribute
        mission.updateParticipantsMerkleRoot(merkleRoot);
        mission.depositRewards(1000 * 10**6);
        
        vm.stopPrank();
        
        // Try to claim before distribution
        vm.startPrank(user1);
        bytes32[] memory proof = generateMerkleProof(0);
        
        vm.expectRevert("Rewards not yet distributed");
        mission.claimReward(participants[0].missionExecutionId, participants[0].rewardAmount, proof);
        
        vm.stopPrank();
    }
    
    function testDeactivateApplication() public {
        vm.startPrank(owner);
        
        mission.addApplication("Test App", "Test Description", "https://test.com", "banner.jpg", "logo.jpg");
        
        IMission.Application memory app = mission.getApplication(1);
        assertTrue(app.isActive);
        
        mission.deactivateApplication(1);
        
        app = mission.getApplication(1);
        assertFalse(app.isActive);
        
        vm.stopPrank();
    }
    
    function testDeactivateInteraction() public {
        vm.startPrank(owner);
        
        mission.addApplication("Test App", "Test Description", "https://test.com", "banner.jpg", "logo.jpg");
        mission.addInteraction(1, "Test Interaction", "Test Description", "Test Action", "https://test.com", 100);
        
        IMission.Interaction memory interaction = mission.getInteraction(1);
        assertTrue(interaction.isActive);
        
        mission.deactivateInteraction(1);
        
        interaction = mission.getInteraction(1);
        assertFalse(interaction.isActive);
        
        vm.stopPrank();
    }
}
