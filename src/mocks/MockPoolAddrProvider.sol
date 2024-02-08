// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.10;

import { PoolAddressesProvider } from "@aave-coreV3/contracts/protocol/configuration/PoolAddressesProvider.sol";

contract MockPoolAddressesProvider is PoolAddressesProvider {

    constructor() PoolAddressesProvider("0", msg.sender) {
        
    }
}