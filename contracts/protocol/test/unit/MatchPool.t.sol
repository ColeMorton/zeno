// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract MatchPoolTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public charlie;
    address public dave;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant VESTING_PERIOD = 1129 days;
    uint256 constant WITHDRAWAL_PERIOD = 30 days;

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

        wbtc.mint(alice, 100 * ONE_BTC);
        wbtc.mint(bob, 100 * ONE_BTC);
        wbtc.mint(charlie, 100 * ONE_BTC);
        wbtc.mint(dave, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);
        treasure.mintBatch(bob, 10);
        treasure.mintBatch(charlie, 10);
        treasure.mintBatch(dave, 10);

        _approveAll(alice);
        _approveAll(bob);
        _approveAll(charlie);
        _approveAll(dave);
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function test_MatchPool_ClaimOrderFairness() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), 2 * ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        vm.prank(charlie);
        uint256 charlieToken = vault.mint(address(treasure), 20, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 bobClaimedFirst;
        uint256 charlieClaimedFirst;

        uint256 snapshotId = vm.snapshotState();

        vm.prank(bob);
        bobClaimedFirst = vault.claimMatch(bobToken);

        vm.prank(charlie);
        charlieClaimedFirst = vault.claimMatch(charlieToken);

        vm.revertToState(snapshotId);

        vm.prank(charlie);
        uint256 charlieClaimedSecond = vault.claimMatch(charlieToken);

        vm.prank(bob);
        uint256 bobClaimedSecond = vault.claimMatch(bobToken);

        assertEq(bobClaimedFirst + charlieClaimedFirst, bobClaimedSecond + charlieClaimedSecond, "Total claimed should be same");
        assertGt(bobClaimedFirst, 0, "Bob should get some match");
        assertGt(charlieClaimedFirst, 0, "Charlie should get some match");
    }

    function test_MatchPool_MultipleRedemptions() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        vm.prank(charlie);
        uint256 charlieToken = vault.mint(address(treasure), 20, address(wbtc), 2 * ONE_BTC);

        vm.prank(dave);
        uint256 daveToken = vault.mint(address(treasure), 30, address(wbtc), ONE_BTC);

        assertEq(vault.matchPool(), 0);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        (, uint256 aliceForfeited) = vault.earlyRedeem(aliceToken);

        assertEq(vault.matchPool(), aliceForfeited);

        vm.warp(block.timestamp + 182 days);

        vm.prank(bob);
        (, uint256 bobForfeited) = vault.earlyRedeem(bobToken);

        assertEq(vault.matchPool(), aliceForfeited + bobForfeited);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 poolBeforeClaims = vault.matchPool();

        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        vm.prank(dave);
        uint256 daveClaimed = vault.claimMatch(daveToken);

        assertLe(
            charlieClaimed + daveClaimed,
            poolBeforeClaims,
            "Total claims should not exceed pool"
        );
        assertGt(charlieClaimed, daveClaimed, "Charlie (2 BTC) should get more than Dave (1 BTC)");
    }

    function test_MatchPool_LateJoiner() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        (, uint256 forfeited1) = vault.earlyRedeem(aliceToken);

        vm.prank(charlie);
        uint256 charlieToken = vault.mint(address(treasure), 20, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(bob);
        (, uint256 forfeited2) = vault.earlyRedeem(bobToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        assertGt(charlieClaimed, 0, "Late joiner should still get match pool share");
    }

    function test_MatchPool_AfterWithdrawals_IncreasedCollateral() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), 2 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 bobCollateralBefore = vault.collateralAmount(bobToken);

        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobToken);

        uint256 bobCollateralAfter = vault.collateralAmount(bobToken);
        assertEq(bobCollateralAfter, bobCollateralBefore + claimed);

        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        uint256 expectedWithdrawal = (bobCollateralAfter * 1000) / 100000;

        vm.prank(bob);
        uint256 withdrawn = vault.withdraw(bobToken);

        assertEq(withdrawn, expectedWithdrawal, "Withdrawal should be based on increased collateral");
    }

    function test_MatchPool_ProRataDistribution() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), 3 * ONE_BTC);

        vm.prank(charlie);
        uint256 charlieToken = vault.mint(address(treasure), 20, address(wbtc), 2 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(bob);
        uint256 bobClaimed = vault.claimMatch(bobToken);

        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        assertGt(bobClaimed, charlieClaimed, "Bob (3 BTC) should claim more than Charlie (2 BTC)");
        assertGt(bobClaimed, 0, "Bob should get some match");
        assertGt(charlieClaimed, 0, "Charlie should get some match");
    }

    function test_MatchPool_EmptyPool_RevertOnClaim() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vm.expectRevert(IVaultNFT.NoPoolAvailable.selector);
        vault.claimMatch(aliceToken);
    }

    function test_MatchPool_FullDrain() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        uint256 poolAmount = vault.matchPool();
        assertGt(poolAmount, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobToken);

        assertGt(claimed, 0, "Claimer should get portion of pool");
        assertLe(claimed, poolAmount, "Claimed should not exceed pool");
        assertLe(vault.matchPool(), poolAmount, "Pool should decrease or stay same");
    }

    function test_MatchPool_MaturesFlagOnClaim() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        assertEq(vault.totalActiveCollateral(), 2 * ONE_BTC);
        assertFalse(vault.matured(bobToken));

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        assertEq(vault.totalActiveCollateral(), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(bob);
        vault.claimMatch(bobToken);

        assertTrue(vault.matured(bobToken));
        assertEq(vault.totalActiveCollateral(), 0);
    }

    function test_MatchPool_ClaimDoesNotAffectBtcToken() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(bob);
        vault.mintBtcToken(bobToken);

        uint256 originalMinted = vault.originalMintedAmount(bobToken);

        vm.prank(bob);
        vault.claimMatch(bobToken);

        assertEq(vault.originalMintedAmount(bobToken), originalMinted, "originalMintedAmount unchanged");
        assertEq(vault.btcTokenAmount(bobToken), originalMinted, "btcTokenAmount unchanged");
    }
}
