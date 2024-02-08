include .env

test-sepolia:; forge test --match-test test_borrowFund --rpc-url $(SEPOLIA_RPC_URL) -vvvv

deploy-sepolia:; forge script script/DeployFlashLoan.s.sol:DeployFlashLoan --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --verify $(ETHERSCAN_API_KEY) --broadcast -vvvv