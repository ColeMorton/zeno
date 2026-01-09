// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVaultState - Unified interface for protocol vault state verification
/// @notice Used by issuer-layer contracts to query protocol vault state
/// @dev Consolidates all read methods needed by AchievementMinter, ChapterMinter, etc.
interface IVaultState {
    /// @notice Get the owner of a vault token
    /// @param tokenId The vault token ID
    /// @return The owner address
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Get the treasure contract address for a vault
    /// @param tokenId The vault token ID
    /// @return The treasure contract address
    function treasureContract(uint256 tokenId) external view returns (address);

    /// @notice Get the mint timestamp for a vault
    /// @param tokenId The vault token ID
    /// @return The timestamp when the vault was minted
    function mintTimestamp(uint256 tokenId) external view returns (uint256);

    /// @notice Check if a vault has completed vesting
    /// @param tokenId The vault token ID
    /// @return True if the vault is vested
    function isVested(uint256 tokenId) external view returns (bool);

    /// @notice Check if a vault's match pool claim has been claimed
    /// @param tokenId The vault token ID
    /// @return True if the match was claimed
    function matchClaimed(uint256 tokenId) external view returns (bool);
}

/// @title IVaultMint - Interface for protocol vault minting
/// @notice Used by issuer-layer contracts to mint protocol vaults
/// @dev Separated from IVaultState for single-responsibility (query vs. mutate)
interface IVaultMint {
    /// @notice Mint a new vault NFT
    /// @param treasureContract The treasure NFT contract address
    /// @param treasureTokenId The treasure NFT token ID
    /// @param collateralToken The collateral ERC-20 token address
    /// @param collateralAmount The amount of collateral to deposit
    /// @return tokenId The minted vault token ID
    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 tokenId);
}

/// @title IVaultStateAndMint - Combined interface for full vault interaction
/// @notice Convenience interface extending both IVaultState and IVaultMint
/// @dev Use when both read and write access is needed
interface IVaultStateAndMint is IVaultState, IVaultMint {}
