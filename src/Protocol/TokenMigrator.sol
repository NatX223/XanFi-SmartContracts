// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "openzeppelin-contracts/access/Ownable.sol";

    /**
     * @title IFund
     * @notice Interface for the Index Fund, defining a function that facilitates the migration of fund tokens from one chain to another.
     * @dev This interface can be implemented by contracts that need to handle token mints within the fund.
     */
    interface IFund {

    /**
     * @notice Handles the migration of a specified amount of a holders fund's tokens.
     * @param holder The address of the holder initiating the migrration.
     * @param amount The amount of the fund's assets to be sold.
     * @dev This function is intended to facilitate the liquidation or sale of fund assets.
     *      It is an external function and can be called by authorized parties(the token migrator).
     */
    function migrateMint(
        address holder, 
        uint256 amount
    ) external;
    }

/**
 * @title TokenMigrator
 * @notice This contract is responsible for handling cross-chain migration of index tokens.
 * @dev Inherits from the `IWormholeReceiver` interface and `Ownable` contract.
 *      The `IWormholeReceiver` interface allows the contract to receive messages from other blockchains using the Wormhole protocol.
 *      The `Ownable` contract provides access control, ensuring that certain functions can only be executed by the contract owner.
 */
contract TokenMigrator is IWormholeReceiver, Ownable {
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
     * @notice A mapping of chain IDs to the corresponding token migrator contract addresses on other blockchains.
     * @dev This is used to route cross-chain messages to the appropriate contract address on a specific blockchain.
     */
    mapping (uint16 => address) public migratorAddresses;

    /**
     * @notice Initializes the tokenMigrator contract with the specified Wormhole Relayer and chain ID.
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
     * @param migratorAddress The address of the token migrator contract on the specified chain.
     * @dev This function allows the owner to map a chain ID to its corresponding token migrator address.
     *      Only the contract owner can call this function.
     */
    function addMigratorAddress(uint16 _chainId, address migratorAddress) public onlyOwner {
        migratorAddresses[_chainId] = migratorAddress;
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
     * @notice Sends a cross-chain message to initiate a token migration to a target chain's index fund.
     * @param holder The address of the holder initiating the token migration.
     * @param amount The amount of tokens to be migrated.
     * @param targetIndex The address of the index contract on the destination chain the tokens are to be migrated to.
     * @param targetChain The destination chain.
     * @dev This function is called from an index contract when a token migration is initialized. 
     *      It uses the Wormhole relayer to send a cross-chain message to the target chain's router, 
     *      including the necessary payload with details of the migration request.
     *      The caller must provide sufficient gas to cover the cross-chain message delivery cost.
     *      The cost is calculated using `quoteCrossChainMessage`, and the transaction reverts if 
     *      the provided gas amount is insufficient.
     * @notice Ensure that the target chain, router addresses, and GAS_LIMIT are properly configured.
     */
    function migrateToken(
        address holder,
        uint256 amount,
        address targetIndex,
        uint16 targetChain
    ) public payable {
        uint256 cost = quoteCrossChainMessage(targetChain);
        require(msg.value >= cost, "not enough gas");
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            migratorAddresses[targetChain],
            abi.encode(holder, amount, targetIndex), // payload
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
     * @dev This function decodes the received payload and triggers the `migrateMint` function on the target index fund contract, enabling the cross-chain migration of index tokens.
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
        (address holder, uint256 amount,  address targetIndex) = abi.decode(
            payload,
            (address, uint256, address)
        );
        IFund(targetIndex).migrateMint(holder, amount);
    }
}