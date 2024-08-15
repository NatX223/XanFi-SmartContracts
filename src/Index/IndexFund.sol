// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
pragma abicoder v2;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "./UniswapHelper.sol";

interface ITokenBridge {
    /**
     * @notice Function to retrieve the address of the wrapped asset corresponding to a specific token on another chain
     * @param tokenChainId The ID of the chain where the original token exists
     * @param tokenAddress The address of the original token on the source chain
     * @return The address of the wrapped asset on the current chain
     */
    function wrappedAsset(uint16 tokenChainId, bytes32 tokenAddress) external view returns (address);
}

interface IFactory {
    /**
     * @notice Function to retrieve the address of the token used for purchases
     * @return The address of the purchase token
     */
    function purchaseToken() external view returns(address);

    /**
     * @notice Function to retrieve the address of the token bridge contract on the currnt chain
     * @return The address of the token bridge
     */
    function tokenBridge() external view returns(address);
}
interface IRouter {
    /**
     * @notice Function to redeem tokens across different chains
     * @param _totalSupply The total supply of the asset being redeemed
     * @param _targetIndex The index contract address of the target chain where the asset will be redeemed
     * @param _userBalance The balance of the user initiating the cross-chain redemption
     * @param _assetContract The address of the asset contract being redeemed
     * @param targetChain The ID of the chain where the asset is to be redeemed
     * @param receiver The address of the receiver on the target chain
     * @param purchaseToken The address of the token used for the purchase
     */
    function crossChainRedeem(uint256 _totalSupply, address _targetIndex, uint256 _userBalance, address _assetContract, uint16 targetChain, address receiver, address purchaseToken) external payable;

    /**
     * @notice Function to retrieve the price of a index
     * @param fundAddress The address of the index 
     * @return The price of the fund
     */
    function getPrice(address fundAddress) external view returns(uint256);
}

/**
 * @title IndexFund
 * @notice This contract represents an index fund and includes functionality for sending and receiving tokens,
 *         interacting with Uniswap, and managing ERC20 tokens.
 * @dev Inherits from the TokenSender, TokenReceiver, ERC20, and UniswapHelper contracts.
 */
contract IndexFund is TokenSender, TokenReceiver, ERC20, UniswapHelper {

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
     * @param helperAddress The address of the UniswapHelper contract.
     * @dev The constructor also initializes the inherited ERC20, TokenBase, and UniswapHelper contracts.
     *      - The `owner` is set to the provided `_owner` address.
     *      - `factoryAddress` is set to the address that deployed the contract.
     *      - The `wormholeRelayer_` is set to an instance of the IWormholeRelayer contract.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole,
        address _owner,
        address helperAddress
    ) ERC20(_name, _symbol) TokenBase(_wormholeRelayer, _tokenBridge, _wormhole) UniswapHelper(helperAddress) {
        owner = _owner;
        factoryAddress = msg.sender;
        wormholeRelayer_ = IWormholeRelayer(_wormholeRelayer);
    }


    /**
     * @notice Mints a specified amount of tokens to the caller's address.
     * @param mintAmount The amount of tokens to be minted.
     * @dev This function is internal and can only be called from within the contract or derived contracts.
     *      The newly minted tokens are sent to the caller (`msg.sender`).
     */
    function mint(uint mintAmount) internal {
        _mint(msg.sender, mintAmount);
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
     * @require The caller must be the factory contract (`factoryAddress`).
     * @require The contract must not have been initialized before.
     */
    function initializeIndex(
        address[] memory _assetContracts,
        uint[] memory _assetRatio,
        uint16[] memory _assetChains,
        uint16 _chainId,
        address _routerAddress
    ) public {
        require(msg.sender == factoryAddress, "This function can only be called through the factory contract");
        require(initialized == false, "The contract has been initialized already");
        assetContracts = _assetContracts;
        assetRatio = _assetRatio;
        assetChains = _assetChains;
        chainId = _chainId;
        routerAddress = _routerAddress;
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
     * @require The length of `targetIndexContracts` must match the length of `assetChains`.
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
                bytes memory data = abi.encodeWithSelector(
                    this.buyToken.selector,
                    assetContracts[i],
                    tokenAmounts[i],
                    address(this),
                    purchaseToken
                );

                (bool success, bytes memory result) = address(this).delegatecall(data);
                if (!success) {
                    if (result.length < 68) revert();
                    assembly {
                        result := add(result, 0x04)
                    }
                    revert(abi.decode(result, (string)));
                }
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
                
        // Mint tokens to the user
        if (initialMint == false) {
            mint(initialSupply);
            initialMint = true;
        } else {
            mint(10);  // Replace with appropriate mint logic as needed
        }
        
        if (balanceOf(msg.sender) == 0) {
            owners += 1;
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
     * @require The user must have a balance of tokens equal to or greater than the specified `amount`.
     */
    function Redeem(uint amount, address targetIndex) public payable {
        require(amount <= balanceOf(msg.sender), "You do not have enough tokens");

        // Iterate through assetContracts to handle the redemption process
        for (uint i = 0; i < assetContracts.length; i++) {
            if (assetChains[i] == chainId) {
                // Handle local asset redemption
                uint256 tokenSellAmount = (balanceOf(msg.sender) * IERC20(assetContracts[i]).balanceOf(address(this))) / totalSupply();
                address purchaseToken = IFactory(factoryAddress).purchaseToken();
                bytes memory data = abi.encodeWithSelector(
                    this.sellToken.selector,
                    assetContracts[i],
                    tokenSellAmount,
                    msg.sender,
                    purchaseToken
                );
                (bool success, bytes memory result) = address(this).delegatecall(data);
                if (!success) {
                    if (result.length < 68) revert();
                    assembly {
                        result := add(result, 0x04)
                    }
                    revert(abi.decode(result, (string)));
                }
            } else {
                // Handle cross-chain asset redemption
                uint256 cost = quoteCrossChainMessage(assetChains[i]);
                address purchaseToken = IFactory(factoryAddress).purchaseToken();
                IRouter(routerAddress).crossChainRedeem{value: cost}(
                    totalSupply(),
                    targetIndex,
                    balanceOf(msg.sender),
                    assetContracts[i],
                    assetChains[i],
                    msg.sender,
                    purchaseToken
                );
            }
        }
        // Burn the user's tokens after redemption
        _burn(msg.sender, amount);
    }

    // function to return all prices of the tokens
    // function getPrice(address token) internal view returns(uint price) {
    //     // write interface and instatiate
    //     IERC20 Itoken = IERC20(token);
    //     uint decimal = Itoken.decimals();
    //     uint amountIn = 1 * (10 ** decimal);
    //     price = estimateAmountOut(token, amountIn);
    // }

    // function to return fund details
    // function Details() public view returns (address, address[] memory, string[] memory, uint[] memory, uint) {
    //     return(owner, assetContracts, assetsNames, assetsRatio, owners);
    // }

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
     * @param sourceAddress The source address of the message, not used in this function.
     * @param sourceChain The source chain ID, not used in this function.
     * @param deliveryHash A hash representing the delivery of the message, not used in this function.
     * @dev This function:
     *      - Decodes the payload to retrieve the asset contract address.
     *      - Encodes a call to `buyToken` with the asset contract address and received token amount.
     *      - Uses `delegatecall` to execute the `buyToken` function on the current contract.
     *      - Handles potential errors from the delegate call by reverting with an appropriate error message.
     * @require The `receivedTokens` array must contain exactly one token transfer.
     * @require The function can only be called by the Wormhole relayer, enforced by the `onlyWormholeRelayer` modifier.
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

        bytes memory data = abi.encodeWithSelector(
            this.buyToken.selector,
            assetContract,
            receivedTokens[0].amount,
            address(this),
            receivedTokens[0].tokenAddress
        );

        (bool success, bytes memory result) = address(this).delegatecall(data);

        if (!success) {
            if (result.length < 68) revert();
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }
    }

    /**
     * @notice Handles the sale of tokens and transfers the proceeds to a specified receiver.
     * @param userSupply The amount of tokens the user is supplying for the sale.
     * @param fundTotalSupply The total supply of tokens in the fund.
     * @param tokenAddress The address of the token being sold.
     * @param receiver The address to which the proceeds from the sale will be sent.
     * @param _outputTokenHomeAddress The address of the output token on the home chain.
     * @param sourceChainId The chain ID of the source chain where the token resides.
     * @dev This function:
     *      - Ensures that only the designated router contract can call it.
     *      - Calculates the amount of tokens to be sold based on the user’s supply and the fund’s total supply.
     *      - Retrieves the wrapped token address from the token bridge.
     *      - Encodes a call to `sellToken` with the calculated parameters.
     *      - Uses `delegatecall` to execute the `sellToken` function on the current contract.
     *      - Handles errors from the delegate call by reverting with an appropriate error message.
     * @require The caller must be the router contract, as enforced by the `require` statement.
     */
    function sale(
        uint256 userSupply,
        uint256 fundTotalSupply,
        address tokenAddress,
        address receiver,
        address _outputTokenHomeAddress,
        uint16 sourceChainId
    ) public {
        require(msg.sender == routerAddress, "Only router allowed");

        // Calculate the amount of tokens to be sold
        uint256 sellAmount = (userSupply * IERC20(tokenAddress).balanceOf(address(this))) / fundTotalSupply;

        // Convert the output token address to the Wormhole format
        bytes32 outputTokenHomeAddress = toWormholeFormat(_outputTokenHomeAddress);

        // Retrieve the token bridge address and wrapped asset address
        address tokenBridgeAddress = IFactory(factoryAddress).tokenBridge();
        address outputToken = ITokenBridge(tokenBridgeAddress).wrappedAsset(sourceChainId, outputTokenHomeAddress);

        // Encode the data for the `sellToken` function call
        bytes memory data = abi.encodeWithSelector(
            this.sellToken.selector,
            tokenAddress,
            sellAmount,
            receiver,
            outputToken
        );

        // Execute the `sellToken` function using `delegatecall`
        (bool success, bytes memory result) = address(this).delegatecall(data);

        // Handle potential errors from the `delegatecall`
        if (!success) {
            if (result.length < 68) revert();
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }
    }


    // modifier addressCheck(address[] memory tokenAddresses) {
    //     for (uint i = 0; i < tokenAddresses.length; i++) {
    //         require(tokenAddresses[i] != address(0), "Invalid token address");
    //     }
    //     _;
    // }

    // rebalancing
    // native buy/sell
}