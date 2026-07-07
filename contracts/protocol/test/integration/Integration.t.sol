// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {BaseTest} from "../utils/BaseTest.sol";

contract IntegrationTest is BaseTest {
    function test_FullLifecycle_MintVestWithdrawStripRecombine() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        assertEq(vault.ownerOf(tokenId), alice);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC);

        _skipVesting();
        assertTrue(vault.isVested(tokenId));

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);
        vm.prank(alice);
        uint256 withdrawn1 = vault.withdraw(tokenId);
        assertGt(withdrawn1, 0);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore + withdrawn1);

        _skipWithdrawalPeriod();
        vm.prank(alice);
        uint256 withdrawn2 = vault.withdraw(tokenId);
        assertGt(withdrawn2, 0);
        assertLt(withdrawn2, withdrawn1);

        // Strip the full remaining active collateral, then recombine it back
        uint256 stripped = _stripAll(alice, tokenId);
        assertEq(btcToken.balanceOf(alice), stripped);
        assertEq(vault.strippedReserve(tokenId), stripped);
        assertEq(vault.collateralAmount(tokenId), 0);

        vm.prank(alice);
        vault.recombine(tokenId, stripped);
        assertEq(btcToken.balanceOf(alice), 0);
        assertEq(vault.strippedReserve(tokenId), 0);
        assertEq(vault.collateralAmount(tokenId), stripped);

        _skipWithdrawalPeriod();
        vm.prank(alice);
        uint256 withdrawn3 = vault.withdraw(tokenId);
        assertGt(withdrawn3, 0);
    }

    function test_EarlyRedemptionFlow() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertGt(returned, 0);
        assertGt(forfeited, 0);
        assertEq(returned + forfeited, ONE_BTC);
        assertEq(wbtc.balanceOf(alice), aliceWbtcBefore + returned);
        assertEq(vault.matchPool(), forfeited);
        assertEq(treasure.ownerOf(0), address(0xdead));

        vm.expectRevert();
        vault.ownerOf(tokenId);
    }

    function test_DormancyClaimFlow() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        assertEq(btcToken.balanceOf(alice), 0);
        assertEq(btcToken.balanceOf(bob), ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertTrue(eligible);

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        (, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.CLAIMABLE));

        uint256 bobWbtcBefore = wbtc.balanceOf(bob);

        // Fractional claims until the reserve is drained
        vm.prank(bob);
        uint256 firstClaim = vault.claimDormantCollateral(tokenId, ONE_BTC / 2);
        assertEq(firstClaim, ONE_BTC / 2);

        vm.prank(bob);
        uint256 secondClaim = vault.claimDormantCollateral(tokenId, ONE_BTC - ONE_BTC / 2);

        assertEq(firstClaim + secondClaim, ONE_BTC);
        assertEq(wbtc.balanceOf(bob), bobWbtcBefore + ONE_BTC);
        assertEq(btcToken.balanceOf(bob), 0);

        // Vault survives: alice keeps the token and its treasure
        assertEq(vault.ownerOf(tokenId), alice);
        assertEq(treasure.ownerOf(0), address(vault));
        assertEq(vault.strippedReserve(tokenId), 0);
    }

    function test_MultiUserMatchPool() public {
        uint256 aliceToken = _mintVault(alice, 0, 2 * ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);
        uint256 charlieToken = _mintVault(charlie, 200, ONE_BTC);

        assertEq(vault.totalActiveCollateral(), 4 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);
        assertGt(forfeited, 0);

        assertEq(vault.matchPool(), forfeited);

        uint256 bobCollateralBefore = vault.collateralAmount(bobToken);
        vm.prank(bob);
        uint256 bobClaimed = vault.claimMatch(bobToken);
        assertGt(bobClaimed, 0);
        assertEq(vault.collateralAmount(bobToken), bobCollateralBefore + bobClaimed);

        uint256 charlieCollateralBefore = vault.collateralAmount(charlieToken);
        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);
        assertGt(charlieClaimed, 0);
        assertEq(vault.collateralAmount(charlieToken), charlieCollateralBefore + charlieClaimed);

        assertLe(bobClaimed + charlieClaimed, forfeited);
    }

    function test_WithdrawalRate() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        // Fixed rate: 1.0% = 1000/100000
        assertEq(withdrawn, (ONE_BTC * 1000) / 100000);
    }

    function test_CollateralNeverDepletes_ZenoParadox() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        for (uint256 i = 0; i < 100; i++) {
            uint256 remaining = vault.collateralAmount(tokenId);
            if (remaining == 0) break;

            vm.prank(alice);
            vault.withdraw(tokenId);

            _skipWithdrawalPeriod();
        }

        uint256 finalRemaining = vault.collateralAmount(tokenId);
        assertGt(finalRemaining, 0);
    }

    function test_TransferUpdatesActivity_PreventsUnintendedDormancy() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        uint256 activityTimestamp = vault.lastActivity(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(activityTimestamp + DORMANCY_THRESHOLD - 100 days);

        vm.prank(alice);
        vault.transferFrom(alice, bob, tokenId);

        vm.warp(block.timestamp + 200 days);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }

    function test_Invariant_TotalActiveCollateral_TracksWithdrawals() public {
        uint256 aliceToken = _mintVault(alice, 0, 2 * ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        uint256 aliceWithdrawn = vault.withdraw(aliceToken);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC - aliceWithdrawn);

        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdraw(bobToken);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC - aliceWithdrawn - bobWithdrawn);
    }

    function test_VestingExactBoundary() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD - 1);

        assertFalse(vault.isVested(tokenId));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.withdraw(tokenId);

        vm.warp(block.timestamp + 1);

        assertTrue(vault.isVested(tokenId));

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);
    }

    function test_WithdrawalPeriodExactBoundary() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.withdraw(tokenId);

        vm.warp(block.timestamp + WITHDRAWAL_PERIOD - 1);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(tokenId);

        vm.warp(block.timestamp + 1);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);
    }

    function test_EarlyRedeem_MidVesting() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        uint256 halfVesting = VESTING_PERIOD / 2;
        vm.warp(block.timestamp + halfVesting);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        uint256 expectedReturned = (ONE_BTC * halfVesting) / VESTING_PERIOD;
        uint256 expectedForfeited = ONE_BTC - expectedReturned;

        assertEq(returned, expectedReturned, "Returned should be ~50%");
        assertEq(forfeited, expectedForfeited, "Forfeited should be ~50%");
        assertApproxEqAbs(returned, forfeited, 1, "Should be approximately 50/50 split");
    }

    function test_Strip_AfterPartialWithdrawals() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(alice);
            vault.withdraw(tokenId);
            _skipWithdrawalPeriod();
        }

        uint256 remainingCollateral = vault.collateralAmount(tokenId);

        uint256 stripped = _stripAll(alice, tokenId);

        assertEq(stripped, remainingCollateral);
        assertEq(vault.strippedReserve(tokenId), remainingCollateral);
        assertEq(btcToken.balanceOf(alice), remainingCollateral);
        assertEq(vault.collateralAmount(tokenId), 0);
    }

    function test_E2E_ThreeYearLifecycle() public {
        uint256 startTime = block.timestamp;

        uint256 aliceToken = _mintVault(alice, 0, 5 * ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, 3 * ONE_BTC);
        uint256 charlieToken = _mintVault(charlie, 200, 2 * ONE_BTC);

        assertEq(vault.totalActiveCollateral(), 10 * ONE_BTC);

        vm.warp(startTime + 500 days);

        vm.prank(charlie);
        (, uint256 charlieForfeited) = vault.earlyRedeem(charlieToken);
        assertGt(charlieForfeited, 0);

        assertEq(vault.matchPool(), charlieForfeited);

        vm.warp(startTime + VESTING_PERIOD + 1);

        assertTrue(vault.isVested(aliceToken));
        assertTrue(vault.isVested(bobToken));

        uint256 aliceTotalWithdrawn = 0;
        uint256 currentTime = block.timestamp;
        for (uint256 i = 0; i < 12; i++) {
            vm.prank(alice);
            uint256 withdrawn = vault.withdraw(aliceToken);
            aliceTotalWithdrawn += withdrawn;
            currentTime += WITHDRAWAL_PERIOD + 1 days;
            vm.warp(currentTime);
        }
        assertGt(aliceTotalWithdrawn, 0);

        vm.prank(bob);
        uint256 bobMatchClaimed = vault.claimMatch(bobToken);
        assertGt(bobMatchClaimed, 0);

        // Bob strips his full active collateral and sells the vBTC to alice
        uint256 bobStripped = _stripAll(bob, bobToken);
        assertGt(bobStripped, 0);

        vm.prank(bob);
        btcToken.transfer(alice, bobStripped);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1 days);

        (bool eligible,) = vault.isDormantEligible(bobToken);
        assertTrue(eligible);

        vm.prank(charlie);
        vault.pokeDormant(bobToken);

        vm.warp(block.timestamp + GRACE_PERIOD + 1 days);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);
        vm.prank(alice);
        uint256 dormantClaimed = vault.claimDormantCollateral(bobToken, bobStripped);

        assertEq(dormantClaimed, bobStripped);
        assertEq(wbtc.balanceOf(alice), aliceWbtcBefore + dormantClaimed);

        // Bob's vault persists with zero reserve; alice exits her fully vested vault
        assertEq(vault.ownerOf(bobToken), bob);
        assertEq(vault.strippedReserve(bobToken), 0);

        assertGt(vault.collateralAmount(aliceToken), 0);
        vm.prank(alice);
        (uint256 aliceReturned,) = vault.earlyRedeem(aliceToken);
        assertGt(aliceReturned, 0);
    }
}
