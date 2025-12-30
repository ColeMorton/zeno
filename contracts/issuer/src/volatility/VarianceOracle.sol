// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVarianceOracle} from "./interfaces/IVarianceOracle.sol";

/// @title VarianceOracle
/// @notice Price ratio observation and variance calculation for vBTC/BTC
/// @dev Provides permissionless observations with configurable TWAP source
contract VarianceOracle is IVarianceOracle {
    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceOracle
    address public immutable twapOracle;

    /// @inheritdoc IVarianceOracle
    uint256 public immutable minObservationInterval;

    /// @inheritdoc IVarianceOracle
    uint32 public immutable twapPeriod;

    /// @inheritdoc IVarianceOracle
    uint256 public immutable maxStaleness;

    /// @inheritdoc IVarianceOracle
    uint256 public immutable minPriceRatio;

    /// @inheritdoc IVarianceOracle
    uint256 public immutable maxPriceRatio;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Precision for fixed-point math (18 decimals)
    uint256 private constant PRECISION = 1e18;

    /// @dev Natural log precision constant for ln calculations
    int256 private constant LN_PRECISION = 1e18;

    /// @dev Maximum iterations for ln calculation
    uint256 private constant LN_MAX_ITERATIONS = 100;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Array of all recorded observations
    Observation[] private _observations;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _twapOracle Address of TWAP oracle (IVBTCOracle compatible)
    /// @param _minObservationInterval Minimum seconds between observations
    /// @param _twapPeriod TWAP period for price queries (seconds)
    /// @param _maxStaleness Maximum staleness before oracle is stale
    /// @param _minPriceRatio Minimum valid price ratio (18 decimals)
    /// @param _maxPriceRatio Maximum valid price ratio (18 decimals)
    constructor(
        address _twapOracle,
        uint256 _minObservationInterval,
        uint32 _twapPeriod,
        uint256 _maxStaleness,
        uint256 _minPriceRatio,
        uint256 _maxPriceRatio
    ) {
        if (_twapOracle == address(0)) revert InvalidPriceRatio(0);
        if (_minPriceRatio >= _maxPriceRatio) revert InvalidPriceRatio(_minPriceRatio);

        twapOracle = _twapOracle;
        minObservationInterval = _minObservationInterval;
        twapPeriod = _twapPeriod;
        maxStaleness = _maxStaleness;
        minPriceRatio = _minPriceRatio;
        maxPriceRatio = _maxPriceRatio;
    }

    /*//////////////////////////////////////////////////////////////
                        OBSERVATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceOracle
    function getCurrentPriceRatio() public view returns (uint256 ratio) {
        // Call external oracle for TWAP price
        // Interface: function getTWAP(uint32 period) external view returns (uint256);
        (bool success, bytes memory data) = twapOracle.staticcall(
            abi.encodeWithSignature("getTWAP(uint32)", twapPeriod)
        );

        if (!success) revert OracleStale(0);

        ratio = abi.decode(data, (uint256));

        // Fail-fast bounds check
        if (ratio < minPriceRatio || ratio > maxPriceRatio) {
            revert PriceOutOfBounds(ratio);
        }
    }

    /// @inheritdoc IVarianceOracle
    function observe() external returns (Observation memory observation) {
        // Check minimum interval
        if (_observations.length > 0) {
            uint256 lastTime = _observations[_observations.length - 1].timestamp;
            if (block.timestamp < lastTime + minObservationInterval) {
                revert ObservationTooSoon(lastTime + minObservationInterval);
            }
        }

        // Get current price ratio
        uint256 currentRatio = getCurrentPriceRatio();

        // Calculate log return
        int256 logReturn = 0;
        if (_observations.length > 0) {
            uint256 previousRatio = _observations[_observations.length - 1].priceRatio;
            logReturn = calculateLogReturn(currentRatio, previousRatio);
        }

        // Create observation
        observation = Observation({
            timestamp: block.timestamp,
            priceRatio: currentRatio,
            logReturn: logReturn
        });

        // Store observation
        _observations.push(observation);

        emit PriceObserved(block.timestamp, currentRatio, logReturn);
    }

    /*//////////////////////////////////////////////////////////////
                        CALCULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceOracle
    function calculateLogReturn(
        uint256 currentRatio,
        uint256 previousRatio
    ) public pure returns (int256 logReturn) {
        if (previousRatio == 0) revert InvalidPriceRatio(previousRatio);

        // Calculate ratio: current / previous (scaled by PRECISION)
        uint256 ratio = (currentRatio * PRECISION) / previousRatio;

        // Calculate natural log
        logReturn = _ln(int256(ratio));
    }

    /// @inheritdoc IVarianceOracle
    function calculateVariance(
        int256[] calldata logReturns,
        uint256 observationsPerYear
    ) external pure returns (uint256 variance) {
        if (logReturns.length == 0) return 0;

        // Sum of squared log returns
        uint256 sumSquared = 0;
        for (uint256 i = 0; i < logReturns.length; i++) {
            int256 r = logReturns[i];
            // Square the log return (result is always positive)
            uint256 squared = uint256(r >= 0 ? r * r : (-r) * (-r));
            sumSquared += squared / PRECISION; // Adjust for double precision
        }

        // Annualize: variance = (observationsPerYear / N) * sumSquared
        variance = (sumSquared * observationsPerYear) / logReturns.length;
    }

    /// @inheritdoc IVarianceOracle
    function calculateVarianceFromSum(
        uint256 squaredLogReturns,
        uint256 observationCount,
        uint256 observationsPerYear
    ) external pure returns (uint256 variance) {
        if (observationCount == 0) return 0;

        // Annualize: variance = (observationsPerYear / N) * sumSquared
        variance = (squaredLogReturns * observationsPerYear) / observationCount;
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceOracle
    function getLatestObservation() external view returns (Observation memory) {
        if (_observations.length == 0) {
            return Observation({timestamp: 0, priceRatio: 0, logReturn: 0});
        }
        return _observations[_observations.length - 1];
    }

    /// @inheritdoc IVarianceOracle
    function getObservation(uint256 index) external view returns (Observation memory) {
        return _observations[index];
    }

    /// @inheritdoc IVarianceOracle
    function observationCount() external view returns (uint256) {
        return _observations.length;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculate natural logarithm using Taylor series
    /// @param x Input value (18 decimals, must be positive)
    /// @return result Natural log of x (18 decimals, signed)
    function _ln(int256 x) internal pure returns (int256 result) {
        // Handle edge cases
        if (x <= 0) return type(int256).min;
        if (x == LN_PRECISION) return 0;

        // Use the identity: ln(x) = 2 * artanh((x-1)/(x+1))
        // where artanh(y) = y + y^3/3 + y^5/5 + ...

        // Calculate y = (x - 1) / (x + 1)
        int256 numerator = x - LN_PRECISION;
        int256 denominator = x + LN_PRECISION;
        int256 y = (numerator * LN_PRECISION) / denominator;

        // Taylor series for artanh(y)
        int256 term = y;
        result = term;

        for (uint256 i = 1; i < LN_MAX_ITERATIONS; i++) {
            // term = term * y^2 / (2i + 1)
            term = (term * y * y) / (LN_PRECISION * LN_PRECISION);
            int256 divisor = int256(2 * i + 1);
            int256 contribution = term / divisor;

            if (contribution == 0) break;

            result += contribution;
        }

        // Multiply by 2 for the artanh identity
        result = result * 2;
    }
}
