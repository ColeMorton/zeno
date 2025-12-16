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
        vault = new VaultNFT(address(btcToken), acceptedTokens, 0);

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
        assertEq(treasure.ownerOf(0), address(0xdead));

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

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

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

        assertGt(bobClaimed, 0);
        assertGt(charlieClaimed, 0);
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

        assertEq(conservativeWithdraw, (ONE_BTC * 833) / 100000);
        assertEq(balancedWithdraw, (ONE_BTC * 1140) / 100000);
        assertEq(aggressiveWithdraw, (ONE_BTC * 1590) / 100000);

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
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), 2 * ONE_BTC, 0);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC, 0);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.withdraw(aliceToken);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);

        vm.prank(bob);
        vault.withdraw(bobToken);

        assertEq(vault.totalActiveCollateral(), 3 * ONE_BTC);
    }

    function test_VestingExactBoundary() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

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
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

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
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

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

    function test_BtcToken_ClaimValueAfterWithdrawals() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        assertEq(vault.getClaimValue(alice, tokenId), ONE_BTC);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        uint256 remainingCollateral = ONE_BTC - withdrawn;
        assertEq(vault.getClaimValue(alice, tokenId), remainingCollateral);

        vm.warp(block.timestamp + WITHDRAWAL_PERIOD);

        vm.prank(alice);
        uint256 withdrawn2 = vault.withdraw(tokenId);

        remainingCollateral -= withdrawn2;
        assertEq(vault.getClaimValue(alice, tokenId), remainingCollateral);
    }

    function test_BtcToken_MultipleHolders() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 4);

        vm.prank(alice);
        btcToken.transfer(charlie, ONE_BTC / 4);

        assertEq(vault.getClaimValue(alice, tokenId), ONE_BTC / 2);
        assertEq(vault.getClaimValue(bob, tokenId), ONE_BTC / 4);
        assertEq(vault.getClaimValue(charlie, tokenId), ONE_BTC / 4);

        vm.prank(alice);
        vault.withdraw(tokenId);

        uint256 remaining = vault.collateralAmount(tokenId);

        assertEq(vault.getClaimValue(alice, tokenId), remaining / 2);
        assertEq(vault.getClaimValue(bob, tokenId), remaining / 4);
        assertEq(vault.getClaimValue(charlie, tokenId), remaining / 4);
    }

    function test_BtcToken_MintAfterPartialWithdraw() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        uint256 currentTime = block.timestamp + VESTING_PERIOD;
        vm.warp(currentTime);

        vm.prank(alice);
        vault.withdraw(tokenId);

        currentTime += WITHDRAWAL_PERIOD;
        vm.warp(currentTime);

        vm.prank(alice);
        vault.withdraw(tokenId);

        currentTime += WITHDRAWAL_PERIOD;
        vm.warp(currentTime);

        vm.prank(alice);
        vault.withdraw(tokenId);

        uint256 remainingCollateral = vault.collateralAmount(tokenId);

        vm.prank(alice);
        uint256 btcMinted = vault.mintBtcToken(tokenId);

        assertEq(btcMinted, remainingCollateral);
        assertEq(vault.btcTokenAmount(tokenId), remainingCollateral);
        assertEq(vault.originalMintedAmount(tokenId), remainingCollateral);
        assertEq(btcToken.balanceOf(alice), remainingCollateral);
    }

    function test_E2E_ThreeYearLifecycle() public {
        uint256 startTime = block.timestamp;

        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), 5 * ONE_BTC, 0);

        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), 3 * ONE_BTC, 1);

        vm.prank(charlie);
        uint256 charlieToken = vault.mint(address(treasure), 20, address(wbtc), 2 * ONE_BTC, 2);

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

        vm.prank(bob);
        vault.mintBtcToken(bobToken);

        uint256 bobBtcTokenBalance = btcToken.balanceOf(bob);

        vm.prank(bob);
        btcToken.transfer(alice, bobBtcTokenBalance);

        currentTime = block.timestamp + DORMANCY_THRESHOLD + 1 days;
        vm.warp(currentTime);

        (bool eligible,) = vault.isDormantEligible(bobToken);
        assertTrue(eligible);

        vm.prank(charlie);
        vault.pokeDormant(bobToken);

        vm.warp(block.timestamp + GRACE_PERIOD + 1 days);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);
        vm.startPrank(alice);
        btcToken.approve(address(vault), type(uint256).max);
        uint256 dormantCollateral = vault.claimDormantCollateral(bobToken);
        vm.stopPrank();

        assertEq(wbtc.balanceOf(alice), aliceWbtcBefore + dormantCollateral);

        assertGt(vault.collateralAmount(aliceToken), 0);
        vm.prank(alice);
        (uint256 aliceReturned,) = vault.earlyRedeem(aliceToken);
        assertGt(aliceReturned, 0);
    }
}
