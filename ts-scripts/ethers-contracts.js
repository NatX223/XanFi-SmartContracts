const { ethers } = require("ethers");
const { loadDeployedAddresses, loadConfig } = require("./utils");
const { abi } = require("./mock-erc20-abi");
const { bytecode } = require("./mock-erc20-bytecode");
const { HTabi } = require("./HT-abi");
const { HTbytecode } = require("./HT-bytecode");
const { routerArtifacts } = require("./index-router-artifacts")
const { factoryArtifacts } = require("./index-factory-artifacts")

function ERC20Mock__factory(signer) {
    return new ethers.ContractFactory(abi, bytecode, signer);
}

function HT__factory(signer) {
    return new ethers.ContractFactory(HTabi, HTbytecode, signer);
}

function Router__factory(signer) {
    return new ethers.ContractFactory(routerArtifacts.abi, routerArtifacts.bytecode, signer);
}

function Index__factory(signer) {
    return new ethers.ContractFactory(factoryArtifacts.abi, factoryArtifacts.bytecode, signer);
}

function getHT(signer) {
    const deployChain = loadConfig().deployChain;
    const HTAddress = loadDeployedAddresses().helloToken[deployChain];
    return new ethers.Contract(HTAddress, HTabi, signer);
}

function getUSDT(signer, chainId) {
    const usdtAddress = loadDeployedAddresses().erc20s[chainId][0];
    return new ethers.Contract(usdtAddress, abi, signer)
}

// function getHT(signer) {
//     const deployChain = loadConfig().deployChain;
//     const HTAddress = loadDeployedAddresses().helloToken[deployChain];
//     return new ethers.Contract(HTAddress, HTabi, signer);
// }

module.exports = { ERC20Mock__factory, HT__factory, Router__factory, Index__factory, getHT, getUSDT };