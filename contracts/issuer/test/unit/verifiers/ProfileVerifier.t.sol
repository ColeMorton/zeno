// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProfileRegistry} from "../../../src/ProfileRegistry.sol";
import {ProfileVerifier} from "../../../src/verifiers/ProfileVerifier.sol";

contract ProfileVerifierTest is Test {
    ProfileRegistry public registry;
    ProfileVerifier public verifier;

    address public user = address(0xBEEF);

    function setUp() public {
        registry = new ProfileRegistry();
        verifier = new ProfileVerifier(address(registry));
    }

    function test_Verify_ReturnsFalse_WhenNoProfile() public view {
        bool result = verifier.verify(user, bytes32(0), "");
        assertFalse(result);
    }

    function test_Verify_ReturnsTrue_WhenHasProfile() public {
        vm.prank(user);
        registry.createProfile();

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(ProfileVerifier.ZeroAddress.selector);
        new ProfileVerifier(address(0));
    }
}
