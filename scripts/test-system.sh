#!/bin/bash

# Comprehensive Test Script for Mission Contract System
# Usage: ./scripts/test-system.sh [test-name]

set -e

TEST_NAME=${1:-"all"}

echo "🧪 Running Mission Contract System Tests..."
echo ""

case $TEST_NAME in
    all)
        echo "📋 Running all tests..."
        forge test -vv
        ;;
    unit)
        echo "📋 Running unit tests..."
        forge test --match-path "test/*.t.sol" -vv
        ;;
    integration)
        echo "📋 Running integration tests..."
        forge test --match-path "test/MissionSystemIntegration.t.sol" -vv
        ;;
    mission)
        echo "📋 Running Mission contract tests..."
        forge test --match-path "test/Mission.t.sol" -vv
        ;;
    factory)
        echo "📋 Running MissionFactory tests..."
        forge test --match-path "test/MissionFactory.t.sol" -vv
        ;;
    manager)
        echo "📋 Running MissionManager tests..."
        forge test --match-path "test/MissionManager.t.sol" -vv
        ;;
    gas)
        echo "📋 Running tests with gas reporting..."
        forge test --gas-report
        ;;
    coverage)
        echo "📋 Running tests with coverage..."
        forge coverage --report lcov
        ;;
    *)
        echo "Usage: $0 [all|unit|integration|mission|factory|manager|gas|coverage]"
        echo ""
        echo "Options:"
        echo "  all          - Run all tests (default)"
        echo "  unit         - Run unit tests only"
        echo "  integration  - Run integration tests only"
        echo "  mission      - Run Mission contract tests"
        echo "  factory      - Run MissionFactory tests"
        echo "  manager      - Run MissionManager tests"
        echo "  gas          - Run tests with gas reporting"
        echo "  coverage     - Run tests with coverage report"
        exit 1
        ;;
esac

echo ""
echo "✅ Tests completed!"

