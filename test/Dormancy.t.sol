// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../src/VaultNFT.sol";
import {BtcToken} from "../src/BtcToken.sol";
import {IVaultNFT} from "../src/interfaces/IVaultNFT.sol";
import {MockTreasure} from "./mocks/MockTreasure.sol";
import {MockWBTC} from "./mocks/MockWBTC.sol";

contract DormancyEdgeCasesTest is Test {
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
        btcToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _setupDormantVault() internal returns (uint256 tokenId) {
        vm.prank(alice);
        tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);
    }

    function test_Dormancy_TransferDuringPokePending_ResetsDormancy() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(bob);
        vault.pokeDormant(tokenId);

        (, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.POKE_PENDING));

        vm.prank(alice);
        vault.transferFrom(alice, charlie, tokenId);

        (bool eligible, IVaultNFT.DormancyState newState) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(newState), uint256(IVaultNFT.DormancyState.ACTIVE));

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, tokenId));
        vault.claimDormantCollateral(tokenId);
    }

    function test_Dormancy_BtcTokenRepurchasedInGrace_NotEligible() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD / 2);

        vm.prank(bob);
        btcToken.transfer(alice, ONE_BTC);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NotClaimable.selector, tokenId));
        vault.claimDormantCollateral(tokenId);
    }

    function test_Dormancy_ExactThresholdBoundary_NotEligibleBefore() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        uint256 activityTimestamp = vault.lastActivity(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC);

        vm.warp(activityTimestamp + DORMANCY_THRESHOLD - 1);

        (bool eligibleBefore,) = vault.isDormantEligible(tokenId);
        assertFalse(eligibleBefore);

        vm.warp(activityTimestamp + DORMANCY_THRESHOLD + 1);

        (bool eligibleAfter,) = vault.isDormantEligible(tokenId);
        assertTrue(eligibleAfter);
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
        vault.claimDormantCollateral(tokenId);

        vm.warp(block.timestamp + 2);

        (, IVaultNFT.DormancyState stateAfter) = vault.isDormantEligible(tokenId);
        assertEq(uint256(stateAfter), uint256(IVaultNFT.DormancyState.CLAIMABLE));

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId);
    }

    function test_Dormancy_PartialBtcTokenAtOwner_StillEligible() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.prank(alice);
        btcToken.transfer(bob, ONE_BTC / 2);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertTrue(eligible);
    }

    function test_Dormancy_WithdrawDuringPokePending_ResetsDormancy() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        (, IVaultNFT.DormancyState stateBefore) = vault.isDormantEligible(tokenId);
        assertEq(uint256(stateBefore), uint256(IVaultNFT.DormancyState.POKE_PENDING));

        vm.prank(alice);
        vault.withdraw(tokenId);

        (bool eligible, IVaultNFT.DormancyState stateAfter) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(stateAfter), uint256(IVaultNFT.DormancyState.ACTIVE));
    }

    function test_Dormancy_ClaimMatchDuringPokePending_ResetsDormancy() public {
        vm.prank(bob);
        uint256 bobToken = vault.mint(address(treasure), 10, address(wbtc), ONE_BTC, 0);

        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + 365 days);

        vm.prank(bob);
        vault.earlyRedeem(bobToken);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(aliceToken);

        vm.prank(alice);
        btcToken.transfer(charlie, ONE_BTC);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        vm.prank(charlie);
        vault.pokeDormant(aliceToken);

        vm.prank(alice);
        vault.claimMatch(aliceToken);

        (bool eligible, IVaultNFT.DormancyState stateAfter) = vault.isDormantEligible(aliceToken);
        assertFalse(eligible);
        assertEq(uint256(stateAfter), uint256(IVaultNFT.DormancyState.ACTIVE));
    }

    function test_Dormancy_TreasureReturnedToOriginalOwner() public {
        uint256 tokenId = _setupDormantVault();

        assertEq(treasure.ownerOf(0), address(vault));

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId);

        assertEq(treasure.ownerOf(0), alice);
    }

    function test_Dormancy_CollateralGoesToClaimer() public {
        uint256 tokenId = _setupDormantVault();

        uint256 bobWbtcBefore = wbtc.balanceOf(bob);

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(bob);
        uint256 collateral = vault.claimDormantCollateral(tokenId);

        assertEq(collateral, ONE_BTC);
        assertEq(wbtc.balanceOf(bob), bobWbtcBefore + ONE_BTC);
    }

    function test_Dormancy_BtcTokenBurnedOnClaim() public {
        uint256 tokenId = _setupDormantVault();

        assertEq(btcToken.balanceOf(bob), ONE_BTC);
        uint256 supplyBefore = btcToken.totalSupply();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId);

        assertEq(btcToken.balanceOf(bob), 0);
        assertEq(btcToken.totalSupply(), supplyBefore - ONE_BTC);
    }

    function test_Dormancy_VaultBurnedAfterClaim() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD);

        vm.prank(bob);
        vault.claimDormantCollateral(tokenId);

        vm.expectRevert();
        vault.ownerOf(tokenId);
    }

    function test_Dormancy_AnyoneCanPoke() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        (, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.POKE_PENDING));
    }

    function test_Dormancy_ProveActivityBeforeGraceExpiry() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD - 1);

        vm.prank(alice);
        vault.proveActivity(tokenId);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }

    function test_Dormancy_ProveActivityAtLastSecond() public {
        uint256 tokenId = _setupDormantVault();

        vm.prank(charlie);
        vault.pokeDormant(tokenId);

        vm.warp(block.timestamp + GRACE_PERIOD - 1);

        (, IVaultNFT.DormancyState state) = vault.isDormantEligible(tokenId);
        assertEq(uint256(state), uint256(IVaultNFT.DormancyState.POKE_PENDING));

        vm.prank(alice);
        vault.proveActivity(tokenId);

        (bool eligible, IVaultNFT.DormancyState newState) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
        assertEq(uint256(newState), uint256(IVaultNFT.DormancyState.ACTIVE));
    }

    function test_Dormancy_NoBtcToken_NotEligible() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD + DORMANCY_THRESHOLD + 1);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }

    function test_Dormancy_OwnerHoldsAllBtcToken_NotEligible() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC, 0);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        vm.warp(block.timestamp + DORMANCY_THRESHOLD + 1);

        (bool eligible,) = vault.isDormantEligible(tokenId);
        assertFalse(eligible);
    }
}
