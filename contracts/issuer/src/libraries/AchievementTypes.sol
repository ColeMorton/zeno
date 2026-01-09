// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AchievementTypes - Shared achievement type constants
/// @notice Provides consistent achievement identifiers across issuer contracts
/// @dev Constants are accessible via AchievementTypes.MINTER, etc.
library AchievementTypes {
    // ==================== Achievement Type Constants ====================

    bytes32 public constant MINTER = keccak256("MINTER");
    bytes32 public constant MATURED = keccak256("MATURED");
    bytes32 public constant HODLER_SUPREME = keccak256("HODLER_SUPREME");
    bytes32 public constant FIRST_MONTH = keccak256("FIRST_MONTH");
    bytes32 public constant QUARTER_STACK = keccak256("QUARTER_STACK");
    bytes32 public constant HALF_YEAR = keccak256("HALF_YEAR");
    bytes32 public constant ANNUAL = keccak256("ANNUAL");
    bytes32 public constant DIAMOND_HANDS = keccak256("DIAMOND_HANDS");

    // ==================== Duration Constants ====================

    uint256 public constant FIRST_MONTH_DURATION = 30 days;
    uint256 public constant QUARTER_STACK_DURATION = 91 days;
    uint256 public constant HALF_YEAR_DURATION = 182 days;
    uint256 public constant ANNUAL_DURATION = 365 days;
    uint256 public constant DIAMOND_HANDS_DURATION = 730 days;
    uint256 public constant HODLER_SUPREME_DURATION = 1129 days;
}
