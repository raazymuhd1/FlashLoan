pragma solidity ^0.8.0;

import { DeployPricingTable } from "../script/DeployPricing.s.sol";
import { PricingTable } from "../src/Pricing.sol";
import { Test, console } from "forge-std/Test.sol";


contract PricingTest is Test {
    DeployPricingTable deployer;
    PricingTable pricing;

    address USER = makeAddr("USER");
    address private USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address private USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address private WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address private SNX = 0x50B728D8D964fd00C2d0AAD81718b71311feF68a;
    address private FRAX = 0x104592a158490a9228070E0A8e5343B499e125D0;
    address private DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address private CURV = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;

    function setUp() public {
        deployer = new DeployPricingTable();
        pricing = deployer.run();

        vm.deal(USER, 10 ether);
    }


    function test_getPrice() public {
         vm.startPrank(USER);
         uint256 price = pricing.getTokenPriceInUsd(DAI, 1000 * 1e8);
         console.log(price);
         vm.stopPrank();
    }
}