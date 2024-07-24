// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { PricingTable } from "../src/Pricing.sol";

contract DeployPricingTable is Script {
    PricingTable pricing;

    // function run() external returns(PricingTable) {

    //     vm.startBroadcast();
    //         pricing = new PricingTable();
    //         console.log(address(pricing));
    //     vm.stopBroadcast();

    //     return pricing;
    // }

}