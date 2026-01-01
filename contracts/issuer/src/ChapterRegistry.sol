// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IChapterRegistry} from "./interfaces/IChapterRegistry.sol";

/// @title ChapterRegistry - Chapter configuration and achievement definitions
/// @notice Stores chapter configs, versions, and achievement definitions for The Ascent
/// @dev Chapters follow calendar quarters but gate eligibility based on holder's journey progress
contract ChapterRegistry is IChapterRegistry, Ownable {
    // ==================== Constants ====================

    /// @notice Total number of chapters in the journey
    uint8 public constant TOTAL_CHAPTERS = 12;

    // ==================== State Variables ====================

    /// @notice Chapter configurations by chapter ID
    mapping(bytes32 => ChapterConfig) private _chapters;

    /// @notice Whether a chapter exists
    mapping(bytes32 => bool) private _chapterExists;

    /// @notice Achievements for each chapter
    mapping(bytes32 => ChapterAchievement[]) private _chapterAchievements;

    /// @notice Achievement details by achievement ID
    mapping(bytes32 => ChapterAchievement) private _achievements;

    /// @notice Whether an achievement exists
    mapping(bytes32 => bool) private _achievementExists;

    /// @notice Which chapter an achievement belongs to
    mapping(bytes32 => bytes32) private _achievementToChapter;

    // ==================== Constructor ====================

    constructor() Ownable(msg.sender) {}

    // ==================== Admin Functions ====================

    /// @inheritdoc IChapterRegistry
    function createChapter(
        uint8 chapterNumber,
        uint16 year,
        uint8 quarter,
        uint48 startTimestamp,
        uint48 endTimestamp,
        uint256 minDaysHeld,
        uint256 maxDaysHeld,
        string calldata achievementBaseURI
    ) external onlyOwner returns (bytes32 chapterId) {
        if (chapterNumber == 0 || chapterNumber > TOTAL_CHAPTERS) {
            revert ChapterNumberOutOfRange(chapterNumber);
        }
        if (startTimestamp >= endTimestamp) {
            revert InvalidTimeWindow(startTimestamp, endTimestamp);
        }
        if (minDaysHeld > maxDaysHeld) {
            revert InvalidDaysHeldRange(minDaysHeld, maxDaysHeld);
        }

        chapterId = getChapterId(chapterNumber, year, quarter);

        if (_chapterExists[chapterId]) {
            revert ChapterAlreadyExists(chapterId);
        }

        _chapters[chapterId] = ChapterConfig({
            chapterNumber: chapterNumber,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            year: year,
            quarter: quarter,
            minDaysHeld: minDaysHeld,
            maxDaysHeld: maxDaysHeld,
            achievementBaseURI: achievementBaseURI,
            active: true
        });

        _chapterExists[chapterId] = true;

        emit ChapterCreated(chapterId, chapterNumber, year, quarter);
    }

    /// @inheritdoc IChapterRegistry
    function addAchievement(
        bytes32 chapterId,
        string calldata name,
        bytes32[] calldata prerequisites
    ) external onlyOwner returns (bytes32 achievementId) {
        return _addAchievement(chapterId, name, prerequisites, address(0));
    }

    /// @inheritdoc IChapterRegistry
    function addAchievementWithVerifier(
        bytes32 chapterId,
        string calldata name,
        bytes32[] calldata prerequisites,
        address verifier
    ) external onlyOwner returns (bytes32 achievementId) {
        return _addAchievement(chapterId, name, prerequisites, verifier);
    }

    /// @dev Internal function to add an achievement
    function _addAchievement(
        bytes32 chapterId,
        string calldata name,
        bytes32[] calldata prerequisites,
        address verifier
    ) internal returns (bytes32 achievementId) {
        if (!_chapterExists[chapterId]) {
            revert ChapterNotFound(chapterId);
        }

        achievementId = getAchievementId(chapterId, name);

        if (_achievementExists[achievementId]) {
            revert AchievementAlreadyExists(achievementId);
        }

        ChapterAchievement memory achievement = ChapterAchievement({
            achievementId: achievementId,
            name: name,
            prerequisites: prerequisites,
            verifier: verifier
        });

        _achievements[achievementId] = achievement;
        _chapterAchievements[chapterId].push(achievement);
        _achievementExists[achievementId] = true;
        _achievementToChapter[achievementId] = chapterId;

        emit AchievementAdded(chapterId, achievementId, name);
    }

    /// @inheritdoc IChapterRegistry
    function setChapterActive(bytes32 chapterId, bool active) external onlyOwner {
        if (!_chapterExists[chapterId]) {
            revert ChapterNotFound(chapterId);
        }

        _chapters[chapterId].active = active;

        emit ChapterActiveChanged(chapterId, active);
    }

    // ==================== View Functions ====================

    /// @inheritdoc IChapterRegistry
    function getChapter(bytes32 chapterId) external view returns (ChapterConfig memory config) {
        if (!_chapterExists[chapterId]) {
            revert ChapterNotFound(chapterId);
        }
        return _chapters[chapterId];
    }

    /// @inheritdoc IChapterRegistry
    function getChapterAchievements(bytes32 chapterId) external view returns (ChapterAchievement[] memory achievements) {
        if (!_chapterExists[chapterId]) {
            revert ChapterNotFound(chapterId);
        }
        return _chapterAchievements[chapterId];
    }

    /// @inheritdoc IChapterRegistry
    function getAchievement(bytes32 achievementId) external view returns (ChapterAchievement memory achievement) {
        if (!_achievementExists[achievementId]) {
            revert AchievementNotFound(achievementId);
        }
        return _achievements[achievementId];
    }

    /// @inheritdoc IChapterRegistry
    function getAchievementChapter(bytes32 achievementId) external view returns (bytes32 chapterId) {
        if (!_achievementExists[achievementId]) {
            revert AchievementNotFound(achievementId);
        }
        return _achievementToChapter[achievementId];
    }

    /// @inheritdoc IChapterRegistry
    function isEligible(bytes32 chapterId, uint256 daysHeld) external view returns (bool eligible) {
        if (!_chapterExists[chapterId]) {
            revert ChapterNotFound(chapterId);
        }

        ChapterConfig storage config = _chapters[chapterId];
        return daysHeld >= config.minDaysHeld && daysHeld <= config.maxDaysHeld;
    }

    /// @inheritdoc IChapterRegistry
    function isWithinMintWindow(bytes32 chapterId) external view returns (bool withinWindow) {
        if (!_chapterExists[chapterId]) {
            revert ChapterNotFound(chapterId);
        }

        ChapterConfig storage config = _chapters[chapterId];
        return block.timestamp >= config.startTimestamp && block.timestamp <= config.endTimestamp;
    }

    /// @inheritdoc IChapterRegistry
    function achievementExists(bytes32 achievementId) external view returns (bool exists) {
        return _achievementExists[achievementId];
    }

    /// @inheritdoc IChapterRegistry
    function getChapterId(uint8 chapterNumber, uint16 year, uint8 quarter) public pure returns (bytes32 chapterId) {
        return keccak256(abi.encodePacked("CH", chapterNumber, "_", year, "Q", quarter));
    }

    /// @inheritdoc IChapterRegistry
    function getAchievementId(bytes32 chapterId, string calldata name) public pure returns (bytes32 achievementId) {
        return keccak256(abi.encodePacked(chapterId, "_", name));
    }
}
