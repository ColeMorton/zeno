// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HybridVaultNFT} from "../src/HybridVaultNFT.sol";
import {BtcToken} from "../src/BtcToken.sol";
import {MockTreasure} from "../test/mocks/MockTreasure.sol";
import {MockCBBTC} from "../test/mocks/MockCBBTC.sol";
import {MockWBTC} from "../test/mocks/MockWBTC.sol";

/// @title DeployHybrid
/// @notice Deploys HybridVaultNFT with cbBTC as primary and a mock LP token as secondary
contract DeployHybrid is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying HybridVaultNFT with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens
        MockTreasure treasure = new MockTreasure();
        console.log("MockTreasure deployed at:", address(treasure));

        MockCBBTC cbbtc = new MockCBBTC();
        console.log("MockCBBTC (primary) deployed at:", address(cbbtc));

        // Mock LP token (using MockWBTC as a generic ERC20)
        MockWBTC lpToken = new MockWBTC();
        console.log("MockLP (secondary) deployed at:", address(lpToken));

        // Predict hybrid vault address for BtcToken deployment
        uint256 nonce = vm.getNonce(deployer);
        address predictedHybridVault = vm.computeCreateAddress(deployer, nonce + 1);

        // Deploy BtcToken (vestedBTC for hybrid vault)
        BtcToken btcToken = new BtcToken(predictedHybridVault, "vestedBTC-Hybrid", "vHYBRID");
        console.log("BtcToken deployed at:", address(btcToken));

        // Deploy HybridVaultNFT
        HybridVaultNFT hybridVault = new HybridVaultNFT(
            address(btcToken),
            address(cbbtc),
            address(lpToken),
            "Hybrid Vault NFT",
            "HVAULT"
        );
        console.log("HybridVaultNFT deployed at:", address(hybridVault));

        require(address(hybridVault) == predictedHybridVault, "HybridVault address mismatch");

        // Mint tokens to deployer
        cbbtc.mint(deployer, 100 * 1e8);
        console.log("Minted 100 cbBTC to deployer");

        lpToken.mint(deployer, 100 * 1e18);
        console.log("Minted 100 LP tokens to deployer");

        treasure.mintBatch(deployer, 10);
        console.log("Minted 10 Treasure NFTs to deployer");

        vm.stopBroadcast();

        console.log("\n=== HybridVaultNFT Deployment Complete ===");
        console.log("TREASURE:", address(treasure));
        console.log("CBBTC (primary):", address(cbbtc));
        console.log("LP_TOKEN (secondary):", address(lpToken));
        console.log("BTC_TOKEN:", address(btcToken));
        console.log("HYBRID_VAULT:", address(hybridVault));
    }
}
