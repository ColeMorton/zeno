// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {BaseTest} from "../utils/BaseTest.sol";

contract DormancyTest is BaseTest {
    /// @dev Mint a vault for alice, strip the full collateral, ship the vBTC to bob,
    /// and warp past the dormancy threshold. Returns the dormant-eligible token ID.
    function _setupDormantVault() internal returns (uint256 tokenId) {
        tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);
    }

    /// @dev Poke and pass the grace period so the reserve becomes claimable.
    function _makeClaimable(uint256 tokenId) internal {
        vm.prank(charlie);
        vault.pokeDormant(tokenId);
        vm.warp(block.timestamp + GRACE_PERIOD);
    }

    // ========== Eligibility ==========

    function test_Dormancy_Eligible_WhenReserveOutstandingAndInactive() public {
        uint256 tokenId = _setupDormantVault();

        (bool eligible, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertTrue(eligible);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.ACTIVE));
    }

    function test_Dormancy_NoReserve_NotEligible() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotDormantEligible.selector, tokenId));
        vault.pokeDormant(tokenId);
    }

    function test_Dormancy_OwnerHoldsFullReserveInBtcToken_NotEligible() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }

    function test_Dormancy_OwnerHoldsPartialBtcToken_StillEligible() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        // Owner keeps half: balance < reserve, still eligible
        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertTrue(eligible);
    }

    function test_Dormancy_ExactThresholdBoundary() public {
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);
        _stripAll(alice, tokenId);

        uint256 activityTimestamp = vault.lastActivity(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(activityTimestamp + DORMANCY_THRESHOLD - 1);

        (bool eligibleBefore,) = vault.isDormantEligible(tokenId);
        assertFalse(eligibleBefore);

        vm.warp(activityTimestamp + DORMANCY_THRESHOLD);

        (bool eligibleAfter,) = vault.isDormantEligible(tokenId);
        assertTrue(eligibleAfter);
    }

    // ========== Poke / Grace Period ==========

    function test_Dormancy_AnyoneCanPoke() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        (, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.POKE_PENDING));
    }

    function test_Dormancy_CannotDoublePoke() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.AlreadyPoked.selector, tokenId));
        vault.pokeDormant(tokenId);
    }

    function test_Dormancy_GraceExactExpiry_NotClaimableBefore() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD - 1);

        (, IVaultNFT.DormancyState stateBefore) = vault.isDormantEligible(tokenId);
        assertEq(uint256(stateBefore), uint256(IVaultNFT.DormancyState.POKE_PENDING));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, tokenId));
        vault.claimDormantCollateral(tokenId, ONE_BTC);

        vm.warp(block.timestamp + 1);

        (, IVaultNFT.DormancyState stateAfter) = vault.isDormantEligible(tokenId);
        assertEq(uint256(stateAfter), uint256(IVaultNFT.DormancyState.CLAIMABLE));

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId, ONE_BTC);
    }

    function test_Dormancy_TransferDuringPokePending_ResetsDormancy() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        vm.prank(alice);
        vault.transferFrom(alice, charlie, tokenId);

        (bool eligible, IVaultNFT.DormancyState newState) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(newState), uint256(IVaultNFT.DormancyState.ACTIVE));

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, tokenId));
        vault.claimDormantCollateral(tokenId, ONE_BTC);
    }

    function test_Dormancy_BtcTokenRepurchasedInGrace_NotEligible() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD / 2);

        // Owner buys back the full reserve worth of vBTC
        vm.prank(bob);
        btcToken.transfer(alice, ONE_BTC);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, tokenId));
        vault.claimDormantCollateral(tokenId, ONE_BTC);
    }

    function test_Dormancy_WithdrawDuringPokePending_ResetsDormancy() public {
        // Partial strip so active collateral remains and withdraw pays out
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 2);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0);

        (bool eligible, IVaultNFT.DormancyState stateAfter) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(stateAfter), uint256(IVaultNFT.DormancyState.ACTIVE));
    }

    function test_Dormancy_ClaimMatchDuringPokePending_ResetsDormancy() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.prank(alice);
        vault.claimMatch(tokenId);

        (bool eligible, IVaultNFT.DormancyState stateAfter) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(stateAfter), uint256(IVaultNFT.DormancyState.ACTIVE));
    }

    function test_Dormancy_ProveActivityBeforeGraceExpiry() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD - 1);

        vm.expectEmit(true, true, false, false);
        emit IVaultNFT.ActivityProven(tokenId, alice);

        vm.prank(alice);
        vault.proveActivity(tokenId);

        (bool eligible, IVaultNFT.DormancyState newState) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(newState), uint256(IVaultNFT.DormancyState.ACTIVE));
    }

    // ========== Claims ==========

    function test_Dormancy_FullClaim() public {
        uint256 tokenId = _setupDormantVault();
        _makeClaimable(tokenId);

        uint256 bobWbtcBefore = wbtc.balanceOf(bob);
        uint256 supplyBefore = btcToken.totalSupply();

        vm.expectEmit(true, true, true, true);
        emit IVaultNFT.DormantCollateralClaimed(tokenId, alice, bob, ONE_BTC);

        vm.prank(bob);
        uint256 claimed = vault.claimDormantCollateral(tokenId, ONE_BTC);

        assertEq(claimed, ONE_BTC);
        assertEq(wbtc.balanceOf(bob), bobWbtcBefore + ONE_BTC);
        assertEq(btcToken.balanceOf(bob), 0);
        assertEq(btcToken.totalSupply(), supplyBefore - ONE_BTC);
        assertEq(vault.strippedReserve(tokenId), 0);
        assertEq(vault.totalStrippedReserve(), 0);
    }

    function test_Dormancy_VaultSurvivesClaim() public {
        uint256 tokenId = _setupDormantVault();
        _makeClaimable(tokenId);

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId, ONE_BTC);

        // Vault persists: owner, treasure, and active collateral untouched
        assertEq(vault.ownerOf(tokenId), alice);
        assertEq(treasure.ownerOf(0), address(vault));
        assertEq(vault.collateralAmount(tokenId), 0);
    }

    function test_Dormancy_ActiveCollateralUntouchedByClaim() public {
        // Strip only half: active half must remain with the vault after a claim
        uint256 tokenId = _mintVault(alice, 0, ONE_BTC);

        _skipVesting();

        vm.prank(alice);
        vault.strip(tokenId, ONE_BTC / 2);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);
        _makeClaimable(tokenId);

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId, ONE_BTC / 2);

        assertEq(vault.collateralAmount(tokenId), ONE_BTC / 2);
        assertEq(vault.strippedReserve(tokenId), 0);
        assertEq(vault.ownerOf(tokenId), alice);
    }

    function test_Dormancy_FractionalMultiClaimant() public {
        uint256 tokenId = _setupDormantVault();

        // Split the vBTC float between bob and charlie
        vm.prank(bob);
        btcToken.transfer(charlie, ONE_BTC / 4);

        _makeClaimable(tokenId);

        uint256 bobWbtcBefore = wbtc.balanceOf(bob);
        uint256 charlieWbtcBefore = wbtc.balanceOf(charlie);

        vm.prank(bob);
        uint256 bobClaimed = vault.claimDormantCollateral(tokenId, ONE_BTC / 2);
        assertEq(bobClaimed, ONE_BTC / 2);
        assertEq(vault.strippedReserve(tokenId), ONE_BTC - ONE_BTC / 2);

        vm.prank(charlie);
        uint256 charlieClaimed = vault.claimDormantCollateral(tokenId, ONE_BTC / 4);
        assertEq(charlieClaimed, ONE_BTC / 4);

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId, ONE_BTC / 4);

        assertEq(wbtc.balanceOf(bob), bobWbtcBefore + ONE_BTC / 2 + ONE_BTC / 4);
        assertEq(wbtc.balanceOf(charlie), charlieWbtcBefore + ONE_BTC / 4);
        assertEq(vault.strippedReserve(tokenId), 0);
        assertEq(vault.totalStrippedReserve(), btcToken.totalSupply());
    }

    function test_Dormancy_ReserveZero_EndsEligibility() public {
        uint256 tokenId = _setupDormantVault();
        _makeClaimable(tokenId);

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId, ONE_BTC);

        (bool eligible, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.ACTIVE));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, tokenId));
        vault.claimDormantCollateral(tokenId, 1);
    }

    function test_Dormancy_Claim_RevertIf_ZeroAmount() public {
        uint256 tokenId = _setupDormantVault();
        _makeClaimable(tokenId);

        vm.prank(bob);
        vm.expectRevert(IVaultNFT.ZeroAmount.selector);
        vault.claimDormantCollateral(tokenId, 0);
    }

    function test_Dormancy_Claim_RevertIf_ExceedsReserve() public {
        uint256 tokenId = _setupDormantVault();
        _makeClaimable(tokenId);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVaultNFT.InsufficientReserve.selector, tokenId, ONE_BTC + 1, ONE_BTC
            )
        );
        vault.claimDormantCollateral(tokenId, ONE_BTC + 1);
    }

    function test_Dormancy_Claim_RevertIf_InsufficientBtcToken() public {
        uint256 tokenId = _setupDormantVault();
        _makeClaimable(tokenId);

        // Charlie holds no vBTC
        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, 0)
        );
        vault.claimDormantCollateral(tokenId, ONE_BTC);
    }
}
