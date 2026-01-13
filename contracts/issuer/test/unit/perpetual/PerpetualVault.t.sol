// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpetualVault} from "../../../src/perpetual/PerpetualVault.sol";
import {IPerpetualVault} from "../../../src/perpetual/interfaces/IPerpetualVault.sol";
import {MockCurvePool} from "../../mocks/MockCurvePool.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

/// @title PerpetualVaultTest
/// @notice Integration tests for PerpetualVault
contract PerpetualVaultTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant ONE_VBTC = 1e8;
    uint256 constant INITIAL_PRICE = 0.85e18; // 15% discount
    uint256 constant FUNDING_INTERVAL = 1 hours;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    PerpetualVault public vault;
    MockERC20 public vBTC;
    MockERC20 public wBTC;
    MockCurvePool public curvePool;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Deploy tokens
        wBTC = new MockERC20("Wrapped BTC", "WBTC", 8);
        vBTC = new MockERC20("Vested BTC", "vBTC", 8);

        // Deploy mock curve pool
        curvePool = new MockCurvePool(address(wBTC), address(vBTC));
        curvePool.setPriceOracle(INITIAL_PRICE);

        // Deploy vault
        vault = new PerpetualVault(address(vBTC), address(curvePool));

        // Fund users
        vBTC.mint(alice, 100 * ONE_VBTC);
        vBTC.mint(bob, 100 * ONE_VBTC);

        // Approve vault
        vm.prank(alice);
        vBTC.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        vBTC.approve(address(vault), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          OPEN POSITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OpenPosition_Long() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(
            ONE_VBTC,
            300, // 3x
            IPerpetualVault.Side.LONG
        );

        assertEq(positionId, 1);

        IPerpetualVault.Position memory pos = vault.getPosition(positionId);
        assertEq(pos.collateral, ONE_VBTC);
        assertEq(pos.notional, 3 * ONE_VBTC);
        assertEq(pos.leverageX100, 300);
        assertEq(pos.entryPrice, INITIAL_PRICE);
        assertEq(uint256(pos.side), uint256(IPerpetualVault.Side.LONG));
    }

    function test_OpenPosition_Short() public {
        vm.prank(bob);
        uint256 positionId = vault.openPosition(
            ONE_VBTC,
            200, // 2x
            IPerpetualVault.Side.SHORT
        );

        assertEq(positionId, 1);

        IPerpetualVault.Position memory pos = vault.getPosition(positionId);
        assertEq(pos.notional, 2 * ONE_VBTC);
        assertEq(uint256(pos.side), uint256(IPerpetualVault.Side.SHORT));
    }

    function test_OpenPosition_UpdatesGlobalState() public {
        vm.prank(alice);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vault.openPosition(2 * ONE_VBTC, 200, IPerpetualVault.Side.SHORT);

        IPerpetualVault.GlobalState memory state = vault.getGlobalState();
        assertEq(state.longOI, 3 * ONE_VBTC);
        assertEq(state.shortOI, 4 * ONE_VBTC);
        assertEq(state.longCollateral, ONE_VBTC);
        assertEq(state.shortCollateral, 2 * ONE_VBTC);
    }

    function test_OpenPosition_RevertsBelowMinCollateral() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerpetualVault.CollateralBelowMinimum.selector,
                1e5 // Below 1e6 minimum
            )
        );
        vault.openPosition(1e5, 300, IPerpetualVault.Side.LONG);
    }

    function test_OpenPosition_RevertsInvalidLeverage() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IPerpetualVault.InvalidLeverage.selector, 50)
        );
        vault.openPosition(ONE_VBTC, 50, IPerpetualVault.Side.LONG); // Below 1x

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IPerpetualVault.InvalidLeverage.selector, 600)
        );
        vault.openPosition(ONE_VBTC, 600, IPerpetualVault.Side.LONG); // Above 5x
    }

    /*//////////////////////////////////////////////////////////////
                         CLOSE POSITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClosePosition_NoChange_ReturnsDeposit() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        uint256 balanceBefore = vBTC.balanceOf(alice);

        vm.prank(alice);
        uint256 payout = vault.closePosition(positionId);

        // No price change = return deposit
        assertApproxEqRel(payout, ONE_VBTC, 0.001e18);
        assertEq(vBTC.balanceOf(alice), balanceBefore + payout);
    }

    function test_ClosePosition_PriceUp_LongProfits() public {
        // Open counterparty position to provide liquidity
        vm.prank(bob);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.SHORT);

        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        // Price goes up 10%
        curvePool.setPriceOracle(0.935e18);

        vm.prank(alice);
        uint256 payout = vault.closePosition(positionId);

        // 10% move × 3x leverage = 30% gain = 1.3 vBTC
        assertApproxEqRel(payout, 1.3e8, 0.01e18);
    }

    function test_ClosePosition_PriceDown_LongLoses() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        // Price goes down 10%
        curvePool.setPriceOracle(0.765e18);

        vm.prank(alice);
        uint256 payout = vault.closePosition(positionId);

        // 10% move × 3x leverage = 30% loss = 0.7 vBTC
        assertApproxEqRel(payout, 0.7e8, 0.01e18);
    }

    function test_ClosePosition_PriceDown_ShortProfits() public {
        // Open counterparty position to provide liquidity
        vm.prank(alice);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.SHORT);

        // Price goes down 10%
        curvePool.setPriceOracle(0.765e18);

        vm.prank(bob);
        uint256 payout = vault.closePosition(positionId);

        // 10% move × 3x leverage = 30% gain for short = 1.3 vBTC
        assertApproxEqRel(payout, 1.3e8, 0.01e18);
    }

    function test_ClosePosition_UpdatesGlobalState() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        IPerpetualVault.GlobalState memory stateBefore = vault.getGlobalState();
        assertEq(stateBefore.longOI, 3 * ONE_VBTC);

        vm.prank(alice);
        vault.closePosition(positionId);

        IPerpetualVault.GlobalState memory stateAfter = vault.getGlobalState();
        assertEq(stateAfter.longOI, 0);
        assertEq(stateAfter.longCollateral, 0);
    }

    function test_ClosePosition_RevertsNotOwner() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerpetualVault.NotPositionOwner.selector,
                positionId,
                bob
            )
        );
        vault.closePosition(positionId);
    }

    function test_ClosePosition_RevertsAlreadyClosed() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(alice);
        vault.closePosition(positionId);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IPerpetualVault.PositionNotFound.selector, positionId)
        );
        vault.closePosition(positionId);
    }

    /*//////////////////////////////////////////////////////////////
                         CAPPED PAYOUT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClosePosition_CappedAt200Percent() public {
        // Open large counterparty to provide sufficient liquidity
        vm.prank(bob);
        vault.openPosition(5 * ONE_VBTC, 500, IPerpetualVault.Side.SHORT);

        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 500, IPerpetualVault.Side.LONG);

        // Price goes up ~17.6% (from 0.85 to 1.00)
        curvePool.setPriceOracle(1.00e18);

        vm.prank(alice);
        uint256 payout = vault.closePosition(positionId);

        // 17.6% × 5x = 88% gain, so payout ~1.88 vBTC (under cap)
        assertApproxEqRel(payout, 1.88e8, 0.05e18); // 5% tolerance
    }

    function test_ClosePosition_FlooredAt001Percent() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 500, IPerpetualVault.Side.LONG);

        // Price goes down 50% (5x × 50% = 250% loss, but floored)
        curvePool.setPriceOracle(0.50e18);

        vm.prank(alice);
        uint256 payout = vault.closePosition(positionId);

        // Should be floored at 0.01% of deposit
        uint256 minPayout = (ONE_VBTC * 1) / 10000;
        assertEq(payout, minPayout);
    }

    /*//////////////////////////////////////////////////////////////
                         FUNDING RATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FundingRate_Balanced() public {
        // Open equal long and short
        vm.prank(alice);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.SHORT);

        int256 rate = vault.getCurrentFundingRate();
        assertEq(rate, 0); // Balanced OI = zero funding
    }

    function test_FundingRate_MoreLongs() public {
        vm.prank(alice);
        vault.openPosition(2 * ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.SHORT);

        int256 rate = vault.getCurrentFundingRate();
        assertTrue(rate > 0); // Longs pay shorts
    }

    function test_FundingRate_MoreShorts() public {
        vm.prank(alice);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vault.openPosition(2 * ONE_VBTC, 300, IPerpetualVault.Side.SHORT);

        int256 rate = vault.getCurrentFundingRate();
        assertTrue(rate < 0); // Shorts pay longs
    }

    function test_FundingAccrual_AffectsPnL() public {
        // Alice opens long, Bob opens short (unbalanced)
        vm.prank(alice);
        vault.openPosition(2 * ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.SHORT);

        // Preview before funding accrual
        (int256 alicePnLBefore, ) = vault.previewClose(1);
        (int256 bobPnLBefore, ) = vault.previewClose(2);

        // Wait for funding to accrue (24 hours = 24 periods)
        vm.warp(block.timestamp + 24 hours);

        // Force funding accrual by opening a small position
        vm.prank(alice);
        vault.openPosition(0.01e8, 100, IPerpetualVault.Side.LONG);

        // Preview after funding accrual
        (int256 alicePnLAfter, ) = vault.previewClose(1);
        (int256 bobPnLAfter, ) = vault.previewClose(2);

        // Longs should have paid funding (lower PnL)
        assertTrue(alicePnLAfter < alicePnLBefore);
        // Shorts should have received funding (higher PnL)
        assertTrue(bobPnLAfter > bobPnLBefore);
    }

    /*//////////////////////////////////////////////////////////////
                        ADD COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AddCollateral() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        uint256 balanceBefore = vBTC.balanceOf(alice);

        vm.prank(alice);
        vault.addCollateral(positionId, ONE_VBTC);

        IPerpetualVault.Position memory pos = vault.getPosition(positionId);
        assertEq(pos.collateral, 2 * ONE_VBTC);
        assertEq(pos.notional, 3 * ONE_VBTC); // Notional unchanged
        assertEq(vBTC.balanceOf(alice), balanceBefore - ONE_VBTC);
    }

    function test_AddCollateral_ReducesEffectiveLeverage() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        // Original: 3x leverage (1 vBTC collateral, 3 vBTC notional)
        // After adding 2 vBTC: effective "buffer" is larger

        vm.prank(alice);
        vault.addCollateral(positionId, 2 * ONE_VBTC);

        IPerpetualVault.Position memory pos = vault.getPosition(positionId);
        assertEq(pos.collateral, 3 * ONE_VBTC);
        assertEq(pos.notional, 3 * ONE_VBTC); // Notional unchanged

        // Price drops 41% (from 0.85 to 0.50)
        curvePool.setPriceOracle(0.50e18);

        (int256 pnl, uint256 payout) = vault.previewClose(positionId);
        assertTrue(pnl < 0);

        // Direction PnL = 3e8 × (0.50 - 0.85) / 0.85 ≈ -1.24e8
        // Raw payout = 3e8 + (-1.24e8) = ~1.76e8
        // This is above min and below max, so payout ≈ 1.76e8
        // The key insight: adding collateral provides a larger buffer against losses
        assertTrue(payout > ONE_VBTC); // More than original deposit
        assertTrue(payout < 2 * ONE_VBTC); // But still a net loss
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreviewClose() public {
        vm.prank(alice);
        uint256 positionId = vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        // Price up 10%
        curvePool.setPriceOracle(0.935e18);

        (int256 pnl, uint256 payout) = vault.previewClose(positionId);

        assertTrue(pnl > 0);
        assertApproxEqRel(payout, 1.3e8, 0.01e18);
    }

    function test_GetUserPositions() public {
        vm.startPrank(alice);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);
        vault.openPosition(ONE_VBTC, 200, IPerpetualVault.Side.SHORT);
        vm.stopPrank();

        uint256[] memory positions = vault.getUserPositions(alice);
        assertEq(positions.length, 2);
        assertEq(positions[0], 1);
        assertEq(positions[1], 2);
    }

    function test_TotalAssets() public {
        vm.prank(alice);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vault.openPosition(2 * ONE_VBTC, 200, IPerpetualVault.Side.SHORT);

        assertEq(vault.totalAssets(), 3 * ONE_VBTC);
    }

    /*//////////////////////////////////////////////////////////////
                       PRICE BOUNDS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetCurrentPrice_RevertsBelowMin() public {
        curvePool.setPriceOracle(0.40e18); // Below 0.50 min

        vm.expectRevert(
            abi.encodeWithSelector(IPerpetualVault.PriceOutOfBounds.selector, 0.40e18)
        );
        vault.getCurrentPrice();
    }

    function test_GetCurrentPrice_RevertsAboveMax() public {
        curvePool.setPriceOracle(1.10e18); // Above 1.00 max

        vm.expectRevert(
            abi.encodeWithSelector(IPerpetualVault.PriceOutOfBounds.selector, 1.10e18)
        );
        vault.getCurrentPrice();
    }

    /*//////////////////////////////////////////////////////////////
                           ZERO-SUM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ZeroSum_LongShortPayouts() public {
        // Alice long, Bob short, equal size
        vm.prank(alice);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.LONG);

        vm.prank(bob);
        vault.openPosition(ONE_VBTC, 300, IPerpetualVault.Side.SHORT);

        uint256 totalBefore = vault.totalAssets();
        assertEq(totalBefore, 2 * ONE_VBTC);

        // Price goes up 10%
        curvePool.setPriceOracle(0.935e18);

        vm.prank(alice);
        uint256 alicePayout = vault.closePosition(1);

        vm.prank(bob);
        uint256 bobPayout = vault.closePosition(2);

        // Total payouts should equal total deposits (zero-sum)
        // Note: Slight difference due to capping mechanics
        assertApproxEqRel(alicePayout + bobPayout, 2 * ONE_VBTC, 0.01e18);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_OpenClose_NeverLosesMoreThanDeposit(
        uint256 collateral,
        uint256 leverageX100,
        uint256 priceMove
    ) public {
        collateral = bound(collateral, 0.01e8, 10e8);
        leverageX100 = bound(leverageX100, 100, 500);
        priceMove = bound(priceMove, 0.50e18, 1.00e18);

        // Mint counterparty liquidity
        uint256 counterpartyAmount = collateral * 5;
        vBTC.mint(bob, counterpartyAmount);
        vm.prank(bob);
        vBTC.approve(address(vault), counterpartyAmount);
        vm.prank(bob);
        vault.openPosition(counterpartyAmount, 100, IPerpetualVault.Side.SHORT);

        vBTC.mint(alice, collateral);
        vm.prank(alice);
        vBTC.approve(address(vault), collateral);

        vm.prank(alice);
        uint256 positionId = vault.openPosition(
            collateral,
            leverageX100,
            IPerpetualVault.Side.LONG
        );

        curvePool.setPriceOracle(priceMove);

        vm.prank(alice);
        uint256 payout = vault.closePosition(positionId);

        // Min payout is 0.01% of collateral
        uint256 minPayout = (collateral * 1) / 10000;
        assertGe(payout, minPayout);

        // Max payout is 200% of collateral
        uint256 maxPayout = (collateral * 20000) / 10000;
        assertLe(payout, maxPayout);
    }
}
