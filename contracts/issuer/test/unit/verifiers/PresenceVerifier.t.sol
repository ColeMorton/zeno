// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProfileRegistry} from "../../../src/ProfileRegistry.sol";
import {PresenceVerifier} from "../../../src/verifiers/PresenceVerifier.sol";

contract PresenceVerifierTest is Test {
    ProfileRegistry public registry;
    PresenceVerifier public verifier;

    address public owner = address(this);
    address public user = address(0xBEEF);

    bytes32 public constant FIRST_STEPS = keccak256("FIRST_STEPS");
    bytes32 public constant STEADY_PACE = keccak256("STEADY_PACE");
    bytes32 public constant COMMITTED = keccak256("COMMITTED");

    function setUp() public {
        registry = new ProfileRegistry();
        verifier = new PresenceVerifier(address(registry));

        // Configure achievements
        verifier.setRequiredDays(FIRST_STEPS, 15);
        verifier.setRequiredDays(STEADY_PACE, 30);
        verifier.setRequiredDays(COMMITTED, 60);
    }

    function test_Verify_ReturnsFalse_WhenNotEnoughDays() public {
        vm.prank(user);
        registry.createProfile();

        // Same day - should fail FIRST_STEPS (requires 15 days)
        bool result = verifier.verify(user, FIRST_STEPS, "");
        assertFalse(result);
    }

    function test_Verify_ReturnsTrue_WhenEnoughDays() public {
        vm.prank(user);
        registry.createProfile();

        // Fast forward 15 days
        vm.warp(block.timestamp + 15 days);

        bool result = verifier.verify(user, FIRST_STEPS, "");
        assertTrue(result);
    }

    function test_Verify_STEADY_PACE() public {
        vm.prank(user);
        registry.createProfile();

        // 29 days - should fail
        vm.warp(block.timestamp + 29 days);
        assertFalse(verifier.verify(user, STEADY_PACE, ""));

        // 30 days - should pass
        vm.warp(block.timestamp + 1 days);
        assertTrue(verifier.verify(user, STEADY_PACE, ""));
    }

    function test_Verify_COMMITTED() public {
        vm.prank(user);
        registry.createProfile();

        // 60 days
        vm.warp(block.timestamp + 60 days);
        assertTrue(verifier.verify(user, COMMITTED, ""));
    }

    function test_Verify_RevertsOnUnconfiguredAchievement() public {
        bytes32 unknownAch = keccak256("UNKNOWN");

        vm.expectRevert(abi.encodeWithSelector(PresenceVerifier.AchievementNotConfigured.selector, unknownAch));
        verifier.verify(user, unknownAch, "");
    }

    function test_SetRequiredDays_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.setRequiredDays(FIRST_STEPS, 20);
    }

    function test_BatchSetRequiredDays() public {
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = keccak256("TEST1");
        ids[1] = keccak256("TEST2");

        uint256[] memory days_ = new uint256[](2);
        days_[0] = 10;
        days_[1] = 20;

        verifier.batchSetRequiredDays(ids, days_);

        assertEq(verifier.requiredDays(ids[0]), 10);
        assertEq(verifier.requiredDays(ids[1]), 20);
    }

    function test_BatchSetRequiredDays_RevertsOnLengthMismatch() public {
        bytes32[] memory ids = new bytes32[](2);
        uint256[] memory days_ = new uint256[](1);

        vm.expectRevert(PresenceVerifier.LengthMismatch.selector);
        verifier.batchSetRequiredDays(ids, days_);
    }
}
