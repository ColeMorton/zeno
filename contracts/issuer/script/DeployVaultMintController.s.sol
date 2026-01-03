// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VaultMintController} from "../src/VaultMintController.sol";
import {TreasureNFT} from "../src/TreasureNFT.sol";

/// @notice Deployment script for VaultMintController
/// @dev Requires TREASURE_NFT, VAULT_NFT, and COLLATERAL_TOKEN env vars
/// @dev Set SKIP_AUTHORIZE=true for local dev with MockTreasure (permissionless minting)
contract DeployVaultMintController is Script {
    function run() external {
        address treasureNFT = vm.envAddress("TREASURE_NFT");
        address vaultNFT = vm.envAddress("VAULT_NFT");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");
        bool skipAuthorize = vm.envOr("SKIP_AUTHORIZE", false);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying VaultMintController with deployer:", deployer);
        console.log("TreasureNFT:", treasureNFT);
        console.log("VaultNFT:", vaultNFT);
        console.log("CollateralToken:", collateralToken);

        vm.startBroadcast(deployerPrivateKey);

        VaultMintController controller = new VaultMintController(
            treasureNFT,
            vaultNFT,
            collateralToken
        );
        console.log("VaultMintController deployed at:", address(controller));

        // Authorize controller as minter on TreasureNFT (skip for MockTreasure in local dev)
        if (!skipAuthorize) {
            TreasureNFT(treasureNFT).authorizeMinter(address(controller));
            console.log("VaultMintController authorized as minter on TreasureNFT");
        } else {
            console.log("Skipping authorizeMinter (SKIP_AUTHORIZE=true)");
        }

        vm.stopBroadcast();

        console.log("\n=== VaultMintController Deployment Complete ===");
        console.log("VAULT_MINT_CONTROLLER:", address(controller));
    }
}
