// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IChapterMinter} from "./interfaces/IChapterMinter.sol";
import {IChapterRegistry} from "./interfaces/IChapterRegistry.sol";
import {IAchievementNFT} from "./interfaces/IAchievementNFT.sol";
import {ITreasureNFT} from "./interfaces/ITreasureNFT.sol";
import {IAchievementVerifier} from "./interfaces/IAchievementVerifier.sol";

/// @notice Minimal interface for protocol vault state verification
interface IVaultState {
    function ownerOf(uint256 tokenId) external view returns (address);
    function treasureContract(uint256 tokenId) external view returns (address);
    function mintTimestamp(uint256 tokenId) external view returns (uint256);
}

/// @title ChapterMinter - Claims chapter achievements with time + journey gates
/// @notice Verifies protocol state and enforces eligibility before minting chapter achievements
/// @dev Enforces calendar time windows and personal journey progress gates
contract ChapterMinter is IChapterMinter, Ownable {
    // ==================== State Variables ====================

    IAchievementNFT public immutable achievements;
    IChapterRegistry public immutable registry;
    ITreasureNFT public immutable treasureNFT;

    /// @notice Mapping of collateral token to protocol address
    mapping(address => IVaultState) public protocols;

    // ==================== Constructor ====================

    constructor(
        address achievements_,
        address registry_,
        address treasureNFT_,
        address[] memory collateralTokens_,
        address[] memory protocols_
    ) Ownable(msg.sender) {
        achievements = IAchievementNFT(achievements_);
        registry = IChapterRegistry(registry_);
        treasureNFT = ITreasureNFT(treasureNFT_);

        for (uint256 i = 0; i < collateralTokens_.length; i++) {
            protocols[collateralTokens_[i]] = IVaultState(protocols_[i]);
        }
    }

    // ==================== Core Functions ====================

    /// @inheritdoc IChapterMinter
    function claimChapterAchievement(
        bytes32 chapterId,
        bytes32 achievementId,
        uint256 vaultId,
        address collateralToken,
        bytes calldata verificationData
    ) external {
        IVaultState selectedProtocol = protocols[collateralToken];
        if (address(selectedProtocol) == address(0)) {
            revert UnsupportedCollateral(collateralToken);
        }

        // Get chapter config
        IChapterRegistry.ChapterConfig memory config = registry.getChapter(chapterId);

        // 1. Time window check (calendar quarter)
        if (block.timestamp < config.startTimestamp) {
            revert MintWindowNotOpen(chapterId, config.startTimestamp);
        }
        if (block.timestamp > config.endTimestamp) {
            revert MintWindowClosed(chapterId, config.endTimestamp);
        }
        if (!config.active) {
            revert ChapterNotActive(chapterId);
        }

        // 2. Verify caller owns the vault
        if (selectedProtocol.ownerOf(vaultId) != msg.sender) {
            revert NotVaultOwner(vaultId, msg.sender);
        }

        // 3. Verify vault contains issuer's treasure
        address vaultTreasure = selectedProtocol.treasureContract(vaultId);
        if (vaultTreasure != address(treasureNFT)) {
            revert VaultNotUsingIssuerTreasure(vaultId, vaultTreasure);
        }

        // 4. Journey gate check (hybrid eligibility - must be within chapter's day range)
        uint256 daysHeld = (block.timestamp - selectedProtocol.mintTimestamp(vaultId)) / 1 days;
        if (daysHeld < config.minDaysHeld) {
            revert JourneyProgressInsufficient(chapterId, config.minDaysHeld, daysHeld);
        }
        if (daysHeld > config.maxDaysHeld) {
            revert JourneyProgressExceeded(chapterId, config.maxDaysHeld, daysHeld);
        }

        // 5. Verify achievement belongs to chapter
        bytes32 achievementChapter = registry.getAchievementChapter(achievementId);
        if (achievementChapter != chapterId) {
            revert IChapterRegistry.AchievementNotInChapter(achievementId, chapterId);
        }

        // 6. Prerequisite check (skill-tree within this chapter)
        IChapterRegistry.ChapterAchievement memory ach = registry.getAchievement(achievementId);
        for (uint256 i = 0; i < ach.prerequisites.length; i++) {
            if (!achievements.hasAchievement(msg.sender, ach.prerequisites[i])) {
                revert PrerequisiteNotMet(achievementId, ach.prerequisites[i]);
            }
        }

        // 7. Achievement-specific verification (if verifier set)
        if (ach.verifier != address(0)) {
            if (!IAchievementVerifier(ach.verifier).verify(msg.sender, achievementId, verificationData)) {
                revert AchievementVerificationFailed(achievementId);
            }
        }

        // 8. Mint (pass isStackable flag from registry)
        achievements.mint(msg.sender, achievementId, chapterId, ach.isStackable);

        emit ChapterAchievementClaimed(msg.sender, achievementId, chapterId, vaultId);
    }

    // ==================== View Functions ====================

    /// @inheritdoc IChapterMinter
    function canClaimChapterAchievement(
        address wallet,
        bytes32 chapterId,
        bytes32 achievementId,
        uint256 vaultId,
        address collateralToken,
        bytes calldata verificationData
    ) external view returns (bool canClaim, string memory reason) {
        IVaultState selectedProtocol = protocols[collateralToken];
        if (address(selectedProtocol) == address(0)) {
            return (false, "Unsupported collateral");
        }

        // Check if already earned (only for non-stackable)
        IChapterRegistry.ChapterAchievement memory ach;
        try registry.getAchievement(achievementId) returns (IChapterRegistry.ChapterAchievement memory a) {
            ach = a;
        } catch {
            return (false, "Achievement not found");
        }

        if (!ach.isStackable && achievements.hasAchievement(wallet, achievementId)) {
            return (false, "Already has this achievement");
        }

        // Get chapter config
        IChapterRegistry.ChapterConfig memory config;
        try registry.getChapter(chapterId) returns (IChapterRegistry.ChapterConfig memory c) {
            config = c;
        } catch {
            return (false, "Chapter not found");
        }

        // Time window checks
        if (block.timestamp < config.startTimestamp) {
            return (false, "Mint window not open");
        }
        if (block.timestamp > config.endTimestamp) {
            return (false, "Mint window closed");
        }
        if (!config.active) {
            return (false, "Chapter not active");
        }

        // Vault ownership
        if (selectedProtocol.ownerOf(vaultId) != wallet) {
            return (false, "Not vault owner");
        }

        // Issuer treasure
        if (selectedProtocol.treasureContract(vaultId) != address(treasureNFT)) {
            return (false, "Vault not using issuer treasure");
        }

        // Journey gate
        uint256 daysHeld = (block.timestamp - selectedProtocol.mintTimestamp(vaultId)) / 1 days;
        if (daysHeld < config.minDaysHeld) {
            return (false, "Journey progress insufficient");
        }
        if (daysHeld > config.maxDaysHeld) {
            return (false, "Journey progress exceeded");
        }

        // Achievement belongs to chapter
        try registry.getAchievementChapter(achievementId) returns (bytes32 achChapter) {
            if (achChapter != chapterId) {
                return (false, "Achievement not in chapter");
            }
        } catch {
            return (false, "Achievement not found");
        }

        // Prerequisites (ach already fetched at start of function)
        for (uint256 i = 0; i < ach.prerequisites.length; i++) {
            if (!achievements.hasAchievement(wallet, ach.prerequisites[i])) {
                return (false, "Prerequisite not met");
            }
        }

        // Achievement-specific verification
        if (ach.verifier != address(0)) {
            if (!IAchievementVerifier(ach.verifier).verify(wallet, achievementId, verificationData)) {
                return (false, "Achievement verification failed");
            }
        }

        return (true, "");
    }

    /// @inheritdoc IChapterMinter
    function getClaimableAchievements(
        address wallet,
        bytes32 chapterId,
        uint256 vaultId,
        address collateralToken
    ) external view returns (bytes32[] memory claimable) {
        IChapterRegistry.ChapterAchievement[] memory allAchievements = registry.getChapterAchievements(chapterId);

        // Count claimable
        uint256 count = 0;
        bool[] memory isClaimable = new bool[](allAchievements.length);

        for (uint256 i = 0; i < allAchievements.length; i++) {
            (bool canClaim,) = this.canClaimChapterAchievement(
                wallet,
                chapterId,
                allAchievements[i].achievementId,
                vaultId,
                collateralToken,
                "" // Empty verification data - achievements with verifiers may require specific data
            );
            if (canClaim) {
                isClaimable[i] = true;
                count++;
            }
        }

        // Build result array
        claimable = new bytes32[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < allAchievements.length; i++) {
            if (isClaimable[i]) {
                claimable[idx++] = allAchievements[i].achievementId;
            }
        }
    }

    // ==================== Admin Functions ====================

    /// @notice Add a protocol for a collateral token
    /// @param collateralToken The collateral token address
    /// @param protocol The protocol address
    function setProtocol(address collateralToken, address protocol) external onlyOwner {
        protocols[collateralToken] = IVaultState(protocol);
    }
}
