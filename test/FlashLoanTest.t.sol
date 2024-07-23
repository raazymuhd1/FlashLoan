pragma solidity ^0.8.0;

import { DeployFlashLoan } from "../script/DeployFlashLoan.s.sol";
import { Test, console } from "forge-std/Test.sol";
import { FlashLoan } from "../src/FlashLoan.sol";
import { ERC20Mock } from "../src/mocks/MockERC.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import {MockPoolAddressesProvider} from "../src/mocks/MockPoolAddrProvider.sol";

contract FlashLoanTest is Test {
    DeployFlashLoan deployer;
    FlashLoan flashloan;
    IERC20 UsdtToken;
    HelperConfig helper;

    // address public USER = makeAddr("USER");
    address public BLACKLISTED_USER = makeAddr("Blacklisted");
    address public ANOTHER_USER = 0x781229c7a798c33EC788520a6bBe12a79eD657FC;
    address public WHALE1 = 0x4D8336bDa6C11BD2a805C291Ec719BaeDD10AcB9;
   //  address public ANOTHER_USER = makeAddr("ANOTHER_USER");
    address public ZERO_ADDRESS = address(0);
    uint256 public PRECISION = 1e6;
    uint256 public TEST_BUY_AMT = 1000;
    uint256 private constant PROFIT_WD_FEE = 0.001 ether;
    address USDT; 
    address WETH;
    address POOL_ADDRESSES;
    address USER;
    address USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address SNX = 0x50B728D8D964fd00C2d0AAD81718b71311feF68a;
    address FRAX = 0x104592a158490a9228070E0A8e5343B499e125D0;
    address WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address MANA = 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4; // 4 decimals returns
    address LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39; // LINK & WETH & AAVE CORRECT
    address UNI = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;
    address CURV = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;  // NOT SUPPORTED
    address AAVE = 0xD6DF932A45C0f255f85145f286eA0b292B21C90B;
    address INCH1 = 0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f;  // LOW LIQ
    address MKR = 0x6f7C932e7684666C9fd1d44527765433e01fF61d;  // NOT SUPPORTED
    address SAND = 0xBbba073C31bF03b8ACf7c28EF0738DeCF3695683;  // NOT SUPPORTED
    address BAL = 0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3;  // NOT SUPPORTED

    function setUp() public {
         helper = new HelperConfig();
        ( USDT, WETH, POOL_ADDRESSES, USER ) = helper.networkConfig();
         UsdtToken = IERC20(USDT);

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
        uint32 pckgType = 1000;

      //   vm.prank(USER);
      //   UsdtToken.transfer(caller, 3000 * PRECISION);

        vm.startPrank(caller);
      //   UsdtToken.mintToken();
        UsdtToken.approve(address(flashloan), TEST_BUY_AMT * PRECISION);
        FlashLoan.User memory user = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION, caller);
        vm.stopPrank();
        _;
    }

    function test_purchasingPackageByNonBlacklistedAccount() public {
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

        if(userBalance > 0) {
            UsdtToken.approve(address(flashloan), TEST_BUY_AMT * PRECISION);
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION, USER);
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
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION, USER);
            console.log("user after registered");
            console.log(userAfter.userAddress);
            uint contractBalance = UsdtToken.balanceOf(address(flashloan));
            console.log("contract balance:");
            console.log(contractBalance);

            FlashLoan.User memory repurchasing = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION, USER);
        vm.stopPrank();

        assert(userBalance > 0);
    }

     function test_purchasingPackageZeroAddress() public {
        uint256 amount_ = 10;
        uint32 pckgType = 5000;

        vm.startPrank(ZERO_ADDRESS);
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION, USER);
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
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT * PRECISION, USER);
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
            FlashLoan.User memory userAfter = flashloan.purchasePackage(pckgType, TEST_BUY_AMT, USER);
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
      bool success = flashloan.withdrawFunds(2000 * PRECISION);

      console.log(success);
   }

   function test_withdrawFundsByNonOwner() public {
      vm.startPrank(ANOTHER_USER);
      UsdtToken.mintToken();
      UsdtToken.transfer(address(flashloan), 1000 * PRECISION);
      bool success = flashloan.withdrawFunds(1000 * PRECISION);

      console.log(success);
   }

   function test_withdrawFundsZeroAmount() public {
      vm.startPrank(USER);
      bool success = flashloan.withdrawFunds(2000 * PRECISION);
      console.log(success);
   }

   function test_borrowAsset() public PurchasingPackage(WHALE1)  {
      uint256 testAmt = 10 * 1e18;
       //   WBTC = 8 decimals
    // WETH = 18 decimals
    // LINK = 18 decimals (NOT RECOMMENDED)
    // WMATIC = 18 decimals
    //  AAVE/WETH approved
    // WETH/WBTC
    // USDT/WETH
    // USDT/WMATIC
    // WETH/WMATIC
    // DAI/WETH
    // WETH/LINK (GOOD LIQ)
    // WETH/USDT (GOOD LIQ)
    // WETH/MANA NOTE (LOW LIQ)
    // WBTC/WMATIC (HIGH GAS FE

      vm.startPrank(WHALE1);
      IERC20(DAI).transfer(address(flashloan), 25 * 1e18);

      flashloan.requestLoan(DAI, testAmt, UNI, WHALE1);
      FlashLoan.UserTrade memory userTrade = flashloan.getUserCurrentTrade(WHALE1);
      FlashLoan.User memory user = flashloan.getUserDetails(WHALE1);
    //   console.log("user trade"); 39_799_479
      console.log(userTrade.userAddress);
      console.log(user.dailyProfitAmount);
      console.log(user.dailyTradeAmount);
      console.log(user.totalTrades);

       console.log(UsdtToken.balanceOf(address(flashloan)));
    //   bool withdrew = flashloan.withdrawProfit{value: PROFIT_WD_FEE}(user.dailyProfitAmount);
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

    function test_uniswap() public {
    //   WBTC = 8 decimals
    // WETH = 18 decimals
    // LINK = 18 decimals
    // WMATIC = 18 decimals
    //  AAVE/WETH approved
    // WETH/WBTC
    // USDT/WETH
    // USDT/WMATIC
    // WETH/WMATIC
    // WMATIC/AAVE
    // WETH/LINK (GOOD LIQ)
    // WETH/USDT (GOOD LIQ)
    // WETH/MANA NOTE (LOW LIQ)
    // WBTC/WMATIC (HIGH GAS FEE)

    // BAL, USDT, UNI == NOTE SHOULD BE TAKEN ABOUT THE PRICE
      uint256 amtIn = 0.01 ether;
      vm.startPrank(USER);
    //   UsdtToken.approve(address(flashloan), amtIn);
      IERC20(WETH).approve(address(flashloan), amtIn);
      (uint256 amountOut, address tokenOut) = flashloan._uniswapV3(WETH, LINK, amtIn);
      console.log(amountOut);
      
      uint256 outAmt = flashloan._sushiswap(LINK, DAI, amountOut);
      console.log(outAmt);


      vm.stopPrank();
      
    }

    // function test_uniswapSecond() public {
    //   uint256 amtIn = 0.01 ether;
    //   vm.startPrank(USER);
    // //   UsdtToken.approve(address(flashloan), amtIn);
    // //   (uint256 amountOut, address tokenOut) = flashloan._uniswapV3(USDT, SAND, amtIn);
    // //   console.log(amountOut);
      
    //   IERC20(WETH).approve(address(flashloan), amtIn);
    //   uint256 outAmt = flashloan._sushiswap(WETH, LINK, amtIn);
    //   console.log(outAmt);


    //   vm.stopPrank();
      
    // }

}
 
