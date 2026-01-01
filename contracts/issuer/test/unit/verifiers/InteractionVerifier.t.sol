// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InteractionVerifier} from "../../../src/verifiers/InteractionVerifier.sol";

contract InteractionVerifierTest is Test {
    InteractionVerifier public verifier;

    address public owner = address(this);
    address public user = address(0xBEEF);
    address public recorder = address(0xCAFE);

    bytes32 public constant WALLET_WARMED = keccak256("WALLET_WARMED");
    bytes32 public constant EXPLORER = keccak256("EXPLORER");
    bytes32 public constant REGULAR = keccak256("REGULAR");

    function setUp() public {
        // Set timestamp to a reasonable value so day calculation works
        vm.warp(1704067200); // Jan 1, 2024

        verifier = new InteractionVerifier();

        // Authorize recorder
        verifier.authorizeRecorder(recorder);

        // Configure achievements
        verifier.setRequirements(WALLET_WARMED, 1, 0);
        verifier.setRequirements(EXPLORER, 3, 0);
        verifier.setRequirements(REGULAR, 3, 3);
    }

    function test_Verify_WALLET_WARMED_ReturnsFalse_WhenNoInteractions() public view {
        bool result = verifier.verify(user, WALLET_WARMED, "");
        assertFalse(result);
    }

    function test_Verify_WALLET_WARMED_ReturnsTrue_WhenHasOneInteraction() public {
        vm.prank(recorder);
        verifier.recordInteraction(user);

        bool result = verifier.verify(user, WALLET_WARMED, "");
        assertTrue(result);
    }

    function test_Verify_EXPLORER_ReturnsTrue_WhenHas3Interactions() public {
        vm.startPrank(recorder);
        verifier.recordInteraction(user);
        verifier.recordInteraction(user);
        verifier.recordInteraction(user);
        vm.stopPrank();

        bool result = verifier.verify(user, EXPLORER, "");
        assertTrue(result);
    }

    function test_Verify_REGULAR_ReturnsFalse_WhenSameDayInteractions() public {
        // 3 interactions on same day
        vm.startPrank(recorder);
        verifier.recordInteraction(user);
        verifier.recordInteraction(user);
        verifier.recordInteraction(user);
        vm.stopPrank();

        // Has 3 interactions but only 1 unique day
        bool result = verifier.verify(user, REGULAR, "");
        assertFalse(result);
    }

    function test_Verify_REGULAR_ReturnsTrue_WhenAcross3Days() public {
        vm.startPrank(recorder);

        // Day 1
        verifier.recordInteraction(user);

        // Day 2
        vm.warp(block.timestamp + 1 days);
        verifier.recordInteraction(user);

        // Day 3
        vm.warp(block.timestamp + 1 days);
        verifier.recordInteraction(user);

        vm.stopPrank();

        bool result = verifier.verify(user, REGULAR, "");
        assertTrue(result);
    }

    function test_RecordInteraction_RevertsForUnauthorized() public {
        vm.prank(user);
        vm.expectRevert(InteractionVerifier.NotAuthorizedRecorder.selector);
        verifier.recordInteraction(user);
    }

    function test_AuthorizeRecorder_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.authorizeRecorder(user);
    }

    function test_RevokeRecorder() public {
        verifier.revokeRecorder(recorder);

        vm.prank(recorder);
        vm.expectRevert(InteractionVerifier.NotAuthorizedRecorder.selector);
        verifier.recordInteraction(user);
    }

    function test_Verify_RevertsOnUnconfiguredAchievement() public {
        bytes32 unknownAch = keccak256("UNKNOWN");

        vm.expectRevert(abi.encodeWithSelector(InteractionVerifier.AchievementNotConfigured.selector, unknownAch));
        verifier.verify(user, unknownAch, "");
    }

    function test_UniqueDays_CountsCorrectly() public {
        vm.startPrank(recorder);

        // Multiple interactions on same day = 1 unique day
        verifier.recordInteraction(user);
        verifier.recordInteraction(user);
        assertEq(verifier.uniqueDays(user), 1);
        assertEq(verifier.interactionCount(user), 2);

        // New day
        vm.warp(block.timestamp + 1 days);
        verifier.recordInteraction(user);
        assertEq(verifier.uniqueDays(user), 2);
        assertEq(verifier.interactionCount(user), 3);

        vm.stopPrank();
    }
}
