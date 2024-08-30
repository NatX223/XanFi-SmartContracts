// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
pragma abicoder v2;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

// Interface for the Token Bridge, which is responsible for handling cross-chain operations.
interface ITokenBridge {
    /**
     * @notice Returns the address of the wrapped asset for a given token on a specific chain.
     * @param tokenChainId The chain ID of the original token.
     * @param tokenAddress The address of the original token on its chain.
     * @return The address of the wrapped asset on the current chain.
     */
    function wrappedAsset(uint16 tokenChainId, bytes32 tokenAddress) external view returns (address);
}

// Interface for the Factory contract, which handles index fund contract creation.
interface IFactory {
    /**
     * @notice Returns the address of the token used for purchases (e.g., USDT).
     * @return The address of the purchase token contract.
     */
    function purchaseToken() external view returns (address);

    /**
     * @notice Returns the address of the token bridge contract used for cross-chain transfers.
     * @return The address of the token bridge contract.
     */
    function tokenBridge() external view returns (address);
}

// Interface for the Router contract, which manages cross-chain communication and asset swaps.
interface IRouter {
    /**
     * @notice Handles cross-chain redemption of index tokens.
     * @param _totalSupply The total supply of the index fund tokens.
     * @param _targetIndex The address of the target index on the destination chain.
     * @param amount The amount of index tokens to redeem.
     * @param _assetContract The address of the asset being redeemed.
     * @param targetChain The chain ID of the target chain.
     * @param receiver The address receiving the redeemed assets.
     * @param purchaseToken The address of the token used for the purchase.
     */
    function crossChainRedeem(
        uint256 _totalSupply,
        address _targetIndex,
        uint256 amount,
        address _assetContract,
        uint16 targetChain,
        address receiver,
        address purchaseToken
    ) external payable;

    /**
     * @notice Returns the current price of the index fund.
     * @param fundAddress The address of the index fund contract.
     * @return The price of the index fund.
     */
    function getPrice(address fundAddress) external view returns (uint256);
}

// Interface for the decentralized exchange (DEX) router used for asset swaps.
interface dexRouter {
    /**
     * @notice Swaps a specific amount of one token for another.
     * @param receiver The address receiving the output tokens.
     * @param amountIn The amount of the input token to swap.
     * @param tokenIn The ERC20 token being swapped.
     * @param tokenOut The ERC20 token to receive from the swap.
     */
    function swapExactTokens(
        address receiver,
        uint256 amountIn,
        IERC20 tokenIn,
        IERC20 tokenOut
    ) external;
}

// Interface for the token migrator contract used for migrating tokens across chains.
interface IMigrator {
    /**
     * @notice Initiates the migration of tokens from one chain to another.
     * @param holder The address of the token holder initiating the migration.
     * @param amount The amount of tokens to be migrated.
     * @param targetIndex The address of the target index contract on the destination chain.
     * @dev This function is intended to be called by contracts managing the token migration process.
     *      It facilitates the movement of tokens from the current chain to a specified index on the target chain.
     *      The implementation should handle the necessary cross-chain communication and ensure that 
     *      the tokens are properly credited to the `targetIndex` on the destination chain.
     */
    function migrateToken(
        address holder,
        uint256 amount,
        address targetIndex,
        uint16 targetChain
    ) external payable;
}

/**
 * @title IndexFund
 * @notice This contract represents an index fund and includes functionality for sending and receiving tokens,
 *         interacting with a Dex, and managing ERC20 tokens.
 * @dev Inherits from the TokenSender, TokenReceiver, ERC20 contracts.
 */
contract IndexFund is TokenSender, TokenReceiver, ERC20 {

    /**
     * @notice The ID of the chain on which this contract is deployed.
     */
    uint16 public chainId;

    /**
     * @notice The gas limit for cross-chain operations.
     * @dev This is a constant value set to 300,000.
     */
    uint256 constant GAS_LIMIT = 300_000;

    /**
     * @notice The Rceived event.
     * @dev This event is emitted anytime the contract receives native coins.
     */
    event Received(address sender, uint amount);

    /**
     * @notice The initial supply of tokens for the index fund.
     * @dev Set to 10,000 tokens multiplied by 10^8 to account for decimals.
     */
    uint initialSupply = 10000 * (10 ** 8);

    /**
     * @notice Indicates whether the initial minting of tokens has been performed.
     */
    bool public initialMint;

    /**
     * @notice The address of the contract owner.
     */
    address public owner;

    /**
     * @notice The total number of owners in the index fund.
     */
    uint256 public owners;

    /**
     * @notice The address of the factory contract associated with this index fund.
     */
    address public factoryAddress;

    /**
     * @notice The address of the router contract used for cross-chain operations.
     */
    address public routerAddress;

    /**
     * @notice The address of the token migrator contract used for cross-chain token migration.
     */
    address public tokenMigratorAddress;

    /**
     * @notice Address of the decentralized exchange (DEX) router used for asset swaps.
     * @dev This address points to the contract responsible for handling token swaps on a DEX.
     */
    address public dexRouterAddress;

    /**
     * @notice Indicates whether the contract has been initialized.
     */
    bool public initialized;

    /**
     * @notice The immutable address of the Wormhole Relayer contract.
     */
    IWormholeRelayer public immutable wormholeRelayer_;

    /**
     * @notice An array of addresses representing the underlying asset contracts in the index.
     */
    address[] public assetContracts;

    /**
     * @notice An array representing the allocation ratios of the underlying assets in the index.
     * @dev Each value corresponds to the respective asset in the `assetContracts` array.
     */
    uint[] public assetRatio;

    /**
     * @notice An array of chain IDs indicating the chains on which the underlying assets are deployed.
     * @dev Each value corresponds to the respective asset in the `assetContracts` array.
     */
    uint16[] public assetChains;

    /**
     * @notice Initializes the IndexFund contract with the provided parameters.
     * @param _name The name of the Index ERC20 token.
     * @param _symbol The symbol of the Index ERC20 token.
     * @param _wormholeRelayer The address of the Wormhole Relayer contract.
     * @param _tokenBridge The address of the Token Bridge contract.
     * @param _wormhole The address of the Wormhole contract.
     * @param _owner The address of the contract owner.
     * @param _dexRouterAddress The address of the integrated Dex router contract.
     * @param _factoryAddress The address of the protocol factory contract.
     * @dev The constructor also initializes the inherited ERC20, and TokenBase contracts.
     *      - The `owner` is set to the provided `_owner` address.
     *      - The `wormholeRelayer_` is set to an instance of the IWormholeRelayer contract.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole,
        address _owner,
        address _dexRouterAddress,
        address _factoryAddress
    ) ERC20(_name, _symbol) TokenBase(_wormholeRelayer, _tokenBridge, _wormhole) {
        owner = _owner;
        factoryAddress = _factoryAddress;
        dexRouterAddress = _dexRouterAddress;
        wormholeRelayer_ = IWormholeRelayer(_wormholeRelayer);
    }

    /**
     * @notice Handles recption of native coin to the smart contract.
     * @dev Native coins can be sent to the contract to offset the 
     * wormhole crosschain operations.
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @notice Mints a specified amount of tokens to a holder's address during the migration process.
     * @param holder The address of the token holder who will receive the newly minted tokens.
     * @param amount The amount of tokens to be minted.
     * @dev This function is external and can only be called by the designated token migrator contract.
     *      It ensures that only the authorized contract can mint tokens during the migration process.
     *      The newly minted tokens are sent to the specified `holder` address.
     *      The caller must be the `tokenMigratorAddress`, otherwise, the transaction will revert.
     */
    function migrateMint(address holder, uint256 amount) external {
        require(msg.sender == tokenMigratorAddress, "Only token migrator contract can call this function");
        _mint(holder, amount);
    }

    /**
     * @notice Initializes the index with the specified assets, their ratios, and corresponding chain IDs.
     * @param _assetContracts An array of addresses representing the underlying asset contracts.
     * @param _assetRatio An array of ratios corresponding to each underlying asset in the index.
     * @param _assetChains An array of chain IDs where each underlying asset is deployed.
     * @param _chainId The ID of the chain on which this index is deployed.
     * @param _routerAddress The address of the router contract used for cross-chain operations.
     * @dev This function can only be called by the factory contract. It ensures that the index can only be initialized once.
     *      - Sets the `assetContracts`, `assetRatio`, `assetChains`, `chainId`, and `routerAddress` state variables.
     *      - Marks the contract as initialized to prevent re-initialization.
     * The caller must be the factory contract (`factoryAddress`).
     * The contract must not have been initialized before.
     * The function is payable in order for the creator to drop off some gas for cross-chain operations.
     * When deployed and initailized from the factory contract, some gas is dropped off by default.
     */
    function initializeIndex(
        address[] memory _assetContracts,
        uint[] memory _assetRatio,
        uint16[] memory _assetChains,
        uint16 _chainId,
        address _routerAddress,
        address _tokenMigratorAddress
    ) public payable {
        require(msg.sender == factoryAddress, "This function can only be called through the factory contract");
        require(initialized == false, "The contract has been initialized already");
        assetContracts = _assetContracts;
        assetRatio = _assetRatio;
        assetChains = _assetChains;
        chainId = _chainId;
        routerAddress = _routerAddress;
        tokenMigratorAddress = _tokenMigratorAddress;
        initialized = true;
    }

    /**
     * @notice Allows users to invest in the index fund by purchasing underlying assets according to their specified ratios.
     * @param amount The amount of the purchase token to invest in the fund.
     * @param targetIndexContracts An array of addresses corresponding to the target index contracts on other chains.
     * @dev This function handles both local and cross-chain asset purchases:
     *      - Local assets (on the same chain as this contract) are bought directly.
     *      - Cross-chain assets are sent to the corresponding target contracts on other chains using `sendTokenWithPayloadToEvm`.
     *      - The function ensures that the number of target index contracts matches the number of asset chains.
     *      - It calculates the appropriate amount to allocate to each asset based on their ratios.
     *      - After investment, if the caller has not previously minted tokens, they will receive an initial supply. Otherwise, they receive newly minted tokens based on the investment.
     * The length of `targetIndexContracts` must match the length of `assetChains`.
     */
    function investFund(uint amount, address[] memory targetIndexContracts) public {
        require(targetIndexContracts.length == assetChains.length, "Target contracts and chains mismatch");
        address purchaseToken = IFactory(factoryAddress).purchaseToken();
        IERC20(purchaseToken).transferFrom(msg.sender, address(this), amount);

        // Calculate the total ratio sum
        uint sum = 0;
        for (uint i = 0; i < assetRatio.length; i++) {
            sum += assetRatio[i];
        }
        
        // Calculate the unit amount
        uint unit = amount / sum;
        
        // Calculate the amount to be bought for each token
        uint[] memory tokenAmounts = new uint[](assetRatio.length);
        for (uint i = 0; i < assetRatio.length; i++) {
            tokenAmounts[i] = unit * assetRatio[i];
        }

        for (uint16 i = 0; i < assetChains.length; i++) {
            if (assetChains[i] == chainId) {
                IERC20(purchaseToken).approve(dexRouterAddress, tokenAmounts[i]);
                dexRouter(dexRouterAddress).swapExactTokens(address(this), tokenAmounts[i], IERC20(purchaseToken), IERC20(assetContracts[i]));
            } else {
                bytes memory payload = abi.encode(assetContracts[i]);
                        
                sendTokenWithPayloadToEvm(
                    assetChains[i],
                    targetIndexContracts[i],
                    payload,
                    0,
                    GAS_LIMIT,
                    purchaseToken,
                    tokenAmounts[i]
                );
            }
        }
        
        if (balanceOf(msg.sender) == 0) {
            owners += 1;
        }

        // Mint tokens to the user
        if (initialMint == false) {
            _mint(msg.sender, initialSupply);
            initialMint = true;
        } else {
            uint256 price = IRouter(routerAddress).getPrice(address(this));
            uint256 mintAmount = amount / price;
            _mint(msg.sender, mintAmount);
        }
    }

    /**
     * @notice Allows users to redeem their tokens for the underlying stablecoins.
     * @param amount The amount of tokens to be redeemed.
     * @param targetIndex The address of the target index contract on a different chain, if applicable.
     * @dev This function handles both local and cross-chain redemptions:
     *      - Local assets are sold directly, and the proceeds are sent to the user.
     *      - Cross-chain assets are redeemed using the `crossChainRedeem` function of the router.
     *      - The user's tokens are burned after the redemption process.
     * The user must have a balance of tokens equal to or greater than the specified `amount`.
     */
    function Redeem(uint amount, address[] memory targetIndex) public payable {
        require(amount <= balanceOf(msg.sender), "You do not have enough tokens");

        // run through assetContracts in a loop
        for (uint i = 0; i < assetContracts.length; i++) {
            if (assetChains[i] == chainId) {
                uint256 tokenSellAmount = (amount * IERC20(assetContracts[i]).balanceOf(address(this))) / totalSupply();
                address purchaseToken = IFactory(factoryAddress).purchaseToken();

                IERC20(purchaseToken).approve(dexRouterAddress, tokenSellAmount);
                dexRouter(dexRouterAddress).swapExactTokens(address(this), tokenSellAmount, IERC20(assetContracts[i]), IERC20(purchaseToken));
            }
            else {
                uint256 cost = quoteCrossChainMessage(assetChains[i]);
                address purchaseToken = IFactory(factoryAddress).purchaseToken();
                IRouter(routerAddress).crossChainRedeem{value: cost}(totalSupply(), targetIndex[i], amount, assetContracts[i], assetChains[i], msg.sender, purchaseToken);
            }
        }

        // Burn tokens
        _burn(msg.sender, amount);
        
        if (balanceOf(msg.sender) == 0) {
            owners -= 1;
        }
    }

    /**
     * @notice Initiates the migration of a specified amount of tokens to an index on a target chain.
     * @param amount The amount of tokens to be migrated.
     * @param targetChain The chain ID of the destination blockchain where the tokens will be migrated.
     * @param targetIndex The address of the target index on the destination chain.
     * @dev This function burns the specified amount of tokens from the sender's balance and triggers the cross-chain migration process.
     *      The function calculates the cost of the cross-chain message and ensures that the caller has enough tokens to migrate.
     *      The tokens are burned from the caller's account, and a migration request is sent to the token migrator contract.
     *      The caller must provide enough ETH to cover the cross-chain messaging cost or the contract should enough ETH to cover the gass fees.
     * @notice Ensure that `msg.sender` has a sufficient token balance and ETH for the cross-chain transaction fees before calling this function.
     */
    function migrateTokens(uint256 amount, uint16 targetChain, address targetIndex) public payable {
        require(balanceOf(msg.sender) >= amount, "You do not have enough tokens");
        uint256 cost = quoteCrossChainMessage(targetChain);
        require(address(this).balance >= cost || msg.value >= cost, "Not enough gas");
        _burn(msg.sender, amount);
        IMigrator(tokenMigratorAddress).migrateToken{value: cost}(msg.sender, amount, targetIndex, targetChain);
    }

    function quoteCrossChainDeposit(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        // Cost of delivering token and payload to targetChain
        uint256 deliveryCost;
        (deliveryCost, ) = wormholeRelayer_.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );

        // Total cost: delivery cost + cost of publishing the 'sending token' wormhole message
        cost = deliveryCost + wormhole.messageFee();
    }

    function quoteCrossChainMessage(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer_.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    /**
     * @notice Handles incoming payload and token transfers from the Wormhole relayer.
     * @param payload Encoded data containing the asset contract address to be used for token purchases.
     * @param receivedTokens Array of `TokenReceived` structures containing token transfer details.
     * @dev This function:
     *      - Decodes the payload to retrieve the asset contract address.
     *      - Calls the dex router function in order to purchase the specified asset tokens.
     * The `receivedTokens` array must contain exactly one token transfer.
     * The function can only be called by the Wormhole relayer, enforced by the `onlyWormholeRelayer` modifier.
     */
    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32, // sourceAddress
        uint16, // sourceChain
        bytes32 // deliveryHash
    ) internal override onlyWormholeRelayer {
        require(receivedTokens.length == 1, "Expected 1 token transfers");

        (address assetContract) = abi.decode(payload, (address));
        IERC20(receivedTokens[0].tokenAddress).approve(dexRouterAddress, receivedTokens[0].amount);
        dexRouter(dexRouterAddress).swapExactTokens(address(this), receivedTokens[0].amount, IERC20(receivedTokens[0].tokenAddress), IERC20(assetContract));
    }

    /**
     * @notice Handles the sale of tokens and transfers the proceeds to a specified receiver.
     * @param amount The amount of tokens the user wants to sell.
     * @param fundTotalSupply The total supply of tokens in the fund.
     * @param tokenAddress The address of the token being sold.
     * @param receiver The address to which the proceeds from the sale will be sent.
     * @param _outputTokenHomeAddress The address of the output token on the home chain.
     * @param sourceChainId The chain ID of the source chain where the token resides.
     * @dev This function:
     *      - Ensures that only the designated router contract can call it.
     *      - Calculates the amount of tokens to be sold based on the user’s supply and the fund’s total supply.
     *      - Calls the dex router function in order to sell off the specified asset tokens.
     * The caller must be the router contract, as enforced by the `require` statement.
     */
    function sale(
        uint256 amount,
        uint256 fundTotalSupply,
        address tokenAddress,
        address receiver,
        address _outputTokenHomeAddress,
        uint16 sourceChainId
    ) public {
        require(msg.sender == routerAddress, "Only router allowed");

        // Calculate the amount of tokens to be sold
        uint256 sellAmount = (amount * IERC20(tokenAddress).balanceOf(address(this))) / fundTotalSupply;

        // Convert the output token address to the Wormhole format
        bytes32 outputTokenHomeAddress = toWormholeFormat(_outputTokenHomeAddress);

        // Retrieve the token bridge address and wrapped asset address
        address tokenBridgeAddress = IFactory(factoryAddress).tokenBridge();
        address outputToken = ITokenBridge(tokenBridgeAddress).wrappedAsset(sourceChainId, outputTokenHomeAddress);

        // Call the Dex Router Contract
        IERC20(tokenAddress).approve(dexRouterAddress, sellAmount);
        dexRouter(dexRouterAddress).swapExactTokens(receiver, sellAmount, IERC20(tokenAddress), IERC20(outputToken));
    }

    /**
     * @notice Handles the sremoval and addition of assets in an index.
     * @param oldAssetAddress The address of asset to be replaced in the index.
     * @param newAssetAddress The address of the new asset to be included in the index.
     * @dev This function:
     *      - Ensures that only the owner of the index contract can call it.
     *      - Sells off all the tokens of the asset being replaced that are held in the index smart contract.
     *      - Buys the new asset tokens using the proceeds from the previous sale.
     * The caller must be the owner(deployer) of the contract, as enforced by the `require` statement.
     */
    function replaceAsset(address oldAssetAddress, address newAssetAddress) public {
        require(msg.sender == owner, "only contract owner can call this function");
        address purchaseToken = IFactory(factoryAddress).purchaseToken();
        // sell off old token
        uint256 oldAmount = IERC20(oldAssetAddress).balanceOf(address(this));
        IERC20(oldAssetAddress).approve(dexRouterAddress, oldAmount);
        dexRouter(dexRouterAddress).swapExactTokens(address(this), oldAmount, IERC20(oldAssetAddress), IERC20(purchaseToken));
        // buy the new token
        uint256 newAmount = IERC20(purchaseToken).balanceOf(address(this));
        IERC20(purchaseToken).approve(dexRouterAddress, newAmount);
        dexRouter(dexRouterAddress).swapExactTokens(address(this), oldAmount, IERC20(purchaseToken), IERC20(newAssetAddress));
    }
}