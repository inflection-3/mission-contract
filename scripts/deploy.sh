#!/bin/bash

# Mission Contract System Deployment Script
# Usage: ./deploy.sh [sepolia|mainnet|monad-testnet]

set -e

NETWORK=$1

if [ -z "$NETWORK" ]; then
    echo "Usage: $0 [sepolia|mainnet|monad-testnet]"
    exit 1
fi

# Check if required environment variables are set
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY environment variable is not set"
    exit 1
fi

if [ -z "$USDC_ADDRESS" ]; then
    echo "Error: USDC_ADDRESS environment variable is not set"
    echo "For Base Sepolia, use: 0x036CbD53842c5426634e7929541eC2318f3dCF7e"
    echo "For Base Mainnet, use: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
    exit 1
fi

# Set RPC URLs based on network
case $NETWORK in
    sepolia)
        RPC_URL="https://sepolia.base.org"
        EXPLORER_URL="https://sepolia.basescan.org"
        NETWORK_NAME="Base Sepolia"
        DEPLOYMENT_PREFIX="base"
        ;;
    mainnet)
        RPC_URL="https://mainnet.base.org"
        EXPLORER_URL="https://basescan.org"
        NETWORK_NAME="Base Mainnet"
        DEPLOYMENT_PREFIX="base"
        ;;
    monad-testnet)
        RPC_URL="https://rpc.ankr.com/monad_testnet"
        EXPLORER_URL="https://testnet-explorer.monad.xyz"
        NETWORK_NAME="Monad Testnet"
        DEPLOYMENT_PREFIX="monad"
        ;;
    *)
        echo "Error: Invalid network. Use 'sepolia', 'mainnet', or 'monad-testnet'"
        exit 1
        ;;
esac

echo "🚀 Deploying Mission Contract System to $NETWORK_NAME..."
echo "📡 RPC URL: $RPC_URL"
echo "🔍 Explorer: $EXPLORER_URL"
echo "💰 USDC Address: $USDC_ADDRESS"
echo ""

# Deploy IdentityLayer first (no dependencies)
echo ""
echo "📦 Deploying IdentityLayer..."
IDENTITY_LAYER_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --json \
    src/IdentityLayer.sol:IdentityLayer | jq -r '.deployedTo')

echo "✅ IdentityLayer deployed at: $IDENTITY_LAYER_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$IDENTITY_LAYER_ADDRESS"

# Deploy INXRewardManager
echo ""
echo "📦 Deploying INXRewardManager..."
REWARD_MANAGER_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --json \
    src/INXRewardManager.sol:INXRewardManager \
    --constructor-args $USDC_ADDRESS | jq -r '.deployedTo')

echo "✅ INXRewardManager deployed at: $REWARD_MANAGER_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$REWARD_MANAGER_ADDRESS"

# Deploy StablecoinSettlement
echo ""
echo "📦 Deploying StablecoinSettlement..."
SETTLEMENT_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --json \
    src/StablecoinSettlement.sol:StablecoinSettlement \
    --constructor-args $USDC_ADDRESS | jq -r '.deployedTo')

echo "✅ StablecoinSettlement deployed at: $SETTLEMENT_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$SETTLEMENT_ADDRESS"

# Deploy MinerIncentive
echo ""
echo "📦 Deploying MinerIncentive..."
MINER_INCENTIVE_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --json \
    src/MinerIncentive.sol:MinerIncentive \
    --constructor-args $USDC_ADDRESS $IDENTITY_LAYER_ADDRESS $REWARD_MANAGER_ADDRESS $SETTLEMENT_ADDRESS | jq -r '.deployedTo')

echo "✅ MinerIncentive deployed at: $MINER_INCENTIVE_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$MINER_INCENTIVE_ADDRESS"

# Deploy Mission implementation
echo ""
echo "📦 Deploying Mission Implementation..."
MISSION_IMPL_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --json \
    src/Mission.sol:Mission | jq -r '.deployedTo')

echo "✅ Mission Implementation deployed at: $MISSION_IMPL_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$MISSION_IMPL_ADDRESS"

# Update MissionFactory deployment to use implementation
echo ""
echo "📦 Deploying MissionFactory..."
FACTORY_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --json \
    src/MissionFactory.sol:MissionFactory \
    --constructor-args $USDC_ADDRESS $MISSION_IMPL_ADDRESS | jq -r '.deployedTo')

echo "✅ MissionFactory deployed at: $FACTORY_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$FACTORY_ADDRESS"

# Update MissionManager deployment
echo ""
echo "📦 Deploying MissionManager..."
MISSION_MANAGER_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --json \
    src/MissionManager.sol:MissionManager \
    --constructor-args $USDC_ADDRESS $FACTORY_ADDRESS | jq -r '.deployedTo')

echo "✅ MissionManager deployed at: $MISSION_MANAGER_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$MISSION_MANAGER_ADDRESS"

# Save deployment info
if [ "$NETWORK" = "monad-testnet" ]; then
    DEPLOYMENT_FILE="deployments/monad-testnet.json"
else
    DEPLOYMENT_FILE="deployments/$DEPLOYMENT_PREFIX-$NETWORK.json"
fi
mkdir -p deployments

cat > $DEPLOYMENT_FILE << EOF
{
  "network": "$NETWORK",
  "rpcUrl": "$RPC_URL",
  "explorerUrl": "$EXPLORER_URL",
  "usdcAddress": "$USDC_ADDRESS",
  "deployments": {
    "IdentityLayer": {
      "address": "$IDENTITY_LAYER_ADDRESS",
      "explorerUrl": "$EXPLORER_URL/address/$IDENTITY_LAYER_ADDRESS"
    },
    "INXRewardManager": {
      "address": "$REWARD_MANAGER_ADDRESS",
      "explorerUrl": "$EXPLORER_URL/address/$REWARD_MANAGER_ADDRESS"
    },
    "StablecoinSettlement": {
      "address": "$SETTLEMENT_ADDRESS",
      "explorerUrl": "$EXPLORER_URL/address/$SETTLEMENT_ADDRESS"
    },
    "MinerIncentive": {
      "address": "$MINER_INCENTIVE_ADDRESS",
      "explorerUrl": "$EXPLORER_URL/address/$MINER_INCENTIVE_ADDRESS"
    },
    "MissionImplementation": {
      "address": "$MISSION_IMPL_ADDRESS",
      "explorerUrl": "$EXPLORER_URL/address/$MISSION_IMPL_ADDRESS"
    },
    "MissionFactory": {
      "address": "$FACTORY_ADDRESS",
      "explorerUrl": "$EXPLORER_URL/address/$FACTORY_ADDRESS"
    },
    "MissionManager": {
      "address": "$MISSION_MANAGER_ADDRESS",
      "explorerUrl": "$EXPLORER_URL/address/$MISSION_MANAGER_ADDRESS"
    }
  },
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo ""
echo "📄 Deployment info saved to: $DEPLOYMENT_FILE"
echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "  - IdentityLayer: $IDENTITY_LAYER_ADDRESS"
echo "  - INXRewardManager: $REWARD_MANAGER_ADDRESS"
echo "  - StablecoinSettlement: $SETTLEMENT_ADDRESS"
echo "  - MinerIncentive: $MINER_INCENTIVE_ADDRESS"
echo "  - Mission Implementation: $MISSION_IMPL_ADDRESS"
echo "  - MissionFactory: $FACTORY_ADDRESS"
echo "  - MissionManager: $MISSION_MANAGER_ADDRESS"
echo ""
echo "Next steps:"
if [ "$NETWORK" = "monad-testnet" ]; then
    echo "1. Authorize contracts in IdentityLayer"
    echo "2. Configure reward contracts in Mission and MinerIncentive"
    echo "3. Test deployed contracts: make test-deployed-monad-testnet"
else
    echo "1. Verify contracts: make verify-$NETWORK"
    echo "2. Test deployed contracts: make test-deployed-$NETWORK"
    echo "3. Or run full pipeline: make deploy-and-test-$NETWORK"
fi
