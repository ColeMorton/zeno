// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";

/// @title ReferralVerifier
/// @notice Verifies successful referral (GUIDE achievement)
contract ReferralVerifier is IAchievementVerifier, Ownable {
    /// @notice Referral count per wallet
    mapping(address => uint256) public referralCount;

    /// @notice Addresses authorized to record referrals
    mapping(address => bool) public authorizedRecorders;

    event ReferralRecorded(address indexed referrer, address indexed referee, uint256 totalReferrals);
    event RecorderAuthorized(address indexed recorder);
    event RecorderRevoked(address indexed recorder);

    constructor() Ownable(msg.sender) {}

    /// @notice Authorize an address to record referrals
    /// @param recorder Address to authorize
    function authorizeRecorder(address recorder) external onlyOwner {
        authorizedRecorders[recorder] = true;
        emit RecorderAuthorized(recorder);
    }

    /// @notice Revoke recording authorization
    /// @param recorder Address to revoke
    function revokeRecorder(address recorder) external onlyOwner {
        authorizedRecorders[recorder] = false;
        emit RecorderRevoked(recorder);
    }

    /// @notice Record a referral
    /// @param referrer Address of the referrer
    /// @param referee Address of the person referred
    function recordReferral(address referrer, address referee) external {
        if (!authorizedRecorders[msg.sender]) revert NotAuthorizedRecorder();
        if (referrer == referee) revert SelfReferralNotAllowed();
        if (referrer == address(0)) revert InvalidReferrer();

        referralCount[referrer]++;
        emit ReferralRecorded(referrer, referee, referralCount[referrer]);
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32,
        bytes calldata
    ) external view returns (bool verified) {
        return referralCount[wallet] >= 1;
    }

    error NotAuthorizedRecorder();
    error SelfReferralNotAllowed();
    error InvalidReferrer();
}
