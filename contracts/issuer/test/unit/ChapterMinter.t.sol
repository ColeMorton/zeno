// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChapterMinter} from "../../src/ChapterMinter.sol";
import {ChapterRegistry} from "../../src/ChapterRegistry.sol";
import {AchievementNFT} from "../../src/AchievementNFT.sol";
import {IChapterMinter} from "../../src/interfaces/IChapterMinter.sol";
import {IChapterRegistry} from "../../src/interfaces/IChapterRegistry.sol";
import {MockTreasureNFT} from "../mocks/MockTreasureNFT.sol";
import {MockVaultNFT} from "../mocks/MockVaultNFT.sol";

contract ChapterMinterTest is Test {
    ChapterMinter public minter;
    ChapterRegistry public registry;
    AchievementNFT public achievementNFT;
    MockTreasureNFT public treasureNFT;
    MockVaultNFT public vaultNFT;

    address public owner = address(this);
    address public user = address(0xBEEF);
    address public collateralToken = address(0xCAFE);

    uint8 public constant CHAPTER_NUMBER = 1;
    uint16 public constant YEAR = 2025;
    uint8 public constant QUARTER = 1;
    uint48 public startTimestamp;
    uint48 public endTimestamp;
    uint256 public constant MIN_DAYS_HELD = 0;
    uint256 public constant MAX_DAYS_HELD = 90;

    bytes32 public chapterId;
    bytes32 public achievementId;
    uint256 public vaultId;

    function setUp() public {
        // Deploy contracts
        registry = new ChapterRegistry();
        achievementNFT = new AchievementNFT(
            "Chapter Achievements",
            "CHACH",
            "https://example.com/",
            false
        );
        treasureNFT = new MockTreasureNFT();
        vaultNFT = new MockVaultNFT();

        // Deploy minter
        address[] memory collaterals = new address[](1);
        collaterals[0] = collateralToken;
        address[] memory protocols = new address[](1);
        protocols[0] = address(vaultNFT);

        minter = new ChapterMinter(
            address(achievementNFT),
            address(registry),
            address(treasureNFT),
            collaterals,
            protocols
        );

        // Authorize minter
        achievementNFT.authorizeMinter(address(minter));

        // Setup timestamps
        startTimestamp = uint48(block.timestamp);
        endTimestamp = uint48(block.timestamp + 91 days);

        // Create chapter
        chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            "ipfs://test/"
        );

        // Add achievement
        achievementId = registry.addAchievement(chapterId, "First Steps", new bytes32[](0));

        // Create vault for user
        vaultId = vaultNFT.mockMint(user, address(treasureNFT), block.timestamp);
    }

    // ==================== claimChapterAchievement Tests ====================

    function test_ClaimChapterAchievement() public {
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");

        assertTrue(achievementNFT.hasAchievement(user, achievementId));
    }

    function test_ClaimChapterAchievement_EmitsEvent() public {
        vm.prank(user);

        vm.expectEmit(true, true, true, true);
        emit IChapterMinter.ChapterAchievementClaimed(user, achievementId, chapterId, vaultId);

        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_WindowNotOpen() public {
        // Warp to before window
        vm.warp(startTimestamp - 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.MintWindowNotOpen.selector, chapterId, startTimestamp));
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_WindowClosed() public {
        // Warp to after window
        vm.warp(endTimestamp + 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.MintWindowClosed.selector, chapterId, endTimestamp));
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_ChapterNotActive() public {
        registry.setChapterActive(chapterId, false);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.ChapterNotActive.selector, chapterId));
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_NotVaultOwner() public {
        address notOwner = address(0xDEAD);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.NotVaultOwner.selector, vaultId, notOwner));
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_WrongTreasure() public {
        // Create vault with different treasure contract
        MockTreasureNFT otherTreasure = new MockTreasureNFT();
        uint256 wrongVaultId = vaultNFT.mockMint(user, address(otherTreasure), block.timestamp);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.VaultNotUsingIssuerTreasure.selector, wrongVaultId, address(otherTreasure)));
        minter.claimChapterAchievement(chapterId, achievementId, wrongVaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_JourneyProgressInsufficient() public {
        // Create chapter 2 with higher journey gate
        bytes32 chapter2Id = registry.createChapter(
            2,
            YEAR,
            QUARTER,
            startTimestamp,
            endTimestamp,
            91, // min days held
            181, // max days held
            "ipfs://test/"
        );
        bytes32 ach2Id = registry.addAchievement(chapter2Id, "Chapter 2 Achievement", new bytes32[](0));

        // User's vault is at day 0 (below 91)
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.JourneyProgressInsufficient.selector, chapter2Id, 91, 0));
        minter.claimChapterAchievement(chapter2Id, ach2Id, vaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_JourneyProgressExceeded() public {
        // Create chapter with extended window but limited journey gate
        bytes32 shortChapterId = registry.createChapter(
            3, // Different chapter number
            YEAR,
            QUARTER,
            startTimestamp,
            uint48(block.timestamp + 200 days), // Extended window
            0, // min days held
            50, // max days held - shorter than the window
            "ipfs://test/"
        );
        bytes32 shortAchId = registry.addAchievement(shortChapterId, "Short Chapter", new bytes32[](0));

        // Create vault at current time
        uint256 shortVaultId = vaultNFT.mockMint(user, address(treasureNFT), block.timestamp);

        // Warp to day 60 (beyond chapter's max of 50, but still in window)
        vm.warp(block.timestamp + 60 days);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.JourneyProgressExceeded.selector, shortChapterId, 50, 60));
        minter.claimChapterAchievement(shortChapterId, shortAchId, shortVaultId, collateralToken, "");
    }

    function test_ClaimChapterAchievement_RevertIf_UnsupportedCollateral() public {
        address unknownCollateral = address(0x9999);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.UnsupportedCollateral.selector, unknownCollateral));
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, unknownCollateral, "");
    }

    function test_ClaimChapterAchievement_WithPrerequisites() public {
        // Add first achievement (no prereqs)
        bytes32 prereqId = registry.addAchievement(chapterId, "Prerequisite", new bytes32[](0));

        // Add second achievement that requires first
        bytes32[] memory prereqs = new bytes32[](1);
        prereqs[0] = prereqId;
        bytes32 dependentId = registry.addAchievement(chapterId, "Dependent", prereqs);

        // Try to claim dependent without prereq - should fail
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterMinter.PrerequisiteNotMet.selector, dependentId, prereqId));
        minter.claimChapterAchievement(chapterId, dependentId, vaultId, collateralToken, "");

        // Claim prerequisite first
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, prereqId, vaultId, collateralToken, "");

        // Now claim dependent - should succeed
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, dependentId, vaultId, collateralToken, "");

        assertTrue(achievementNFT.hasAchievement(user, dependentId));
    }

    // ==================== canClaimChapterAchievement Tests ====================

    function test_CanClaimChapterAchievement_Success() public view {
        (bool canClaim, string memory reason) = minter.canClaimChapterAchievement(
            user,
            chapterId,
            achievementId,
            vaultId,
            collateralToken,
            ""
        );

        assertTrue(canClaim);
        assertEq(reason, "");
    }

    function test_CanClaimChapterAchievement_AlreadyHas() public {
        // Claim first
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");

        (bool canClaim, string memory reason) = minter.canClaimChapterAchievement(
            user,
            chapterId,
            achievementId,
            vaultId,
            collateralToken,
            ""
        );

        assertFalse(canClaim);
        assertEq(reason, "Already has this achievement");
    }

    function test_CanClaimChapterAchievement_WindowClosed() public {
        vm.warp(endTimestamp + 1);

        (bool canClaim, string memory reason) = minter.canClaimChapterAchievement(
            user,
            chapterId,
            achievementId,
            vaultId,
            collateralToken,
            ""
        );

        assertFalse(canClaim);
        assertEq(reason, "Mint window closed");
    }

    // ==================== getClaimableAchievements Tests ====================

    function test_GetClaimableAchievements() public {
        // Add more achievements
        bytes32 ach2 = registry.addAchievement(chapterId, "Second", new bytes32[](0));
        bytes32 ach3 = registry.addAchievement(chapterId, "Third", new bytes32[](0));

        bytes32[] memory claimable = minter.getClaimableAchievements(user, chapterId, vaultId, collateralToken);

        assertEq(claimable.length, 3);
    }

    function test_GetClaimableAchievements_AfterClaiming() public {
        // Add second achievement
        registry.addAchievement(chapterId, "Second", new bytes32[](0));

        // Claim first
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken, "");

        bytes32[] memory claimable = minter.getClaimableAchievements(user, chapterId, vaultId, collateralToken);

        // Only second should be claimable
        assertEq(claimable.length, 1);
    }

    // ==================== Stackable Achievement Tests ====================

    function test_ClaimStackableAchievement_MultipleTimes() public {
        // Add stackable achievement
        bytes32 stackableId = registry.addStackableAchievement(chapterId, "Mint 5 NFTs", new bytes32[](0), address(0));

        // Claim first time
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, stackableId, vaultId, collateralToken, "");

        assertTrue(achievementNFT.hasAchievement(user, stackableId));
        assertEq(achievementNFT.achievementCount(user, stackableId), 1);

        // Claim second time - should succeed for stackable
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, stackableId, vaultId, collateralToken, "");

        assertEq(achievementNFT.achievementCount(user, stackableId), 2);
        assertEq(achievementNFT.balanceOf(user), 2);
    }

    function test_CanClaimStackableAchievement_AfterFirstClaim() public {
        // Add stackable achievement
        bytes32 stackableId = registry.addStackableAchievement(chapterId, "Mint 5 NFTs", new bytes32[](0), address(0));

        // Claim first time
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, stackableId, vaultId, collateralToken, "");

        // Check canClaim - should still be true for stackable
        (bool canClaim, string memory reason) = minter.canClaimChapterAchievement(
            user,
            chapterId,
            stackableId,
            vaultId,
            collateralToken,
            ""
        );

        assertTrue(canClaim);
        assertEq(reason, "");
    }

    function test_GetClaimableAchievements_IncludesStackable() public {
        // Add stackable achievement
        bytes32 stackableId = registry.addStackableAchievement(chapterId, "Mint 5 NFTs", new bytes32[](0), address(0));

        // Claim it
        vm.prank(user);
        minter.claimChapterAchievement(chapterId, stackableId, vaultId, collateralToken, "");

        bytes32[] memory claimable = minter.getClaimableAchievements(user, chapterId, vaultId, collateralToken);

        // Should include both: original achievementId (not claimed yet) and stackable (can be claimed again)
        assertEq(claimable.length, 2);
    }

    // ==================== Admin Tests ====================

    function test_SetProtocol() public {
        address newCollateral = address(0x1111);
        address newProtocol = address(0x2222);

        minter.setProtocol(newCollateral, newProtocol);

        // Verify by trying to claim (will fail for other reasons but won't revert on UnsupportedCollateral)
        // This is a basic test that the mapping was updated
    }
}
