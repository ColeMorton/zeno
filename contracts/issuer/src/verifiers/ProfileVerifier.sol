// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";
import {IProfileRegistry} from "../interfaces/IProfileRegistry.sol";

/// @title ProfileVerifier
/// @notice Verifies wallet has created an on-chain profile (TRAILHEAD achievement)
contract ProfileVerifier is IAchievementVerifier {
    IProfileRegistry public immutable PROFILES;

    constructor(address profiles) {
        if (profiles == address(0)) revert ZeroAddress();
        PROFILES = IProfileRegistry(profiles);
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32,
        bytes calldata
    ) external view returns (bool verified) {
        return PROFILES.hasProfile(wallet);
    }

    error ZeroAddress();
}
