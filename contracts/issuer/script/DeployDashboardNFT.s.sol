// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DashboardNFT} from "../src/DashboardNFT.sol";

/// @notice Deployment script for DashboardNFT
/// @dev Configures feature prices and activates features
contract DeployDashboardNFT is Script {
    function run() external {
        // Load configuration from environment
        string memory name = vm.envOr("DASHBOARD_NAME", string("Dashboard NFT"));
        string memory symbol = vm.envOr("DASHBOARD_SYMBOL", string("DASH"));
        string memory baseURI = vm.envOr("DASHBOARD_BASE_URI", string("https://api.example.com/dashboard/"));
        address revenueReceiver = vm.envAddress("REVENUE_RECEIVER");
        uint96 royaltyBps = uint96(vm.envOr("ROYALTY_BPS", uint256(500))); // Default 5%

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying DashboardNFT with deployer:", deployer);
        console.log("Revenue receiver:", revenueReceiver);
        console.log("Royalty (bps):", royaltyBps);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DashboardNFT
        DashboardNFT dashboard = new DashboardNFT(name, symbol, baseURI, revenueReceiver, royaltyBps);
        console.log("DashboardNFT deployed at:", address(dashboard));

        // Configure cosmetic feature prices (lower tier)
        dashboard.setMintPrice(dashboard.THEME_DARK(), 0.002 ether);
        dashboard.setMintPrice(dashboard.THEME_NEON(), 0.002 ether);
        dashboard.setMintPrice(dashboard.FRAME_ANIMATED(), 0.003 ether);
        dashboard.setMintPrice(dashboard.AVATAR_CUSTOM(), 0.001 ether);

        // Configure functional feature prices (higher tier)
        dashboard.setMintPrice(dashboard.ANALYTICS_PRO(), 0.01 ether);
        dashboard.setMintPrice(dashboard.EXPORT_CSV(), 0.005 ether);
        dashboard.setMintPrice(dashboard.ALERTS_ADVANCED(), 0.008 ether);
        dashboard.setMintPrice(dashboard.PORTFOLIO_MULTI(), 0.015 ether);

        // Configure bundle price (discounted)
        dashboard.setMintPrice(dashboard.FOUNDERS_BUNDLE(), 0.03 ether);

        console.log("Feature prices configured");

        // Activate all features for minting
        dashboard.setFeatureActive(dashboard.THEME_DARK(), true);
        dashboard.setFeatureActive(dashboard.THEME_NEON(), true);
        dashboard.setFeatureActive(dashboard.FRAME_ANIMATED(), true);
        dashboard.setFeatureActive(dashboard.AVATAR_CUSTOM(), true);
        dashboard.setFeatureActive(dashboard.ANALYTICS_PRO(), true);
        dashboard.setFeatureActive(dashboard.EXPORT_CSV(), true);
        dashboard.setFeatureActive(dashboard.ALERTS_ADVANCED(), true);
        dashboard.setFeatureActive(dashboard.PORTFOLIO_MULTI(), true);
        dashboard.setFeatureActive(dashboard.FOUNDERS_BUNDLE(), true);

        console.log("All features activated");

        vm.stopBroadcast();

        console.log("\n=== DashboardNFT Deployment Complete ===");
        console.log("DASHBOARD_NFT:", address(dashboard));
        console.log("REVENUE_RECEIVER:", revenueReceiver);
        console.log("\nFeature Prices:");
        console.log("  THEME_DARK: 0.002 ETH");
        console.log("  THEME_NEON: 0.002 ETH");
        console.log("  FRAME_ANIMATED: 0.003 ETH");
        console.log("  AVATAR_CUSTOM: 0.001 ETH");
        console.log("  ANALYTICS_PRO: 0.01 ETH");
        console.log("  EXPORT_CSV: 0.005 ETH");
        console.log("  ALERTS_ADVANCED: 0.008 ETH");
        console.log("  PORTFOLIO_MULTI: 0.015 ETH");
        console.log("  FOUNDERS_BUNDLE: 0.03 ETH");
    }
}
