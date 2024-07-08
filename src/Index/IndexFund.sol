// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
pragma abicoder v2;

// importing the ERC20 token contract
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";
import "wormhole-solidity-sdk/interfaces/IERC20.sol";

contract IndexFund is TokenSender, TokenReceiver, ERC20 {
    
    constructor() {
        
    }
}