// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IChapterAchievementNFT - Soulbound chapter achievement tokens
/// @notice Interface for ERC-5192 compliant non-transferable chapter achievement NFTs
/// @dev Separate from personal journey achievements (IAchievementNFT)
interface IChapterAchievementNFT {
    // ==================== Events ====================

    /// @notice ERC-5192: Emitted when a token is locked (soulbound)
    event Locked(uint256 indexed tokenId);

    /// @notice Emitted when a chapter achievement is earned
    event ChapterAchievementEarned(
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

    /// @notice Achievement already earned by this wallet
    error AchievementAlreadyEarned(address wallet, bytes32 achievementId);

    // ==================== Admin Functions ====================

    /// @notice Authorize an address to mint achievements
    /// @param minter Address to authorize (typically ChapterMinter contract)
    function authorizeMinter(address minter) external;

    /// @notice Revoke minting authorization
    /// @param minter Address to revoke
    function revokeMinter(address minter) external;

    // ==================== Core Functions ====================

    /// @notice Mint a chapter achievement to a wallet
    /// @dev Can only be called by authorized minters
    /// @param to Wallet earning the achievement
    /// @param achievementId Achievement type identifier
    /// @param chapterId Chapter the achievement belongs to
    /// @return tokenId The minted token ID
    function mint(
        address to,
        bytes32 achievementId,
        bytes32 chapterId
    ) external returns (uint256 tokenId);

    // ==================== View Functions ====================

    /// @notice Check if a wallet has earned a specific achievement
    /// @param wallet Address to check
    /// @param achievementId Achievement type to query
    /// @return earned Whether the wallet has this achievement
    function hasAchievement(address wallet, bytes32 achievementId) external view returns (bool earned);

    /// @notice Get the achievement type for a token
    /// @param tokenId Token to query
    /// @return achievementId The achievement type
    function achievementType(uint256 tokenId) external view returns (bytes32 achievementId);

    /// @notice Get the chapter for a token
    /// @param tokenId Token to query
    /// @return chapterId The chapter ID
    function tokenChapter(uint256 tokenId) external view returns (bytes32 chapterId);

    /// @notice ERC-5192: Check if a token is locked (soulbound)
    /// @param tokenId Token to check
    /// @return locked Always true for soulbound tokens
    function locked(uint256 tokenId) external view returns (bool locked);

    /// @notice Check if an address is an authorized minter
    /// @param minter Address to check
    /// @return authorized Whether the address can mint
    function authorizedMinters(address minter) external view returns (bool authorized);

    /// @notice Get total supply of minted achievements
    /// @return supply Total tokens minted
    function totalSupply() external view returns (uint256 supply);
}
