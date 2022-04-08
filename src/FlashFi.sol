// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import './deps/IERC20.sol';


contract FlashFi {

    // Initialization variables
    address private _pool_provider = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

    // Storage variables
    mapping(address => uint256) private _bals;

    // Dispatch flash loan transaction
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

        // Increment available balance for ERC20
        _bals[asset] += amount;

        return true;
    }

    // Function called by Aave Pool contract
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {

        // Ensure balance consistency
        require(IERC20(asset).balanceOf(address(this)) == _bals[asset], "Balance error.");
        
        // Store transaction debt
        uint256 debt = amount + premium;

        // Decode parameter data (placeholder)
        (uint8 decoded, uint8 also_decoded) = abi.decode(params, (uint8, uint8));

        /* To-do:
            1) Execute trade
            If successful: 
                2) Decrement _bals by amount
                3) Reobtain debt 
                    - Same token, same quantity (right?)
                4) Take 1% service fee of debt-deduced profit
            Else:
                2) Revert transaction
        */

        // Decrement available balance for ERC20
        _bals[asset] -= amount;
    
        return true;
    }  

}
