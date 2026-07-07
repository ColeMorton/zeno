// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VaultNFT} from "../src/VaultNFT.sol";
import {VestingEscrow} from "../src/VestingEscrow.sol";
import {BtcToken} from "../src/BtcToken.sol";
import {MockTreasure} from "../test/mocks/MockTreasure.sol";
import {MockCBBTC} from "../test/mocks/MockCBBTC.sol";
import {MockWBTC} from "../test/mocks/MockWBTC.sol";

/// @title DeployHybrid
/// @notice Deploys the dual-collateral composition: VaultNFT (cbBTC primary leg) plus a
/// VestingEscrow holding a mock LP token as the secondary leg.
contract DeployHybrid is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying hybrid composition with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens
        MockTreasure treasure = new MockTreasure();
        console.log("MockTreasure deployed at:", address(treasure));

        MockCBBTC cbbtc = new MockCBBTC();
        console.log("MockCBBTC (primary) deployed at:", address(cbbtc));

        // Mock LP token (using MockWBTC as a generic ERC20)
        MockWBTC lpToken = new MockWBTC();
        console.log("MockLP (secondary) deployed at:", address(lpToken));

        // Predict vault address for BtcToken deployment
        uint256 nonce = vm.getNonce(deployer);
        address predictedVault = vm.computeCreateAddress(deployer, nonce + 1);

        // Deploy BtcToken (vestedBTC for the vault)
        BtcToken btcToken = new BtcToken(predictedVault, "vestedBTC-Hybrid", "vHYBRID");
        console.log("BtcToken deployed at:", address(btcToken));

        // Deploy VaultNFT (primary leg)
        VaultNFT vault = new VaultNFT(
            address(btcToken),
            address(cbbtc),
            "Hybrid Vault NFT",
            "HVAULT"
        );
        console.log("VaultNFT deployed at:", address(vault));

        require(address(vault) == predictedVault, "Vault address mismatch");

        // Deploy VestingEscrow (secondary leg)
        VestingEscrow escrow = new VestingEscrow(address(vault), address(lpToken));
        console.log("VestingEscrow deployed at:", address(escrow));

        // Mint tokens to deployer
        cbbtc.mint(deployer, 100 * 1e8);
        console.log("Minted 100 cbBTC to deployer");

        lpToken.mint(deployer, 100 * 1e18);
        console.log("Minted 100 LP tokens to deployer");

        treasure.mintBatch(deployer, 10);
        console.log("Minted 10 Treasure NFTs to deployer");

        vm.stopBroadcast();

        console.log("\n=== Hybrid Composition Deployment Complete ===");
        console.log("TREASURE:", address(treasure));
        console.log("CBBTC (primary):", address(cbbtc));
        console.log("LP_TOKEN (secondary):", address(lpToken));
        console.log("BTC_TOKEN:", address(btcToken));
        console.log("VAULT:", address(vault));
        console.log("VESTING_ESCROW:", address(escrow));
    }
}
