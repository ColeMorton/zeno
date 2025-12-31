// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VaultNFT} from "../src/VaultNFT.sol";
import {BtcToken} from "../src/BtcToken.sol";
import {MockTreasure} from "../test/mocks/MockTreasure.sol";
import {MockWBTC} from "../test/mocks/MockWBTC.sol";
import {MockCBBTC} from "../test/mocks/MockCBBTC.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Shared MockTreasure
        MockTreasure treasure = new MockTreasure();
        console.log("MockTreasure deployed at:", address(treasure));

        // ========== WBTC Stack ==========
        MockWBTC wbtc = new MockWBTC();
        console.log("MockWBTC deployed at:", address(wbtc));

        uint256 nonce = vm.getNonce(deployer);
        address predictedWbtcVault = vm.computeCreateAddress(deployer, nonce + 1);

        BtcToken btcTokenWbtc = new BtcToken(predictedWbtcVault, "vestedBTC-wBTC", "vWBTC");
        console.log("BtcToken (WBTC) deployed at:", address(btcTokenWbtc));

        VaultNFT vaultWbtc = new VaultNFT(
            address(btcTokenWbtc),
            address(wbtc),
            "Vault NFT-wBTC",
            "VAULT-W"
        );
        console.log("VaultNFT (WBTC) deployed at:", address(vaultWbtc));

        require(address(vaultWbtc) == predictedWbtcVault, "WBTC Vault address mismatch");

        wbtc.mint(deployer, 100 * 1e8);
        console.log("Minted 100 WBTC to deployer");

        // ========== cbBTC Stack ==========
        MockCBBTC cbbtc = new MockCBBTC();
        console.log("MockCBBTC deployed at:", address(cbbtc));

        nonce = vm.getNonce(deployer);
        address predictedCbbtcVault = vm.computeCreateAddress(deployer, nonce + 1);

        BtcToken btcTokenCbbtc = new BtcToken(predictedCbbtcVault, "vestedBTC-cbBTC", "vcbBTC");
        console.log("BtcToken (cbBTC) deployed at:", address(btcTokenCbbtc));

        VaultNFT vaultCbbtc = new VaultNFT(
            address(btcTokenCbbtc),
            address(cbbtc),
            "Vault NFT-cbBTC",
            "VAULT-C"
        );
        console.log("VaultNFT (cbBTC) deployed at:", address(vaultCbbtc));

        require(address(vaultCbbtc) == predictedCbbtcVault, "cbBTC Vault address mismatch");

        cbbtc.mint(deployer, 100 * 1e8);
        console.log("Minted 100 cbBTC to deployer");

        // ========== Shared Treasure ==========
        treasure.mintBatch(deployer, 10);
        console.log("Minted 10 Treasure NFTs to deployer");

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("TREASURE:", address(treasure));
        console.log("WBTC:", address(wbtc));
        console.log("BTC_TOKEN_WBTC:", address(btcTokenWbtc));
        console.log("VAULT_WBTC:", address(vaultWbtc));
        console.log("CBBTC:", address(cbbtc));
        console.log("BTC_TOKEN_CBBTC:", address(btcTokenCbbtc));
        console.log("VAULT_CBBTC:", address(vaultCbbtc));
    }
}
