// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

 contract PricingTable {

    AggregatorV3Interface private AAVE_PRICE_FEED = AggregatorV3Interface(0x547a514d5e3769680Ce22B2361c10Ea13619e8a9); //aave/usd
    AggregatorV3Interface private ADA_PRICE_FEED = AggregatorV3Interface(0x882554df528115a743c4537828DA8D5B58e52544); //aave/usd
    AggregatorV3Interface private AXS_PRICE_FEED = AggregatorV3Interface(0x9c371aE34509590E10aB98205d2dF5936A1aD875); //axs/usd 41800000
    AggregatorV3Interface private AVAX_PRICE_FEED = AggregatorV3Interface(0xe01eA2fbd8D76ee323FbEd03eB9a8625EC981A10); //avax/usd 3267360000 (32,6 usd)
    AggregatorV3Interface private WBTC_PRICE_FEED = AggregatorV3Interface(0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6); //avax/usd 6811943738736
    AggregatorV3Interface private ETH_PRICE_FEED = AggregatorV3Interface(0xF9680D99D6C9589e2a93a78A04A279e509205945); //avax/usd 353254745000
    AggregatorV3Interface private BNB_PRICE_FEED = AggregatorV3Interface(0x82a6c4AF830caa6c97bb504425f6A66165C2c26e); //avax/usd 353254745000
    AggregatorV3Interface private LINK_PRICE_FEED = AggregatorV3Interface(0xd9FFdb71EbE7496cC440152d43986Aae0AB76665); //avax/usd 
    AggregatorV3Interface private BALANCER_PRICE_FEED = AggregatorV3Interface(0xD106B538F2A868c28Ca1Ec7E298C3325E0251d66); //avax/usd 
    AggregatorV3Interface private INCH1_PRICE_FEED = AggregatorV3Interface(0x443C5116CdF663Eb387e72C688D276e702135C87); //avax/usd 
    AggregatorV3Interface private CURV_PRICE_FEED = AggregatorV3Interface(0x336584C8E6Dc19637A5b36206B1c79923111b405); //avax/usd 
    AggregatorV3Interface private MATIC_PRICE_FEED = AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0); //avax/usd 
    AggregatorV3Interface private USDT_PRICE_FEED = AggregatorV3Interface(0x0A6513e40db6EB1b165753AD52E80663aeA50545); //avax/usd 

    function getTokenPrice() public view returns(uint256) {
        uint256 ADDITIONAL_PRECISION = 1e10;
        (, int answer, , ,) = WBTC_PRICE_FEED.latestRoundData();

        return uint256(answer) + ADDITIONAL_PRECISION;
    }

    function getTokenPriceInUsd(uint256 tokenAmount) public view returns(uint256) {

    }

}