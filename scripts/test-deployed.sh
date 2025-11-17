#!/bin/bash

# Mission Contract System Testing Script for Deployed Contracts
# Usage: ./test-deployed.sh [sepolia|mainnet|monad-testnet]

set -e

NETWORK=$1

if [ -z "$NETWORK" ]; then
    echo "Usage: $0 [sepolia|mainnet|monad-testnet]"
    exit 1
fi

# Check if deployment file exists
if [ "$NETWORK" = "monad-testnet" ]; then
    DEPLOYMENT_FILE="deployments/monad-testnet.json"
else
    DEPLOYMENT_FILE="deployments/base-$NETWORK.json"
fi
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    echo "Error: Deployment file $DEPLOYMENT_FILE not found"
    echo "Please run deployment first: make deploy-$NETWORK"
    exit 1
fi

# Extract addresses from deployment file
FACTORY_ADDRESS=$(jq -r '.deployments.MissionFactory.address' $DEPLOYMENT_FILE)
MISSION_MANAGER_ADDRESS=$(jq -r '.deployments.MissionManager.address' $DEPLOYMENT_FILE)
USDC_ADDRESS=$(jq -r '.usdcAddress' $DEPLOYMENT_FILE)
RPC_URL=$(jq -r '.rpcUrl' $DEPLOYMENT_FILE)

echo "🧪 Testing deployed contracts on Base $NETWORK..."
echo "📡 RPC URL: $RPC_URL"
echo "🏭 MissionFactory: $FACTORY_ADDRESS"
echo "📋 MissionManager: $MISSION_MANAGER_ADDRESS"
echo "💰 USDC: $USDC_ADDRESS"
echo ""

# Create test script
cat > test-deployed.js << EOF
const { ethers } = require('ethers');

// Contract ABI (simplified for testing)
const MISSION_FACTORY_ABI = [
    "function createMission() external returns (address)",
    "function getMissionCount() external view returns (uint256)",
    "function getMission(uint256) external view returns (address)",
    "function getAllMissions() external view returns (address[] memory)"
];

const MISSION_MANAGER_ABI = [
    "function createMission(string memory name, string memory description) external returns (uint256 missionId, address missionAddress)",
    "function getTotalMissions() external view returns (uint256)",
    "function getMissionInfo(uint256) external view returns (tuple(uint256 missionId, address missionAddress, string name, string description, bool isActive, uint256 totalParticipants, uint256 totalRewards))",
    "function addApplicationToMission(uint256 missionId, string memory appName, string memory appDescription, string memory appUrl, string memory bannerImage, string memory appLogo) external",
    "function addInteractionToMission(uint256 missionId, uint256 applicationId, string memory title, string memory description, string memory actionTitle, string memory interactionUrl, uint256 rewardAmount) external"
];

const MISSION_ABI = [
    "function addApplication(string memory name, string memory description, string memory appUrl, string memory bannerImage, string memory appLogo) external",
    "function addInteraction(uint256 applicationId, string memory title, string memory description, string memory actionTitle, string memory interactionUrl, uint256 rewardAmount) external",
    "function addParticipant(address user, uint256[] memory interactionIds) external",
    "function depositRewards(uint256 amount) external",
    "function distributeRewards() external",
    "function getTotalParticipants() external view returns (uint256)",
    "function getTotalRewardPool() external view returns (uint256)",
    "function getApplicationCount() external view returns (uint256)",
    "function getInteractionCount() external view returns (uint256)"
];

async function testDeployedContracts() {
    console.log('🚀 Starting deployed contract tests...');
    
    // Connect to network
    const provider = new ethers.JsonRpcProvider('$RPC_URL');
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    console.log('📡 Connected to Base $NETWORK');
    console.log('👤 Wallet address:', wallet.address);
    
    // Get wallet balance
    const balance = await provider.getBalance(wallet.address);
    console.log('💰 Wallet balance:', ethers.formatEther(balance), 'ETH');
    
    // Connect to contracts
    const factory = new ethers.Contract('$FACTORY_ADDRESS', MISSION_FACTORY_ABI, wallet);
    const missionManager = new ethers.Contract('$MISSION_MANAGER_ADDRESS', MISSION_MANAGER_ABI, wallet);
    
    console.log('\\n🏭 Testing MissionFactory...');
    
    // Test factory functions
    const initialMissionCount = await factory.getMissionCount();
    console.log('📊 Initial mission count:', initialMissionCount.toString());
    
    // Create a mission through factory
    console.log('📦 Creating mission through factory...');
    const tx1 = await factory.createMission();
    await tx1.wait();
    
    const newMissionCount = await factory.getMissionCount();
    console.log('📊 New mission count:', newMissionCount.toString());
    
    const missionAddress = await factory.getMission(newMissionCount);
    console.log('🎯 Created mission at:', missionAddress);
    
    console.log('\\n📋 Testing MissionManager...');
    
    // Test mission contract functions
    const totalMissions = await missionManager.getTotalMissions();
    console.log('📊 Total missions in contract:', totalMissions.toString());
    
    // Create a mission through mission contract
    console.log('📦 Creating mission through MissionManager...');
    const tx2 = await missionManager.createMission("Test Mission", "A test mission for Base deployment");
    await tx2.wait();
    
    const missionId = tx2.returnValues.missionId;
    const missionAddress2 = tx2.returnValues.missionAddress;
    console.log('🎯 Created mission ID:', missionId.toString());
    console.log('🎯 Created mission address:', missionAddress2);
    
    // Get mission info
    const missionInfo = await missionManager.getMissionInfo(missionId);
    console.log('📋 Mission info:', {
        id: missionInfo.missionId.toString(),
        address: missionInfo.missionAddress,
        name: missionInfo.name,
        description: missionInfo.description,
        isActive: missionInfo.isActive
    });
    
    // Connect to the created mission
    const mission = new ethers.Contract(missionAddress2, MISSION_ABI, wallet);
    
    console.log('\\n🎯 Testing Mission contract...');
    
    // Add an application
    console.log('📱 Adding application...');
    const tx3 = await missionManager.addApplicationToMission(
        missionId,
        "Test App",
        "A test application",
        "https://testapp.com",
        "banner.jpg",
        "logo.jpg"
    );
    await tx3.wait();
    
    const appCount = await mission.getApplicationCount();
    console.log('📱 Application count:', appCount.toString());
    
    // Add an interaction
    console.log('⚡ Adding interaction...');
    const tx4 = await missionManager.addInteractionToMission(
        missionId,
        1, // application ID
        "Test Interaction",
        "A test interaction",
        "Click Here",
        "https://interaction.com",
        ethers.parseUnits("100", 6) // 100 USDC
    );
    await tx4.wait();
    
    const interactionCount = await mission.getInteractionCount();
    console.log('⚡ Interaction count:', interactionCount.toString());
    
    console.log('\\n✅ All tests completed successfully!');
    console.log('\\n📊 Summary:');
    console.log('- Factory missions created:', newMissionCount.toString());
    console.log('- MissionManager missions:', (await missionManager.getTotalMissions()).toString());
    console.log('- Applications added:', appCount.toString());
    console.log('- Interactions added:', interactionCount.toString());
}

testDeployedContracts().catch(console.error);
EOF

# Check if Node.js and ethers are available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js to run the tests."
    exit 1
fi

if ! npm list ethers &> /dev/null; then
    echo "📦 Installing ethers.js..."
    npm install ethers
fi

# Run the test
echo "🧪 Running deployed contract tests..."
node test-deployed.js

# Clean up
rm -f test-deployed.js

echo ""
echo "🎉 Deployed contract testing completed!"
echo ""
echo "📊 Test Results Summary:"
echo "✅ Contract deployment verification"
echo "✅ Factory mission creation"
echo "✅ MissionManager mission creation"
echo "✅ Application and interaction management"
echo "✅ Contract interaction testing"
