// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HybridVaultNFT} from "../../src/HybridVaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IHybridVaultNFT} from "../../src/interfaces/IHybridVaultNFT.sol";
import {VaultMath} from "../../src/libraries/VaultMath.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

contract HybridVaultNFTTest is Test {
    HybridVaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public primaryToken; // cbBTC
    MockWBTC public secondaryToken; // LP token

    address public alice;
    address public bob;

    uint256 constant ONE_BTC = 1e8;
    uint256 constant ONE_LP = 1e18;
    uint256 constant VESTING_PERIOD = 1129 days;
    uint256 constant WITHDRAWAL_PERIOD = 30 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        treasure = new MockTreasure();
        primaryToken = new MockWBTC();
        secondaryToken = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-cbBTC", "vcbBTC");
        vault = new HybridVaultNFT(
            address(btcToken),
            address(primaryToken),
            address(secondaryToken),
            "Hybrid Vault NFT",
            "HVAULT"
        );

        primaryToken.mint(alice, 100 * ONE_BTC);
        primaryToken.mint(bob, 100 * ONE_BTC);
        secondaryToken.mint(alice, 100 * ONE_LP);
        secondaryToken.mint(bob, 100 * ONE_LP);
        treasure.mintBatch(alice, 10);
        treasure.mintBatch(bob, 10);

        vm.startPrank(alice);
        primaryToken.approve(address(vault), type(uint256).max);
        secondaryToken.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();

        vm.startPrank(bob);
        primaryToken.approve(address(vault), type(uint256).max);
        secondaryToken.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    // ========== Mint Tests ==========

    function test_Mint() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 7 * ONE_BTC, 3 * ONE_LP);

        assertEq(tokenId, 0);
        assertEq(vault.ownerOf(tokenId), alice);
        assertEq(vault.primaryAmount(tokenId), 7 * ONE_BTC);
        assertEq(vault.secondaryAmount(tokenId), 3 * ONE_LP);
        assertEq(vault.totalActivePrimary(), 7 * ONE_BTC);
        assertEq(vault.totalActiveSecondary(), 3 * ONE_LP);
    }

    function test_Mint_RevertIf_ZeroPrimaryCollateral() public {
        vm.prank(alice);
        vm.expectRevert(IHybridVaultNFT.ZeroPrimaryCollateral.selector);
        vault.mint(address(treasure), 0, 0, ONE_LP);
    }

    function test_Mint_RevertIf_ZeroSecondaryCollateral() public {
        vm.prank(alice);
        vm.expectRevert(IHybridVaultNFT.ZeroSecondaryCollateral.selector);
        vault.mint(address(treasure), 0, ONE_BTC, 0);
    }

    // ========== Primary Withdrawal Tests ==========

    function test_WithdrawPrimary_AfterVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 10 * ONE_BTC, ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 expectedWithdrawal = (10 * ONE_BTC * 1000) / 100000; // 1%
        uint256 aliceBalanceBefore = primaryToken.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = vault.withdrawPrimary(tokenId);

        assertEq(withdrawn, expectedWithdrawal);
        assertEq(primaryToken.balanceOf(alice), aliceBalanceBefore + expectedWithdrawal);
        assertEq(vault.primaryAmount(tokenId), 10 * ONE_BTC - expectedWithdrawal);
    }

    function test_WithdrawPrimary_RevertIf_StillVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, ONE_LP);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IHybridVaultNFT.StillVesting.selector, tokenId));
        vault.withdrawPrimary(tokenId);
    }

    function test_WithdrawPrimary_RevertIf_TooSoon() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.withdrawPrimary(tokenId);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdrawPrimary(tokenId);
    }

    function test_WithdrawPrimary_MultipleWithdrawals() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 10 * ONE_BTC, ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 totalWithdrawn = 0;
        uint256 currentPrimary = 10 * ONE_BTC;

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(alice);
            uint256 withdrawn = vault.withdrawPrimary(tokenId);
            totalWithdrawn += withdrawn;
            currentPrimary -= withdrawn;

            assertEq(vault.primaryAmount(tokenId), currentPrimary);
            vm.warp(block.timestamp + WITHDRAWAL_PERIOD);
        }

        assertTrue(totalWithdrawn > 0);
        assertTrue(vault.primaryAmount(tokenId) < 10 * ONE_BTC);
    }

    // ========== Secondary Withdrawal Tests ==========

    function test_WithdrawSecondary_AfterVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, 5 * ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 aliceBalanceBefore = secondaryToken.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = vault.withdrawSecondary(tokenId);

        assertEq(withdrawn, 5 * ONE_LP);
        assertEq(secondaryToken.balanceOf(alice), aliceBalanceBefore + 5 * ONE_LP);
        assertEq(vault.secondaryAmount(tokenId), 0);
        assertTrue(vault.secondaryWithdrawn(tokenId));
    }

    function test_WithdrawSecondary_RevertIf_StillVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, ONE_LP);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IHybridVaultNFT.StillVesting.selector, tokenId));
        vault.withdrawSecondary(tokenId);
    }

    function test_WithdrawSecondary_RevertIf_AlreadyWithdrawn() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.withdrawSecondary(tokenId);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IHybridVaultNFT.SecondaryAlreadyWithdrawn.selector, tokenId));
        vault.withdrawSecondary(tokenId);
    }

    // ========== Early Redemption Tests ==========

    function test_EarlyRedeem_AtHalfVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 10 * ONE_BTC, 10 * ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD / 2);

        uint256 alicePrimaryBefore = primaryToken.balanceOf(alice);
        uint256 aliceSecondaryBefore = secondaryToken.balanceOf(alice);

        vm.prank(alice);
        (
            uint256 primaryReturned,
            uint256 primaryForfeited,
            uint256 secondaryReturned,
            uint256 secondaryForfeited
        ) = vault.earlyRedeem(tokenId);

        // ~50% returned, ~50% forfeited
        assertTrue(primaryReturned > 0);
        assertTrue(primaryForfeited > 0);
        assertTrue(secondaryReturned > 0);
        assertTrue(secondaryForfeited > 0);

        assertEq(primaryToken.balanceOf(alice), alicePrimaryBefore + primaryReturned);
        assertEq(secondaryToken.balanceOf(alice), aliceSecondaryBefore + secondaryReturned);

        // Match pools should be funded
        assertEq(vault.primaryMatchPool(), primaryForfeited);
        assertEq(vault.secondaryMatchPool(), secondaryForfeited);

        // Vault should be burned
        vm.expectRevert();
        vault.ownerOf(tokenId);
    }

    function test_EarlyRedeem_AtDayZero() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 10 * ONE_BTC, 10 * ONE_LP);

        vm.prank(alice);
        (
            uint256 primaryReturned,
            uint256 primaryForfeited,
            uint256 secondaryReturned,
            uint256 secondaryForfeited
        ) = vault.earlyRedeem(tokenId);

        // All forfeited at day 0
        assertEq(primaryReturned, 0);
        assertEq(primaryForfeited, 10 * ONE_BTC);
        assertEq(secondaryReturned, 0);
        assertEq(secondaryForfeited, 10 * ONE_LP);
    }

    // ========== vestedBTC Separation Tests ==========

    function test_MintBtcToken_AfterVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 5 * ONE_BTC, ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        uint256 minted = vault.mintBtcToken(tokenId);

        assertEq(minted, 5 * ONE_BTC);
        assertEq(btcToken.balanceOf(alice), 5 * ONE_BTC);
    }

    function test_MintBtcToken_RevertIf_StillVesting() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, ONE_LP);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IHybridVaultNFT.StillVesting.selector, tokenId));
        vault.mintBtcToken(tokenId);
    }

    function test_MintBtcToken_RevertIf_AlreadyMinted() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IHybridVaultNFT.BtcTokenAlreadyMinted.selector, tokenId));
        vault.mintBtcToken(tokenId);
    }

    function test_ReturnBtcToken() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 5 * ONE_BTC, ONE_LP);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.startPrank(alice);
        btcToken.approve(address(vault), type(uint256).max);
        vault.returnBtcToken(tokenId);
        vm.stopPrank();

        assertEq(btcToken.balanceOf(alice), 0);
    }

    // ========== Match Pool Tests ==========

    function test_ClaimPrimaryMatch() public {
        // Alice creates vault
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, 10 * ONE_BTC, ONE_LP);

        // Bob creates vault and early redeems, funding match pool
        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, 10 * ONE_BTC, ONE_LP);

        vm.prank(bob);
        vault.earlyRedeem(bobToken);

        // Alice's vault vests
        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 alicePrimaryBefore = primaryToken.balanceOf(alice);
        uint256 poolBefore = vault.primaryMatchPool();

        vm.prank(alice);
        uint256 claimed = vault.claimPrimaryMatch(aliceToken);

        assertTrue(claimed > 0);
        assertEq(vault.primaryMatchPool(), poolBefore - claimed);
        assertEq(vault.primaryAmount(aliceToken), 10 * ONE_BTC + claimed);
    }

    function test_ClaimSecondaryMatch() public {
        // Alice creates vault
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, ONE_BTC, 10 * ONE_LP);

        // Bob creates vault and early redeems
        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, ONE_BTC, 10 * ONE_LP);

        vm.prank(bob);
        vault.earlyRedeem(bobToken);

        // Alice's vault vests
        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 poolBefore = vault.secondaryMatchPool();

        vm.prank(alice);
        uint256 claimed = vault.claimSecondaryMatch(aliceToken);

        assertTrue(claimed > 0);
        assertEq(vault.secondaryMatchPool(), poolBefore - claimed);
        assertEq(vault.secondaryAmount(aliceToken), 10 * ONE_LP + claimed);
    }

    // ========== Delegation Tests ==========

    function test_GrantWithdrawalDelegate() public {
        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 5000); // 50%

        IHybridVaultNFT.WalletDelegatePermission memory perm = vault.getWalletDelegatePermission(alice, bob);
        assertEq(perm.percentageBPS, 5000);
        assertTrue(perm.active);
    }

    function test_WithdrawPrimaryAsDelegate() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 10 * ONE_BTC, ONE_LP);

        vm.prank(alice);
        vault.grantWithdrawalDelegate(bob, 5000); // 50%

        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 bobBalanceBefore = primaryToken.balanceOf(bob);

        vm.prank(bob);
        uint256 withdrawn = vault.withdrawPrimaryAsDelegate(tokenId);

        assertTrue(withdrawn > 0);
        assertEq(primaryToken.balanceOf(bob), bobBalanceBefore + withdrawn);
    }

    function test_VaultDelegation() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 10 * ONE_BTC, ONE_LP);

        vm.prank(alice);
        vault.grantVaultDelegate(tokenId, bob, 2500, 0); // 25%, no expiry

        IHybridVaultNFT.VaultDelegatePermission memory perm = vault.getVaultDelegatePermission(tokenId, bob);
        assertEq(perm.percentageBPS, 2500);
        assertTrue(perm.active);
        assertEq(perm.expiresAt, 0);
    }

    // ========== View Function Tests ==========

    function test_GetVaultInfo() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 7 * ONE_BTC, 3 * ONE_LP);

        (
            address treasureContract_,
            uint256 treasureTokenId_,
            uint256 primaryAmount_,
            uint256 secondaryAmount_,
            uint256 mintTimestamp_,
            uint256 lastPrimaryWithdrawal_,
            bool secondaryWithdrawn_,
            uint256 btcTokenAmount_
        ) = vault.getVaultInfo(tokenId);

        assertEq(treasureContract_, address(treasure));
        assertEq(treasureTokenId_, 0);
        assertEq(primaryAmount_, 7 * ONE_BTC);
        assertEq(secondaryAmount_, 3 * ONE_LP);
        assertTrue(mintTimestamp_ > 0);
        assertEq(lastPrimaryWithdrawal_, 0);
        assertFalse(secondaryWithdrawn_);
        assertEq(btcTokenAmount_, 0);
    }

    function test_GetWithdrawablePrimary() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, 10 * ONE_BTC, ONE_LP);

        // Before vesting
        assertEq(vault.getWithdrawablePrimary(tokenId), 0);

        // After vesting
        vm.warp(block.timestamp + VESTING_PERIOD);
        uint256 expected = (10 * ONE_BTC * 1000) / 100000; // 1%
        assertEq(vault.getWithdrawablePrimary(tokenId), expected);
    }

    function test_GetWithdrawableSecondary() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, 5 * ONE_LP);

        // Before vesting
        assertEq(vault.getWithdrawableSecondary(tokenId), 0);

        // After vesting
        vm.warp(block.timestamp + VESTING_PERIOD);
        assertEq(vault.getWithdrawableSecondary(tokenId), 5 * ONE_LP);

        // After withdrawal
        vm.prank(alice);
        vault.withdrawSecondary(tokenId);
        assertEq(vault.getWithdrawableSecondary(tokenId), 0);
    }

    function test_IsVested() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, ONE_BTC, ONE_LP);

        assertFalse(vault.isVested(tokenId));

        vm.warp(block.timestamp + VESTING_PERIOD);
        assertTrue(vault.isVested(tokenId));
    }
}
