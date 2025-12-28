-include .env

.PHONY: all test deploy

build:; forge build;
test:; forge test;	

install:
	forge install cyfrin/foundry-devops@0.4.0 
	forge install smartcontactkits/chainlink-brownie-contracts@1.3.0
	forge install transmissions11/solmate@v6


deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url=$(SEPOLIA_RPC) --account=$(DEPLOYER_CAST_ACCOUNT) --broadcast --verify --etherscan-api-key=$(ETHERSCAN_API_KEY) 