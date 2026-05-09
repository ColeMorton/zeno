// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {SimCurvePool} from "../src/mocks/SimCurvePool.sol";
import {ICurveCryptoSwap} from "@issuer/interfaces/ICurveCryptoSwap.sol";

/// @title MockToken - Simple ERC20 with public mint for testing
contract MockToken is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title SimCurvePoolTest - Unit tests for ratio bounds and AMM invariants
contract SimCurvePoolTest is Test {
    MockToken public wbtc;
    MockToken public vbtc;
    SimCurvePool public pool;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant PRECISION = 1e18;
    uint256 constant FEE_BPS = 30;
    uint256 constant BPS = 10000;
    uint256 constant RATIO_CEILING = 1.0e18;
    uint256 constant RATIO_FLOOR = 0.5e18;

    function setUp() public {
        wbtc = new MockToken("Wrapped BTC", "WBTC", 8);
        vbtc = new MockToken("vested BTC", "vBTC", 8);
        pool = new SimCurvePool(address(wbtc), address(vbtc));

        // Fund test accounts generously
        wbtc.mint(alice, 10_000_000e8);
        vbtc.mint(alice, 10_000_000e8);
        wbtc.mint(bob, 10_000_000e8);
        vbtc.mint(bob, 10_000_000e8);
    }

    // ==================== Helpers ====================

    function _initializePool(uint256 wbtcAmt, uint256 vbtcAmt) internal {
        vm.startPrank(alice);
        wbtc.approve(address(pool), wbtcAmt);
        vbtc.approve(address(pool), vbtcAmt);
        pool.add_liquidity([wbtcAmt, vbtcAmt], 0);
        vm.stopPrank();
    }

    function _expectedDy(uint256 reserveIn, uint256 reserveOut, uint256 dx)
        internal
        pure
        returns (uint256 dy)
    {
        uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
        dy = reserveOut * dxAfterFee / (reserveIn + dxAfterFee);
    }

    // ==================== Initialization Tests ====================

    function test_Initialize_InBounds() public {
        uint256 wbtcAmt = 800e8;
        uint256 vbtcAmt = 1000e8; // ratio = 0.8

        _initializePool(wbtcAmt, vbtcAmt);

        assertTrue(pool.initialized());
        assertEq(pool.spotPrice(), 0.8e18);
        assertEq(pool.reserve0(), wbtcAmt);
        assertEq(pool.reserve1(), vbtcAmt);
    }

    function test_Initialize_AtCeiling() public {
        uint256 wbtcAmt = 1000e8;
        uint256 vbtcAmt = 1000e8; // ratio = 1.0

        _initializePool(wbtcAmt, vbtcAmt);

        assertTrue(pool.initialized());
        assertEq(pool.spotPrice(), 1.0e18);
    }

    function test_Initialize_AtFloor() public {
        uint256 wbtcAmt = 500e8;
        uint256 vbtcAmt = 1000e8; // ratio = 0.5

        _initializePool(wbtcAmt, vbtcAmt);

        assertTrue(pool.initialized());
        assertEq(pool.spotPrice(), 0.5e18);
    }

    function test_Initialize_AboveCeiling() public {
        uint256 wbtcAmt = 1100e8;
        uint256 vbtcAmt = 1000e8; // ratio = 1.1

        vm.startPrank(alice);
        wbtc.approve(address(pool), wbtcAmt);
        vbtc.approve(address(pool), vbtcAmt);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.RatioBoundsExceeded.selector, 0, 1.1e18));
        pool.add_liquidity([wbtcAmt, vbtcAmt], 0);
        vm.stopPrank();

        assertFalse(pool.initialized());
    }

    function test_Initialize_BelowFloor() public {
        uint256 wbtcAmt = 400e8;
        uint256 vbtcAmt = 1000e8; // ratio = 0.4

        vm.startPrank(alice);
        wbtc.approve(address(pool), wbtcAmt);
        vbtc.approve(address(pool), vbtcAmt);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.RatioBoundsExceeded.selector, 0, 0.4e18));
        pool.add_liquidity([wbtcAmt, vbtcAmt], 0);
        vm.stopPrank();

        assertFalse(pool.initialized());
    }

    // ==================== Swap Within Bounds ====================

    function test_Swap_WbtcToVbtc_WithinBounds() public {
        _initializePool(800e8, 1000e8); // ratio = 0.8

        uint256 dx = 50e8;
        uint256 expectedDy = _expectedDy(800e8, 1000e8, dx);

        vm.startPrank(alice);
        wbtc.approve(address(pool), dx);
        uint256 dy = pool.exchange(0, 1, dx, expectedDy);
        vm.stopPrank();

        assertEq(dy, expectedDy);

        uint256 newRatio = pool.spotPrice();
        assertGt(newRatio, 0.8e18); // ratio increased
        assertLe(newRatio, RATIO_CEILING);
        assertGe(newRatio, RATIO_FLOOR);

        assertEq(pool.reserve0(), 800e8 + dx);
        assertEq(pool.reserve1(), 1000e8 - dy);
    }

    function test_Swap_VbtcToWbtc_WithinBounds() public {
        _initializePool(800e8, 1000e8); // ratio = 0.8

        uint256 dx = 100e8;
        uint256 expectedDy = _expectedDy(1000e8, 800e8, dx);

        vm.startPrank(alice);
        vbtc.approve(address(pool), dx);
        uint256 dy = pool.exchange(1, 0, dx, expectedDy);
        vm.stopPrank();

        assertEq(dy, expectedDy);

        uint256 newRatio = pool.spotPrice();
        assertLt(newRatio, 0.8e18); // ratio decreased
        assertLe(newRatio, RATIO_CEILING);
        assertGe(newRatio, RATIO_FLOOR);

        assertEq(pool.reserve0(), 800e8 - dy);
        assertEq(pool.reserve1(), 1000e8 + dx);
    }

    // ==================== Swap Bounds Enforcement ====================

    function test_Swap_WbtcToVbtc_ExceedsCeiling() public {
        _initializePool(1000e8, 1000e8); // ratio = 1.0

        // Any WBTC -> vBTC swap pushes ratio above 1.0
        uint256 dx = 1e8;
        uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
        uint256 dy = 1000e8 * dxAfterFee / (1000e8 + dxAfterFee);
        uint256 newRatio = (1000e8 + dx) * PRECISION / (1000e8 - dy);

        vm.startPrank(alice);
        wbtc.approve(address(pool), dx);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.RatioBoundsExceeded.selector, PRECISION, newRatio));
        pool.exchange(0, 1, dx, 0);
        vm.stopPrank();
    }

    function test_Swap_VbtcToWbtc_ExceedsFloor() public {
        _initializePool(500e8, 1000e8); // ratio = 0.5

        // Any vBTC -> WBTC swap pushes ratio below 0.5
        uint256 dx = 1e8;
        uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
        uint256 dy = 500e8 * dxAfterFee / (1000e8 + dxAfterFee);
        uint256 newRatio = (500e8 - dy) * PRECISION / (1000e8 + dx);

        vm.startPrank(alice);
        vbtc.approve(address(pool), dx);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.RatioBoundsExceeded.selector, RATIO_FLOOR, newRatio));
        pool.exchange(1, 0, dx, 0);
        vm.stopPrank();
    }

    function test_Swap_WbtcToVbtc_LargeButWithinBounds() public {
        _initializePool(800e8, 1000e8); // ratio = 0.8

        // Swap a large amount but calculate exact boundary
        // We need: (800e8 + dx) / (1000e8 - dy) <= 1.0e18
        // With dy = 1000e8 * dxAfterFee / (800e8 + dxAfterFee)
        // Let's just use a moderate amount that we know stays in bounds
        uint256 dx = 50e8;

        vm.startPrank(alice);
        wbtc.approve(address(pool), dx);
        uint256 dy = pool.exchange(0, 1, dx, 0);
        vm.stopPrank();

        uint256 newRatio = pool.spotPrice();
        assertLe(newRatio, RATIO_CEILING);
        assertGe(newRatio, RATIO_FLOOR);
        assertGt(dy, 0);
    }

    function test_Swap_VbtcToWbtc_LargeButWithinBounds() public {
        _initializePool(800e8, 1000e8); // ratio = 0.8

        uint256 dx = 100e8;

        vm.startPrank(alice);
        vbtc.approve(address(pool), dx);
        uint256 dy = pool.exchange(1, 0, dx, 0);
        vm.stopPrank();

        uint256 newRatio = pool.spotPrice();
        assertLe(newRatio, RATIO_CEILING);
        assertGe(newRatio, RATIO_FLOOR);
        assertGt(dy, 0);
    }

    // ==================== Add Liquidity Bounds (Initialized Pool) ====================

    function test_AddLiquidity_Initialized_InBounds() public {
        _initializePool(800e8, 1000e8); // ratio = 0.8

        // Add balanced liquidity
        uint256 wbtcAmt = 80e8;
        uint256 vbtcAmt = 100e8; // maintains 0.8 ratio

        vm.startPrank(bob);
        wbtc.approve(address(pool), wbtcAmt);
        vbtc.approve(address(pool), vbtcAmt);
        pool.add_liquidity([wbtcAmt, vbtcAmt], 0);
        vm.stopPrank();

        assertEq(pool.spotPrice(), 0.8e18);
        assertEq(pool.reserve0(), 880e8);
        assertEq(pool.reserve1(), 1100e8);
    }

    function test_AddLiquidity_Initialized_PushesAboveCeiling() public {
        _initializePool(900e8, 1000e8); // ratio = 0.9

        // Add only WBTC, pushing ratio above 1.0
        uint256 wbtcAmt = 200e8;
        uint256 vbtcAmt = 0;

        vm.startPrank(bob);
        wbtc.approve(address(pool), wbtcAmt);
        vbtc.approve(address(pool), vbtcAmt);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.RatioBoundsExceeded.selector, 0.9e18, 1.1e18));
        pool.add_liquidity([wbtcAmt, vbtcAmt], 0);
        vm.stopPrank();
    }

    function test_AddLiquidity_Initialized_PushesBelowFloor() public {
        _initializePool(600e8, 1000e8); // ratio = 0.6

        // Add only vBTC, pushing ratio below 0.5
        uint256 wbtcAmt = 0;
        uint256 vbtcAmt = 500e8;

        vm.startPrank(bob);
        wbtc.approve(address(pool), wbtcAmt);
        vbtc.approve(address(pool), vbtcAmt);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.RatioBoundsExceeded.selector, 0.6e18, 0.4e18));
        pool.add_liquidity([wbtcAmt, vbtcAmt], 0);
        vm.stopPrank();
    }

    // ==================== get_dy Bounds ====================

    function test_GetDy_OutOfBounds_ReturnsZero() public {
        _initializePool(1000e8, 1000e8); // ratio = 1.0

        // Any WBTC -> vBTC swap would exceed ceiling
        uint256 dy = pool.get_dy(0, 1, 1e8);
        assertEq(dy, 0);
    }

    function test_GetDy_WithinBounds_ReturnsNonZero() public {
        _initializePool(800e8, 1000e8); // ratio = 0.8

        uint256 dy = pool.get_dy(0, 1, 50e8);
        assertGt(dy, 0);

        uint256 dy2 = pool.get_dy(1, 0, 50e8);
        assertGt(dy2, 0);
    }

    // ==================== Constant-Product Invariant ====================

    function test_ConstantProductInvariant_WbtcToVbtc() public {
        _initializePool(800e8, 1000e8);

        uint256 dx = 50e8;
        uint256 kBefore = pool.reserve0() * pool.reserve1();

        vm.startPrank(alice);
        wbtc.approve(address(pool), dx);
        uint256 dy = pool.exchange(0, 1, dx, 0);
        vm.stopPrank();

        uint256 kAfter = pool.reserve0() * pool.reserve1();

        // Actual product increases because fees stay in pool
        assertGe(kAfter, kBefore, "k should not decrease");

        // Virtual invariant: (reserveIn + dxAfterFee) * (reserveOut - dy) should approximate reserveIn * reserveOut
        // Rounding error is bounded by (reserveIn + dxAfterFee) due to floor division in dy
        uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
        uint256 virtualK = (800e8 + dxAfterFee) * (1000e8 - dy);
        uint256 expectedK = 800e8 * 1000e8;
        assertGe(virtualK, expectedK, "virtual invariant violated");
        assertLe(virtualK - expectedK, 800e8 + dxAfterFee, "rounding error too large");
    }

    function test_ConstantProductInvariant_VbtcToWbtc() public {
        _initializePool(800e8, 1000e8);

        uint256 dx = 100e8;
        uint256 kBefore = pool.reserve0() * pool.reserve1();

        vm.startPrank(alice);
        vbtc.approve(address(pool), dx);
        uint256 dy = pool.exchange(1, 0, dx, 0);
        vm.stopPrank();

        uint256 kAfter = pool.reserve0() * pool.reserve1();

        // Actual product increases because fees stay in pool
        assertGe(kAfter, kBefore, "k should not decrease");

        // Virtual invariant with rounding tolerance
        uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
        uint256 virtualK = (1000e8 + dxAfterFee) * (800e8 - dy);
        uint256 expectedK = 800e8 * 1000e8;
        assertGe(virtualK, expectedK, "virtual invariant violated");
        assertLe(virtualK - expectedK, 1000e8 + dxAfterFee, "rounding error too large");
    }

    function testFuzz_ConstantProductInvariant(uint256 dx) public {
        _initializePool(800e8, 1000e8);

        dx = bound(dx, 1e8, 50e8);

        uint256 kBefore = pool.reserve0() * pool.reserve1();

        vm.startPrank(alice);
        wbtc.approve(address(pool), dx);

        // If swap would exceed bounds, it reverts; that's expected
        try pool.exchange(0, 1, dx, 0) returns (uint256 dy) {
            vm.stopPrank();

            uint256 kAfter = pool.reserve0() * pool.reserve1();
            assertGe(kAfter, kBefore, "k should not decrease");

            uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
            uint256 virtualK = (800e8 + dxAfterFee) * (1000e8 - dy);
            uint256 expectedK = 800e8 * 1000e8;
            assertGe(virtualK, expectedK, "virtual invariant violated");
            assertLe(virtualK - expectedK, 800e8 + dxAfterFee, "rounding error too large");
        } catch {
            vm.stopPrank();
            // Revert is acceptable if bounds would be breached
            uint256 newRatio = (800e8 + dx) * PRECISION / (1000e8 - _expectedDy(800e8, 1000e8, dx));
            assertTrue(newRatio > RATIO_CEILING || newRatio < RATIO_FLOOR, "revert should only happen on bounds breach");
        }
    }

    // ==================== Gas Baseline ====================

    function test_SwapGasBaseline() public {
        _initializePool(800e8, 1000e8);

        vm.startPrank(alice);
        wbtc.approve(address(pool), 50e8);

        uint256 gasBefore = gasleft();
        pool.exchange(0, 1, 50e8, 0);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();

        // Log gas for baseline tracking (no assertion, just documentation)
        emit log_named_uint("swap gas used", gasUsed);
    }

    // ==================== Edge Cases ====================

    function test_Exchange_NotInitialized() public {
        vm.startPrank(alice);
        wbtc.approve(address(pool), 100e8);
        vm.expectRevert(SimCurvePool.NotInitialized.selector);
        pool.exchange(0, 1, 100e8, 0);
        vm.stopPrank();
    }

    function test_Exchange_ZeroAmount() public {
        _initializePool(800e8, 1000e8);

        vm.startPrank(alice);
        vm.expectRevert(SimCurvePool.ZeroAmount.selector);
        pool.exchange(0, 1, 0, 0);
        vm.stopPrank();
    }

    function test_Exchange_InsufficientOutput() public {
        _initializePool(800e8, 1000e8);

        uint256 dx = 50e8;
        uint256 expectedDy = _expectedDy(800e8, 1000e8, dx);
        uint256 minDy = expectedDy + 1; // impossible

        vm.startPrank(alice);
        wbtc.approve(address(pool), dx);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.InsufficientOutput.selector, expectedDy, minDy));
        pool.exchange(0, 1, dx, minDy);
        vm.stopPrank();
    }

    function test_Exchange_InvalidCoinIndex() public {
        _initializePool(800e8, 1000e8);

        vm.startPrank(alice);
        wbtc.approve(address(pool), 10e8);
        vm.expectRevert(abi.encodeWithSelector(SimCurvePool.InvalidCoinIndex.selector, int128(0)));
        pool.exchange(0, 0, 10e8, 0);
        vm.stopPrank();
    }
}
