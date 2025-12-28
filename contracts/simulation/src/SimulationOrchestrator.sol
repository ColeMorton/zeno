// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";

import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementNFT} from "@issuer/AchievementNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title MockWBTC - ERC20 mock for simulation
/// @dev 8 decimals to match real WBTC
contract MockWBTC is ERC20 {
    constructor() ERC20("Wrapped BTC", "WBTC") {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title IssuerDeployment - Container for issuer contract addresses
struct IssuerDeployment {
    TreasureNFT treasureNFT;
    AchievementNFT achievementNFT;
    AchievementMinter minter;
    string name;
}

/// @title ProtocolDeployment - Container for protocol contract addresses
struct ProtocolDeployment {
    VaultNFT vault;
    BtcToken btcToken;
    MockWBTC wbtc;
}

/// @title SimulationOrchestrator - Deploys protocol + issuers for simulation
/// @notice Central controller for cross-layer integration testing
/// @dev Not upgradeable - designed for test environments only
contract SimulationOrchestrator {
    // ==================== State ====================

    ProtocolDeployment public protocol;
    IssuerDeployment[] public issuers;

    uint256 internal constant ONE_BTC = 1e8;

    // ==================== Events ====================

    event ProtocolDeployed(address vault, address btcToken, address wbtc);
    event IssuerDeployed(uint256 indexed issuerId, string name, address minter);
    event ActorFunded(address indexed actor, uint256 wbtcAmount, uint256 treasureCount);

    // ==================== Protocol Deployment ====================

    /// @notice Deploy the core protocol stack
    /// @return vault The deployed VaultNFT
    /// @return btcToken The deployed BtcToken
    /// @return wbtc The deployed MockWBTC
    function deployProtocol() external returns (VaultNFT vault, BtcToken btcToken, MockWBTC wbtc) {
        require(address(protocol.vault) == address(0), "Protocol already deployed");

        // Deploy mock WBTC
        wbtc = new MockWBTC();

        // Compute predicted vault address for BtcToken initialization
        // Contract nonces start at 1 (EIP-161), so after deploying WBTC (nonce 1),
        // BtcToken will use nonce 2, and VaultNFT will use nonce 3
        address predictedVault = _computeCreateAddress(address(this), 3);

        // Deploy BtcToken with predicted vault address
        btcToken = new BtcToken(predictedVault, "Vested BTC", "vBTC");

        // Deploy VaultNFT with BtcToken and single collateral token
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT", "VAULT");

        require(address(vault) == predictedVault, "Vault address mismatch");

        // Store deployment
        protocol = ProtocolDeployment({
            vault: vault,
            btcToken: btcToken,
            wbtc: wbtc
        });

        emit ProtocolDeployed(address(vault), address(btcToken), address(wbtc));
    }

    // ==================== Issuer Deployment ====================

    /// @notice Deploy a new issuer stack
    /// @param name Issuer name for identification
    /// @return issuerId Index of the deployed issuer
    /// @return minter The deployed AchievementMinter
    function deployIssuer(string memory name) external returns (uint256 issuerId, AchievementMinter minter) {
        require(address(protocol.vault) != address(0), "Deploy protocol first");

        // Deploy issuer treasure NFT
        TreasureNFT treasureNFT = new TreasureNFT(
            string.concat(name, " Treasure"),
            string.concat(name, "_TRS"),
            ""
        );

        // Deploy achievement NFT (on-chain SVG disabled for testing simplicity)
        AchievementNFT achievementNFT = new AchievementNFT(
            string.concat(name, " Achievement"),
            string.concat(name, "_ACH"),
            "",
            false
        );

        // Deploy achievement minter with single collateral token mapping to single protocol
        address[] memory collateralTokens = new address[](1);
        collateralTokens[0] = address(protocol.wbtc);
        address[] memory protocols = new address[](1);
        protocols[0] = address(protocol.vault);

        minter = new AchievementMinter(
            address(achievementNFT),
            address(treasureNFT),
            collateralTokens,
            protocols
        );

        // Configure permissions
        achievementNFT.authorizeMinter(address(minter));
        treasureNFT.authorizeMinter(address(minter));

        // Store deployment
        issuerId = issuers.length;
        issuers.push(IssuerDeployment({
            treasureNFT: treasureNFT,
            achievementNFT: achievementNFT,
            minter: minter,
            name: name
        }));

        emit IssuerDeployed(issuerId, name, address(minter));
    }

    // ==================== Actor Funding ====================

    /// @notice Fund an actor with WBTC and Treasure NFTs
    /// @param actor Address to fund
    /// @param wbtcAmount Amount of WBTC to mint (in satoshis)
    /// @param issuerId Which issuer's treasure to mint
    /// @param treasureCount Number of treasure NFTs to mint
    function fundActor(
        address actor,
        uint256 wbtcAmount,
        uint256 issuerId,
        uint256 treasureCount
    ) external {
        require(address(protocol.vault) != address(0), "Deploy protocol first");
        require(issuerId < issuers.length, "Invalid issuer ID");

        // Mint WBTC
        protocol.wbtc.mint(actor, wbtcAmount);

        // Mint treasure NFTs
        IssuerDeployment storage issuer = issuers[issuerId];
        for (uint256 i = 0; i < treasureCount; i++) {
            issuer.treasureNFT.mint(actor);
        }

        emit ActorFunded(actor, wbtcAmount, treasureCount);
    }

    // ==================== View Functions ====================

    /// @notice Get the number of deployed issuers
    function issuerCount() external view returns (uint256) {
        return issuers.length;
    }

    /// @notice Get issuer deployment by ID
    function getIssuer(uint256 issuerId) external view returns (
        address treasureNFT,
        address achievementNFT,
        address minter,
        string memory name
    ) {
        require(issuerId < issuers.length, "Invalid issuer ID");
        IssuerDeployment storage issuer = issuers[issuerId];
        return (
            address(issuer.treasureNFT),
            address(issuer.achievementNFT),
            address(issuer.minter),
            issuer.name
        );
    }

    // ==================== Internal Helpers ====================

    /// @dev Compute CREATE address for nonce prediction
    function _computeCreateAddress(address deployer, uint256 nonce) internal pure returns (address) {
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }
}
