// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AchievementNFT} from "../../src/AchievementNFT.sol";
import {IAchievementNFT} from "../../src/interfaces/IAchievementNFT.sol";

contract AchievementNFTTest is Test {
    AchievementNFT public achievement;
    address public owner;
    address public minter;
    address public alice;
    address public bob;

    // Cache achievement type constants
    bytes32 public MINTER;
    bytes32 public MATURED;
    bytes32 public HODLER_SUPREME;
    bytes32 public FIRST_MONTH;

    // Chapter ID for regular (non-chapter) achievements
    bytes32 public constant NO_CHAPTER = bytes32(0);

    function setUp() public {
        owner = makeAddr("owner");
        minter = makeAddr("minter");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.prank(owner);
        achievement = new AchievementNFT("Achievements", "ACH", "https://example.com/", true);

        // Cache constants
        MINTER = achievement.MINTER();
        MATURED = achievement.MATURED();
        HODLER_SUPREME = achievement.HODLER_SUPREME();
        FIRST_MONTH = achievement.FIRST_MONTH();
    }

    function test_Constructor() public view {
        assertEq(achievement.name(), "Achievements");
        assertEq(achievement.symbol(), "ACH");
        assertEq(achievement.owner(), owner);
    }

    function test_AchievementTypeConstants() public view {
        assertEq(achievement.MINTER(), keccak256("MINTER"));
        assertEq(achievement.MATURED(), keccak256("MATURED"));
        assertEq(achievement.HODLER_SUPREME(), keccak256("HODLER_SUPREME"));
        assertEq(achievement.FIRST_MONTH(), keccak256("FIRST_MONTH"));
        assertEq(achievement.QUARTER_STACK(), keccak256("QUARTER_STACK"));
        assertEq(achievement.HALF_YEAR(), keccak256("HALF_YEAR"));
        assertEq(achievement.ANNUAL(), keccak256("ANNUAL"));
        assertEq(achievement.DIAMOND_HANDS(), keccak256("DIAMOND_HANDS"));
    }

    function test_AuthorizeMinter() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        assertTrue(achievement.authorizedMinters(minter));
    }

    function test_AuthorizeMinter_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IAchievementNFT.MinterAuthorized(minter);
        achievement.authorizeMinter(minter);
    }

    function test_AuthorizeMinter_RevertIf_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        achievement.authorizeMinter(minter);
    }

    function test_RevokeMinter() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);
        assertTrue(achievement.authorizedMinters(minter));

        vm.prank(owner);
        achievement.revokeMinter(minter);
        assertFalse(achievement.authorizedMinters(minter));
    }

    function test_RevokeMinter_EmitsEvent() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit IAchievementNFT.MinterRevoked(minter);
        achievement.revokeMinter(minter);
    }

    function test_Mint_AsAuthorizedMinter() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        uint256 tokenId = achievement.mint(alice, MINTER, NO_CHAPTER, false);

        assertEq(achievement.ownerOf(tokenId), alice);
        assertEq(achievement.totalSupply(), 1);
        assertEq(achievement.achievementType(tokenId), MINTER);
        assertEq(achievement.tokenChapter(tokenId), NO_CHAPTER);
        assertTrue(achievement.hasAchievement(alice, MINTER));
    }

    function test_Mint_RevertIf_NotAuthorized() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAchievementNFT.NotAuthorizedMinter.selector, alice)
        );
        achievement.mint(alice, MINTER, NO_CHAPTER, false);
    }

    function test_Mint_RevertIf_AlreadyEarned_NonStackable() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        achievement.mint(alice, MINTER, NO_CHAPTER, false);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAchievementNFT.AchievementAlreadyEarned.selector,
                alice,
                MINTER
            )
        );
        achievement.mint(alice, MINTER, NO_CHAPTER, false);
    }

    function test_Mint_DifferentAchievementTypes() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.startPrank(minter);
        uint256 tokenId1 = achievement.mint(alice, MINTER, NO_CHAPTER, false);
        uint256 tokenId2 = achievement.mint(alice, MATURED, NO_CHAPTER, false);
        uint256 tokenId3 = achievement.mint(alice, HODLER_SUPREME, NO_CHAPTER, false);
        vm.stopPrank();

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);

        assertTrue(achievement.hasAchievement(alice, MINTER));
        assertTrue(achievement.hasAchievement(alice, MATURED));
        assertTrue(achievement.hasAchievement(alice, HODLER_SUPREME));
        assertEq(achievement.totalSupply(), 3);
    }

    function test_Mint_EmitsEvents() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        vm.expectEmit(true, false, false, false);
        emit IAchievementNFT.Locked(0);
        vm.expectEmit(true, true, true, true);
        emit IAchievementNFT.AchievementEarned(alice, 0, MINTER, NO_CHAPTER);
        achievement.mint(alice, MINTER, NO_CHAPTER, false);
    }

    function test_Locked_AlwaysTrue() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        uint256 tokenId = achievement.mint(alice, MINTER, NO_CHAPTER, false);

        assertTrue(achievement.locked(tokenId));
    }

    function test_Locked_RevertIf_TokenDoesNotExist() public {
        vm.expectRevert();
        achievement.locked(999);
    }

    function test_Transfer_RevertIf_Soulbound() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        uint256 tokenId = achievement.mint(alice, MINTER, NO_CHAPTER, false);

        vm.prank(alice);
        vm.expectRevert(IAchievementNFT.SoulboundTransferNotAllowed.selector);
        achievement.transferFrom(alice, bob, tokenId);
    }

    function test_SafeTransfer_RevertIf_Soulbound() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        uint256 tokenId = achievement.mint(alice, MINTER, NO_CHAPTER, false);

        vm.prank(alice);
        vm.expectRevert(IAchievementNFT.SoulboundTransferNotAllowed.selector);
        achievement.safeTransferFrom(alice, bob, tokenId);
    }

    function test_HasAchievement() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        assertFalse(achievement.hasAchievement(alice, MINTER));

        vm.prank(minter);
        achievement.mint(alice, MINTER, NO_CHAPTER, false);

        assertTrue(achievement.hasAchievement(alice, MINTER));
        assertFalse(achievement.hasAchievement(alice, MATURED));
    }

    function test_SetBaseURI() public {
        vm.prank(owner);
        achievement.setUseOnChainSVG(false);

        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        achievement.mint(alice, MINTER, NO_CHAPTER, false);

        vm.prank(owner);
        achievement.setBaseURI("https://newuri.com/");

        assertEq(achievement.tokenURI(0), "https://newuri.com/0");
    }

    function test_SetBaseURI_RevertIf_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        achievement.setBaseURI("https://newuri.com/");
    }

    function test_SupportsInterface_ERC5192() public view {
        // ERC-5192 interface ID: 0xb45a3c0e
        assertTrue(achievement.supportsInterface(0xb45a3c0e));
    }

    function test_SupportsInterface_ERC721() public view {
        // ERC-721 interface ID: 0x80ac58cd
        assertTrue(achievement.supportsInterface(0x80ac58cd));
    }

    function test_SupportsInterface_ERC165() public view {
        // ERC-165 interface ID: 0x01ffc9a7
        assertTrue(achievement.supportsInterface(0x01ffc9a7));
    }

    function test_Mint_CustomBytes32Achievement() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        // Test minting with a custom bytes32 achievement type
        bytes32 customType = keccak256("CUSTOM_ACHIEVEMENT");

        vm.prank(minter);
        uint256 tokenId = achievement.mint(alice, customType, NO_CHAPTER, false);

        assertEq(achievement.achievementType(tokenId), customType);
        assertTrue(achievement.hasAchievement(alice, customType));
    }

    function testFuzz_Mint_IncrementingTokenIds(uint8 count) public {
        vm.assume(count > 0 && count <= 50);

        vm.prank(owner);
        achievement.authorizeMinter(minter);

        for (uint8 i = 0; i < count; i++) {
            address wallet = makeAddr(string(abi.encodePacked("wallet", i)));
            vm.prank(minter);
            uint256 tokenId = achievement.mint(wallet, MINTER, NO_CHAPTER, false);
            assertEq(tokenId, i);
        }

        assertEq(achievement.totalSupply(), count);
    }

    // ==================== Chapter Achievement Tests ====================

    function test_Mint_WithChapterId() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        bytes32 chapterId = keccak256("CHAPTER_1");
        bytes32 achievementId = keccak256("FIRST_STEPS");

        vm.prank(minter);
        uint256 tokenId = achievement.mint(alice, achievementId, chapterId, false);

        assertEq(achievement.tokenChapter(tokenId), chapterId);
        assertEq(achievement.achievementType(tokenId), achievementId);
        assertTrue(achievement.hasAchievement(alice, achievementId));
    }

    // ==================== Stackable Achievement Tests ====================

    function test_Mint_Stackable_MultipleTimes() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        bytes32 stackableAchievement = keccak256("STACKABLE");

        // First mint
        vm.prank(minter);
        uint256 tokenId1 = achievement.mint(alice, stackableAchievement, NO_CHAPTER, true);

        // Second mint - should succeed for stackable
        vm.prank(minter);
        uint256 tokenId2 = achievement.mint(alice, stackableAchievement, NO_CHAPTER, true);

        // Third mint
        vm.prank(minter);
        uint256 tokenId3 = achievement.mint(alice, stackableAchievement, NO_CHAPTER, true);

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);
        assertEq(achievement.achievementCount(alice, stackableAchievement), 3);
        assertTrue(achievement.hasAchievement(alice, stackableAchievement));
    }

    function test_AchievementCount_NonStackable() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        vm.prank(minter);
        achievement.mint(alice, MINTER, NO_CHAPTER, false);

        assertEq(achievement.achievementCount(alice, MINTER), 1);
    }

    function test_AchievementCount_Zero_WhenNotEarned() public view {
        assertEq(achievement.achievementCount(alice, MINTER), 0);
    }

    // ==================== Chapter + Stackable Combined Tests ====================

    function test_Mint_ChapterStackable() public {
        vm.prank(owner);
        achievement.authorizeMinter(minter);

        bytes32 chapterId = keccak256("CHAPTER_1");
        bytes32 achievementId = keccak256("REPEATABLE_LESSON");

        // First claim
        vm.prank(minter);
        uint256 tokenId1 = achievement.mint(alice, achievementId, chapterId, true);

        // Second claim - stackable
        vm.prank(minter);
        uint256 tokenId2 = achievement.mint(alice, achievementId, chapterId, true);

        assertEq(achievement.tokenChapter(tokenId1), chapterId);
        assertEq(achievement.tokenChapter(tokenId2), chapterId);
        assertEq(achievement.achievementCount(alice, achievementId), 2);
    }
}
