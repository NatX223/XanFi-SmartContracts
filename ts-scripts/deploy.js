const { ethers } = require("ethers");
const { HT__factory } = require("./ethers-contracts.js");
const {
  loadDeployedAddresses,
  getWallet,
  loadConfig,
  storeDeployedAddresses,
  getChain,
} = require("./utils");

const deployChain = loadConfig().deployChain;

async function deployHT() {
  const deployed = loadDeployedAddresses();
  const chain = getChain(deployChain);

  const signer = getWallet(deployChain);
  const factory = HT__factory(signer);
  const HT = await factory.deploy(chain.wormholeRelayer, chain.tokenBridge, chain.wormhole);
  await HT.deployed();
  console.log(`HT deployed to ${HT.address} on ${chain.description}`);
  deployed.helloToken[chain.chainId] = HT.address;

  storeDeployedAddresses(deployed);
}

deployHT();
