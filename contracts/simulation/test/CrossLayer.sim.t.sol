// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SimulationOrchestrator, ProtocolDeployment, IssuerDeployment, MockWBTC} from "../src/SimulationOrchestrator.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementNFT} from "@issuer/AchievementNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";

/// @title CrossLayerSimTest - Integration tests verifying issuer contracts against real protocol
/// @notice Phase 1: Core cross-layer integration validation
/// @dev These tests deploy real VaultNFT + real issuer contracts (no mocks for protocol)
contract CrossLayerSimTest is Test {
    SimulationOrchestrator public orchestrator;

    // Protocol contracts
    VaultNFT public vault;
    BtcToken public btcToken;
    MockWBTC public wbtc;

    // Issuer contracts
    TreasureNFT public treasureNFT;
    AchievementNFT public achievementNFT;
    AchievementMinter public minter;

    // Test actors
    address public alice;
    address public bob;

    // Constants
    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;

    // Achievement type constants
    bytes32 internal constant MINTER = keccak256("MINTER");
    bytes32 internal constant MATURED = keccak256("MATURED");
    bytes32 internal constant HODLER_SUPREME = keccak256("HODLER_SUPREME");
    bytes32 internal constant FIRST_MONTH = keccak256("FIRST_MONTH");

    function setUp() public {
        // Create test actors
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy orchestrator
        orchestrator = new SimulationOrchestrator();

        // Deploy protocol stack
        (vault, btcToken, wbtc) = orchestrator.deployProtocol();

        // Deploy issuer stack
        (, AchievementMinter deployedMinter) = orchestrator.deployIssuer("TestIssuer");
        minter = deployedMinter;

        // Get issuer contracts
        (address treasureAddr, address achievementAddr, , ) = orchestrator.getIssuer(0);
        treasureNFT = TreasureNFT(treasureAddr);
        achievementNFT = AchievementNFT(achievementAddr);

        // Fund actors
        orchestrator.fundActor(alice, 10 * ONE_BTC, 0, 5);
        orchestrator.fundActor(bob, 10 * ONE_BTC, 0, 5);

        // Approve vault for actors
        vm.prank(alice);
        wbtc.approve(address(vault), type(uint256).max);
        vm.prank(alice);
        treasureNFT.setApprovalForAll(address(vault), true);

        vm.prank(bob);
        wbtc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        treasureNFT.setApprovalForAll(address(vault), true);
    }

    // ==================== Test 1: MINTER Achievement ====================

    /// @notice Verify minting vault → claiming MINTER achievement works against real protocol
    /// @dev This is the core cross-layer integration: issuer's AchievementMinter calls real VaultNFT
    function test_MintVault_ClaimMinterAchievement() public {
        // 1. Alice mints a vault with issuer's treasure
        uint256 treasureId = 0; // First treasure minted to alice
        uint256 collateral = 1 * ONE_BTC;

        vm.prank(alice);
        uint256 vaultId = vault.mint(
            address(treasureNFT),
            treasureId,
            address(wbtc),
            collateral
        );

        // 2. Verify vault state
        assertEq(vault.ownerOf(vaultId), alice, "Alice should own vault");
        assertEq(vault.treasureContract(vaultId), address(treasureNFT), "Vault should contain issuer treasure");
        assertEq(vault.collateralAmount(vaultId), collateral, "Collateral should match");

        // 3. Alice claims MINTER achievement via issuer's AchievementMinter
        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        // 4. Verify achievement state
        assertTrue(achievementNFT.hasAchievement(alice, MINTER), "Alice should have MINTER achievement");
        assertEq(achievementNFT.balanceOf(alice), 1, "Alice should have 1 achievement NFT");

        // 5. Verify duplicate prevention
        vm.prank(alice);
        vm.expectRevert();
        minter.claimMinterAchievement(vaultId, address(wbtc));
    }

    /// @notice Verify MINTER achievement fails for wrong issuer's treasure
    function test_MinterAchievement_RejectsWrongIssuerTreasure() public {
        // Deploy a second issuer
        (, AchievementMinter minter2) = orchestrator.deployIssuer("OtherIssuer");
        (address treasure2Addr, , , ) = orchestrator.getIssuer(1);
        TreasureNFT treasureNFT2 = TreasureNFT(treasure2Addr);

        // Fund alice with second issuer's treasure
        orchestrator.fundActor(alice, 0, 1, 1);

        // Approve vault for alice's new treasure
        vm.prank(alice);
        treasureNFT2.setApprovalForAll(address(vault), true);

        // Alice mints vault with second issuer's treasure
        vm.prank(alice);
        uint256 vaultId = vault.mint(
            address(treasureNFT2),
            0, // First treasure from issuer 2
            address(wbtc),
            ONE_BTC
        );

        // Try to claim MINTER from first issuer - should fail
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.VaultNotUsingIssuerTreasure.selector,
                vaultId,
                address(treasureNFT2)
            )
        );
        minter.claimMinterAchievement(vaultId, address(wbtc));
    }

    // ==================== Test 2: Full 1129-day Lifecycle ====================

    /// @notice Verify complete lifecycle: mint → vest → withdraw → match claim → MATURED
    function test_FullLifecycle_MaturedAchievement() public {
        // 1. Both Alice and Bob mint vaults at the same time
        // Note: Alice has treasures 0-4, Bob has treasures 5-9
        vm.prank(bob);
        uint256 bobVaultId = vault.mint(
            address(treasureNFT),
            5, // Bob's first treasure
            address(wbtc),
            2 * ONE_BTC
        );

        uint256 treasureId = 0; // Alice's first treasure
        uint256 collateral = 1 * ONE_BTC;

        vm.prank(alice);
        uint256 vaultId = vault.mint(
            address(treasureNFT),
            treasureId,
            address(wbtc),
            collateral
        );

        // 2. Claim MINTER achievement (prerequisite for MATURED)
        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        // 3. Verify MATURED cannot be claimed before vesting
        (bool canClaim, string memory reason) = minter.canClaimMaturedAchievement(alice, vaultId, address(wbtc));
        assertFalse(canClaim, "Should not be able to claim MATURED before vesting");
        assertEq(reason, "Vault not vested", "Reason should be vesting");

        // 4. Bob early redeems at day 500 to fund the match pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(bob);
        vault.earlyRedeem(bobVaultId);

        // 5. Continue time warp to past vesting period for Alice
        vm.warp(block.timestamp + (VESTING_PERIOD - 500 days) + 1);

        // 6. Verify vault is now vested
        assertTrue(vault.isVested(vaultId), "Vault should be vested");

        // 7. Verify MATURED still cannot be claimed (match not claimed)
        (canClaim, reason) = minter.canClaimMaturedAchievement(alice, vaultId, address(wbtc));
        assertFalse(canClaim, "Should not be able to claim MATURED without match claim");
        assertEq(reason, "Match not claimed", "Reason should be match not claimed");

        // 8. Claim match pool share (pool was funded by Bob's early redemption)
        vm.prank(alice);
        vault.claimMatch(vaultId);

        // 9. Verify match was claimed
        assertTrue(vault.matchClaimed(vaultId), "Match should be claimed");

        // 10. Now claim MATURED achievement
        vm.prank(alice);
        minter.claimMaturedAchievement(vaultId, address(wbtc));

        // 11. Verify achievement state
        assertTrue(achievementNFT.hasAchievement(alice, MATURED), "Alice should have MATURED achievement");
        assertEq(achievementNFT.balanceOf(alice), 2, "Alice should have 2 achievements (MINTER + MATURED)");
    }

    /// @notice Verify MATURED requires MINTER prerequisite
    function test_MaturedAchievement_RequiresMinterPrerequisite() public {
        // Setup: Bob funds the match pool (Bob has treasures 5-9)
        vm.prank(bob);
        uint256 bobVaultId = vault.mint(address(treasureNFT), 5, address(wbtc), 2 * ONE_BTC);

        // 1. Alice mints vault (but doesn't claim MINTER) (Alice has treasures 0-4)
        vm.prank(alice);
        uint256 vaultId = vault.mint(
            address(treasureNFT),
            0,
            address(wbtc),
            ONE_BTC
        );

        // 2. Bob early redeems to fund match pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(bob);
        vault.earlyRedeem(bobVaultId);

        // 3. Time warp past vesting for Alice
        vm.warp(block.timestamp + (VESTING_PERIOD - 500 days) + 1);

        // 4. Claim match
        vm.prank(alice);
        vault.claimMatch(vaultId);

        // 5. Try to claim MATURED without MINTER - should fail
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.MissingMinterAchievement.selector,
                alice
            )
        );
        minter.claimMaturedAchievement(vaultId, address(wbtc));
    }

    // ==================== Test 3: Hodler Supreme Atomic Vault ====================

    /// @notice Verify mintHodlerSupremeVault atomic operation
    /// @dev This tests the most complex cross-layer interaction:
    ///      Achievement minting + Treasure minting + Protocol vault creation
    function test_HodlerSupremeVault_AtomicOperation() public {
        // Setup: Bob funds the match pool (Bob has treasures 5-9)
        vm.prank(bob);
        uint256 bobVaultId = vault.mint(address(treasureNFT), 5, address(wbtc), 2 * ONE_BTC);

        // Prerequisites: Alice needs MINTER and MATURED achievements
        // 1. Mint first vault (Alice has treasures 0-4)
        vm.prank(alice);
        uint256 firstVaultId = vault.mint(
            address(treasureNFT),
            0, // Alice's first treasure
            address(wbtc),
            ONE_BTC
        );

        // 2. Claim MINTER
        vm.prank(alice);
        minter.claimMinterAchievement(firstVaultId, address(wbtc));

        // 3. Bob early redeems to fund match pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(bob);
        vault.earlyRedeem(bobVaultId);

        // 4. Time warp past vesting + claim match
        vm.warp(block.timestamp + (VESTING_PERIOD - 500 days) + 1);
        vm.prank(alice);
        vault.claimMatch(firstVaultId);

        // 5. Claim MATURED
        vm.prank(alice);
        minter.claimMaturedAchievement(firstVaultId, address(wbtc));

        // Verify prerequisites
        assertTrue(achievementNFT.hasAchievement(alice, MINTER), "Should have MINTER");
        assertTrue(achievementNFT.hasAchievement(alice, MATURED), "Should have MATURED");

        // 5. Now mint Hodler Supreme vault
        uint256 hodlerSupremeCollateral = 5 * ONE_BTC;

        // Approve minter to take WBTC from alice
        vm.prank(alice);
        wbtc.approve(address(minter), hodlerSupremeCollateral);

        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);
        uint256 aliceVaultsBefore = vault.balanceOf(alice);

        vm.prank(alice);
        uint256 hodlerVaultId = minter.mintHodlerSupremeVault(
            address(wbtc),
            hodlerSupremeCollateral
        );

        // 6. Verify atomic operation results

        // Achievement minted
        assertTrue(
            achievementNFT.hasAchievement(alice, HODLER_SUPREME),
            "Alice should have HODLER_SUPREME achievement"
        );

        // Vault created and transferred to alice
        assertEq(vault.ownerOf(hodlerVaultId), alice, "Alice should own Hodler Supreme vault");
        assertEq(vault.balanceOf(alice), aliceVaultsBefore + 1, "Alice should have one more vault");

        // Vault contains issuer's treasure
        assertEq(
            vault.treasureContract(hodlerVaultId),
            address(treasureNFT),
            "Hodler Supreme vault should contain issuer treasure"
        );

        // Collateral transferred
        assertEq(
            vault.collateralAmount(hodlerVaultId),
            hodlerSupremeCollateral,
            "Hodler Supreme vault should have correct collateral"
        );
        assertEq(
            wbtc.balanceOf(alice),
            aliceWbtcBefore - hodlerSupremeCollateral,
            "Alice WBTC should be reduced by collateral amount"
        );

        // 7. Verify duplicate prevention
        vm.prank(alice);
        wbtc.approve(address(minter), ONE_BTC);

        vm.prank(alice);
        vm.expectRevert();
        minter.mintHodlerSupremeVault(address(wbtc), ONE_BTC);
    }

    /// @notice Verify Hodler Supreme fails without prerequisites
    function test_HodlerSupremeVault_RequiresPrerequisites() public {
        uint256 collateral = ONE_BTC;

        // Alice has no achievements
        vm.prank(alice);
        wbtc.approve(address(minter), collateral);

        // Should fail - missing MINTER
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.MissingMinterAchievement.selector,
                alice
            )
        );
        minter.mintHodlerSupremeVault(address(wbtc), collateral);

        // Now get MINTER achievement
        vm.prank(alice);
        uint256 vaultId = vault.mint(address(treasureNFT), 0, address(wbtc), collateral);

        vm.prank(alice);
        minter.claimMinterAchievement(vaultId, address(wbtc));

        // Should still fail - missing MATURED
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                AchievementMinter.MissingMaturedAchievement.selector,
                alice
            )
        );
        minter.mintHodlerSupremeVault(address(wbtc), collateral);
    }

    // ==================== Duration Achievement Test ====================

    /// @notice Verify duration achievements work with real protocol timestamps
    function test_DurationAchievement_FirstMonth() public {
        // 1. Alice mints vault
        vm.prank(alice);
        uint256 vaultId = vault.mint(
            address(treasureNFT),
            0,
            address(wbtc),
            ONE_BTC
        );

        // 2. Verify cannot claim immediately
        (bool canClaim, ) = minter.canClaimDurationAchievement(alice, vaultId, address(wbtc), FIRST_MONTH);
        assertFalse(canClaim, "Should not be able to claim FIRST_MONTH immediately");

        // 3. Time warp 30 days
        vm.warp(block.timestamp + 30 days);

        // 4. Now can claim
        (canClaim, ) = minter.canClaimDurationAchievement(alice, vaultId, address(wbtc), FIRST_MONTH);
        assertTrue(canClaim, "Should be able to claim FIRST_MONTH after 30 days");

        // 5. Claim and verify
        vm.prank(alice);
        minter.claimDurationAchievement(vaultId, address(wbtc), FIRST_MONTH);

        assertTrue(
            achievementNFT.hasAchievement(alice, FIRST_MONTH),
            "Alice should have FIRST_MONTH achievement"
        );
    }
}
