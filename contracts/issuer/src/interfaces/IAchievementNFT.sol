// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IAchievementNFT - Unified interface for soulbound achievement NFTs
/// @notice ERC-5192 compliant non-transferable NFT for both regular and chapter achievements
/// @dev Supports stackable achievements, chapter association, and count tracking
///      Regular achievements use chapterId = bytes32(0)
interface IAchievementNFT is IERC721 {
    // ==================== Events ====================

    /// @notice ERC-5192: Emitted when a token is locked (soulbound)
    event Locked(uint256 indexed tokenId);

    /// @notice Emitted when an achievement is earned
    event AchievementEarned(
        address indexed wallet,
        uint256 indexed tokenId,
        bytes32 indexed achievementId,
        bytes32 chapterId
    );

    /// @notice Emitted when a minter is authorized
    event MinterAuthorized(address indexed minter);

    /// @notice Emitted when a minter is revoked
    event MinterRevoked(address indexed minter);

    // ==================== Errors ====================

    /// @notice Transfer not allowed (soulbound)
    error SoulboundTransferNotAllowed();

    /// @notice Caller is not an authorized minter
    error NotAuthorizedMinter(address caller);

    /// @notice Non-stackable achievement already earned by this wallet
    error AchievementAlreadyEarned(address wallet, bytes32 achievementId);

    // ==================== Admin Functions ====================

    /// @notice Authorize an address to mint achievements
    /// @param minter Address to authorize
    function authorizeMinter(address minter) external;

    /// @notice Revoke minting authorization
    /// @param minter Address to revoke
    function revokeMinter(address minter) external;

    // ==================== Core Functions ====================

    /// @notice Mint an achievement to a wallet
    /// @dev Can only be called by authorized minters
    /// @param to Wallet earning the achievement
    /// @param achievementId Achievement type identifier
    /// @param chapterId Chapter ID (bytes32(0) for non-chapter achievements)
    /// @param isStackable Whether this achievement can be earned multiple times
    /// @return tokenId The minted token ID
    function mint(
        address to,
        bytes32 achievementId,
        bytes32 chapterId,
        bool isStackable
    ) external returns (uint256 tokenId);

    // ==================== View Functions ====================

    /// @notice Check if a wallet has earned a specific achievement
    /// @param wallet Address to check
    /// @param achievementId Achievement type to query
    /// @return earned Whether the wallet has this achievement
    function hasAchievement(address wallet, bytes32 achievementId) external view returns (bool earned);

    /// @notice Get the number of times a wallet has earned an achievement
    /// @param wallet Address to check
    /// @param achievementId Achievement type to query
    /// @return count Number of times earned (0 if never earned)
    function achievementCount(address wallet, bytes32 achievementId) external view returns (uint256 count);

    /// @notice Get the achievement type for a token
    /// @param tokenId Token to query
    /// @return achievementId The achievement type
    function achievementType(uint256 tokenId) external view returns (bytes32 achievementId);

    /// @notice Get the chapter for a token
    /// @param tokenId Token to query
    /// @return chapterId The chapter ID (bytes32(0) for non-chapter achievements)
    function tokenChapter(uint256 tokenId) external view returns (bytes32 chapterId);

    /// @notice ERC-5192: Check if a token is locked (soulbound)
    /// @param tokenId Token to check
    /// @return Always true for soulbound tokens
    function locked(uint256 tokenId) external view returns (bool);

    /// @notice Check if an address is an authorized minter
    /// @param minter Address to check
    /// @return Whether the address can mint
    function authorizedMinters(address minter) external view returns (bool);

    /// @notice Get total supply of minted achievements
    /// @return Total tokens minted
    function totalSupply() external view returns (uint256);

    /// @notice Check if using on-chain SVG
    /// @return Whether on-chain SVG is enabled
    function useOnChainSVG() external view returns (bool);

    /// @notice Toggle between on-chain SVG and external URI
    /// @param useOnChain Whether to use on-chain SVG
    function setUseOnChainSVG(bool useOnChain) external;
}
