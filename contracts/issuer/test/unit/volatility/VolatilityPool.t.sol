// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VolatilityPool} from "../../../src/volatility/VolatilityPool.sol";
import {IVolatilityPool} from "../../../src/volatility/interfaces/IVolatilityPool.sol";
import {MockVarianceOracle} from "../../mocks/MockVarianceOracle.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

/// @title VolatilityPoolTest
/// @notice Unit tests for VolatilityPool
contract VolatilityPoolTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant ONE_VBTC = 1e8;
    uint256 constant PRECISION = 1e18;
    uint256 constant STRIKE_VARIANCE = 4e16; // 4% annualized
    uint256 constant SETTLEMENT_INTERVAL = 1 days;
    uint256 constant VARIANCE_WINDOW = 7 days;
    uint256 constant MIN_DEPOSIT = 1e6; // 0.01 vBTC

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    VolatilityPool public pool;
    MockERC20 public vBTC;
    MockVarianceOracle public oracle;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Warp to a reasonable timestamp to avoid underflows
        vm.warp(1704067200); // Jan 1, 2024

        // Deploy token
        vBTC = new MockERC20("Vested BTC", "vBTC", 8);

        // Deploy mock oracle
        oracle = new MockVarianceOracle();

        // Deploy pool
        pool = new VolatilityPool(
            address(vBTC),
            address(oracle),
            STRIKE_VARIANCE,
            SETTLEMENT_INTERVAL,
            VARIANCE_WINDOW,
            MIN_DEPOSIT
        );

        // Fund users
        vBTC.mint(alice, 100 * ONE_VBTC);
        vBTC.mint(bob, 100 * ONE_VBTC);

        // Approve pool
        vm.prank(alice);
        vBTC.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        vBTC.approve(address(pool), type(uint256).max);

        // Add some initial observations to oracle
        _addObservationsWithVariance(STRIKE_VARIANCE);
    }

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DepositLong() public {
        vm.prank(alice);
        uint256 shares = pool.depositLong(ONE_VBTC);

        assertEq(shares, ONE_VBTC);
        assertEq(pool.longPoolAssets(), ONE_VBTC);
        assertEq(pool.longPoolShares(), ONE_VBTC);
        assertEq(pool.longSharesOf(alice), ONE_VBTC);
        assertEq(vBTC.balanceOf(address(pool)), ONE_VBTC);
    }

    function test_DepositShort() public {
        vm.prank(bob);
        uint256 shares = pool.depositShort(ONE_VBTC);

        assertEq(shares, ONE_VBTC);
        assertEq(pool.shortPoolAssets(), ONE_VBTC);
        assertEq(pool.shortPoolShares(), ONE_VBTC);
        assertEq(pool.shortSharesOf(bob), ONE_VBTC);
    }

    function test_DepositLong_MultipleDepositors() public {
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(bob);
        uint256 shares = pool.depositLong(2 * ONE_VBTC);

        assertEq(shares, 2 * ONE_VBTC);
        assertEq(pool.longPoolAssets(), 3 * ONE_VBTC);
        assertEq(pool.longPoolShares(), 3 * ONE_VBTC);
    }

    function test_DepositLong_RevertsBelowMinimum() public {
        vm.prank(alice);
        vm.expectRevert(IVolatilityPool.ZeroAmount.selector);
        pool.depositLong(MIN_DEPOSIT - 1);
    }

    function test_DepositShort_RevertsBelowMinimum() public {
        vm.prank(bob);
        vm.expectRevert(IVolatilityPool.ZeroAmount.selector);
        pool.depositShort(MIN_DEPOSIT - 1);
    }

    /*//////////////////////////////////////////////////////////////
                         WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawLong() public {
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        uint256 balanceBefore = vBTC.balanceOf(alice);

        vm.prank(alice);
        uint256 assets = pool.withdrawLong(ONE_VBTC);

        assertEq(assets, ONE_VBTC);
        assertEq(pool.longPoolAssets(), 0);
        assertEq(pool.longPoolShares(), 0);
        assertEq(pool.longSharesOf(alice), 0);
        assertEq(vBTC.balanceOf(alice), balanceBefore + ONE_VBTC);
    }

    function test_WithdrawShort() public {
        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        vm.prank(bob);
        uint256 assets = pool.withdrawShort(ONE_VBTC);

        assertEq(assets, ONE_VBTC);
        assertEq(pool.shortPoolAssets(), 0);
    }

    function test_WithdrawLong_RevertsInsufficientShares() public {
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVolatilityPool.InsufficientShares.selector,
                2 * ONE_VBTC,
                ONE_VBTC
            )
        );
        pool.withdrawLong(2 * ONE_VBTC);
    }

    function test_WithdrawLong_RevertsZeroAmount() public {
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(alice);
        vm.expectRevert(IVolatilityPool.ZeroAmount.selector);
        pool.withdrawLong(0);
    }

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Settle_RevertsNotDue() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IVolatilityPool.SettlementNotDue.selector,
                block.timestamp + SETTLEMENT_INTERVAL
            )
        );
        pool.settle();
    }

    function test_Settle_AfterInterval() public {
        // Setup: both sides deposit
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        // Wait for settlement interval
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);

        // Should not revert
        pool.settle();

        assertEq(pool.lastSettlementTime(), block.timestamp);
    }

    function test_Settle_LongWins_HighVariance() public {
        // Setup: both sides deposit
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        uint256 longAssetsBefore = pool.longPoolAssets();
        uint256 shortAssetsBefore = pool.shortPoolAssets();

        // Set high variance (above strike)
        _addObservationsWithVariance(8e16); // 8% variance

        // Wait and settle
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // Long pool should have gained
        uint256 longAssetsAfter = pool.longPoolAssets();
        uint256 shortAssetsAfter = pool.shortPoolAssets();

        assertTrue(longAssetsAfter > longAssetsBefore);
        assertTrue(shortAssetsAfter < shortAssetsBefore);

        // Total should be conserved
        assertEq(longAssetsAfter + shortAssetsAfter, longAssetsBefore + shortAssetsBefore);
    }

    function test_Settle_ShortWins_LowVariance() public {
        // Setup: both sides deposit
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        uint256 longAssetsBefore = pool.longPoolAssets();
        uint256 shortAssetsBefore = pool.shortPoolAssets();

        // Set low variance (below strike)
        _addObservationsWithVariance(2e16); // 2% variance

        // Wait and settle
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // Short pool should have gained
        uint256 longAssetsAfter = pool.longPoolAssets();
        uint256 shortAssetsAfter = pool.shortPoolAssets();

        assertTrue(shortAssetsAfter > shortAssetsBefore);
        assertTrue(longAssetsAfter < longAssetsBefore);
    }

    function test_Settle_NoTransfer_AtStrike() public {
        // Setup: both sides deposit
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        uint256 longAssetsBefore = pool.longPoolAssets();
        uint256 shortAssetsBefore = pool.shortPoolAssets();

        // Set variance equal to strike
        _addObservationsWithVariance(STRIKE_VARIANCE);

        // Wait and settle
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // No change in assets
        assertEq(pool.longPoolAssets(), longAssetsBefore);
        assertEq(pool.shortPoolAssets(), shortAssetsBefore);
    }

    function test_Settle_OneSided_NoTransfer() public {
        // Only long deposits
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        uint256 longAssetsBefore = pool.longPoolAssets();

        // Set high variance
        _addObservationsWithVariance(10e16);

        // Wait and settle
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // No counterparty = no transfer
        assertEq(pool.longPoolAssets(), longAssetsBefore);
    }

    function test_Settle_ImbalancedPools() public {
        // 3:1 ratio
        vm.prank(alice);
        pool.depositLong(3 * ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        // Set high variance
        _addObservationsWithVariance(8e16);

        // Wait and settle
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // Transfer is based on matched amount (1 vBTC)
        // So long gains are limited by short pool size
        assertTrue(pool.longPoolAssets() > 3 * ONE_VBTC);
        assertTrue(pool.shortPoolAssets() < ONE_VBTC);
    }

    /*//////////////////////////////////////////////////////////////
                       SHARE PRICING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SharePricing_AfterSettlement() public {
        // Alice deposits first
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        // Long wins, Alice's shares worth more
        _addObservationsWithVariance(8e16);
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // Preview shows Alice's shares are worth more
        uint256 aliceAssets = pool.previewWithdrawLong(ONE_VBTC);
        assertTrue(aliceAssets > ONE_VBTC);

        // Bob's shares worth less
        uint256 bobAssets = pool.previewWithdrawShort(ONE_VBTC);
        assertTrue(bobAssets < ONE_VBTC);
    }

    function test_SharePricing_NewDepositorGetsProRataShares() public {
        // Alice deposits first
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        // Long wins
        _addObservationsWithVariance(8e16);
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // Charlie deposits after settlement
        address charlie = makeAddr("charlie");
        vBTC.mint(charlie, ONE_VBTC);
        vm.prank(charlie);
        vBTC.approve(address(pool), type(uint256).max);

        uint256 longAssetsBefore = pool.longPoolAssets();
        uint256 longSharesBefore = pool.longPoolShares();

        vm.prank(charlie);
        uint256 charlieShares = pool.depositLong(ONE_VBTC);

        // Charlie should get fewer shares because exchange rate is > 1
        assertTrue(charlieShares < ONE_VBTC);

        // But Charlie's shares should be worth the deposit
        uint256 charlieAssets = pool.previewWithdrawLong(charlieShares);
        assertApproxEqRel(charlieAssets, ONE_VBTC, 0.001e18);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IsSettlementDue() public {
        assertFalse(pool.isSettlementDue());

        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        assertTrue(pool.isSettlementDue());
    }

    function test_NextSettlementTime() public {
        uint256 expected = block.timestamp + SETTLEMENT_INTERVAL;
        assertEq(pool.nextSettlementTime(), expected);
    }

    function test_GetCurrentVariance() public {
        _addObservationsWithVariance(5e16);
        uint256 variance = pool.getCurrentVariance();
        assertApproxEqRel(variance, 5e16, 0.1e18); // 10% tolerance for calculation differences
    }

    function test_PreviewWithdrawLong() public {
        vm.prank(alice);
        pool.depositLong(ONE_VBTC);

        uint256 preview = pool.previewWithdrawLong(ONE_VBTC);
        assertEq(preview, ONE_VBTC);
    }

    function test_PreviewWithdrawShort() public {
        vm.prank(bob);
        pool.depositShort(ONE_VBTC);

        uint256 preview = pool.previewWithdrawShort(ONE_VBTC);
        assertEq(preview, ONE_VBTC);
    }

    /*//////////////////////////////////////////////////////////////
                       CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsImmutables() public {
        assertEq(pool.vBTC(), address(vBTC));
        assertEq(pool.varianceOracle(), address(oracle));
        assertEq(pool.strikeVariance(), STRIKE_VARIANCE);
        assertEq(pool.settlementInterval(), SETTLEMENT_INTERVAL);
        assertEq(pool.varianceWindow(), VARIANCE_WINDOW);
        assertEq(pool.minDeposit(), MIN_DEPOSIT);
    }

    function test_Constructor_RevertsZeroAddress() public {
        vm.expectRevert(IVolatilityPool.ZeroAddress.selector);
        new VolatilityPool(
            address(0),
            address(oracle),
            STRIKE_VARIANCE,
            SETTLEMENT_INTERVAL,
            VARIANCE_WINDOW,
            MIN_DEPOSIT
        );

        vm.expectRevert(IVolatilityPool.ZeroAddress.selector);
        new VolatilityPool(
            address(vBTC),
            address(0),
            STRIKE_VARIANCE,
            SETTLEMENT_INTERVAL,
            VARIANCE_WINDOW,
            MIN_DEPOSIT
        );
    }

    function test_Constructor_RevertsZeroMinDeposit() public {
        vm.expectRevert(IVolatilityPool.ZeroAmount.selector);
        new VolatilityPool(
            address(vBTC),
            address(oracle),
            STRIKE_VARIANCE,
            SETTLEMENT_INTERVAL,
            VARIANCE_WINDOW,
            0 // zero minDeposit should revert
        );
    }

    /*//////////////////////////////////////////////////////////////
                         CONSERVATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TotalAssets_Conserved() public {
        // Multiple deposits
        vm.prank(alice);
        pool.depositLong(5 * ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(3 * ONE_VBTC);

        uint256 totalDeposited = 8 * ONE_VBTC;

        // Multiple settlements with varying variance
        for (uint256 i = 0; i < 5; i++) {
            _addObservationsWithVariance((i + 1) * 2e16);
            vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
            pool.settle();
        }

        // Total assets should be conserved
        uint256 totalAssets = pool.longPoolAssets() + pool.shortPoolAssets();
        assertEq(totalAssets, totalDeposited);
    }

    function test_TotalAssets_ConservedAfterWithdrawals() public {
        vm.prank(alice);
        pool.depositLong(5 * ONE_VBTC);

        vm.prank(bob);
        pool.depositShort(3 * ONE_VBTC);

        // Settlement
        _addObservationsWithVariance(8e16);
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        // Alice withdraws half
        vm.prank(alice);
        uint256 aliceWithdrew = pool.withdrawLong(2.5e8);

        // Bob withdraws all
        uint256 bobShares = pool.shortSharesOf(bob);
        vm.prank(bob);
        uint256 bobWithdrew = pool.withdrawShort(bobShares);

        // Pool balance + withdrawals should equal total deposits
        uint256 remaining = vBTC.balanceOf(address(pool));
        uint256 totalOut = aliceWithdrew + bobWithdrew;
        assertEq(remaining + totalOut, 8 * ONE_VBTC);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DepositWithdraw_RoundTrip(uint256 amount) public {
        amount = bound(amount, MIN_DEPOSIT, 50 * ONE_VBTC);

        uint256 balanceBefore = vBTC.balanceOf(alice);

        vm.prank(alice);
        uint256 shares = pool.depositLong(amount);

        vm.prank(alice);
        uint256 assets = pool.withdrawLong(shares);

        // Should get back what was deposited
        assertEq(assets, amount);
        assertEq(vBTC.balanceOf(alice), balanceBefore);
    }

    function testFuzz_Settlement_ConservesValue(
        uint256 longDeposit,
        uint256 shortDeposit,
        uint256 variance
    ) public {
        longDeposit = bound(longDeposit, MIN_DEPOSIT, 50 * ONE_VBTC);
        shortDeposit = bound(shortDeposit, MIN_DEPOSIT, 50 * ONE_VBTC);
        variance = bound(variance, 1e15, 20e16); // 0.1% to 20%

        vm.prank(alice);
        pool.depositLong(longDeposit);

        vm.prank(bob);
        pool.depositShort(shortDeposit);

        uint256 totalBefore = pool.longPoolAssets() + pool.shortPoolAssets();

        _addObservationsWithVariance(variance);
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        pool.settle();

        uint256 totalAfter = pool.longPoolAssets() + pool.shortPoolAssets();

        // Value should be conserved
        assertEq(totalAfter, totalBefore);
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Add observations with target variance
    function _addObservationsWithVariance(uint256 targetVariance) internal {
        // Clear existing observations
        oracle.clearObservations();

        // Calculate log return that would give target variance
        // variance = (252 / n) * sum(r^2)
        // For n=7 observations: sum(r^2) = variance * 7 / 252
        // Each r^2 = variance / 36 (approx)
        // r = sqrt(variance / 36)

        uint256 n = 7;
        uint256 sqPerObs = (targetVariance * PRECISION) / 252;
        int256 logReturn = int256(_sqrt(sqPerObs));

        uint256 startTime = block.timestamp - VARIANCE_WINDOW;

        // Add observations
        uint256[] memory timestamps = new uint256[](n);
        uint256[] memory priceRatios = new uint256[](n);
        int256[] memory logReturns = new int256[](n);

        for (uint256 i = 0; i < n; i++) {
            timestamps[i] = startTime + (i * 1 days);
            priceRatios[i] = 0.85e18;
            logReturns[i] = logReturn;
        }

        oracle.addObservations(timestamps, priceRatios, logReturns);
    }

    /// @dev Integer square root using Babylonian method
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
