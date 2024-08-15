const { ethers } = require("ethers");
const { Index__factory, Router__factory } = require("./ethers-contracts.js");
const {
  loadDeployedAddresses,
  getWallet,
  loadConfig,
  storeDeployedAddresses,
  getChain,
} = require("./utils.js");

const deployChain = loadConfig().deployChain;

async function deployProtocol() {
    const deployed = loadDeployedAddresses();
    const chain = getChain(deployChain);
    const signer = getWallet(deployChain);
    console.log(deployChain, chain, signer);

    const indexFactory = Index__factory(signer);
    const indexRouter = Router__factory(signer);
    console.log(indexFactory, indexRouter, "deploying");
    const IR = await indexRouter.deploy(chain.wormholeRelayer, deployChain);
    await IR.deployed();
    const IF = await indexFactory.deploy(chain.tokenBridge, chain.wormhole, chain.wormholeRelayer, chain.purchaseToken, deployChain, chain.helperAddress, IR.address);
    await IF.deployed();

    console.log(`factory deployed to ${IF.address} and router deployed to ${IR.address} on ${chain.description}`);
    deployed.factoryAddresses[chain.chainId] = IF.address;
    deployed.routerAddresses[chain.chainId] = IR.address;

    storeDeployedAddresses(deployed);
  }

  deployProtocol();