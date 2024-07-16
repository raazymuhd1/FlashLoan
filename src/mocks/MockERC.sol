// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Test} from "./ERC20Test.sol";

contract ERC20Mock is ERC20Test {

    uint256 public constant TEST_AMOUNT = 1000_000 * 1e18;

    constructor() ERC20Test("USDTMock", "MockUSDT") {}

    function mintToken() external {
        _mint(msg.sender, TEST_AMOUNT);
    }
}