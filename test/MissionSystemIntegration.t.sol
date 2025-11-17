// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/IdentityLayer.sol";
import "../src/INXRewardManager.sol";
import "../src/StablecoinSettlement.sol";
import "../src/MinerIncentive.sol";
import "../src/Mission.sol";
import "../src/MissionFactory.sol";
import "../src/MissionManager.sol";
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

/**
 * @title MissionSystemIntegrationTest
 * @dev Comprehensive integration tests for the entire Mission Contract System
 */
contract MissionSystemIntegrationTest is Test {
    // Contracts
    IdentityLayer public identityLayer;
    INXRewardManager public rewardManager;
    StablecoinSettlement public settlement;
    MinerIncentive public minerIncentive;
    Mission public mission;
    MissionFactory public factory;
    MissionManager public missionManager;
    MockUSDC public usdcToken;
    
    // Test addresses
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);
    address public miner1 = address(0x6);
    address public miner2 = address(0x7);
    
    // Test data
    bytes32 public did1;
    bytes32 public did2;
    bytes32 public did3;
    bytes32 public minerDid1;
    bytes32 public minerDid2;
    
    // Merkle tree data for rewards
    bytes32[] public leaves;
    bytes32 public merkleRoot;
    
    struct ParticipantData {
        address user;
        uint256 missionExecutionId;
        uint256 rewardAmount;
    }
    
    ParticipantData[] public participants;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy USDC token
        usdcToken = new MockUSDC();
        
        // Deploy IdentityLayer
        identityLayer = new IdentityLayer();
        
        // Deploy INXRewardManager
        rewardManager = new INXRewardManager(address(usdcToken));
        
        // Deploy StablecoinSettlement
        settlement = new StablecoinSettlement(address(usdcToken));
        
        // Deploy MinerIncentive
        minerIncentive = new MinerIncentive(
            address(usdcToken),
            address(identityLayer),
            address(rewardManager),
            address(settlement)
        );
        
        // Deploy Mission implementation
        Mission implementation = new Mission();
        
        // Deploy MissionFactory
        factory = new MissionFactory(address(usdcToken), address(implementation));
        
        // Deploy MissionManager
        missionManager = new MissionManager(address(usdcToken), address(factory));
        
        // Transfer factory ownership to MissionManager
        factory.transferOwnership(address(missionManager));
        
        // Authorize contracts in IdentityLayer
        identityLayer.setAuthorizedUpdater(address(minerIncentive), true);
        identityLayer.setAuthorizedUpdater(address(missionManager), true);
        
        // Mint USDC to owner and users
        usdcToken.mint(owner, 10000000 * 10**6); // 10M USDC
        usdcToken.mint(user1, 100000 * 10**6); // 100k USDC
        usdcToken.mint(user2, 100000 * 10**6);
        usdcToken.mint(user3, 100000 * 10**6);
        usdcToken.mint(miner1, 100000 * 10**6);
        usdcToken.mint(miner2, 100000 * 10**6);
        
        // Setup participant data for Merkle tree
        setupParticipantData();
        
        // Generate DIDs (don't register them in setUp - let individual tests register)
        did1 = keccak256(abi.encodePacked("did:test:user1", user1, block.timestamp));
        did2 = keccak256(abi.encodePacked("did:test:user2", user2, block.timestamp));
        did3 = keccak256(abi.encodePacked("did:test:user3", user3, block.timestamp));
        minerDid1 = keccak256(abi.encodePacked("did:test:miner1", miner1, block.timestamp));
        minerDid2 = keccak256(abi.encodePacked("did:test:miner2", miner2, block.timestamp));
        
        vm.stopPrank();
    }
    
    function setupParticipantData() internal {
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
        
        // Generate Merkle root
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
        
        for (uint256 i = 0; i < leaves.length; i++) {
            currentLevel[i] = leaves[i];
        }
        
        uint256 currentIndex = index;
        
        while (currentLevel.length > 1) {
            uint256 nextLevelLength = (currentLevel.length + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelLength);
            
            bytes32[] memory newProof = new bytes32[](proof.length + 1);
            for (uint256 i = 0; i < proof.length; i++) {
                newProof[i] = proof[i];
            }
            
            if (currentIndex % 2 == 0) {
                if (currentIndex + 1 < currentLevel.length) {
                    newProof[proof.length] = currentLevel[currentIndex + 1];
                }
            } else {
                newProof[proof.length] = currentLevel[currentIndex - 1];
            }
            
            proof = newProof;
            
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
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
    
    // ============ Identity Layer Tests ============
    
    function testIdentityRegistration() public {
        // Generate unique DID for this test
        bytes32 testDid = keccak256(abi.encodePacked("testIdentityRegistration", user1, block.number));
        
        vm.startPrank(user1);
        
        identityLayer.registerIdentity(testDid, "ipfs://user1-metadata");
        identityLayer.linkAddressToDid(testDid);
        
        IdentityLayer.Identity memory identity = identityLayer.getIdentity(testDid);
        assertEq(identity.owner, user1);
        assertEq(identity.did, testDid);
        assertTrue(identity.isActive);
        assertEq(identityLayer.getDidForAddress(user1), testDid);
        
        vm.stopPrank();
    }
    
    function testMultipleIdentityRegistrations() public {
        // Generate unique DIDs for this test
        bytes32 testDid1 = keccak256(abi.encodePacked("testMultipleIdentityRegistrations", user1, block.number));
        bytes32 testDid2 = keccak256(abi.encodePacked("testMultipleIdentityRegistrations", user2, block.number));
        bytes32 testDid3 = keccak256(abi.encodePacked("testMultipleIdentityRegistrations", user3, block.number));
        
        vm.startPrank(user1);
        identityLayer.registerIdentity(testDid1, "ipfs://user1-metadata");
        identityLayer.linkAddressToDid(testDid1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        identityLayer.registerIdentity(testDid2, "ipfs://user2-metadata");
        identityLayer.linkAddressToDid(testDid2);
        vm.stopPrank();
        
        vm.startPrank(user3);
        identityLayer.registerIdentity(testDid3, "ipfs://user3-metadata");
        identityLayer.linkAddressToDid(testDid3);
        vm.stopPrank();
        
        assertEq(identityLayer.getTotalIdentities(), 3);
    }
    
    function testReputationTracking() public {
        // Generate unique DID for this test
        bytes32 testDid = keccak256(abi.encodePacked("testReputationTracking", user1, block.number));
        
        vm.startPrank(user1);
        identityLayer.registerIdentity(testDid, "ipfs://user1-metadata");
        identityLayer.linkAddressToDid(testDid);
        vm.stopPrank();
        
        vm.startPrank(address(identityLayer));
        identityLayer.recordTransaction(user1, 1000 * 10**6, true);
        identityLayer.recordTransaction(user1, 500 * 10**6, true);
        identityLayer.recordTransaction(user1, 200 * 10**6, false);
        vm.stopPrank();
        
        IdentityLayer.ReputationMetrics memory metrics = identityLayer.getReputationMetricsByAddress(user1);
        assertEq(metrics.transactionCount, 3);
        assertEq(metrics.successfulTransactions, 2);
        assertEq(metrics.failedTransactions, 1);
        assertEq(metrics.totalVolume, 1700 * 10**6);
    }
    
    // ============ Mission Creation Tests ============
    
    function testCreateMissionThroughManager() public {
        vm.startPrank(owner);
        
        (uint256 missionId, address missionAddress) = missionManager.createMission(
            "Test Mission",
            "Test Description"
        );
        
        assertEq(missionId, 1);
        assertTrue(missionAddress != address(0));
        assertEq(missionManager.getTotalMissions(), 1);
        
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        assertEq(info.name, "Test Mission");
        assertEq(info.description, "Test Description");
        assertTrue(info.isActive);
        
        vm.stopPrank();
    }
    
    function testAddApplicationToMission() public {
        vm.startPrank(owner);
        
        missionManager.createMission("Test Mission", "Test Description");
        
        missionManager.addApplicationToMission(
            1,
            "Test App",
            "Test App Description",
            "https://testapp.com",
            "banner.jpg",
            "logo.jpg"
        );
        
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        Mission missionContract = Mission(info.missionAddress);
        
        assertEq(missionContract.getApplicationCount(), 1);
        
        IMission.Application memory app = missionContract.getApplication(1);
        assertEq(app.name, "Test App");
        assertEq(app.description, "Test App Description");
        
        vm.stopPrank();
    }
    
    function testAddInteractionToMission() public {
        vm.startPrank(owner);
        
        missionManager.createMission("Test Mission", "Test Description");
        missionManager.addApplicationToMission(
            1,
            "Test App",
            "Test App Description",
            "https://testapp.com",
            "banner.jpg",
            "logo.jpg"
        );
        
        missionManager.addInteractionToMission(
            1,
            1,
            "Test Interaction",
            "Test Interaction Description",
            "Click Here",
            "https://interaction.com",
            100 * 10**6
        );
        
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        Mission missionContract = Mission(info.missionAddress);
        
        assertEq(missionContract.getInteractionCount(), 1);
        
        IMission.Interaction memory interaction = missionContract.getInteraction(1);
        assertEq(interaction.title, "Test Interaction");
        assertEq(interaction.rewardAmount, 100 * 10**6);
        
        vm.stopPrank();
    }
    
    // ============ Reward Distribution Tests ============
    
    function testUSDCRewardDistribution() public {
        vm.startPrank(owner);
        
        // Create mission
        missionManager.createMission("Reward Mission", "Test Description");
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        Mission missionContract = Mission(info.missionAddress);
        
        // Set reward contracts through MissionManager
        missionManager.setMissionRewardContracts(
            1,
            address(rewardManager),
            address(settlement),
            address(identityLayer)
        );
        
        // Set Merkle root
        missionManager.updateMissionParticipantsMerkleRoot(1, merkleRoot);
        
        // Deposit rewards through MissionManager
        usdcToken.approve(address(missionManager), 1000 * 10**6);
        missionManager.depositRewardsToMission(1, 1000 * 10**6);
        
        // Distribute rewards through MissionManager
        missionManager.distributeRewardsForMission(1);
        
        assertTrue(missionContract.rewardsDistributed());
        assertEq(missionContract.distributedRewards(), 1000 * 10**6);
        
        vm.stopPrank();
    }
    
    function testClaimUSDCRewards() public {
        vm.startPrank(owner);
        
        // Setup mission with rewards
        missionManager.createMission("Reward Mission", "Test Description");
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        Mission missionContract = Mission(info.missionAddress);
        
        missionManager.setMissionRewardContracts(
            1,
            address(rewardManager),
            address(settlement),
            address(identityLayer)
        );
        
        missionManager.updateMissionParticipantsMerkleRoot(1, merkleRoot);
        
        usdcToken.approve(address(missionManager), 1000 * 10**6);
        missionManager.depositRewardsToMission(1, 1000 * 10**6);
        missionManager.distributeRewardsForMission(1);
        
        vm.stopPrank();
        
        // User1 claims reward through MissionManager
        vm.startPrank(user1);
        uint256 balanceBefore = usdcToken.balanceOf(user1);
        bytes32[] memory proof = generateMerkleProof(0);
        
        missionManager.claimRewardFromMission(
            1,
            participants[0].missionExecutionId,
            participants[0].rewardAmount,
            proof
        );
        
        uint256 balanceAfter = usdcToken.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, participants[0].rewardAmount);
        
        // Check claim status through mission contract
        MissionManager.MissionInfo memory claimInfo = missionManager.getMissionInfo(1);
        Mission claimMissionContract = Mission(claimInfo.missionAddress);
        assertTrue(claimMissionContract.hasUserClaimedReward(user1));
        
        vm.stopPrank();
    }
    
    function testMultipleUsersClaimRewards() public {
        vm.startPrank(owner);
        
        // Setup mission
        missionManager.createMission("Reward Mission", "Test Description");
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        Mission missionContract = Mission(info.missionAddress);
        
        missionManager.setMissionRewardContracts(
            1,
            address(rewardManager),
            address(settlement),
            address(identityLayer)
        );
        
        missionManager.updateMissionParticipantsMerkleRoot(1, merkleRoot);
        
        usdcToken.approve(address(missionManager), 1000 * 10**6);
        missionManager.depositRewardsToMission(1, 1000 * 10**6);
        missionManager.distributeRewardsForMission(1);
        
        vm.stopPrank();
        
        // User1 claims through MissionManager
        vm.startPrank(user1);
        bytes32[] memory proof1 = generateMerkleProof(0);
        missionManager.claimRewardFromMission(
            1,
            participants[0].missionExecutionId,
            participants[0].rewardAmount,
            proof1
        );
        vm.stopPrank();
        
        // User2 claims through MissionManager
        vm.startPrank(user2);
        bytes32[] memory proof2 = generateMerkleProof(1);
        missionManager.claimRewardFromMission(
            1,
            participants[1].missionExecutionId,
            participants[1].rewardAmount,
            proof2
        );
        vm.stopPrank();
        
        // User3 claims through MissionManager
        vm.startPrank(user3);
        bytes32[] memory proof3 = generateMerkleProof(2);
        missionManager.claimRewardFromMission(
            1,
            participants[2].missionExecutionId,
            participants[2].rewardAmount,
            proof3
        );
        vm.stopPrank();
        
        // Check claims through mission contract
        MissionManager.MissionInfo memory finalInfo = missionManager.getMissionInfo(1);
        Mission finalMissionContract = Mission(finalInfo.missionAddress);
        assertTrue(finalMissionContract.hasUserClaimedReward(user1));
        assertTrue(finalMissionContract.hasUserClaimedReward(user2));
        assertTrue(finalMissionContract.hasUserClaimedReward(user3));
    }
    
    // ============ Miner Incentive Tests ============
    
    function testMinerRegistration() public {
        // Generate unique DID for this test
        bytes32 testMinerDid = keccak256(abi.encodePacked("testMinerRegistration", miner1, block.number));
        
        vm.startPrank(miner1);
        
        identityLayer.registerIdentity(testMinerDid, "ipfs://miner1-metadata");
        identityLayer.linkAddressToDid(testMinerDid);
        
        vm.stopPrank();
        
        vm.startPrank(owner);
        minerIncentive.registerMiner(miner1);
        
        MinerIncentive.Miner memory miner = minerIncentive.getMiner(miner1);
        assertTrue(miner.isActive);
        assertEq(miner.minerAddress, miner1);
        
        vm.stopPrank();
    }
    
    function testRecordMinerContribution() public {
        // Generate unique DID for this test
        bytes32 testMinerDid = keccak256(abi.encodePacked("testRecordMinerContribution", miner1, block.number));
        
        vm.startPrank(miner1);
        
        identityLayer.registerIdentity(testMinerDid, "ipfs://miner1-metadata");
        identityLayer.linkAddressToDid(testMinerDid);
        
        vm.stopPrank();
        
        vm.startPrank(owner);
        minerIncentive.registerMiner(miner1);
        
        vm.stopPrank();
        
        vm.startPrank(owner);
        
        // Create incentive pool
        usdcToken.approve(address(minerIncentive), 5000 * 10**6);
        minerIncentive.createIncentivePool(
            "Q1 2024 Pool",
            5000 * 10**6,
            block.timestamp,
            block.timestamp + 90 days
        );
        
        // Record contribution (returns void, contribution ID is auto-incremented)
        minerIncentive.recordContribution(
            miner1,
            1000 * 10**6,
            5, // 5 people onboarded
            "US",
            "onboarding",
            keccak256("proof-hash"),
            1 // poolId
        );
        
        // Get the first contribution (ID starts at 1)
        MinerIncentive.Contribution memory contribution = minerIncentive.getContribution(1);
        assertEq(contribution.miner, miner1);
        assertEq(contribution.peopleOnboarded, 5);
        assertEq(contribution.geography, "US");
        
        vm.stopPrank();
    }
    
    function testMinerRewardDistribution() public {
        // Generate unique DID for this test
        bytes32 testMinerDid = keccak256(abi.encodePacked("testMinerRewardDistribution", miner1, block.number));
        
        vm.startPrank(miner1);
        identityLayer.registerIdentity(testMinerDid, "ipfs://miner1-metadata");
        identityLayer.linkAddressToDid(testMinerDid);
        vm.stopPrank();
        
        vm.startPrank(owner);
        minerIncentive.registerMiner(miner1);
        vm.stopPrank();
        
        vm.startPrank(owner);
        
        // Create pool and fund it
        usdcToken.approve(address(minerIncentive), 10000 * 10**6);
        minerIncentive.createIncentivePool(
            "Q1 2024 Pool",
            10000 * 10**6,
            block.timestamp,
            block.timestamp + 90 days
        );
        
        // Record contributions
        minerIncentive.recordContribution(
            miner1,
            2000 * 10**6,
            10,
            "US",
            "onboarding",
            keccak256("proof1"),
            1 // poolId
        );
        
        minerIncentive.recordContribution(
            miner1,
            1500 * 10**6,
            8,
            "US",
            "onboarding",
            keccak256("proof2"),
            1 // poolId
        );
        
        // Verify contributions
        minerIncentive.verifyContribution(1);
        minerIncentive.verifyContribution(2);
        
        // Distribute rewards (simplified - in real scenario, owner would call with specific amounts)
        address[] memory miners = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        miners[0] = miner1;
        amounts[0] = 1000 * 10**6; // 1000 USDC reward
        
        minerIncentive.distributeRewards(
            1,
            miners,
            amounts,
            MinerIncentive.RewardType.USDC,
            0
        );
        
        MinerIncentive.Miner memory miner = minerIncentive.getMiner(miner1);
        assertGt(miner.totalRewardsEarned, 0);
        
        vm.stopPrank();
    }
    
    // ============ Full System Integration Test ============
    
    function testFullSystemFlow() public {
        // Generate unique DIDs for this test
        bytes32 testDid1 = keccak256(abi.encodePacked("testFullSystemFlow", user1, block.number));
        bytes32 testDid2 = keccak256(abi.encodePacked("testFullSystemFlow", user2, block.number));
        
        // Step 1: Register identities
        vm.startPrank(user1);
        identityLayer.registerIdentity(testDid1, "ipfs://user1-metadata");
        identityLayer.linkAddressToDid(testDid1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        identityLayer.registerIdentity(testDid2, "ipfs://user2-metadata");
        identityLayer.linkAddressToDid(testDid2);
        vm.stopPrank();
        
        // Step 2: Create mission
        vm.startPrank(owner);
        missionManager.createMission("Full System Test", "Integration test mission");
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        Mission missionContract = Mission(info.missionAddress);
        
        // Step 3: Configure mission through MissionManager
        missionManager.setMissionRewardContracts(
            1,
            address(rewardManager),
            address(settlement),
            address(identityLayer)
        );
        
        // Step 4: Add application and interaction
        missionManager.addApplicationToMission(
            1,
            "Test App",
            "Test App Description",
            "https://testapp.com",
            "banner.jpg",
            "logo.jpg"
        );
        
        missionManager.addInteractionToMission(
            1,
            1,
            "Complete Task",
            "Complete this task to earn rewards",
            "Start",
            "https://task.com",
            100 * 10**6
        );
        
        // Step 5: Set Merkle root and deposit rewards through MissionManager
        missionManager.updateMissionParticipantsMerkleRoot(1, merkleRoot);
        usdcToken.approve(address(missionManager), 1000 * 10**6);
        missionManager.depositRewardsToMission(1, 1000 * 10**6);
        missionManager.distributeRewardsForMission(1);
        
        vm.stopPrank();
        
        // Step 6: Users claim rewards
        vm.startPrank(user1);
        bytes32[] memory proof1 = generateMerkleProof(0);
        missionContract.claimReward(
            participants[0].missionExecutionId,
            participants[0].rewardAmount,
            proof1
        );
        vm.stopPrank();
        
        vm.startPrank(user2);
        bytes32[] memory proof2 = generateMerkleProof(1);
        missionContract.claimReward(
            participants[1].missionExecutionId,
            participants[1].rewardAmount,
            proof2
        );
        vm.stopPrank();
        
        // Step 7: Verify reputation was updated
        IdentityLayer.ReputationMetrics memory metrics1 = identityLayer.getReputationMetricsByAddress(user1);
        IdentityLayer.ReputationMetrics memory metrics2 = identityLayer.getReputationMetricsByAddress(user2);
        
        assertGt(metrics1.reputationScore, 0);
        assertGt(metrics2.reputationScore, 0);
        assertGt(metrics1.rewardsEarned, 0);
        assertGt(metrics2.rewardsEarned, 0);
        
        // Step 8: Verify balances
        assertGt(usdcToken.balanceOf(user1), 100000 * 10**6); // Initial + reward
        assertGt(usdcToken.balanceOf(user2), 100000 * 10**6);
    }
    
    function testMultipleMissionsFlow() public {
        vm.startPrank(owner);
        
        // Create multiple missions
        missionManager.createMission("Mission 1", "First mission");
        missionManager.createMission("Mission 2", "Second mission");
        missionManager.createMission("Mission 3", "Third mission");
        
        assertEq(missionManager.getTotalMissions(), 3);
        
        // Verify all missions are active
        for (uint256 i = 1; i <= 3; i++) {
            MissionManager.MissionInfo memory info = missionManager.getMissionInfo(i);
            assertTrue(info.isActive);
            assertTrue(info.missionAddress != address(0));
        }
        
        vm.stopPrank();
    }
    
    function testMissionDeactivation() public {
        vm.startPrank(owner);
        
        missionManager.createMission("Test Mission", "Test Description");
        MissionManager.MissionInfo memory info = missionManager.getMissionInfo(1);
        assertTrue(info.isActive);
        
        missionManager.deactivateMission(1);
        
        info = missionManager.getMissionInfo(1);
        assertFalse(info.isActive);
        
        vm.stopPrank();
    }
}

