pragma solidity ^0.8.0;

import { DeployFlashLoan } from "../script/DeployFlashLoan.s.sol";
import { Test, console } from "forge-std/Test.sol";
import { FlashLoan } from "../src/FlashLoan.sol";
import { ERC20Mock } from "../src/mocks/MockERC.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { IERC20 } from "../src/mocks/ERC20Test.sol";
// import { IERC20 } from "@aave-coreV3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";

contract FlashLoanTest is Test {
    DeployFlashLoan deployer;
    FlashLoan flashloan;
    IERC20 UsdtToken;
    HelperConfig helper;

    // address public USER = makeAddr("USER");
    address public BLACKLISTED_USER = makeAddr("Blacklisted");
    address public ANOTHER_USER = makeAddr("ANOTHER_USER");
    address public ZERO_ADDRESS = address(0);
    uint256 public PRECISION = 1e6;
    uint256 public TEST_BUY_AMT = 1000;
    address USDT; 
    address WETH;
    address POOL_ADDRESSES;
    address USER;

    function setUp() public {
         helper = new HelperConfig();
        ( USDT, WETH, POOL_ADDRESSES, USER ) = helper.networkConfig();
         UsdtToken = IERC20(USDT);

        deployer = new DeployFlashLoan();
        flashloan = deployer.run(payable(USER), USDT, POOL_ADDRESSES);

        vm.deal(USER, 10 ether);
        vm.prank(USER);
        // // deposit some initial funds into flashloan contract
        UsdtToken.transfer(address(flashloan), 2000 * PRECISION);
    }

    modifier Blacklisted() {
        vm.prank(USER);
        bool isBlacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);
        console.log(isBlacklisted);
        _;
    }

    modifier PurchasingPackage(address caller) {
        uint32 pckgType = 1000;

        vm.prank(USER);
        UsdtToken.transfer(caller, 3000 * PRECISION);

        vm.startPrank(caller);
        // UsdtToken.mintToken();
        UsdtToken.approve(address(flashloan), TEST_BUY_AMT * PRECISION);
        FlashLoan.User memory user = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION);
        vm.stopPrank();
        _;
    }

    function test_purchasingPackageNonBlacklistedAccount() public {
        uint256 amount_ = 10;
        uint32 pckgType = 1000;

        vm.startPrank(USER);
        UsdtToken.mintToken();
        uint256 userBalance = UsdtToken.balanceOf(USER);
        console.log("USDT Balance of this user:");
        console.log(userBalance);

        FlashLoan.User memory userBfore = flashloan.getUserDetails(USER);
        console.log("user before registered");
        console.log(userBfore.userAddress);

        if(userBalance > 0) {
            UsdtToken.approve(address(flashloan), TEST_BUY_AMT * PRECISION);
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION);
            console.log("user after registered");
            console.log(userAfter.userAddress);
            uint contractBalance = UsdtToken.balanceOf(address(flashloan));
            console.log("contract balance:");
            console.log(contractBalance);
        }
        vm.stopPrank();

        assert(userBalance > 0);
    }

     function test_purchasingPackageZeroAddress() public {
        uint256 amount_ = 10;
        uint32 pckgType = 5000;

        vm.startPrank(ZERO_ADDRESS);
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT);
            console.log(userAfter.userAddress);
            uint contractBalance = UsdtToken.balanceOf(address(flashloan));
            console.log("contract balance:");
            console.log(contractBalance);
        vm.stopPrank();
    }

    function test_purchasingPackageByBlacklistedAccount() public Blacklisted {
        uint256 amount_ = 10;
        uint32 pckgType = 1000;
        vm.prank(USER);
        bool isBlacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);

        vm.startPrank(BLACKLISTED_USER);
        UsdtToken.mintToken();
        uint256 userBalance = UsdtToken.balanceOf(BLACKLISTED_USER);
        console.log("USDT Balance of this user:");
        console.log(userBalance);

        FlashLoan.User memory userBfore = flashloan.getUserDetails(BLACKLISTED_USER);
        console.log(userBfore.userAddress);

        if(userBalance > 0) {
            UsdtToken.approve(address(flashloan), TEST_BUY_AMT);
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
       assert(bforeBlacklisted == false);
       assert(afterBlacklisted == true);
   }

    function test_blacklistBlacklistedAccount() public {
       vm.startPrank(USER);
       bool bforeBlacklisted = flashloan.checkBlacklistedAccount(BLACKLISTED_USER);
       bool isBlacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);
       bool afterBlacklisted = flashloan.checkBlacklistedAccount(BLACKLISTED_USER);

       console.log(bforeBlacklisted);
       console.log(afterBlacklisted);

       bool blacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);        
       vm.stopPrank();
       
   }

   function test_restrictAccount() public PurchasingPackage(ANOTHER_USER) {
        bool tradeAllowed = false;
        bool withdrawAllowed = false;

        vm.startPrank(USER);
        FlashLoan.User memory userBforeRestricted = flashloan.getUserDetails(ANOTHER_USER);
        console.log("before restricted");
        console.log(userBforeRestricted.isTradeAllowed);
        bool restricted = flashloan.restrictAccountActions(ANOTHER_USER, tradeAllowed, withdrawAllowed);
        console.log(restricted);
        FlashLoan.User memory userAfterRestricted = flashloan.getUserDetails(ANOTHER_USER);
        console.log("after restricted");
        console.log(userAfterRestricted.isTradeAllowed);
        vm.stopPrank();

        assert(restricted == true);
   }

   function test_restrictNotRegisteredAccount() public {
        bool tradeAllowed = false;
        bool withdrawAllowed = false;

        vm.startPrank(USER);
        FlashLoan.User memory userBforeRestricted = flashloan.getUserDetails(ANOTHER_USER);
        console.log("before restricted");
        console.log(userBforeRestricted.isTradeAllowed);
        bool restricted = flashloan.restrictAccountActions(ANOTHER_USER, tradeAllowed, withdrawAllowed);
        console.log(restricted);
        FlashLoan.User memory userAfterRestricted = flashloan.getUserDetails(ANOTHER_USER);
        console.log("after restricted");
        console.log(userAfterRestricted.isTradeAllowed);
        vm.stopPrank();

        assert(restricted == true);
   }

    function test_restrictRestrictedAccount() public PurchasingPackage(ANOTHER_USER) {
        bool tradeAllowed = false;
        bool withdrawAllowed = false;

        vm.startPrank(USER);
        FlashLoan.User memory userBforeRestricted = flashloan.getUserDetails(ANOTHER_USER);
        console.log("before restricted");
        console.log(userBforeRestricted.isTradeAllowed);
        bool restricted = flashloan.restrictAccountActions(ANOTHER_USER, tradeAllowed, withdrawAllowed);
        console.log(restricted);
        FlashLoan.User memory userAfterRestricted = flashloan.getUserDetails(ANOTHER_USER);
        console.log("after restricted");
        console.log(userAfterRestricted.isTradeAllowed);

        flashloan.restrictAccountActions(ANOTHER_USER, tradeAllowed, withdrawAllowed);
        vm.stopPrank();

        assert(restricted == true);
   }

   function test_withdrawProfit() public PurchasingPackage(ANOTHER_USER) {
        uint256 amountToWd = 100 * PRECISION;
        vm.startPrank(ANOTHER_USER);
        bool withdrew = flashloan.withdrawProfit(amountToWd);
   }

   function test_withdrawFundsByOwner() public {
      vm.startPrank(USER);
      UsdtToken.mintToken();
      UsdtToken.transfer(address(flashloan), 1000 * PRECISION);
      bool success = flashloan.withdrawFunds(100 * PRECISION);

      console.log(success);
   }

   function test_withdrawFundsAboveAvailableAmounts() public {
      vm.startPrank(USER);
      UsdtToken.mintToken();
      UsdtToken.transfer(address(flashloan), 1000 * PRECISION);
      bool success = flashloan.withdrawFunds(2000);

      console.log(success);
   }

   function test_withdrawFundsByNonOwner() public {
      vm.startPrank(ANOTHER_USER);
      UsdtToken.mintToken();
      UsdtToken.transfer(address(flashloan), 1000 * PRECISION);
      bool success = flashloan.withdrawFunds(2000);

      console.log(success);
   }

   function test_withdrawFundsZeroAmount() public {
      vm.startPrank(USER);
      bool success = flashloan.withdrawFunds(2000);
      console.log(success);
   }

//    function test_tradeOnUniswap() public {
//         uint256 testAmt = 10;
//         vm.startPrank(USER);
//         console.log(USER);
//         IERC20(USDT).approve(address(flashloan), testAmt);
//         (uint256 tradedAmount, ) = flashloan.uniswapV3(USDT, WETH, testAmt);
//         vm.stopPrank();
//         // uint256 tradedAmount = flashloan.uniswapV3(USDT, WETH, testAmt);
//         console.log(tradedAmount);
//    }

//    function test_tradeOnSushiswap() public {
//       uint256 amountIn = 10;
//       vm.startPrank(USER);
//       IERC20(USDT).approve(address(flashloan), amountIn);
//       (uint256 tradedAmount, ) = flashloan.sushiswap(USDT, WETH, amountIn);
//       vm.stopPrank();

//         // amounts at [0] is tokenIn
//       console.log(tradedAmount);
//    }

//    function test_tradeOnQuickswap() public {
//       uint256 amountIn = 10;
//       vm.startPrank(USER);
//       IERC20(USDT).approve(address(flashloan), amountIn);
//       uint256[] memory tradedAmounts = flashloan.quickSwap(USDT, WETH, amountIn);
//       vm.stopPrank();

//         // amounts at [0] is tokenIn
//       console.log(tradedAmounts[0]);
//    }
   function test_borrowAsset() public PurchasingPackage(USER) {
      uint256 testAmt = 40 * PRECISION;
      vm.startPrank(USER);
      flashloan.requestLoan(USDT, testAmt, WETH, USER);
      FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(USER);
      FlashLoan.User memory user = flashloan.getUserDetails(USER);
    //   console.log("user trade"); 39_799_479
      console.log(userTrade.userAddress);
      console.log(user.dailyProfitAmount);
      console.log(user.dailyTradeAmount);
      console.log(user.totalTrades);
      vm.stopPrank();
   }

   function test_borrowAssetByNotRegisteredUser() public {
      uint256 testAmt = 40 * PRECISION;
      vm.startPrank(ANOTHER_USER);
      flashloan.requestLoan(USDT, testAmt, WETH, ANOTHER_USER);
      FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(ANOTHER_USER);
      FlashLoan.User memory user = flashloan.getUserDetails(ANOTHER_USER);
    //   console.log("user trade"); 39_799_479
      console.log(userTrade.userAddress);
      console.log(user.dailyProfitAmount);
      console.log(user.dailyTradeAmount);
      console.log(user.totalTrades);
      vm.stopPrank();
   }

   function test_borrowAssetByBlacklistedAccount() public PurchasingPackage(BLACKLISTED_USER) {
      uint256 testAmt = 40 * PRECISION;
      vm.prank(USER);
      bool isBlacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);
      vm.startPrank(BLACKLISTED_USER);
      flashloan.requestLoan(USDT, testAmt, WETH, BLACKLISTED_USER);
      FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(BLACKLISTED_USER);
      FlashLoan.User memory user = flashloan.getUserDetails(BLACKLISTED_USER);
    //   console.log("user trade"); 39_799_479
      console.log(userTrade.userAddress);
      console.log(user.dailyProfitAmount);
      console.log(user.dailyTradeAmount);
      console.log(user.totalTrades);
      vm.stopPrank();
   }


   function test_supplyingInitialFunds() public {
       uint256 amountToSupply = 100 * PRECISION;

       vm.startPrank(USER);
       UsdtToken.mintToken();
       UsdtToken.approve(address(flashloan), amountToSupply);
       bool funded = flashloan.supplyInitialFunds(amountToSupply);
       uint256 contractFunds = UsdtToken.balanceOf(address(flashloan));
       console.log(funded);
       console.log(contractFunds);
   }
   function test_supplyingInitialFundsBelowMinimumAmount() public {
       uint256 amountToSupply = 10 * PRECISION;

       vm.startPrank(USER);
       UsdtToken.mintToken();
       UsdtToken.approve(address(flashloan), amountToSupply);
       bool funded = flashloan.supplyInitialFunds(amountToSupply);
       uint256 contractFunds = UsdtToken.balanceOf(address(flashloan));
       console.log(funded);
       console.log(contractFunds);
   }

   function test_supplyingInitialFundsByNonOwner() public {
       uint256 amountToSupply = 100 * PRECISION;

       vm.startPrank(ANOTHER_USER);
       UsdtToken.mintToken();
       UsdtToken.approve(address(flashloan), amountToSupply);
       bool funded = flashloan.supplyInitialFunds(amountToSupply);
       uint256 contractFunds = UsdtToken.balanceOf(address(flashloan));
       console.log(funded);
       console.log(contractFunds);
   }

   function test_getUserDetails() public PurchasingPackage(ANOTHER_USER) {
        vm.prank(USER);
        FlashLoan.User memory user = flashloan.getUserDetails(ANOTHER_USER);
        console.log(user.userAddress);

        assert(user.userAddress == ANOTHER_USER);
   }


   function test_getPackagesList() public {
      vm.prank(USER);
      uint32[] memory packages = flashloan.getPackagesList();
      console.log(packages[0]);

      assert(packages[0] == 500);
   }

   function test_getTotalAmountBeingBorrowed() public {
      vm.startPrank(USER);
      uint256 borrowedAmountInTotal = flashloan.getTotalBorrowed();
      console.log(borrowedAmountInTotal);
      vm.stopPrank();
   }

   function test_getTotalTradesNumber() public {
      vm.startPrank(USER);
      uint256 tradesInTotal = flashloan.getTotalTradesCount();
      console.log(tradesInTotal);
      vm.stopPrank();
   }

   function test_getTotalFundsAvailable() public {
      uint256 amountToSupply = 100 * PRECISION;

      vm.startPrank(USER);
      UsdtToken.mintToken();
      UsdtToken.approve(address(flashloan), amountToSupply);
      bool funded = flashloan.supplyInitialFunds(amountToSupply);
      uint256 totalFundsAvail = flashloan.getTotalFunds();
      console.log(totalFundsAvail);
      vm.stopPrank();
   }

   function test_getOwner() public {
      vm.startPrank(USER);
      address owner = flashloan.getOwner();
      console.log(owner);
      vm.stopPrank();
   }

}
 