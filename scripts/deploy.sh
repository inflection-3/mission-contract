#!/bin/bash

# Mission Contract System Deployment Script
# Usage: ./deploy.sh [sepolia|mainnet]

set -e

NETWORK=$1

if [ -z "$NETWORK" ]; then
    echo "Usage: $0 [sepolia|mainnet]"
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
        ;;
    mainnet)
        RPC_URL="https://mainnet.base.org"
        EXPLORER_URL="https://basescan.org"
        ;;
    *)
        echo "Error: Invalid network. Use 'sepolia' or 'mainnet'"
        exit 1
        ;;
esac

echo "🚀 Deploying Mission Contract System to Base $NETWORK..."
echo "📡 RPC URL: $RPC_URL"
echo "🔍 Explorer: $EXPLORER_URL"
echo "💰 USDC Address: $USDC_ADDRESS"
echo ""

# Deploy contracts
echo "📦 Deploying MissionFactory..."
FACTORY_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --json \
    src/MissionFactory.sol:MissionFactory \
    --constructor-args $USDC_ADDRESS | jq -r '.deployedTo')

echo "✅ MissionFactory deployed at: $FACTORY_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$FACTORY_ADDRESS"

echo ""
echo "📦 Deploying MissionManager..."
MISSION_MANAGER_ADDRESS=$(forge create \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --json \
    src/MissionManager.sol:MissionManager \
    --constructor-args $USDC_ADDRESS $FACTORY_ADDRESS | jq -r '.deployedTo')

echo "✅ MissionManager deployed at: $MISSION_MANAGER_ADDRESS"
echo "🔗 View on explorer: $EXPLORER_URL/address/$MISSION_MANAGER_ADDRESS"

# Save deployment info
DEPLOYMENT_FILE="deployments/base-$NETWORK.json"
mkdir -p deployments

cat > $DEPLOYMENT_FILE << EOF
{
  "network": "base-$NETWORK",
  "rpcUrl": "$RPC_URL",
  "explorerUrl": "$EXPLORER_URL",
  "usdcAddress": "$USDC_ADDRESS",
  "deployments": {
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
echo "Next steps:"
echo "1. Verify contracts: make verify-$NETWORK"
echo "2. Test deployed contracts: make test-deployed-$NETWORK"
echo "3. Or run full pipeline: make deploy-and-test-$NETWORK"
