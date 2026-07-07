// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {VestingEscrow} from "../../src/VestingEscrow.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";
import {BaseTest} from "../utils/BaseTest.sol";

contract VestingEscrowTest is BaseTest {
    VestingEscrow public escrow;
    MockWBTC public lpToken;

    uint256 internal constant LP_AMOUNT = 5e18;

    function setUp() public override {
        super.setUp();
        lpToken = new MockWBTC();
        escrow = new VestingEscrow(address(vault), address(lpToken));

        lpToken.mint(alice, 100e18);
        lpToken.mint(bob, 100e18);
        vm.prank(alice);
        lpToken.approve(address(escrow), type(uint256).max);
        vm.prank(bob);
        lpToken.approve(address(escrow), type(uint256).max);
    }

    function _mintWithEscrow(address user, uint256 treasureId, uint256 collateral, uint256 lpAmount)
        internal
        returns (uint256 tokenId)
    {
        tokenId = _mintVault(user, treasureId, collateral);
        vm.startPrank(user);
        vault.setRedeemHook(tokenId, address(escrow));
        escrow.deposit(tokenId, lpAmount);
        vm.stopPrank();
    }

    // ========== Redeem Hook ==========

    function test_SetRedeemHook() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        vm.prank(alice);
        vault.setRedeemHook(tokenId, address(escrow));
        assertEq(vault.redeemHook(tokenId), address(escrow));
    }

    function test_SetRedeemHook_RevertIf_NotOwner() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.setRedeemHook(tokenId, address(escrow));
    }

    function test_SetRedeemHook_RevertIf_AlreadySet() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        vm.startPrank(alice);
        vault.setRedeemHook(tokenId, address(escrow));
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.HookAlreadySet.selector, tokenId));
        vault.setRedeemHook(tokenId, address(escrow));
        vm.stopPrank();
    }

    // ========== Deposit ==========

    function test_Deposit() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);

        assertEq(escrow.escrowAmount(tokenId), LP_AMOUNT);
        assertEq(escrow.mintTimestamp(tokenId), vault.mintTimestamp(tokenId));
        assertEq(escrow.totalEscrowed(), LP_AMOUNT);
        assertEq(lpToken.balanceOf(address(escrow)), LP_AMOUNT);
    }

    function test_Deposit_RevertIf_HookNotBound() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VestingEscrow.HookNotBound.selector, tokenId));
        escrow.deposit(tokenId, LP_AMOUNT);
    }

    function test_Deposit_RevertIf_AlreadyDeposited() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VestingEscrow.AlreadyDeposited.selector, tokenId));
        escrow.deposit(tokenId, LP_AMOUNT);
    }

    function test_Deposit_RevertIf_ZeroAmount() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        vm.prank(alice);
        vm.expectRevert(VestingEscrow.ZeroAmount.selector);
        escrow.deposit(tokenId, 0);
    }

    // ========== Claim ==========

    function test_Claim_AfterVesting() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        _skipVesting();

        uint256 balanceBefore = lpToken.balanceOf(alice);
        vm.prank(alice);
        uint256 claimed = escrow.claim(tokenId);

        assertEq(claimed, LP_AMOUNT);
        assertEq(lpToken.balanceOf(alice), balanceBefore + LP_AMOUNT);
        assertEq(escrow.escrowAmount(tokenId), 0);
        assertEq(escrow.totalEscrowed(), 0);
    }

    function test_Claim_RevertIf_StillVesting() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VestingEscrow.StillVesting.selector, tokenId));
        escrow.claim(tokenId);
    }

    function test_Claim_RevertIf_NotVaultOwner() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        _skipVesting();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(VestingEscrow.NotVaultOwner.selector, tokenId));
        escrow.claim(tokenId);
    }

    function test_Claim_RightsFollowVaultTransfer() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        _skipVesting();

        vm.prank(alice);
        vault.transferFrom(alice, bob, tokenId);

        vm.prank(bob);
        uint256 claimed = escrow.claim(tokenId);
        assertEq(claimed, LP_AMOUNT);
    }

    function test_Claimable() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        assertEq(escrow.claimable(tokenId), 0);
        _skipVesting();
        assertEq(escrow.claimable(tokenId), LP_AMOUNT);
    }

    // ========== Atomic Early Exit ==========

    function test_EarlyRedeem_SettlesBothLegsAtomically() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);

        // Halfway through vesting: ~50% returned on both legs
        vm.warp(block.timestamp + VESTING_PERIOD / 2);

        uint256 wbtcBefore = wbtc.balanceOf(alice);
        uint256 lpBefore = lpToken.balanceOf(alice);

        vm.prank(alice);
        (uint256 primaryReturned,) = vault.earlyRedeem(tokenId);

        // Primary leg paid by the vault
        assertEq(wbtc.balanceOf(alice), wbtcBefore + primaryReturned);
        assertGt(primaryReturned, 0);

        // Secondary leg settled by the escrow in the same transaction
        uint256 lpReturned = lpToken.balanceOf(alice) - lpBefore;
        assertGt(lpReturned, 0);
        assertLt(lpReturned, LP_AMOUNT);
        assertEq(escrow.escrowAmount(tokenId), 0);

        // Forfeited LP accrued to the escrow match pool
        assertEq(escrow.matchPool(), LP_AMOUNT - lpReturned);

        // Vault burned
        vm.expectRevert();
        vault.ownerOf(tokenId);
    }

    function test_EarlyRedeem_ForfeitAccruesToRemainingPositions() public {
        uint256 aliceId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        uint256 bobId = _mintWithEscrow(bob, 100, ONE_BTC, LP_AMOUNT);

        vm.warp(block.timestamp + VESTING_PERIOD / 2);

        vm.prank(alice);
        vault.earlyRedeem(aliceId);

        uint256 pending = escrow.pendingMatch(bobId);
        assertGt(pending, 0);
        assertEq(pending, escrow.matchPool());

        // Bob claims his position with the accrued match after vesting
        _skipVesting();
        vm.prank(bob);
        uint256 claimed = escrow.claim(bobId);
        assertEq(claimed, LP_AMOUNT + pending);
    }

    function test_EarlyRedeem_AfterClaim_NoEscrowEffect() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        _skipVesting();

        vm.startPrank(alice);
        escrow.claim(tokenId);

        uint256 lpBefore = lpToken.balanceOf(alice);
        vault.earlyRedeem(tokenId); // fully vested: full primary back, hook no-ops
        vm.stopPrank();

        assertEq(lpToken.balanceOf(alice), lpBefore);
    }

    function test_OnEarlyRedeem_RevertIf_NotVault() public {
        uint256 tokenId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        vm.prank(alice);
        vm.expectRevert(VestingEscrow.NotVault.selector);
        escrow.onEarlyRedeem(tokenId, alice);
    }

    // ========== Match Conservation ==========

    function test_MatchPool_Conservation() public {
        uint256 aliceId = _mintWithEscrow(alice, 0, ONE_BTC, LP_AMOUNT);
        uint256 bobId = _mintWithEscrow(bob, 100, ONE_BTC, 3e18);

        vm.warp(block.timestamp + VESTING_PERIOD / 4);
        vm.prank(alice);
        vault.earlyRedeem(aliceId);

        vm.prank(bob);
        uint256 settled = escrow.claimMatch(bobId);

        // Settled share never exceeds the pool accrual
        assertLe(settled, LP_AMOUNT);
        assertEq(escrow.escrowAmount(bobId), 3e18 + settled);
        // Escrow always holds enough tokens to cover positions + unsettled pool
        assertGe(lpToken.balanceOf(address(escrow)), escrow.totalEscrowed() + escrow.matchPool());
    }
}
