// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import './deps/IERC20.sol';


contract FlashFi {

    // Initialization variables
    address private _pool_provider = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

    // Storage variables
    mapping(address => uint256) private _bals;
    mapping(address => bytes4) private _methods;
    
    // Setting supported dexes
    constructor() {
        _methods[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = bytes4(keccak256("univ2Router(bytes)"));
    }

    /* Dispatch flash loan transaction
    (notes will be added here)
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

        // Increment available balance for ERC20
        _bals[asset] += amount;
        
        // Ensure balance consistency
        require(IERC20(asset).balanceOf(address(this)) == _bals[asset], "balance error.");
        
        // Store transaction debt
        uint256 debt = amount + premium;

        // Use address-specific method
        require(address(bytes20(params[12:32])) != address(0), "Unsupported target dex address.");
        (bool success, ) = address(this).call(
            abi.encodeWithSelector(
                _methods[address(bytes20(params[12:32]))], 
                abi.encode(params, debt)
            )
        );

        // this.call(_methods[target_dex]) + params

        /* To-do:
            1) Execute trade
            If successful: 
                2) Decrement _bals by amount
                3) Reobtain debt 
                    - Same token, same quantity
                4) Take 1% service fee of debt-deduced profit
            Else:
                2) Revert transaction
        */

        // Decrement available balance for ERC20
        _bals[asset] -= amount;
    

        // Return true denoting successful execution
        return true;
    }

    function univ2Router(
        bytes calldata params
    ) external returns (bool) {
        
        // Decode execution parameters
        (bytes memory trade_params, uint256 debt) = abi.decode(params, (bytes, uint256));

        // Decode trade parameters (currently placeholder)
        (address target_dex, address asset, uint256 amountIn) = abi.decode(trade_params, (address, address, uint256));

        // Obtaining asset decimal count
        ( , bytes memory decimals) = asset.call(
            abi.encode(
                "decimals()"
            )
        );
        // Calculate exponentiated amount in
        uint256 exp_amountIn = amountIn * 10 ** abi.decode(decimals, (uint256));
        
        // Pre-trade requisites
        require(IERC20(asset).transferFrom(msg.sender, address(this), exp_amountIn), 'transferFrom failed.');
        require(IERC20(asset).approve(target_dex, exp_amountIn), 'approve failed.');
    
        // Trade execution
        // _univ2.call(
        //     abi.encodeWithSignature(
        //         "swapExactTokensForTokens(uint,uint,address[],address,uint)",
        //         exp_amountIn, exp_amountOutMin, path, to, deadline
        //     )
        // );

        // Return true denoting successful execution
        return true;
    }
}