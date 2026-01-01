// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IProfileRegistry
/// @notice Interface for on-chain profile storage used for achievement verification
interface IProfileRegistry {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a profile is created
    event ProfileCreated(address indexed wallet, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error AlreadyRegistered();

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create an on-chain profile for the caller
    function createProfile() external;

    /// @notice Check if a wallet has created a profile
    /// @param wallet Address to check
    /// @return True if wallet has a profile
    function hasProfile(address wallet) external view returns (bool);

    /// @notice Get the timestamp when a wallet registered
    /// @param wallet Address to check
    /// @return Registration timestamp (0 if not registered)
    function registeredAt(address wallet) external view returns (uint256);

    /// @notice Get number of days since registration
    /// @param wallet Address to check
    /// @return Days since registration (0 if not registered)
    function getDaysRegistered(address wallet) external view returns (uint256);
}
