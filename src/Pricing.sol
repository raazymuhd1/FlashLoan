// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

 contract PricingTable {

    AggregatorV3Interface private AAVE_PRICE_FEED = AggregatorV3Interface(0x547a514d5e3769680Ce22B2361c10Ea13619e8a9); //aave/usd
    AggregatorV3Interface private ADA_PRICE_FEED = AggregatorV3Interface(0x882554df528115a743c4537828DA8D5B58e52544); //aave/usd
    AggregatorV3Interface private AXS_PRICE_FEED = AggregatorV3Interface(0x9c371aE34509590E10aB98205d2dF5936A1aD875); //axs/usd 41800000
    AggregatorV3Interface private AVAX_PRICE_FEED = AggregatorV3Interface(0xe01eA2fbd8D76ee323FbEd03eB9a8625EC981A10); //avax/usd 3267360000 (32,6 usd)
    AggregatorV3Interface private BTC_PRICE_FEED = AggregatorV3Interface(0xc907E116054Ad103354f2D350FD2514433D57F6f); //avax/usd 6811943738736
    AggregatorV3Interface private ETH_PRICE_FEED = AggregatorV3Interface(0xF9680D99D6C9589e2a93a78A04A279e509205945); //avax/usd 353254745000
    AggregatorV3Interface private LINK_PRICE_FEED = AggregatorV3Interface(0xd9FFdb71EbE7496cC440152d43986Aae0AB76665); //avax/usd 

    function getTokenPrice() public view returns(int) {
        (, int answer, , ,) = BTC_PRICE_FEED.latestRoundData();
        return answer;
    }

}