// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './deps/IERC20.sol';


contract FlashFi {

    // Initialization variables
    address private _pool_provider = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

    // Storage variables
    mapping(address => bytes4) private _methods;
    
    // Setting supported dexes
    constructor() {
        _methods[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = bytes4(keccak256("univ2Router(bytes)"));
        _methods[0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F] = bytes4(keccak256("univ2Router(bytes)"));
    }

    /* Initiate flash loan backed trade.
    Asset:
        Address of desired ERC20.
    Amount:
        uint256 denoting desired ERC20 quantity.
    Params:
        ABI encoded, variable length byte array containing trade parameters.
            * First 32 bytes must be (padded) target dex address
            * Remainder must be specific to router function parameters
    */
    function flashTrade (
        address asset, 
        uint256 amount, 
        bytes calldata params
    ) external returns (bool) {

        // Execute flash loan
        ( , bytes memory _pool) = _pool_provider.call(abi.encode("getLendingPool()"));
        (bool success, ) = abi.decode(_pool, (address)).call(
            abi.encodeWithSignature(
                "flashLoanSimple(address,address,uint256,bytes,uint16)",
                 address(this), asset, amount, params, 0
            )
        );

        // Require successful execution
        require(success, "Transaction failed.");

        // Return true denoting successful execution
        return true;
    }

    // Function called by Aave Pool contract
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        // address initiator,
        bytes calldata params
    ) external returns (bool) {
        
        // Ensure balance consistency
        require(IERC20(asset).balanceOf(address(this)) >= amount, "ERC20 balance error.");
        
        // Store transaction debt
        uint256 debt = amount + premium;

        // Use address-specific method
        require(_methods[address(bytes20(params[12:32]))] != bytes4(0x0), "Unsupported target dex address.");
        (bool success, ) = address(this).call(
            abi.encodeWithSelector(
                _methods[address(bytes20(params[12:32]))], 
                params
            )
        );

        // Ensure trade completion
        require(success, "Trade failed.");

        /* To-do:
            1) Execute trade
            If successful: 
                2) Reobtain debt 
                    * Same token, same quantity
                3) Take 1% service fee of debt-deduced profit
            Else:
                2) Revert transaction
        */
    
        // Return true denoting successful execution
        return true;
    }

    function univ2Router(
        bytes calldata params
    ) external returns (bool) {
        
        // Decode trade parameters (currently placeholder)
        (
            address target_dex, 
            uint256 amountIn,
            uint256 amountOutMin,
            address[] memory assets,
            uint256 deadline
        ) = abi.decode(params, (address, uint256, uint256, address[], uint256));

        // Obtaining asset decimal count
        (, bytes memory encoded_decimals) = assets[0].call(
            abi.encode(
                "decimals()"
            )
        );
        uint256 decimals = abi.decode(encoded_decimals, (uint256));

        // Calculate exponentiated amount in
        uint256 exp_amountIn = amountIn * 10 ** decimals;
        uint256 exp_amountOutMin = amountOutMin * 10 ** decimals;

        // Pre-trade requisites
        require(IERC20(assets[0]).approve(target_dex, exp_amountIn), 'approve failed.');
    
        // Trade execution
        (bool success, ) = target_dex.call(
            abi.encodeWithSignature(
                "swapExactTokensForTokens(uint,uint,address[],address,uint)",
                exp_amountIn, exp_amountOutMin, assets, address(this), deadline
            )
        );

        // Return true denoting successful execution
        return true;
    }

    function oneinchBuyBack() external pure returns (bool) {

        // Return true denoting successful execution
        return true;
    }
}
