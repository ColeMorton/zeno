// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockTWAPOracle - Controllable TWAP oracle for VarianceOracle simulation
/// @dev VarianceOracle calls getTWAP(uint32) via staticcall on its twapOracle
contract MockTWAPOracle {
    uint256 private _twap;

    error TWAPOutOfBounds(uint256 twap);

    constructor(uint256 initialTwap) {
        if (initialTwap < 5e17 || initialTwap > 1e18) revert TWAPOutOfBounds(initialTwap);
        _twap = initialTwap;
    }

    /// @notice Set the TWAP value (called by test harness each tick)
    /// @param twap_ New TWAP in 18 decimals, bounded [0.5e18, 1e18]
    function setTWAP(uint256 twap_) external {
        if (twap_ < 5e17 || twap_ > 1e18) revert TWAPOutOfBounds(twap_);
        _twap = twap_;
    }

    /// @notice Get TWAP value (called by VarianceOracle)
    /// @param period TWAP period (unused in mock, real oracle uses this)
    /// @return TWAP value in 18 decimals
    function getTWAP(uint32 period) external view returns (uint256) {
        period; // silence unused warning
        return _twap;
    }
}
