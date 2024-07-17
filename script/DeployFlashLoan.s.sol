// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import { FlashLoan } from "../src/FlashLoan.sol";
import { Script, console } from "forge-std/Script.sol";
import { MockFlashLoanSimpleReceiver } from "@aave-coreV3/contracts/mocks/flashloan/MockSimpleFlashLoanReceiver.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";
import { ERC20Mock } from "../src/mocks/MockERC.sol";

contract DeployFlashLoan is Script {
    FlashLoan flashLoan;
    // POOL ADDRESS ON POLYGON MAINNET 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
    address POOL_POLYGON = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address USDT_POL = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    // POOL ADDRESS ON SEPOLIA
    address private constant POOL_ADDRESS = 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A;
    address USDT_SEPOL = 0xAF0F6e8b0Dc5c913bbF4d14c22B4E78Dd14310B6; // usdt sepolia aave
    uint256 testAmount = 100 * 1e6;

    MockPoolAddressesProvider mockPoolAddressProvider;
    ERC20Mock erc20Mock;

    function run(address poolOwner_, address payable flashloanOwner_) external returns(FlashLoan, ERC20Mock) {

        vm.startBroadcast();
        mockPoolAddressProvider = new MockPoolAddressesProvider(poolOwner_);
        erc20Mock = new ERC20Mock();
        // flashLoan = new FlashLoan(address(erc20Mock), address(mockPoolAddressProvider), flashloanOwner_); 
        // flashLoan = new FlashLoan(USDT_POL, POOL_POLYGON); 
        flashLoan = new FlashLoan(USDT_SEPOL, POOL_ADDRESS, flashloanOwner_); 
        // flashloan.requestLoan(USDT_SEPOL, testAmount);
        vm.stopBroadcast();

        return (flashLoan, erc20Mock);
    }
}