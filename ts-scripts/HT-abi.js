const HTabi = [
    {
      type: "constructor",
      inputs: [
        { name: "_wormholeRelayer", type: "address", internalType: "address" },
        { name: "_tokenBridge", type: "address", internalType: "address" },
        { name: "_wormhole", type: "address", internalType: "address" }
      ],
      stateMutability: "nonpayable"
    },
    {
      type: "function",
      name: "quoteCrossChainDeposit",
      inputs: [{ name: "targetChain", type: "uint16", internalType: "uint16" }],
      outputs: [{ name: "cost", type: "uint256", internalType: "uint256" }],
      stateMutability: "view"
    },
    {
      type: "function",
      name: "receiveWormholeMessages",
      inputs: [
        { name: "payload", type: "bytes", internalType: "bytes" },
        { name: "additionalVaas", type: "bytes[]", internalType: "bytes[]" },
        { name: "sourceAddress", type: "bytes32", internalType: "bytes32" },
        { name: "sourceChain", type: "uint16", internalType: "uint16" },
        { name: "deliveryHash", type: "bytes32", internalType: "bytes32" }
      ],
      outputs: [],
      stateMutability: "payable"
    },
    {
      type: "function",
      name: "sendCrossChainDeposit",
      inputs: [
        { name: "targetChain", type: "uint16", internalType: "uint16" },
        { name: "targetHelloToken", type: "address", internalType: "address" },
        { name: "recipient", type: "address", internalType: "address" },
        { name: "amount", type: "uint256", internalType: "uint256" },
        { name: "token", type: "address", internalType: "address" }
      ],
      outputs: [],
      stateMutability: "payable"
    },
    {
      type: "function",
      name: "sendNativeCrossChainDeposit",
      inputs: [
        { name: "targetChain", type: "uint16", internalType: "uint16" },
        { name: "targetHelloToken", type: "address", internalType: "address" },
        { name: "recipient", type: "address", internalType: "address" },
        { name: "amount", type: "uint256", internalType: "uint256" }
      ],
      outputs: [],
      stateMutability: "payable"
    },
    {
      type: "function",
      name: "setRegisteredSender",
      inputs: [
        { name: "sourceChain", type: "uint16", internalType: "uint16" },
        { name: "sourceAddress", type: "bytes32", internalType: "bytes32" }
      ],
      outputs: [],
      stateMutability: "nonpayable"
    },
    {
      type: "function",
      name: "tokenBridge",
      inputs: [],
      outputs: [{ name: "", type: "address", internalType: "contract ITokenBridge" }],
      stateMutability: "view"
    },
    {
      type: "function",
      name: "wormhole",
      inputs: [],
      outputs: [{ name: "", type: "address", internalType: "contract IWormhole" }],
      stateMutability: "view"
    },
    {
      type: "function",
      name: "wormholeRelayer",
      inputs: [],
      outputs: [{ name: "", type: "address", internalType: "contract IWormholeRelayer" }],
      stateMutability: "view"
    },
    {
      type: "error",
      name: "NotAnEvmAddress",
      inputs: [{ name: "", type: "bytes32", internalType: "bytes32" }]
    }
  ];
  
  module.exports = { HTabi };
  