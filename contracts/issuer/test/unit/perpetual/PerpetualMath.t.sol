// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpetualMath} from "../../../src/perpetual/PerpetualMath.sol";

/// @dev Helper contract to test library reverts
contract PerpetualMathWrapper {
    function calculateDirectionPnL(
        uint256 notional,
        uint256 entryPrice,
        uint256 currentPrice,
        bool isLong
    ) external pure returns (int256) {
        return PerpetualMath.calculateDirectionPnL(notional, entryPrice, currentPrice, isLong);
    }
}

/// @title PerpetualMathTest
/// @notice Unit tests for PerpetualMath library
contract PerpetualMathTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant PRECISION = 1e18;
    uint256 constant BPS = 10000;
    uint256 constant ONE_VBTC = 1e8;

    /*//////////////////////////////////////////////////////////////
                      FUNDING RATE CALCULATION
    //////////////////////////////////////////////////////////////*/

    function test_FundingRate_Balanced_ReturnsZero() public pure {
        // Equal longs and shorts = zero funding
        int256 rate = PerpetualMath.calculateFundingRate(100e8, 100e8);
        assertEq(rate, 0);
    }

    function test_FundingRate_MoreLongs_ReturnsPositive() public pure {
        // 60% longs, 40% shorts = positive funding (longs pay shorts)
        int256 rate = PerpetualMath.calculateFundingRate(60e8, 40e8);
        // K × (60 - 40) / (60 + 40) = 5000 × 20 / 100 = 1000 BPS
        assertTrue(rate > 0);
        // Expected: 5000 × 0.2 = 1000 BPS but capped at 100
        assertEq(rate, 100); // Capped at MAX_FUNDING_RATE_BPS
    }

    function test_FundingRate_MoreShorts_ReturnsNegative() public pure {
        // 40% longs, 60% shorts = negative funding (shorts pay longs)
        int256 rate = PerpetualMath.calculateFundingRate(40e8, 60e8);
        assertTrue(rate < 0);
        assertEq(rate, -100); // Capped at -MAX_FUNDING_RATE_BPS
    }

    function test_FundingRate_SmallImbalance() public pure {
        // 55% longs, 45% shorts
        int256 rate = PerpetualMath.calculateFundingRate(55e8, 45e8);
        // K × (55 - 45) / (55 + 45) = 5000 × 10 / 100 = 500 BPS
        // But capped at 100
        assertTrue(rate > 0);
    }

    function test_FundingRate_OnlyLongs_MaxPositive() public pure {
        // 100% longs, 0% shorts
        int256 rate = PerpetualMath.calculateFundingRate(100e8, 0);
        // K × (100 - 0) / (100 + 0) = 5000 BPS, capped at 100
        assertEq(rate, 100);
    }

    function test_FundingRate_OnlyShorts_MaxNegative() public pure {
        // 0% longs, 100% shorts
        int256 rate = PerpetualMath.calculateFundingRate(0, 100e8);
        assertEq(rate, -100);
    }

    function test_FundingRate_ZeroOI_ReturnsZero() public pure {
        int256 rate = PerpetualMath.calculateFundingRate(0, 0);
        assertEq(rate, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        FUNDING DELTA CALCULATION
    //////////////////////////////////////////////////////////////*/

    function test_FundingDelta_OnePeriod() public pure {
        // 100 BPS for 1 period
        int256 delta = PerpetualMath.calculateFundingDelta(100, 1);
        // (100 × 1 × 1e18) / 10000 = 0.01e18
        assertEq(delta, 0.01e18);
    }

    function test_FundingDelta_TenPeriods() public pure {
        // 50 BPS for 10 periods
        int256 delta = PerpetualMath.calculateFundingDelta(50, 10);
        // (50 × 10 × 1e18) / 10000 = 0.05e18
        assertEq(delta, 0.05e18);
    }

    function test_FundingDelta_Negative() public pure {
        // -100 BPS for 5 periods
        int256 delta = PerpetualMath.calculateFundingDelta(-100, 5);
        assertEq(delta, -0.05e18);
    }

    /*//////////////////////////////////////////////////////////////
                      DIRECTION P&L CALCULATION
    //////////////////////////////////////////////////////////////*/

    function test_DirectionPnL_Long_PriceUp10Percent() public pure {
        // Entry 0.85, current 0.935 (+10%)
        uint256 notional = 3e8; // 3 vBTC notional (1 vBTC at 3x)
        int256 pnl = PerpetualMath.calculateDirectionPnL(
            notional,
            0.85e18,
            0.935e18,
            true // long
        );

        // PnL = notional × (0.935 - 0.85) / 0.85 = 3 × 0.1 = 0.3 vBTC
        assertApproxEqRel(pnl, int256(0.3e8), 0.01e18);
    }

    function test_DirectionPnL_Long_PriceDown10Percent() public pure {
        // Entry 0.85, current 0.765 (-10%)
        uint256 notional = 3e8;
        int256 pnl = PerpetualMath.calculateDirectionPnL(
            notional,
            0.85e18,
            0.765e18,
            true // long
        );

        // PnL = -0.3 vBTC
        assertApproxEqRel(pnl, -int256(0.3e8), 0.01e18);
    }

    function test_DirectionPnL_Short_PriceDown10Percent() public pure {
        // Shorts profit when price goes down
        uint256 notional = 3e8;
        int256 pnl = PerpetualMath.calculateDirectionPnL(
            notional,
            0.85e18,
            0.765e18,
            false // short
        );

        // PnL = +0.3 vBTC
        assertApproxEqRel(pnl, int256(0.3e8), 0.01e18);
    }

    function test_DirectionPnL_Short_PriceUp10Percent() public pure {
        // Shorts lose when price goes up
        uint256 notional = 3e8;
        int256 pnl = PerpetualMath.calculateDirectionPnL(
            notional,
            0.85e18,
            0.935e18,
            false // short
        );

        // PnL = -0.3 vBTC
        assertApproxEqRel(pnl, -int256(0.3e8), 0.01e18);
    }

    function test_DirectionPnL_NoChange() public pure {
        uint256 notional = 3e8;
        int256 pnl = PerpetualMath.calculateDirectionPnL(
            notional,
            0.85e18,
            0.85e18, // Same price
            true
        );

        assertEq(pnl, 0);
    }

    function test_DirectionPnL_ZeroPrice_Reverts() public {
        PerpetualMathWrapper wrapper = new PerpetualMathWrapper();
        vm.expectRevert(PerpetualMath.ZeroPrice.selector);
        wrapper.calculateDirectionPnL(3e8, 0, 0.85e18, true);
    }

    /*//////////////////////////////////////////////////////////////
                        FUNDING P&L CALCULATION
    //////////////////////////////////////////////////////////////*/

    function test_FundingPnL_PositiveAccrual() public pure {
        // Position received funding
        uint256 notional = 3e8;
        int256 entryAccumulator = 0;
        int256 currentAccumulator = 0.01e18; // 1% accumulated funding

        int256 pnl = PerpetualMath.calculateFundingPnL(
            notional,
            entryAccumulator,
            currentAccumulator
        );

        // PnL = 3e8 × 0.01e18 / 1e18 = 0.03e8
        assertEq(pnl, int256(0.03e8));
    }

    function test_FundingPnL_NegativeAccrual() public pure {
        // Position paid funding
        uint256 notional = 3e8;
        int256 entryAccumulator = 0;
        int256 currentAccumulator = -0.02e18; // -2% accumulated

        int256 pnl = PerpetualMath.calculateFundingPnL(
            notional,
            entryAccumulator,
            currentAccumulator
        );

        assertEq(pnl, -int256(0.06e8));
    }

    function test_FundingPnL_NoChange() public pure {
        uint256 notional = 3e8;
        int256 pnl = PerpetualMath.calculateFundingPnL(notional, 0.05e18, 0.05e18);
        assertEq(pnl, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        CAPPED PAYOUT CALCULATION
    //////////////////////////////////////////////////////////////*/

    function test_CappedPayout_PositivePnL() public pure {
        // 30% gain
        uint256 collateral = 1e8;
        int256 pnl = int256(0.3e8);

        uint256 payout = PerpetualMath.calculateCappedPayout(collateral, pnl);

        // 1.3 vBTC
        assertEq(payout, 1.3e8);
    }

    function test_CappedPayout_NegativePnL() public pure {
        // 30% loss
        uint256 collateral = 1e8;
        int256 pnl = -int256(0.3e8);

        uint256 payout = PerpetualMath.calculateCappedPayout(collateral, pnl);

        // 0.7 vBTC
        assertEq(payout, 0.7e8);
    }

    function test_CappedPayout_HitsCap() public pure {
        // 150% gain (should cap at 200%)
        uint256 collateral = 1e8;
        int256 pnl = int256(1.5e8);

        uint256 payout = PerpetualMath.calculateCappedPayout(collateral, pnl);

        // Capped at 2x = 2 vBTC
        assertEq(payout, 2e8);
    }

    function test_CappedPayout_HitsFloor() public pure {
        // 150% loss (should floor at 0.01%)
        uint256 collateral = 1e8;
        int256 pnl = -int256(1.5e8);

        uint256 payout = PerpetualMath.calculateCappedPayout(collateral, pnl);

        // Floored at 0.01% = 0.0001 vBTC = 10000 units
        uint256 minPayout = (1e8 * 1) / 10000;
        assertEq(payout, minPayout);
    }

    function test_CappedPayout_ExactMax() public pure {
        // Exactly 100% gain = 200% payout (at cap)
        uint256 collateral = 1e8;
        int256 pnl = int256(1e8);

        uint256 payout = PerpetualMath.calculateCappedPayout(collateral, pnl);

        assertEq(payout, 2e8);
    }

    function test_CappedPayout_ZeroCollateral() public pure {
        uint256 payout = PerpetualMath.calculateCappedPayout(0, 100);
        assertEq(payout, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          NOTIONAL CALCULATION
    //////////////////////////////////////////////////////////////*/

    function test_CalculateNotional_3xLeverage() public pure {
        uint256 notional = PerpetualMath.calculateNotional(1e8, 300);
        assertEq(notional, 3e8);
    }

    function test_CalculateNotional_1xLeverage() public pure {
        uint256 notional = PerpetualMath.calculateNotional(1e8, 100);
        assertEq(notional, 1e8);
    }

    function test_CalculateNotional_5xLeverage() public pure {
        uint256 notional = PerpetualMath.calculateNotional(1e8, 500);
        assertEq(notional, 5e8);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CappedPayout_NeverExceedsCap(
        uint256 collateral,
        int256 pnl
    ) public pure {
        collateral = bound(collateral, 1, 1000e8);
        pnl = bound(pnl, -int256(2000e8), int256(2000e8));

        uint256 payout = PerpetualMath.calculateCappedPayout(collateral, pnl);

        uint256 maxPayout = (collateral * 20000) / BPS;
        uint256 minPayout = (collateral * 1) / BPS;

        assertLe(payout, maxPayout);
        assertGe(payout, minPayout);
    }

    function testFuzz_FundingRate_AlwaysCapped(
        uint256 longOI,
        uint256 shortOI
    ) public pure {
        longOI = bound(longOI, 0, 1000e8);
        shortOI = bound(shortOI, 0, 1000e8);

        int256 rate = PerpetualMath.calculateFundingRate(longOI, shortOI);

        // Always within [-100, 100] BPS
        assertLe(rate, 100);
        assertGe(rate, -100);
    }

    function testFuzz_DirectionPnL_ZeroSum(
        uint256 notional,
        uint256 entryPrice,
        uint256 currentPrice
    ) public pure {
        notional = bound(notional, 1e6, 100e8);
        entryPrice = bound(entryPrice, 0.5e18, 1e18);
        currentPrice = bound(currentPrice, 0.5e18, 1e18);

        int256 longPnL = PerpetualMath.calculateDirectionPnL(
            notional,
            entryPrice,
            currentPrice,
            true
        );

        int256 shortPnL = PerpetualMath.calculateDirectionPnL(
            notional,
            entryPrice,
            currentPrice,
            false
        );

        // Long PnL + Short PnL = 0 (zero-sum)
        assertEq(longPnL + shortPnL, 0);
    }
}
