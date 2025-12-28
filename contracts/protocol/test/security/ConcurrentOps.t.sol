// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract ConcurrentOpsTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public charlie;
    address public dave;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;

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

        // Fund alice
        wbtc.mint(alice, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);

        vm.startPrank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function test_MultipleDelegatesWithdrawSamePeriod() public {
        // Alice mints vault with 10 BTC
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        // Grant 30% to Bob, 30% to Charlie (60% total, leaving 40% for owner)
        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 3000);
        vault.grantWithdrawalDelegate(tokenId, charlie, 3000);
        vm.stopPrank();

        assertEq(vault.totalDelegatedBPS(tokenId), 6000);

        // Skip to vested
        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 collateralBefore = vault.collateralAmount(tokenId);

        // Both delegates withdraw in same period
        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);

        vm.prank(charlie);
        uint256 charlieWithdrawn = vault.withdrawAsDelegate(tokenId);

        uint256 collateralAfter = vault.collateralAmount(tokenId);

        // Total withdrawn should equal collateral decrease
        assertEq(collateralBefore - collateralAfter, bobWithdrawn + charlieWithdrawn);

        // Each should get their proportional share
        // Both have 30% of 60% total delegated = equal shares
        // Allow small rounding difference
        assertApproxEqRel(bobWithdrawn, charlieWithdrawn, 0.01e18);
    }

    function test_OwnerAndDelegateWithdrawSamePeriod() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        // Grant 50% to Bob
        vm.prank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 5000);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 collateralBefore = vault.collateralAmount(tokenId);

        // Owner withdraws first
        vm.prank(alice);
        uint256 ownerWithdrawn = vault.withdraw(tokenId);

        // Then delegate withdraws
        vm.prank(bob);
        uint256 delegateWithdrawn = vault.withdrawAsDelegate(tokenId);

        uint256 collateralAfter = vault.collateralAmount(tokenId);

        // Both withdrawals should have reduced collateral
        assertEq(collateralBefore - collateralAfter, ownerWithdrawn + delegateWithdrawn);

        // Owner gets full withdrawal rate
        // Delegate gets 50% of remaining pool
        assertGt(ownerWithdrawn, 0);
        assertGt(delegateWithdrawn, 0);
    }

    function test_DelegateCannotWithdrawAfterRevocation() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        vm.prank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 5000);

        vm.warp(block.timestamp + VESTING_PERIOD);

        // Verify bob can withdraw
        (bool canWithdraw,) = vault.canDelegateWithdraw(tokenId, bob);
        assertTrue(canWithdraw);

        // Alice revokes
        vm.prank(alice);
        vault.revokeWithdrawalDelegate(tokenId, bob);

        // Bob can no longer withdraw
        (canWithdraw,) = vault.canDelegateWithdraw(tokenId, bob);
        assertFalse(canWithdraw);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotActiveDelegate.selector, tokenId, bob));
        vault.withdrawAsDelegate(tokenId);
    }

    function test_DelegationPersistsAfterTransfer() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        // Grant delegation to bob
        vm.prank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, 5000);

        // Transfer NFT to dave
        vm.prank(alice);
        vault.transferFrom(alice, dave, tokenId);

        // Check delegation state
        IVaultNFT.DelegatePermission memory permission = vault.getDelegatePermission(tokenId, bob);

        // Delegation still exists (by design for gas optimization)
        assertTrue(permission.active);
        assertEq(permission.percentageBPS, 5000);

        // Skip to vested
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Bob can still withdraw as delegate
        vm.prank(bob);
        uint256 withdrawn = vault.withdrawAsDelegate(tokenId);
        assertGt(withdrawn, 0);

        // Dave (new owner) can also withdraw
        vm.prank(dave);
        uint256 daveWithdrawn = vault.withdraw(tokenId);
        assertGt(daveWithdrawn, 0);
    }

    function test_MatchClaimWhileOthersActive() public {
        // Create two vaults - use different treasure token IDs
        vm.prank(alice);
        uint256 tokenId1 = vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC);

        wbtc.mint(bob, 100 * ONE_BTC);
        treasure.mintBatch(bob, 10); // Bob gets tokenIds 10-19
        vm.startPrank(bob);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        uint256 tokenId2 = vault.mint(address(treasure), 10, address(wbtc), 5 * ONE_BTC);
        vm.stopPrank();

        // Alice early redeems, funding match pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(alice);
        vault.earlyRedeem(tokenId1);

        uint256 matchPool = vault.matchPool();
        assertGt(matchPool, 0);

        // Bob's vault matures
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Bob claims match - should get at least some of the pool
        vm.prank(bob);
        uint256 claimed = vault.claimMatch(tokenId2);
        assertGt(claimed, 0);

        // Pool should have decreased
        assertLt(vault.matchPool(), matchPool);
    }

    function test_ConcurrentMatchClaims() public {
        // Create three vaults - each with different treasure tokenIds
        wbtc.mint(bob, 100 * ONE_BTC);
        wbtc.mint(charlie, 100 * ONE_BTC);
        treasure.mintBatch(bob, 10);     // Bob gets tokenIds 10-19
        treasure.mintBatch(charlie, 10); // Charlie gets tokenIds 20-29

        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        vm.startPrank(bob);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), 5 * ONE_BTC);
        vm.stopPrank();

        vm.startPrank(charlie);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        uint256 charlieToken = vault.mint(address(treasure), 20, address(wbtc), 5 * ONE_BTC);
        vm.stopPrank();

        // Alice early redeems at midpoint
        vm.warp(block.timestamp + 546 days);
        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);

        uint256 matchPoolBefore = vault.matchPool();
        assertEq(matchPoolBefore, forfeited);

        // Skip to vested
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Bob and Charlie both claim in same block
        vm.prank(bob);
        uint256 bobClaimed = vault.claimMatch(bobToken);

        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimMatch(charlieToken);

        // Both should have claimed something
        assertGt(bobClaimed, 0);
        assertGt(charlieClaimed, 0);

        // Total claimed should not exceed the pool
        // Note: Sequential claims are pro-rata against total collateral,
        // so total claimed may be less than pool due to distribution mechanics
        assertLe(bobClaimed + charlieClaimed, matchPoolBefore);

        // Pool should have decreased by total claimed
        assertEq(vault.matchPool(), matchPoolBefore - bobClaimed - charlieClaimed);
    }

    function test_DelegationLimitEnforced() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), 10 * ONE_BTC);

        vm.startPrank(alice);

        // Grant 60% to Bob
        vault.grantWithdrawalDelegate(tokenId, bob, 6000);

        // Grant 30% to Charlie
        vault.grantWithdrawalDelegate(tokenId, charlie, 3000);

        // Try to grant 20% to Dave (would exceed 100%)
        vm.expectRevert(IVaultNFT.ExceedsDelegationLimit.selector);
        vault.grantWithdrawalDelegate(tokenId, dave, 2000);

        // Can grant exactly 10% to Dave
        vault.grantWithdrawalDelegate(tokenId, dave, 1000);

        vm.stopPrank();

        assertEq(vault.totalDelegatedBPS(tokenId), 10000); // 100%
    }

    function testFuzz_ConcurrentDelegateWithdrawals(
        uint256 collateral,
        uint16 bobPercent,
        uint16 charliePercent
    ) public {
        collateral = bound(collateral, ONE_BTC, 100 * ONE_BTC);
        bobPercent = uint16(bound(bobPercent, 100, 4900)); // 1% to 49%
        charliePercent = uint16(bound(charliePercent, 100, 10000 - bobPercent - 100)); // Leave room for owner

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), collateral);

        vm.startPrank(alice);
        vault.grantWithdrawalDelegate(tokenId, bob, bobPercent);
        vault.grantWithdrawalDelegate(tokenId, charlie, charliePercent);
        vm.stopPrank();

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 collateralBefore = vault.collateralAmount(tokenId);

        vm.prank(bob);
        uint256 bobWithdrawn = vault.withdrawAsDelegate(tokenId);

        vm.prank(charlie);
        uint256 charlieWithdrawn = vault.withdrawAsDelegate(tokenId);

        uint256 collateralAfter = vault.collateralAmount(tokenId);

        // Conservation: withdrawn == collateral decrease
        assertEq(bobWithdrawn + charlieWithdrawn, collateralBefore - collateralAfter);

        // Proportionality: bob's share / charlie's share ≈ bobPercent / charliePercent
        // Allow 1% tolerance for rounding
        if (charlieWithdrawn > 0) {
            uint256 ratio = (bobWithdrawn * charliePercent) / charlieWithdrawn;
            assertApproxEqRel(ratio, bobPercent, 0.02e18);
        }
    }
}
