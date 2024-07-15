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
import {IERC20} from "@aave-coreV3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import { IUniswapV3 } from "./interfaces/IUniswapV3.sol";
import { IV2SwapRouter } from "./interfaces/IV2SwapRouter.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase {
    // ------------------------------- ERRORS -----------------------------------------
    error FlashLoan_ZeroAddress();
    error FlashLoan_NotEnoughBalance();
    error FlashLoan_AcountBlacklisted();

    // --------------------------- STATE VARIABLES --------------------------------------
    uint256 private constant PRECISION = 1e6; // six decimal places for USDT
    uint256 private constant MINIMUM_PURCHASING = 500;
    uint256 private constant THOUSAND = 1000;
    uint256 private constant THREE_THOUSAND = 3000;
    uint256 private constant FIVE_THOUSAND = 5000;
    uint256 private constant TEN_THOUSAND = 10000;
    address payable private immutable i_owner;
    IERC20 private immutable i_paymentToken; // payment for purchasing packages
    uint32[] private packagesLists = [500, 1000, 3000, 5000, 10000];

    // EXTERNAL CONTRACTS On Mumbai Testnets
    address private constant POOL_ADDRESS = 0x4CeDCB57Af02293231BAA9D39354D6BFDFD251e0; // polygon testnet;
    IUniswapV3 private constant UNISWAP_ROUTERV3 = IUniswapV3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IV2SwapRouter private constant SUSHISWAP_ROUTERV2 = IV2SwapRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    IV2SwapRouter private constant QUICKSWAP_ROUTERV2 = IV2SwapRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    // ------------------------ MAPPINGS ----------------------------------------
    mapping(address => User) private user;
    mapping(address => bool) private accountBlacklisted;

    struct User {
        address userAddress;
        uint256 profit;
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

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address paymentToken_) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(POOL_ADDRESS)) {
         i_owner = payable(msg.sender);
        i_paymentToken = IERC20(paymentToken_);
    }

    // ------------------------------------------ EVENTS -----------------------------------------------------
    event Purchasing_Successfull(address user, uint32 packageType);

    // -------------------------------------- MODIFIERS -------------------------------------------------------

    modifier OnlyOwner() {
        require(i_owner == msg.sender , "Only Owner can call");
        _;
    }

    modifier IsValidAddress() {
        if(msg.sender == address(0)) revert FlashLoan_ZeroAddress();
        _;
    }

    modifier NotBacklisted() {
        if(accountBlacklisted[msg.sender] == true) revert FlashLoan_AcountBlacklisted();
        _;
    }

    // --------------------------------------- EXTERNAL & INTERNAL FUNCTIONS ---------------------------------------------
    receive() external payable {} // in case we want this contract tobe able to receive ether

    function withdrawProfit() external returns(bool withdrew) {

    }

    function restrictAccountActions(address account, bool tradeAllowed, bool withdrawAllowed) external OnlyOwner IsValidAddress returns(bool) {
        user[account].isTradeAllowed = tradeAllowed;
        user[account].isWithdrawAllowed = withdrawAllowed;
        return true;
    }

    function blacklistAccounts(address accountToBlacklist_) external OnlyOwner IsValidAddress returns(bool) {
        accountBlacklisted[accountToBlacklist_] = true;
        accountBlacklisted[accountToBlacklist_];
    }


    function _arbitrageTrade() internal {}
    /**
    @dev buy package
    @param packageTypes_ - types of package
    @param payAmount_ - amount of user needs to pay for the package
     */
     function purchasePackage(uint32 packageTypes_, uint256 payAmount_) external IsValidAddress NotBacklisted returns(User memory) {
        if(payAmount_ < MINIMUM_PURCHASING * PRECISION) revert FlashLoan_NotEnoughBalance();
        _altPackageChecking(packageTypes_, payAmount_);
        i_paymentToken.transfer(address(this), payAmount_);

        return user[msg.sender];
     }


     function _altPackageChecking(uint32 packageTypes_, uint256 payAmount_) internal {
        user[msg.sender] = User(msg.sender, 0, 0, 0, 0, Packages.FiveHundreds, 50, 20, true, true, true); // set default values
        User memory newUser = user[msg.sender];

        if(packageTypes_ == packagesLists[0] && payAmount_ >=  MINIMUM_PURCHASING * PRECISION) {
            newUser.packageType = Packages.FiveHundreds;
            newUser.dailyProfitLimit = 20 * PRECISION;
            newUser.dailyLimitTrade = 50 * PRECISION;

        } else if(packageTypes_ == packagesLists[1] && payAmount_ >= THOUSAND * PRECISION) {
            newUser.packageType = Packages.Thousands;
            newUser.dailyProfitLimit = 40 * PRECISION;
            newUser.dailyLimitTrade = 100 * PRECISION;
        }
         else if(packageTypes_ == packagesLists[2] && payAmount_ >= THREE_THOUSAND * PRECISION) {
            newUser.packageType = Packages.ThreeThousands;
            newUser.dailyProfitLimit = 120 * PRECISION;
            newUser.dailyLimitTrade = 300 * PRECISION;
        }
         else if(packageTypes_ == packagesLists[3] && payAmount_ >= FIVE_THOUSAND * PRECISION) {
            newUser.packageType = Packages.TenThousands;
            newUser.dailyProfitLimit = 200 * PRECISION;
            newUser.dailyLimitTrade = 500 * PRECISION;
        }
         else if(packageTypes_ == packagesLists[3] && payAmount_ >= TEN_THOUSAND * PRECISION) {
            newUser.packageType = Packages.FiveHundreds;
            newUser.dailyProfitLimit = 400 * PRECISION;
            newUser.dailyLimitTrade = 1000 * PRECISION;
        }
     }

    //  function _packageChecking(string memory packageTypes_) internal returns(Packages package) {
    //     string memory fiveHundredPckg = keccak256(abi.encodePacked(packageTypes_)) == keccak256(abi.encodePacked("fivehundred"));
    //     string memory thousandPckg = keccak256(abi.encodePacked(packageTypes_)) == keccak256(abi.encodePacked("thousand"));
    //     string memory threeThousandPckg = keccak256(abi.encodePacked(packageTypes_)) == keccak256(abi.encodePacked("threethousand"));
    //     string memory fiveThousandPckg = keccak256(abi.encodePacked(packageTypes_)) == keccak256(abi.encodePacked("fivethousand"));
    //     string memory tenThousandPckg = keccak256(abi.encodePacked(packageTypes_)) == keccak256(abi.encodePacked("tenthousand"));

    //     if(fiveHundredPckg) {
    //         return Packages.FiveHundreds;
    //     } else if(thousandPckg) {
    //         return Packages.Thousands;
    //     } else if(threeThousandPckg) {
    //         return Packages.ThreeThousands;
    //     } else if(tenThousandPckg) {
    //         return Packages.TenThousands;
    //     }
    //  }

    // function sushiswap(address tokenIn, address tokenOut, uint256 amount) internal  returns(uint256[] memory) {
    //     IERC20(tokenIn).approve(sushiSwapAddress, amount);
    //     address[] memory pair = new address[](2);
    //     pair[1] = tokenIn;
    //     pair[2] = tokenOut; 
    //     uint256[] memory  amounts = IV2SwapRouter(sushiSwapAddress).swapTokensForExactTokens(
    //             amount,
    //             0,
    //             pair,
    //             address(this),
    //             block.timestamp + 86400
    //         );
    //     return amounts;
        
    // }

    // function quickSwap(address tokenIn, address tokenOut, uint256 amount) internal returns(uint256){
    //     IERC20(tokenIn).approve(qucikswapAddress, amount);
    //     IV2SwapRouter.SushiswapParams memory params =
    //         IV2SwapRouter.SushiswapParams({
    //             tokenIn: tokenIn,
    //             tokenOut: tokenOut,
    //             recipient: address(this),
    //             deadline: block.timestamp + 86400,
    //             amountIn: amount,
    //             amountOutMinimum: 0,
    //             limitSqrtPrice: 0
    //         });

    //     uint256 amountOut = IV2SwapRouter(qucikswapAddress).exactInputSingle(params);
    //     return amountOut;
        
    // }


    // this function wil be call by aave pool 
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


    function requestLoan(address asset_, uint256 amount_) external IsValidAddress NotBacklisted {
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

    function getTotalBorrowed() public view returns(uint256) {

    }

    function getTotalTrade() external view returns(uint256) {

    }

    function getUserDetails(address account) external view returns(User memory user_) {
        user_ = user[account];
    }

    function getBalance(address tokenAddr) public returns(uint256 balance) {
        balance = i_paymentToken.balanceOf(address(this));
    }

    function withdrawFunds() external OnlyOwner IsValidAddress returns(bool) {
        uint256 availableFunds = i_paymentToken.balanceOf(address(this));
        if(availableFunds > 0) {
            i_paymentToken.transfer(i_owner, address(this).balance);
        }


    } 

}
