# Mission Contract System - Deployment Guide

This guide will walk you through deploying the Mission Contract System to Base blockchain.

## 🚀 Quick Deployment

### Prerequisites

1. **Environment Setup**
   ```bash
   # Copy environment template
   cp env.example .env
   
   # Edit .env with your values
   nano .env
   ```

2. **Required Environment Variables**
   ```bash
   # Your private key (without 0x prefix)
   PRIVATE_KEY=your_private_key_here
   
   # USDC contract address for the network
   USDC_ADDRESS=0x036CbD53842c5426634e7929541eC2318f3dCF7e  # Base Sepolia
   # USDC_ADDRESS=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913  # Base Mainnet
   
   # Etherscan API key for contract verification
   ETHERSCAN_API_KEY=your_etherscan_api_key_here
   ```

3. **Get Base Sepolia ETH**
   - Visit [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
   - Or use [Alchemy Faucet](https://sepoliafaucet.com/)

### Deploy to Base Sepolia (Recommended for Testing)

```bash
# Full deployment and testing pipeline
make deploy-and-test-sepolia
```

This will:
1. ✅ Build contracts
2. 🚀 Deploy to Base Sepolia
3. 🔍 Verify contracts on BaseScan
4. 🧪 Test deployed contracts

### Deploy to Base Mainnet

```bash
# Full deployment and testing pipeline
make deploy-and-test-mainnet
```

## 📋 Step-by-Step Deployment

### 1. Build Contracts

```bash
make build
```

### 2. Deploy to Base Sepolia

```bash
make deploy-sepolia
```

Expected output:
```
🚀 Deploying Mission Contract System to Base sepolia...
📡 RPC URL: https://sepolia.base.org
🔍 Explorer: https://sepolia.basescan.org
💰 USDC Address: 0x036CbD53842c5426634e7929541eC2318f3dCF7e

📦 Deploying MissionFactory...
✅ MissionFactory deployed at: 0x...
🔗 View on explorer: https://sepolia.basescan.org/address/0x...

📦 Deploying MissionManager...
✅ MissionManager deployed at: 0x...
🔗 View on explorer: https://sepolia.basescan.org/address/0x...

📄 Deployment info saved to: deployments/base-sepolia.json
```

### 3. Verify Contracts

```bash
make verify-sepolia
```

### 4. Test Deployed Contracts

```bash
make test-deployed-sepolia
```

## 🔧 Manual Script Usage

### Deploy Script

```bash
# Deploy to Base Sepolia
./scripts/deploy.sh sepolia

# Deploy to Base Mainnet
./scripts/deploy.sh mainnet
```

### Verify Script

```bash
# Verify on Base Sepolia
./scripts/verify.sh sepolia

# Verify on Base Mainnet
./scripts/verify.sh mainnet
```

### Test Script

```bash
# Test deployed contracts on Base Sepolia
./scripts/test-deployed.sh sepolia

# Test deployed contracts on Base Mainnet
./scripts/test-deployed.sh mainnet
```

## 📊 Deployment Verification

After deployment, you should see:

1. **Contract Addresses** in `deployments/base-{network}.json`
2. **Verified Contracts** on BaseScan
3. **Successful Test Results** from deployed contract testing

## 🧪 Testing Deployed Contracts

The test script will:

1. ✅ Connect to Base network
2. ✅ Verify wallet balance
3. ✅ Test MissionFactory functions
4. ✅ Test MissionManager functions
5. ✅ Create missions, applications, and interactions
6. ✅ Verify all functionality works on-chain

## 🔍 Troubleshooting

### Common Issues

1. **"Insufficient funds"**
   - Get Base Sepolia ETH from faucet
   - Check wallet balance

2. **"Private key not set"**
   - Ensure `.env` file exists and has correct `PRIVATE_KEY`

3. **"USDC address not set"**
   - Set correct `USDC_ADDRESS` for your network

4. **"Etherscan API key not set"**
   - Get API key from [Etherscan](https://etherscan.io/apis)
   - Set `ETHERSCAN_API_KEY` in `.env`

### Network Information

| Network | RPC URL | Explorer | Chain ID | USDC Address |
|---------|---------|----------|----------|--------------|
| Base Sepolia | https://sepolia.base.org | https://sepolia.basescan.org | 84532 | 0x036CbD53842c5426634e7929541eC2318f3dCF7e |
| Base Mainnet | https://mainnet.base.org | https://basescan.org | 8453 | 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 |

## 📝 Post-Deployment

After successful deployment:

1. **Save Contract Addresses** - Keep the deployment JSON file safe
2. **Verify on Explorer** - Check contracts on BaseScan
3. **Test Functionality** - Run the test script to verify everything works
4. **Monitor Gas Usage** - Check transaction costs and optimize if needed

## 🚨 Security Notes

- **Never commit private keys** to version control
- **Use testnet first** before mainnet deployment
- **Verify all contracts** on the explorer
- **Test thoroughly** before production use

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Verify your environment variables
3. Ensure you have sufficient ETH for gas
4. Check network connectivity
5. Open an issue on GitHub
