// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Index/IndexFund.sol";
import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

/**
 * @title IndexFactory
 * @notice This contract serves as a factory for deploying index fund contracts. It provides functionality to
 *         create and manage index funds.
 * @dev The IndexFactory contract itself is owned and managed by a single owner using the Ownable pattern.
 */
contract IndexFactory is Ownable {
    /**
     * @notice The chain ID representing the blockchain network where this contract is deployed.
     */
    uint16 chainId;

    /**
     * @notice The constant gas limit used for cross-chain operations when interacting with the Wormhole protocol.
     */
    uint256 constant GAS_LIMIT = 500_000;

    /**
     * @notice The Wormhole relayer contract responsible for handling cross-chain communication and relaying messages or transactions.
     */
    IWormholeRelayer public immutable wormholeRelayer;

    /**
     * @notice Address of the Dex router that is used when deploying the index fund contract.
     */
    address dexRouterAddress;

    /**
     * @notice Address of the protocol router contract used for performing cross-chain sale functions.
     */
    address routerAddress;

    /**
     * @notice Address of the Token Bridge contract used for transferring tokens across different blockchain networks via the Wormhole protocol.
     */
    address tokenBridgeAddress;

    /**
     * @notice Address of the Wormhole core contract used for cross-chain communication and managing messages between chains.
     */
    address wormholeAddress;

    /**
     * @notice Address of the Wormhole relayer contract used for forwarding messages and transactions across chains.
     */
    address wormholeRelayerAddress;

    /**
     * @notice Address of the ERC20 token used as the purchase or payment token within the index fund or related operations.
     */
    address _purchaseToken;


    /**
     * @notice Event emitted when the contract receives ETH. Logs the sender's address and the received amount.
     * @param sender The address that sent the ETH.
     * @param amount The amount of ETH received.
     */
    event Received(address sender, uint amount);

    /**
     * @notice A special function to handle ETH transfers sent directly to the contract.
     *         Emits the Received event when ETH is received.
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @notice Structure representing the properties of an index fund.
     * @param name The name of the index fund.
     * @param symbol The symbol representing the index fund (e.g., a ticker).
     * @param owner The address of the owner/creator of the index fund.
     * @param assetContracts The list of addresses for the ERC20 contracts that make up the assets of the fund.
     * @param assetRatio The allocation ratio for each asset in the fund (e.g., percentage of total assets).
     * @param assetChains The chain IDs representing the blockchain networks where each asset is located.
     */
    struct fund {
        string name;
        string symbol;
        address owner;
        address[] assetContracts;
        uint[] assetRatio;
        uint16[] assetChains;
    }

    /**
     * @notice Utilizing OpenZeppelin's Counters library for managing counters, which includes functions like increment, decrement, and reset.
     */
    using Counters for Counters.Counter; // OpenZeppelin Counter

    /**
     * @notice Counter for tracking the number of index funds created.
     */
    Counters.Counter public _indexCount;

    /**
     * @notice Counter for tracking the number of funds created (if separate from index funds).
     */
    Counters.Counter public _fundCount;

    /**
     * @notice Mapping to store details of each fund based on its unique ID.
     * @dev The key is a unique identifier for each fund, and the value is the `fund` struct containing all relevant fund information.
     */
    mapping (uint256 => fund) public funds;

    /**
     * @notice Event emitted when a new index is created.
     * @param deployer The address of the user who created the index.
     * @param indexAddress The address of the deployed index contract.
     * @param name The name of the index fund.
     */
    event IndexCreated(address deployer, address indexAddress, string name);

    /**
     * @notice Event emitted when an index is deployed.
     * @param deployer The address of the user who deployed the index.
     * @param indexAddress The address of the deployed index contract.
     * @param name The name of the index fund.
     */
    event IndexDeployed(address deployer, address indexAddress, string name);

    /**
     * @notice Mapping to store the address of each index contract based on its unique ID.
     * @dev The key is a unique identifier for each index, and the value is the address of the deployed index contract.
     */
    mapping(uint256 => address) public indicies;

    /**
     * @notice Structure representing a blockchain network where index funds can be deployed.
     * @param chainId The ID of the blockchain network.
     * @param factoryAddress The address of the factory contract on that specific chain.
     */
    struct Chain {
        uint16 chainId;
        address factoryAddress;
    }

    /**
     * @notice Array of supported blockchain networks where index funds can be deployed.
     * @dev Each element in the array is a `Chain` struct, storing the chain ID and corresponding factory address.
     */
    Chain[] public chains;

    /**
     * @notice Constructor for initializing the IndexFactory contract with necessary addresses and configurations.
     * @param _tokenBridge The address of the Token Bridge contract used for cross-chain token transfers.
     * @param _wormhole The address of the Wormhole core contract used for cross-chain communication.
     * @param _wormholeRelayer The address of the Wormhole relayer contract used for relaying messages across chains.
     * @param purchaseToken_ The address of the ERC20 token to be used as the primary purchase or payment token within the index funds.
     * @param _chainId The chain ID representing the blockchain network where this contract is deployed.
     * @param _dexRouterAddress The address of the decentralized exchange (DEX) router used for swapping tokens within the index fund.
     * @param _routerAddress The address of an additional router contract used for token management or other operations.
     * @dev The constructor sets the contract owner using the Ownable pattern. It also initializes several key addresses and parameters 
     *      related to cross-chain communication, token management, and index fund operations.
     */
    constructor(
        address _tokenBridge, 
        address _wormhole, 
        address _wormholeRelayer, 
        address purchaseToken_, 
        uint16 _chainId, 
        address _dexRouterAddress, 
        address _routerAddress
    ) Ownable(msg.sender) {
        tokenBridgeAddress = _tokenBridge;
        wormholeAddress = _wormhole;
        wormholeRelayerAddress = _wormholeRelayer;
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        chainId = _chainId;
        _purchaseToken = purchaseToken_;
        dexRouterAddress = _dexRouterAddress;
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

    /**
     * @notice Adds a new supported blockchain network to the list of chains where index funds can be deployed.
     * @param _chainId The chain ID representing the blockchain network.
     * @param _factoryAddress The address of the factory contract on that specific chain.
     * @dev Only the contract owner can call this function. The new chain is stored in the `chains` array.
     */
    function setChain(uint16 _chainId, address _factoryAddress) public onlyOwner {
        Chain memory newChain = Chain({
            chainId: _chainId,
            factoryAddress: _factoryAddress
        });

        chains.push(newChain);
    }

    /**
     * @notice Creates a new index fund by deploying an index contract and initiating cross-chain deployments.
     * @param _name The name of the index fund.
     * @param _symbol The symbol representing the index fund (e.g., a ticker).
     * @param _owner The address of the owner/creator of the index fund.
     * @param _assetContracts An array of addresses for the ERC20 contracts that make up the assets of the fund.
     * @param _assetRatio An array of ratios defining the allocation of each asset in the fund.
     * @param _assetChains An array of chain IDs representing the blockchain networks where each asset is located.
     * @dev The function deploys the index fund on the current chain and then triggers cross-chain deployments to all supported chains.
     *      The deployment cost is divided among all the supported chains, and the deployment details are sent to each chain via `crossChainDeployment`.
     *      An `IndexCreated` event is emitted once the index is successfully created.
     */
    function createIndex(
        string memory _name, 
        string memory _symbol, 
        address _owner, 
        address[] memory _assetContracts, 
        uint[] memory _assetRatio, 
        uint16[] memory _assetChains
    ) public payable {
        address indexAddress = deployIndex(_name, _symbol, msg.sender, _assetContracts, _assetRatio, _assetChains);
        uint256 cost = msg.value / chains.length;

        for (uint i = 0; i < chains.length; i++) {
            // Send index deployment information to all supported chains
            crossChainDeployment(
                chains[i].chainId, 
                chains[i].factoryAddress, 
                _name, 
                _symbol, 
                _owner, 
                _assetContracts, 
                _assetRatio, 
                _assetChains
            );
        }

        emit IndexCreated(msg.sender, indexAddress, _name);
    }


    /**
     * @notice Deploys a new index fund contract and initializes it with the provided assets and configurations.
     * @param _name The name of the index fund.
     * @param _symbol The symbol representing the index fund (e.g., a ticker).
     * @param _owner The address of the owner/creator of the index fund.
     * @param _assetContracts An array of addresses for the ERC20 contracts that make up the assets of the fund.
     * @param _assetRatio An array of ratios defining the allocation of each asset in the fund.
     * @param _assetChains An array of chain IDs representing the blockchain networks where each asset is located.
     * @return indexAddress The address of the deployed index fund contract.
     * @dev This function is marked as `internal` and can only be called within the contract. It initializes the index fund using the
     *      provided details and stores it in the `indicies` mapping. An `IndexDeployed` event is emitted once the index is successfully deployed.
     */
    function deployIndex(
        string memory _name, 
        string memory _symbol, 
        address _owner, 
        address[] memory _assetContracts, 
        uint[] memory _assetRatio, 
        uint16[] memory _assetChains
    ) internal returns(address indexAddress) {
        IndexFund newIndex = new IndexFund(_name, _symbol, wormholeRelayerAddress, tokenBridgeAddress, wormholeAddress, _owner, dexRouterAddress, address(this));
        newIndex.initializeIndex(_assetContracts, _assetRatio, _assetChains, chainId, routerAddress);
        indicies[_indexCount.current()] = address(newIndex);
        _indexCount.increment();
        indexAddress = address(newIndex);
        emit IndexDeployed(msg.sender, address(newIndex), _name);
    }

    /**
     * @notice Facilitates cross-chain deployment by sending the index fund details to a target chain.
     * @param targetChain The chain ID of the target blockchain network.
     * @param targetAddress The address of the factory contract on the target chain where the deployment details will be sent.
     * @param name The name of the index fund.
     * @param symbol The symbol representing the index fund (e.g., a ticker).
     * @param _owner The address of the owner/creator of the index fund.
     * @param _assetContracts An array of addresses for the ERC20 contracts that make up the assets of the fund.
     * @param _assetRatio An array of ratios defining the allocation of each asset in the fund.
     * @param _assetChains An array of chain IDs representing the blockchain networks where each asset is located.
     * @dev This function encodes the index details into a payload and sends it to the target chain using the Wormhole Relayer.
     *      The gas cost for the cross-chain deployment is quoted and deducted from the contract’s balance.
     */
    function crossChainDeployment(
        uint16 targetChain,
        address targetAddress,
        string memory name,
        string memory symbol,
        address _owner,
        address[] memory _assetContracts,
        uint[] memory _assetRatio,
        uint16[] memory _assetChains
    ) internal {
        uint256 cost = quoteCrossChainDeployment(targetChain);
        require(address(this).balance > cost, "not enough gas");
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(name, symbol, _owner, _assetContracts, _assetRatio, _assetChains), // payload
            0,
            GAS_LIMIT
        );
    }

    /**
     * @notice Handles incoming messages from the Wormhole Relayer containing index fund deployment details.
     * @param payload The encoded payload containing the index fund details (name, symbol, owner, assets, etc.).
     * @param additionalVaas Not used in this implementation, but reserved for additional VAA data if needed.
     * @param sourceAddress The address of the contract that called `sendPayloadToEvm` on the source chain.
     * @param sourceChain The chain ID of the source blockchain network.
     * @param deliveryId A unique identifier for the message delivery.
     * @dev The function can only be called by the Wormhole Relayer. It decodes the payload, creates a new `fund` struct with the provided details,
     *      and stores it in the `funds` mapping. The `fundCount` counter is incremented to track the newly created fund.
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32, // address that called 'sendPayloadToEvm' (HelloWormhole contract address)
        uint16 sourceChain,
        bytes32 // unique identifier of delivery
    ) public payable {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        // Parse the payload and do the corresponding actions
        (string memory name, string memory symbol, address _owner, address[] memory assetContracts, uint[] memory assetRatio, uint16[] memory assetChains) = abi.decode(
            payload,
            (string, string, address, address[], uint[], uint16[])
        );
        fund memory newFund = fund({
            name: name,
            symbol: symbol,
            owner: _owner,
            assetContracts: assetContracts,
            assetRatio: assetRatio,
            assetChains: assetChains
        });

        funds[_fundCount.current()] = newFund;
        _fundCount.increment();
    }

    /**
     * @notice Returns the address of the primary purchase token used within the index funds.
     * @return The address of the ERC20 token used for purchases.
     * @dev This function provides a getter for the `_purchaseToken` variable.
     */
    function purchaseToken() public view returns(address) {
        return _purchaseToken;
    }

    /**
     * @notice Allows the contract owner to withdraw a specified amount of ETH from the contract.
     * @param amount The amount of ETH to be refunded to the owner.
     * @dev The function checks if the contract has enough balance before proceeding with the transfer. The transfer is made using the `call` method, and a `require` statement ensures that the transfer was successful.
     *      Only the contract owner can call this function.
     */
    function refund(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient contract balance");
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Returns the details of a specific fund based on its ID.
     * @param id The unique identifier of the fund.
     * @return A `fund` struct containing all the details of the specified fund, including its name, symbol, owner, assets, and allocations.
     * @dev This function allows users to retrieve information about a particular fund stored in the `funds` mapping.
     */
    function getFunds(uint256 id) public view returns(fund memory) {
        return funds[id];
    }

    /**
     * @notice Returns the address of the Token Bridge contract used for cross-chain token transfers.
     * @return The address of the Token Bridge contract.
     * @dev This function provides a getter for the `tokenBridgeAddress` variable.
     */
    function tokenBridge() public view returns(address) {
        return tokenBridgeAddress;
    }

}