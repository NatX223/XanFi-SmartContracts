// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "openzeppelin-contracts/access/Ownable.sol";

    /**
     * @title IFund
     * @notice Interface for the Index Fund, defining a function that facilitates the sale of fund shares.
     * @dev This interface can be implemented by contracts that need to handle token sales or liquidations within the fund.
     */
    interface IFund {

        /**
         * @notice Handles the sale of a specified amount of the fund's assets.
         * @param amount The amount of the fund's assets to be sold.
         * @param fundTotalSupply The total supply of the fund's tokens.
         * @param tokenAddress The address of the ERC20 token that is being sold.
         * @param receiver The address that will receive the proceeds from the sale.
         * @param _outputTokenHomeAddress The address of the output token on the source chain (used for cross-chain transactions).
         * @param sourceChainId The chain ID of the source blockchain where the transaction originates.
         * @dev This function is intended to facilitate the liquidation or sale of fund assets, taking into account cross-chain operations if needed.
         */
        function sale(
            uint256 amount, 
            uint256 fundTotalSupply, 
            address tokenAddress, 
            address receiver, 
            address _outputTokenHomeAddress, 
            uint16 sourceChainId
        ) external;
    }


/**
 * @title Router
 * @notice This contract is responsible for handling cross-chain messages and managing ownership for operations involving the Wormhole protocol.
 * @dev Inherits from the `IWormholeReceiver` interface and `Ownable` contract.
 *      The `IWormholeReceiver` interface allows the contract to receive messages from other blockchains using the Wormhole protocol.
 *      The `Ownable` contract provides access control, ensuring that certain functions can only be executed by the contract owner.
 */
contract Router is IWormholeReceiver, Ownable {

    /**
     * @notice The fixed gas limit used for cross-chain message delivery via the Wormhole relayer.
     * @dev This constant determines the maximum gas available for executing the cross-chain payload.
     */
    uint256 constant GAS_LIMIT = 300_000;

    /**
     * @notice The Wormhole Relayer contract interface, used to send and receive messages across different blockchains.
     * @dev This variable is immutable and is set once during contract deployment.
     */
    IWormholeRelayer public immutable wormholeRelayer;

    /**
     * @notice The chain ID representing the current blockchain network where this contract is deployed.
     * @dev This ID is used to distinguish between different blockchain networks in a cross-chain setup.
     */
    uint16 public chainId;

    /**
     * @notice A mapping of chain IDs to the corresponding router contract addresses on other blockchains.
     * @dev This is used to route cross-chain messages to the appropriate contract address on a specific blockchain.
     */
    mapping (uint16 => address) public routerAddresses;

    /**
     * @notice A mapping of token addresses to their respective prices.
     * @dev This mapping stores the price of each token, which can be used for operations such as cross-chain swaps, conversions, or other financial calculations.
     */
    mapping (address => uint256) public prices;

    /**
     * @notice Initializes the Router contract with the specified Wormhole Relayer and chain ID.
     * @param _wormholeRelayer The address of the Wormhole Relayer contract responsible for cross-chain communication.
     * @param _chainId The chain ID representing the blockchain network where this Router contract is deployed.
     * @dev The constructor sets the Wormhole Relayer contract address and the chain ID. It also passes the deployer's address as the owner to the `Ownable` contract.
     */
    constructor(address _wormholeRelayer, uint16 _chainId) Ownable(msg.sender) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        chainId = _chainId;
    }

    /**
     * @notice Adds or updates the router contract address for a specific chain ID.
     * @param _chainId The chain ID of the blockchain network where the router contract is deployed.
     * @param routerAddress The address of the router contract on the specified chain.
     * @dev This function allows the owner to map a chain ID to its corresponding router address. This is essential for routing cross-chain messages to the correct destination.
     *      Only the contract owner can call this function.
     */
    function addRouterAddress(uint16 _chainId, address routerAddress) public onlyOwner {
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

    /**
     * @notice Sends a cross-chain message to redeem assets on a target chain's index fund.
     * @param _totalSupply The total supply of the fund's tokens.
     * @param _targetIndex The address of the target index fund on the destination chain.
     * @param amount The amount of assets to be redeemed.
     * @param _assetContract The address of the asset's contract being redeemed.
     * @param targetChain The chain ID of the target blockchain where the assets will be redeemed.
     * @param receiver The address that will receive the redeemed assets.
     * @param purchaseToken The address of the purchase token being used for the redemption.
     * @dev This function sends a payload to the target chain's router using the Wormhole relayer. The payload includes information about the redemption request, which is processed on the target chain.
     *      The caller must provide enough gas to cover the cross-chain message delivery.
     */
    function crossChainRedeem(
        uint256 _totalSupply, 
        address _targetIndex, 
        uint256 amount, 
        address _assetContract, 
        uint16 targetChain, 
        address receiver, 
        address purchaseToken
    ) public payable {
        uint256 cost = quoteCrossChainMessage(targetChain);
        require(msg.value >= cost, "not enough gas");
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            routerAddresses[targetChain],
            abi.encode(_totalSupply, _assetContract, amount, _targetIndex, receiver, purchaseToken, chainId), // payload
            0,
            GAS_LIMIT
        );
    }

    /**
     * @notice Receives and processes cross-chain messages delivered by the Wormhole relayer.
     * @param payload The encoded data sent from another blockchain.
     * @param additionalVaas Additional verification data from the Wormhole relayer (not used here).
     * @param senderAddress The address that initiated the cross-chain message (not used here).
     * @param sourceChain The chain ID of the blockchain where the message originated.
     * @param deliveryId The unique identifier for the message delivery (not used here).
     * @dev This function decodes the received payload and triggers the `sale` function on the target index fund contract, enabling the cross-chain redemption of assets.
     *      The Wormhole relayer is the only entity allowed to call this function.
     */
    function receiveWormholeMessages(
        bytes memory payload, 
        bytes[] memory additionalVaas, 
        bytes32 senderAddress, 
        uint16 sourceChain, 
        bytes32 deliveryId
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        // Parse the payload and execute the corresponding actions
        (uint256 totalSupply, address assetContract, uint256 amount, address targetIndex, address receiver, address outputTokenHomeAddress, uint16 sourceChainId) = abi.decode(
            payload,
            (uint256, address, uint256, address, address, address, uint16)
        );
        IFund(targetIndex).sale(amount, totalSupply, assetContract, receiver, outputTokenHomeAddress, sourceChainId);
    }

    /**
     * @notice Updates the price of a specific fund's token.
     * @param fundAddress The address of the fund whose token price is being updated.
     * @param price The new price of the fund's token.
     * @dev Only the contract owner can call this function. This is useful for keeping token prices in sync across the platform.
     */
    function updatePrice(address fundAddress, uint256 price) external onlyOwner {
        prices[fundAddress] = price;
    }

    /**
     * @notice Retrieves the price of a specific fund's token.
     * @param fundAddress The address of the fund.
     * @return The current price of the fund's token.
     * @dev This function provides a public view of the prices stored in the `prices` mapping.
     */
    function getPrice(address fundAddress) public view returns(uint256) {
        return prices[fundAddress];
    }

}