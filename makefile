# Makefile for Mission Contract System
.PHONY: build deploy test clean verify

# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif


build:
	forge build

deploy-monad:
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "Error: PRIVATE_KEY environment variable not set"; exit 1; fi
	forge create --rpc-url https://rpc.ankr.com/monad_testnet --private-key $(PRIVATE_KEY) --broadcast src/MissionContract.sol:MissionContract

deploy-base:
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "Error: PRIVATE_KEY environment variable not set"; exit 1; fi
	forge create --rpc-url https://base-sepolia.drpc.org --private-key $(PRIVATE_KEY) --broadcast src/MissionContract.sol:MissionContract

deploy-linea:
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "Error: PRIVATE_KEY environment variable not set"; exit 1; fi
	forge create --rpc-url https://rpc.sepolia.linea.build --private-key $(PRIVATE_KEY) --broadcast src/MissionContract.sol:MissionContract


test:
	forge test

# Run tests with verbose output
test-verbose:
	forge test -vv

# Run integration tests
test-integration:
	@echo "Running integration tests..."
	@chmod +x scripts/test-system.sh
	@./scripts/test-system.sh integration

# Run all tests with gas reporting
test-gas:
	@echo "Running tests with gas reporting..."
	@chmod +x scripts/test-system.sh
	@./scripts/test-system.sh gas

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	@chmod +x scripts/test-system.sh
	@./scripts/test-system.sh coverage

# Run comprehensive test suite
test-all:
	@echo "Running comprehensive test suite..."
	@chmod +x scripts/test-system.sh
	@./scripts/test-system.sh all

# Clean build artifacts
clean:
	forge clean

# Deploy to Base Sepolia testnet
deploy-sepolia:
	@echo "Deploying Mission Contract System to Base Sepolia..."
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh sepolia

# Deploy to Base mainnet
deploy-mainnet:
	@echo "Deploying Mission Contract System to Base Mainnet..."
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh mainnet

# Deploy to Monad testnet
deploy-monad-testnet:
	@echo "Deploying Mission Contract System to Monad Testnet..."
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh monad-testnet

# Verify contracts on Base Sepolia
verify-sepolia:
	@echo "Verifying contracts on Base Sepolia..."
	@chmod +x scripts/verify.sh
	@./scripts/verify.sh sepolia

# Verify contracts on Base mainnet
verify-mainnet:
	@echo "Verifying contracts on Base Mainnet..."
	@chmod +x scripts/verify.sh
	@./scripts/verify.sh mainnet

# Verify contracts on Monad testnet
verify-monad-testnet:
	@echo "Verifying contracts on Monad Testnet..."
	@chmod +x scripts/verify.sh
	@./scripts/verify.sh monad-testnet

# Test deployed contracts on Base Sepolia
test-deployed-sepolia:
	@echo "Testing deployed contracts on Base Sepolia..."
	@chmod +x scripts/test-deployed.sh
	@./scripts/test-deployed.sh sepolia

# Test deployed contracts on Base mainnet
test-deployed-mainnet:
	@echo "Testing deployed contracts on Base Mainnet..."
	@chmod +x scripts/test-deployed.sh
	@./scripts/test-deployed.sh mainnet

# Test deployed contracts on Monad testnet
test-deployed-monad-testnet:
	@echo "Testing deployed contracts on Monad Testnet..."
	@chmod +x scripts/test-deployed.sh
	@./scripts/test-deployed.sh monad-testnet

# Full deployment and testing pipeline for Base Sepolia
deploy-and-test-sepolia: build deploy-sepolia verify-sepolia test-deployed-sepolia

# Full deployment and testing pipeline for Base mainnet
deploy-and-test-mainnet: build deploy-mainnet verify-mainnet test-deployed-mainnet

# Full deployment and testing pipeline for Monad testnet
deploy-and-test-monad-testnet: build deploy-monad-testnet verify-monad-testnet test-deployed-monad-testnet

# Help
help:
	@echo "Available commands:"
	@echo "  build                    - Build contracts"
    @echo "  test                     - Run tests"
    @echo "  test-verbose             - Run tests with verbose output"
    @echo "  test-integration         - Run integration tests"
    @echo "  test-gas                 - Run tests with gas reporting"
    @echo "  test-coverage            - Run tests with coverage"
    @echo "  test-all                 - Run comprehensive test suite"
	@echo "  clean                    - Clean build artifacts"
	@echo "  deploy-sepolia           - Deploy to Base Sepolia testnet"
	@echo "  deploy-mainnet           - Deploy to Base Mainnet"
	@echo "  deploy-monad-testnet     - Deploy to Monad Testnet"
	@echo "  verify-sepolia           - Verify contracts on Base Sepolia"
	@echo "  verify-mainnet           - Verify contracts on Base Mainnet"
	@echo "  verify-monad-testnet     - Verify contracts on Monad Testnet"
	@echo "  test-deployed-sepolia    - Test deployed contracts on Base Sepolia"
	@echo "  test-deployed-mainnet    - Test deployed contracts on Base Mainnet"
	@echo "  test-deployed-monad-testnet - Test deployed contracts on Monad Testnet"
	@echo "  deploy-and-test-sepolia  - Full pipeline for Base Sepolia"
	@echo "  deploy-and-test-mainnet  - Full pipeline for Base Mainnet"
	@echo "  deploy-and-test-monad-testnet - Full pipeline for Monad Testnet"