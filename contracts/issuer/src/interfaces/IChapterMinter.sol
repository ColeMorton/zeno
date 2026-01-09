// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IChapterMinter - Claims chapter achievements with time + journey gates
/// @notice Interface for claiming chapter achievements by verifying protocol state
/// @dev Enforces calendar time windows and personal journey progress gates
interface IChapterMinter {
    // ==================== Events ====================

    /// @notice Emitted when a chapter achievement is claimed
    event ChapterAchievementClaimed(
        address indexed wallet,
        bytes32 indexed achievementId,
        bytes32 indexed chapterId,
        uint256 vaultId
    );

    // ==================== Errors ====================

    /// @notice Chapter mint window has not opened yet
    error MintWindowNotOpen(bytes32 chapterId, uint48 startTimestamp);

    /// @notice Chapter mint window has closed (permanent)
    error MintWindowClosed(bytes32 chapterId, uint48 endTimestamp);

    /// @notice Chapter is not active (emergency pause)
    error ChapterNotActive(bytes32 chapterId);

    /// @notice Holder has not progressed far enough in their journey
    error JourneyProgressInsufficient(bytes32 chapterId, uint256 required, uint256 actual);

    /// @notice Holder has progressed beyond this chapter's range
    error JourneyProgressExceeded(bytes32 chapterId, uint256 maxAllowed, uint256 actual);

    /// @notice Required prerequisite achievement not earned
    error PrerequisiteNotMet(bytes32 achievementId, bytes32 prerequisite);

    /// @notice Caller does not own the vault
    error NotVaultOwner(uint256 vaultId, address caller);

    /// @notice Vault not using issuer's treasure contract
    error VaultNotUsingIssuerTreasure(uint256 vaultId, address treasureContract);

    /// @notice Unsupported collateral token
    error UnsupportedCollateral(address collateralToken);

    /// @notice Achievement-specific verification failed
    error AchievementVerificationFailed(bytes32 achievementId);

    /// @notice Zero address provided
    error ZeroAddress();

    /// @notice Achievement not part of specified chapter
    error AchievementNotInChapter(bytes32 achievementId, bytes32 chapterId);

    /// @notice Achievement has too many prerequisites
    error TooManyPrerequisites(bytes32 achievementId, uint256 count, uint256 max);

    // ==================== Core Functions ====================

    /// @notice Claim a chapter achievement
    /// @dev Verifies:
    ///      1. Calendar time window (startTimestamp <= now <= endTimestamp)
    ///      2. Journey gate (minDaysHeld <= daysHeld <= maxDaysHeld)
    ///      3. Prerequisites (all required achievements earned)
    ///      4. Vault ownership and issuer treasure
    ///      5. Achievement-specific verification (if verifier set)
    /// @param chapterId The chapter version ID
    /// @param achievementId The achievement to claim
    /// @param vaultId The vault ID to verify ownership
    /// @param collateralToken The collateral token to identify the protocol
    /// @param verificationData Optional data for achievement-specific verification
    function claimChapterAchievement(
        bytes32 chapterId,
        bytes32 achievementId,
        uint256 vaultId,
        address collateralToken,
        bytes calldata verificationData
    ) external;

    // ==================== View Functions ====================

    /// @notice Check if a wallet can claim a chapter achievement
    /// @param wallet Address to check
    /// @param chapterId Chapter version ID
    /// @param achievementId Achievement to claim
    /// @param vaultId Vault to verify
    /// @param collateralToken Collateral token for protocol lookup
    /// @param verificationData Optional data for achievement-specific verification
    /// @return canClaim Whether the achievement can be claimed
    /// @return reason Failure reason if cannot claim
    function canClaimChapterAchievement(
        address wallet,
        bytes32 chapterId,
        bytes32 achievementId,
        uint256 vaultId,
        address collateralToken,
        bytes calldata verificationData
    ) external view returns (bool canClaim, string memory reason);

    /// @notice Get all claimable achievements for a wallet in a chapter
    /// @param wallet Address to check
    /// @param chapterId Chapter version ID
    /// @param vaultId Vault to verify
    /// @param collateralToken Collateral token for protocol lookup
    /// @return claimable Array of claimable achievement IDs
    function getClaimableAchievements(
        address wallet,
        bytes32 chapterId,
        uint256 vaultId,
        address collateralToken
    ) external view returns (bytes32[] memory claimable);
}
