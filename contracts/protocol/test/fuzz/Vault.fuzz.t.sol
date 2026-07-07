// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "../utils/BaseTest.sol";

contract InvariantsTest is BaseTest {
    function testFuzz_Invariant_NoFreeMoney(
        uint256 depositAmount,
        uint256 withdrawCount
    ) public {
        depositAmount = bound(depositAmount, 1e6, 100 * ONE_BTC);
        withdrawCount = bound(withdrawCount, 0, 50);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);

        uint256 tokenId = _mintVault(alice, 0, depositAmount);

        _skipVesting();

        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < withdrawCount; i++) {
            vm.prank(alice);
            uint256 withdrawn = vault.withdraw(tokenId);
            totalWithdrawn += withdrawn;
            _skipWithdrawalPeriod();
        }

        uint256 remainingCollateral = vault.collateralAmount(tokenId);

        assertLe(
            totalWithdrawn + remainingCollateral,
            depositAmount,
            "Cannot withdraw more than deposited"
        );

        uint256 aliceWbtcAfter = wbtc.balanceOf(alice);
        uint256 aliceNetGain = aliceWbtcAfter - (aliceWbtcBefore - depositAmount);

        assertLe(aliceNetGain, depositAmount, "Net gain cannot exceed deposit");
    }

    function testFuzz_Invariant_CollateralAccounting(
        uint256 aliceDeposit,
        uint256 bobDeposit,
        uint256 charlieDeposit,
        uint256 aliceRedeemDay
    ) public {
        aliceDeposit = bound(aliceDeposit, ONE_BTC, 10 * ONE_BTC);
        bobDeposit = bound(bobDeposit, ONE_BTC, 10 * ONE_BTC);
        charlieDeposit = bound(charlieDeposit, ONE_BTC, 10 * ONE_BTC);
        aliceRedeemDay = bound(aliceRedeemDay, 1, 1092);

        uint256 aliceToken = _mintVault(alice, 0, aliceDeposit);
        uint256 bobToken = _mintVault(bob, 100, bobDeposit);
        uint256 charlieToken = _mintVault(charlie, 200, charlieDeposit);

        vm.warp(block.timestamp + aliceRedeemDay * 1 days);

        vm.prank(alice);
        (uint256 aliceReturned, uint256 aliceForfeited) = vault.earlyRedeem(aliceToken);

        uint256 vaultWbtcAfter = wbtc.balanceOf(address(vault));
        uint256 sumCollaterals = vault.collateralAmount(bobToken) + vault.collateralAmount(charlieToken);
        uint256 matchPoolBalance = vault.matchPool();

        assertEq(
            sumCollaterals + matchPoolBalance,
            vaultWbtcAfter,
            "Collateral accounting mismatch"
        );

        assertEq(
            aliceReturned + aliceForfeited,
            aliceDeposit,
            "Early redemption split incorrect"
        );
    }

    function testFuzz_Invariant_Zeno(uint256 withdrawalCount) public {
        withdrawalCount = bound(withdrawalCount, 100, 500);

        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        for (uint256 i = 0; i < withdrawalCount; i++) {
            uint256 remaining = vault.collateralAmount(tokenId);
            if (remaining == 0) break;

            vm.prank(alice);
            vault.withdraw(tokenId);

            _skipWithdrawalPeriod();
        }

        uint256 finalRemaining = vault.collateralAmount(tokenId);
        assertGt(finalRemaining, 0, "Collateral should never fully deplete (Zeno's paradox)");
    }

    function testFuzz_Invariant_MatchPoolBalance(
        uint256 deposit1,
        uint256 deposit2,
        uint256 redeemDay
    ) public {
        deposit1 = bound(deposit1, ONE_BTC, 50 * ONE_BTC);
        deposit2 = bound(deposit2, ONE_BTC, 50 * ONE_BTC);
        redeemDay = bound(redeemDay, 1, 1092);

        uint256 aliceToken = _mintVault(alice, 0, deposit1);
        uint256 bobToken = _mintVault(bob, 100, deposit2);

        assertEq(vault.matchPool(), 0, "Match pool should start at 0");

        vm.warp(block.timestamp + redeemDay * 1 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);

        assertEq(vault.matchPool(), forfeited, "Match pool should equal forfeited amount");

        uint256 poolBefore = vault.matchPool();
        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobToken);

        assertEq(vault.matchPool(), poolBefore - claimed, "Match pool should decrease by claimed");
        assertLe(claimed, poolBefore, "Cannot claim more than the pool");
    }

    function testFuzz_Invariant_StripReserveBacking(
        uint256 deposit,
        uint256 stripAmount,
        uint256 recombineAmount
    ) public {
        deposit = bound(deposit, ONE_BTC, 100 * ONE_BTC);
        stripAmount = bound(stripAmount, 1, deposit);

        uint256 tokenId = _mintVault(alice, 0, deposit);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, stripAmount);

        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply(), "Reserve must back supply 1:1");
        assertEq(
            wbtc.balanceOf(address(vault)),
            vault.totalActiveCollateral() + vault.totalStrippedReserve() + vault.matchPool(),
            "Vault balance must equal active + reserve + pool"
        );

        recombineAmount = bound(recombineAmount, 1, stripAmount);
        vm.prank(alice);
        vault.recombine(tokenId, recombineAmount);

        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply(), "Reserve must back supply 1:1");
        assertEq(vault.collateralAmount(tokenId) + vault.strippedReserve(tokenId), deposit);
        assertEq(
            wbtc.balanceOf(address(vault)),
            vault.totalActiveCollateral() + vault.totalStrippedReserve() + vault.matchPool(),
            "Vault balance must equal active + reserve + pool"
        );
    }

    function test_Invariant_TotalActiveCollateral_TracksCorrectly() public {
        uint256 aliceToken = _mintVault(alice, 0, 2 * ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, 3 * ONE_BTC);

        assertEq(vault.totalActiveCollateral(), 5 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);

        // Settlement moves pool collateral into the active total
        vm.prank(bob);
        uint256 bobClaimed = vault.claimMatch(bobToken);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC + bobClaimed);
        assertEq(vault.collateralAmount(bobToken), 3 * ONE_BTC + bobClaimed);
    }
}
