pragma solidity ^0.8.0;

import { DeployPricingTable } from "../script/DeployPricing.s.sol";
import { PricingTable } from "../src/Pricing.sol";
import { Test, console } from "forge-std/Test.sol";


contract PricingTest is Test {
    DeployPricingTable deployer;
    PricingTable pricing;

    address USER = makeAddr("USER");

    function setUp() public {
        deployer = new DeployPricingTable();
        pricing = deployer.run();

        vm.deal(USER, 10 ether);
    }


    function test_getPrice() public {
         vm.startPrank(USER);
         uint256 price = pricing.getTokenPrice();
         console.log(price);

         vm.stopPrank();
    }
}