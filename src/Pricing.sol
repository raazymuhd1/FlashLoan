// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


// --------------------------------- Cool Dev ------------------------------------------
// --------------------------------- -- ------------------------------------------
// --------------------------------- --- ------------------------------------------
// --------------------------------- ---- ------------------------------------------
// --------------------------------- -- ------------------------------------------
// --------------------------------- ---- ------------------------------------------
// --------------------------------- PRICING TABLES ------------------------------------------


import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IERC20 } from "./interfaces/IERC20.sol";


abstract contract PricingTable {

    AggregatorV3Interface private WBTC_PRICE_FEED = AggregatorV3Interface(0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6);
    AggregatorV3Interface private ETH_PRICE_FEED = AggregatorV3Interface(0xF9680D99D6C9589e2a93a78A04A279e509205945); 
    AggregatorV3Interface private DAI_PRICE_FEED = AggregatorV3Interface(0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D); 
    AggregatorV3Interface private USDT_PRICE_FEED = AggregatorV3Interface(0x0A6513e40db6EB1b165753AD52E80663aeA50545); 
    AggregatorV3Interface private USDC_PRICE_FEED = AggregatorV3Interface(0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7); 

    address private USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address private USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address private WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address private DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;

    address[] tokenLists = [USDT, WETH, WBTC, DAI, USDC];

    /**
        @dev function to check for several tokens price
        @param token - token address that needs to check the price for
     */
    function checkTokenPrice(address token) internal returns(uint256 tokenPrice) {
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

    /**
        @dev calculate each token amount to token price in USD
        @param tokenAddress - An address of token u want to check for
        @param tokenAmount - a token amount 
     */
    function getTokenPriceInUsd(address tokenAddress, uint256 tokenAmount) internal returns(uint256 priceInUsd) {
        uint256 tokenDecimals = IERC20(tokenAddress).decimals();
        uint256 PRECISION18 = 1e18;
        uint256 PRECISION6 = 1e6;
        uint256 PRECISION8 = 1e8;

        if(tokenAddress == address(0)) revert("InvalidToken: No price for invalid token address");

        if(tokenDecimals == 6) {
             priceInUsd = (checkTokenPrice(tokenAddress) * tokenAmount) / PRECISION6 ;
        } else if(tokenDecimals == 8) {
             priceInUsd = ((checkTokenPrice(tokenAddress) * tokenAmount) / PRECISION8) / 1e2 ;
        } else if(tokenDecimals == 18) {
             priceInUsd = ((checkTokenPrice(tokenAddress) * tokenAmount) / PRECISION18) / 1e12 ;
        }
    }

    /**
        @dev checking token price for tokens that has 18 decimals
        @param priceFeed - a chainlink price oracle contract 
     */
    function _checkingTokenReturnsPrice18Decimals(AggregatorV3Interface priceFeed) internal view returns(uint256 price) {
        uint256 ADDITIONAL_PRECISION = 1e10;
        (, int answer, , ,) = priceFeed.latestRoundData();
        price = uint256(answer) * ADDITIONAL_PRECISION;
    }

    /**
        @dev checking token price for tokens that has 6 decimals
        @param priceFeed - a chainlink price oracle contract 
     */
    function _checkingTokenReturnsPrice6Decimals(AggregatorV3Interface priceFeed) internal view returns(uint256 price) {
        uint256 DIVIDED_PRECISION = 1e2;
        (, int answer, , ,) = priceFeed.latestRoundData();
        price = uint256(answer) / DIVIDED_PRECISION;
    }

}