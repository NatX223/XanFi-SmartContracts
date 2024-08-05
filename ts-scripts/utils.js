const { ethers, Wallet } = require("ethers");
const { readFileSync, writeFileSync } = require("fs");
const { ChainId } = require("@certusone/wormhole-sdk");
require('dotenv').config();

function getChain(chainId) {
  const chain = loadConfig().chains.find((c) => c.chainId === chainId);
  if (!chain) {
    throw new Error(`Chain ${chainId} not found`);
  }
  return chain;
}

function getWallet(chainId) {
  const rpc = loadConfig().chains.find((c) => c.chainId === chainId)?.rpc;
  let provider = new ethers.providers.JsonRpcProvider(rpc);
  if (!process.env.EVM_PRIVATE_KEY)
    throw Error(
      "No private key provided (use the EVM_PRIVATE_KEY environment variable)"
    );
  return new Wallet(process.env.EVM_PRIVATE_KEY, provider);
}

function getHelloToken(chainId) {
    const deployed = loadDeployedAddresses().helloToken[chainId];
    if (!deployed) {
      throw new Error(`No deployed hello token on chain ${chainId}`);
    }
    return HelloToken__factory.connect(deployed, getWallet(chainId));
  }

let _config;
let _deployed;

function loadConfig() {
  if (!_config) {
    _config = JSON.parse(
      readFileSync("testnet/config.json", { encoding: "utf-8" })
    );
  }
  return _config;
}

function loadDeployedAddresses() {
  if (!_deployed) {
    _deployed = JSON.parse(
      readFileSync("testnet/deployedAddresses.json", {
        encoding: "utf-8",
      })
    );
    // if (!deployed) {
    //   _deployed = {
    //     erc20s: {},
    //     helloToken: {},
    //   };
    // }
  }
  return _deployed;
}

function storeDeployedAddresses(deployed) {
  writeFileSync(
    "testnet/deployedAddresses.json",
    JSON.stringify(deployed, null, 2)
  );
}

function checkFlag(patterns) {
  return getArg(patterns, { required: false, isFlag: true });
}

function getArg(patterns, { isFlag = false, required = true } = {}) {
  let idx = -1;
  if (typeof patterns === "string") {
    patterns = [patterns];
  }
  for (const pattern of patterns) {
    idx = process.argv.findIndex((x) => x === pattern);
    if (idx !== -1) {
      break;
    }
  }
  if (idx === -1) {
    if (required) {
      throw new Error(
        "Missing required cmd line arg: " + JSON.stringify(patterns)
      );
    }
    return undefined;
  }
  if (isFlag) {
    return process.argv[idx];
  }
  return process.argv[idx + 1];
}

const deployed = (x) => x.deployed();
const wait = (x) => x.wait();

module.exports = {
  getChain,
  getWallet,
  loadConfig,
  loadDeployedAddresses,
  storeDeployedAddresses,
  checkFlag,
  getArg,
  deployed,
  wait,
};
