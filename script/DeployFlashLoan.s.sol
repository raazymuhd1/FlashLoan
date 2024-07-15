// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import { FlashLoan } from "../src/FlashLoan.sol";
import { Script, console } from "forge-std/Script.sol";
import { MockFlashLoanSimpleReceiver } from "@aave-coreV3/contracts/mocks/flashloan/MockSimpleFlashLoanReceiver.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";

contract DeployFlashLoan is Script {
    FlashLoan flashLoan;
    // POOL ADDRESS ON SEPOLIA
    address private constant POOL_ADDRESS = 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A;
    address paymentToken = 0xA02f6adc7926efeBBd59Fd43A84f4E0c0c91e832;
    uint256 testAmount = 100_000_000 wei;

    MockFlashLoanSimpleReceiver simpleFlashLoanMock;
    MockPoolAddressesProvider mockPoolAddressProvider;

    function run() external {

        vm.startBroadcast();
        // mockPoolAddressProvider = new MockPoolAddressesProvider();
        // simpleFlashLoanMock = new MockFlashLoanSimpleReceiver(mockPoolAddressProvider);
        flashLoan = new FlashLoan(paymentToken); 
        // flashLoan.requestLoan(paymentToken, testAmount);

        vm.stopBroadcast();
        // return flashLoan;

    // forge test --match-test test_flashExist --rpc-url $SEPOLIA_RPC_URL -vvvv

    }
}