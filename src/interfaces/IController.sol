// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IController {
    struct ProfitParams {
        address tokenAddress;
        address userAddress;
        uint256 profitAmount;
        uint256 profitUSD;
        uint256 borrowedValueinUSD;
    }
    function transferProfit(ProfitParams memory params) external returns(bool);
    function checkUserRole(address account) external view returns (bool);
    function checkADMINRole(address account) external view returns (bool);
}