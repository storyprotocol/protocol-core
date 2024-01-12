-include .env

.PHONY: all test clean

all: clean install build

# Clean the repo
forge-clean  :; forge clean
clean  :; npx hardhat clean

# Remove modules
forge-remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; npm install

# Update Dependencies
forge-update:; forge update

forge-build:; forge build
build :; npx hardhat compile

test :; forge test

snapshot :; forge snapshot

slither :; slither ./contracts

format :; npx prettier --write contracts/**/*.sol && npx prettier --write contracts/*.sol

# solhint should be installed globally
lint :; npx solhint contracts/**/*.sol && npx solhint contracts/*.sol

deploy-goerli :; npx hardhat run ./script/deploy-reveal-engine.js --network goerli
verify-goerli :; npx hardhat verify --network goerli ${contract}

anvil :; anvil -m 'test test test test test test test test test test test junk'

