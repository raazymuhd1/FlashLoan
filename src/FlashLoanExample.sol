// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice this contract is belonged to METABANK project
 * @author RAAZY_DEVS
 */

import {FlashLoanSimpleReceiverBase} from "@aave-coreV3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave-coreV3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave-coreV3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import { IController } from "./interfaces/IController.sol";
import { IUniswapV3 } from "./interfaces/IUniswapV3.sol";
import { IV2SwapRouter } from "./interfaces/IV2SwapRouter.sol";


contract MetaBankFlashLoan is FlashLoanSimpleReceiverBase {

    event FUNDTransferred(address account, uint256 amount);
    event SignControllerchanged(address prevSigner, address newSigner);
    event BoomerangControllerchanged(address prevController, address newController);

    //@notice Signer the event is emited at the time of changeSigner function invoke. 
    //@param previousSigner address of the previous contract owner.
    //@param newSigner address of the new contract owner.

    event SignerChanged(
        address signer,
        address newOwner
    );

    //@notice Sign struct stores the sign bytes
    //@param v it holds(129-130) from sign value length always 27/28.
    //@param r it holds(0-66) from sign value length.
    //@param s it holds(67-128) from sign value length.
    //@param nonce unique value.

    struct Sign{
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 nonce;
    }

    enum dexList {
        uniswapV2,
        uniswapV3,
        paraswap,
        quickwap
    }

    uint8[] dexPath;
    address[] pairs;
    address[] currentpairs;

    // dex lists
    address sushiSwapAddress;
    address uniswapv3Address;
    address qucikswapAddress;

    address public MetabankController;
    address public signController;

    mapping (bytes32 => bool) public isValidSign;


    modifier onlyUSERRole() {
        require(IController(MetabankController).checkUserRole(msg.sender), "Metabank controller: account not whitelisted");
        _;
    }

    modifier onlyADMINRole() {
        require(IController(MetabankController).checkADMINRole(msg.sender), "Metabank controller: invalid ADMIN account");
        _;
    }

    constructor(address _addressProvider, address _uniswapv3Address,address _quickswapAddress, address _sushiswapAddress, address _metabankController, address _signer) 
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
       MetabankController = _metabankController;
       uniswapv3Address = _uniswapv3Address;
       qucikswapAddress = _quickswapAddress;
       sushiSwapAddress = _sushiswapAddress;
       signController = _signer;
    }

    function changeSignController(address newSigner) external onlyADMINRole() {
        require(newSigner != address(0), "Invalid signer address");
        address temp = signController;
        signController = newSigner;
        emit SignControllerchanged(temp, newSigner);
    }

    function changeMetabankController(address newBoomerangController) external onlyADMINRole() {
        require(newBoomerangController != address(0), "Invalid signer address");
        address temp = MetabankController;
        MetabankController = newBoomerangController;
        emit BoomerangControllerchanged(temp, MetabankController);
    }

    function withdrawFunds(address token, uint256 amount) external  onlyADMINRole() returns(bool) {
        require(amount !=0, "BoomerangController: amount should be greater than zero");
        bool status = IERC20(token).transfer(msg.sender, amount);
        emit FUNDTransferred(token, amount);
        return  status;
    }

    function swapTokens(uint256 amount, uint256 premium) internal {
        require((pairs.length) - 1 == dexPath.length, "invalid trx");

        uint256 borrowed = amount;

        for (uint i = 0; i < dexPath.length; i++)
        {

            if(dexList(dexPath[i]) == dexList.uniswapV3) {
                amount = uniswapV3(pairs[i], pairs[i+1], amount);
            }

            if(dexList(dexPath[i]) == dexList.paraswap) {
                amount = uniswapV3(pairs[i], pairs[i+1], amount);
            }
            
            if(dexList(dexPath[i]) == dexList.quickwap) {
                amount = quickSwap(pairs[i], pairs[i+1], amount);
            }
        }

        uint256 slippage = (borrowed - amount);
        require(slippage <= ((borrowed * 25)/1000), "Non-executable trade");
    }

    function uniswapV3(address tokenIn, address tokenOut, uint256 amount) internal returns(uint256) {

        IERC20(tokenIn).approve(uniswapv3Address, amount);
        IUniswapV3.ExactInputSingleParams memory params =
            IUniswapV3.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp + 86400,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOut = IUniswapV3(uniswapv3Address).exactInputSingle(params);
        return amountOut;

    }

    function sushiswap(address tokenIn, address tokenOut, uint256 amount) internal  returns(uint256[] memory) {
        IERC20(tokenIn).approve(sushiSwapAddress, amount);
        address[] memory pair = new address[](2);
        pair[1] = tokenIn;
        pair[2] = tokenOut; 
        uint256[] memory  amounts = IV2SwapRouter(sushiSwapAddress).swapTokensForExactTokens(
                amount,
                0,
                pair,
                address(this),
                block.timestamp + 86400
            );
        return amounts;
        
    }

    function quickSwap(address tokenIn, address tokenOut, uint256 amount) internal returns(uint256){
        IERC20(tokenIn).approve(qucikswapAddress, amount);
        IV2SwapRouter.SushiswapParams memory params =
            IV2SwapRouter.SushiswapParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                recipient: address(this),
                deadline: block.timestamp + 86400,
                amountIn: amount,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            });

        uint256 amountOut = IV2SwapRouter(qucikswapAddress).exactInputSingle(params);
        return amountOut;
        
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        swapTokens(amount, premium);
        uint256 amountOwed = amount + premium; // borrowed amount + fee
        IERC20(asset).approve(address(POOL), amountOwed); // approving the POOL to pull the borrowed amounts + fee;
        return true;
    }

    function requestFlashLoan(address _token, uint256 _amount, uint8[] memory _dexList, address[] memory _pairs, uint256 profit, uint256 borrowedAmountinUSD, uint256 profitinUSD, Sign calldata sign) public onlyUSERRole() {
        verifySign(msg.sender, _token, _amount,sign);
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "";
        uint16 referralCode = 0;
        dexPath = _dexList;
        pairs = _pairs;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );

        if(profit > 0){
        IERC20(_token).transfer(MetabankController, profit);
        IController.ProfitParams memory _params = IController.ProfitParams(_token, msg.sender, profit, profitinUSD,borrowedAmountinUSD);
        IController(MetabankController).transferProfit(_params);
        }
    }

    function verifySign(
        address account,
        address bToken,
        uint256 amount,
        Sign memory sign
    ) internal  {
        bytes32 hash = keccak256(
            abi.encodePacked(this, account, bToken, amount,sign.nonce)
        );

        require(
            !isValidSign[hash],
            "Duplicate Sign"
        );

        isValidSign[hash] = true;

        require(
            signController ==
                ecrecover(
                    keccak256(
                        abi.encodePacked(
                            "\x19Ethereum Signed Message:\n32",
                            hash
                        )
                    ),
                    sign.v,
                    sign.r,
                    sign.s
                ),
            "Signer sign verification failed"
        );

    }

    receive() external payable {}
}