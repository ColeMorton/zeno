// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReferralVerifier} from "../../../src/verifiers/ReferralVerifier.sol";

contract ReferralVerifierTest is Test {
    ReferralVerifier public verifier;

    address public owner = address(this);
    address public referrer = address(0xBEEF);
    address public referee = address(0xCAFE);
    address public recorder = address(0xDEAD);

    function setUp() public {
        verifier = new ReferralVerifier();
        verifier.authorizeRecorder(recorder);
    }

    function test_Verify_ReturnsFalse_WhenNoReferrals() public view {
        bool result = verifier.verify(referrer, bytes32(0), "");
        assertFalse(result);
    }

    function test_Verify_ReturnsTrue_WhenHasReferral() public {
        vm.prank(recorder);
        verifier.recordReferral(referrer, referee);

        bool result = verifier.verify(referrer, bytes32(0), "");
        assertTrue(result);
    }

    function test_RecordReferral_RevertsForUnauthorized() public {
        vm.prank(referrer);
        vm.expectRevert(ReferralVerifier.NotAuthorizedRecorder.selector);
        verifier.recordReferral(referrer, referee);
    }

    function test_RecordReferral_RevertsSelfReferral() public {
        vm.prank(recorder);
        vm.expectRevert(ReferralVerifier.SelfReferralNotAllowed.selector);
        verifier.recordReferral(referrer, referrer);
    }

    function test_RecordReferral_RevertsInvalidReferrer() public {
        vm.prank(recorder);
        vm.expectRevert(ReferralVerifier.InvalidReferrer.selector);
        verifier.recordReferral(address(0), referee);
    }

    function test_ReferralCount_Increments() public {
        vm.startPrank(recorder);
        verifier.recordReferral(referrer, referee);
        assertEq(verifier.referralCount(referrer), 1);

        verifier.recordReferral(referrer, address(0x1234));
        assertEq(verifier.referralCount(referrer), 2);
        vm.stopPrank();
    }

    function test_AuthorizeRecorder_OnlyOwner() public {
        vm.prank(referrer);
        vm.expectRevert();
        verifier.authorizeRecorder(referrer);
    }

    function test_RevokeRecorder() public {
        verifier.revokeRecorder(recorder);

        vm.prank(recorder);
        vm.expectRevert(ReferralVerifier.NotAuthorizedRecorder.selector);
        verifier.recordReferral(referrer, referee);
    }
}
