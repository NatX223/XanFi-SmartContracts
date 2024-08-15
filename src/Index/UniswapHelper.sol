// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;
pragma abicoder v2;

interface IDexHelper {
    function buyAsset (address _assetToken, uint _amount, address _receiver, address purchaseToken) external returns(uint);
    function sellAsset (address _assetToken, uint _amount, address _receiver, address outputToken) external returns(uint);
} 

interface IERC {
    function approve(address spender, uint256 value) external returns (bool);
}

contract UniswapHelper {
    address public helperAddress;
    IDexHelper public tradeHelper;

    constructor (address _helperAddress) {
        helperAddress = _helperAddress;
        tradeHelper = IDexHelper(_helperAddress);
    }

    // the buyAsset function follows the swapexactinput example from uniswap documentation 
    function buyToken (
        // the token the user is buying
        address _assetToken,
        // the amount the user intends to buy
        uint _amount,
        // the receivers address i.e the smart contract address
        address _receiver,
        address purchaseToken
    ) public returns(uint amountOut) {
        IERC token = IERC(purchaseToken);
        token.approve(helperAddress, _amount);
        amountOut = tradeHelper.buyAsset(_assetToken, _amount, _receiver, purchaseToken);
    }

    function sellToken (
        // the token the user is selling
        address _assetToken,
        // the amount the user intends to buy
        uint _amount,
        // the receivers address i.e the smart contract address
        address _receiver,
        address outputToken
    ) public returns(uint amountOut) {
        IERC token = IERC(_assetToken);
        token.approve(helperAddress, _amount);
        amountOut = tradeHelper.sellAsset(_assetToken, _amount, _receiver, outputToken);
    }

}