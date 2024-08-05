const { ethers } = require("ethers");
const { loadDeployedAddresses, loadConfig } = require("./utils");
const { abi } = require("./mock-erc20-abi");
const { bytecode } = require("./mock-erc20-bytecode");
const { HTabi } = require("./HT-abi");
const { HTbytecode } = require("./HT-bytecode");

function ERC20Mock__factory(signer) {
    return new ethers.ContractFactory(abi, bytecode, signer);
}

function HT__factory(signer) {
    return new ethers.ContractFactory(HTabi, HTbytecode, signer);
}

function getHT(signer) {
    const deployChain = loadConfig().deployChain;
    const HTAddress = loadDeployedAddresses().helloToken[deployChain];
    return new ethers.Contract(HTAddress, HTabi, signer);
}

module.exports = { ERC20Mock__factory, HT__factory, getHT };