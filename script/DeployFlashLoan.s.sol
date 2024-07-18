// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import { FlashLoan } from "../src/FlashLoan.sol";
import { Script, console } from "forge-std/Script.sol";
import { MockFlashLoanSimpleReceiver } from "@aave-coreV3/contracts/mocks/flashloan/MockSimpleFlashLoanReceiver.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";
import { ERC20Mock } from "../src/mocks/MockERC.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract DeployFlashLoan is Script {
    FlashLoan flashLoan;
    
    MockPoolAddressesProvider mockPoolAddressProvider;
    ERC20Mock erc20Mock;

    function run(address poolOwner_, address payable flashloanOwner_, address USDT, address POOL_ADDRESSES) external returns(FlashLoan, ERC20Mock) {

        vm.startBroadcast();
        mockPoolAddressProvider = new MockPoolAddressesProvider(poolOwner_);
        erc20Mock = new ERC20Mock();
        // flashLoan = new FlashLoan(address(erc20Mock), address(mockPoolAddressProvider), flashloanOwner_); 
        flashLoan = new FlashLoan(USDT, POOL_ADDRESSES, flashloanOwner_); 
        vm.stopBroadcast();

        return (flashLoan, erc20Mock);
    }
}