pragma solidity ^0.8.0;

import { DeployFlashLoan } from "../script/DeployFlashLoan.s.sol";
import { Test, console } from "forge-std/Test.sol";
import { FlashLoan } from "../src/FlashLoan.sol";
import { ERC20Mock } from "../src/mocks/MockERC.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";
import { DeployPricingTable } from "../script/DeployPricing.s.sol";
import { PricingTable } from "../src/Pricing.sol";

contract FlashLoanTest is Test {
    DeployPricingTable pricingDeployer;
    PricingTable pricing;
    DeployFlashLoan deployer;
    FlashLoan flashloan;
    IERC20 UsdtToken;
    HelperConfig helper;

    // address public USER = makeAddr("USER");
    address public BLACKLISTED_USER = makeAddr("Blacklisted");
    address public ANOTHER_USER = 0x781229c7a798c33EC788520a6bBe12a79eD657FC;
    address public WHALE1 = 0x4D8336bDa6C11BD2a805C291Ec719BaeDD10AcB9;
    address public WHALE2 = 0x87673F8587De5f1ec8fDBCaBC9C2b742bcd61DC6;
    // address public ANOTHER_USER = makeAddr("ANOTHER_USER");
    address public ZERO_ADDRESS = address(0);
    uint256 public PRECISION = 1e6;
    uint256 public TEST_BUY_AMT = 10000;
    uint256 private constant PROFIT_WD_FEE = 2;
    address WETH;
    address POOL_ADDRESSES;
    address USER;

    address USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; 
    address USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39; 
    address AAVE = 0xD6DF932A45C0f255f85145f286eA0b292B21C90B;

    function setUp() public {
         helper = new HelperConfig();
        ( USDT, WETH, POOL_ADDRESSES, USER ) = helper.networkConfig();
         UsdtToken = IERC20(USDT);

        // pricingDeployer = new DeployPricingTable();
        // pricing = pricingDeployer.run();

        deployer = new DeployFlashLoan();
        flashloan = deployer.run(payable(USER), USDT, POOL_ADDRESSES);

        vm.deal(USER, 10 ether);
        vm.deal(ANOTHER_USER, 10 ether);
    }

    modifier Blacklisted() {
        vm.prank(USER);
        bool isBlacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);
        console.log(isBlacklisted);
        _;
    }

    modifier PurchasingPackage(address caller) {
        uint32 pckgType = 500;

      //   vm.prank(USER);
      //   UsdtToken.transfer(caller, 3000 * PRECISION);

        vm.startPrank(caller);
        // UsdtToken.mintToken();
        IERC20(USDT).approve(address(flashloan), TEST_BUY_AMT * PRECISION);
        FlashLoan.User memory user = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION);
        vm.stopPrank();
        _;
    }

    function test_purchasingPackageByNonBlacklistedAccount() public {
        uint256 amount_ = 10;
        uint32 pckgType = 10000;

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

     function test_purchasingPackageByRegisteredUser() public {
        uint256 amount_ = 10;
        uint32 pckgType = 5000;

        vm.startPrank(USER);
        UsdtToken.mintToken();
        uint256 userBalance = UsdtToken.balanceOf(USER);
        console.log("USDT Balance of this user:");
        console.log(userBalance);

        FlashLoan.User memory userBfore = flashloan.getUserDetails(USER);
        console.log("user before registered");
        console.log(userBfore.userAddress);

            UsdtToken.approve(address(flashloan), TEST_BUY_AMT * PRECISION);
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION);
            console.log("user after registered");
            console.log(userAfter.userAddress);
            uint contractBalance = UsdtToken.balanceOf(address(flashloan));
            console.log("contract balance:");
            console.log(contractBalance);

            FlashLoan.User memory repurchasing = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION);
        vm.stopPrank();

        assert(userBalance > 0);
    }

     function test_purchasingPackageZeroAddress() public {
        uint256 amount_ = 10;
        uint32 pckgType = 5000;

        vm.startPrank(ZERO_ADDRESS);
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION);
            console.log(userAfter.userAddress);
            uint contractBalance = UsdtToken.balanceOf(address(flashloan));
            console.log("contract balance:");
            console.log(contractBalance);
        vm.stopPrank();
    }

     function test_purchasingPackageWithZeroBalance() public {
        uint256 amount_ = 10;
        uint32 pckgType = 5000;

        vm.startPrank(USER);
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION);
            console.log(userAfter.userAddress);
            uint contractBalance = UsdtToken.balanceOf(address(flashloan));
            console.log("contract balance:");
            console.log(contractBalance);
        vm.stopPrank();
    }

    function test_purchasingPackageByBlacklistedAccount() public Blacklisted {
        uint256 amount_ = 10;
        uint32 pckgType = 1000;

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

    function test_blacklistByNonOwner() public {
       vm.startPrank(ANOTHER_USER);
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

   function test_restrictNonRegisteredAccount() public {
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
        bool withdrew = flashloan.withdrawProfit(amountToWd, 3 * PRECISION);
   }

   function test_withdrawFundsByOwner() public {
     uint256 amountToSupply = 0.1 ether;
      vm.startPrank(USER);
    //   UsdtToken.mintToken();
      IERC20(WETH).approve(address(flashloan), amountToSupply);
      bool funded = flashloan.supplyInitialFunds(amountToSupply, WETH);
      vm.stopPrank();

      vm.prank(ANOTHER_USER);
      bool success = flashloan.withdrawFunds(0.01 ether, WETH);

      console.log(success);
   }

   function test_withdrawFundsAboveAvailableAmounts() public {
      uint256 amountToSupply = 100 * PRECISION;
      vm.startPrank(USER);
      UsdtToken.mintToken();
      UsdtToken.approve(address(flashloan), amountToSupply);
      bool funded = flashloan.supplyInitialFunds(amountToSupply, USDT);
      bool success = flashloan.withdrawFunds(2000 * PRECISION, USDT);

      console.log(success);
   }

   function test_withdrawFundsByNonOwner() public {
      uint256 amountToSupply = 100 * PRECISION;
      vm.startPrank(ANOTHER_USER);
      UsdtToken.mintToken();
      UsdtToken.transfer(address(flashloan), 1000 * PRECISION);
      bool success = flashloan.withdrawFunds(1000 * PRECISION, USDT);

      console.log(success);
   }

   function test_withdrawFundsZeroAmount() public {
      vm.startPrank(USER);
      bool success = flashloan.withdrawFunds(2000 * PRECISION, USDT);
      console.log(success);
   }

   function test_borrowAsset() public PurchasingPackage(USER) {
      uint256 testAmt = 0.01 ether;
    // WMATIC = 18 decimals
    //  AAVE/WETH approved
    // WETH/WBTC (APPROVED/TESTED)
    // USDT/WETH (APPROVED/TESTED)
    // USDT/WMATIC (APPROVED/TESTED)
    // WETH/WMATIC (APPROVED/TESTED)
    // DAI/WETH (APPROVED/TESTED)
    // DAI/WMATIC (APPROVED/TESTED) (high amount, high fee for protocol)
    // WETH/LINK (GOOD LIQ) (APPROVED/TESTED)
    // WETH/USDT (GOOD LIQ) (APPROVED/TESTED)
    // WETH/AAVE  (APPROVED/TESTED)
    // WBTC/WMATIC (HIGH GAS FE, HIGH LOSTS)
      vm.startPrank(USER);
      IERC20(WETH).transfer(address(flashloan), 0.1 ether);
    //   uint256 beforeTrade = pricing.getTokenPriceInUsd(USDT, testAmt);
      flashloan.requestLoan(WETH, testAmt, USDT);
      FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(USER);
      FlashLoan.User memory user = flashloan.getUserDetails(USER);
    //   uint256 afterTrade = pricing.getTokenPriceInUsd(DAI, user.dailyProfitAmount);
      uint256 percentage = 1;
    //    for USDT & WBTC adds additional 1e10 precision at the end
    //    console.log(beforeTrade);
    //    console.log(afterTrade);
    UsdtToken.approve(address(flashloan), 3 * PRECISION);
    bool succeed = flashloan.withdrawProfit(user.totalProfits, 3 * PRECISION);
    flashloan.resetUserDataMonthly(user.userAddress);
    FlashLoan.User memory userAfter = flashloan.getUserDetails(USER);
    //    uint256 result = (beforeTrade * percentage) / 100;
    //    console.log(result);
    console.log(userAfter.monthlyProfitAmount);
      vm.stopPrank();
   }


   // function test_borrowAssetByUserNotAllowedToTrade() public PurchasingPackage(ANOTHER_USER) {
   //    bool tradeAllowed = false;
   //    bool withdrawAllowed = false;
   //    uint256 testAmt = 40 * PRECISION;

   //    vm.prank(USER);
   //    bool restricted = flashloan.restrictAccountActions(ANOTHER_USER, tradeAllowed, withdrawAllowed);

   //    vm.startPrank(ANOTHER_USER);
   //    flashloan.requestLoan(USDT, testAmt, INCH1, ANOTHER_USER);
   //    FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(ANOTHER_USER);
   //    FlashLoan.User memory user = flashloan.getUserDetails(ANOTHER_USER);
   //  //   console.log("user trade"); 39_799_479
   //    console.log(userTrade.userAddress);
   //    console.log(user.dailyProfitAmount);
   //    console.log(user.dailyTradeAmount);
   //    console.log(user.totalTrades);

   //    bool withdrew = flashloan.withdrawProfit{value: PROFIT_WD_FEE}(user.dailyProfitAmount);
   //    vm.stopPrank();
   // }


   // function test_borrowAssetByNotRegisteredUser() public {
   //    uint256 testAmt = 40 * PRECISION;
   //    vm.startPrank(ANOTHER_USER);
   //    flashloan.requestLoan(USDT, testAmt, INCH1, ANOTHER_USER);
   //    FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(ANOTHER_USER);
   //    FlashLoan.User memory user = flashloan.getUserDetails(ANOTHER_USER);
   //  //   console.log("user trade"); 39_799_479
   //    console.log(userTrade.userAddress);
   //    console.log(user.dailyProfitAmount);
   //    console.log(user.dailyTradeAmount);
   //    console.log(user.totalTrades);
   //    vm.stopPrank();
   // }

   // function test_borrowAssetByBlacklistedAccount() public PurchasingPackage(BLACKLISTED_USER) {
   //    uint256 testAmt = 40 * PRECISION;
   //    vm.prank(USER);
   //    bool isBlacklisted = flashloan.blacklistAccounts(BLACKLISTED_USER);
   //    vm.startPrank(BLACKLISTED_USER);
   //    flashloan.requestLoan(USDT, testAmt, INCH1, BLACKLISTED_USER);
   //    FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(BLACKLISTED_USER);
   //    FlashLoan.User memory user = flashloan.getUserDetails(BLACKLISTED_USER);
   //  //   console.log("user trade"); 39_799_479
   //    console.log(userTrade.userAddress);
   //    console.log(user.dailyProfitAmount);
   //    console.log(user.dailyTradeAmount);
   //    console.log(user.totalTrades);
   //    vm.stopPrank();
   // }


   function test_supplyingInitialFunds() public {
       uint256 amountToSupply = 100 * PRECISION;

       vm.startPrank(USER);
       UsdtToken.mintToken();
       UsdtToken.approve(address(flashloan), amountToSupply);
       bool funded = flashloan.supplyInitialFunds(amountToSupply, USDT);
       uint256 contractFunds = UsdtToken.balanceOf(address(flashloan));
       console.log(funded);
       console.log(contractFunds);
   }
   function test_supplyingInitialFundsBelowMinimumAmount() public {
       uint256 amountToSupply = 10 * PRECISION;

       vm.startPrank(USER);
       UsdtToken.mintToken();
       UsdtToken.approve(address(flashloan), amountToSupply);
       bool funded = flashloan.supplyInitialFunds(amountToSupply, USDT);
       uint256 contractFunds = UsdtToken.balanceOf(address(flashloan));
       console.log(funded);
       console.log(contractFunds);
   }

   function test_supplyingInitialFundsByNonOwner() public {
       uint256 amountToSupply = 100 * PRECISION;

       vm.startPrank(ANOTHER_USER);
       UsdtToken.mintToken();
       UsdtToken.approve(address(flashloan), amountToSupply);
       bool funded = flashloan.supplyInitialFunds(amountToSupply, USDT);
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
      bool funded = flashloan.supplyInitialFunds(amountToSupply, USDT);
      uint256 totalFundsAvail = flashloan.getTotalFunds(USDT);
      console.log(totalFundsAvail);
      vm.stopPrank();
   }

   function test_getOwner() public {
      vm.startPrank(USER);
      address owner = flashloan.getOwner();
      console.log(owner);
      vm.stopPrank();
   }

    // function test_uniswap() public {
    //   uint256 amtIn = 0.01 ether;
    //   vm.startPrank(USER);
    // //   UsdtToken.approve(address(flashloan), amtIn);
    //   IERC20(WETH).approve(address(flashloan), amtIn);
    //   (uint256 amountOut, address tokenOut) = flashloan._uniswapV3(WETH, LINK, amtIn);
    //   console.log(amountOut);
      
    //   uint256 outAmt = flashloan._sushiswap(LINK, DAI, amountOut);
    //   console.log(outAmt);


    //   vm.stopPrank();
      
    // }


}
 
