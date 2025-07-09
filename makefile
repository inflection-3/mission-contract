# Makefile
.PHONY: build deploy test

build:
	forge build

deploy:
	forge create --rpc-url https://84532.rpc.thirdweb.com --private-key $(PRIVATE_KEY) src/MissionContract.sol:MissionContract

test:
	forge test