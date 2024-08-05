// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;
// pragma abicoder v2;

// // importing the ERC20 token contract
// import "openzeppelin-contracts/token/ERC20/ERC20.sol";
// import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";
// import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
// import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
// // import "wormhole-solidity-sdk/interfaces/IERC20.sol";

// interface IFactory {
//     function purchaseToken() external view returns(address);
// }

// interface IRouter {
//     function crossChainRedeem(uint256 totalSupply, address targetIndex, uint256 userBalance, address assetContract, uint16 targetChain) external payable;
//     function getPrice(address fundAddress) external view returns(uint256);
// }

// contract IndexFund is TokenSender, TokenReceiver, ERC20 {
//     uint16 public chainId;
//     uint256 constant GAS_LIMIT = 300_000;

//     uint initialSupply = 10000 * (10 ** 8);
//     bool public initialMint;
//     address public owner;
//     uint256 public owners;
//     address public factoryAddress;
//     address public routerAddress;
//     bool public initialized;
//     IWormholeRelayer public immutable wormholeRelayer_;

//     // an array of the underlying assets for the index
//     address[] public assetContracts;
//     // string[] public assetsNames;
//     uint[] public assetRatio;
//     uint16[] public assetChains;

//     constructor(string memory _name, string memory _symbol, address _wormholeRelayer, address _tokenBridge, address _wormhole, address _owner) ERC20(_name, _symbol) TokenBase(_wormholeRelayer, _tokenBridge, _wormhole) {
//         owner = _owner;
//         factoryAddress = msg.sender;
//         wormholeRelayer_ = IWormholeRelayer(_wormholeRelayer);
//     }

//     function mint(uint mintAmount) internal {
//         _mint(msg.sender, mintAmount);
//     }

//     // function to get create index instantly
//     function initializeIndex(address[] memory _assetContracts, uint[] memory _assetRatio, uint16[] memory _assetChains, uint16 _chainId, address _routerAddress) public {
//         require(msg.sender == factoryAddress, "This function can only be called through the factory contract");
//         require(initialized == false, "The contract has been initialized already");
//         assetContracts = _assetContracts;
//         assetRatio = _assetRatio;
//         assetChains = _assetChains;
//         chainId = _chainId;
//         routerAddress = _routerAddress;
//         initialized = true;
//     }

//     // function to invest in fund
//     function investFund(uint amount, address[] memory targetIndexContracts) public {
//         require(targetIndexContracts.length == assetChains.length, "Target contracts and chains mismatch");
//         address purchaseToken = IFactory(factoryAddress).purchaseToken();
//         IERC20(purchaseToken).transferFrom(msg.sender, address(this), amount);

//         // Calculate the total ratio sum
//         uint sum = 0;
//         for (uint i = 0; i < assetRatio.length; i++) {
//             sum += assetRatio[i];
//         }
        
//         // Calculate the unit amount
//         uint unit = amount / sum;
        
//         // Calculate the amount to be bought for each token
//         uint[] memory tokenAmounts = new uint[](assetRatio.length);
//         for (uint i = 0; i < assetRatio.length; i++) {
//             tokenAmounts[i] = unit * assetRatio[i];
//         }

//         for (uint16 i = 0; i < assetChains.length; i++) {
//             if (assetChains[i] == chainId) {
//                 bytes memory data = abi.encodeWithSelector(this.buyAsset.selector, assetContracts[i], tokenAmounts[i], address(this));

//                 (bool success, bytes memory result) = address(this).delegatecall(data);
//                 if (!success) {
//                     if (result.length < 68) revert();
//                     assembly {
//                         result := add(result, 0x04)
//                     }
//                     revert(abi.decode(result, (string)));
//                 }
//             } else {

//                 bytes memory payload = abi.encode(assetContracts[i], assetRatio[i]);
                        
//                 sendTokenWithPayloadToEvm(
//                     assetChains[i],
//                     targetIndexContracts[i],
//                     payload,
//                     0,
//                     GAS_LIMIT,
//                     purchaseToken,
//                     tokenAmounts[i]
//                 );
//             }
//         }
                
//         // Get the price of the token
//         if (initialMint == false) {
//             mint(initialSupply);
//             initialMint = true;
//         } else {
//             // uint price = Price();
//             // uint mintAmount = amount / price;
//             // total value / totalSupply();
//             mint(10);
//         }
        
//         if (balanceOf(msg.sender) == 0) {
//             owners += 1;
//         }
//     }

//     // function to redeem stable coin
//     function Redeem(uint amount, address targetIndex) public payable {
//         require(amount <= balanceOf(msg.sender), "You do not have enough tokens");

//         // run through assetContracts in a loop
//         for (uint i = 0; i < assetContracts.length; i++) {
//             if (assetChains[i] == chainId) {
//                 uint256 tokenSellAmount = (balanceOf(msg.sender) * IERC20(assetContracts[i]).balanceOf(address(this))) / totalSupply();
//                 bytes memory data = abi.encodeWithSelector(this.sellAsset.selector, assetContracts[i], tokenSellAmount, msg.sender);
//                 (bool success, bytes memory result) = address(this).delegatecall(data[i]);
//                 if (!success) {
//                     if (result.length < 68) revert();
//                     assembly {
//                         result := add(result, 0x04)
//                     }
//                     revert(abi.decode(result, (string)));
//                 }
//             }
//             else {
//                 uint256 cost = quoteCrossChainMessage(assetChains[i]);
//                 IRouter(routerAddress).crossChainRedeem{value: cost}(totalSupply(), targetIndex, balanceOf(msg.sender), assetContracts[i], assetChains[i], msg.sender);
//             }
//         }
//         // Burn tokens
//         _burn(msg.sender, amount);
//     }

//     // function to return all prices of the tokens
//     // function getPrice(address token) internal view returns(uint price) {
//     //     // write interface and instatiate
//     //     IERC20 Itoken = IERC20(token);
//     //     uint decimal = Itoken.decimals();
//     //     uint amountIn = 1 * (10 ** decimal);
//     //     price = estimateAmountOut(token, amountIn);
//     // }

//     // function to return fund details
//     // function Details() public view returns (address, address[] memory, string[] memory, uint[] memory, uint) {
//     //     return(owner, assetContracts, assetsNames, assetsRatio, owners);
//     // }

//     function quoteCrossChainDeposit(
//         uint16 targetChain
//     ) public view returns (uint256 cost) {
//         // Cost of delivering token and payload to targetChain
//         uint256 deliveryCost;
//         (deliveryCost, ) = wormholeRelayer_.quoteEVMDeliveryPrice(
//             targetChain,
//             0,
//             GAS_LIMIT
//         );

//         // Total cost: delivery cost + cost of publishing the 'sending token' wormhole message
//         cost = deliveryCost + wormhole.messageFee();
//     }

//     function quoteCrossChainMessage(
//         uint16 targetChain
//     ) public view returns (uint256 cost) {
//         (cost, ) = wormholeRelayer_.quoteEVMDeliveryPrice(
//             targetChain,
//             0,
//             GAS_LIMIT
//         );
//     }

//     function receivePayloadAndTokens(
//         bytes memory payload,
//         TokenReceived[] memory receivedTokens,
//         bytes32, // sourceAddress
//         uint16,
//         bytes32 // deliveryHash
//     ) internal override onlyWormholeRelayer {
//         require(receivedTokens.length == 1, "Expected 1 token transfers");

//         (address assetContract) = abi.decode(payload, (address, uint));

//         bytes memory data = abi.encodeWithSelector(this.buyAsset.selector, assetContract, receivedTokens[0].amount, address(this));

//         (bool success, bytes memory result) = address(this).delegatecall(data);

//         if (!success) {
//             if (result.length < 68) revert();
//             assembly {
//                 result := add(result, 0x04)
//             }
//             revert(abi.decode(result, (string)));
//         }
//         return result;
//     }

//     function sale(uint256 userSupply, uint256 fundTotalSupply, address tokenAddress, address receiver) public {
//         require(msg.sender == routerAddress, "Only router allowed");

//         uint256 sellAmount = (userSupply * IERC20(tokenAddress).balanceOf(address(this))) / fundTotalSupply;
//         bytes memory data = abi.encodeWithSelector(this.sellAsset.selector, tokenAddress, sellAmount, receiver);
//         (bool success, bytes memory result) = address(this).delegatecall(data);
//         if (!success) {
//             if (result.length < 68) revert();
//             assembly {
//                 result := add(result, 0x04)
//             }
//             revert(abi.decode(result, (string)));
//         }
//     }

//     modifier addressCheck(address[] memory tokenAddresses) {
//         for (uint i = 0; i < tokenAddresses.length; i++) {
//             require(tokenAddresses[i] != address(0), "Invalid token address");
//         }
//         _;
//     }

//     // rebalancing
//     // native buy/sell
// }