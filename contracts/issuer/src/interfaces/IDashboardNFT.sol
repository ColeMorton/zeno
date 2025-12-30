// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IDashboardNFT - Interface for revenue-generating UI unlock NFTs
/// @notice ERC-721 + ERC-2981 with paid minting for dashboard feature unlocks
/// @dev Uses bytes32 identifiers for extensibility without contract redeployment
interface IDashboardNFT is IERC721 {
    // ═══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a feature NFT is minted
    event FeatureMinted(
        address indexed wallet,
        uint256 indexed tokenId,
        bytes32 indexed featureType,
        uint256 price
    );

    /// @notice Emitted when a feature price is updated
    event FeaturePriceSet(bytes32 indexed featureType, uint256 price);

    /// @notice Emitted when a feature is activated or deactivated
    event FeatureActiveSet(bytes32 indexed featureType, bool active);

    /// @notice Emitted when revenue receiver is updated
    event RevenueReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    /// @notice Emitted when funds are withdrawn
    event FundsWithdrawn(address indexed receiver, uint256 amount);

    // ═══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Feature type is not active for minting
    error FeatureNotActive(bytes32 featureType);

    /// @notice Feature type has no price configured
    error FeatureNotConfigured(bytes32 featureType);

    /// @notice Payment is less than required mint price
    error InsufficientPayment(uint256 required, uint256 provided);

    /// @notice No funds available to withdraw
    error NoFundsToWithdraw();

    /// @notice ETH transfer failed
    error WithdrawFailed();

    /// @notice Zero address provided
    error ZeroAddress();

    // ═══════════════════════════════════════════════════════════════════════════════
    // MINT
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Mint a feature NFT with payment
    /// @param featureType_ The feature type to mint
    /// @return tokenId The minted token ID
    function mint(bytes32 featureType_) external payable returns (uint256 tokenId);

    // ═══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Check if a wallet owns any token of a specific feature type
    /// @param wallet Address to check
    /// @param featureType_ Feature type to query
    /// @return Whether the wallet has this feature
    function hasFeature(address wallet, bytes32 featureType_) external view returns (bool);

    /// @notice Get the feature type for a token
    /// @param tokenId Token ID to query
    /// @return The feature type (bytes32 identifier)
    function featureType(uint256 tokenId) external view returns (bytes32);

    /// @notice Get the mint price for a feature type
    /// @param featureType_ Feature type to query
    /// @return Price in wei
    function mintPrice(bytes32 featureType_) external view returns (uint256);

    /// @notice Check if a feature type is active for minting
    /// @param featureType_ Feature type to query
    /// @return Whether the feature is active
    function featureActive(bytes32 featureType_) external view returns (bool);

    /// @notice Get the revenue receiver address
    /// @return The address receiving mint fees and royalties
    function revenueReceiver() external view returns (address);

    /// @notice Get total supply of Dashboard NFTs
    /// @return Total number minted
    function totalSupply() external view returns (uint256);

    // ═══════════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Set the mint price for a feature type
    /// @param featureType_ Feature type to configure
    /// @param price Price in wei
    function setMintPrice(bytes32 featureType_, uint256 price) external;

    /// @notice Activate or deactivate a feature for minting
    /// @param featureType_ Feature type to configure
    /// @param active Whether minting is enabled
    function setFeatureActive(bytes32 featureType_, bool active) external;

    /// @notice Update the revenue receiver address
    /// @param receiver New receiver address
    function setRevenueReceiver(address receiver) external;

    /// @notice Withdraw accumulated funds to revenue receiver
    function withdraw() external;

    // ═══════════════════════════════════════════════════════════════════════════════
    // FEATURE TYPE CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════════

    // Cosmetic features
    function THEME_DARK() external view returns (bytes32);
    function THEME_NEON() external view returns (bytes32);
    function FRAME_ANIMATED() external view returns (bytes32);
    function AVATAR_CUSTOM() external view returns (bytes32);

    // Functional features
    function ANALYTICS_PRO() external view returns (bytes32);
    function EXPORT_CSV() external view returns (bytes32);
    function ALERTS_ADVANCED() external view returns (bytes32);
    function PORTFOLIO_MULTI() external view returns (bytes32);

    // Bundle
    function FOUNDERS_BUNDLE() external view returns (bytes32);
}
