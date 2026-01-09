// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {IVaultNFTDelegation} from "../../src/interfaces/IVaultNFTDelegation.sol";
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
    uint256 public tokenId2;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        dave = makeAddr("dave");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        // Mint tokens and setup approvals
        wbtc.mint(alice, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);

        vm.startPrank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);

        // Mint two vault NFTs
        tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);
        tokenId2 = vault.mint(address(treasure), 1, address(wbtc), 2 * ONE_BTC);
        vm.stopPrank();

        // Fast forward past vesting period
        vm.warp(block.timestamp + VESTING_PERIOD);
    }

    // ========== Basic Wallet-Level Delegation Tests ==========

    function test_GrantDelegation() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000); // 60%

        IVaultNFT.WalletDelegatePermission memory permission = vault.getWalletDelegatePermission(alice, bob);
        assertEq(permission.percentageBPS, 6000);
        assertEq(permission.grantedAt, block.timestamp);
        assertTrue(permission.active);
        assertEq(vault.walletTotalDelegatedBPS(alice), 6000);
    }

    function test_GrantDelegation_EmitEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IVaultNFTDelegation.WalletDelegateGranted(alice, bob, 6000);

        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);
    }

    function test_GrantDelegation_RevertIf_ZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(IVaultNFTDelegation.ZeroAddress.selector);
        vault.grantWithdrawalDelegate(address(0), 6000);
    }

    function test_GrantDelegation_RevertIf_SelfDelegate() public {
        vm.prank(alice);
        vm.expectRevert(IVaultNFTDelegation.CannotDelegateSelf.selector);
        vault.grantWithdrawalDelegate(alice, 6000);
    }

    function test_GrantDelegation_RevertIf_InvalidPercentage() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.InvalidPercentage.selector, 0));
        vault.grantWithdrawalDelegate(bob, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.InvalidPercentage.selector, 10001));
        vault.grantWithdrawalDelegate(bob, 10001);
    }

    function test_GrantDelegation_RevertIf_ExceedsLimit() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);
        vault.grantWithdrawalDelegate(charlie, 3000);

        vm.expectRevert(IVaultNFTDelegation.ExceedsDelegationLimit.selector);
        vault.grantWithdrawalDelegate(dave, 2000); // Would total 11000 (110%)
        vm.stopPrank();
    }

    // ========== Multiple Delegates Tests ==========

    function test_MultipleDelegates() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);     // 60%
        vault.grantWithdrawalDelegate(charlie, 3000); // 30%
        vm.stopPrank();

        assertEq(vault.walletTotalDelegatedBPS(alice), 9000);

        IVaultNFT.WalletDelegatePermission memory bobPermission = vault.getWalletDelegatePermission(alice, bob);
        IVaultNFT.WalletDelegatePermission memory charliePermission = vault.getWalletDelegatePermission(alice, charlie);

        assertEq(bobPermission.percentageBPS, 6000);
        assertEq(charliePermission.percentageBPS, 3000);
        assertTrue(bobPermission.active);
        assertTrue(charliePermission.active);
    }

    function test_UpdateExistingDelegate() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        vm.expectEmit(true, true, false, true);
        emit IVaultNFTDelegation.WalletDelegateUpdated(alice, bob, 6000, 8000);
        vault.grantWithdrawalDelegate(bob, 8000); // Update to 80%
        vm.stopPrank();

        assertEq(vault.walletTotalDelegatedBPS(alice), 8000);

        IVaultNFT.WalletDelegatePermission memory permission = vault.getWalletDelegatePermission(alice, bob);
        assertEq(permission.percentageBPS, 8000);
    }

    // ========== Multi-Vault Scenarios (Wallet-Level Applies to All) ==========

    function test_WalletDelegation_AppliesToAllVaults() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000); // 60% - applies to ALL alice's vaults

        // Bob can withdraw from BOTH vaults with one delegation
        (bool canWithdraw1, uint256 amount1,) = vault.canDelegateWithdraw(tokenId, bob);
        (bool canWithdraw2, uint256 amount2,) = vault.canDelegateWithdraw(tokenId2, bob);

        assertTrue(canWithdraw1);
        assertTrue(canWithdraw2);
        assertGt(amount1, 0);
        assertGt(amount2, 0);

        // Amounts should be proportional to each vault's collateral
        // tokenId has 1 BTC, tokenId2 has 2 BTC
        assertGt(amount2, amount1);
    }

    function test_IndependentVaultCooldowns() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        // Bob withdraws from vault 1
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        // Bob can still withdraw from vault 2 (independent cooldown)
        (bool canWithdraw,,) = vault.canDelegateWithdraw(tokenId2, bob);
        assertTrue(canWithdraw);

        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId2); // Should succeed

        // Now Bob is on cooldown for both vaults
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.WithdrawalPeriodNotMet.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.WithdrawalPeriodNotMet.selector, tokenId2, bob));
        vault.withdrawAsDelegate(tokenId2);
    }

    // ========== Ownership Transfer Tests ==========

    function test_OwnershipTransfer_NewOwnerDelegationApplies() public {
        // Alice delegates to Bob
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        // Transfer vault to Dave
        vm.prank(alice);
        vault.transferFrom(alice, dave, tokenId);

        // Bob can no longer withdraw from transferred vault (Alice is no longer owner)
        (bool canWithdraw,,) = vault.canDelegateWithdraw(tokenId, bob);
        assertFalse(canWithdraw);

        // Dave delegates to Charlie
        vm.prank(dave);
        vault.grantWithdrawalDelegate(charlie, 5000);

        // Charlie can now withdraw from the vault
        (bool canWithdrawCharlie,,) = vault.canDelegateWithdraw(tokenId, charlie);
        assertTrue(canWithdrawCharlie);
    }

    function test_OwnershipTransfer_CooldownPersists() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        // Bob withdraws
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        // Record Bob's cooldown
        uint256 bobCooldown = vault.getDelegateCooldown(bob, tokenId);
        assertEq(bobCooldown, block.timestamp);

        // Transfer to Dave
        vm.prank(alice);
        vault.transferFrom(alice, dave, tokenId);

        // Dave delegates to Bob
        vm.prank(dave);
        vault.grantWithdrawalDelegate(bob, 5000);

        // Bob's cooldown persists - cannot withdraw
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.WithdrawalPeriodNotMet.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);

        // After cooldown expires, Bob can withdraw
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId); // Should succeed
    }

    // ========== Cumulative Withdrawal Tests ==========

    function test_CumulativeWithdrawals() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);
        vault.grantWithdrawalDelegate(charlie, 4000);
        vm.stopPrank();

        uint256 currentCollateral = vault.collateralAmount(tokenId);

        // Bob withdraws first
        uint256 bobBalanceBefore = wbtc.balanceOf(bob);
        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);

        uint256 bobPool = (currentCollateral * 1000) / 100000;
        uint256 expectedBobShare = (bobPool * 6000) / 10000;
        assertEq(bobWithdrawn, expectedBobShare);
        assertEq(wbtc.balanceOf(bob), bobBalanceBefore + expectedBobShare);

        // Charlie withdraws from remaining collateral
        uint256 remainingCollateral = vault.collateralAmount(tokenId);
        uint256 charlieBalanceBefore = wbtc.balanceOf(charlie);
        vm.prank(charlie);
        uint256 charlieWithdrawn = vault.withdrawAsDelegate(tokenId);

        uint256 charliePool = (remainingCollateral * 1000) / 100000;
        uint256 expectedCharlieShare = (charliePool * 4000) / 10000;
        assertEq(charlieWithdrawn, expectedCharlieShare);
        assertEq(wbtc.balanceOf(charlie), charlieBalanceBefore + expectedCharlieShare);

        uint256 finalCollateral = vault.collateralAmount(tokenId);
        assertEq(finalCollateral, currentCollateral - bobWithdrawn - charlieWithdrawn);
    }

    function test_DelegateWithdrawal_IndependentFromOwner() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 5000);

        // Bob withdraws
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        // Bob cannot withdraw again immediately
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.WithdrawalPeriodNotMet.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);

        // Alice can still withdraw (independent cooldown)
        vm.prank(alice);
        vault.withdraw(tokenId);

        // After 30 days, Bob can withdraw again
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);
    }

    // ========== Revoke Tests ==========

    function test_RevokeSingleDelegate() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        vm.expectEmit(true, true, false, true);
        emit IVaultNFTDelegation.WalletDelegateRevoked(alice, bob);
        vault.revokeWithdrawalDelegate(bob);
        vm.stopPrank();

        IVaultNFT.WalletDelegatePermission memory permission = vault.getWalletDelegatePermission(alice, bob);
        assertFalse(permission.active);
        assertEq(vault.walletTotalDelegatedBPS(alice), 0);
    }

    function test_RevokeAllDelegates() public {
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);
        vault.grantWithdrawalDelegate(charlie, 3000);

        vm.expectEmit(true, false, false, true);
        emit IVaultNFTDelegation.AllWalletDelegatesRevoked(alice);
        vault.revokeAllWithdrawalDelegates();
        vm.stopPrank();

        assertEq(vault.walletTotalDelegatedBPS(alice), 0);

        // Delegates should no longer be able to withdraw
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.NotActiveDelegate.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_RevokeDelegate_RevertIf_NotActive() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.DelegateNotActive.selector, alice, bob));
        vault.revokeWithdrawalDelegate(bob);
    }

    // ========== Delegation Withdrawal Tests ==========

    function test_WithdrawAsDelegate() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        uint256 currentCollateral = vault.collateralAmount(tokenId);
        uint256 totalPool = (currentCollateral * 1000) / 100000;
        uint256 expectedAmount = (totalPool * 6000) / 10000;

        uint256 bobBalanceBefore = wbtc.balanceOf(bob);

        vm.expectEmit(true, true, true, true);
        emit IVaultNFTDelegation.DelegatedWithdrawal(tokenId, bob, alice, expectedAmount);

        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);

        assertEq(withdrawn, expectedAmount);
        assertEq(wbtc.balanceOf(bob), bobBalanceBefore + expectedAmount);
        assertEq(vault.collateralAmount(tokenId), currentCollateral - expectedAmount);
    }

    function test_WithdrawAsDelegate_RevertIf_NotDelegate() public {
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.NotActiveDelegate.selector, tokenId, dave));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_WithdrawAsDelegate_RevertIf_StillVesting() public {
        vm.startPrank(alice);
        uint256 newTokenId = vault.mint(address(treasure), 2, address(wbtc), ONE_BTC);
        vm.stopPrank();

        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        // Rewind time to before vesting completes for new vault
        vm.warp(block.timestamp - VESTING_PERIOD + 1 days);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, newTokenId));
        vault.withdrawAsDelegate(newTokenId);
    }

    function test_WithdrawAsDelegate_RevertIf_TooSoon() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.WithdrawalPeriodNotMet.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);
    }

    // ========== View Function Tests ==========

    function test_CanDelegateWithdraw() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        (bool canWithdraw, uint256 amount, IVaultNFTDelegation.DelegationType dtype) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw);
        assertGt(amount, 0);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.WalletLevel));

        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        (canWithdraw, amount, dtype) = vault.canDelegateWithdraw(tokenId, bob);
        assertFalse(canWithdraw);
        assertEq(amount, 0);
    }

    function test_CanDelegateWithdraw_NotDelegate() public {
        (bool canWithdraw, uint256 amount,) = vault.canDelegateWithdraw(tokenId, dave);
        assertFalse(canWithdraw);
        assertEq(amount, 0);
    }

    function test_GetWalletDelegatePermission() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        IVaultNFT.WalletDelegatePermission memory permission = vault.getWalletDelegatePermission(alice, bob);
        assertEq(permission.percentageBPS, 6000);
        assertEq(permission.grantedAt, block.timestamp);
        assertTrue(permission.active);
    }

    function test_GetDelegateCooldown() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        // Before withdrawal, cooldown is 0
        assertEq(vault.getDelegateCooldown(bob, tokenId), 0);

        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        // After withdrawal, cooldown is set
        assertEq(vault.getDelegateCooldown(bob, tokenId), block.timestamp);
    }

    // ========== Integration Tests ==========

    function test_DelegationWithOwnerWithdrawal() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        uint256 currentCollateral = vault.collateralAmount(tokenId);
        uint256 totalPool = (currentCollateral * 1000) / 100000;

        // Bob withdraws his 60%
        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);
        uint256 expectedBobAmount = (totalPool * 6000) / 10000;
        assertEq(bobWithdrawn, expectedBobAmount);

        // Owner can still do normal withdraw
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        vm.prank(alice);
        uint256 ownerWithdrawn = vault.withdraw(tokenId);

        uint256 remainingCollateral = currentCollateral - bobWithdrawn;
        uint256 expectedOwnerAmount = (remainingCollateral * 1000) / 100000;
        assertEq(ownerWithdrawn, expectedOwnerAmount);
    }

    function test_DelegationActivityTracking() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 6000);

        uint256 activityBefore = vault.lastActivity(tokenId);

        vm.warp(block.timestamp + 1);

        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        uint256 activityAfter = vault.lastActivity(tokenId);
        assertGt(activityAfter, activityBefore);
    }

    // ========== Same Delegate Multiple Owners Tests ==========

    function test_SameDelegateMultipleOwners() public {
        // Give Dave some assets (treasures start at tokenId 10 since alice has 0-9)
        wbtc.mint(dave, 100 * ONE_BTC);
        treasure.mintBatch(dave, 5); // Dave gets tokenIds 10-14

        vm.startPrank(dave);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        uint256 daveTokenId = vault.mint(address(treasure), 10, address(wbtc), 3 * ONE_BTC);
        vm.stopPrank();

        // Fast forward for Dave's vault
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Both Alice and Dave delegate to Bob
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 5000);

        vm.prank(dave);
        vault.grantWithdrawalDelegate(bob, 3000);

        // Bob can withdraw from Alice's vault
        vm.prank(bob);
        vault.withdrawAsDelegate(tokenId);

        // Bob can also withdraw from Dave's vault (independent cooldowns)
        vm.prank(bob);
        vault.withdrawAsDelegate(daveTokenId);

        // Both cooldowns are now active
        assertEq(vault.getDelegateCooldown(bob, tokenId), block.timestamp);
        assertEq(vault.getDelegateCooldown(bob, daveTokenId), block.timestamp);
    }

    // ========== Fuzz Tests ==========

    function testFuzz_DelegationPercentages(uint256 percentage1, uint256 percentage2) public {
        percentage1 = bound(percentage1, 1, 5000);
        percentage2 = bound(percentage2, 1, 10000 - percentage1);

        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, percentage1);
        vault.grantWithdrawalDelegate(charlie, percentage2);
        vm.stopPrank();

        assertEq(vault.walletTotalDelegatedBPS(alice), percentage1 + percentage2);

        uint256 collateralBeforeBob = vault.collateralAmount(tokenId);
        uint256 bobPool = (collateralBeforeBob * 1000) / 100000;
        uint256 expectedBob = (bobPool * percentage1) / 10000;

        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);
        assertApproxEqAbs(bobWithdrawn, expectedBob, 1);

        uint256 collateralBeforeCharlie = vault.collateralAmount(tokenId);
        uint256 charliePool = (collateralBeforeCharlie * 1000) / 100000;
        uint256 expectedCharlie = (charliePool * percentage2) / 10000;

        vm.prank(charlie);
        uint256 charlieWithdrawn = vault.withdrawAsDelegate(tokenId);
        assertApproxEqAbs(charlieWithdrawn, expectedCharlie, 1);

        uint256 finalCollateral = vault.collateralAmount(tokenId);
        assertEq(collateralBeforeBob - finalCollateral, bobWithdrawn + charlieWithdrawn);
    }

    function testFuzz_CannotExceedDelegationLimit(uint256 p1, uint256 p2, uint256 p3) public {
        p1 = bound(p1, 1, 3333);
        p2 = bound(p2, 1, 3333);
        p3 = bound(p3, 1, 3333);

        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(bob, p1);
        vault.grantWithdrawalDelegate(charlie, p2);

        if (p1 + p2 + p3 > 10000) {
            vm.expectRevert(IVaultNFTDelegation.ExceedsDelegationLimit.selector);
        }
        vault.grantWithdrawalDelegate(dave, p3);
        vm.stopPrank();
    }

    // ========== Vault-Level Delegation Tests ==========

    function test_GrantVaultDelegate() public {
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, 0); // 50%, indefinite

        IVaultNFT.VaultDelegatePermission memory permission = vault.getVaultDelegatePermission(tokenId, bob);
        assertEq(permission.percentageBPS, 5000);
        assertEq(permission.grantedAt, block.timestamp);
        assertEq(permission.expiresAt, 0);
        assertTrue(permission.active);
        assertEq(vault.vaultTotalDelegatedBPS(tokenId), 5000);
    }

    function test_GrantVaultDelegate_TimeBound() public {
        uint256 duration = 30 days;

        vm.expectEmit(true, true, false, true);
        emit IVaultNFTDelegation.VaultDelegateGranted(tokenId, bob, 5000, block.timestamp + duration);

        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, duration);

        IVaultNFT.VaultDelegatePermission memory permission = vault.getVaultDelegatePermission(tokenId, bob);
        assertEq(permission.expiresAt, block.timestamp + duration);
    }

    function test_GrantVaultDelegate_RevertIf_NotOwner() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.NotVaultOwner.selector, tokenId));
        vault.grantVaultDelegate(tokenId, charlie, 5000, 0);
    }

    function test_GrantVaultDelegate_RevertIf_ZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(IVaultNFTDelegation.ZeroAddress.selector);
        vault.grantVaultDelegate(tokenId, address(0), 5000, 0);
    }

    function test_GrantVaultDelegate_RevertIf_SelfDelegate() public {
        vm.prank(alice);
        vm.expectRevert(IVaultNFTDelegation.CannotDelegateSelf.selector);
        vault.grantVaultDelegate(tokenId, alice, 5000, 0);
    }

    function test_GrantVaultDelegate_RevertIf_InvalidPercentage() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.InvalidPercentage.selector, 0));
        vault.grantVaultDelegate(tokenId, bob, 0, 0);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.InvalidPercentage.selector, 10001));
        vault.grantVaultDelegate(tokenId, bob, 10001, 0);
    }

    function test_RevokeVaultDelegate() public {
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, 0);

        vm.expectEmit(true, true, false, true);
        emit IVaultNFTDelegation.VaultDelegateRevoked(tokenId, bob);

        vm.prank(alice);
        vault.revokeVaultDelegate(tokenId, bob);

        IVaultNFT.VaultDelegatePermission memory permission = vault.getVaultDelegatePermission(tokenId, bob);
        assertFalse(permission.active);
        assertEq(vault.vaultTotalDelegatedBPS(tokenId), 0);
    }

    function test_RevokeVaultDelegate_RevertIf_NotOwner() public {
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, 0);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.NotVaultOwner.selector, tokenId));
        vault.revokeVaultDelegate(tokenId, bob);
    }

    function test_RevokeVaultDelegate_RevertIf_NotActive() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.VaultDelegateNotActive.selector, tokenId, bob));
        vault.revokeVaultDelegate(tokenId, bob);
    }

    function test_VaultDelegateOverridesWalletLevel() public {
        // Grant wallet-level 30%
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 3000);

        // Grant vault-specific 70%
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 7000, 0);

        // Check resolution - vault-specific should win
        (uint256 percentageBPS, IVaultNFTDelegation.DelegationType dtype,) = vault.getEffectiveDelegation(tokenId, bob);
        assertEq(percentageBPS, 7000);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.VaultSpecific));

        // canDelegateWithdraw should report VaultSpecific
        (bool canWithdraw, uint256 amount, IVaultNFTDelegation.DelegationType returnedType) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw);
        assertGt(amount, 0);
        assertEq(uint256(returnedType), uint256(IVaultNFTDelegation.DelegationType.VaultSpecific));

        // Withdrawal uses vault-specific rate (70%)
        uint256 collateral = vault.collateralAmount(tokenId);
        uint256 pool = (collateral * 1000) / 100000;
        uint256 expectedVaultSpecific = (pool * 7000) / 10000;

        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);
        assertEq(withdrawn, expectedVaultSpecific);
    }

    function test_VaultDelegateExpiry() public {
        uint256 duration = 7 days;

        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, duration);

        // Before expiry - can withdraw
        (bool canWithdraw,,) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw);

        // After expiry - cannot withdraw
        vm.warp(block.timestamp + duration + 1);

        (canWithdraw,,) = vault.canDelegateWithdraw(tokenId, bob);
        assertFalse(canWithdraw);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.NotActiveDelegate.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_VaultDelegateTravelsWithTransfer() public {
        // Grant vault-specific delegation to Bob
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, 0);

        // Transfer vault to Dave
        vm.prank(alice);
        vault.transferFrom(alice, dave, tokenId);

        // Bob can still withdraw (vault-specific travels with vault)
        (bool canWithdraw, uint256 amount, IVaultNFTDelegation.DelegationType dtype) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw);
        assertGt(amount, 0);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.VaultSpecific));

        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);
        assertGt(withdrawn, 0);
    }

    function test_WalletDelegateDoesNotTravelWithTransfer() public {
        // Grant wallet-level delegation to Bob
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 5000);

        // Transfer vault to Dave
        vm.prank(alice);
        vault.transferFrom(alice, dave, tokenId);

        // Bob cannot withdraw (wallet-level follows owner, not vault)
        (bool canWithdraw,,) = vault.canDelegateWithdraw(tokenId, bob);
        assertFalse(canWithdraw);
    }

    function test_IndependentCapacityCaps() public {
        // Grant 100% wallet-level
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 10000);

        // Grant 100% vault-specific - should succeed (independent caps)
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, charlie, 10000, 0);

        assertEq(vault.walletTotalDelegatedBPS(alice), 10000);
        assertEq(vault.vaultTotalDelegatedBPS(tokenId), 10000);

        // Both can withdraw (vault-specific applies to tokenId for charlie, wallet-level for bob)
        (bool bobCanWithdraw,,) = vault.canDelegateWithdraw(tokenId, bob);
        (bool charlieCanWithdraw,,) = vault.canDelegateWithdraw(tokenId, charlie);

        // Charlie has vault-specific which overrides any wallet-level (which she doesn't have)
        assertTrue(charlieCanWithdraw);
        // Bob has wallet-level only
        assertTrue(bobCanWithdraw);
    }

    function test_CannotExceedVaultDelegationLimit() public {
        vm.startPrank(alice);
        vault.grantVaultDelegate(tokenId, bob, 6000, 0);
        vault.grantVaultDelegate(tokenId, charlie, 3000, 0);

        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.ExceedsVaultDelegationLimit.selector, tokenId));
        vault.grantVaultDelegate(tokenId, dave, 2000, 0); // Would total 11000 (110%)
        vm.stopPrank();
    }

    function test_ExpiredVaultDelegateWithFallback() public {
        // Grant wallet-level 30%
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 3000);

        // Grant vault-specific 70% with expiry
        uint256 duration = 7 days;
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 7000, duration);

        // Expire vault-specific
        vm.warp(block.timestamp + duration + 1);

        // getEffectiveDelegation shows the expired vault-specific (for visibility)
        (uint256 percentageBPS, IVaultNFTDelegation.DelegationType dtype, bool isExpired) = vault.getEffectiveDelegation(tokenId, bob);
        assertEq(percentageBPS, 7000);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.VaultSpecific));
        assertTrue(isExpired);

        // canDelegateWithdraw falls back to wallet-level since vault-specific is expired
        (bool canWithdraw, uint256 amount, IVaultNFTDelegation.DelegationType returnedType) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw);
        assertGt(amount, 0);
        assertEq(uint256(returnedType), uint256(IVaultNFTDelegation.DelegationType.WalletLevel));
    }

    function test_ExpiredVaultDelegateNoWalletFallback() public {
        // Grant vault-specific 50% with expiry (no wallet-level)
        uint256 duration = 7 days;
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, duration);

        // Expire vault-specific
        vm.warp(block.timestamp + duration + 1);

        // getEffectiveDelegation shows the expired vault-specific
        (uint256 percentageBPS, IVaultNFTDelegation.DelegationType dtype, bool isExpired) = vault.getEffectiveDelegation(tokenId, bob);
        assertEq(percentageBPS, 5000);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.VaultSpecific));
        assertTrue(isExpired);

        // Without wallet-level fallback, cannot withdraw
        (bool canWithdraw,,) = vault.canDelegateWithdraw(tokenId, bob);
        assertFalse(canWithdraw);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFTDelegation.NotActiveDelegate.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_UpdateExistingVaultDelegate() public {
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, 0);

        vm.expectEmit(true, true, false, true);
        emit IVaultNFTDelegation.VaultDelegateUpdated(tokenId, bob, 5000, 8000, 0);

        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 8000, 0);

        assertEq(vault.vaultTotalDelegatedBPS(tokenId), 8000);
    }

    function test_VaultDelegateWithdrawal() public {
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, 0);

        uint256 collateral = vault.collateralAmount(tokenId);
        uint256 pool = (collateral * 1000) / 100000;
        uint256 expected = (pool * 5000) / 10000;

        uint256 bobBalanceBefore = wbtc.balanceOf(bob);

        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);

        assertEq(withdrawn, expected);
        assertEq(wbtc.balanceOf(bob), bobBalanceBefore + expected);
    }

    function test_VaultDelegatePerVaultIsolation() public {
        // Grant vault-specific for tokenId only
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 5000, 0);

        // Bob can withdraw from tokenId
        (bool canWithdraw1,,) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw1);

        // Bob cannot withdraw from tokenId2 (no delegation)
        (bool canWithdraw2,,) = vault.canDelegateWithdraw(tokenId2, bob);
        assertFalse(canWithdraw2);
    }

    function test_GetEffectiveDelegation_None() public {
        (uint256 percentageBPS, IVaultNFTDelegation.DelegationType dtype, bool isExpired) = vault.getEffectiveDelegation(tokenId, bob);
        assertEq(percentageBPS, 0);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.None));
        assertFalse(isExpired);
    }

    function test_GetEffectiveDelegation_WalletLevel() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 3000);

        (uint256 percentageBPS, IVaultNFTDelegation.DelegationType dtype, bool isExpired) = vault.getEffectiveDelegation(tokenId, bob);
        assertEq(percentageBPS, 3000);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.WalletLevel));
        assertFalse(isExpired);
    }

    function test_GetEffectiveDelegation_VaultSpecific() public {
        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 7000, 0);

        (uint256 percentageBPS, IVaultNFTDelegation.DelegationType dtype, bool isExpired) = vault.getEffectiveDelegation(tokenId, bob);
        assertEq(percentageBPS, 7000);
        assertEq(uint256(dtype), uint256(IVaultNFTDelegation.DelegationType.VaultSpecific));
        assertFalse(isExpired);
    }

    function testFuzz_VaultDelegation(uint256 percentage, uint256 duration) public {
        percentage = bound(percentage, 1, 10000);
        duration = bound(duration, 0, 365 days);

        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, percentage, duration);

        IVaultNFT.VaultDelegatePermission memory permission = vault.getVaultDelegatePermission(tokenId, bob);
        assertEq(permission.percentageBPS, percentage);
        assertTrue(permission.active);

        if (duration > 0) {
            assertEq(permission.expiresAt, block.timestamp + duration);
        } else {
            assertEq(permission.expiresAt, 0);
        }

        assertEq(vault.vaultTotalDelegatedBPS(tokenId), percentage);
    }

    function testFuzz_VaultDelegateWithdrawal(uint256 collateral, uint256 percentage) public {
        collateral = bound(collateral, 1e8, 100e8); // 1-100 BTC
        percentage = bound(percentage, 100, 10000); // 1-100%

        // Mint a new vault with fuzzed collateral
        wbtc.mint(alice, collateral);
        vm.startPrank(alice);
        uint256 newTokenId = vault.mint(address(treasure), 2, address(wbtc), collateral);
        vm.stopPrank();

        // Fast forward past vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Grant vault-specific delegation
        vm.prank(alice);
        vault.grantVaultDelegate(newTokenId, bob, percentage, 0);

        uint256 currentCollateral = vault.collateralAmount(newTokenId);
        uint256 pool = (currentCollateral * 1000) / 100000;
        uint256 expected = (pool * percentage) / 10000;

        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(newTokenId);

        assertEq(withdrawn, expected);
        assertEq(vault.collateralAmount(newTokenId), currentCollateral - withdrawn);
    }
}
