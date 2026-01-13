// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVarianceOracle} from "../../src/volatility/interfaces/IVarianceOracle.sol";

/// @notice Mock variance oracle for testing VolatilityPool
contract MockVarianceOracle is IVarianceOracle {
    /// @dev Array of mock observations
    Observation[] private _observations;

    /// @dev Precision for fixed-point math
    uint256 private constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                              MOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a mock observation directly
    function addObservation(
        uint256 timestamp,
        uint256 priceRatio,
        int256 logReturn
    ) external {
        _observations.push(Observation({
            timestamp: timestamp,
            priceRatio: priceRatio,
            logReturn: logReturn
        }));

        emit PriceObserved(timestamp, priceRatio, logReturn);
    }

    /// @notice Add multiple observations at once
    function addObservations(
        uint256[] calldata timestamps,
        uint256[] calldata priceRatios,
        int256[] calldata logReturns
    ) external {
        require(timestamps.length == priceRatios.length && priceRatios.length == logReturns.length, "Length mismatch");

        for (uint256 i = 0; i < timestamps.length; i++) {
            _observations.push(Observation({
                timestamp: timestamps[i],
                priceRatio: priceRatios[i],
                logReturn: logReturns[i]
            }));

            emit PriceObserved(timestamps[i], priceRatios[i], logReturns[i]);
        }
    }

    /// @notice Clear all observations
    function clearObservations() external {
        delete _observations;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    function getCurrentPriceRatio() external view override returns (uint256 ratio) {
        if (_observations.length == 0) return 0.85e18; // Default
        return _observations[_observations.length - 1].priceRatio;
    }

    function observe() external override returns (Observation memory observation) {
        // Mock implementation - just return the latest if exists
        if (_observations.length > 0) {
            return _observations[_observations.length - 1];
        }
        // Return a default observation
        observation = Observation({
            timestamp: block.timestamp,
            priceRatio: 0.85e18,
            logReturn: 0
        });
        _observations.push(observation);
        emit PriceObserved(block.timestamp, 0.85e18, 0);
    }

    function calculateLogReturn(
        uint256 currentRatio,
        uint256 previousRatio
    ) external pure override returns (int256 logReturn) {
        if (previousRatio == 0) return 0;
        // Simplified: just return the percentage change scaled
        if (currentRatio >= previousRatio) {
            return int256(((currentRatio - previousRatio) * PRECISION) / previousRatio);
        } else {
            return -int256(((previousRatio - currentRatio) * PRECISION) / previousRatio);
        }
    }

    function calculateVariance(
        int256[] calldata logReturns,
        uint256 observationsPerYear
    ) external pure override returns (uint256 variance) {
        if (logReturns.length == 0) return 0;

        uint256 sumSquared = 0;
        for (uint256 i = 0; i < logReturns.length; i++) {
            int256 r = logReturns[i];
            uint256 squared = uint256(r >= 0 ? r * r : (-r) * (-r));
            sumSquared += squared / PRECISION;
        }

        variance = (sumSquared * observationsPerYear) / logReturns.length;
    }

    function calculateVarianceFromSum(
        uint256 squaredLogReturns,
        uint256 observationCount,
        uint256 observationsPerYear
    ) external pure override returns (uint256 variance) {
        if (observationCount == 0) return 0;
        variance = (squaredLogReturns * observationsPerYear) / observationCount;
    }

    function getLatestObservation() external view override returns (Observation memory) {
        if (_observations.length == 0) {
            return Observation({timestamp: 0, priceRatio: 0, logReturn: 0});
        }
        return _observations[_observations.length - 1];
    }

    function getObservation(uint256 index) external view override returns (Observation memory) {
        return _observations[index];
    }

    function observationCount() external view override returns (uint256) {
        return _observations.length;
    }

    function twapOracle() external pure override returns (address) {
        return address(0);
    }

    function minObservationInterval() external pure override returns (uint256) {
        return 1 hours;
    }

    function twapPeriod() external pure override returns (uint32) {
        return 1800; // 30 minutes
    }

    function maxStaleness() external pure override returns (uint256) {
        return 1 hours;
    }

    function minPriceRatio() external pure override returns (uint256) {
        return 0.50e18;
    }

    function maxPriceRatio() external pure override returns (uint256) {
        return 1.00e18;
    }
}
