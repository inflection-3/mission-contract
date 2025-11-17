#!/bin/bash

# Mission Contract System Verification Script
# Usage: ./verify.sh [sepolia|mainnet|monad-testnet]

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
IDENTITY_LAYER_ADDRESS=$(jq -r '.deployments.IdentityLayer.address' $DEPLOYMENT_FILE)
REWARD_MANAGER_ADDRESS=$(jq -r '.deployments.INXRewardManager.address' $DEPLOYMENT_FILE)
SETTLEMENT_ADDRESS=$(jq -r '.deployments.StablecoinSettlement.address' $DEPLOYMENT_FILE)
MINER_INCENTIVE_ADDRESS=$(jq -r '.deployments.MinerIncentive.address' $DEPLOYMENT_FILE)
MISSION_IMPL_ADDRESS=$(jq -r '.deployments.MissionImplementation.address' $DEPLOYMENT_FILE)
FACTORY_ADDRESS=$(jq -r '.deployments.MissionFactory.address' $DEPLOYMENT_FILE)
MISSION_MANAGER_ADDRESS=$(jq -r '.deployments.MissionManager.address' $DEPLOYMENT_FILE)
USDC_ADDRESS=$(jq -r '.usdcAddress' $DEPLOYMENT_FILE)
RPC_URL=$(jq -r '.rpcUrl' $DEPLOYMENT_FILE)
EXPLORER_URL=$(jq -r '.explorerUrl' $DEPLOYMENT_FILE)

# Determine chain ID
case $NETWORK in
    sepolia)
        CHAIN_ID="84532"
        NETWORK_NAME="Base Sepolia"
        ;;
    mainnet)
        CHAIN_ID="8453"
        NETWORK_NAME="Base Mainnet"
        ;;
    monad-testnet)
        CHAIN_ID="10143"
        NETWORK_NAME="Monad Testnet"
        ;;
    *)
        echo "Error: Invalid network"
        exit 1
        ;;
esac

echo "🔍 Verifying contracts on $NETWORK_NAME..."
echo "📡 RPC URL: $RPC_URL"
echo ""

# Verify IdentityLayer
echo "🔍 Verifying IdentityLayer at $IDENTITY_LAYER_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    $IDENTITY_LAYER_ADDRESS \
    src/IdentityLayer.sol:IdentityLayer || echo "⚠️  IdentityLayer verification skipped or failed"

# Verify INXRewardManager
echo "🔍 Verifying INXRewardManager at $REWARD_MANAGER_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    $REWARD_MANAGER_ADDRESS \
    src/INXRewardManager.sol:INXRewardManager \
    --constructor-args $(cast abi-encode "constructor(address)" $USDC_ADDRESS) || echo "⚠️  INXRewardManager verification skipped or failed"

# Verify StablecoinSettlement
echo "🔍 Verifying StablecoinSettlement at $SETTLEMENT_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    $SETTLEMENT_ADDRESS \
    src/StablecoinSettlement.sol:StablecoinSettlement \
    --constructor-args $(cast abi-encode "constructor(address)" $USDC_ADDRESS) || echo "⚠️  StablecoinSettlement verification skipped or failed"

# Verify MinerIncentive
echo "🔍 Verifying MinerIncentive at $MINER_INCENTIVE_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    $MINER_INCENTIVE_ADDRESS \
    src/MinerIncentive.sol:MinerIncentive \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address)" $USDC_ADDRESS $IDENTITY_LAYER_ADDRESS $REWARD_MANAGER_ADDRESS $SETTLEMENT_ADDRESS) || echo "⚠️  MinerIncentive verification skipped or failed"

# Verify Mission Implementation
echo "🔍 Verifying Mission Implementation at $MISSION_IMPL_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    $MISSION_IMPL_ADDRESS \
    src/Mission.sol:Mission || echo "⚠️  Mission Implementation verification skipped or failed"

# Verify MissionFactory
echo "🔍 Verifying MissionFactory at $FACTORY_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    $FACTORY_ADDRESS \
    src/MissionFactory.sol:MissionFactory \
    --constructor-args $(cast abi-encode "constructor(address,address)" $USDC_ADDRESS $MISSION_IMPL_ADDRESS) || echo "⚠️  MissionFactory verification skipped or failed"

# Verify MissionManager
echo "🔍 Verifying MissionManager at $MISSION_MANAGER_ADDRESS..."
forge verify-contract \
    --rpc-url $RPC_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    $MISSION_MANAGER_ADDRESS \
    src/MissionManager.sol:MissionManager \
    --constructor-args $(cast abi-encode "constructor(address,address)" $USDC_ADDRESS $FACTORY_ADDRESS) || echo "⚠️  MissionManager verification skipped or failed"

echo ""
echo "🎉 Contract verification completed!"
echo ""
echo "View verified contracts on $EXPLORER_URL:"
echo "  IdentityLayer: $EXPLORER_URL/address/$IDENTITY_LAYER_ADDRESS"
echo "  INXRewardManager: $EXPLORER_URL/address/$REWARD_MANAGER_ADDRESS"
echo "  StablecoinSettlement: $EXPLORER_URL/address/$SETTLEMENT_ADDRESS"
echo "  MinerIncentive: $EXPLORER_URL/address/$MINER_INCENTIVE_ADDRESS"
echo "  Mission Implementation: $EXPLORER_URL/address/$MISSION_IMPL_ADDRESS"
echo "  MissionFactory: $EXPLORER_URL/address/$FACTORY_ADDRESS"
echo "  MissionManager: $EXPLORER_URL/address/$MISSION_MANAGER_ADDRESS"
