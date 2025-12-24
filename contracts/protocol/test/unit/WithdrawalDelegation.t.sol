// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {VaultMath} from "../../src/libraries/VaultMath.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract WithdrawalDelegationTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;      // Vault owner
    address public bob;        // Delegate
    address public charlie;    // Another delegate
    address public dave;       // Non-delegate

    uint256 constant ONE_BTC = 1e8;
    uint256 constant VESTING_PERIOD = 1129 days;
    uint256 constant WITHDRAWAL_PERIOD = 30 days;

    uint256 public tokenId;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        dave = makeAddr("dave");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address[] memory acceptedTokens = new address[](1);
        acceptedTokens[0] = address(wbtc);

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr);
        vault = new VaultNFT(address(btcToken), acceptedTokens);

        // Mint tokens and setup approvals
        wbtc.mint(alice, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);

        vm.startPrank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);

        // Mint a vault NFT
        tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);
        vm.stopPrank();

        // Fast forward past vesting period
        vm.warp(block.timestamp + VESTING_PERIOD);
    }

    // ========== Basic Delegation Tests ==========

    function test_GrantDelegation() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000); // 60%

        IVaultNFT.DelegatePermission memory permission = vault.getDelegatePermission(tokenId, bob);
        assertEq(permission.percentageBPS, 6000);
        assertEq(permission.lastWithdrawal, 0);
        assertEq(permission.grantedAt, block.timestamp);
        assertTrue(permission.active);
        assertEq(vault.totalDelegatedBPS(tokenId), 6000);
    }

    function test_GrantDelegation_EmitEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IVaultNFT.WithdrawalDelegateGranted(tokenId, bob, 6000);

        vm.prank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
    }

    function test_GrantDelegation_RevertIf_NotOwner() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
    }

    function test_GrantDelegation_RevertIf_ZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(IVaultNFT.ZeroAddress.selector);
        vault.grantWithdrawalDelegate(tokenId, address(0), 6000);
    }

    function test_GrantDelegation_RevertIf_SelfDelegate() public {
        vm.prank(alice);
        vm.expectRevert(IVaultNFT.CannotDelegateSelf.selector);
        vault.grantWithdrawalDelegate(tokenId, alice, 6000);
    }

    function test_GrantDelegation_RevertIf_InvalidPercentage() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.InvalidPercentage.selector, 0));
        vault.grantWithdrawalDelegate(tokenId, bob, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.InvalidPercentage.selector, 10001));
        vault.grantWithdrawalDelegate(tokenId, bob, 10001);
    }

    function test_GrantDelegation_RevertIf_ExceedsLimit() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vault.grantWithdrawalDelegate(tokenId, charlie, 3000);
        
        vm.expectRevert(IVaultNFT.ExceedsDelegationLimit.selector);
        vault.grantWithdrawalDelegate(tokenId, dave, 2000); // Would total 11000 (110%)
        vm.stopPrank();
    }

    // ========== Multiple Delegates Tests ==========

    function test_MultipleDelegates() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);     // 60%
        vault.grantWithdrawalDelegate(tokenId, charlie, 3000); // 30%
        vm.stopPrank();

        assertEq(vault.totalDelegatedBPS(tokenId), 9000);
        
        IVaultNFT.DelegatePermission memory bobPermission = vault.getDelegatePermission(tokenId, bob);
        IVaultNFT.DelegatePermission memory charliePermission = vault.getDelegatePermission(tokenId, charlie);
        
        assertEq(bobPermission.percentageBPS, 6000);
        assertEq(charliePermission.percentageBPS, 3000);
        assertTrue(bobPermission.active);
        assertTrue(charliePermission.active);
    }

    function test_UpdateExistingDelegate() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vault.grantWithdrawalDelegate(tokenId, bob, 8000); // Update to 80%
        vm.stopPrank();

        assertEq(vault.totalDelegatedBPS(tokenId), 8000);
        
        IVaultNFT.DelegatePermission memory permission = vault.getDelegatePermission(tokenId, bob);
        assertEq(permission.percentageBPS, 8000);
    }

    // ========== Cumulative Withdrawal Tests ==========

    function test_CumulativeWithdrawals() public {
        // Grant 60% to Bob, 40% to Charlie (100% total delegation)
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vault.grantWithdrawalDelegate(tokenId, charlie, 4000);
        vm.stopPrank();

        uint256 currentCollateral = vault.collateralAmount(tokenId);

        // Bob withdraws first
        uint256 bobBalanceBefore = wbtc.balanceOf(bob);
        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);
        
        // Calculate Bob's expected amount
        uint256 bobPool = (currentCollateral * 875) / 100000;
        uint256 expectedBobShare = (bobPool * 6000) / 10000;   // 60%
        assertEq(bobWithdrawn, expectedBobShare);
        assertEq(wbtc.balanceOf(bob), bobBalanceBefore + expectedBobShare);

        // Charlie withdraws from remaining collateral
        uint256 remainingCollateral = vault.collateralAmount(tokenId);
        uint256 charlieBalanceBefore = wbtc.balanceOf(charlie);
        vm.prank(charlie);
        uint256 charlieWithdrawn = vault.withdrawAsDelegate(tokenId);
        
        // Calculate Charlie's expected amount from remaining collateral
        uint256 charliePool = (remainingCollateral * 875) / 100000;
        uint256 expectedCharlieShare = (charliePool * 4000) / 10000; // 40%
        assertEq(charlieWithdrawn, expectedCharlieShare);
        assertEq(wbtc.balanceOf(charlie), charlieBalanceBefore + expectedCharlieShare);

        // Verify final collateral amount
        uint256 finalCollateral = vault.collateralAmount(tokenId);
        assertEq(finalCollateral, currentCollateral - bobWithdrawn - charlieWithdrawn);
    }

    function test_DelegateWithdrawal_IndependentCooldowns() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 5000); // 50%
        vm.stopPrank();

        // Bob withdraws
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        // Bob cannot withdraw again immediately
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.WithdrawalPeriodNotMet.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);

        // Alice can still withdraw (independent cooldown)
        vm.prank(alice);
        vault.withdraw(tokenId); // Owner withdrawal should work

        // After 30 days, Bob can withdraw again
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId); // Should succeed
    }

    // ========== Revoke Tests ==========

    function test_RevokeSingleDelegate() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vault.revokeWithdrawalDelegate(tokenId, bob);
        vm.stopPrank();

        IVaultNFT.DelegatePermission memory permission = vault.getDelegatePermission(tokenId, bob);
        assertFalse(permission.active);
        assertEq(vault.totalDelegatedBPS(tokenId), 0);
    }

    function test_RevokeSingleDelegate_EmitEvent() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);

        vm.expectEmit(true, true, false, true);
        emit IVaultNFT.WithdrawalDelegateRevoked(tokenId, bob);
        vault.revokeWithdrawalDelegate(tokenId, bob);
        vm.stopPrank();
    }

    function test_RevokeAllDelegates() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vault.grantWithdrawalDelegate(tokenId, charlie, 3000);
        
        vm.expectEmit(true, false, false, true);
        emit IVaultNFT.AllWithdrawalDelegatesRevoked(tokenId);
        vault.revokeAllWithdrawalDelegates(tokenId);
        vm.stopPrank();

        assertEq(vault.totalDelegatedBPS(tokenId), 0);
        
        // Delegates should no longer be able to withdraw
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotActiveDelegate.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_RevokeDelegate_RevertIf_NotOwner() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.revokeWithdrawalDelegate(tokenId, bob);
    }

    function test_RevokeDelegate_RevertIf_NotActive() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.DelegateNotActive.selector, tokenId, bob));
        vault.revokeWithdrawalDelegate(tokenId, bob);
    }

    // ========== Delegation Withdrawal Tests ==========

    function test_WithdrawAsDelegate() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000); // 60%
        vm.stopPrank();

        uint256 currentCollateral = vault.collateralAmount(tokenId);
        uint256 totalPool = (currentCollateral * 875) / 100000; // 0.875% monthly rate
        uint256 expectedAmount = (totalPool * 6000) / 10000;    // 60%

        uint256 bobBalanceBefore = wbtc.balanceOf(bob);
        
        vm.expectEmit(true, true, false, true);
        emit IVaultNFT.DelegatedWithdrawal(tokenId, bob, expectedAmount);
        
        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);

        assertEq(withdrawn, expectedAmount);
        assertEq(wbtc.balanceOf(bob), bobBalanceBefore + expectedAmount);
        assertEq(vault.collateralAmount(tokenId), currentCollateral - expectedAmount);
    }

    function test_WithdrawAsDelegate_RevertIf_NotDelegate() public {
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotActiveDelegate.selector, tokenId, dave));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_WithdrawAsDelegate_RevertIf_StillVesting() public {
        // Create new vault and don't fast forward
        vm.startPrank(alice);
        uint256 newTokenId = vault.mint(address(treasure), 1, address(wbtc), ONE_BTC);
        vault.grantWithdrawalDelegate(newTokenId, bob, 6000);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, newTokenId));
        vault.withdrawAsDelegate(newTokenId);
    }

    function test_WithdrawAsDelegate_RevertIf_TooSoon() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vm.stopPrank();

        // First withdrawal
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        // Second withdrawal too soon
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.WithdrawalPeriodNotMet.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_WithdrawAsDelegate_ZeroAmount() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vm.stopPrank();

        // Drain the vault collateral significantly
        // With 0.875% withdrawal rate per period, after N withdrawals:
        // Remaining = initial * (1 - 0.00875)^N
        // After 100 withdrawals: ~43% remains
        // After 200 withdrawals: ~19% remains
        // After 300 withdrawals: ~8% remains
        vm.startPrank(alice);
        for (uint256 i = 0; i < 300; i++) {
            try vault.withdraw(tokenId) {} catch {}
            vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        }
        vm.stopPrank();

        // Make sure enough time has passed for Bob's withdrawal
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        // Bob's withdrawal should be very small after 300 owner withdrawals
        // Remaining collateral: ~8% of 10 BTC = 0.8 BTC
        // Bob's share: 60% of (0.8 BTC * 0.875%) = ~0.004 BTC = 400,000 sats
        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);
        assertLt(withdrawn, ONE_BTC / 100); // Less than 0.01 BTC after 300 periods
    }

    // ========== View Function Tests ==========

    function test_CanDelegateWithdraw() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vm.stopPrank();

        (bool canWithdraw, uint256 amount) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw);
        assertGt(amount, 0);

        // After withdrawal, should not be able to withdraw again
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        (canWithdraw, amount) = vault.canDelegateWithdraw(tokenId, bob);
        assertFalse(canWithdraw);
        assertEq(amount, 0);
    }

    function test_CanDelegateWithdraw_NotDelegate() public {
        (bool canWithdraw, uint256 amount) = vault.canDelegateWithdraw(tokenId, dave);
        assertFalse(canWithdraw);
        assertEq(amount, 0);
    }

    function test_GetDelegatePermission() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vm.stopPrank();

        IVaultNFT.DelegatePermission memory permission = vault.getDelegatePermission(tokenId, bob);
        assertEq(permission.percentageBPS, 6000);
        assertEq(permission.lastWithdrawal, 0);
        assertEq(permission.grantedAt, block.timestamp);
        assertTrue(permission.active);
    }

    // ========== Integration Tests ==========

    function test_DelegationWithOwnerWithdrawal() public {
        // Owner delegates 60%, keeps 40%
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vm.stopPrank();

        uint256 currentCollateral = vault.collateralAmount(tokenId);
        uint256 totalPool = (currentCollateral * 875) / 100000;

        // Bob withdraws his 60%
        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);
        uint256 expectedBobAmount = (totalPool * 6000) / 10000;
        assertEq(bobWithdrawn, expectedBobAmount);

        // Owner can still do normal withdraw (full amount since no remaining delegation)
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        
        vm.prank(alice);
        uint256 ownerWithdrawn = vault.withdraw(tokenId);
        
        // Owner gets full withdrawal amount from remaining collateral
        uint256 remainingCollateral = currentCollateral - bobWithdrawn;
        uint256 expectedOwnerAmount = (remainingCollateral * 875) / 100000;
        assertEq(ownerWithdrawn, expectedOwnerAmount);
    }

    function test_DelegationActivityTracking() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);
        vm.stopPrank();

        uint256 activityBefore = vault.lastActivity(tokenId);
        
        // Wait a bit to ensure timestamp difference
        vm.warp(block.timestamp + 1);
        
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        uint256 activityAfter = vault.lastActivity(tokenId);
        assertGt(activityAfter, activityBefore);
    }

    // ========== Fuzz Tests ==========

    function testFuzz_DelegationPercentages(uint256 percentage1, uint256 percentage2) public {
        percentage1 = bound(percentage1, 1, 5000);  // 0.01% to 50%
        percentage2 = bound(percentage2, 1, 10000 - percentage1); // Remaining up to 100%

        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, percentage1);
        vault.grantWithdrawalDelegate(tokenId, charlie, percentage2);
        vm.stopPrank();

        assertEq(vault.totalDelegatedBPS(tokenId), percentage1 + percentage2);

        // Bob withdraws first - from original collateral
        uint256 collateralBeforeBob = vault.collateralAmount(tokenId);
        uint256 bobPool = (collateralBeforeBob * 875) / 100000;
        uint256 expectedBob = (bobPool * percentage1) / 10000;

        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);
        // Allow 1 satoshi tolerance for integer division rounding
        assertApproxEqAbs(bobWithdrawn, expectedBob, 1);

        // Charlie withdraws second - from REDUCED collateral (after Bob's withdrawal)
        uint256 collateralBeforeCharlie = vault.collateralAmount(tokenId);
        uint256 charliePool = (collateralBeforeCharlie * 875) / 100000;
        uint256 expectedCharlie = (charliePool * percentage2) / 10000;

        vm.prank(charlie);
        uint256 charlieWithdrawn = vault.withdrawAsDelegate(tokenId);
        // Allow 1 satoshi tolerance for integer division rounding
        assertApproxEqAbs(charlieWithdrawn, expectedCharlie, 1);

        // Verify collateral was reduced by total withdrawn
        uint256 finalCollateral = vault.collateralAmount(tokenId);
        assertEq(collateralBeforeBob - finalCollateral, bobWithdrawn + charlieWithdrawn);
    }

    function testFuzz_CannotExceedDelegationLimit(uint256 p1, uint256 p2, uint256 p3) public {
        p1 = bound(p1, 1, 3333);  // Max ~33.33%
        p2 = bound(p2, 1, 3333);  // Max ~33.33%
        p3 = bound(p3, 1, 3333);  // Max ~33.33%

        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, p1);
        vault.grantWithdrawalDelegate(tokenId, charlie, p2);
        
        if (p1 + p2 + p3 > 10000) {
            vm.expectRevert(IVaultNFT.ExceedsDelegationLimit.selector);
        }
        vault.grantWithdrawalDelegate(tokenId, dave, p3);
        vm.stopPrank();
    }
}