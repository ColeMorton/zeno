// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SignatureVerifier} from "../../../src/verifiers/SignatureVerifier.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SignatureVerifierTest is Test {
    using MessageHashUtils for bytes32;

    SignatureVerifier public verifier;

    uint256 public userPrivateKey = 0xA11CE;
    address public user;

    function setUp() public {
        verifier = new SignatureVerifier();
        user = vm.addr(userPrivateKey);
    }

    function test_Verify_ReturnsFalse_WhenNotSigned() public view {
        bool result = verifier.verify(user, bytes32(0), "");
        assertFalse(result);
    }

    function test_Verify_ReturnsTrue_WhenSigned() public {
        bytes memory signature = _signCommitment(userPrivateKey);

        vm.prank(user);
        verifier.signCommitment(signature);

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_SignCommitment_SetsTimestamp() public {
        bytes memory signature = _signCommitment(userPrivateKey);
        uint256 expectedTimestamp = block.timestamp;

        vm.prank(user);
        verifier.signCommitment(signature);

        assertEq(verifier.commitmentTimestamp(user), expectedTimestamp);
    }

    function test_SignCommitment_RevertsOnInvalidSignature() public {
        // Create signature from different key
        uint256 wrongKey = 0xB0B;
        bytes memory wrongSignature = _signCommitment(wrongKey);

        vm.prank(user);
        vm.expectRevert(SignatureVerifier.InvalidSignature.selector);
        verifier.signCommitment(wrongSignature);
    }

    function test_SignCommitment_RevertsOnAlreadySigned() public {
        bytes memory signature = _signCommitment(userPrivateKey);

        vm.startPrank(user);
        verifier.signCommitment(signature);

        vm.expectRevert(SignatureVerifier.AlreadySigned.selector);
        verifier.signCommitment(signature);
        vm.stopPrank();
    }

    function test_SignCommitment_EmitsEvent() public {
        bytes memory signature = _signCommitment(userPrivateKey);

        vm.expectEmit(true, false, false, true);
        emit SignatureVerifier.CommitmentSigned(user, block.timestamp);

        vm.prank(user);
        verifier.signCommitment(signature);
    }

    function test_COMMITMENT_MESSAGE_IsCorrect() public view {
        bytes32 expected = keccak256("I commit to The Ascent");
        assertEq(verifier.COMMITMENT_MESSAGE(), expected);
    }

    function _signCommitment(uint256 privateKey) internal view returns (bytes memory) {
        bytes32 messageHash = verifier.COMMITMENT_MESSAGE().toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }
}
