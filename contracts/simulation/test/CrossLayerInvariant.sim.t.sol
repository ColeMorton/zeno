// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SimulationOrchestrator, ProtocolDeployment, IssuerDeployment, MockWBTC} from "../src/SimulationOrchestrator.sol";
import {CrossLayerHandler} from "../src/handlers/CrossLayerHandler.sol";
import {SimAdversary} from "../src/actors/SimAdversary.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementNFT} from "@issuer/AchievementNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";

/// @title CrossLayerInvariantTest - Invariant tests for cross-layer integration
/// @notice Verifies protocol + issuer invariants hold under random operations
contract CrossLayerInvariantTest is Test {
    SimulationOrchestrator public orchestrator;
    CrossLayerHandler public handler;
    SimAdversary public adversary;

    // Protocol contracts
    VaultNFT public vault;
    BtcToken public btcToken;
    MockWBTC public wbtc;

    // Issuer contracts
    TreasureNFT public treasureNFT;
    AchievementNFT public achievementNFT;
    AchievementMinter public minter;

    // Test actors
    address[] public actors;
    address public alice;
    address public bob;
    address public charlie;

    uint256 internal constant ONE_BTC = 1e8;

    function setUp() public {
        // Create actors
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        actors.push(alice);
        actors.push(bob);
        actors.push(charlie);

        // Deploy orchestrator and full stack
        orchestrator = new SimulationOrchestrator();
        (vault, btcToken, wbtc) = orchestrator.deployProtocol();
        (, AchievementMinter deployedMinter) = orchestrator.deployIssuer("TestIssuer");
        minter = deployedMinter;

        // Get issuer contracts
        (address treasureAddr, address achievementAddr, , ) = orchestrator.getIssuer(0);
        treasureNFT = TreasureNFT(treasureAddr);
        achievementNFT = AchievementNFT(achievementAddr);

        // Fund actors with WBTC and treasures
        for (uint256 i = 0; i < actors.length; i++) {
            orchestrator.fundActor(actors[i], 1000 * ONE_BTC, 0, 100);

            // Setup approvals
            vm.startPrank(actors[i]);
            wbtc.approve(address(vault), type(uint256).max);
            treasureNFT.setApprovalForAll(address(vault), true);
            vm.stopPrank();
        }

        // Create handler
        handler = new CrossLayerHandler(
            vault,
            btcToken,
            wbtc,
            treasureNFT,
            achievementNFT,
            minter,
            actors
        );

        // Create adversary
        adversary = new SimAdversary(
            address(vault),
            address(btcToken),
            address(wbtc),
            address(treasureNFT),
            address(minter)
        );

        // Target only the handler for invariant testing
        targetContract(address(handler));
    }

    // ==================== Protocol Invariants ====================

    /// @notice Total WBTC in vault must equal sum of all collaterals + match pool
    function invariant_collateralConservation() public view {
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 matchPool = vault.matchPool();

        uint256 sumCollaterals = 0;
        uint256 tokenCount = handler.getMintedVaultCount();

        for (uint256 i = 0; i < tokenCount; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                sumCollaterals += amount;
            } catch {
                // Token was burned, skip
            }
        }

        assertEq(
            vaultBalance,
            sumCollaterals + matchPool,
            "Collateral conservation violated"
        );
    }

    /// @notice Match pool must equal total forfeited minus total claimed
    function invariant_matchPoolConsistency() public view {
        uint256 matchPool = vault.matchPool();
        uint256 totalForfeited = handler.ghost_totalForfeited();
        uint256 totalClaimed = handler.ghost_totalMatchClaimed();

        assertEq(
            matchPool,
            totalForfeited - totalClaimed,
            "Match pool inconsistent"
        );
    }

    /// @notice Total withdrawn + remaining collateral <= total deposited
    function invariant_noFreeMoney() public view {
        uint256 totalDeposited = handler.ghost_totalDeposited();
        uint256 totalWithdrawn = handler.ghost_totalWithdrawn();

        uint256 sumRemaining = 0;
        uint256 tokenCount = handler.getMintedVaultCount();

        for (uint256 i = 0; i < tokenCount; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                sumRemaining += amount;
            } catch {}
        }

        uint256 matchPool = vault.matchPool();

        assertLe(
            totalWithdrawn + sumRemaining + matchPool,
            totalDeposited + handler.ghost_totalMatchClaimed(),
            "Free money detected"
        );
    }

    /// @notice Vault WBTC balance must never exceed total deposited
    function invariant_vaultBalanceBounded() public view {
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 totalDeposited = handler.ghost_totalDeposited();

        assertLe(vaultBalance, totalDeposited, "Vault balance exceeds deposits");
    }

    // ==================== Cross-Layer Invariants ====================

    /// @notice Achievement count must match ghost variable
    function invariant_achievementCountConsistency() public view {
        uint256 ghostCount = handler.ghost_achievementsMinted();
        uint256 actualCount = achievementNFT.totalSupply();

        assertEq(ghostCount, actualCount, "Achievement count mismatch");
    }

    /// @notice Vaults with issuer treasure must match ghost variable
    function invariant_issuerVaultConsistency() public view {
        uint256 ghostCount = handler.ghost_vaultsWithIssuerTreasure();
        uint256 tokenCount = handler.getMintedVaultCount();

        uint256 actualCount = 0;
        for (uint256 i = 0; i < tokenCount; i++) {
            try vault.treasureContract(i) returns (address treasure) {
                if (treasure == address(treasureNFT)) {
                    actualCount++;
                }
            } catch {}
        }

        assertEq(ghostCount, actualCount, "Issuer vault count mismatch");
    }

    /// @notice No adversary attacks should succeed
    function invariant_noAdversarySuccess() public view {
        assertFalse(
            adversary.hasCriticalVulnerability(),
            "Adversary found vulnerability"
        );
    }

    // ==================== Debug Invariant ====================

    /// @notice Print call summary for debugging
    function invariant_callSummary() public view {
        (
            uint256 mints,
            uint256 withdraws,
            uint256 redeems,
            uint256 matchClaims,
            uint256 achievementClaims,
            uint256 warps
        ) = handler.getCallSummary();

        console.log("=== Cross-Layer Invariant Test Summary ===");
        console.log("Vault mints:", mints);
        console.log("Withdrawals:", withdraws);
        console.log("Early redeems:", redeems);
        console.log("Match claims:", matchClaims);
        console.log("Achievement claims:", achievementClaims);
        console.log("Time warps:", warps);
    }
}

/// @title MultiActorScenarioTest - Scripted multi-actor scenarios
/// @notice Tests specific scenarios with multiple actors
contract MultiActorScenarioTest is Test {
    SimulationOrchestrator public orchestrator;

    VaultNFT public vault;
    BtcToken public btcToken;
    MockWBTC public wbtc;
    TreasureNFT public treasureNFT;
    AchievementNFT public achievementNFT;
    AchievementMinter public minter;

    address[] public actors;
    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;

    function setUp() public {
        orchestrator = new SimulationOrchestrator();
        (vault, btcToken, wbtc) = orchestrator.deployProtocol();
        (, AchievementMinter deployedMinter) = orchestrator.deployIssuer("TestIssuer");
        minter = deployedMinter;

        (address treasureAddr, address achievementAddr, , ) = orchestrator.getIssuer(0);
        treasureNFT = TreasureNFT(treasureAddr);
        achievementNFT = AchievementNFT(achievementAddr);

        // Create 10 actors
        for (uint256 i = 0; i < 10; i++) {
            address actor = makeAddr(string.concat("actor", vm.toString(i)));
            actors.push(actor);

            orchestrator.fundActor(actor, 100 * ONE_BTC, 0, 10);

            vm.startPrank(actor);
            wbtc.approve(address(vault), type(uint256).max);
            treasureNFT.setApprovalForAll(address(vault), true);
            vm.stopPrank();
        }
    }

    /// @notice Scenario: 10 actors mint vaults, 5 early redeem, 5 wait for vesting
    function test_Scenario_MixedBehavior() public {
        uint256[] memory vaultIds = new uint256[](10);

        // All 10 actors mint vaults
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(actors[i]);
            vaultIds[i] = vault.mint(
                address(treasureNFT),
                i * 10, // Each actor uses their first treasure
                address(wbtc),
                10 * ONE_BTC
            );
        }

        // Verify all vaults created
        assertEq(vault.balanceOf(actors[0]), 1);
        assertEq(vault.balanceOf(actors[9]), 1);

        // First 5 actors claim MINTER achievement
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(actors[i]);
            minter.claimMinterAchievement(vaultIds[i], address(wbtc));
        }

        // Verify achievements
        assertTrue(achievementNFT.hasAchievement(actors[0], keccak256("MINTER")));
        assertFalse(achievementNFT.hasAchievement(actors[5], keccak256("MINTER")));

        // Time warp 500 days
        vm.warp(block.timestamp + 500 days);

        // Actors 5-9 early redeem (funding match pool)
        for (uint256 i = 5; i < 10; i++) {
            vm.prank(actors[i]);
            vault.earlyRedeem(vaultIds[i]);
        }

        // Verify match pool has funds
        assertGt(vault.matchPool(), 0, "Match pool should have funds");

        // Time warp past vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Actors 0-4 claim match
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(actors[i]);
            vault.claimMatch(vaultIds[i]);
        }

        // Actors 0-4 claim MATURED achievement
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(actors[i]);
            minter.claimMaturedAchievement(vaultIds[i], address(wbtc));
        }

        // Verify MATURED achievements
        assertTrue(achievementNFT.hasAchievement(actors[0], keccak256("MATURED")));
        assertTrue(achievementNFT.hasAchievement(actors[4], keccak256("MATURED")));

        // Verify collateral conservation
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 sumCollaterals = 0;
        for (uint256 i = 0; i < 5; i++) {
            sumCollaterals += vault.collateralAmount(vaultIds[i]);
        }
        assertEq(vaultBalance, sumCollaterals + vault.matchPool());
    }

    /// @notice Scenario: Adversary attempts attacks on all actor vaults
    function test_Scenario_AdversaryProbe() public {
        SimAdversary adversary = new SimAdversary(
            address(vault),
            address(btcToken),
            address(wbtc),
            address(treasureNFT),
            address(minter)
        );

        // Actor 0 mints a vault
        vm.prank(actors[0]);
        uint256 vaultId = vault.mint(
            address(treasureNFT),
            0,
            address(wbtc),
            10 * ONE_BTC
        );

        // Adversary attempts all attacks
        bool[] memory results = adversary.runAllAttacks(vaultId);

        // All attacks should fail
        for (uint256 i = 0; i < results.length; i++) {
            assertFalse(results[i], "Attack should have failed");
        }

        // Verify no critical vulnerabilities
        assertFalse(adversary.hasCriticalVulnerability());

        // Verify adversary has no unexpected tokens
        assertEq(vault.balanceOf(address(adversary)), 0);
        assertEq(wbtc.balanceOf(address(adversary)), 0);
    }

    /// @notice Scenario: Race condition - multiple actors claim match simultaneously
    function test_Scenario_MatchClaimRace() public {
        // All actors mint vaults
        uint256[] memory vaultIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(actors[i]);
            vaultIds[i] = vault.mint(
                address(treasureNFT),
                i * 10,
                address(wbtc),
                10 * ONE_BTC
            );
        }

        // One actor early redeems to fund match pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(actors[9]);
        vault.earlyRedeem(vaultIds[9]);

        // Time warp past vesting for remaining actors
        vm.warp(block.timestamp + VESTING_PERIOD);

        // All remaining actors claim match in same block
        uint256 totalMatchClaimed = 0;
        for (uint256 i = 0; i < 9; i++) {
            vm.prank(actors[i]);
            uint256 claimed = vault.claimMatch(vaultIds[i]);
            totalMatchClaimed += claimed;
        }

        // Collateral conservation should hold (match pool may have dust due to rounding)
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 matchPool = vault.matchPool();
        uint256 sumCollaterals = 0;
        for (uint256 i = 0; i < 9; i++) {
            sumCollaterals += vault.collateralAmount(vaultIds[i]);
        }
        assertEq(vaultBalance, sumCollaterals + matchPool, "Collateral conservation should hold");

        // Verify fair distribution - all actors got some match share
        assertTrue(totalMatchClaimed > 0, "Some match should have been claimed");
    }

    /// @notice Scenario: Sequential withdrawals over time
    function test_Scenario_SequentialWithdrawals() public {
        // Actor 0 mints a vault
        vm.prank(actors[0]);
        uint256 vaultId = vault.mint(
            address(treasureNFT),
            0,
            address(wbtc),
            100 * ONE_BTC
        );

        uint256 initialCollateral = vault.collateralAmount(vaultId);

        // Time warp past vesting
        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // Perform 12 monthly withdrawals (1 year)
        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < 12; i++) {
            // Warp past withdrawal period
            vm.warp(block.timestamp + 30 days);

            vm.prank(actors[0]);
            uint256 withdrawn = vault.withdraw(vaultId);
            totalWithdrawn += withdrawn;
        }

        // After 12 withdrawals at 1% each, should have ~88.6% remaining
        uint256 remainingCollateral = vault.collateralAmount(vaultId);
        uint256 expectedRemaining = initialCollateral;
        for (uint256 i = 0; i < 12; i++) {
            expectedRemaining = expectedRemaining - (expectedRemaining * 1000 / 100000);
        }

        assertEq(remainingCollateral, expectedRemaining, "Remaining collateral mismatch");

        // Verify Zeno's paradox - collateral never reaches zero
        assertGt(remainingCollateral, 0, "Collateral should never reach zero");
    }
}
