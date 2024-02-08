// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanSimpleReceiverBase} from "@aave-coreV3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave-coreV3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave-coreV3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase {
    error FlashLoan_ZeroAddress();

    address payable private owner;

    constructor(
        address poolProviderAddress_
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(poolProviderAddress_)) {
        owner = payable(msg.sender);
    }

    function executeOperation(
        address asset, // asset we want to borrow
        uint256 amount, // asset amount
        uint256 premium, // protocol fee
        address initiator, // initiator will be this contract
        bytes calldata params // optional param
    ) external override returns (bool) {

        // perform an arbitrage here..

         uint256 amountOwed = amount + premium; // repay amount amount we borrow + fee ( premium )
         IERC20(asset).approve(address(POOL), amountOwed); // give a permission to an aave lending pool to take back the loaned fund 
         return true;
    }


    function requestLoan(address asset_, uint256 amount_) external {
        address receiverAddress = address(this); // receiver will be this contract
        address asset = asset_; // we can borrow more than one assets
        uint256 amount = amount_;
        bytes memory params = ""; // any bytes data to pass
        uint16 refCode = 0;

        //  flashloan simple function can only borrow one asset
        // while flashloan function can borrow more than one asset
         POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            refCode
         );
    }


    function getBalance(address tokenAddr) public returns(uint256 balance) {
        balance = IERC20(tokenAddr).balanceOf(address(this));
    }

    function withdraw(address tokenAddr) external OnlyOwner returns(bool) {
        IERC20 token = IERC20(tokenAddr);
        if(msg.sender == address(0) || owner == address(0)) {
            revert FlashLoan_ZeroAddress();
        }

        token.transfer(msg.sender, address(this).balance);
    } 

    modifier OnlyOwner() {
        require(owner == msg.sender , "Only Owner can call");
        _;
    }


    receive() external payable {} // in case we want this contract tobe able to receive ether
}
