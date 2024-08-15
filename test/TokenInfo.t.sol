// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Index} from "../src/TokenInfo.sol";

import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract TokenInfoTest is WormholeRelayerBasicTest {
    Index public helloSource;
    Index public helloTarget;

    ERC20Mock public token;

    function setUpSource() public override {
        helloSource = new Index(
            address(relayerSource),
            address(tokenBridgeSource),
            address(wormholeSource)
        );

        token = createAndAttestToken(sourceChain);
    }

    function setUpTarget() public override {
        helloTarget = new Index(
            address(relayerTarget),
            address(tokenBridgeTarget),
            address(wormholeTarget)
        );
    }

    function testRemoteDeposit() public {
        uint256 amount = 19e17;
        token.approve(address(helloSource), amount);

        vm.selectFork(targetFork);
        address recipient = 0x1234567890123456789012345678901234567890;

        address purchaseToken = 0x1234567890123456789012345678901234567100;

        vm.selectFork(sourceFork);
        uint256 cost = helloSource.quoteCrossChainDeposit(targetChain);

        vm.recordLogs();
        helloSource.sendCrossChainDeposit{value: cost}(
            targetChain, address(helloTarget), recipient, amount, address(token), purchaseToken
        );
        performDelivery();

        vm.selectFork(targetFork);
        address wormholeWrappedToken = tokenBridgeTarget.wrappedAsset(sourceChain, toWormholeFormat(address(token)));
        // assertEq(IERC20(wormholeWrappedToken).balanceOf(recipient), amount);
        assertEq(helloTarget.tokenPurchase(), purchaseToken);
    }
}