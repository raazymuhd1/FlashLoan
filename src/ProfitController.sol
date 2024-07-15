// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

contract ProfitController {

    mapping(address user => Profit) private userProfit;

    event Deposited(address indexed profitOwner, uint256 indexed amount);

    struct Profit {
        uint256 totalProfit;
        address userWallet;
    }

    modifier NotZeroAddress() {
        require(msg.sender != address(0), "zero address");
        _;
    }

    function depositProfit(uint256 profit_, address owner) external NotZeroAddress returns(Profit memory) {
        Profit memory profitOfUser = Profit({ totalProfit: profit_ , userWallet: owner});
        userProfit[owner] = profitOfUser;

       emit Deposited(owner, profit_);
    }

    function distributeProfit() public returns(uint256) {

    }
}