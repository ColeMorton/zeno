// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "../utils/BaseTest.sol";

contract MatchPoolTest is BaseTest {
    address public dave;

    function setUp() public override {
        super.setUp();
        dave = makeAddr("dave");
        _fundUser(dave, 1000); // treasures 300-399
    }

    function test_MatchPool_SettlementOrderIndependent() public {
        uint256 aliceToken = _mintVault(alice, 0, 2 * ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);
        uint256 charlieToken = _mintVault(charlie, 200, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);
        assertGt(forfeited, 0);

        uint256 snapshotId = vm.snapshotState();

        vm.prank(bob);
        uint256 bobClaimedFirst = vault.claimMatch(bobToken);
        vm.prank(charlie);
        uint256 charlieClaimedSecond = vault.claimMatch(charlieToken);

        vm.revertToState(snapshotId);

        vm.prank(charlie);
        uint256 charlieClaimedFirst = vault.claimMatch(charlieToken);
        vm.prank(bob);
        uint256 bobClaimedSecond = vault.claimMatch(bobToken);

        // Accumulator accounting: each vault gets exactly the same amount in either order
        assertEq(bobClaimedFirst, bobClaimedSecond, "Bob's settlement must be order-independent");
        assertEq(
            charlieClaimedFirst,
            charlieClaimedSecond,
            "Charlie's settlement must be order-independent"
        );
        assertGt(bobClaimedFirst, 0, "Bob should get some match");
        assertGt(charlieClaimedFirst, 0, "Charlie should get some match");

        // Equal collateral => equal shares
        assertEq(bobClaimedFirst, charlieClaimedFirst, "Equal collateral gets equal shares");
    }

    function test_MatchPool_MultipleRedemptions() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);
        uint256 charlieToken = _mintVault(charlie, 200, 2 * ONE_BTC);
        uint256 daveToken = _mintVault(dave, 300, ONE_BTC);

        assertEq(vault.matchPool(), 0);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        (, uint256 aliceForfeited) = vault.earlyRedeem(aliceToken);

        assertEq(vault.matchPool(), aliceForfeited);

        vm.warp(block.timestamp + 182 days);

        vm.prank(bob);
        (, uint256 bobForfeited) = vault.earlyRedeem(bobToken);

        // Bob's redemption settles his own pending share first, reducing the pool,
        // then his forfeiture accrues on top.
        assertLe(vault.matchPool(), aliceForfeited + bobForfeited);

        uint256 poolBeforeClaims = vault.matchPool();

        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        vm.prank(dave);
        uint256 daveClaimed = vault.claimMatch(daveToken);

        assertLe(charlieClaimed + daveClaimed, poolBeforeClaims, "Total claims cannot exceed pool");
        assertGt(charlieClaimed, daveClaimed, "Charlie (2 BTC) should get more than Dave (1 BTC)");
    }

    function test_MatchPool_LateJoiner_ExcludedFromPriorForfeits() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        // Charlie joins after the first forfeiture: nothing pending for him
        uint256 charlieToken = _mintVault(charlie, 200, ONE_BTC);
        assertEq(vault.pendingMatch(charlieToken), 0);

        vm.warp(block.timestamp + 365 days);

        vm.prank(bob);
        vault.earlyRedeem(bobToken);

        // Charlie participates in the second forfeiture
        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        assertGt(charlieClaimed, 0, "Late joiner shares in forfeits after joining");
    }

    function test_MatchPool_AfterClaim_IncreasedWithdrawalBase() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, 2 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        _skipVesting();

        uint256 bobCollateralBefore = vault.collateralAmount(bobToken);

        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobToken);

        uint256 bobCollateralAfter = vault.collateralAmount(bobToken);
        assertEq(bobCollateralAfter, bobCollateralBefore + claimed);

        uint256 expectedWithdrawal = (bobCollateralAfter * 1000) / 100000;

        vm.prank(bob);
        uint256 withdrawn = vault.withdraw(bobToken);

        assertEq(withdrawn, expectedWithdrawal, "Withdrawal based on settled collateral");
    }

    function test_MatchPool_ProRataDistribution() public {
        uint256 aliceToken = _mintVault(alice, 0, 5 * ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, 3 * ONE_BTC);
        uint256 charlieToken = _mintVault(charlie, 200, 2 * ONE_BTC);
        aliceToken; // silence unused warning path

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        vm.prank(bob);
        uint256 bobClaimed = vault.claimMatch(bobToken);

        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        assertGt(bobClaimed, 0);
        assertGt(charlieClaimed, 0);
        // 3:2 collateral ratio => 3:2 match ratio (floor rounding tolerance of 1)
        assertApproxEqAbs(bobClaimed * 2, charlieClaimed * 3, 3);
    }

    function test_MatchPool_EmptyPool_ClaimReturnsZero() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);

        vm.prank(alice);
        uint256 claimed = vault.claimMatch(aliceToken);

        assertEq(claimed, 0, "No pool: settlement is a no-op, never a revert");
    }

    function test_MatchPool_AutomaticSettlementOnWithdraw() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        uint256 pending = vault.pendingMatch(bobToken);
        assertGt(pending, 0);

        _skipVesting();

        vm.prank(bob);
        uint256 withdrawn = vault.withdraw(bobToken);

        // Withdraw settled the pending match first: 1% of (collateral + pending)
        assertEq(withdrawn, ((ONE_BTC + pending) * 1000) / 100000);
        assertEq(vault.pendingMatch(bobToken), 0);
    }

    function test_MatchPool_AutomaticSettlementOnStrip() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        uint256 pending = vault.pendingMatch(bobToken);
        assertGt(pending, 0);

        _skipVesting();

        vm.prank(bob);
        vault.strip(bobToken, ONE_BTC);

        // Settlement happened before the strip; pending share stays active
        assertEq(vault.collateralAmount(bobToken), pending);
        assertEq(vault.strippedReserve(bobToken), ONE_BTC);
        assertEq(vault.pendingMatch(bobToken), 0);
    }

    function test_MatchPool_ConservationAcrossFullDrain() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);
        uint256 charlieToken = _mintVault(charlie, 200, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);

        vm.prank(bob);
        uint256 bobClaimed = vault.claimMatch(bobToken);
        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        assertLe(bobClaimed + charlieClaimed, forfeited, "Settled total cannot exceed forfeited");
        assertEq(vault.matchPool(), forfeited - bobClaimed - charlieClaimed);
    }

    function test_MatchPool_PendingMatchView() public {
        uint256 aliceToken = _mintVault(alice, 0, ONE_BTC);
        uint256 bobToken = _mintVault(bob, 100, ONE_BTC);
        uint256 charlieToken = _mintVault(charlie, 200, ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);

        // Two equal vaults remain: each is pending half (floor)
        uint256 bobPending = vault.pendingMatch(bobToken);
        uint256 charliePending = vault.pendingMatch(charlieToken);
        assertEq(bobPending, charliePending);
        assertApproxEqAbs(bobPending, forfeited / 2, 1);

        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobToken);
        assertEq(claimed, bobPending, "claimMatch settles exactly the pending amount");
    }
}
