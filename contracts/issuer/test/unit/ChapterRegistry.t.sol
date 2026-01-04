// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChapterRegistry} from "../../src/ChapterRegistry.sol";
import {IChapterRegistry} from "../../src/interfaces/IChapterRegistry.sol";

contract ChapterRegistryTest is Test {
    ChapterRegistry public registry;

    address public owner = address(this);
    address public nonOwner = address(0xBEEF);

    // Chapter config defaults
    uint8 public constant CHAPTER_NUMBER = 1;
    uint16 public constant YEAR = 2025;
    uint8 public constant QUARTER = 1;
    uint48 public startTimestamp;
    uint48 public endTimestamp;
    uint256 public constant MIN_DAYS_HELD = 0;
    uint256 public constant MAX_DAYS_HELD = 90;
    string public constant ACHIEVEMENT_BASE_URI = "ipfs://Qm.../ch1_2025q1/";

    function setUp() public {
        registry = new ChapterRegistry();
        startTimestamp = uint48(block.timestamp);
        endTimestamp = uint48(block.timestamp + 91 days);
    }

    // ==================== createChapter Tests ====================

    function test_CreateChapter() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        IChapterRegistry.ChapterConfig memory config = registry.getChapter(chapterId);

        assertEq(config.chapterNumber, CHAPTER_NUMBER);
        assertEq(config.year, YEAR);
        assertEq(config.quarter, QUARTER);
        assertEq(config.startTimestamp, startTimestamp);
        assertEq(config.endTimestamp, endTimestamp);
        assertEq(config.minDaysHeld, MIN_DAYS_HELD);
        assertEq(config.maxDaysHeld, MAX_DAYS_HELD);
        assertEq(config.achievementBaseURI, ACHIEVEMENT_BASE_URI);
        assertTrue(config.active);
    }

    function test_CreateChapter_EmitsEvent() public {
        bytes32 expectedChapterId = registry.getChapterId(CHAPTER_NUMBER, YEAR, QUARTER);

        vm.expectEmit(true, true, false, true);
        emit IChapterRegistry.ChapterCreated(expectedChapterId, CHAPTER_NUMBER, YEAR, QUARTER);

        registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );
    }

    function test_CreateChapter_RevertIf_ChapterNumberZero() public {
        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.ChapterNumberOutOfRange.selector, 0));

        registry.createChapter(
            0, // Invalid
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );
    }

    function test_CreateChapter_RevertIf_ChapterNumberTooHigh() public {
        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.ChapterNumberOutOfRange.selector, 13));

        registry.createChapter(
            13, // Invalid (max is 12)
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );
    }

    function test_CreateChapter_RevertIf_InvalidTimeWindow() public {
        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.InvalidTimeWindow.selector, endTimestamp, startTimestamp));

        registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            endTimestamp, // Swapped - start > end
            startTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );
    }

    function test_CreateChapter_RevertIf_InvalidDaysHeldRange() public {
        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.InvalidDaysHeldRange.selector, 100, 50));

        registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            100, // min > max
            50,
            ACHIEVEMENT_BASE_URI
        );
    }

    function test_CreateChapter_RevertIf_AlreadyExists() public {
        registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        bytes32 chapterId = registry.getChapterId(CHAPTER_NUMBER, YEAR, QUARTER);
        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.ChapterAlreadyExists.selector, chapterId));

        registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );
    }

    function test_CreateChapter_RevertIf_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();

        registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );
    }

    // ==================== addAchievement Tests ====================

    function test_AddAchievement() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        string memory name = "First Steps";
        bytes32[] memory prerequisites = new bytes32[](0);

        bytes32 achievementId = registry.addAchievement(chapterId, name, prerequisites);

        IChapterRegistry.ChapterAchievement memory ach = registry.getAchievement(achievementId);

        assertEq(ach.achievementId, achievementId);
        assertEq(ach.name, name);
        assertEq(ach.prerequisites.length, 0);
        assertTrue(registry.achievementExists(achievementId));
        assertEq(registry.getAchievementChapter(achievementId), chapterId);
    }

    function test_AddAchievement_WithPrerequisites() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        // Add first achievement
        bytes32 firstId = registry.addAchievement(chapterId, "First Steps", new bytes32[](0));

        // Add second achievement with prerequisite
        bytes32[] memory prerequisites = new bytes32[](1);
        prerequisites[0] = firstId;
        bytes32 secondId = registry.addAchievement(chapterId, "Second Steps", prerequisites);

        IChapterRegistry.ChapterAchievement memory ach = registry.getAchievement(secondId);
        assertEq(ach.prerequisites.length, 1);
        assertEq(ach.prerequisites[0], firstId);
    }

    function test_AddAchievement_EmitsEvent() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        string memory name = "First Steps";
        bytes32 expectedId = registry.getAchievementId(chapterId, name);

        vm.expectEmit(true, true, false, true);
        emit IChapterRegistry.AchievementAdded(chapterId, expectedId, name);

        registry.addAchievement(chapterId, name, new bytes32[](0));
    }

    function test_AddAchievement_RevertIf_ChapterNotFound() public {
        bytes32 fakeChapterId = keccak256("fake");

        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.ChapterNotFound.selector, fakeChapterId));

        registry.addAchievement(fakeChapterId, "First Steps", new bytes32[](0));
    }

    function test_AddAchievement_RevertIf_AlreadyExists() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        registry.addAchievement(chapterId, "First Steps", new bytes32[](0));

        bytes32 achievementId = registry.getAchievementId(chapterId, "First Steps");
        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.AchievementAlreadyExists.selector, achievementId));

        registry.addAchievement(chapterId, "First Steps", new bytes32[](0));
    }

    // ==================== setChapterActive Tests ====================

    function test_SetChapterActive() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        assertTrue(registry.getChapter(chapterId).active);

        registry.setChapterActive(chapterId, false);
        assertFalse(registry.getChapter(chapterId).active);

        registry.setChapterActive(chapterId, true);
        assertTrue(registry.getChapter(chapterId).active);
    }

    function test_SetChapterActive_EmitsEvent() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        vm.expectEmit(true, false, false, true);
        emit IChapterRegistry.ChapterActiveChanged(chapterId, false);

        registry.setChapterActive(chapterId, false);
    }

    // ==================== isEligible Tests ====================

    function test_IsEligible() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        assertTrue(registry.isEligible(chapterId, 0));
        assertTrue(registry.isEligible(chapterId, 45));
        assertTrue(registry.isEligible(chapterId, 90));
        assertFalse(registry.isEligible(chapterId, 91));
    }

    function test_IsEligible_Chapter2() public {
        bytes32 chapterId = registry.createChapter(
            2, // Chapter 2
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            91, // min
            181, // max
            ACHIEVEMENT_BASE_URI
        );

        assertFalse(registry.isEligible(chapterId, 90));
        assertTrue(registry.isEligible(chapterId, 91));
        assertTrue(registry.isEligible(chapterId, 150));
        assertTrue(registry.isEligible(chapterId, 181));
        assertFalse(registry.isEligible(chapterId, 182));
    }

    // ==================== isWithinMintWindow Tests ====================

    function test_IsWithinMintWindow() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        assertTrue(registry.isWithinMintWindow(chapterId));

        // Before window
        vm.warp(startTimestamp - 1);
        assertFalse(registry.isWithinMintWindow(chapterId));

        // After window
        vm.warp(endTimestamp + 1);
        assertFalse(registry.isWithinMintWindow(chapterId));
    }

    // ==================== getChapterAchievements Tests ====================

    function test_GetChapterAchievements() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        registry.addAchievement(chapterId, "First", new bytes32[](0));
        registry.addAchievement(chapterId, "Second", new bytes32[](0));
        registry.addAchievement(chapterId, "Third", new bytes32[](0));

        IChapterRegistry.ChapterAchievement[] memory achievements = registry.getChapterAchievements(chapterId);

        assertEq(achievements.length, 3);
        assertEq(achievements[0].name, "First");
        assertEq(achievements[1].name, "Second");
        assertEq(achievements[2].name, "Third");
    }

    // ==================== isStackable Tests ====================

    function test_AddAchievement_NotStackable() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        bytes32 achievementId = registry.addAchievement(chapterId, "First Steps", new bytes32[](0));
        assertFalse(registry.isStackable(achievementId));
    }

    function test_AddStackableAchievement() public {
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            ACHIEVEMENT_BASE_URI
        );

        bytes32 achievementId = registry.addStackableAchievement(chapterId, "Mint 5 NFTs", new bytes32[](0), address(0));

        assertTrue(registry.isStackable(achievementId));
        assertTrue(registry.achievementExists(achievementId));

        IChapterRegistry.ChapterAchievement memory ach = registry.getAchievement(achievementId);
        assertEq(ach.name, "Mint 5 NFTs");
        assertTrue(ach.isStackable);
    }

    function test_IsStackable_RevertIf_AchievementNotFound() public {
        bytes32 fakeId = keccak256("fake");
        vm.expectRevert(abi.encodeWithSelector(IChapterRegistry.AchievementNotFound.selector, fakeId));
        registry.isStackable(fakeId);
    }

    // ==================== ID Generation Tests ====================

    function test_GetChapterId_Deterministic() public view {
        bytes32 id1 = registry.getChapterId(1, 2025, 1);
        bytes32 id2 = registry.getChapterId(1, 2025, 1);
        bytes32 id3 = registry.getChapterId(2, 2025, 1);

        assertEq(id1, id2);
        assertTrue(id1 != id3);
    }

    function test_GetAchievementId_Deterministic() public view {
        bytes32 chapterId = registry.getChapterId(1, 2025, 1);
        bytes32 id1 = registry.getAchievementId(chapterId, "First Steps");
        bytes32 id2 = registry.getAchievementId(chapterId, "First Steps");
        bytes32 id3 = registry.getAchievementId(chapterId, "Second Steps");

        assertEq(id1, id2);
        assertTrue(id1 != id3);
    }
}
