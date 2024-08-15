// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Index/IndexFund.sol";
import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

contract IndexFactory is Ownable {
    uint16 chainId;
    uint256 constant GAS_LIMIT = 250_000;
    IWormholeRelayer public immutable wormholeRelayer;

    address helperAddress;
    address routerAddress;
    address tokenBridgeAddress;
    address wormholeAddress;
    address wormholeRelayerAddress;
    address _purchaseToken;

    using Counters for Counters.Counter; // OpenZeppelin Counter
    Counters.Counter public _indexCount; // Counter for indecies created

    event IndexCreated(address deployer, address indexAddress, string name);
    event IndexDeployed(address deployer, address indexAddress, string name);

    struct Index {
        address deployer;
        address indexAddress;
        string name;
    }

    mapping(uint256 => Index) indicies;

    struct Chain {
        uint16 chainId;
        address factoryAddress;
    }

    Chain[] public chains;

    constructor(address _tokenBridge, address _wormhole, address _wormholeRelayer, address purchaseToken_, uint16 _chainId, address _helperAddress, address _routerAddress) Ownable(msg.sender) {
        tokenBridgeAddress = _tokenBridge;
        wormholeAddress = _wormhole;
        wormholeRelayerAddress = _wormholeRelayer;
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        chainId = _chainId;
        _purchaseToken = purchaseToken_;
        helperAddress = _helperAddress;
        routerAddress = _routerAddress;
    }

    function quoteCrossChainDeployment(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function setChain(uint16 _chainId, address _factoryAddress) public onlyOwner() {
        Chain memory newChain = Chain({
            chainId: _chainId,
            factoryAddress: _factoryAddress
        });

        chains.push(newChain);
    }

    function createIndex(string memory _name, string memory _symbol, address _owner, address[] memory _assetContracts, uint[] memory _assetRatio, uint16[] memory _assetChains) public payable {
        address indexAddress = deployIndex(_name, _symbol, msg.sender, _assetContracts, _assetRatio, _assetChains);
        uint256 cost = msg.value / chains.length;
        for (uint i = 0; i < chains.length; i++) {
            // send info to all chains
            crossChainDeployment(chains[i].chainId, chains[i].factoryAddress, _name, _symbol, _owner, _assetContracts, _assetRatio, _assetChains);
        }
        emit IndexCreated(msg.sender, indexAddress, _name);
    }

    function deployIndex(string memory _name, string memory _symbol, address _owner, address[] memory _assetContracts, uint[] memory _assetRatio, uint16[] memory _assetChains) internal returns(address indexAddress) {
        IndexFund newIndex = new IndexFund(_name, _symbol, wormholeRelayerAddress, tokenBridgeAddress, wormholeAddress, _owner, helperAddress);
        newIndex.initializeIndex(_assetContracts, _assetRatio, _assetChains, chainId, routerAddress);
        indicies[_indexCount.current()].deployer = _owner;
        indicies[_indexCount.current()].indexAddress = address(newIndex);
        indicies[_indexCount.current()].name = _name;
        _indexCount.increment();
        indexAddress = address(newIndex);
        emit IndexDeployed(msg.sender, address(newIndex), _name);
    }

    function crossChainDeployment(
        uint16 targetChain,
        address targetAddress,
        string memory name,
        string memory symbol,
        address _owner,
        address[] memory _assetContracts, 
        uint[] memory _assetRatio, 
        uint16[] memory _assetChains
    ) public payable {
        uint256 cost = quoteCrossChainDeployment(targetChain);
        // require(msg.value == cost, "not enough gas");
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(name, symbol, _owner, _assetContracts, _assetRatio, _assetChains), // payload
            0,
            GAS_LIMIT
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32, // address that called 'sendPayloadToEvm' (HelloWormhole contract address)
        uint16 sourceChain,
        bytes32 // unique identifier of delivery
    ) public payable {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        // Parse the payload and do the corresponding actions!
        (string memory name, string memory symbol, address _owner, address[] memory _assetContracts, uint[] memory _assetRatio, uint16[] memory _assetChains) = abi.decode(
            payload,
            (string, string, address, address[], uint[], uint16[])
        );
        deployIndex(name, symbol, _owner, _assetContracts, _assetRatio, _assetChains);
    }

    function purchaseToken() public view returns(address) {
        return _purchaseToken;
    }

    function tokenBridge() public view returns(address) {
        return tokenBridgeAddress;
    }
}