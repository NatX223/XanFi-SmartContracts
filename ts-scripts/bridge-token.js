const { ethers } = require("ethers");
const { ERC20Mock__factory, getHT, getUSDT } = require("./ethers-contracts.js");
const {
  loadDeployedAddresses,
  getWallet,
  wait,
  loadConfig,
  storeDeployedAddresses,
  getChain
} = require("./utils");
const {
  ChainId,
  attestFromEth,
  createWrappedOnEth,
  getSignedVAAWithRetry,
  parseSequenceFromLogEth,
  tryNativeToHexString,
} = require("@certusone/wormhole-sdk");
const grpcWebNodeHttpTransport = require("@improbable-eng/grpc-web-node-http-transport");
const { ChainInfo, getArg } = require("./utils");

const sourceChain = loadConfig().sourceChain;
const targetChain = loadConfig().targetChain;

async function bridgeToken() {
  const deployed = loadDeployedAddresses();
  const from = getChain(sourceChain);
  const to = getChain(targetChain);

  const signer = getWallet(from.chainId);
  const USDT = getUSDT(signer, sourceChain);
  const amount = ethers.utils.parseEther("1000");
  const HTSource = loadDeployedAddresses().helloToken[sourceChain];
  await USDT.approve(HTSource, amount);
  // await wait();

  console.log(
    `Attesting tokens with token bridge on chain(s) ${loadConfig()
      .chains.map((c) => c.chainId)
      .filter((c) => c === targetChain)
      .join(", ")}`
  );
  // for (const chain of loadConfig().chains) {
  //   if (chain.chainId !== targetChain) {
  //     continue;
  //   }
  //   await attestWorkflow({
  //     from: getChain(sourceChain),
  //     to: chain,
  //     token: USDT.address,
  //   });
  //   console.log("attestation done");
  // }

  // send tokens to signer.address on target chain
  const HTTarget = loadDeployedAddresses().helloToken[targetChain];

  const HT = getHT(signer);
  const cost = await HT.quoteCrossChainDeposit(targetChain);
  await HT.sendCrossChainDeposit(targetChain, HTTarget, signer.address, amount, USDT.address, {value: cost});
  console.log("crosschain deposit");
  console.log(`bridged 1000 USDT to ${to.description}`);
}

async function attestWorkflow({ to, from, token }) {
  const attestRx = await attestFromEth(
    from.tokenBridge,
    getWallet(from.chainId),
    token
  );
  const seq = parseSequenceFromLogEth(attestRx, from.wormhole);

  const res = await getSignedVAAWithRetry(
    ["https://api.testnet.wormscan.io"],
    Number(from.chainId),
    tryNativeToHexString(from.tokenBridge, "ethereum"),
    seq.toString(),
    { transport: grpcWebNodeHttpTransport.NodeHttpTransport() }
  );
  const createWrappedRx = await createWrappedOnEth(
    to.tokenBridge,
    getWallet(to.chainId),
    res.vaaBytes
  );
  console.log(
    `Attested token from chain ${from.chainId} to chain ${to.chainId}`
  );
}

bridgeToken();
