include .env

test-trade-sepolia:; forge test --mt test_tradeOnUniswap --fork-url ${SEPOLIA_RPC_URL} -vvvv

test-trade-mainnet:; forge test --mt test_tradeOnUniswap --fork-url ${ETH_MAINNET} -vvvv

test-trade-polygon:; forge test --mt test_tradeOnUniswap --fork-url ${POLYGON_MAINNET} -vvvv


test-borrow-sepolia:; forge test --mt test_borrowAsset --fork-url ${SEPOLIA_RPC_URL} -vvvv
test-borrow-mainnet:; forge test --mt test_borrowAsset --fork-url ${ETH_MAINNET} -vvvv
test-borrow-polygon:; forge test --mt test_borrowAsset --fork-url ${POLYGON_MAINNET} -vvvv

deploy-sepolia:; forge script script/DeployFlashLoan.s.sol:DeployFlashLoan --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY_1) --verify $(ETHERSCAN_API_KEY) --legacy --broadcast -vvvv

deploy-polygon:; forge script script/DeployFlashLoan.s.sol:DeployFlashLoan --rpc-url $(POLYGON_MAINNET) --private-key $(PRIVATE_KEY_2) --verify $(ETHERSCAN_API_KEY) --broadcast -vvvv
