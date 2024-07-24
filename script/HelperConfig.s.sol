// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { ERC20Mock } from "../src/mocks/MockERC.sol";
import { MockWETH } from "../src/mocks/MockWETH.sol";
import { MockPoolAddressesProvider } from "../src/mocks/MockPoolAddrProvider.sol";

contract HelperConfig {

    struct Params {
        address USDT;
        address WETH;
        address POOL_ADDRESSES;
        address USER;
    }

    Params public networkConfig;


    constructor() {
        if(block.chainid == 1) {
           networkConfig =  mainnet();
        } else if(block.chainid == 137) {
            networkConfig = polygon();
        } else if(block.chainid == 11155111) {
            networkConfig = sepolia();
        } else if(block.chainid == 31337) {
            networkConfig = anvil();
        }
    }

    function polygon() public returns(Params memory) {
         Params memory params = Params({
            USDT: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F, // actually USDT
            WETH: 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            POOL_ADDRESSES: 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb,
            USER: 0x4D8336bDa6C11BD2a805C291Ec719BaeDD10AcB9
        });
        
        return params;  
    }


    function sepolia() public returns(Params memory) {
        // polygon mumbai 0x4CeDCB57Af02293231BAA9D39354D6BFDFD251e0
        Params memory params = Params({
            USDT: 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0,
            WETH: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            POOL_ADDRESSES: 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A,
            // 0x16590fC840c195742d61DD160C19F3825E820c59 WHALE
            USER: 0xb1B83bC9d243C23b3e884C1cd3F5415e0E484423
        });

        return params;
    }

    function anvil() public returns(Params memory) {
        ERC20Mock mockErc20 = new ERC20Mock();
        MockWETH mockWeth = new MockWETH();
        MockPoolAddressesProvider mockPoolAddressProvider = new MockPoolAddressesProvider(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        Params memory params = Params({
            USDT: address(mockErc20),
            WETH: address(mockWeth),
            POOL_ADDRESSES: address(mockPoolAddressProvider),
            USER: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });

        return params;
    }

    function mainnet() public returns(Params memory) {
        Params memory params = Params({
            USDT: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            POOL_ADDRESSES: 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e,
            USER: 0x70213959A644BaA94840bbfb4129550bceCEB3c2
        });

        return params;
    }

}