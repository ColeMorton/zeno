// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {BaseTest} from "../utils/BaseTest.sol";

contract VaultNFTTest is BaseTest {
    // ========== Mint ==========

    function test_Mint() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        assertEq(tokenId, 0);
        assertEq(vault.ownerOf(tokenId), alice);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC);
        assertEq(vault.totalActiveCollateral(), ONE_BTC);
        assertEq(vault.strippedReserve(tokenId), 0);
    }

    function test_Mint_RevertIf_InvalidCollateral() public {
        address fakeToken = makeAddr("fakeToken");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.InvalidCollateralToken.selector, fakeToken));
        vault.mint(address(treasure), 0, fakeToken, ONE_BTC);
    }

    function test_Mint_RevertIf_ZeroCollateral() public {
        vm.prank(alice);
        vm.expectRevert(IVaultNFT.ZeroCollateral.selector);
        vault.mint(address(treasure), 0, address(wbtc), 0);
    }

    // ========== Withdraw ==========

    function test_Withdraw_AfterVesting() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        uint256 expectedWithdrawal = (ONE_BTC * 1000) / 100000;
        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        assertEq(withdrawn, expectedWithdrawal);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore + expectedWithdrawal);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC - expectedWithdrawal);
    }

    function test_Withdraw_DecrementsTotalActiveCollateral() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        assertEq(vault.totalActiveCollateral(), ONE_BTC - withdrawn);
    }

    function test_Withdraw_RevertIf_StillVesting() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.withdraw(tokenId);
    }

    function test_Withdraw_RevertIf_TooSoon() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.withdraw(tokenId);

        vm.warp(block.timestamp + 15 days);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(tokenId);
    }

    function test_Withdraw_MultipleWithdrawals() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        uint256 remainingCollateral = ONE_BTC;

        for (uint256 i = 0; i < 3; i++) {
            uint256 expectedWithdrawal = (remainingCollateral * 1000) / 100000;

            vm.prank(alice);
            uint256 withdrawn = vault.withdraw(tokenId);

            assertEq(withdrawn, expectedWithdrawal);
            remainingCollateral -= expectedWithdrawal;

            _skipWithdrawalPeriod();
        }

        assertEq(vault.collateralAmount(tokenId), remainingCollateral);
    }

    // ========== Early Redemption ==========

    function test_EarlyRedeem() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        uint256 expectedReturned = (ONE_BTC * 365 days) / VESTING_PERIOD;
        uint256 expectedForfeited = ONE_BTC - expectedReturned;

        assertEq(returned, expectedReturned);
        assertEq(forfeited, expectedForfeited);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore + returned);
        assertEq(vault.matchPool(), forfeited);

        vm.expectRevert();
        vault.ownerOf(tokenId);
    }

    function test_EarlyRedeem_AtDayZero() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertEq(returned, 0);
        assertEq(forfeited, ONE_BTC);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore);
    }

    function test_EarlyRedeem_AfterFullVesting() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertEq(returned, ONE_BTC);
        assertEq(forfeited, 0);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore + ONE_BTC);
    }

    function test_EarlyRedeem_RevertIf_StripOutstanding() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 4);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultNFT.StripOutstanding.selector, tokenId, ONE_BTC / 4)
        );
        vault.earlyRedeem(tokenId);
    }

    function test_EarlyRedeem_AfterFullRecombine() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 2);

        vm.prank(alice);
        vault.recombine(tokenId, ONE_BTC / 2);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertEq(returned + forfeited, ONE_BTC);
    }

    // ========== Strip ==========

    function test_Strip() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.expectEmit(true, true, false, true);
        emit IVaultNFT.Stripped(tokenId, alice, ONE_BTC / 2);

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 2);

        assertEq(btcToken.balanceOf(alice), ONE_BTC / 2);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC / 2);
        assertEq(vault.strippedReserve(tokenId), ONE_BTC / 2);
        assertEq(vault.totalStrippedReserve(), ONE_BTC / 2);
        assertEq(vault.totalActiveCollateral(), ONE_BTC / 2);
    }

    function test_Strip_RevertIf_StillVesting() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.strip(tokenId, ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD - 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.strip(tokenId, ONE_BTC);
    }

    function test_Strip_Repeatable() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.startPrank(alice);
        vault.strip(tokenId, ONE_BTC / 4);
        vault.strip(tokenId, ONE_BTC / 4);
        vault.strip(tokenId, ONE_BTC / 2);
        vm.stopPrank();

        assertEq(btcToken.balanceOf(alice), ONE_BTC);
        assertEq(vault.strippedReserve(tokenId), ONE_BTC);
        assertEq(vault.collateralAmount(tokenId), 0);
        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply());
    }

    function test_Strip_RevertIf_ZeroAmount() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vm.expectRevert(IVaultNFT.ZeroAmount.selector);
        vault.strip(tokenId, 0);
    }

    function test_Strip_RevertIf_InsufficientCollateral() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVaultNFT.InsufficientCollateral.selector, tokenId, ONE_BTC + 1, ONE_BTC
            )
        );
        vault.strip(tokenId, ONE_BTC + 1);
    }

    function test_Strip_RevertIf_NotOwner() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.strip(tokenId, ONE_BTC);
    }

    // ========== Recombine ==========

    function test_Recombine() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.expectEmit(true, true, false, true);
        emit IVaultNFT.Recombined(tokenId, alice, ONE_BTC);

        vm.prank(alice);
        vault.recombine(tokenId, ONE_BTC);

        assertEq(btcToken.balanceOf(alice), 0);
        assertEq(btcToken.totalSupply(), 0);
        assertEq(vault.strippedReserve(tokenId), 0);
        assertEq(vault.totalStrippedReserve(), 0);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC);
        assertEq(vault.totalActiveCollateral(), ONE_BTC);
    }

    function test_Recombine_Partial() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        vault.recombine(tokenId, ONE_BTC / 4);

        assertEq(btcToken.balanceOf(alice), ONE_BTC - ONE_BTC / 4);
        assertEq(vault.strippedReserve(tokenId), ONE_BTC - ONE_BTC / 4);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC / 4);
        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply());
    }

    function test_Recombine_RevertIf_ZeroAmount() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        vm.expectRevert(IVaultNFT.ZeroAmount.selector);
        vault.recombine(tokenId, 0);
    }

    function test_Recombine_RevertIf_InsufficientReserve() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 2);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVaultNFT.InsufficientReserve.selector, tokenId, ONE_BTC, ONE_BTC / 2
            )
        );
        vault.recombine(tokenId, ONE_BTC);
    }

    function test_Recombine_RevertIf_InsufficientBtcToken() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, ONE_BTC / 2)
        );
        vault.recombine(tokenId, ONE_BTC);
    }

    function test_Recombine_RevertIf_NotOwner() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotTokenOwner.selector, tokenId));
        vault.recombine(tokenId, ONE_BTC);
    }

    // ========== Reserve Immunization ==========

    function test_Withdraw_DoesNotTouchReserve() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        _skipVesting();

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        // Active collateral is 0, so withdrawal pays 1% of 0 = 0
        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        assertEq(withdrawn, 0);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore);
        assertEq(vault.strippedReserve(tokenId), ONE_BTC);
        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply());
    }

    function test_Withdraw_PartialStrip_OnlyActiveBase() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 2);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        // 1% of the active half only
        assertEq(withdrawn, ((ONE_BTC / 2) * 1000) / 100000);
        assertEq(vault.strippedReserve(tokenId), ONE_BTC / 2);
    }

    // ========== Match Settlement ==========

    function test_ClaimMatch() public {
        uint256 aliceTokenId = _mintVault(alice, 0, ONE_BTC);
        uint256 bobTokenId = _mintVault(bob, 100, ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceTokenId);
        assertGt(forfeited, 0);

        uint256 bobCollateralBefore = vault.collateralAmount(bobTokenId);
        uint256 pending = vault.pendingMatch(bobTokenId);

        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobTokenId);

        assertGt(claimed, 0);
        assertEq(claimed, pending);
        assertEq(vault.collateralAmount(bobTokenId), bobCollateralBefore + claimed);
        assertEq(vault.pendingMatch(bobTokenId), 0);
    }

    function test_ClaimMatch_NoVestingGate() public {
        uint256 aliceTokenId = _mintVault(alice, 0, ONE_BTC);
        uint256 bobTokenId = _mintVault(bob, 100, ONE_BTC);

        vm.prank(alice);
        vault.earlyRedeem(aliceTokenId); // day-zero redeem, forfeits everything

        // Bob settles immediately, still deep in vesting
        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobTokenId);

        assertGt(claimed, 0);
    }

    function test_ClaimMatch_ReturnsZeroWhenNothingPending() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.prank(alice);
        uint256 claimed = vault.claimMatch(tokenId);

        assertEq(claimed, 0);
    }

    function test_ClaimMatch_SecondClaimReturnsZero() public {
        uint256 aliceTokenId = _mintVault(alice, 0, ONE_BTC);
        uint256 bobTokenId = _mintVault(bob, 100, ONE_BTC);

        vm.warp(block.timestamp + 365 days);
        vm.prank(alice);
        vault.earlyRedeem(aliceTokenId);

        vm.prank(bob);
        uint256 first = vault.claimMatch(bobTokenId);
        assertGt(first, 0);

        vm.prank(bob);
        uint256 second = vault.claimMatch(bobTokenId);
        assertEq(second, 0);
    }

    // ========== Views ==========

    function test_GetVaultInfo() public {
        // vm.getBlockTimestamp, not block.timestamp: via-IR rematerializes TIMESTAMP
        // per use, so a block.timestamp local can silently re-read after vm.warp.
        uint256 mintTime = vm.getBlockTimestamp();
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        uint256 stripTime = mintTime + VESTING_PERIOD;
        vm.warp(stripTime);

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 4);

        (
            address treasureContract_,
            uint256 treasureTokenId_,
            address collateralToken_,
            uint256 collateralAmount_,
            uint256 strippedReserve_,
            uint256 mintTimestamp_,
            uint256 lastWithdrawal_,
            uint256 lastActivity_
        ) = vault.getVaultInfo(tokenId);

        assertEq(treasureContract_, address(treasure));
        assertEq(treasureTokenId_, 0);
        assertEq(collateralToken_, address(wbtc));
        assertEq(collateralAmount_, ONE_BTC - ONE_BTC / 4);
        assertEq(strippedReserve_, ONE_BTC / 4);
        assertEq(mintTimestamp_, mintTime);
        assertEq(lastWithdrawal_, 0);
        assertEq(lastActivity_, stripTime);
    }

    function test_IsVested() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        assertFalse(vault.isVested(tokenId));

        vm.warp(block.timestamp + VESTING_PERIOD - 1);
        assertFalse(vault.isVested(tokenId));

        vm.warp(block.timestamp + 1);
        assertTrue(vault.isVested(tokenId));
    }

    function test_GetWithdrawableAmount() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        assertEq(vault.getWithdrawableAmount(tokenId), 0);

        _skipVesting();

        uint256 expected = (ONE_BTC * 1000) / 100000;
        assertEq(vault.getWithdrawableAmount(tokenId), expected);

        vm.prank(alice);
        vault.withdraw(tokenId);

        assertEq(vault.getWithdrawableAmount(tokenId), 0);

        _skipWithdrawalPeriod();

        uint256 remaining = ONE_BTC - expected;
        uint256 nextExpected = (remaining * 1000) / 100000;
        assertEq(vault.getWithdrawableAmount(tokenId), nextExpected);
    }

    function test_Transfer_UpdatesActivity() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        uint256 initialActivity = vault.lastActivity(tokenId);

        vm.warp(block.timestamp + 100 days);

        vm.prank(alice);
        vault.transferFrom(alice, bob, tokenId);

        assertGt(vault.lastActivity(tokenId), initialActivity);
        assertEq(vault.ownerOf(tokenId), bob);
    }

    // ========== Fuzz ==========

    function testFuzz_Withdraw(uint256 collateral) public {
        collateral = bound(collateral, ONE_BTC / 100, 100 * ONE_BTC);

        uint256 tokenId = _mintVault(alice, 0, collateral);

        _skipVesting();

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        assertEq(withdrawn, (collateral * 1000) / 100000);
    }

    function testFuzz_EarlyRedeem_LinearUnlock(uint256 daysHeld) public {
        daysHeld = bound(daysHeld, 0, 1129);

        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.warp(block.timestamp + daysHeld * 1 days);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        uint256 expectedReturned = (ONE_BTC * daysHeld * 1 days) / VESTING_PERIOD;

        assertEq(returned, expectedReturned);
        assertEq(forfeited, ONE_BTC - expectedReturned);
        assertEq(returned + forfeited, ONE_BTC);
    }

    function testFuzz_StripRecombine_ReserveBacking(uint256 stripAmount, uint256 recombineAmount)
        public
    {
        stripAmount = bound(stripAmount, 1, ONE_BTC);

        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, stripAmount);

        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply());

        recombineAmount = bound(recombineAmount, 1, stripAmount);
        vm.prank(alice);
        vault.recombine(tokenId, recombineAmount);

        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply());
        assertEq(vault.collateralAmount(tokenId) + vault.strippedReserve(tokenId), ONE_BTC);
    }
}
