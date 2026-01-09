// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {IVaultNFTDormancy} from "../../src/interfaces/IVaultNFTDormancy.sol";
import {VaultMath} from "../../src/libraries/VaultMath.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract VaultNFTTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant VESTING_PERIOD = 1129 days;
    uint256 constant WITHDRAWAL_PERIOD = 30 days;
    uint256 constant DORMANCY_THRESHOLD = 1129 days;
    uint256 constant GRACE_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        wbtc.mint(alice, 100 * ONE_BTC);
        wbtc.mint(bob, 100 * ONE_BTC);
        treasure.mintBatch(alice, 10);
        treasure.mintBatch(bob, 10);

        vm.startPrank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();

        vm.startPrank(bob);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function test_Mint() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        assertEq(tokenId, 0);
        assertEq(vault.ownerOf(tokenId), alice);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC);
        assertEq(vault.totalActiveCollateral(), ONE_BTC);
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

    function test_Withdraw_AfterVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 expectedWithdrawal = (ONE_BTC * 1000) / 100000;
        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        assertEq(withdrawn, expectedWithdrawal);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore + expectedWithdrawal);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC - expectedWithdrawal);
    }

    function test_Withdraw_RevertIf_StillVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.withdraw(tokenId);
    }

    function test_Withdraw_RevertIf_TooSoon() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.withdraw(tokenId);

        vm.warp(block.timestamp + 15 days);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(tokenId);
    }

    function test_Withdraw_MultipleWithdrawals() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 remainingCollateral = ONE_BTC;

        for (uint256 i = 0; i < 3; i++) {
            uint256 expectedWithdrawal = (remainingCollateral * 1000) / 100000;

            vm.prank(alice);
            uint256 withdrawn = vault.withdraw(tokenId);

            assertEq(withdrawn, expectedWithdrawal);
            remainingCollateral -= expectedWithdrawal;

            vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        }

        assertEq(vault.collateralAmount(tokenId), remainingCollateral);
    }

    function test_EarlyRedeem() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

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
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertEq(returned, 0);
        assertEq(forfeited, ONE_BTC);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore);
    }

    function test_EarlyRedeem_AfterFullVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertEq(returned, ONE_BTC);
        assertEq(forfeited, 0);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore + ONE_BTC);
    }

    function test_MintBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        uint256 amount = vault.mintBtcToken(tokenId);

        assertEq(amount, ONE_BTC);
        assertEq(btcToken.balanceOf(alice), ONE_BTC);
        assertEq(vault.btcTokenAmount(tokenId), ONE_BTC);
        assertEq(vault.originalMintedAmount(tokenId), ONE_BTC);
    }

    function test_MintBtcToken_RevertIf_NotVested() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.mintBtcToken(tokenId);
    }

    function test_MintBtcToken_RevertIf_AlreadyMinted() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.BtcTokenAlreadyMinted.selector, tokenId));
        vault.mintBtcToken(tokenId);
    }

    function test_ReturnBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        vault.returnBtcToken(tokenId);

        assertEq(btcToken.balanceOf(alice), 0);
        assertEq(vault.btcTokenAmount(tokenId), 0);
        assertEq(vault.originalMintedAmount(tokenId), 0);
    }

    function test_ReturnBtcToken_RevertIf_NoBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.BtcTokenRequired.selector, tokenId));
        vault.returnBtcToken(tokenId);
    }

    function test_EarlyRedeem_WithBtcToken_RequiresFull() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, ONE_BTC / 2)
        );
        vault.earlyRedeem(tokenId);
    }

    function test_ClaimMatch() public {
        vm.prank(alice);
        uint256 aliceTokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobTokenId = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(aliceTokenId);

        assertGt(forfeited, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 bobCollateralBefore = vault.collateralAmount(bobTokenId);

        vm.prank(bob);
        uint256 claimed = vault.claimMatch(bobTokenId);

        assertGt(claimed, 0);
        assertEq(vault.collateralAmount(bobTokenId), bobCollateralBefore + claimed);
    }

    function test_ClaimMatch_RevertIf_NotVested() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotVested.selector, tokenId));
        vault.claimMatch(tokenId);
    }

    function test_ClaimMatch_RevertIf_AlreadyClaimed() public {
        vm.prank(alice);
        uint256 aliceTokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.prank(bob);
        uint256 bobTokenId = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        vault.earlyRedeem(aliceTokenId);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(bob);
        vault.claimMatch(bobTokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.AlreadyClaimed.selector, bobTokenId));
        vault.claimMatch(bobTokenId);
    }

    function test_Dormancy_FullFlow() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        (bool eligible, IVaultNFTDormancy.DormancyState state) = vault.isDormantEligible(tokenId);
        assertTrue(eligible);
        assertEq(uint256(state), uint256(IVaultNFTDormancy.DormancyState.ACTIVE));

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        (, state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFTDormancy.DormancyState.POKE_PENDING));

        vm.warp(block.timestamp + GRACE_PERIOD);

        (, state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFTDormancy.DormancyState.CLAIMABLE));

        uint256 bobWbtcBefore = wbtc.balanceOf(bob);

        vm.prank(bob);
        uint256 collateral = vault.claimDormantCollateral(tokenId);

        assertEq(collateral, ONE_BTC);
        assertEq(wbtc.balanceOf(bob), bobWbtcBefore + ONE_BTC);
        assertEq(btcToken.balanceOf(bob), 0);
        assertEq(treasure.ownerOf(0), address(0xdead));
    }

    function test_Dormancy_ProveActivity() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        vm.prank(alice);
        vault.proveActivity(tokenId);

        (bool eligible, IVaultNFTDormancy.DormancyState state) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(state), uint256(IVaultNFTDormancy.DormancyState.ACTIVE));
    }

    function test_Dormancy_NotEligible_OwnerHoldsBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }

    function test_Dormancy_NotEligible_NoBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD + DORMANCY_THRESHOLD);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }

    function test_IsVested() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        assertFalse(vault.isVested(tokenId));

        vm.warp(block.timestamp + VESTING_PERIOD - 1);
        assertFalse(vault.isVested(tokenId));

        vm.warp(block.timestamp + 1);
        assertTrue(vault.isVested(tokenId));
    }

    function test_GetWithdrawableAmount() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        assertEq(vault.getWithdrawableAmount(tokenId), 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 expected = (ONE_BTC * 1000) / 100000;
        assertEq(vault.getWithdrawableAmount(tokenId), expected);

        vm.prank(alice);
        vault.withdraw(tokenId);

        assertEq(vault.getWithdrawableAmount(tokenId), 0);

        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        uint256 remaining = ONE_BTC - expected;
        uint256 nextExpected = (remaining * 1000) / 100000;
        assertEq(vault.getWithdrawableAmount(tokenId), nextExpected);
    }

    function test_Transfer_UpdatesActivity() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        uint256 initialActivity = vault.lastActivity(tokenId);

        vm.warp(block.timestamp + 100 days);

        vm.prank(alice);
        vault.transferFrom(alice, bob, tokenId);

        assertGt(vault.lastActivity(tokenId), initialActivity);
        assertEq(vault.ownerOf(tokenId), bob);
    }

    function testFuzz_Withdraw(uint256 collateral) public {
        collateral = bound(collateral, ONE_BTC / 100, 100 * ONE_BTC);

        vm.startPrank(alice);
        wbtc.mint(alice, collateral);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), collateral);
        vm.stopPrank();

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        uint256 expected = (collateral * 1000) / 100000;
        assertEq(withdrawn, expected);
    }

    function testFuzz_EarlyRedeem_LinearUnlock(uint256 daysHeld) public {
        daysHeld = bound(daysHeld, 0, 1129);

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + daysHeld * 1 days);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        uint256 expectedReturned = (ONE_BTC * daysHeld * 1 days) / VESTING_PERIOD;
        uint256 expectedForfeited = ONE_BTC - expectedReturned;

        assertEq(returned, expectedReturned);
        assertEq(forfeited, expectedForfeited);
        assertEq(returned + forfeited, ONE_BTC);
    }

    function test_GetCollateralClaim_NoBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        assertEq(vault.getCollateralClaim(tokenId), 0);
    }

    function test_GetCollateralClaim_WithBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        assertEq(vault.getCollateralClaim(tokenId), ONE_BTC);
    }

    function test_GetClaimValue() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        assertEq(vault.getClaimValue(alice, tokenId), ONE_BTC);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        assertEq(vault.getClaimValue(alice, tokenId), ONE_BTC / 2);
        assertEq(vault.getClaimValue(bob, tokenId), ONE_BTC / 2);
    }
}
