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

import {FlashLoanSimpleReceiverBase} from "@aave-coreV3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave-coreV3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "./mocks/ERC20Test.sol";
import { IUniswapV3 } from "./interfaces/IUniswapV3.sol";
import { IV2SwapRouter } from "./interfaces/IV2SwapRouter.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase {
    // ------------------------------- ERRORS -----------------------------------------
    error FlashLoan_ZeroAddress();
    error FlashLoan_NotEnoughBalance();
    error FlashLoan_AcountBlacklisted();
    error FlashLoan_NoAssetBeingPassed();
    error FLashLoan_UserNotRegistered();
    error FlashLoan_ProfitStillZero();
    error FlashLoan_WithdrawFeeNotEnough();
    error FlashLoan_CannotWdAboveProfit();
    error FlashLoan_DailyTradeAmountHasReached();
    error FlashLoan_DailyProfitAmountHasReached();

    // --------------------------- STATE VARIABLES --------------------------------------
    uint256 private constant PRECISION = 1e6; // six decimal places for USDT
    uint256 private constant MINIMUM_PURCHASING = 500;
    uint256 private constant THOUSAND = 1000;
    uint256 private constant THREE_THOUSAND = 3000;
    uint256 private constant FIVE_THOUSAND = 5000;
    uint256 private constant TEN_THOUSAND = 10000;
    uint256 private constant PROFIT_WD_FEE = 0.001 ether;
    address payable private immutable i_owner;
    IERC20 private immutable i_paymentToken; // payment for purchasing packages
    address private immutable i_poolAddress;
    uint32[] private packagesLists = [500, 1000, 3000, 5000, 10000];
    uint256 private borrowedAmountInTotal = 0;

    // DEXES ROUTER
    IUniswapV3 private constant UNISWAP_ROUTERV3 = IUniswapV3(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45); // POLYGON 
    IV2SwapRouter private constant SUSHISWAP_ROUTERV2 = IV2SwapRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); 
    IV2SwapRouter private constant QUICKSWAP_ROUTERV2 = IV2SwapRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    // ------------------------ MAPPINGS ----------------------------------------
    mapping(address => User) private user;
    mapping(address => bool) private accountBlacklisted;

    struct User {
        address userAddress;
        uint256 dailyProfit;
        uint256 dailyTrade;
        uint256 totalBorrowed;
        uint256 totalProfit;
        uint256 totalTrades;
        Packages packageType;
        uint256 dailyLimitTrade;
        uint256 dailyProfitLimit;
        bool isRegistered;
        bool isTradeAllowed;
        bool isWithdrawAllowed;
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
        if(user_.dailyTrade == user_.dailyLimitTrade) revert FlashLoan_DailyTradeAmountHasReached();
        _;
    }

    modifier IsDailyProfitReached() {
        User memory user_ = user[msg.sender];
        if(user_.dailyProfit == user_.dailyProfitLimit) revert FlashLoan_DailyProfitAmountHasReached();
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

    // --------------------------------------- EXTERNAL & INTERNAL FUNCTIONS ---------------------------------------------
    receive() external payable {} // in case we want this contract tobe able to receive ether

    function withdrawProfit(uint256 amountToWd) external payable IsValidAddress NotBlacklisted returns(bool withdrew) {
        if(msg.sender != user[msg.sender].userAddress) revert FLashLoan_UserNotRegistered();
        if(amountToWd > user[msg.sender].totalProfit) revert FlashLoan_CannotWdAboveProfit();
        if(user[msg.sender].totalProfit <= 0) revert FlashLoan_ProfitStillZero(); 
        if(msg.value < PROFIT_WD_FEE) revert FlashLoan_WithdrawFeeNotEnough();

        user[msg.sender].totalProfit -= amountToWd;
        i_paymentToken.transferFrom(address(this), msg.sender,amountToWd);
        emit Withdrawal_Successfull(msg.sender, amountToWd);
        withdrew = true; 
    }

    /**
        @dev account restrictions from trade, purchase package, and withdraw
        @param account - account to restricted
        @param  tradeAllowed - true if allowed / false if not allowed 
        @param  withdrawAllowed - true if allowed / false if not allowed 
     */
    function restrictAccountActions(address account, bool tradeAllowed, bool withdrawAllowed) external OnlyOwner IsValidAddress returns(bool) {
        if(account != user[account].userAddress) revert FLashLoan_UserNotRegistered();
        user[account].isTradeAllowed = tradeAllowed;
        user[account].isWithdrawAllowed = withdrawAllowed;
        return true;
    }

    /**
        @dev blacklist an account by owner only
        @param accountToBlacklist_ - account target to blacklist
     */
    function blacklistAccounts(address accountToBlacklist_) external OnlyOwner IsValidAddress returns(bool) {
        accountBlacklisted[accountToBlacklist_] = true;
        return accountBlacklisted[accountToBlacklist_];
    }

    function checkBlacklistedAccount(address account) external view returns(bool) {
        return accountBlacklisted[account];
    }

    function _arbitrageTrade() internal {}


    /**
    @dev buy package
    @param packageTypes_ - types of package
    @param payAmount_ - amount of user needs to pay for the package
     */
     function purchasePackage(uint32 packageTypes_, uint256 payAmount_) external IsValidAddress NotBlacklisted returns(User memory) {
        uint256 userBalance = i_paymentToken.balanceOf(msg.sender);
        if(payAmount_ < MINIMUM_PURCHASING * PRECISION || userBalance == 0 || userBalance <= payAmount_) revert FlashLoan_NotEnoughBalance();
        uint32 typesOfPckg = _altPackageChecking(packageTypes_, payAmount_);
        i_paymentToken.transferFrom(msg.sender, address(this), payAmount_);

        emit Purchasing_Successfull(msg.sender, typesOfPckg);
        return user[msg.sender];
     }


     function _altPackageChecking(uint32 packageTypes_, uint256 payAmount_) internal returns(uint32) {
        uint32 typesOfPackage;
        uint256 dailyProfit = 0;
        uint256 dailyTrade = 0;
        uint256 totalBorrowed = 0;
        uint256 totalProfit = 0;
        uint256 totalTrades = 0;
        Packages packageType;
        uint256 dailyLimitTrade;
        uint256 dailyProfitLimit;
        bool isRegistered = true;
        bool isTradeAllowed = true;
        bool isWithdrawAllowed = true;

        if(packageTypes_ == packagesLists[0] && payAmount_ >=  MINIMUM_PURCHASING * PRECISION) {
            packageType = Packages.FiveHundreds;
            dailyProfitLimit = 20 * PRECISION;
            dailyLimitTrade = 50 * PRECISION;
            typesOfPackage = packagesLists[0];

        } else if(packageTypes_ == packagesLists[1] && payAmount_ >= THOUSAND * PRECISION) {
            packageType = Packages.Thousands;
            dailyProfitLimit = 40 * PRECISION;
            dailyLimitTrade = 100 * PRECISION;
            typesOfPackage = packagesLists[1];
        }
         else if(packageTypes_ == packagesLists[2] && payAmount_ >= THREE_THOUSAND * PRECISION) {
            packageType = Packages.ThreeThousands;
            dailyProfitLimit = 120 * PRECISION;
            dailyLimitTrade = 300 * PRECISION;
            typesOfPackage = packagesLists[2];
        }
         else if(packageTypes_ == packagesLists[3] && payAmount_ >= FIVE_THOUSAND * PRECISION) {
            packageType = Packages.TenThousands;
            dailyProfitLimit = 200 * PRECISION;
            dailyLimitTrade = 500 * PRECISION;
            typesOfPackage = packagesLists[3];
        }
         else if(packageTypes_ == packagesLists[3] && payAmount_ >= TEN_THOUSAND * PRECISION) {
            packageType = Packages.FiveHundreds;
            dailyProfitLimit = 400 * PRECISION;
            dailyLimitTrade = 1000 * PRECISION;
            typesOfPackage = packagesLists[4];
        }

        user[msg.sender] = User(msg.sender, dailyProfit, dailyTrade, totalBorrowed, totalProfit, totalTrades, packageType, dailyLimitTrade, dailyProfitLimit, isRegistered, isTradeAllowed, isWithdrawAllowed); 

        return typesOfPackage;
     }


     function uniswapV3(address tokenIn, address tokenOut, uint256 amountIn) external IsValidAddress NotBlacklisted returns(uint256) {
        // transfer the tokenIn amount to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
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
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOut = UNISWAP_ROUTERV3.exactInputSingle(params);
        return amountOut;

    }

    function sushiswap(address tokenIn, address tokenOut, uint256 amountIn) external IsValidAddress NotBlacklisted returns(uint256[] memory) {

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
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
        return amounts;
        
    }

    function quickSwap(address tokenIn, address tokenOut, uint256 amountIn) external IsValidAddress NotBlacklisted returns(uint256[] memory){

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


    // this function wil be call by aave pool 
    function executeOperation(
        address asset, // asset we want to borrow
        uint256 amount, // asset amount
        uint256 premium, // protocol fee
        address initiator, // initiator will be this contract
        bytes calldata params // optional param
    ) external override returns (bool) {

        // perform an arbitrage here..

         uint256 amountOwed = amount + premium; // repay amount we borrow + fee ( premium )
         IERC20(asset).approve(address(POOL), amountOwed); // give a permission to an aave lending pool to take back the loaned fund 
         return true;
    }


    function requestLoan(address asset_, uint256 amount_) external IsValidAddress NotBlacklisted IsDailyTradeReached IsDailyProfitReached {
        address receiverAddress = address(this); // receiver will be this contract
        address asset = asset_; // we can borrow more than one assets
        uint256 amount = amount_;
        bytes memory params = ""; // any bytes data to pass
        uint16 refCode = 0;

        //  flashloan simple function can only borrow one asset
        // while flashloan function can borrow more than one asset
        if(asset_ != address(0) && amount_ > 0) {
            POOL.flashLoanSimple(
                receiverAddress,
                asset,
                amount,
                params,
                refCode
            );
           borrowedAmountInTotal += amount_;
           return;
        }

        revert FlashLoan_NoAssetBeingPassed();
    }

    function getTotalBorrowed() public view returns(uint256 totalBorrowed) {
        totalBorrowed = borrowedAmountInTotal;
    }

    function getTotalTraded() external view returns(uint256) {

    }

    function getPackagesList() external view returns(uint32[] memory pckgsList) {
        pckgsList = packagesLists;
    }

    function getUserDetails(address account) external view returns(User memory user_) {
        user_ = user[account];
    }

    function getOwner() external view returns(address) {
        return i_owner;
    }

    function getTotalFunds() public view returns(uint256 balance) {
        balance = i_paymentToken.balanceOf(address(this));
    }

    function withdrawFunds() external OnlyOwner IsValidAddress NotBlacklisted returns(bool) {
        uint256 availableFunds = i_paymentToken.balanceOf(address(this));
        if(availableFunds > 0) {
            i_paymentToken.transfer(i_owner, availableFunds);
            return true;
        }

        return false;
    } 

}
