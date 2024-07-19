// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockWETH {

    constructor() {}

    mapping(address => uint256) private balances;

    function deposit(uint256 amount) external payable {
        (bool success, ) =  payable(msg.sender).call{value: msg.value}("");
        mint(msg.sender, amount);
    }

    function transfer(address from, address to, uint256 value) external returns(bool) {
        balances[from] -= value;
        balances[to] += value;
        return true;
    }

    function withdraw(uint256 amount) external payable {
        (bool success, ) = payable(msg.sender).call{value: amount}("");
    }

    function mint(address to, uint256 amount) internal returns(uint) {
        balances[to] += amount;
        return amount;
    }

    receive() external payable {}
}