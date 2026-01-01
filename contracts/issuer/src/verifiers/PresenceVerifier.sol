// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";
import {IProfileRegistry} from "../interfaces/IProfileRegistry.sol";

/// @title PresenceVerifier
/// @notice Verifies user has been registered for N days (FIRST_STEPS, STEADY_PACE, COMMITTED)
contract PresenceVerifier is IAchievementVerifier, Ownable {
    IProfileRegistry public immutable PROFILES;

    /// @notice Achievement ID to required days
    mapping(bytes32 => uint256) public requiredDays;

    event RequiredDaysSet(bytes32 indexed achievementId, uint256 days_);

    constructor(address profiles) Ownable(msg.sender) {
        if (profiles == address(0)) revert ZeroAddress();
        PROFILES = IProfileRegistry(profiles);
    }

    /// @notice Set required days for an achievement
    /// @param achievementId Achievement identifier
    /// @param days_ Number of days required
    function setRequiredDays(bytes32 achievementId, uint256 days_) external onlyOwner {
        requiredDays[achievementId] = days_;
        emit RequiredDaysSet(achievementId, days_);
    }

    /// @notice Batch set required days for multiple achievements
    /// @param achievementIds Array of achievement identifiers
    /// @param daysArr Array of required days
    function batchSetRequiredDays(
        bytes32[] calldata achievementIds,
        uint256[] calldata daysArr
    ) external onlyOwner {
        if (achievementIds.length != daysArr.length) revert LengthMismatch();
        for (uint256 i = 0; i < achievementIds.length; i++) {
            requiredDays[achievementIds[i]] = daysArr[i];
            emit RequiredDaysSet(achievementIds[i], daysArr[i]);
        }
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32 achievementId,
        bytes calldata
    ) external view returns (bool verified) {
        uint256 required = requiredDays[achievementId];
        if (required == 0) revert AchievementNotConfigured(achievementId);
        uint256 daysRegistered = PROFILES.getDaysRegistered(wallet);
        return daysRegistered >= required;
    }

    error ZeroAddress();
    error LengthMismatch();
    error AchievementNotConfigured(bytes32 achievementId);
}
