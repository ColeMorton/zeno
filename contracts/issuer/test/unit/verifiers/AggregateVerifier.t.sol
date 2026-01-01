// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregateVerifier} from "../../../src/verifiers/AggregateVerifier.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockAchievementNFT is ERC721 {
    uint256 private _tokenIdCounter;

    constructor() ERC721("MockAchievement", "MACH") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _mint(to, tokenId);
        return tokenId;
    }
}

contract AggregateVerifierTest is Test {
    MockAchievementNFT public achievementNFT;
    AggregateVerifier public verifier;

    address public owner = address(this);
    address public user = address(0xBEEF);

    bytes32 public constant STUDENT = keccak256("STUDENT");
    bytes32 public constant CHAPTER_COMPLETE = keccak256("CHAPTER_COMPLETE");

    function setUp() public {
        achievementNFT = new MockAchievementNFT();
        verifier = new AggregateVerifier(address(achievementNFT));

        // Configure achievements
        verifier.setRequiredCount(STUDENT, 1);
        verifier.setRequiredCount(CHAPTER_COMPLETE, 10);
    }

    function test_Verify_ReturnsFalse_WhenNoAchievements() public view {
        bool result = verifier.verify(user, STUDENT, "");
        assertFalse(result);
    }

    function test_Verify_STUDENT_ReturnsTrue_WhenHasOneAchievement() public {
        achievementNFT.mint(user);

        bool result = verifier.verify(user, STUDENT, "");
        assertTrue(result);
    }

    function test_Verify_CHAPTER_COMPLETE_ReturnsFalse_WhenNotEnough() public {
        // Mint 9 achievements
        for (uint256 i = 0; i < 9; i++) {
            achievementNFT.mint(user);
        }

        bool result = verifier.verify(user, CHAPTER_COMPLETE, "");
        assertFalse(result);
    }

    function test_Verify_CHAPTER_COMPLETE_ReturnsTrue_WhenHas10() public {
        // Mint 10 achievements
        for (uint256 i = 0; i < 10; i++) {
            achievementNFT.mint(user);
        }

        bool result = verifier.verify(user, CHAPTER_COMPLETE, "");
        assertTrue(result);
    }

    function test_Verify_RevertsOnUnconfiguredAchievement() public {
        bytes32 unknownAch = keccak256("UNKNOWN");

        vm.expectRevert(abi.encodeWithSelector(AggregateVerifier.AchievementNotConfigured.selector, unknownAch));
        verifier.verify(user, unknownAch, "");
    }

    function test_SetRequiredCount_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.setRequiredCount(STUDENT, 5);
    }

    function test_BatchSetRequiredCount() public {
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = keccak256("TEST1");
        ids[1] = keccak256("TEST2");

        uint256[] memory counts = new uint256[](2);
        counts[0] = 5;
        counts[1] = 15;

        verifier.batchSetRequiredCount(ids, counts);

        assertEq(verifier.requiredCount(ids[0]), 5);
        assertEq(verifier.requiredCount(ids[1]), 15);
    }

    function test_BatchSetRequiredCount_RevertsOnLengthMismatch() public {
        bytes32[] memory ids = new bytes32[](2);
        uint256[] memory counts = new uint256[](1);

        vm.expectRevert(AggregateVerifier.LengthMismatch.selector);
        verifier.batchSetRequiredCount(ids, counts);
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(AggregateVerifier.ZeroAddress.selector);
        new AggregateVerifier(address(0));
    }
}
