const { ethers } = require("ethers");
const { ERC20Mock__factory } = require("./ethers-contracts.js");
const {
  loadDeployedAddresses,
  getWallet,
  loadConfig,
  storeDeployedAddresses,
  getChain,
} = require("./utils");

const chain = loadConfig().deployChain;

async function deployTokens() {
  const deployed = loadDeployedAddresses();

  const signer = getWallet(chain);
  const factory = ERC20Mock__factory(signer);
  const WBTC = await factory.deploy("Wrapped Bitcoin", "WBTC");
  await WBTC.deployed();
  const WETH = await factory.deploy("Wrapped Ethereum", "WETH");
  await WETH.deployed();
  const WLD = await factory.deploy("World Coin", "WLD");
  await WLD.deployed();
  const W = await factory.deploy("Wormhole", "W");
  await W.deployed();
  const addresses = deployed.erc20s[chain];
  if (addresses === null) {
    deployed.erc20s[chain] = [{"WBTC": WBTC.address}, {"WETH": WETH.address}, {"WLD": WLD.address}, {"W": W.address}];
  } else {
    deployed.erc20s[chain] = [...addresses, {"WBTC": WBTC.address}, {"WETH": WETH.address}, {"WLD": WLD.address}, {"W": W.address}];
  }
  
  console.log("Minting...");
  await WBTC.mint(signer.address, ethers.utils.parseEther("10000"));
  await WETH.mint(signer.address, ethers.utils.parseEther("10000"));
  await WLD.mint(signer.address, ethers.utils.parseEther("10000"));
  await W.mint(signer.address, ethers.utils.parseEther("10000"));
  // await wait();
  console.log("Minted 10000 TOKENs to signer");

  storeDeployedAddresses(deployed);
}


deployTokens();
