// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";

/// @title AggregateVerifier
/// @notice Verifies N achievements completed (CHAPTER_COMPLETE, STUDENT)
contract AggregateVerifier is IAchievementVerifier, Ownable {
    /// @notice Achievement NFT contract (ERC721 with balanceOf)
    IERC721 public immutable ACHIEVEMENTS;

    /// @notice Achievement ID to required count
    mapping(bytes32 => uint256) public requiredCount;

    event RequiredCountSet(bytes32 indexed achievementId, uint256 count);

    constructor(address achievements) Ownable(msg.sender) {
        if (achievements == address(0)) revert ZeroAddress();
        ACHIEVEMENTS = IERC721(achievements);
    }

    /// @notice Set required achievement count for an achievement
    /// @param achievementId Achievement identifier
    /// @param count Number of achievements required
    function setRequiredCount(bytes32 achievementId, uint256 count) external onlyOwner {
        requiredCount[achievementId] = count;
        emit RequiredCountSet(achievementId, count);
    }

    /// @notice Batch set required counts for multiple achievements
    /// @param achievementIds Array of achievement identifiers
    /// @param counts Array of required counts
    function batchSetRequiredCount(
        bytes32[] calldata achievementIds,
        uint256[] calldata counts
    ) external onlyOwner {
        if (achievementIds.length != counts.length) revert LengthMismatch();
        for (uint256 i = 0; i < achievementIds.length; i++) {
            requiredCount[achievementIds[i]] = counts[i];
            emit RequiredCountSet(achievementIds[i], counts[i]);
        }
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32 achievementId,
        bytes calldata
    ) external view returns (bool verified) {
        uint256 required = requiredCount[achievementId];
        if (required == 0) revert AchievementNotConfigured(achievementId);
        return ACHIEVEMENTS.balanceOf(wallet) >= required;
    }

    error ZeroAddress();
    error LengthMismatch();
    error AchievementNotConfigured(bytes32 achievementId);
}
