// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VaultNFT} from "../src/VaultNFT.sol";
import {BtcToken} from "../src/BtcToken.sol";
import {MockTreasure} from "../test/mocks/MockTreasure.sol";
import {MockWBTC} from "../test/mocks/MockWBTC.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        MockWBTC wbtc = new MockWBTC();
        console.log("MockWBTC deployed at:", address(wbtc));

        MockTreasure treasure = new MockTreasure();
        console.log("MockTreasure deployed at:", address(treasure));

        uint256 nonce = vm.getNonce(deployer);
        address predictedVault = vm.computeCreateAddress(deployer, nonce + 1);

        BtcToken btcToken = new BtcToken(predictedVault, "vestedBTC-wBTC", "vWBTC");
        console.log("BtcToken deployed at:", address(btcToken));

        VaultNFT vault = new VaultNFT(
            address(btcToken),
            address(wbtc),
            "Vault NFT-wBTC",
            "VAULT-W"
        );
        console.log("VaultNFT deployed at:", address(vault));

        require(address(vault) == predictedVault, "Vault address mismatch");

        wbtc.mint(deployer, 100 * 1e8);
        console.log("Minted 100 WBTC to deployer");

        treasure.mintBatch(deployer, 10);
        console.log("Minted 10 Treasure NFTs to deployer");

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("WBTC:", address(wbtc));
        console.log("TREASURE:", address(treasure));
        console.log("BTC_TOKEN:", address(btcToken));
        console.log("VAULT:", address(vault));
    }
}
