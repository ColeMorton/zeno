// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title ITreasureNFT - Interface for issuer-branded treasure NFTs
/// @notice ERC-721 with tier-based visuals derived from vault collateral percentile
interface ITreasureNFT is IERC721 {
    // ==================== Enums ====================

    /// @notice Tier levels based on collateral percentile
    enum Tier { Bronze, Silver, Gold, Platinum, Diamond }

    // ==================== Events ====================

    /// @notice ERC-4906: Emitted when metadata for a token is updated
    event MetadataUpdate(uint256 indexed tokenId);

    /// @notice ERC-4906: Emitted when metadata for a range of tokens is updated
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);

    /// @notice Emitted when thresholds are updated
    event ThresholdsUpdated(uint256 silver, uint256 gold, uint256 platinum, uint256 diamond);

    /// @notice Emitted when a treasure is linked to a vault
    event VaultLinked(uint256 indexed treasureTokenId, uint256 indexed vaultId);

    // ==================== Errors ====================

    /// @notice Caller is not an authorized minter
    error NotAuthorizedMinter(address caller);

    /// @notice Caller is not the keeper
    error NotKeeper(address caller);

    /// @notice Treasure already linked to a vault
    error AlreadyLinkedToVault(uint256 treasureTokenId);

    // ==================== Core Functions ====================

    /// @notice Mint a new Treasure NFT
    /// @param to Recipient address
    /// @return tokenId The minted token ID
    function mint(address to) external returns (uint256 tokenId);

    /// @notice Mint multiple Treasure NFTs to the same address
    /// @param to Recipient address
    /// @param count Number of tokens to mint
    /// @return tokenIds The minted token IDs
    function mintBatch(address to, uint256 count) external returns (uint256[] memory tokenIds);

    /// @notice Link a treasure to its containing vault
    /// @dev Called by minter when treasure is deposited into vault
    /// @param treasureTokenId The treasure token ID
    /// @param vaultId The vault token ID that now holds this treasure
    function linkToVault(uint256 treasureTokenId, uint256 vaultId) external;

    // ==================== Admin Functions ====================

    /// @notice Authorize an address to mint Treasure NFTs
    /// @param minter Address to authorize
    function authorizeMinter(address minter) external;

    /// @notice Revoke minting authorization
    /// @param minter Address to revoke
    function revokeMinter(address minter) external;

    /// @notice Update percentile thresholds for tier computation
    /// @dev Called by keeper to update distribution-based thresholds
    /// @param silver Collateral amount for 50th percentile
    /// @param gold Collateral amount for 75th percentile
    /// @param platinum Collateral amount for 90th percentile
    /// @param diamond Collateral amount for 99th percentile
    function updateThresholds(
        uint256 silver,
        uint256 gold,
        uint256 platinum,
        uint256 diamond
    ) external;

    // ==================== View Functions ====================

    /// @notice Check if an address is an authorized minter
    /// @param minter Address to check
    /// @return Whether the address is authorized
    function authorizedMinters(address minter) external view returns (bool);

    /// @notice Get total supply of Treasure NFTs
    /// @return Total number of Treasure NFTs minted
    function totalSupply() external view returns (uint256);

    /// @notice Get the vault ID that holds this treasure
    /// @param treasureTokenId The treasure token ID
    /// @return vaultId The vault token ID (0 if not linked)
    function treasureVault(uint256 treasureTokenId) external view returns (uint256 vaultId);

    /// @notice Compute tier from collateral amount
    /// @param collateral The collateral amount in wei
    /// @return tier The computed tier
    function computeTier(uint256 collateral) external view returns (Tier tier);

    /// @notice Get the tier for a specific treasure
    /// @param treasureTokenId The treasure token ID
    /// @return tier The current tier based on vault collateral
    function getTier(uint256 treasureTokenId) external view returns (Tier tier);
}
