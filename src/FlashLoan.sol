// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
Package.    Limit                    Profit 
500$            50$ per trade     20$ (monthly)
1000$.         100$ per trade.   40$ (monthly)
3000$.         300$ per trade   120$ (monthly)
5000$.         500$ per trade    200$ (monthly)
10000$.       1000$ per day     400$ (monthly)
 */


import {FlashLoanSimpleReceiverBase} from "@aave-coreV3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave-coreV3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import { IUniswapV3 } from "./interfaces/IUniswapV3.sol";
import { IV2SwapRouter } from "./interfaces/IV2SwapRouter.sol";
import { PricingTable } from "./Pricing.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase, PricingTable {
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
    error FlashLoan_InvalidTokenAddress();
    error FlashLoan_NotAllowedToWithdraw();
    error FlashLoan_NotAllowedToTrade();
    error FlashLoan_OutputZeroOrTooLittle();
    error FlashLoan_BorrowerAndUserAddrNotMatch(address userAddress, address borrower);

    // --------------------------- STATE VARIABLES --------------------------------------
    uint256 private constant PRECISION = 1e6; // six decimal places for USDT
    uint256 private constant MINIMUM_PURCHASING = 500 * PRECISION;
    uint256 private constant THOUSAND = 1000 * PRECISION;
    uint256 private constant THREE_THOUSAND = 3000 * PRECISION;
    uint256 private constant FIVE_THOUSAND = 5000 * PRECISION;
    uint256 private constant TEN_THOUSAND = 10000 * PRECISION;
    uint256 private constant PROFIT_WD_FEE = 0.001 ether;
    uint256 private constant INITIAL_FUNDS = 5 * PRECISION;
    address payable private immutable i_owner;
    IERC20 private immutable i_paymentToken; // payment for purchasing packages (USDT token)
    address private immutable i_poolAddress;
    uint32[] private packagesLists = [500, 1000, 3000, 5000, 10000];
    uint256 private borrowedAmountInTotal = 0;
    uint256 private tradeCounts = 0;

    // DEXES ROUTER
    IUniswapV3 private constant UNISWAP_ROUTERV3 = IUniswapV3(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45); 
    IV2SwapRouter private constant SUSHISWAP_ROUTERV2 = IV2SwapRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); 
    IV2SwapRouter private constant QUICKSWAP_ROUTERV2 = IV2SwapRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff); 

    // ------------------------ MAPPINGS ----------------------------------------
    mapping(address => User) private user;
    mapping(address => bool) private accountBlacklisted;

    struct UserTrade {
        address userAddress;
        address[] pair;
        uint256 amountTokenIn;
    }

    struct User {
        address userAddress;
        uint256 monthlyProfitAmount;
        uint256 monthlyProfitLimit;
        uint256 perTradeAmountLimit;
        uint256 totalBorrowedAmount;
        uint256 totalTrades;
        uint256 totalProfits;
        Packages packageType;
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
    event FundsHasBeenSupplied(address supplier, uint256 supplyAmount);
    event UserDailyProfitAndTradeReset(address owner);

    // -------------------------------------- MODIFIERS -------------------------------------------------------

    modifier OnlyOwner() {
        require(i_owner == msg.sender , "Only Owner can call");
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
        if(user[msg.sender].isRegistered == false && msg.sender != i_owner) revert FLashLoan_UserNotRegistered();
        _;
    }

    modifier IsWithdrawAllowed() {
        if(user[msg.sender].isWithdrawAllowed == false && msg.sender != i_owner) revert FlashLoan_NotAllowedToWithdraw();
        _;
    }

    modifier IsTradeAllowed(address token, uint256 amount) {
        uint256 tradeValueInUsd = getTokenPriceInUsd(token, amount);
        User memory user_ = user[msg.sender];

        if(user[msg.sender].isTradeAllowed == false && msg.sender != i_owner) revert FlashLoan_NotAllowedToTrade();
        if(tradeValueInUsd > user_.perTradeAmountLimit) revert("Trade: amount to trade above the limit");
        _;
    }

    // --------------------------------------- EXTERNAL & INTERNAL FUNCTIONS ---------------------------------------------
    receive() external payable {} // in case we want this contract tobe able to receive ether

    /**
        @notice withdraw profit by user
        @param amountToWd - amount of their profit wanted to withdraw, only user that has been registered and has profit amount more than 0
        @return withdrew - return true if withdrawal went successfully
     */
    function withdrawProfit(uint256 amountToWd, uint256 fee) external IsValidAddress NotBlacklisted IsRegistered returns(bool withdrew) {
        if(amountToWd > user[msg.sender].totalProfits) revert FlashLoan_CannotWdAboveProfit();
        if(user[msg.sender].totalProfits <= 0) revert FlashLoan_ProfitStillZero(); 
        if(fee < 2 * PRECISION) revert FlashLoan_WithdrawFeeNotEnough();
        // if(user[msg.sender].totalProfits < 5 * PRECISION) revert("WD: you need to have atleast 5 USDT in profits");

        user[msg.sender].totalProfits -= amountToWd;
        i_paymentToken.transferFrom(msg.sender, address(this), fee);
        i_paymentToken.transfer(msg.sender, amountToWd);
        emit Withdrawal_Successfull(msg.sender, amountToWd);
        withdrew = true; 
    }

     /**
       @notice OnlyOwner can call this function
       @param amountToWd - amount of funds to wd
       @return bool - return true if withdrawal went successfully (TESTED)
      */
     function withdrawFunds(uint256 amountToWd, address tokenAsset) external OnlyOwner IsValidAddress NotBlacklisted returns(bool) {
        uint256 availableFunds = IERC20(tokenAsset).balanceOf(address(this));

        if(availableFunds == 0) revert FlashLoan_NoFundsAvailable();
        if(amountToWd > availableFunds) revert FlashLoan_WithdrawAmountCannotBeMoreThanBalance("Withdraw amount cannot be more than available balance on this contract");

        if(availableFunds > 0) {
            IERC20(tokenAsset).transfer(i_owner, amountToWd);
            emit Withdrawal_Successfull(msg.sender, amountToWd);
            return true;
        }

        return false;
    } 

    /**
        @dev reset daily data of user (daily profit, daily trade) tobe 0 after 24 hours
        @param account - a user address that needs tobe reset
     */
    function resetUserDataMonthly(address account) external OnlyOwner IsValidAddress NotBlacklisted returns(User memory) {
        User memory currentUser = user[account];
        if(currentUser.isRegistered == true && currentUser.monthlyProfitAmount > 0) {
            user[account].monthlyProfitAmount = 0;
            emit UserDailyProfitAndTradeReset(msg.sender);
            return currentUser;
        }
        return currentUser;
    }

    /**
        @dev account restrictions from trade, purchase package, and withdraw
        @param account - account to restricted
        @param  tradeAllowed - true if allowed / false if not allowed 
        @param  withdrawAllowed - true if allowed / false if not allowed  (TESTED)
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
        @param accountToBlacklist_ - account target to blacklist (TESTED)
     */
    function blacklistAccounts(address accountToBlacklist_) external OnlyOwner IsValidAddress returns(bool) {
        if(checkBlacklistedAccount(accountToBlacklist_) == true) revert("Account has been blaclisted");
        accountBlacklisted[accountToBlacklist_] = true;
        return accountBlacklisted[accountToBlacklist_];
    }

    /**
        @dev checking whether user has been blacklisted or not
        @param account - user registered address
     */
    function checkBlacklistedAccount(address account) public view returns(bool) {
        return accountBlacklisted[account];
    }


    /**
    @dev buy package
    @param packageTypes_ - types of package
    @param payAmount_ - amount of user needs to pay for the package (TESTED)
     */
     function purchasePackage(uint32 packageTypes_, uint256 payAmount_) external IsValidAddress NotBlacklisted returns(User memory) {
        uint256 userBalance = i_paymentToken.balanceOf(msg.sender);
        uint256 amountToPay = payAmount_;
        if(amountToPay < MINIMUM_PURCHASING) revert FlashLoan_NotEnoughPayment();
        if(userBalance == 0 || userBalance <= amountToPay) revert FlashLoan_NotEnoughBalance();
        if(user[msg.sender].isRegistered == true) revert FLashLoan_UserHasBeenRegistered();
        
        i_paymentToken.transferFrom(msg.sender, address(this), amountToPay);
        uint32 typesOfPckg = _altPackageChecking(packageTypes_, amountToPay);
        emit Purchasing_Successfull(msg.sender, typesOfPckg);
        return user[msg.sender];
     }


     /**
        @dev checking user selected packages
        @param packageTypes_ - types of packages user selected
        @param payAmount_ - an amount user needs to pay for user selected packages
      */
     function _altPackageChecking(uint32 packageTypes_, uint256 payAmount_) internal returns(uint32) {
        uint32 typesOfPackage;
        uint256 monthlyProfitLimit = 0;
        uint256 perTradeAmountLimit = 0;
        Packages packageType = Packages.FiveHundreds;

        // payAmount_ ( ex: 10_000_000 usdt (6 decimals) >= MINIMUM_PURCHASING (500_000_000 usdt) 6 decimals )
        // on the frontend needs to pass an amount * PRECISION (usdt decimals)
        if(packageTypes_ == packagesLists[0] && payAmount_ >=  MINIMUM_PURCHASING) {
            packageType = Packages.FiveHundreds;
            monthlyProfitLimit = 20;
            perTradeAmountLimit = 50;
            typesOfPackage = packagesLists[0];

        } else if(packageTypes_ == packagesLists[1] && payAmount_ >= THOUSAND) {
            packageType = Packages.Thousands;
            monthlyProfitLimit = 40;
            perTradeAmountLimit = 100;
            typesOfPackage = packagesLists[1];
        }
         else if(packageTypes_ == packagesLists[2] && payAmount_ >= THREE_THOUSAND) {
            packageType = Packages.ThreeThousands;
            monthlyProfitLimit = 120;
            perTradeAmountLimit = 300;
            typesOfPackage = packagesLists[2];
        }
         else if(packageTypes_ == packagesLists[3] && payAmount_ >= FIVE_THOUSAND) {
            packageType = Packages.FiveThousands;
            monthlyProfitLimit = 200;
            perTradeAmountLimit = 500;
            typesOfPackage = packagesLists[3];
        }
         else if(packageTypes_ == packagesLists[4] && payAmount_ >= TEN_THOUSAND) {
            packageType = Packages.TenThousands;
            monthlyProfitLimit = 400;
            perTradeAmountLimit = 1000;
            typesOfPackage = packagesLists[4];
        }

        address[] memory defaultPair = new address[](2);
        defaultPair[0] = address(0);
        defaultPair[1] = address(0);
        UserTrade memory userTrades = UserTrade(msg.sender, defaultPair, 0);
        user[msg.sender] = User( 
             msg.sender, 0, monthlyProfitLimit * PRECISION, perTradeAmountLimit * PRECISION, 0, 0, 0, packageType, true, true, true, userTrades); 

        return typesOfPackage;
     }

    /**
        @dev supplying an initial funds into this contract to cover borrow asset fee from AAVE
        @param supplyAmount - an amount to supply (TESTED)
     */
    function supplyInitialFunds(uint256 supplyAmount, address asset) external OnlyOwner IsValidAddress returns(bool) {
        if(asset == address(0)) revert("ASSET: Invalid token asset address");
        if(supplyAmount <= 0) revert("PLEASE SUPPLY ATLEAST 5 USDT");
        IERC20(asset).transferFrom(msg.sender, address(this), supplyAmount);
        emit FundsHasBeenSupplied(msg.sender, supplyAmount);
        return true;
    }

     function _uniswapV3(address tokenIn, address tokenOut, uint256 amountIn) internal IsValidAddress returns(uint256, address) {
        if(tokenIn == address(0) || tokenOut == address(0)) revert("TokenIn or Token out is invalid");
        if(amountIn <= 0) revert("AMOUNTIN: amount in should be more than zero");
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
                // amountIn: inAmount,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            });

        uint256 amountTokenOut = UNISWAP_ROUTERV3.exactInputSingle(params);
        if(amountTokenOut <= 0) revert FlashLoan_OutputZeroOrTooLittle();
        return (amountTokenOut, tokenOut);

    }

    function _sushiswap(address tokenIn, address tokenOut, uint256 amountIn) internal IsValidAddress returns(uint256) {
        // IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        if(tokenIn == address(0) || tokenOut == address(0)) revert("TokenIn or Token out is invalid");
        if(amountIn <= 0) revert("AMOUNTIN: amount in should be more than zero");
        IERC20(tokenIn).approve(address(SUSHISWAP_ROUTERV2), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut; 
        uint256[] memory  amounts = SUSHISWAP_ROUTERV2.swapExactTokensForTokens(
                amountIn,
                1,
                path,
                address(this),
                block.timestamp
            );

        if(amounts[1] <= 0) revert FlashLoan_OutputZeroOrTooLittle();
        return amounts[1];
    }

    function quickSwap(address tokenIn, address tokenOut, uint256 amountIn) public IsValidAddress NotBlacklisted returns(uint256){
       
        IERC20(tokenIn).approve(address(QUICKSWAP_ROUTERV2), amountIn);
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut; 
        uint256[] memory  amounts = QUICKSWAP_ROUTERV2.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp
            );

        // IV2SwapRouter.ExactInputSingleParams memory params =
        //     IV2SwapRouter.ExactInputSingleParams({
        //         tokenIn: tokenIn,
        //         tokenOut: tokenOut,
        //         recipient: address(this),
        //         deadline: block.timestamp,
        //         amountIn: amountIn,
        //         amountOutMinimum: 1,
        //         limitSqrtPrice: 0
        //     });
        // uint256 amountTokenOut = QUICKSWAP_ROUTERV2.exactInputSingle(params);

        return amounts[1];
        
    }


    function _updateUserData(uint256 profits_, uint256 amount, address borrower, address asset_) internal {
            uint256 borrowedOrTradeAmount;
            uint256 borrowedAmountInUsd = getTokenPriceInUsd(asset_, amount);
            User memory user_ = user[borrower];

            if(user_.monthlyProfitAmount + profits_ > user_.monthlyProfitLimit) revert("Profit: monthly profit limit has been reached the limit");

          unchecked {
                    borrowedOrTradeAmount = amount;
                    borrowedAmountInTotal += borrowedAmountInUsd;
                    tradeCounts += 1;
                    user[borrower].totalBorrowedAmount += borrowedAmountInUsd;
                    user[borrower].totalTrades += 1;
            }

        if(profits_ <= 0) revert("No profit from this trade, try again later");

        unchecked {
                user[borrower].monthlyProfitAmount += profits_;
                user[borrower].totalProfits += profits_;
            
        }

    }

    function _profitHandler(address asset, uint256 tradeAmount, uint256 outputAmount) internal returns(uint256 profits_) {
         uint256 tradeValueInUsd = getTokenPriceInUsd(asset, tradeAmount);
         uint256 outputValueInUsd = getTokenPriceInUsd(asset, outputAmount);
         uint256 profitPercentage = 1;

         profits_ = tradeValueInUsd > outputValueInUsd ? (tradeValueInUsd * profitPercentage) / 100 : outputValueInUsd - tradeValueInUsd;
         
    }

    // this function wil be called by aave pool 
    function executeOperation(
        address asset, // asset we want to borrow
        uint256 amount, // asset amount
        uint256 premium, // protocol fee 5000
        address initiator, // initiator will be this contract
        bytes calldata params // optional param
    ) external override returns (bool) {

          (address borrower) = abi.decode(params, (address));
          UserTrade memory userTrade = user[borrower].userTrade;
          uint256 borrowedAmount = amount; 
          uint256 amountOwed;
          address[] memory resetTradePair = new address[](2);
          resetTradePair[0] = address(0);
          resetTradePair[1] = address(0);

          if(userTrade.userAddress == address(0)) revert FlashLoan_BorrowerAddressIsZero(userTrade.userAddress);
          if(userTrade.pair[0] == address(0) || userTrade.pair[1] == address(0)) revert FlashLoan_InvalidTokenAddress();
          if(borrower != userTrade.userAddress)  revert FlashLoan_BorrowerAndUserAddrNotMatch(borrower, userTrade.userAddress);

                // perform an arbitrage here..
                (uint256 amountTokenIn, address tokenIn) = _uniswapV3(userTrade.pair[0], userTrade.pair[1], userTrade.amountTokenIn);
                 uint256 amountTokenOut = _sushiswap(tokenIn, userTrade.pair[0], amountTokenIn);
              
                unchecked {
                    amountOwed = borrowedAmount + premium;
                }

                _updateUserData(_profitHandler(userTrade.pair[0], borrowedAmount, amountTokenOut), borrowedAmount, borrower, userTrade.pair[0]);
                // reset user trade
                 user[borrower].userTrade.pair = resetTradePair;
                 user[borrower].userTrade.amountTokenIn = 0;

                if(amountOwed < borrowedAmount + premium) revert("Pool Repay: Pool repayment failed");
                unchecked {
                    IERC20(asset).approve(address(POOL), amountOwed); // give a permission to an aave lending pool to take back the loaned fund 
                }
                return true;

    }

    // TESTED
    function requestLoan(address assetToBorrow, uint256 amountToBorrow_, address targetTokenOut) external IsValidAddress 
    NotBlacklisted 
    IsRegistered
    IsTradeAllowed(assetToBorrow, amountToBorrow_)
    {
        address receiverAddress = address(this); // receiver will be this contract
        address asset = assetToBorrow; // we can borrow more than one assets
        uint256 amount = amountToBorrow_;
        bytes memory params = abi.encode(msg.sender); // this is needed to identified the borrower address
        uint16 refCode = 0;
        uint256 contractBalanceOfAssets = IERC20(assetToBorrow).balanceOf(address(this));

        address[] memory tradePair = new address[](2);
        tradePair[0] = assetToBorrow;
        tradePair[1] = targetTokenOut;

        if(contractBalanceOfAssets == 0) revert FlashLoan_NotEnoughFeeToCoverTxs();
        if(assetToBorrow == address(0) || amount == 0) revert FlashLoan_NoAssetBeingPassedOrAmountZero();

           user[msg.sender].userTrade.userAddress = msg.sender;
           user[msg.sender].userTrade.pair = tradePair;
           user[msg.sender].userTrade.amountTokenIn = amount;

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

    /**
      @dev get total asset that has been borrowed by all users (TESTED)
     */
    function getTotalBorrowed() external view returns(uint256 totalBorrowed) {
        totalBorrowed = borrowedAmountInTotal;
    }

    // TESTED
    function getTotalTradesCount() external view returns(uint256) {
        uint256 tradeInTotal = tradeCounts;
        return tradeInTotal;
    }

    // TESTED
    function getPackagesList() external view returns(uint32[] memory pckgsList) {
        pckgsList = packagesLists;
    }

    // TESTED
    function getUserDetails(address account) public view returns(User memory user_) {
        user_ = user[account];
    }

    // TESTED
    function getOwner() external view returns(address) {
        return i_owner;
    }

    // TESTED
    function getTotalFunds(address asset) external view returns(uint256 balance) {
        balance = IERC20(asset).balanceOf(address(this));
    }


}
