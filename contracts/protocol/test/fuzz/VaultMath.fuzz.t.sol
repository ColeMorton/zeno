// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultMath} from "../../src/libraries/VaultMath.sol";

contract VaultMathFuzzTest is Test {
    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1093 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;
    uint256 internal constant DORMANCY_THRESHOLD = 1093 days;
    uint256 internal constant GRACE_PERIOD = 30 days;
    uint256 internal constant BASIS_POINTS = 100000;

    // ========== getTierRate Tests ==========

    function test_GetTierRate_AllValidTiers() public pure {
        assertEq(VaultMath.getTierRate(0), 833);   // Conservative
        assertEq(VaultMath.getTierRate(1), 1140);  // Balanced
        assertEq(VaultMath.getTierRate(2), 1590);  // Aggressive
    }

    function test_GetTierRate_InvalidTier_Reverts() public {
        // Library reverts with "Invalid tier" for tier > 2
        // Using try/catch since library reverts are internal
        bool reverted = false;
        try this.callGetTierRate(3) returns (uint256) {
            // Should not reach here
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "Should revert for invalid tier");
    }

    // Helper to make external call for try/catch
    function callGetTierRate(uint8 tier) external pure returns (uint256) {
        return VaultMath.getTierRate(tier);
    }

    // ========== calculateWithdrawal Fuzz Tests ==========

    function testFuzz_CalculateWithdrawal_ConservativeTier(uint256 collateral) public pure {
        collateral = bound(collateral, 1, type(uint128).max);
        uint256 result = VaultMath.calculateWithdrawal(collateral, 0);
        uint256 expected = (collateral * 833) / BASIS_POINTS;
        assertEq(result, expected);
    }

    function testFuzz_CalculateWithdrawal_BalancedTier(uint256 collateral) public pure {
        collateral = bound(collateral, 1, type(uint128).max);
        uint256 result = VaultMath.calculateWithdrawal(collateral, 1);
        uint256 expected = (collateral * 1140) / BASIS_POINTS;
        assertEq(result, expected);
    }

    function testFuzz_CalculateWithdrawal_AggressiveTier(uint256 collateral) public pure {
        collateral = bound(collateral, 1, type(uint128).max);
        uint256 result = VaultMath.calculateWithdrawal(collateral, 2);
        uint256 expected = (collateral * 1590) / BASIS_POINTS;
        assertEq(result, expected);
    }

    function testFuzz_CalculateWithdrawal_AllTiers(uint256 collateral, uint8 tier) public pure {
        // Minimum collateral for non-zero withdrawal: 100000 / 833 = 121
        collateral = bound(collateral, 121, type(uint128).max);
        tier = uint8(bound(tier, 0, 2));

        uint256 result = VaultMath.calculateWithdrawal(collateral, tier);

        // Result should always be less than collateral (rate < 100%)
        assertLt(result, collateral);
        // Result should be non-zero for sufficient collateral
        assertGt(result, 0);
    }

    function test_CalculateWithdrawal_DustAmount() public pure {
        // Test with 1 satoshi
        uint256 result = VaultMath.calculateWithdrawal(1, 0);
        // 1 * 833 / 100000 = 0 (rounding down)
        assertEq(result, 0);

        // Minimum amount for non-zero withdrawal at conservative tier
        // collateral * 833 / 100000 >= 1
        // collateral >= 100000 / 833 = 120.05 -> 121
        result = VaultMath.calculateWithdrawal(121, 0);
        assertGt(result, 0);
    }

    function test_CalculateWithdrawal_OneBTC() public pure {
        uint256 result = VaultMath.calculateWithdrawal(ONE_BTC, 0);
        // 1e8 * 833 / 100000 = 833000 satoshis = 0.00833 BTC
        assertEq(result, 833000);
    }

    function testFuzz_CalculateWithdrawal_RoundingLoss(uint256 collateral, uint8 tier) public pure {
        collateral = bound(collateral, 1, type(uint128).max);
        tier = uint8(bound(tier, 0, 2));

        uint256 result = VaultMath.calculateWithdrawal(collateral, tier);
        uint256 rate = VaultMath.getTierRate(tier);

        // Verify rounding is always down (truncation)
        uint256 exactProduct = collateral * rate;
        uint256 reconstructed = result * BASIS_POINTS;
        assertLe(reconstructed, exactProduct);
    }

    // ========== calculateEarlyRedemption Fuzz Tests ==========

    function testFuzz_CalculateEarlyRedemption_BeforeMint(
        uint256 collateral,
        uint256 mintTime,
        uint256 currentTime
    ) public pure {
        collateral = bound(collateral, 1, type(uint128).max);
        mintTime = bound(mintTime, 1, type(uint128).max);
        currentTime = bound(currentTime, 0, mintTime);

        (uint256 returned, uint256 forfeited) = VaultMath.calculateEarlyRedemption(
            collateral, mintTime, currentTime
        );

        assertEq(returned, 0);
        assertEq(forfeited, collateral);
    }

    function testFuzz_CalculateEarlyRedemption_AfterVesting(
        uint256 collateral,
        uint256 mintTime,
        uint256 extraTime
    ) public pure {
        collateral = bound(collateral, 1, type(uint128).max);
        mintTime = bound(mintTime, 0, type(uint64).max);
        extraTime = bound(extraTime, 0, type(uint64).max);
        uint256 currentTime = mintTime + VESTING_PERIOD + extraTime;

        (uint256 returned, uint256 forfeited) = VaultMath.calculateEarlyRedemption(
            collateral, mintTime, currentTime
        );

        assertEq(returned, collateral);
        assertEq(forfeited, 0);
    }

    function testFuzz_CalculateEarlyRedemption_DuringVesting(
        uint256 collateral,
        uint256 mintTime,
        uint256 elapsed
    ) public pure {
        // Minimum collateral * elapsed / VESTING_PERIOD >= 1
        // For small elapsed (1 day), collateral >= VESTING_PERIOD / 1 day = 1093
        collateral = bound(collateral, VESTING_PERIOD, type(uint128).max);
        mintTime = bound(mintTime, 0, type(uint64).max);
        elapsed = bound(elapsed, 1 days, VESTING_PERIOD - 1 days);
        uint256 currentTime = mintTime + elapsed;

        (uint256 returned, uint256 forfeited) = VaultMath.calculateEarlyRedemption(
            collateral, mintTime, currentTime
        );

        // Conservation: returned + forfeited == collateral
        assertEq(returned + forfeited, collateral);

        // Returned should be proportional to elapsed time
        uint256 expectedReturned = (collateral * elapsed) / VESTING_PERIOD;
        assertEq(returned, expectedReturned);

        // Both should be non-zero during vesting with sufficient collateral
        assertGt(returned, 0);
        assertGt(forfeited, 0);
    }

    function test_CalculateEarlyRedemption_BoundaryConditions() public pure {
        uint256 collateral = ONE_BTC;
        uint256 mintTime = 1000;

        // Day 0 (at mint time)
        (uint256 r0, uint256 f0) = VaultMath.calculateEarlyRedemption(collateral, mintTime, mintTime);
        assertEq(r0, 0);
        assertEq(f0, collateral);

        // Day 1
        (uint256 r1, uint256 f1) = VaultMath.calculateEarlyRedemption(collateral, mintTime, mintTime + 1 days);
        assertGt(r1, 0);
        assertEq(r1 + f1, collateral);

        // Midpoint (day 546)
        (uint256 rMid, uint256 fMid) = VaultMath.calculateEarlyRedemption(
            collateral, mintTime, mintTime + 546 days
        );
        // Should be roughly 50%
        assertApproxEqRel(rMid, collateral / 2, 0.01e18); // 1% tolerance

        // Day 1092 (one day before vesting)
        (uint256 r1092, uint256 f1092) = VaultMath.calculateEarlyRedemption(
            collateral, mintTime, mintTime + 1092 days
        );
        assertGt(f1092, 0); // Still some forfeiture

        // Day 1093 (exactly at vesting)
        (uint256 r1093, uint256 f1093) = VaultMath.calculateEarlyRedemption(
            collateral, mintTime, mintTime + 1093 days
        );
        assertEq(r1093, collateral);
        assertEq(f1093, 0);
    }

    // ========== calculateMatchShare Fuzz Tests ==========

    function testFuzz_CalculateMatchShare_ProportionalDistribution(
        uint256 pool,
        uint256 holderCollateral,
        uint256 totalCollateral
    ) public pure {
        pool = bound(pool, 1, type(uint128).max);
        totalCollateral = bound(totalCollateral, 1, type(uint128).max);
        holderCollateral = bound(holderCollateral, 1, totalCollateral);

        uint256 share = VaultMath.calculateMatchShare(pool, holderCollateral, totalCollateral);

        // Share should be proportional
        uint256 expected = (pool * holderCollateral) / totalCollateral;
        assertEq(share, expected);

        // Share should not exceed pool
        assertLe(share, pool);
    }

    function testFuzz_CalculateMatchShare_ZeroPool(
        uint256 holderCollateral,
        uint256 totalCollateral
    ) public pure {
        holderCollateral = bound(holderCollateral, 1, type(uint128).max);
        totalCollateral = bound(totalCollateral, holderCollateral, type(uint128).max);

        uint256 share = VaultMath.calculateMatchShare(0, holderCollateral, totalCollateral);
        assertEq(share, 0);
    }

    function testFuzz_CalculateMatchShare_ZeroTotalCollateral(
        uint256 pool,
        uint256 holderCollateral
    ) public pure {
        pool = bound(pool, 1, type(uint128).max);
        holderCollateral = bound(holderCollateral, 1, type(uint128).max);

        uint256 share = VaultMath.calculateMatchShare(pool, holderCollateral, 0);
        assertEq(share, 0);
    }

    function test_CalculateMatchShare_SingleHolder() public pure {
        uint256 pool = ONE_BTC;
        uint256 share = VaultMath.calculateMatchShare(pool, ONE_BTC, ONE_BTC);
        assertEq(share, pool); // Gets entire pool
    }

    function test_CalculateMatchShare_EqualHolders() public pure {
        uint256 pool = ONE_BTC;
        // Two equal holders
        uint256 share1 = VaultMath.calculateMatchShare(pool, ONE_BTC, 2 * ONE_BTC);
        uint256 share2 = VaultMath.calculateMatchShare(pool, ONE_BTC, 2 * ONE_BTC);
        assertEq(share1, share2);
        assertEq(share1, pool / 2);
    }

    // ========== isVested Fuzz Tests ==========

    function testFuzz_IsVested_BeforeVesting(uint256 mintTime, uint256 elapsed) public pure {
        mintTime = bound(mintTime, 0, type(uint64).max);
        elapsed = bound(elapsed, 0, VESTING_PERIOD - 1);
        uint256 currentTime = mintTime + elapsed;

        assertFalse(VaultMath.isVested(mintTime, currentTime));
    }

    function testFuzz_IsVested_AfterVesting(uint256 mintTime, uint256 extraTime) public pure {
        mintTime = bound(mintTime, 0, type(uint64).max);
        extraTime = bound(extraTime, 0, type(uint64).max);
        uint256 currentTime = mintTime + VESTING_PERIOD + extraTime;

        assertTrue(VaultMath.isVested(mintTime, currentTime));
    }

    function test_IsVested_ExactBoundary() public pure {
        uint256 mintTime = 1000;

        assertFalse(VaultMath.isVested(mintTime, mintTime + VESTING_PERIOD - 1));
        assertTrue(VaultMath.isVested(mintTime, mintTime + VESTING_PERIOD));
        assertTrue(VaultMath.isVested(mintTime, mintTime + VESTING_PERIOD + 1));
    }

    // ========== canWithdraw Fuzz Tests ==========

    function testFuzz_CanWithdraw_BeforePeriod(uint256 lastWithdrawal, uint256 elapsed) public pure {
        lastWithdrawal = bound(lastWithdrawal, 0, type(uint64).max);
        elapsed = bound(elapsed, 0, WITHDRAWAL_PERIOD - 1);
        uint256 currentTime = lastWithdrawal + elapsed;

        assertFalse(VaultMath.canWithdraw(lastWithdrawal, currentTime));
    }

    function testFuzz_CanWithdraw_AfterPeriod(uint256 lastWithdrawal, uint256 extraTime) public pure {
        lastWithdrawal = bound(lastWithdrawal, 0, type(uint64).max);
        extraTime = bound(extraTime, 0, type(uint64).max);
        uint256 currentTime = lastWithdrawal + WITHDRAWAL_PERIOD + extraTime;

        assertTrue(VaultMath.canWithdraw(lastWithdrawal, currentTime));
    }

    function test_CanWithdraw_ExactBoundary() public pure {
        uint256 lastWithdrawal = 1000;

        assertFalse(VaultMath.canWithdraw(lastWithdrawal, lastWithdrawal + WITHDRAWAL_PERIOD - 1));
        assertTrue(VaultMath.canWithdraw(lastWithdrawal, lastWithdrawal + WITHDRAWAL_PERIOD));
        assertTrue(VaultMath.canWithdraw(lastWithdrawal, lastWithdrawal + WITHDRAWAL_PERIOD + 1));
    }

    // ========== isDormant Fuzz Tests ==========

    function testFuzz_IsDormant_BeforeThreshold(uint256 lastActivity, uint256 elapsed) public pure {
        lastActivity = bound(lastActivity, 0, type(uint64).max);
        elapsed = bound(elapsed, 0, DORMANCY_THRESHOLD - 1);
        uint256 currentTime = lastActivity + elapsed;

        assertFalse(VaultMath.isDormant(lastActivity, currentTime));
    }

    function testFuzz_IsDormant_AfterThreshold(uint256 lastActivity, uint256 extraTime) public pure {
        lastActivity = bound(lastActivity, 0, type(uint64).max);
        extraTime = bound(extraTime, 0, type(uint64).max);
        uint256 currentTime = lastActivity + DORMANCY_THRESHOLD + extraTime;

        assertTrue(VaultMath.isDormant(lastActivity, currentTime));
    }

    function test_IsDormant_ExactBoundary() public pure {
        uint256 lastActivity = 1000;

        assertFalse(VaultMath.isDormant(lastActivity, lastActivity + DORMANCY_THRESHOLD - 1));
        assertTrue(VaultMath.isDormant(lastActivity, lastActivity + DORMANCY_THRESHOLD));
        assertTrue(VaultMath.isDormant(lastActivity, lastActivity + DORMANCY_THRESHOLD + 1));
    }

    // ========== isGracePeriodExpired Fuzz Tests ==========

    function testFuzz_IsGracePeriodExpired_ZeroPokeTimestamp(uint256 currentTime) public pure {
        assertFalse(VaultMath.isGracePeriodExpired(0, currentTime));
    }

    function testFuzz_IsGracePeriodExpired_BeforePeriod(uint256 pokeTime, uint256 elapsed) public pure {
        pokeTime = bound(pokeTime, 1, type(uint64).max);
        elapsed = bound(elapsed, 0, GRACE_PERIOD - 1);
        uint256 currentTime = pokeTime + elapsed;

        assertFalse(VaultMath.isGracePeriodExpired(pokeTime, currentTime));
    }

    function testFuzz_IsGracePeriodExpired_AfterPeriod(uint256 pokeTime, uint256 extraTime) public pure {
        pokeTime = bound(pokeTime, 1, type(uint64).max);
        extraTime = bound(extraTime, 0, type(uint64).max);
        uint256 currentTime = pokeTime + GRACE_PERIOD + extraTime;

        assertTrue(VaultMath.isGracePeriodExpired(pokeTime, currentTime));
    }

    function test_IsGracePeriodExpired_ExactBoundary() public pure {
        uint256 pokeTime = 1000;

        assertFalse(VaultMath.isGracePeriodExpired(pokeTime, pokeTime + GRACE_PERIOD - 1));
        assertTrue(VaultMath.isGracePeriodExpired(pokeTime, pokeTime + GRACE_PERIOD));
        assertTrue(VaultMath.isGracePeriodExpired(pokeTime, pokeTime + GRACE_PERIOD + 1));
    }
}
