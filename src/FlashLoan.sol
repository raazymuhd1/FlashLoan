// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 @notice supported tokens on aave pool: USDT, USDC, WETH, DAI, MAKER DAO, LINK, AAVE, WBTC, 1INCH
 @notice MAINNET ADDRESSES Of Price Feeds
 @notice AAVE price feeds address: 0x72484B12719E23115761D5DA1646945632979bB6
 @notice 1INCH price feeds address: 0x443C5116CdF663Eb387e72C688D276e702135C87

 @notice AMOY TESTNET ADDRESSES Of Price Feeds
 @notice BTC: 0xe7656e23fE8077D438aEfbec2fAbDf2D8e070C4f
 @notice DAI: 0x1896522f28bF5912dbA483AC38D7eE4c920fDB6E
 @notice ETH: 0xF0d50568e3A7e8259E16663972b11910F89BD8e7
 @notice LINK: 0xc2e2848e28B9fE430Ab44F55a8437a33802a219C
 @notice USDC: 0x1b8739bB4CdF0089d07097A9Ae5Bd274b29C6F16
 @notice USDT: 0x3aC23DcB4eCfcBd24579e1f34542524d0E4eDeA8

 @notice packages 
Package.    Limit                    Profit 
500$            50$ per trade     20$
1000$.         100$ per trade.   40$
3000$.         300$ per trade   120$
5000$.         500$ per trade    200$
10000$.       1000$ per day     400$
 */

/**
    @notice limitation with uniswap router v1 is not available on sepolia, only on eth mainnet
    @notice limitation with uniswap router v2 is on sepolia is not fully working, only on mainnet.
    @notice limitation with uniswap router v1 on polygon is polygon mumbai has been deprecated, and is not available on AMOY TESTNET yet. only working for polygon mainnet.
 */

import {FlashLoanSimpleReceiverBase} from "@aave-coreV3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave-coreV3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "./mocks/ERC20Test.sol";
import { IUniswapV3 } from "./interfaces/IUniswapV3.sol";
import { IV2SwapRouter } from "./interfaces/IV2SwapRouter.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase {
    // ------------------------------- ERRORS -----------------------------------------
    error FlashLoan_ZeroAddress();
    error FlashLoan_NotEnoughBalance();
    error FlashLoan_NoFundsAvailable();
    error FlashLoan_NotEnoughPayment();
    error FlashLoan_AcountBlacklisted();
    error FlashLoan_NoAssetBeingPassedOrAmountZero();
    error FLashLoan_UserNotRegistered();
    error FLashLoan_UserHasBeenRegistered();
    error FlashLoan_ProfitStillZero();
    error FlashLoan_WithdrawFeeNotEnough();
    error FlashLoan_CannotWdAboveProfit();
    error FlashLoan_DailyTradeAmountHasReached();
    error FlashLoan_DailyProfitAmountHasReached();
    error FlashLoan_UserTradeAddressIsNotMatch();
    error FlashLoan_BorrowerAddressIsZero(address borrower);
    error FlashLoan_NotEnoughFeeToCoverTxs();
    error FlashLoan_PackageNotAvailable(string reason);
    error FlashLoan_WithdrawAmountCannotBeMoreThanBalance(string reason);

    // --------------------------- STATE VARIABLES --------------------------------------
    uint256 private constant PRECISION = 1e6; // six decimal places for USDT
    uint256 private constant MINIMUM_PURCHASING = 500 * PRECISION;
    uint256 private constant THOUSAND = 1000 * PRECISION;
    uint256 private constant THREE_THOUSAND = 3000 * PRECISION;
    uint256 private constant FIVE_THOUSAND = 5000 * PRECISION;
    uint256 private constant TEN_THOUSAND = 10000 * PRECISION;
    uint256 private constant PROFIT_WD_FEE = 0.001 ether;
    address payable private immutable i_owner;
    IERC20 private immutable i_paymentToken; // payment for purchasing packages
    address private immutable i_poolAddress;
    uint32[] private packagesLists = [500, 1000, 3000, 5000, 10000];
    uint256 private borrowedAmountInTotal = 0;

    // DEXES ROUTER
    IUniswapV3 private constant UNISWAP_ROUTERV3 = IUniswapV3(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45); // POLYGON / ETH MAINNET
    IV2SwapRouter private constant SUSHISWAP_ROUTERV2 = IV2SwapRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); 
    // IV2SwapRouter private constant QUICKSWAP_ROUTERV2 = IV2SwapRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff); // quickswap v2
    IV2SwapRouter private constant QUICKSWAP_ROUTERV2 = IV2SwapRouter(0xf5b509bB0909a69B1c207E495f687a596C168E12); // quickswap v3 

    // ------------------------ MAPPINGS ----------------------------------------
    mapping(address => User) private user;
    mapping(address => bool) private accountBlacklisted;
    // mapping(address => UserTrade) private s_userTrade;

    struct UserTrade {
        address userAddress;
        address[] pair;
        uint256 amountTokenIn;
    }

    struct User {
        address userAddress;
        uint256 dailyProfitAmount;
        uint256 dailyTradeAmount;
        uint256 totalBorrowedAmount;
        uint256 totalProfitAmount;
        uint256 totalTrades;
        Packages packageType;
        uint256 dailyLimitTradeAmount;
        uint256 dailyProfitLimitAmount;
        bool isRegistered;
        bool isTradeAllowed;
        bool isWithdrawAllowed;
        UserTrade userTrade;
    }

    enum Packages {
        FiveHundreds,
        Thousands,
        ThreeThousands,
        FiveThousands,
        TenThousands
    }

    // ------------------------------------------ CONSTRUCTOR -----------------------------------------------

    constructor(address paymentToken_, address poolAddress_, address payable owner_) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(poolAddress_)) {
         i_owner = owner_;
        i_paymentToken = IERC20(paymentToken_);
        i_poolAddress = poolAddress_;
    }

    // ------------------------------------------ EVENTS -----------------------------------------------------
    event Purchasing_Successfull(address user, uint32 packageType);
    event Withdrawal_Successfull(address user, uint256 wdAmount);

    // -------------------------------------- MODIFIERS -------------------------------------------------------

    modifier OnlyOwner() {
        require(i_owner == msg.sender , "Only Owner can call");
        _;
    }

    modifier IsDailyTradeReached() {
        User memory user_ = user[msg.sender];
        if(user_.dailyTradeAmount > 0 && user_.dailyTradeAmount >= user_.dailyLimitTradeAmount) revert FlashLoan_DailyTradeAmountHasReached();
        _;
    }

    modifier IsDailyProfitReached() {
        User memory user_ = user[msg.sender];
        if(user_.dailyProfitAmount > 0 && user_.dailyProfitAmount >= user_.dailyProfitLimitAmount) revert FlashLoan_DailyProfitAmountHasReached();
        _;
    }

    modifier IsValidAddress() {
        if(msg.sender == address(0)) revert FlashLoan_ZeroAddress();
        _;
    }

    modifier NotBlacklisted() {
        if(accountBlacklisted[msg.sender] == true) revert FlashLoan_AcountBlacklisted();
        _;
    }

    modifier IsRegistered() {
        if(user[msg.sender].isRegistered == false) revert FLashLoan_UserNotRegistered();
        _;
    }

    // --------------------------------------- EXTERNAL & INTERNAL FUNCTIONS ---------------------------------------------
    receive() external payable {} // in case we want this contract tobe able to receive ether

    function withdrawProfit(uint256 amountToWd) external payable IsValidAddress NotBlacklisted returns(bool withdrew) {
        if(user[msg.sender].userAddress == address(0)) revert FLashLoan_UserNotRegistered();
        if(amountToWd * PRECISION > user[msg.sender].totalProfitAmount) revert FlashLoan_CannotWdAboveProfit();
        if(user[msg.sender].totalProfitAmount <= 0) revert FlashLoan_ProfitStillZero(); 
        if(msg.value < PROFIT_WD_FEE) revert FlashLoan_WithdrawFeeNotEnough();

        user[msg.sender].totalProfitAmount -= amountToWd;
        i_paymentToken.transfer(msg.sender, amountToWd);
        emit Withdrawal_Successfull(msg.sender, amountToWd);
        withdrew = true; 
    }

     function withdrawFunds(uint256 amountToWd) external OnlyOwner IsValidAddress NotBlacklisted returns(bool) {
        uint256 availableFunds = i_paymentToken.balanceOf(address(this));

        if(availableFunds == 0) revert FlashLoan_NoFundsAvailable();
        if(amountToWd * PRECISION > availableFunds) revert FlashLoan_WithdrawAmountCannotBeMoreThanBalance("Withdraw amount cannot be more than available balance on this contract");

        if(availableFunds > 0) {
            i_paymentToken.transfer(i_owner, amountToWd * PRECISION );
            emit Withdrawal_Successfull(msg.sender, amountToWd * PRECISION);
            return true;
        }

        return false;
    } 

    /**
        @dev account restrictions from trade, purchase package, and withdraw
        @param account - account to restricted
        @param  tradeAllowed - true if allowed / false if not allowed 
        @param  withdrawAllowed - true if allowed / false if not allowed 
     */
    function restrictAccountActions(address account, bool tradeAllowed, bool withdrawAllowed) external OnlyOwner IsValidAddress returns(bool) {
        if(account != user[account].userAddress) revert FLashLoan_UserNotRegistered();
        if(user[account].isTradeAllowed == false || user[account].isWithdrawAllowed == false) revert("user has been restricted");
        user[account].isTradeAllowed = tradeAllowed;
        user[account].isWithdrawAllowed = withdrawAllowed;
        return true;
    }

    /**
        @dev blacklist an account by owner only
        @param accountToBlacklist_ - account target to blacklist
     */
    function blacklistAccounts(address accountToBlacklist_) external OnlyOwner IsValidAddress returns(bool) {
        if(accountBlacklisted[accountToBlacklist_] == true) revert("Account has been blaclisted");
        accountBlacklisted[accountToBlacklist_] = true;
        return accountBlacklisted[accountToBlacklist_];
    }

    function checkBlacklistedAccount(address account) external view returns(bool) {
        return accountBlacklisted[account];
    }


    /**
    @dev buy package
    @param packageTypes_ - types of package
    @param payAmount_ - amount of user needs to pay for the package
     */
     function purchasePackage(uint32 packageTypes_, uint256 payAmount_) external IsValidAddress NotBlacklisted returns(User memory) {
        uint256 userBalance = i_paymentToken.balanceOf(msg.sender);
        uint256 amountToPay = payAmount_ * PRECISION;
        if(amountToPay < MINIMUM_PURCHASING) revert FlashLoan_NotEnoughPayment();
        if(userBalance == 0 || userBalance <= amountToPay) revert FlashLoan_NotEnoughBalance();
        if(user[msg.sender].isRegistered == true) revert FLashLoan_UserHasBeenRegistered();
        
        i_paymentToken.transferFrom(msg.sender, address(this), amountToPay);
        uint32 typesOfPckg = _altPackageChecking(packageTypes_, amountToPay);
        emit Purchasing_Successfull(msg.sender, typesOfPckg);
        return user[msg.sender];
     }


     function _altPackageChecking(uint32 packageTypes_, uint256 payAmount_) internal returns(uint32) {
        uint32 typesOfPackage;
        uint256 dailyProfitAmount = 0;
        uint256 dailyTradeAmount = 0;
        uint256 totalBorrowedAmount = 0;
        uint256 totalProfitAmount = 0;
        uint256 totalTrades = 0;
        Packages packageType = Packages.FiveHundreds;
        uint256 dailyLimitTradeAmount = 20;
        uint256 dailyProfitLimitAmount = 50;
        bool isRegistered = true;
        bool isTradeAllowed = true;
        bool isWithdrawAllowed = true;

        if(packageTypes_ == packagesLists[0] && payAmount_ >=  MINIMUM_PURCHASING) {
            packageType = Packages.FiveHundreds;
            dailyProfitLimitAmount = 20;
            dailyLimitTradeAmount = 50;
            typesOfPackage = packagesLists[0];

        } else if(packageTypes_ == packagesLists[1] && payAmount_ >= THOUSAND) {
            packageType = Packages.Thousands;
            dailyProfitLimitAmount = 40;
            dailyLimitTradeAmount = 100;
            typesOfPackage = packagesLists[1];
        }
         else if(packageTypes_ == packagesLists[2] && payAmount_ >= THREE_THOUSAND) {
            packageType = Packages.ThreeThousands;
            dailyProfitLimitAmount = 120;
            dailyLimitTradeAmount = 300;
            typesOfPackage = packagesLists[2];
        }
         else if(packageTypes_ == packagesLists[3] && payAmount_ >= FIVE_THOUSAND) {
            packageType = Packages.TenThousands;
            dailyProfitLimitAmount = 200;
            dailyLimitTradeAmount = 500;
            typesOfPackage = packagesLists[3];
        }
         else if(packageTypes_ == packagesLists[3] && payAmount_ >= TEN_THOUSAND) {
            packageType = Packages.FiveHundreds;
            dailyProfitLimitAmount = 400;
            dailyLimitTradeAmount = 1000;
            typesOfPackage = packagesLists[4];
        }

        address[] memory defaultPair = new address[](2);
        defaultPair[0] = address(0);
        defaultPair[1] = address(0);
        UserTrade memory userTrades = UserTrade(msg.sender, defaultPair, 0);
        user[msg.sender] = User( 
             msg.sender, dailyProfitAmount, dailyTradeAmount, totalBorrowedAmount, totalProfitAmount, totalTrades, packageType, dailyLimitTradeAmount * PRECISION, dailyProfitLimitAmount * PRECISION, isRegistered, isTradeAllowed, isWithdrawAllowed, userTrades); 

        return typesOfPackage;
     }


     function _uniswapV3(address tokenIn, address tokenOut, uint256 amountIn) internal IsValidAddress NotBlacklisted returns(uint256, address) {
        // transfer the tokenIn amount to this contract
        // IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        // then this contract approved uniswap router to pull the tokenIn amountIn
        IERC20(tokenIn).approve(address(UNISWAP_ROUTERV3), amountIn);

        IUniswapV3.ExactInputSingleParams memory params =
            IUniswapV3.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: address(this),
                // deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            });

        uint256 amountTokenOut = UNISWAP_ROUTERV3.exactInputSingle(params);
        return (amountTokenOut, tokenOut);

    }

    function _sushiswap(address tokenIn, address tokenOut, uint256 amountIn) internal IsValidAddress NotBlacklisted returns(uint256, address) {

        // IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(SUSHISWAP_ROUTERV2), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut; 
        uint256[] memory  amounts = SUSHISWAP_ROUTERV2.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp
            );
        return (amounts[1], tokenOut);
        
    }

    function quickSwap(address tokenIn, address tokenOut, uint256 amountIn) internal IsValidAddress NotBlacklisted returns(uint256[] memory){

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(QUICKSWAP_ROUTERV2), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut; 
        uint256[] memory  amounts = SUSHISWAP_ROUTERV2.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp
            );
        return amounts;
        
    }


    function _updateUserData(uint256 amountTokenOut, uint256 amount, address borrower) internal {
            uint256 profits;
            uint256 borrowedOrTradeAmount;

          unchecked {
                    profits = amountTokenOut - amount; // this still needs tobe fixed
                    borrowedOrTradeAmount = amount * PRECISION;

                    borrowedAmountInTotal += borrowedOrTradeAmount;
                    user[borrower].totalBorrowedAmount += borrowedOrTradeAmount;
                    user[borrower].dailyTradeAmount += borrowedOrTradeAmount;
                    user[borrower].totalTrades += 1;
            }

        unchecked {
             if(profits != 0) {
                    user[borrower].dailyProfitAmount += profits;
                    user[borrower].totalProfitAmount += profits;
              } else {
                    user[borrower].dailyProfitAmount += 0;
                    user[borrower].totalProfitAmount += 0;
              }
        }

    }

    // this function wil be call by aave pool 
    function executeOperation(
        address asset, // asset we want to borrow
        uint256 amount, // asset amount
        uint256 premium, // protocol fee
        address initiator, // initiator will be this contract
        bytes calldata params // optional param
    ) external override returns (bool) {

          (address borrower) = abi.decode(params, (address));
          UserTrade memory userTrade = user[borrower].userTrade;
          uint256 amountOwed;

          address[] memory resetTradePair = new address[](2);
          resetTradePair[0] = address(0);
          resetTradePair[1] = address(0);

          if(userTrade.userAddress == address(0)) revert FlashLoan_BorrowerAddressIsZero(userTrade.userAddress);
          if(borrower != address(0) && borrower == userTrade.userAddress) {
                // perform an arbitrage here..
                (uint256 amountTokenIn, address tokenIn) = _uniswapV3(userTrade.pair[0], userTrade.pair[1], amount);
                (uint256 amountTokenOut, address tokenOut) = _sushiswap(tokenIn, userTrade.pair[0], amountTokenIn);

                unchecked {
                    amountOwed = amount + premium; // repay amount we borrow + fee ( premium )
                }

                _updateUserData(amountTokenOut, amount, borrower);

                // reset user trade
                 user[borrower].userTrade.pair = resetTradePair;
                 user[borrower].userTrade.amountTokenIn = 0;
                IERC20(asset).approve(address(POOL), amountOwed); // give a permission to an aave lending pool to take back the loaned fund 
                return true;
            }

    }


    function requestLoan(address assetToBorrow, uint256 amountToBorrow_, address targetTokenOut, address borrower) external IsValidAddress 
    NotBlacklisted 
    IsDailyTradeReached 
    IsDailyProfitReached 
    IsRegistered
    {
        address receiverAddress = address(this); // receiver will be this contract
        address asset = assetToBorrow; // we can borrow more than one assets
        uint256 amount = amountToBorrow_;
        bytes memory params = abi.encode(borrower); // this is needed to identified the borrower address
        uint16 refCode = 0;
        uint256 contractBalancesOfUsdt = IERC20(assetToBorrow).balanceOf(address(this));

        address[] memory tradePair = new address[](2);
        tradePair[0] = assetToBorrow;
        tradePair[1] = targetTokenOut;

        if(contractBalancesOfUsdt < amountToBorrow_ * PRECISION || contractBalancesOfUsdt == 0) revert FlashLoan_NotEnoughFeeToCoverTxs();
        if(assetToBorrow == address(0) || amountToBorrow_ == 0) revert FlashLoan_NoAssetBeingPassedOrAmountZero();

           user[borrower].userTrade.userAddress = borrower;
           user[borrower].userTrade.pair = tradePair;
           user[borrower].userTrade.amountTokenIn = amount * PRECISION;

         POOL.flashLoanSimple(
                receiverAddress,
                asset,
                amount,
                params,
                refCode
         );

    }

    function getUserCurrentTrade(address user_) public returns(UserTrade memory) {
        return user[user_].userTrade;
    } 

    function getTotalBorrowed() public view returns(uint256 totalBorrowed) {
        totalBorrowed = borrowedAmountInTotal;
    }

    function getTotalTraded() external view returns(uint256) {

    }

    function getPackagesList() external view returns(uint32[] memory pckgsList) {
        pckgsList = packagesLists;
    }

    function getUserDetails(address account) public view returns(User memory user_) {
        user_ = user[account];
    }

    function getOwner() external view returns(address) {
        return i_owner;
    }

    function getTotalFunds() public view returns(uint256 balance) {
        balance = i_paymentToken.balanceOf(address(this));
    }

}
