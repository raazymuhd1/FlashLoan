pragma solidity ^0.8.0;

import { DeployFlashLoan } from "../script/DeployFlashLoan.s.sol";
import { Test, console } from "forge-std/Test.sol";
import { FlashLoan } from "../src/FlashLoan.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashLoanTest is Test {
    DeployFlashLoan deployer;
    FlashLoan flashloan;

    address public USDT = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address public USER = 0x34699bE6B2a22E79209b8e9f9517C5e18db7eB89;

    function setUp() public {
        deployer = new DeployFlashLoan();
        flashloan = deployer.run();

        console.log(address(flashloan));

    }

    function test_borrowFund() public {
        uint256 amount_ = 10;

        vm.startPrank(USER);
        flashloan.requestLoan(USDT, amount_);

        console.log(IERC20(USDT).balanceOf(USER));
    }

}
 