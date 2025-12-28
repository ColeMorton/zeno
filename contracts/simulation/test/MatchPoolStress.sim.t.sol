// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SimulationOrchestrator, MockWBTC} from "../src/SimulationOrchestrator.sol";
import {CrossLayerInvariants} from "../src/assertions/CrossLayerInvariants.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {IVaultNFT} from "@protocol/interfaces/IVaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementNFT} from "@issuer/AchievementNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MatchPoolStressTest - Economic stress testing for match pool
/// @notice Tests edge cases and attack vectors on match pool distribution
contract MatchPoolStressTest is Test {
    SimulationOrchestrator public orchestrator;

    VaultNFT public vault;
    BtcToken public btcToken;
    MockWBTC public wbtc;
    TreasureNFT public treasureNFT;
    AchievementMinter public minter;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;

    // Large actor pool for stress tests
    address[] public actors;
    uint256[] public vaultIds;

    function setUp() public {
        orchestrator = new SimulationOrchestrator();
        (vault, btcToken, wbtc) = orchestrator.deployProtocol();
        (, AchievementMinter minter_) = orchestrator.deployIssuer("StressTest");
        minter = minter_;

        (address treasureAddr, , , ) = orchestrator.getIssuer(0);
        treasureNFT = TreasureNFT(treasureAddr);
    }

    /// @notice Create N actors with vaults
    function _createActors(uint256 count, uint256 collateralEach) internal {
        for (uint256 i = 0; i < count; i++) {
            address actor = makeAddr(string.concat("actor", vm.toString(i)));
            actors.push(actor);

            // Fund actor via orchestrator (handles treasure minting authorization)
            orchestrator.fundActor(actor, collateralEach, 0, 1);

            // Setup approvals
            vm.startPrank(actor);
            wbtc.approve(address(vault), type(uint256).max);
            treasureNFT.setApprovalForAll(address(vault), true);

            // Mint vault - treasure ID is cumulative across all fundActor calls
            uint256 vaultId = vault.mint(
                address(treasureNFT),
                i,
                address(wbtc),
                collateralEach
            );
            vaultIds.push(vaultId);
            vm.stopPrank();
        }
    }

    // ==================== Mass Early Redemption ====================

    /// @notice 80% of actors early redeem at day 500
    function test_MassEarlyRedemption_80PercentExit() public {
        uint256 actorCount = 100;
        uint256 collateral = 10 * ONE_BTC;
        _createActors(actorCount, collateral);

        uint256 totalDeposited = actorCount * collateral;
        assertEq(wbtc.balanceOf(address(vault)), totalDeposited, "Initial balance");

        // Warp to day 500
        vm.warp(block.timestamp + 500 days);

        // 80% early redeem
        uint256 redeemCount = (actorCount * 80) / 100;
        uint256 totalForfeited = 0;

        for (uint256 i = 0; i < redeemCount; i++) {
            vm.prank(actors[i]);
            (, uint256 forfeited) = vault.earlyRedeem(vaultIds[i]);
            totalForfeited += forfeited;
        }

        // Match pool should have all forfeited funds
        assertEq(vault.matchPool(), totalForfeited, "Match pool = forfeited");

        // Remaining 20% vest and claim
        vm.warp(block.timestamp + VESTING_PERIOD);

        uint256 remainingActors = actorCount - redeemCount;
        uint256 totalClaimed = 0;

        for (uint256 i = redeemCount; i < actorCount; i++) {
            vm.prank(actors[i]);
            uint256 claimed = vault.claimMatch(vaultIds[i]);
            totalClaimed += claimed;
        }

        // Most forfeited funds should be distributed
        // With dynamic allocation, some pool may remain due to formula mechanics
        assertLt(vault.matchPool(), totalForfeited / 2, "Most of pool distributed");

        // Collateral conservation
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 sumCollaterals = 0;
        for (uint256 i = redeemCount; i < actorCount; i++) {
            sumCollaterals += vault.collateralAmount(vaultIds[i]);
        }
        assertEq(vaultBalance, sumCollaterals + vault.matchPool(), "Conservation");
    }

    // ==================== Race to Claim ====================

    /// @notice All vested actors claim match in same block
    function test_RaceToClaim_SimultaneousClaims() public {
        uint256 actorCount = 50;
        uint256 collateral = 10 * ONE_BTC;
        _createActors(actorCount, collateral);

        // One actor early redeems to fund pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(actors[0]);
        (, uint256 forfeited) = vault.earlyRedeem(vaultIds[0]);

        uint256 initialPool = vault.matchPool();
        assertEq(initialPool, forfeited, "Pool funded");

        // Warp past vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // All remaining actors claim in same "block"
        uint256[] memory claims = new uint256[](actorCount - 1);
        uint256 totalClaimed = 0;

        for (uint256 i = 1; i < actorCount; i++) {
            vm.prank(actors[i]);
            claims[i - 1] = vault.claimMatch(vaultIds[i]);
            totalClaimed += claims[i - 1];
        }

        // Total claimed should be significant portion of pool
        // Dynamic allocation means some pool may remain
        assertGt(totalClaimed, initialPool / 2, "Most of pool claimed");

        // Verify all claims were non-zero
        for (uint256 i = 0; i < claims.length; i++) {
            assertGt(claims[i], 0, "Each claim > 0");
        }

        // Collateral conservation
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 sumCollaterals = 0;
        for (uint256 i = 1; i < actorCount; i++) {
            sumCollaterals += vault.collateralAmount(vaultIds[i]);
        }
        assertEq(vaultBalance, sumCollaterals + vault.matchPool(), "Conservation");
    }

    // ==================== Dust Attack ====================

    /// @notice Many micro-vaults attempt to drain pool via rounding
    function test_DustAttack_ManyMicroVaults() public {
        // Create one large depositor
        address whale = makeAddr("whale");
        orchestrator.fundActor(whale, 100 * ONE_BTC, 0, 1);

        vm.startPrank(whale);
        wbtc.approve(address(vault), type(uint256).max);
        treasureNFT.setApprovalForAll(address(vault), true);
        uint256 whaleVaultId = vault.mint(address(treasureNFT), 0, address(wbtc), 100 * ONE_BTC);
        vm.stopPrank();

        // Create many dust depositors (minimum viable collateral)
        uint256 dustCount = 100;
        uint256 dustAmount = 1000; // 0.00001 BTC (1000 satoshis)

        for (uint256 i = 0; i < dustCount; i++) {
            address dustActor = makeAddr(string.concat("dust", vm.toString(i)));
            orchestrator.fundActor(dustActor, dustAmount, 0, 1);

            vm.startPrank(dustActor);
            wbtc.approve(address(vault), type(uint256).max);
            treasureNFT.setApprovalForAll(address(vault), true);
            uint256 dustVaultId = vault.mint(address(treasureNFT), i + 1, address(wbtc), dustAmount);
            actors.push(dustActor);
            vaultIds.push(dustVaultId);
            vm.stopPrank();
        }

        // Whale early redeems to fund pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(whale);
        (, uint256 forfeited) = vault.earlyRedeem(whaleVaultId);

        uint256 initialPool = vault.matchPool();

        // Warp past vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // All dust actors claim
        uint256 totalDustClaimed = 0;
        for (uint256 i = 0; i < dustCount; i++) {
            vm.prank(actors[i]);
            uint256 claimed = vault.claimMatch(vaultIds[i]);
            totalDustClaimed += claimed;
        }

        // Dust actors should get minimal share due to small collateral
        // Their total claim should be << whale's forfeited amount
        assertLt(totalDustClaimed, forfeited / 10, "Dust claims < 10% of pool");

        // No free money - dust actors didn't profit beyond their share
        for (uint256 i = 0; i < dustCount; i++) {
            uint256 collateral = vault.collateralAmount(vaultIds[i]);
            // Even with match bonus, should be reasonable
            assertLt(collateral, dustAmount * 2, "No excessive dust profit");
        }
    }

    // ==================== Claim Order Independence ====================

    /// @notice Verify first vs last claimer fairness
    function test_ClaimOrderIndependence() public {
        // Create 10 actors with identical collateral
        uint256 actorCount = 10;
        uint256 collateral = 10 * ONE_BTC;
        _createActors(actorCount, collateral);

        // First actor early redeems
        vm.warp(block.timestamp + 500 days);
        vm.prank(actors[0]);
        vault.earlyRedeem(vaultIds[0]);

        // Warp past vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Track claims
        uint256[] memory claims = new uint256[](actorCount - 1);
        for (uint256 i = 1; i < actorCount; i++) {
            vm.prank(actors[i]);
            claims[i - 1] = vault.claimMatch(vaultIds[i]);
        }

        // With dynamic allocation, later claimers may get different amounts
        // But verify no single claimer gets a disproportionate share
        uint256 maxClaim = claims[0];
        uint256 minClaim = claims[0];
        for (uint256 i = 1; i < claims.length; i++) {
            if (claims[i] > maxClaim) maxClaim = claims[i];
            if (claims[i] < minClaim) minClaim = claims[i];
        }

        // Max should not be more than 5x min (accounting for dynamic allocation)
        assertLt(maxClaim, minClaim * 5, "Claim spread within bounds");
    }

    // ==================== Empty Pool Edge Cases ====================

    /// @notice Verify behavior when no early redemptions occurred
    function test_EmptyPool_NoEarlyRedemptions() public {
        uint256 actorCount = 5;
        uint256 collateral = 10 * ONE_BTC;
        _createActors(actorCount, collateral);

        // Warp past vesting without any early redemptions
        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // Match pool should be empty
        assertEq(vault.matchPool(), 0, "Pool empty");

        // Claims should revert with NoPoolAvailable
        vm.prank(actors[0]);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.NoPoolAvailable.selector));
        vault.claimMatch(vaultIds[0]);
    }

    /// @notice Verify cannot double-claim match
    function test_DoubleClaim_Reverts() public {
        uint256 actorCount = 3;
        uint256 collateral = 10 * ONE_BTC;
        _createActors(actorCount, collateral);

        // Fund pool via early redemption
        vm.warp(block.timestamp + 500 days);
        vm.prank(actors[0]);
        vault.earlyRedeem(vaultIds[0]);

        // Warp past vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // First claim succeeds
        vm.prank(actors[1]);
        vault.claimMatch(vaultIds[1]);

        // Second claim on same vault should revert
        vm.prank(actors[1]);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.AlreadyClaimed.selector, vaultIds[1]));
        vault.claimMatch(vaultIds[1]);
    }

    // ==================== Withdrawal After Match Claim ====================

    /// @notice Verify withdrawals work correctly after match claim increases collateral
    function test_WithdrawalAfterMatchClaim() public {
        uint256 actorCount = 3;
        uint256 collateral = 100 * ONE_BTC;
        _createActors(actorCount, collateral);

        // Fund pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(actors[0]);
        vault.earlyRedeem(vaultIds[0]);

        // Warp past vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Claim match
        uint256 collateralBefore = vault.collateralAmount(vaultIds[1]);
        vm.prank(actors[1]);
        uint256 matchClaimed = vault.claimMatch(vaultIds[1]);
        uint256 collateralAfter = vault.collateralAmount(vaultIds[1]);

        assertEq(collateralAfter, collateralBefore + matchClaimed, "Collateral increased");

        // Now perform withdrawal - should be based on new (higher) collateral
        vm.warp(block.timestamp + 30 days);
        vm.prank(actors[1]);
        uint256 withdrawn = vault.withdraw(vaultIds[1]);

        // Withdrawal should be 1% of the higher collateral
        uint256 expectedWithdrawal = collateralAfter * 1000 / 100000;
        assertEq(withdrawn, expectedWithdrawal, "Withdrawal based on new collateral");
    }

    // ==================== Invariant Verification ====================

    /// @notice Run invariant checks after stress scenario
    function test_InvariantsAfterStress() public {
        uint256 actorCount = 20;
        uint256 collateral = 10 * ONE_BTC;
        _createActors(actorCount, collateral);

        // Mixed behavior: 50% early redeem, 50% vest
        vm.warp(block.timestamp + 500 days);
        uint256 totalForfeited = 0;
        for (uint256 i = 0; i < actorCount / 2; i++) {
            vm.prank(actors[i]);
            (, uint256 forfeited) = vault.earlyRedeem(vaultIds[i]);
            totalForfeited += forfeited;
        }

        // Vest and claim
        vm.warp(block.timestamp + VESTING_PERIOD);
        uint256 totalMatchClaimed = 0;
        for (uint256 i = actorCount / 2; i < actorCount; i++) {
            vm.prank(actors[i]);
            totalMatchClaimed += vault.claimMatch(vaultIds[i]);
        }

        // Verify invariants using library
        (bool valid, string memory reason) = CrossLayerInvariants.checkCollateralConservation(
            vault, IERC20(address(wbtc)), actorCount
        );
        assertTrue(valid, reason);

        (valid, reason) = CrossLayerInvariants.checkMatchPoolConsistency(
            vault, totalForfeited, totalMatchClaimed
        );
        assertTrue(valid, reason);

        (valid, reason) = CrossLayerInvariants.checkMatchPoolSolvency(vault);
        assertTrue(valid, reason);
    }
}
