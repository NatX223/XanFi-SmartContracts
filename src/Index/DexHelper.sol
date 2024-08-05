// // implement the following functions
// buyAsset
// sellAsset
// estimateAmountOut

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';

contract Uniswap {
    address public constant Router = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; // the router contract address
    address public constant factoryAdd = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

    ISwapRouter public constant swapRouter = ISwapRouter(Router);

    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant poolFee = 5000;

    // the buyAsset function follows the swapexactinput example from uniswap documentation 
    function buyAsset (
        // the token the user is buying
        address _assetToken,
        // the amount the user intends to buy
        uint _amount,
        // the receivers address i.e the smart contract address
        address _receiver,
        address purchaseToken
        ) public returns(uint amountOut) {
            // getting the amountoutminimum
            // uint amount = estimateAmountOut(_assetToken, _amount);
            // the price is actually to be calculated using an oracle
            TransferHelper.safeTransferFrom(purchaseToken, msg.sender, address(this), _amount);
            TransferHelper.safeApprove(purchaseToken, address(swapRouter), _amount);

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: purchaseToken,
                tokenOut: _assetToken,
                fee: poolFee,
                recipient: _receiver,
                deadline: block.timestamp + 10,
                amountIn: _amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap and gets the amount paid to the receiver.
        amountOut = swapRouter.exactInputSingle(params);   
    }

    // Uniswap price oracle for determining the equivalent amount to be paid
    // get the address of USDT for mumbai testnet
    function estimateAmountOut(address tokenOut, uint amountIn, address purchaseToken) internal view returns (uint amount) {
        uint32 secondsAgo = 2;
        address _pool = IUniswapV3Factory(factoryAdd).getPool(
            purchaseToken, tokenOut, poolFee
        );
        require(_pool != address(0), "pool for the token pair does not exist");
        address pool = _pool;
        (int24 tick, uint128 meanLiq) = OracleLibrary.consult(pool, secondsAgo);
        amount = OracleLibrary.getQuoteAtTick(
            tick, uint128(amountIn), purchaseToken, tokenOut
        );

        return amount;
    }

    // function estimateAmountOut(address tokenOut, uint amountIn, address purchaseToken) internal view returns (uint amount) {
    //     uint32 secondsAgo = 10; // Example value, adjust as needed
    //     address _pool = IUniswapV3Factory(factoryAdd).getPool(purchaseToken, tokenOut, poolFee);
    //     require(_pool != address(0), "pool for the token pair does not exist");
    //     address pool = _pool;
    //     (int24 tick, uint128 liquidity, , , , , ) = ISwapRouter(pool).slot0();
    //     amount = OracleLibrary.getQuoteAtTick(tick, uint128(amountIn), purchaseToken, tokenOut, liquidity, secondsAgo);
    //     return amount;
    // }


    function sellAsset (
        // the token the user is buying
        address _assetToken,
        // the amount the user intends to buy
        uint _amount,
        // the receivers address i.e the smart contract address
        address _receiver,
        address outputToken
        ) public returns(uint amountOut) {
            // getting the amountoutminimum
            // uint amount = estimateAmountOut(_assetToken, _amount);
            // the price is actually to be calculated using an oracle
            TransferHelper.safeApprove(_assetToken, address(swapRouter), _amount);

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _assetToken,
                tokenOut: outputToken,
                fee: poolFee,
                recipient: _receiver,
                deadline: block.timestamp + 10,
                amountIn: _amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap and gets the amount paid to the receiver.
        amountOut = swapRouter.exactInputSingle(params);  
    }

}