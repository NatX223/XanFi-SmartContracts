// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "openzeppelin-contracts/access/Ownable.sol";

interface IFund {
    function sale(uint256 userSupply, uint256 fundTotalSupply, address tokenAddress, address receiver, address _outputTokenHomeAddress, uint16 sourceChainId) external;
}

contract Router is IWormholeReceiver, Ownable {
    uint256 constant GAS_LIMIT = 300_000;
    IWormholeRelayer public immutable wormholeRelayer;

    uint16 public chainId;

    mapping (uint16 => address) public routerAddresses;
    mapping (address => uint256) public prices;

    constructor(address _wormholeRelayer, uint16 _chainId) Ownable(msg.sender) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        chainId = _chainId;
    }

    function addRouterAddress(uint16 _chainId, address routerAddress) public onlyOwner() {
        routerAddresses[_chainId] = routerAddress;
    }

    function quoteCrossChainMessage(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function crossChainRedeem(uint256 _totalSupply, address _targetIndex, uint256 amount, address _assetContract, uint16 targetChain, address receiver, address purchaseToken) public payable {
        uint256 cost = quoteCrossChainMessage(targetChain);
        require(msg.value == cost, "not enough gas");
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            routerAddresses[targetChain],
            abi.encode(_totalSupply, _assetContract, amount, _targetIndex, receiver, purchaseToken, chainId), // payload
            0,
            GAS_LIMIT
        );
    }

    function receiveWormholeMessages(bytes memory payload, bytes[] memory, bytes32, uint16 sourceChain, bytes32) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        // Parse the payload and do the corresponding actions!
        (uint256 totalSupply, address assetContract, uint256 userSupply, address targetIndex, address receiver, address outputTokenHomeAddress, uint16 sourceChainId) = abi.decode(
            payload,
            (uint256, address, uint256, address, address, address, uint16)
        );
        IFund(targetIndex).sale(userSupply, totalSupply, assetContract, receiver, outputTokenHomeAddress, sourceChainId);
    }

    function updatePrice(address fundAddress, uint256 price) external onlyOwner() {
        prices[fundAddress] = price;
    }

    function getPrice(address fundAddress) public view returns(uint256) {
        return prices[fundAddress];
    }
}