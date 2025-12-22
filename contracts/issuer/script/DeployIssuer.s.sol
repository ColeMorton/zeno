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

        address vaultNFT = vm.envAddress("VAULT_NFT");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying issuer contracts with deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy AchievementNFT
        AchievementNFT achievement = new AchievementNFT(
            achievementName,
            achievementSymbol,
            achievementBaseURI
        );
        console.log("AchievementNFT deployed at:", address(achievement));

        // Deploy TreasureNFT
        TreasureNFT treasure = new TreasureNFT(treasureName, treasureSymbol, treasureBaseURI);
        console.log("TreasureNFT deployed at:", address(treasure));

        // Deploy AchievementMinter
        AchievementMinter minter = new AchievementMinter(
            address(achievement),
            address(treasure),
            vaultNFT
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
        console.log("VAULT_NFT:", vaultNFT);
    }
}
