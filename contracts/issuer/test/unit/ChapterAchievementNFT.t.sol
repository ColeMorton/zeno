// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChapterAchievementNFT} from "../../src/ChapterAchievementNFT.sol";
import {IChapterAchievementNFT} from "../../src/interfaces/IChapterAchievementNFT.sol";

contract ChapterAchievementNFTTest is Test {
    ChapterAchievementNFT public nft;

    address public owner = address(this);
    address public minter = address(0xCAFE);
    address public user = address(0xBEEF);
    address public user2 = address(0xDEAD);

    bytes32 public constant ACHIEVEMENT_ID = keccak256("CH1_2025Q1_FIRST_STEPS");
    bytes32 public constant CHAPTER_ID = keccak256("CH1_2025Q1");

    function setUp() public {
        nft = new ChapterAchievementNFT(
            "Chapter Achievements",
            "CHACH",
            "https://example.com/",
            false // useOnChainSVG
        );
        nft.authorizeMinter(minter);
    }

    // ==================== mint Tests ====================

    function test_Mint() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.achievementType(tokenId), ACHIEVEMENT_ID);
        assertEq(nft.tokenChapter(tokenId), CHAPTER_ID);
        assertTrue(nft.hasAchievement(user, ACHIEVEMENT_ID));
    }

    function test_Mint_EmitsEvents() public {
        vm.prank(minter);

        vm.expectEmit(true, false, false, false);
        emit IChapterAchievementNFT.Locked(0);

        vm.expectEmit(true, true, true, true);
        emit IChapterAchievementNFT.ChapterAchievementEarned(user, 0, ACHIEVEMENT_ID, CHAPTER_ID);

        nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);
    }

    function test_Mint_IncrementingTokenIds() public {
        vm.startPrank(minter);

        bytes32 ach1 = keccak256("ACH1");
        bytes32 ach2 = keccak256("ACH2");
        bytes32 ach3 = keccak256("ACH3");

        uint256 id1 = nft.mint(user, ach1, CHAPTER_ID);
        uint256 id2 = nft.mint(user, ach2, CHAPTER_ID);
        uint256 id3 = nft.mint(user2, ach3, CHAPTER_ID);

        vm.stopPrank();

        assertEq(id1, 0);
        assertEq(id2, 1);
        assertEq(id3, 2);
        assertEq(nft.totalSupply(), 3);
    }

    function test_Mint_RevertIf_AlreadyEarned() public {
        vm.prank(minter);
        nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IChapterAchievementNFT.AchievementAlreadyEarned.selector, user, ACHIEVEMENT_ID));
        nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);
    }

    function test_Mint_RevertIf_NotAuthorizedMinter() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IChapterAchievementNFT.NotAuthorizedMinter.selector, user));
        nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);
    }

    // ==================== Soulbound Tests ====================

    function test_Transfer_Reverts() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        vm.prank(user);
        vm.expectRevert(IChapterAchievementNFT.SoulboundTransferNotAllowed.selector);
        nft.transferFrom(user, user2, tokenId);
    }

    function test_SafeTransfer_Reverts() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        vm.prank(user);
        vm.expectRevert(IChapterAchievementNFT.SoulboundTransferNotAllowed.selector);
        nft.safeTransferFrom(user, user2, tokenId);
    }

    function test_Locked_AlwaysTrue() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        assertTrue(nft.locked(tokenId));
    }

    // ==================== Authorization Tests ====================

    function test_AuthorizeMinter() public {
        address newMinter = address(0x1234);
        assertFalse(nft.authorizedMinters(newMinter));

        vm.expectEmit(true, false, false, false);
        emit IChapterAchievementNFT.MinterAuthorized(newMinter);

        nft.authorizeMinter(newMinter);
        assertTrue(nft.authorizedMinters(newMinter));
    }

    function test_RevokeMinter() public {
        assertTrue(nft.authorizedMinters(minter));

        vm.expectEmit(true, false, false, false);
        emit IChapterAchievementNFT.MinterRevoked(minter);

        nft.revokeMinter(minter);
        assertFalse(nft.authorizedMinters(minter));
    }

    function test_AuthorizeMinter_RevertIf_NotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        nft.authorizeMinter(user);
    }

    // ==================== ERC-5192 Interface Tests ====================

    function test_SupportsInterface_ERC5192() public view {
        // ERC-5192 interface ID: 0xb45a3c0e
        assertTrue(nft.supportsInterface(0xb45a3c0e));
    }

    function test_SupportsInterface_ERC721() public view {
        // ERC-721 interface ID: 0x80ac58cd
        assertTrue(nft.supportsInterface(0x80ac58cd));
    }

    // ==================== tokenURI Tests ====================

    function test_TokenURI_ExternalURI() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, "https://example.com/0");
    }

    function test_SetBaseURI() public {
        nft.setBaseURI("https://newbase.com/");

        vm.prank(minter);
        uint256 tokenId = nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, "https://newbase.com/0");
    }

    function test_SetUseOnChainSVG() public {
        assertFalse(nft.useOnChainSVG());
        nft.setUseOnChainSVG(true);
        assertTrue(nft.useOnChainSVG());
    }

    // ==================== hasAchievement Tests ====================

    function test_HasAchievement() public {
        assertFalse(nft.hasAchievement(user, ACHIEVEMENT_ID));

        vm.prank(minter);
        nft.mint(user, ACHIEVEMENT_ID, CHAPTER_ID);

        assertTrue(nft.hasAchievement(user, ACHIEVEMENT_ID));
        assertFalse(nft.hasAchievement(user2, ACHIEVEMENT_ID));
    }

    // ==================== totalSupply Tests ====================

    function test_TotalSupply() public {
        assertEq(nft.totalSupply(), 0);

        vm.startPrank(minter);
        nft.mint(user, keccak256("A1"), CHAPTER_ID);
        assertEq(nft.totalSupply(), 1);

        nft.mint(user, keccak256("A2"), CHAPTER_ID);
        assertEq(nft.totalSupply(), 2);
        vm.stopPrank();
    }
}
