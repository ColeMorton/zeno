// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";

/// @title SignatureVerifier
/// @notice Verifies signed commitment attestation (RESOLUTE achievement)
contract SignatureVerifier is IAchievementVerifier {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @notice Message that must be signed
    bytes32 public constant COMMITMENT_MESSAGE = keccak256("I commit to The Ascent");

    /// @notice Tracks wallets that have signed commitment
    mapping(address => bool) public hasSignedCommitment;

    /// @notice Timestamp when commitment was signed
    mapping(address => uint256) public commitmentTimestamp;

    event CommitmentSigned(address indexed wallet, uint256 timestamp);

    /// @notice Sign the commitment message
    /// @param signature EIP-191 personal signature of COMMITMENT_MESSAGE
    function signCommitment(bytes calldata signature) external {
        if (hasSignedCommitment[msg.sender]) revert AlreadySigned();

        bytes32 messageHash = COMMITMENT_MESSAGE.toEthSignedMessageHash();
        address signer = messageHash.recover(signature);

        if (signer != msg.sender) revert InvalidSignature();

        hasSignedCommitment[msg.sender] = true;
        commitmentTimestamp[msg.sender] = block.timestamp;

        emit CommitmentSigned(msg.sender, block.timestamp);
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32,
        bytes calldata
    ) external view returns (bool verified) {
        return hasSignedCommitment[wallet];
    }

    error AlreadySigned();
    error InvalidSignature();
}
