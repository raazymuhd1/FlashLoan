pragma solidity ^0.8.0;

import { DeployFlashLoan } from "../script/DeployFlashLoan.s.sol";
import { Test, console } from "forge-std/Test.sol";
import { FlashLoan } from "../src/FlashLoan.sol";
import { ERC20Mock } from "../src/mocks/MockERC.sol";
import { IERC20 } from "../src/mocks/ERC20Test.sol";
// import { IERC20 } from "@aave-coreV3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";

contract FlashLoanTest is Test {
    DeployFlashLoan deployer;
    FlashLoan flashloan;
    ERC20Mock mockERC20;

    address WETH_SEPOL = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address USDT_SEPOL = 0xAF0F6e8b0Dc5c913bbF4d14c22B4E78Dd14310B6; // usdt sepolia aave
    // address USDT_SEPOL = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0; // usdt sepolia
    address public USER = makeAddr("USER");
    address public BLACKLISTED_USER = makeAddr("Blacklisted");
    address public ANOTHER_USER = makeAddr("ANOTHER_USER");
    uint256 public PRECISION = 1e18;
    uint256 public TEST_BUY_AMT = 500 * PRECISION;

    function setUp() public {
        deployer = new DeployFlashLoan();
        (flashloan, mockERC20) = deployer.run(USER, payable(USER));

        vm.deal(USER, 10 ether);
    }

    function test_puchasingPackage() public {
        uint256 amount_ = 10;
        uint32 pckgType = 500;

        vm.startPrank(USER);
        mockERC20.mintToken();
        uint256 userBalance = mockERC20.balanceOf(USER);
        console.log("USDT Balance of this user:");
        console.log(userBalance);

        FlashLoan.User memory userBfore = flashloan.getUserDetails(USER);
        console.log(userBfore.userAddress);

        if(userBalance > 0) {
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT);
            console.log(userAfter.userAddress);
        }
        vm.stopPrank();

        assert(userBalance > 0);
    }

   function test_blacklist() public {
       vm.startPrank(USER);
       bool bforeBlacklisted = flashloan.checkBlacklistedAccount(BLACKLISTED_USER);
       bool isBlacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);
       bool afterBlacklisted = flashloan.checkBlacklistedAccount(BLACKLISTED_USER);

       console.log(bforeBlacklisted);
       console.log(afterBlacklisted);
       vm.stopPrank();
       
       assert(afterBlacklisted == true);
   }

   function test_restrictAccount() public {
        bool tradeAllowed = false;
        bool withdrawAllowed = false;

        vm.startPrank(USER);
        bool restricted = flashloan.restrictAccountActions(ANOTHER_USER, tradeAllowed, withdrawAllowed);
        console.log(restricted);
        vm.stopPrank();
   }

   function test_tradeOnUniswap() public {
      uint256 testAmt = 10 * 1e6;
      vm.startPrank(USER);
    //   IERC20(USDT_SEPOL).approve(address(flashloan), testAmt);
    //  if(testAmt != type(uint256).max) {
    //     uint256 tradedAmount = flashloan.uniswapV3(USDT_SEPOL, WETH_SEPOL, testAmt);
    //     console.log(tradedAmount);
    //  }
     vm.stopPrank();
   }

   function test_borrowAsset() public {
      uint256 testAmt = 10 * 1e6;
      vm.startPrank(USER);
      flashloan.requestLoan(USDT_SEPOL, testAmt);
      console.log("borrowed");
      vm.stopPrank();
   }

}
 