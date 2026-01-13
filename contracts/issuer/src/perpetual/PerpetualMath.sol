// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PerpetualMath
/// @notice Library for perpetual vault calculations (funding rate, P&L, payoffs)
/// @dev All calculations use fixed-point math with 18 decimal precision
library PerpetualMath {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant BPS = 10000;

    /// @dev Minimum payout: 0.01% (dust floor to avoid rounding to zero)
    uint256 internal constant MIN_PAYOUT_BPS = 1;

    /// @dev Maximum payout: 200% (2x deposit cap)
    uint256 internal constant MAX_PAYOUT_BPS = 20000;

    /// @dev Funding rate sensitivity: K in formula K × (longOI - shortOI) / totalOI
    /// @dev 5000 BPS = 50% max funding rate when fully one-sided
    uint256 internal constant FUNDING_SENSITIVITY_BPS = 5000;

    /// @dev Maximum funding rate per period (1% = 100 BPS)
    uint256 internal constant MAX_FUNDING_RATE_BPS = 100;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroPrice();
    error ZeroCollateral();

    /*//////////////////////////////////////////////////////////////
                         FUNDING RATE CALCULATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate current funding rate based on OI imbalance
    /// @dev fundingRate = K × (longOI - shortOI) / (longOI + shortOI)
    /// @param longOI Total long open interest
    /// @param shortOI Total short open interest
    /// @return rateBPS Funding rate in BPS (positive = longs pay shorts)
    function calculateFundingRate(
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (int256 rateBPS) {
        uint256 totalOI = longOI + shortOI;
        if (totalOI == 0) return 0;

        // Calculate OI delta as signed integer
        int256 oiDelta = int256(longOI) - int256(shortOI);

        // fundingRate = sensitivity × oiDelta / totalOI
        rateBPS = (int256(FUNDING_SENSITIVITY_BPS) * oiDelta) / int256(totalOI);

        // Cap at maximum funding rate
        if (rateBPS > int256(MAX_FUNDING_RATE_BPS)) {
            rateBPS = int256(MAX_FUNDING_RATE_BPS);
        } else if (rateBPS < -int256(MAX_FUNDING_RATE_BPS)) {
            rateBPS = -int256(MAX_FUNDING_RATE_BPS);
        }
    }

    /// @notice Calculate funding accumulator delta for a period
    /// @param fundingRateBPS Current funding rate in BPS
    /// @param periods Number of funding periods elapsed
    /// @return fundingDelta Per-notional funding delta (18 decimals)
    function calculateFundingDelta(
        int256 fundingRateBPS,
        uint256 periods
    ) internal pure returns (int256 fundingDelta) {
        // fundingDelta = (rateBPS / BPS) × periods × PRECISION
        // Simplified: (rateBPS × periods × PRECISION) / BPS
        fundingDelta = (fundingRateBPS * int256(periods) * int256(PRECISION)) / int256(BPS);
    }

    /*//////////////////////////////////////////////////////////////
                          P&L CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate direction P&L based on price movement
    /// @dev Long: (currentPrice - entryPrice) / entryPrice × notional
    /// @dev Short: (entryPrice - currentPrice) / entryPrice × notional
    /// @param notional Position notional (collateral × leverage)
    /// @param entryPrice Entry price (18 decimals)
    /// @param currentPrice Current price (18 decimals)
    /// @param isLong True for long, false for short
    /// @return pnl Direction P&L (can be negative)
    function calculateDirectionPnL(
        uint256 notional,
        uint256 entryPrice,
        uint256 currentPrice,
        bool isLong
    ) internal pure returns (int256 pnl) {
        if (entryPrice == 0) revert ZeroPrice();

        if (isLong) {
            // Long profits when price goes up
            if (currentPrice >= entryPrice) {
                pnl = int256((notional * (currentPrice - entryPrice)) / entryPrice);
            } else {
                pnl = -int256((notional * (entryPrice - currentPrice)) / entryPrice);
            }
        } else {
            // Short profits when price goes down
            if (currentPrice <= entryPrice) {
                pnl = int256((notional * (entryPrice - currentPrice)) / entryPrice);
            } else {
                pnl = -int256((notional * (currentPrice - entryPrice)) / entryPrice);
            }
        }
    }

    /// @notice Calculate funding P&L for a position
    /// @param notional Position notional
    /// @param entryFundingAccumulator Funding accumulator at position entry
    /// @param currentFundingAccumulator Current funding accumulator
    /// @return pnl Funding P&L (positive = received, negative = paid)
    function calculateFundingPnL(
        uint256 notional,
        int256 entryFundingAccumulator,
        int256 currentFundingAccumulator
    ) internal pure returns (int256 pnl) {
        // fundingPnL = notional × (currentAccumulator - entryAccumulator) / PRECISION
        int256 accumulatorDelta = currentFundingAccumulator - entryFundingAccumulator;
        pnl = (int256(notional) * accumulatorDelta) / int256(PRECISION);
    }

    /// @notice Calculate total P&L (direction + funding)
    /// @param directionPnL P&L from price movement
    /// @param fundingPnL P&L from funding payments
    /// @return totalPnL Combined P&L
    function calculateTotalPnL(
        int256 directionPnL,
        int256 fundingPnL
    ) internal pure returns (int256 totalPnL) {
        totalPnL = directionPnL + fundingPnL;
    }

    /*//////////////////////////////////////////////////////////////
                          CAPPED PAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate capped payout from collateral and P&L
    /// @dev Payout = clamp(collateral + pnl, 0.01% × collateral, 200% × collateral)
    /// @param collateral User's deposited collateral
    /// @param totalPnL Combined P&L (direction + funding)
    /// @return payout Capped payout amount
    function calculateCappedPayout(
        uint256 collateral,
        int256 totalPnL
    ) internal pure returns (uint256 payout) {
        if (collateral == 0) return 0;

        // Calculate raw payout
        int256 rawPayout;
        if (totalPnL >= 0) {
            rawPayout = int256(collateral) + totalPnL;
        } else {
            // Ensure we don't underflow
            if (uint256(-totalPnL) >= collateral) {
                rawPayout = 0;
            } else {
                rawPayout = int256(collateral) - int256(uint256(-totalPnL));
            }
        }

        // Calculate caps
        uint256 minPayout = (collateral * MIN_PAYOUT_BPS) / BPS;
        uint256 maxPayout = (collateral * MAX_PAYOUT_BPS) / BPS;

        // Apply caps
        if (rawPayout <= int256(minPayout)) {
            payout = minPayout;
        } else if (rawPayout >= int256(maxPayout)) {
            payout = maxPayout;
        } else {
            payout = uint256(rawPayout);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate notional from collateral and leverage
    /// @param collateral Deposit amount
    /// @param leverageX100 Leverage × 100
    /// @return notional Leveraged notional
    function calculateNotional(
        uint256 collateral,
        uint256 leverageX100
    ) internal pure returns (uint256 notional) {
        notional = (collateral * leverageX100) / 100;
    }
}
