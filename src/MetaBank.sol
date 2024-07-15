// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MetaBank is ERC20 {

    uint256 private decimals_ = 1e18;
    uint256 private constant INITIAL_AMOUNT = 1000_000;

    mapping(uint256 => RewardByLevel) private rewardByLevel;

    struct RewardByLevel {
        uint256 level;
        uint256 rewardsPercentage;
    }

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, INITIAL_AMOUNT * decimals_);
    }

    function transferWithFee() external returns(bool) {

    }

    function refferalSystem() external {
        
    }

}