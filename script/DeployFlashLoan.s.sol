// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import { FlashLoan } from "../src/FlashLoan.sol";
import { Script, console } from "forge-std/Script.sol";
import { MockFlashLoanSimpleReceiver } from "@aave-coreV3/contracts/mocks/flashloan/MockSimpleFlashLoanReceiver.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract DeployFlashLoan is Script {
    FlashLoan flashLoan;

    address REAL_OWNER = 0xb1B83bC9d243C23b3e884C1cd3F5415e0E484423;

    function run(address USDT, address POOL_ADDR, address flashloanOwner_) external returns(FlashLoan) {

        vm.startBroadcast();
        flashLoan = new FlashLoan(USDT, POOL_ADDR, flashloanOwner_); 
        vm.stopBroadcast();

        return flashLoan;
    }

    // function run() external returns(FlashLoan) {

    //     vm.startBroadcast();
    //     flashLoan = new FlashLoan(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0, 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A, REAL_OWNER); 
    //     vm.stopBroadcast();

    //     return flashLoan;
    // }

}