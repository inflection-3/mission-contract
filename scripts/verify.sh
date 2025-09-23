#!/bin/bash

# Mission Contract System Verification Script
# Usage: ./verify.sh [sepolia|mainnet]

set -e

NETWORK=$1

if [ -z "$NETWORK" ]; then
    echo "Usage: $0 [sepolia|mainnet]"
    exit 1
fi

# Check if deployment file exists
DEPLOYMENT_FILE="deployments/base-$NETWORK.json"
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

echo "🔍 Verifying contracts on Base $NETWORK..."
echo "📡 RPC URL: $RPC_URL"
echo ""

# Verify MissionFactory
echo "🔍 Verifying MissionFactory at $FACTORY_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $(if [ "$NETWORK" = "sepolia" ]; then echo "84532"; else echo "8453"; fi) \
    $FACTORY_ADDRESS \
    src/MissionFactory.sol:MissionFactory \
    --constructor-args $(cast abi-encode "constructor(address)" $USDC_ADDRESS)

echo "✅ MissionFactory verified!"

# Verify MissionManager
echo "🔍 Verifying MissionManager at $MISSION_MANAGER_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $(if [ "$NETWORK" = "sepolia" ]; then echo "84532"; else echo "8453"; fi) \
    $MISSION_MANAGER_ADDRESS \
    src/MissionManager.sol:MissionManager \
    --constructor-args $(cast abi-encode "constructor(address,address)" $USDC_ADDRESS $FACTORY_ADDRESS)

echo "✅ MissionManager verified!"

echo ""
echo "🎉 All contracts verified successfully!"
echo ""
echo "View verified contracts:"
echo "MissionFactory: https://sepolia.basescan.org/address/$FACTORY_ADDRESS"
echo "MissionManager: https://sepolia.basescan.org/address/$MISSION_MANAGER_ADDRESS"
