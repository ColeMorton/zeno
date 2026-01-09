// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AchievementNFT} from "../src/AchievementNFT.sol";
import {TreasureNFT} from "../src/TreasureNFT.sol";
import {AchievementMinter} from "../src/AchievementMinter.sol";

/// @notice Deployment script for issuer contracts
/// @dev Requires environment variables for configuration
contract DeployIssuer is Script {
    function run() external {
        // Load configuration from environment
        string memory achievementName = vm.envString("ACHIEVEMENT_NAME");
        string memory achievementSymbol = vm.envString("ACHIEVEMENT_SYMBOL");
        string memory achievementBaseURI = vm.envString("ACHIEVEMENT_BASE_URI");

        string memory treasureName = vm.envString("TREASURE_NAME");
        string memory treasureSymbol = vm.envString("TREASURE_SYMBOL");
        string memory treasureBaseURI = vm.envString("TREASURE_BASE_URI");

        // Load protocol addresses for each collateral type
        address wbtc = vm.envAddress("WBTC");
        address cbbtc = vm.envAddress("CBBTC");
        address tbtc = vm.envAddress("TBTC");
        address vaultWBTC = vm.envAddress("VAULT_WBTC");
        address vaultCBBTC = vm.envAddress("VAULT_CBBTC");
        address vaultTBTC = vm.envAddress("VAULT_TBTC");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying issuer contracts with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy AchievementNFT (with on-chain SVG enabled by default)
        AchievementNFT achievement = new AchievementNFT(
            achievementName,
            achievementSymbol,
            achievementBaseURI,
            true
        );
        console.log("AchievementNFT deployed at:", address(achievement));

        // Deploy TreasureNFT (use first vault as protocol reference)
        TreasureNFT treasure = new TreasureNFT(treasureName, treasureSymbol, treasureBaseURI, vaultWBTC);
        console.log("TreasureNFT deployed at:", address(treasure));

        // Prepare collateral and protocol arrays
        address[] memory collaterals = new address[](3);
        collaterals[0] = wbtc;
        collaterals[1] = cbbtc;
        collaterals[2] = tbtc;

        address[] memory protocols = new address[](3);
        protocols[0] = vaultWBTC;
        protocols[1] = vaultCBBTC;
        protocols[2] = vaultTBTC;

        // Deploy AchievementMinter
        AchievementMinter minter = new AchievementMinter(
            address(achievement),
            address(treasure),
            collaterals,
            protocols
        );
        console.log("AchievementMinter deployed at:", address(minter));

        // Configure permissions
        achievement.authorizeMinter(address(minter));
        console.log("AchievementMinter authorized on AchievementNFT");

        treasure.authorizeMinter(address(minter));
        console.log("AchievementMinter authorized on TreasureNFT");

        vm.stopBroadcast();

        console.log("\n=== Issuer Deployment Complete ===");
        console.log("ACHIEVEMENT_NFT:", address(achievement));
        console.log("TREASURE_NFT:", address(treasure));
        console.log("ACHIEVEMENT_MINTER:", address(minter));
        console.log("VAULT_WBTC:", vaultWBTC);
        console.log("VAULT_CBBTC:", vaultCBBTC);
        console.log("VAULT_TBTC:", vaultTBTC);
    }
}
