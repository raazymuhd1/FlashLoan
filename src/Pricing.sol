// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

 contract PricingTable {

    AggregatorV3Interface private WBTC_PRICE_FEED = AggregatorV3Interface(0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6); //avax/usd 6811943738736
    AggregatorV3Interface private ETH_PRICE_FEED = AggregatorV3Interface(0xF9680D99D6C9589e2a93a78A04A279e509205945); //avax/usd 353254745000
    AggregatorV3Interface private BALANCER_PRICE_FEED = AggregatorV3Interface(0xD106B538F2A868c28Ca1Ec7E298C3325E0251d66); //avax/usd 
    AggregatorV3Interface private CURV_PRICE_FEED = AggregatorV3Interface(0x336584C8E6Dc19637A5b36206B1c79923111b405); //avax/usd 
    AggregatorV3Interface private DAI_PRICE_FEED = AggregatorV3Interface(0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D); //avax/usd 
    AggregatorV3Interface private USDT_PRICE_FEED = AggregatorV3Interface(0x0A6513e40db6EB1b165753AD52E80663aeA50545); 
    AggregatorV3Interface private USDC_PRICE_FEED = AggregatorV3Interface(0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7); 

    address private USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address private USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address private WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address private SNX = 0x50B728D8D964fd00C2d0AAD81718b71311feF68a;
    address private FRAX = 0x104592a158490a9228070E0A8e5343B499e125D0;
    address private DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address private CURV = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;  // NOT SUPPORTED

    address[] tokenLists = [USDT, WETH, WBTC, DAI, USDC];

    function checkTokenPrice(address token) public returns(uint256 tokenPrice) {
        uint256 tokenDecimals = IERC20(token).decimals();

        if(tokenDecimals == 6) {
            if(token == tokenLists[0]) {
              tokenPrice = _checkingTokenReturnsPrice6Decimals(USDT_PRICE_FEED);
            } else if(token == tokenLists[4]) {
              tokenPrice = _checkingTokenReturnsPrice6Decimals(USDC_PRICE_FEED);
            }

        } else if(tokenDecimals == 18) {
            if(token == tokenLists[1]) {
               tokenPrice = _checkingTokenReturnsPrice18Decimals(ETH_PRICE_FEED);
            } else if(token == tokenLists[3]) {
               tokenPrice = _checkingTokenReturnsPrice18Decimals(DAI_PRICE_FEED);
            } 

        } else if(tokenDecimals == 8 && token == tokenLists[2]) {
            (, int answer, , ,) = WBTC_PRICE_FEED.latestRoundData();
            tokenPrice = uint256(answer);
        }
    }

    function getTokenPriceInUsd(address tokenAddress, uint256 tokenAmount) external returns(uint256 priceInUsd) {
        uint256 tokenDecimals = IERC20(tokenAddress).decimals();
        uint256 PRECISION18 = 1e18;
        uint256 PRECISION6 = 1e6;
        uint256 PRECISION8 = 1e8;

        if(tokenDecimals == 6) {
             priceInUsd = (checkTokenPrice(tokenAddress) * tokenAmount) / PRECISION6 ;
        } else if(tokenDecimals == 8) {
             priceInUsd = (checkTokenPrice(tokenAddress) * tokenAmount) / PRECISION8 ;
        } else if(tokenDecimals == 18) {
             priceInUsd = (checkTokenPrice(tokenAddress) * tokenAmount) / PRECISION18 ;
        }
    }

    function _checkingTokenReturnsPrice18Decimals(AggregatorV3Interface priceFeed) internal view returns(uint256 price) {
        uint256 ADDITIONAL_PRECISION = 1e10;
        (, int answer, , ,) = priceFeed.latestRoundData();
        price = uint256(answer) * ADDITIONAL_PRECISION;
    }

    function _checkingTokenReturnsPrice6Decimals(AggregatorV3Interface priceFeed) internal view returns(uint256 price) {
        uint256 ADDITIONAL_PRECISION = 1e2;
        (, int answer, , ,) = priceFeed.latestRoundData();
        price = uint256(answer) + ADDITIONAL_PRECISION;
    }

}