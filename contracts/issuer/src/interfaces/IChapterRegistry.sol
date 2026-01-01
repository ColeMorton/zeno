// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IChapterRegistry - Chapter configuration and achievement definitions
/// @notice Interface for managing chapter configs, versions, and achievement definitions
/// @dev Chapters follow calendar quarters but gate eligibility based on holder's journey progress
interface IChapterRegistry {
    // ==================== Structs ====================

    /// @notice Configuration for a chapter version
    /// @param chapterNumber Chapter number (1-12)
    /// @param startTimestamp Calendar quarter start (when minting opens)
    /// @param endTimestamp Calendar quarter end (permanent lock after this)
    /// @param year Calendar year (e.g., 2025)
    /// @param quarter Calendar quarter (1-4)
    /// @param minDaysHeld Minimum days held to participate (journey gate)
    /// @param maxDaysHeld Maximum days held to participate (journey gate)
    /// @param achievementBaseURI IPFS base URI for high-res achievement images
    /// @param active Emergency pause flag
    struct ChapterConfig {
        uint8 chapterNumber;
        uint48 startTimestamp;
        uint48 endTimestamp;
        uint16 year;
        uint8 quarter;
        uint256 minDaysHeld;
        uint256 maxDaysHeld;
        string achievementBaseURI;
        bool active;
    }

    /// @notice Achievement definition within a chapter
    /// @param achievementId Full encoded ID (keccak256 of chapter + name)
    /// @param name Display name
    /// @param prerequisites Required achievements (skill-tree dependencies)
    /// @param verifier Optional verifier contract for achievement-specific validation
    struct ChapterAchievement {
        bytes32 achievementId;
        string name;
        bytes32[] prerequisites;
        address verifier;
    }

    // ==================== Events ====================

    /// @notice Emitted when a new chapter version is created
    event ChapterCreated(
        bytes32 indexed chapterId,
        uint8 indexed chapterNumber,
        uint16 year,
        uint8 quarter
    );

    /// @notice Emitted when a chapter is activated or deactivated
    event ChapterActiveChanged(bytes32 indexed chapterId, bool active);

    /// @notice Emitted when an achievement is added to a chapter
    event AchievementAdded(
        bytes32 indexed chapterId,
        bytes32 indexed achievementId,
        string name
    );

    // ==================== Errors ====================

    /// @notice Chapter already exists with this ID
    error ChapterAlreadyExists(bytes32 chapterId);

    /// @notice Chapter not found
    error ChapterNotFound(bytes32 chapterId);

    /// @notice Invalid time window (start >= end)
    error InvalidTimeWindow(uint48 start, uint48 end);

    /// @notice Chapter number out of range (must be 1-12)
    error ChapterNumberOutOfRange(uint8 number);

    /// @notice Invalid days held range (min > max)
    error InvalidDaysHeldRange(uint256 min, uint256 max);

    /// @notice Achievement already exists
    error AchievementAlreadyExists(bytes32 achievementId);

    /// @notice Achievement not found
    error AchievementNotFound(bytes32 achievementId);

    /// @notice Achievement does not belong to chapter
    error AchievementNotInChapter(bytes32 achievementId, bytes32 chapterId);

    // ==================== Admin Functions ====================

    /// @notice Create a new chapter version
    /// @param chapterNumber Chapter number (1-12)
    /// @param year Calendar year (e.g., 2025)
    /// @param quarter Calendar quarter (1-4)
    /// @param startTimestamp Calendar quarter start
    /// @param endTimestamp Calendar quarter end
    /// @param minDaysHeld Minimum days held to participate
    /// @param maxDaysHeld Maximum days held to participate
    /// @param achievementBaseURI IPFS base URI for achievement images
    /// @return chapterId The generated chapter ID
    function createChapter(
        uint8 chapterNumber,
        uint16 year,
        uint8 quarter,
        uint48 startTimestamp,
        uint48 endTimestamp,
        uint256 minDaysHeld,
        uint256 maxDaysHeld,
        string calldata achievementBaseURI
    ) external returns (bytes32 chapterId);

    /// @notice Add an achievement to a chapter (no verifier)
    /// @param chapterId The chapter to add the achievement to
    /// @param name Achievement display name
    /// @param prerequisites Required achievements (bytes32 IDs)
    /// @return achievementId The generated achievement ID
    function addAchievement(
        bytes32 chapterId,
        string calldata name,
        bytes32[] calldata prerequisites
    ) external returns (bytes32 achievementId);

    /// @notice Add an achievement to a chapter with a custom verifier
    /// @param chapterId The chapter to add the achievement to
    /// @param name Achievement display name
    /// @param prerequisites Required achievements (bytes32 IDs)
    /// @param verifier Custom verifier contract (address(0) for no verification)
    /// @return achievementId The generated achievement ID
    function addAchievementWithVerifier(
        bytes32 chapterId,
        string calldata name,
        bytes32[] calldata prerequisites,
        address verifier
    ) external returns (bytes32 achievementId);

    /// @notice Set chapter active status
    /// @param chapterId Chapter to update
    /// @param active New active status
    function setChapterActive(bytes32 chapterId, bool active) external;

    // ==================== View Functions ====================

    /// @notice Get chapter configuration
    /// @param chapterId Chapter ID to query
    /// @return config The chapter configuration
    function getChapter(bytes32 chapterId) external view returns (ChapterConfig memory config);

    /// @notice Get all achievements for a chapter
    /// @param chapterId Chapter ID to query
    /// @return achievements Array of achievements
    function getChapterAchievements(bytes32 chapterId) external view returns (ChapterAchievement[] memory achievements);

    /// @notice Get a specific achievement
    /// @param achievementId Achievement ID to query
    /// @return achievement The achievement definition
    function getAchievement(bytes32 achievementId) external view returns (ChapterAchievement memory achievement);

    /// @notice Get the chapter an achievement belongs to
    /// @param achievementId Achievement ID to query
    /// @return chapterId The chapter ID
    function getAchievementChapter(bytes32 achievementId) external view returns (bytes32 chapterId);

    /// @notice Check if holder is eligible for a chapter based on journey progress
    /// @param chapterId Chapter to check
    /// @param daysHeld Holder's days held
    /// @return eligible Whether holder meets journey gate requirements
    function isEligible(bytes32 chapterId, uint256 daysHeld) external view returns (bool eligible);

    /// @notice Check if chapter is within its calendar mint window
    /// @param chapterId Chapter to check
    /// @return withinWindow Whether current time is within start/end
    function isWithinMintWindow(bytes32 chapterId) external view returns (bool withinWindow);

    /// @notice Check if achievement exists
    /// @param achievementId Achievement to check
    /// @return exists Whether achievement exists
    function achievementExists(bytes32 achievementId) external view returns (bool exists);

    /// @notice Generate chapter ID from number, year, and quarter
    /// @param chapterNumber Chapter number (1-12)
    /// @param year Calendar year (e.g., 2025)
    /// @param quarter Calendar quarter (1-4)
    /// @return chapterId The generated chapter ID
    function getChapterId(uint8 chapterNumber, uint16 year, uint8 quarter) external pure returns (bytes32 chapterId);

    /// @notice Generate achievement ID from chapter and name
    /// @param chapterId Chapter ID
    /// @param name Achievement name
    /// @return achievementId The generated achievement ID
    function getAchievementId(bytes32 chapterId, string calldata name) external pure returns (bytes32 achievementId);
}
