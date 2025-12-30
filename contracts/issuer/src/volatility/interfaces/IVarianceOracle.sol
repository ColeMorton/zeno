// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVarianceOracle
/// @notice Interface for price ratio observation and variance calculation
/// @dev Provides vBTC/BTC price ratio observations for variance swap settlement
interface IVarianceOracle {
    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice A single price observation
    struct Observation {
        uint256 timestamp;          // Block timestamp of observation
        uint256 priceRatio;         // vBTC/BTC ratio (18 decimals)
        int256 logReturn;           // Natural log of ratio change (18 decimals, signed)
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new observation is recorded
    event PriceObserved(
        uint256 indexed timestamp,
        uint256 priceRatio,
        int256 logReturn
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OracleStale(uint256 lastUpdate);
    error InvalidPriceRatio(uint256 ratio);
    error ObservationTooSoon(uint256 nextAllowed);
    error PriceOutOfBounds(uint256 price);

    /*//////////////////////////////////////////////////////////////
                          OBSERVATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current vBTC/BTC price ratio from DEX TWAP
    /// @return ratio Price ratio with 18 decimals (e.g., 0.85e18 = 85%)
    function getCurrentPriceRatio() external view returns (uint256 ratio);

    /// @notice Record a new observation (permissionless)
    /// @return observation The recorded observation
    /// @dev Enforces minimum interval between observations
    function observe() external returns (Observation memory observation);

    /*//////////////////////////////////////////////////////////////
                        CALCULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate log return between two price ratios
    /// @param currentRatio Current price ratio (18 decimals)
    /// @param previousRatio Previous price ratio (18 decimals)
    /// @return logReturn Natural log of (current/previous) (18 decimals, signed)
    function calculateLogReturn(
        uint256 currentRatio,
        uint256 previousRatio
    ) external pure returns (int256 logReturn);

    /// @notice Calculate annualized variance from log returns
    /// @param logReturns Array of log returns (18 decimals, signed)
    /// @param observationsPerYear Annualization factor (e.g., 252 for daily)
    /// @return variance Annualized variance (18 decimals)
    function calculateVariance(
        int256[] calldata logReturns,
        uint256 observationsPerYear
    ) external pure returns (uint256 variance);

    /// @notice Calculate variance from squared log returns
    /// @param squaredLogReturns Sum of squared log returns
    /// @param observationCount Number of observations
    /// @param observationsPerYear Annualization factor
    /// @return variance Annualized variance (18 decimals)
    function calculateVarianceFromSum(
        uint256 squaredLogReturns,
        uint256 observationCount,
        uint256 observationsPerYear
    ) external pure returns (uint256 variance);

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get latest observation
    function getLatestObservation() external view returns (Observation memory);

    /// @notice Get historical observation by index
    function getObservation(uint256 index) external view returns (Observation memory);

    /// @notice Get total number of observations
    function observationCount() external view returns (uint256);

    /// @notice Get TWAP oracle address (for price ratio source)
    function twapOracle() external view returns (address);

    /// @notice Minimum time between observations
    function minObservationInterval() external view returns (uint256);

    /// @notice TWAP period used for price queries
    function twapPeriod() external view returns (uint32);

    /// @notice Maximum staleness before oracle is considered stale
    function maxStaleness() external view returns (uint256);

    /// @notice Minimum valid price ratio (fail-fast bound)
    function minPriceRatio() external view returns (uint256);

    /// @notice Maximum valid price ratio (fail-fast bound)
    function maxPriceRatio() external view returns (uint256);
}
