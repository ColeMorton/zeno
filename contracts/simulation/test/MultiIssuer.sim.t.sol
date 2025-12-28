// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SimulationOrchestrator, MockWBTC} from "../src/SimulationOrchestrator.sol";
import {CrossLayerInvariants} from "../src/assertions/CrossLayerInvariants.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementNFT} from "@issuer/AchievementNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";

/// @title MultiIssuerTest - Tests for multi-issuer isolation and fair match pool sharing
/// @notice Verifies multiple issuers can coexist on same protocol without interference
contract MultiIssuerTest is Test {
    SimulationOrchestrator public orchestrator;

    // Protocol
    VaultNFT public vault;
    BtcToken public btcToken;
    MockWBTC public wbtc;

    // Issuer A
    TreasureNFT public treasureA;
    AchievementNFT public achievementA;
    AchievementMinter public minterA;

    // Issuer B
    TreasureNFT public treasureB;
    AchievementNFT public achievementB;
    AchievementMinter public minterB;

    // Actors
    address public alice; // Uses Issuer A
    address public bob;   // Uses Issuer B
    address public charlie; // Uses both issuers

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;

    bytes32 internal constant MINTER = keccak256("MINTER");
    bytes32 internal constant MATURED = keccak256("MATURED");

    function setUp() public {
        // Create actors
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy orchestrator and protocol
        orchestrator = new SimulationOrchestrator();
        (vault, btcToken, wbtc) = orchestrator.deployProtocol();

        // Deploy Issuer A
        (, AchievementMinter minterA_) = orchestrator.deployIssuer("IssuerA");
        minterA = minterA_;
        (address treasureAAddr, address achievementAAddr, , ) = orchestrator.getIssuer(0);
        treasureA = TreasureNFT(treasureAAddr);
        achievementA = AchievementNFT(achievementAAddr);

        // Deploy Issuer B
        (, AchievementMinter minterB_) = orchestrator.deployIssuer("IssuerB");
        minterB = minterB_;
        (address treasureBAddr, address achievementBAddr, , ) = orchestrator.getIssuer(1);
        treasureB = TreasureNFT(treasureBAddr);
        achievementB = AchievementNFT(achievementBAddr);

        // Fund actors with WBTC
        wbtc.mint(alice, 100 * ONE_BTC);
        wbtc.mint(bob, 100 * ONE_BTC);
        wbtc.mint(charlie, 100 * ONE_BTC);

        // Fund actors with treasures from both issuers
        orchestrator.fundActor(alice, 0, 0, 10);   // Alice gets Issuer A treasures
        orchestrator.fundActor(bob, 0, 1, 10);     // Bob gets Issuer B treasures
        orchestrator.fundActor(charlie, 0, 0, 5);  // Charlie gets both
        orchestrator.fundActor(charlie, 0, 1, 5);

        // Setup approvals
        _setupApprovals(alice);
        _setupApprovals(bob);
        _setupApprovals(charlie);
    }

    function _setupApprovals(address actor) internal {
        vm.startPrank(actor);
        wbtc.approve(address(vault), type(uint256).max);
        treasureA.setApprovalForAll(address(vault), true);
        treasureB.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    // ==================== Issuer Isolation Tests ====================

    /// @notice Verify Issuer A's minter rejects vaults with Issuer B's treasure
    function test_IssuerIsolation_MinterRejectsWrongTreasure() public {
        // Bob mints vault with Issuer B treasure
        vm.prank(bob);
        uint256 vaultId = vault.mint(
            address(treasureB),
            0, // Bob's first Issuer B treasure
            address(wbtc),
            10 * ONE_BTC
        );

        // Try to claim MINTER achievement from Issuer A - should fail
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.VaultNotUsingIssuerTreasure.selector,
                vaultId,
                address(treasureB)
            )
        );
        minterA.claimMinterAchievement(vaultId, address(wbtc));

        // But should succeed with Issuer B's minter
        vm.prank(bob);
        minterB.claimMinterAchievement(vaultId, address(wbtc));

        // Verify Bob has achievement from B but not A
        assertTrue(achievementB.hasAchievement(bob, MINTER), "Bob should have Issuer B MINTER");
        assertFalse(achievementA.hasAchievement(bob, MINTER), "Bob should NOT have Issuer A MINTER");
    }

    /// @notice Verify achievements are issuer-specific
    function test_IssuerIsolation_AchievementsAreSeparate() public {
        // Alice mints vault with Issuer A treasure
        vm.prank(alice);
        uint256 aliceVaultId = vault.mint(address(treasureA), 0, address(wbtc), 10 * ONE_BTC);

        // Bob mints vault with Issuer B treasure
        vm.prank(bob);
        uint256 bobVaultId = vault.mint(address(treasureB), 0, address(wbtc), 10 * ONE_BTC);

        // Each claims their respective MINTER
        vm.prank(alice);
        minterA.claimMinterAchievement(aliceVaultId, address(wbtc));

        vm.prank(bob);
        minterB.claimMinterAchievement(bobVaultId, address(wbtc));

        // Verify separation
        assertTrue(achievementA.hasAchievement(alice, MINTER));
        assertFalse(achievementA.hasAchievement(bob, MINTER));
        assertFalse(achievementB.hasAchievement(alice, MINTER));
        assertTrue(achievementB.hasAchievement(bob, MINTER));

        // Achievement counts are separate
        assertEq(achievementA.totalSupply(), 1);
        assertEq(achievementB.totalSupply(), 1);
    }

    /// @notice Verify user can have achievements from multiple issuers
    function test_IssuerIsolation_UserCanHaveMultipleIssuerAchievements() public {
        // Charlie mints vault with Issuer A treasure (Charlie has treasures 10-14)
        vm.prank(charlie);
        uint256 vaultIdA = vault.mint(address(treasureA), 10, address(wbtc), 10 * ONE_BTC);

        // Charlie mints vault with Issuer B treasure (Charlie has treasures 10-14)
        vm.prank(charlie);
        uint256 vaultIdB = vault.mint(address(treasureB), 11, address(wbtc), 10 * ONE_BTC);

        // Charlie claims MINTER from both issuers
        vm.prank(charlie);
        minterA.claimMinterAchievement(vaultIdA, address(wbtc));

        vm.prank(charlie);
        minterB.claimMinterAchievement(vaultIdB, address(wbtc));

        // Charlie has achievements from both
        assertTrue(achievementA.hasAchievement(charlie, MINTER));
        assertTrue(achievementB.hasAchievement(charlie, MINTER));

        // Charlie has 2 achievement NFTs total (1 from each issuer)
        assertEq(achievementA.balanceOf(charlie), 1);
        assertEq(achievementB.balanceOf(charlie), 1);
    }

    // ==================== Match Pool Fairness Tests ====================

    /// @notice Verify match pool claims work across issuers
    /// @dev Protocol uses dynamic allocation: first claim reduces totalActiveCollateral
    function test_MatchPool_ClaimsWorkAcrossIssuers() public {
        // Alice mints with Issuer A (10 BTC)
        vm.prank(alice);
        uint256 aliceVaultId = vault.mint(address(treasureA), 0, address(wbtc), 10 * ONE_BTC);

        // Bob mints with Issuer B (10 BTC)
        vm.prank(bob);
        uint256 bobVaultId = vault.mint(address(treasureB), 0, address(wbtc), 10 * ONE_BTC);

        // Charlie mints with Issuer A (10 BTC) and early redeems to fund pool
        vm.prank(charlie);
        uint256 charlieVaultId = vault.mint(address(treasureA), 10, address(wbtc), 10 * ONE_BTC);

        // Charlie early redeems at day 500
        vm.warp(block.timestamp + 500 days);
        vm.prank(charlie);
        (, uint256 forfeited) = vault.earlyRedeem(charlieVaultId);

        uint256 initialPool = vault.matchPool();
        assertGt(initialPool, 0, "Match pool should have funds");
        assertEq(initialPool, forfeited, "Match pool should equal forfeited amount");

        // Fast forward to vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Track collateral before claims
        uint256 aliceCollateralBefore = vault.collateralAmount(aliceVaultId);
        uint256 bobCollateralBefore = vault.collateralAmount(bobVaultId);

        // Both Alice and Bob claim match
        vm.prank(alice);
        uint256 aliceMatch = vault.claimMatch(aliceVaultId);

        vm.prank(bob);
        uint256 bobMatch = vault.claimMatch(bobVaultId);

        // Verify both received match (protocol uses dynamic allocation)
        assertGt(aliceMatch, 0, "Alice should receive match");
        assertGt(bobMatch, 0, "Bob should receive match");

        // Total claimed should not exceed initial pool
        assertLe(aliceMatch + bobMatch, initialPool, "Total claimed <= initial pool");

        // Match adds to collateral, not direct WBTC transfer
        assertEq(vault.collateralAmount(aliceVaultId), aliceCollateralBefore + aliceMatch, "Alice collateral increased");
        assertEq(vault.collateralAmount(bobVaultId), bobCollateralBefore + bobMatch, "Bob collateral increased");

        // Collateral conservation holds
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 remaining = vault.collateralAmount(aliceVaultId) + vault.collateralAmount(bobVaultId);
        assertEq(vaultBalance, remaining + vault.matchPool(), "Collateral conservation");
    }

    /// @notice Verify larger collateral holders get more match (not necessarily proportional)
    /// @dev Protocol uses dynamic allocation - larger holder gets more, but ratio varies by claim order
    function test_MatchPool_LargerCollateralGetsMore() public {
        // Alice: 10 BTC (Issuer A)
        vm.prank(alice);
        uint256 aliceVaultId = vault.mint(address(treasureA), 0, address(wbtc), 10 * ONE_BTC);

        // Bob: 30 BTC (Issuer B) - 3x Alice's collateral
        vm.prank(bob);
        uint256 bobVaultId = vault.mint(address(treasureB), 0, address(wbtc), 30 * ONE_BTC);

        // Charlie: 20 BTC (Issuer A) - funds the pool via early redeem
        vm.prank(charlie);
        uint256 charlieVaultId = vault.mint(address(treasureA), 10, address(wbtc), 20 * ONE_BTC);

        // Charlie early redeems
        vm.warp(block.timestamp + 500 days);
        vm.prank(charlie);
        vault.earlyRedeem(charlieVaultId);

        uint256 initialPool = vault.matchPool();
        assertGt(initialPool, 0, "Pool should have funds");

        // Fast forward to vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Claim match - Alice first
        vm.prank(alice);
        uint256 aliceMatch = vault.claimMatch(aliceVaultId);

        vm.prank(bob);
        uint256 bobMatch = vault.claimMatch(bobVaultId);

        // With dynamic allocation: Bob should still get more than Alice (larger collateral)
        assertGt(bobMatch, aliceMatch, "Bob (30 BTC) should get more than Alice (10 BTC)");

        // Total claimed <= initial pool
        assertLe(aliceMatch + bobMatch, initialPool, "Total claimed <= initial pool");

        // Collateral conservation
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 remaining = vault.collateralAmount(aliceVaultId) + vault.collateralAmount(bobVaultId);
        assertEq(vaultBalance, remaining + vault.matchPool(), "Collateral conservation");
    }

    // ==================== Full Lifecycle Multi-Issuer Tests ====================

    /// @notice Complete lifecycle with multiple issuers
    function test_FullLifecycle_MultipleIssuers() public {
        // Setup: Each user mints with their preferred issuer
        vm.prank(alice);
        uint256 aliceVaultId = vault.mint(address(treasureA), 0, address(wbtc), 10 * ONE_BTC);

        vm.prank(bob);
        uint256 bobVaultId = vault.mint(address(treasureB), 0, address(wbtc), 10 * ONE_BTC);

        // Charlie mints with both and early redeems one (Charlie has treasures 10-14)
        vm.prank(charlie);
        uint256 charlieVaultA = vault.mint(address(treasureA), 10, address(wbtc), 10 * ONE_BTC);

        vm.prank(charlie);
        uint256 charlieVaultB = vault.mint(address(treasureB), 11, address(wbtc), 10 * ONE_BTC);

        // Claim MINTER achievements
        vm.prank(alice);
        minterA.claimMinterAchievement(aliceVaultId, address(wbtc));

        vm.prank(bob);
        minterB.claimMinterAchievement(bobVaultId, address(wbtc));

        vm.prank(charlie);
        minterA.claimMinterAchievement(charlieVaultA, address(wbtc));

        vm.prank(charlie);
        minterB.claimMinterAchievement(charlieVaultB, address(wbtc));

        // Charlie early redeems Issuer B vault to fund pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(charlie);
        vault.earlyRedeem(charlieVaultB);

        // Fast forward to vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // All remaining vault holders claim match
        vm.prank(alice);
        vault.claimMatch(aliceVaultId);

        vm.prank(bob);
        vault.claimMatch(bobVaultId);

        vm.prank(charlie);
        vault.claimMatch(charlieVaultA);

        // Claim MATURED achievements
        vm.prank(alice);
        minterA.claimMaturedAchievement(aliceVaultId, address(wbtc));

        vm.prank(bob);
        minterB.claimMaturedAchievement(bobVaultId, address(wbtc));

        vm.prank(charlie);
        minterA.claimMaturedAchievement(charlieVaultA, address(wbtc));

        // Verify final state
        assertTrue(achievementA.hasAchievement(alice, MATURED));
        assertTrue(achievementB.hasAchievement(bob, MATURED));
        assertTrue(achievementA.hasAchievement(charlie, MATURED));

        // Charlie should NOT have MATURED from Issuer B (vault was early redeemed)
        assertFalse(achievementB.hasAchievement(charlie, MATURED));

        // Collateral conservation
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 matchPool = vault.matchPool();
        uint256 sumCollaterals = vault.collateralAmount(aliceVaultId)
            + vault.collateralAmount(bobVaultId)
            + vault.collateralAmount(charlieVaultA);

        assertEq(vaultBalance, sumCollaterals + matchPool, "Collateral conservation");
    }

    // ==================== Invariant Verification ====================

    /// @notice Verify all cross-layer invariants hold for multi-issuer scenario
    function test_Invariants_HoldAcrossIssuers() public {
        // Complex scenario with multiple issuers
        vm.prank(alice);
        uint256 v1 = vault.mint(address(treasureA), 0, address(wbtc), 10 * ONE_BTC);

        vm.prank(bob);
        uint256 v2 = vault.mint(address(treasureB), 0, address(wbtc), 20 * ONE_BTC);

        vm.prank(charlie);
        uint256 v3 = vault.mint(address(treasureA), 10, address(wbtc), 15 * ONE_BTC);

        // Claims and operations
        vm.prank(alice);
        minterA.claimMinterAchievement(v1, address(wbtc));

        vm.prank(bob);
        minterB.claimMinterAchievement(v2, address(wbtc));

        // Early redeem
        vm.warp(block.timestamp + 500 days);
        vm.prank(charlie);
        vault.earlyRedeem(v3);

        // Vest and claim
        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.claimMatch(v1);

        vm.prank(bob);
        vault.claimMatch(v2);

        // Verify protocol invariants using library
        (bool valid, string memory reason) = CrossLayerInvariants.checkCollateralConservation(
            vault, wbtc, 10
        );
        assertTrue(valid, reason);

        // Verify cross-layer invariants
        (valid, reason) = CrossLayerInvariants.checkMaturedPrerequisite(achievementA, alice);
        assertTrue(valid, reason);

        (valid, reason) = CrossLayerInvariants.checkMaturedPrerequisite(achievementB, bob);
        assertTrue(valid, reason);

        // Match pool solvency
        (valid, reason) = CrossLayerInvariants.checkMatchPoolSolvency(vault);
        assertTrue(valid, reason);
    }

    /// @notice Verify achievement prerequisite chains hold across issuers
    function test_Invariants_AchievementPrerequisites() public {
        // Setup full achievement chain for both issuers
        vm.prank(alice);
        uint256 aliceVaultId = vault.mint(address(treasureA), 0, address(wbtc), 10 * ONE_BTC);

        vm.prank(bob);
        uint256 bobVaultId = vault.mint(address(treasureB), 0, address(wbtc), 10 * ONE_BTC);

        // Fund match pool
        vm.prank(charlie);
        uint256 charlieVaultId = vault.mint(address(treasureA), 10, address(wbtc), 10 * ONE_BTC);

        vm.warp(block.timestamp + 500 days);
        vm.prank(charlie);
        vault.earlyRedeem(charlieVaultId);

        // Get MINTER
        vm.prank(alice);
        minterA.claimMinterAchievement(aliceVaultId, address(wbtc));

        vm.prank(bob);
        minterB.claimMinterAchievement(bobVaultId, address(wbtc));

        // Vest, claim match, get MATURED
        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.claimMatch(aliceVaultId);
        vm.prank(alice);
        minterA.claimMaturedAchievement(aliceVaultId, address(wbtc));

        vm.prank(bob);
        vault.claimMatch(bobVaultId);
        vm.prank(bob);
        minterB.claimMaturedAchievement(bobVaultId, address(wbtc));

        // Verify prerequisites hold
        (bool valid, string memory reason) = CrossLayerInvariants.checkAllCrossLayerInvariants(
            achievementA, alice
        );
        assertTrue(valid, reason);

        (valid, reason) = CrossLayerInvariants.checkAllCrossLayerInvariants(
            achievementB, bob
        );
        assertTrue(valid, reason);

        // Verify Charlie (no achievements yet) also passes
        (valid, reason) = CrossLayerInvariants.checkAllCrossLayerInvariants(
            achievementA, charlie
        );
        assertTrue(valid, reason);
    }
}
