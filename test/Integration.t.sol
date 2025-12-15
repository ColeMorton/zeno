// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VaultNFT} from "../src/VaultNFT.sol";
import {BtcToken} from "../src/BtcToken.sol";
import {IVaultNFT} from "../src/interfaces/IVaultNFT.sol";
import {VaultMath} from "../src/libraries/VaultMath.sol";
import {MockTreasure} from "./mocks/MockTreasure.sol";
import {MockWBTC} from "./mocks/MockWBTC.sol";

contract IntegrationTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public charlie;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant VESTING_PERIOD = 1093 days;
    uint256 constant WITHDRAWAL_PERIOD = 30 days;
    uint256 constant DORMANCY_THRESHOLD = 1093 days;
    uint256 constant GRACE_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

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
        treasure.mintBatch(alice, 10);
        treasure.mintBatch(bob, 10);
        treasure.mintBatch(charlie, 10);

        _approveAll(alice);
        _approveAll(bob);
        _approveAll(charlie);
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function test_FullLifecycle_MintVestWithdrawSeparateRecombine() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        assertEq(vault.ownerOf(tokenId), alice);
        assertEq(vault.collateralAmount(tokenId), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);
        assertTrue(vault.isVested(tokenId));

        uint256 aliceBalanceBefore = wbtc.balanceOf(alice);
        vm.prank(alice);
        uint256 withdrawn1 = vault.withdraw(tokenId);
        assertGt(withdrawn1, 0);
        assertEq(wbtc.balanceOf(alice), aliceBalanceBefore + withdrawn1);

        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        vm.prank(alice);
        uint256 withdrawn2 = vault.withdraw(tokenId);
        assertGt(withdrawn2, 0);
        assertLt(withdrawn2, withdrawn1);

        vm.prank(alice);
        uint256 btcMinted = vault.mintBtcToken(tokenId);
        assertEq(btcToken.balanceOf(alice), btcMinted);
        assertEq(vault.btcTokenAmount(tokenId), btcMinted);

        vm.prank(alice);
        vault.returnBtcToken(tokenId);
        assertEq(btcToken.balanceOf(alice), 0);
        assertEq(vault.btcTokenAmount(tokenId), 0);

        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        vm.prank(alice);
        uint256 withdrawn3 = vault.withdraw(tokenId);
        assertGt(withdrawn3, 0);
    }

    function test_EarlyRedemptionFlow() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + 500 days);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertGt(returned, 0);
        assertGt(forfeited, 0);
        assertEq(returned + forfeited, ONE_BTC);
        assertEq(wbtc.balanceOf(alice), aliceWbtcBefore + returned);
        assertEq(vault.matchPool(), forfeited);

        vm.expectRevert();
        vault.ownerOf(tokenId);
    }

    function test_DormancyClaimFlow() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);
        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        assertEq(btcToken.balanceOf(alice), 0);
        assertEq(btcToken.balanceOf(bob), ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertTrue(eligible);

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        (, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.CLAIMABLE));

        uint256 bobWbtcBefore = wbtc.balanceOf(bob);

        vm.prank(bob);
        uint256 collateral = vault.claimDormantCollateral(tokenId);

        assertEq(collateral, ONE_BTC);
        assertEq(wbtc.balanceOf(bob), bobWbtcBefore + ONE_BTC);
        assertEq(btcToken.balanceOf(bob), 0);
        assertEq(treasure.ownerOf(0), alice);

        vm.expectRevert();
        vault.ownerOf(tokenId);
    }

    function test_MultiUserMatchPool() public {
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), 2 * ONE_BTC, 0);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC, 0);

        vm.prank(charlie);
        uint256 charlieToken = vault.mint(address(treasure), 20, address(wbtc), ONE_BTC, 0);

        assertEq(vault.totalActiveCollateral(), 4 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (, uint256 forfeited) = vault.earlyRedeem(aliceToken);
        assertGt(forfeited, 0);

        uint256 poolAfterAlice = vault.matchPool();
        assertEq(poolAfterAlice, forfeited);

        vm.warp(block.timestamp + VESTING_PERIOD);

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

        assertApproxEqAbs(bobClaimed, charlieClaimed, 1);
    }

    function test_WithdrawalTiers() public {
        vm.prank(alice);
        uint256 conservativeToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.prank(bob);
        uint256 balancedToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC, 1);

        vm.prank(charlie);
        uint256 aggressiveToken = vault.mint(address(treasure), 20, address(wbtc), ONE_BTC, 2);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        uint256 conservativeWithdraw = vault.withdraw(conservativeToken);

        vm.prank(bob);
        uint256 balancedWithdraw = vault.withdraw(balancedToken);

        vm.prank(charlie);
        uint256 aggressiveWithdraw = vault.withdraw(aggressiveToken);

        assertEq(conservativeWithdraw, (ONE_BTC * 833) / 10000);
        assertEq(balancedWithdraw, (ONE_BTC * 1140) / 10000);
        assertEq(aggressiveWithdraw, (ONE_BTC * 1590) / 10000);

        assertLt(conservativeWithdraw, balancedWithdraw);
        assertLt(balancedWithdraw, aggressiveWithdraw);
    }

    function test_CollateralNeverDepletes_ZenoParadox() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 2);

        vm.warp(block.timestamp + VESTING_PERIOD);

        for (uint256 i = 0; i < 100; i++) {
            uint256 remaining = vault.collateralAmount(tokenId);
            if (remaining == 0) break;

            vm.prank(alice);
            vault.withdraw(tokenId);

            vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        }

        uint256 finalRemaining = vault.collateralAmount(tokenId);
        assertGt(finalRemaining, 0);
    }

    function test_TransferUpdatesActivity_PreventsUnintendedDormancy() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD - 100 days);

        vm.prank(alice);
        vault.transferFrom(alice, bob, tokenId);

        vm.warp(block.timestamp + 200 days);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }

    function test_EarlyRedeem_WithSeparatedBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        assertEq(returned, ONE_BTC);
        assertEq(forfeited, 0);
        assertEq(wbtc.balanceOf(alice), aliceWbtcBefore + ONE_BTC);
        assertEq(btcToken.balanceOf(alice), 0);
    }

    function test_Invariant_TotalCollateralConsistency() public {
        vm.prank(alice);
        vault.mint(address(treasure), 0, address(wbtc), 2 * ONE_BTC, 0);

        vm.prank(bob);
        vault.mint(address(treasure), 10, address(wbtc), ONE_BTC, 0);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.withdraw(0);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);

        vm.prank(alice);
        vault.claimMatch(0);

        assertLt(vault.totalActiveCollateral(), 3 * ONE_BTC);
    }
}
