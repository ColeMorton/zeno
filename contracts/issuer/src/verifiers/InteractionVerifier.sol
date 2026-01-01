// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";

/// @title InteractionVerifier
/// @notice Tracks contract interactions per wallet (WALLET_WARMED, EXPLORER, REGULAR)
contract InteractionVerifier is IAchievementVerifier, Ownable {
    /// @notice Total interaction count per wallet
    mapping(address => uint256) public interactionCount;

    /// @notice Unique days with interactions per wallet
    mapping(address => uint256) public uniqueDays;

    /// @notice Last recorded day per wallet (prevents double-counting same day)
    mapping(address => uint256) private _lastDay;

    /// @notice Achievement ID to required interaction count
    mapping(bytes32 => uint256) public requiredInteractions;

    /// @notice Achievement ID to required unique days
    mapping(bytes32 => uint256) public requiredDays;

    /// @notice Addresses authorized to record interactions
    mapping(address => bool) public authorizedRecorders;

    event InteractionRecorded(address indexed wallet, uint256 totalCount, uint256 uniqueDays);
    event RequirementsSet(bytes32 indexed achievementId, uint256 interactions, uint256 days_);
    event RecorderAuthorized(address indexed recorder);
    event RecorderRevoked(address indexed recorder);

    constructor() Ownable(msg.sender) {}

    /// @notice Authorize an address to record interactions
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

    /// @notice Set requirements for an achievement
    /// @param achievementId Achievement identifier
    /// @param interactions Number of interactions required
    /// @param days_ Number of unique days required (0 = no day requirement)
    function setRequirements(
        bytes32 achievementId,
        uint256 interactions,
        uint256 days_
    ) external onlyOwner {
        requiredInteractions[achievementId] = interactions;
        requiredDays[achievementId] = days_;
        emit RequirementsSet(achievementId, interactions, days_);
    }

    /// @notice Record an interaction for a wallet
    /// @param wallet Wallet that interacted
    function recordInteraction(address wallet) external {
        if (!authorizedRecorders[msg.sender]) revert NotAuthorizedRecorder();

        interactionCount[wallet]++;

        uint256 currentDay = block.timestamp / 1 days;
        if (_lastDay[wallet] != currentDay) {
            _lastDay[wallet] = currentDay;
            uniqueDays[wallet]++;
        }

        emit InteractionRecorded(wallet, interactionCount[wallet], uniqueDays[wallet]);
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32 achievementId,
        bytes calldata
    ) external view returns (bool verified) {
        uint256 reqInteractions = requiredInteractions[achievementId];
        uint256 reqDays = requiredDays[achievementId];

        if (reqInteractions == 0 && reqDays == 0) {
            revert AchievementNotConfigured(achievementId);
        }

        bool interactionsOk = reqInteractions == 0 || interactionCount[wallet] >= reqInteractions;
        bool daysOk = reqDays == 0 || uniqueDays[wallet] >= reqDays;

        return interactionsOk && daysOk;
    }

    error NotAuthorizedRecorder();
    error AchievementNotConfigured(bytes32 achievementId);
}
