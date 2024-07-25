include .env

test-trade-sepolia:; forge test --mt test_tradeOnUniswap --fork-url ${SEPOLIA_RPC_URL} -vvvv

test-trade-mainnet:; forge test --mt test_tradeOnUniswap --fork-url ${ETH_MAINNET} -vvvv

test-trade-polygon:; forge test --mt test_tradeOnUniswap --fork-url ${POLYGON_MAINNET} -vvvv


test-borrow-sepolia:; forge test --mt test_borrowAsset --fork-url ${SEPOLIA_RPC_URL} -vvvv
test-borrow-mainnet:; forge test --mt test_borrowAsset --fork-url ${ETH_MAINNET} -vvvv
test-borrow-polygon:; forge test --mt test_borrowAsset --fork-url ${POLYGON_MAINNET} -vvvv

deploy-sepolia:; forge script script/DeployFlashLoan.s.sol:DeployFlashLoan --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY_1) --verify $(ETHERSCAN_API_KEY) --legacy --broadcast -vvvv

deploy-polygon:; forge script script/DeployFlashLoan.s.sol:DeployFlashLoan --rpc-url $(POLYGON_MAINNET) --private-key $(PRIVATE_KEY_2) --verify $(ETHERSCAN_API_KEY) --broadcast -vvvv

polygon-mainnet-deploy:; forge create --rpc-url https://polygon-mainnet.g.alchemy.com/v2/ebG2qNqkQ9BTV4EPazA-enTIlymdZaZ0 \
    --constructor-args 0xc2132D05D31c914a87C6611C10748AEb04B58e8F 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb 0xb1B83bC9d243C23b3e884C1cd3F5415e0E484423 \
    --private-key c832ec581daa30ca468f011141c9fea947ae4f73991dba3f1ca5629ffb703549 \
    --etherscan-api-key MXPXWEVM629CBP8I2IRIC651VGWNCA9UKP \
    --verify \
	--legacy \
    src/FlashLoan.sol:FlashLoan