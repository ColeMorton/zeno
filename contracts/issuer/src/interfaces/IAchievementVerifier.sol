// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAchievementVerifier - Interface for achievement-specific verification
/// @notice Verifiers implement custom logic to determine if a wallet can claim an achievement
/// @dev Each achievement type (profile, presence, interaction, etc.) has its own verifier
interface IAchievementVerifier {
    /// @notice Verify if a wallet meets the requirements for an achievement
    /// @param wallet The wallet attempting to claim
    /// @param achievementId The achievement being claimed
    /// @param data Optional verification data (e.g., signatures, proofs)
    /// @return verified True if the wallet meets the achievement requirements
    function verify(
        address wallet,
        bytes32 achievementId,
        bytes calldata data
    ) external view returns (bool verified);
}
