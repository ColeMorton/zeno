// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementNFT} from "@issuer/AchievementNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";
import {MockWBTC} from "../SimulationOrchestrator.sol";

/// @title CrossLayerHandler - Stateful handler for cross-layer invariant testing
/// @notice Extends VaultHandler pattern with achievement and treasure tracking
/// @dev Used by Foundry's invariant testing framework
contract CrossLayerHandler is Test {
    // ==================== Protocol Contracts ====================
    VaultNFT public vault;
    BtcToken public btcToken;
    MockWBTC public wbtc;

    // ==================== Issuer Contracts ====================
    TreasureNFT public treasureNFT;
    AchievementNFT public achievementNFT;
    AchievementMinter public minter;

    // ==================== Constants ====================
    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;

    // Achievement type constants
    bytes32 internal constant MINTER = keccak256("MINTER");
    bytes32 internal constant MATURED = keccak256("MATURED");
    bytes32 internal constant FIRST_MONTH = keccak256("FIRST_MONTH");

    // ==================== Actor State ====================
    address[] public actors;
    uint256[] public mintedVaultIds;
    mapping(address => uint256[]) public userVaultIds;
    mapping(address => uint256) public userTreasureOffset;
    mapping(address => uint256) public userTreasureCount;

    // ==================== Ghost Variables (Protocol) ====================
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalForfeited;
    uint256 public ghost_totalMatchClaimed;

    // ==================== Ghost Variables (Cross-Layer) ====================
    uint256 public ghost_achievementsMinted;
    uint256 public ghost_treasuresMinted;
    uint256 public ghost_vaultsWithIssuerTreasure;
    mapping(address => uint256) public ghost_userAchievementCount;

    // ==================== Call Counters ====================
    uint256 public calls_mintVault;
    uint256 public calls_withdraw;
    uint256 public calls_earlyRedeem;
    uint256 public calls_claimMatch;
    uint256 public calls_claimAchievement;
    uint256 public calls_warp;

    // ==================== Constructor ====================

    constructor(
        VaultNFT vault_,
        BtcToken btcToken_,
        MockWBTC wbtc_,
        TreasureNFT treasureNFT_,
        AchievementNFT achievementNFT_,
        AchievementMinter minter_,
        address[] memory actors_
    ) {
        vault = vault_;
        btcToken = btcToken_;
        wbtc = wbtc_;
        treasureNFT = treasureNFT_;
        achievementNFT = achievementNFT_;
        minter = minter_;
        actors = actors_;

        // Initialize treasure offsets for each actor
        uint256 treasuresPerActor = 100;
        for (uint256 i = 0; i < actors_.length; i++) {
            userTreasureOffset[actors_[i]] = i * treasuresPerActor;
        }
    }

    // ==================== Modifiers ====================

    modifier useActor(uint256 actorSeed) {
        address actor = actors[actorSeed % actors.length];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    // ==================== Handler Functions ====================

    /// @notice Mint a vault with issuer's treasure
    function mintVaultWithIssuer(
        uint256 actorSeed,
        uint256 collateral
    ) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        // Bound collateral to reasonable range
        collateral = bound(collateral, ONE_BTC / 100, 10 * ONE_BTC);

        // Check if actor has WBTC
        if (wbtc.balanceOf(actor) < collateral) return;

        // Get next treasure ID for this actor
        uint256 treasureId = userTreasureOffset[actor] + userTreasureCount[actor];

        // Check if actor owns the treasure
        try treasureNFT.ownerOf(treasureId) returns (address owner) {
            if (owner != actor) return;
        } catch {
            return;
        }

        // Mint vault
        uint256 vaultId = vault.mint(
            address(treasureNFT),
            treasureId,
            address(wbtc),
            collateral
        );

        // Update state
        mintedVaultIds.push(vaultId);
        userVaultIds[actor].push(vaultId);
        userTreasureCount[actor]++;

        // Update ghost variables
        ghost_totalDeposited += collateral;
        ghost_treasuresMinted++;
        ghost_vaultsWithIssuerTreasure++;

        calls_mintVault++;
    }

    /// @notice Withdraw from a vested vault
    function withdraw(uint256 actorSeed, uint256 vaultSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userVaultIds[actor].length == 0) return;

        uint256 vaultId = userVaultIds[actor][vaultSeed % userVaultIds[actor].length];

        // Check ownership
        if (vault.ownerOf(vaultId) != actor) return;
        if (vault.collateralAmount(vaultId) == 0) return;

        try vault.withdraw(vaultId) returns (uint256 amount) {
            ghost_totalWithdrawn += amount;
            calls_withdraw++;
        } catch {}
    }

    /// @notice Early redeem a vault (funds match pool)
    function earlyRedeem(uint256 actorSeed, uint256 vaultSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userVaultIds[actor].length == 0) return;

        uint256 vaultIdx = vaultSeed % userVaultIds[actor].length;
        uint256 vaultId = userVaultIds[actor][vaultIdx];

        if (vault.ownerOf(vaultId) != actor) return;

        try vault.earlyRedeem(vaultId) returns (uint256 returned, uint256 forfeited) {
            ghost_totalWithdrawn += returned;
            ghost_totalForfeited += forfeited;
            ghost_vaultsWithIssuerTreasure--;

            _removeVaultFromUser(actor, vaultIdx);
            calls_earlyRedeem++;
        } catch {}
    }

    /// @notice Claim match pool share
    function claimMatch(uint256 actorSeed, uint256 vaultSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userVaultIds[actor].length == 0) return;

        uint256 vaultId = userVaultIds[actor][vaultSeed % userVaultIds[actor].length];

        if (vault.ownerOf(vaultId) != actor) return;

        try vault.claimMatch(vaultId) returns (uint256 amount) {
            ghost_totalMatchClaimed += amount;
            calls_claimMatch++;
        } catch {}
    }

    /// @notice Claim MINTER achievement
    function claimMinterAchievement(uint256 actorSeed, uint256 vaultSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userVaultIds[actor].length == 0) return;

        uint256 vaultId = userVaultIds[actor][vaultSeed % userVaultIds[actor].length];

        // Check if already has achievement
        if (achievementNFT.hasAchievement(actor, MINTER)) return;

        try minter.claimMinterAchievement(vaultId, address(wbtc)) {
            ghost_achievementsMinted++;
            ghost_userAchievementCount[actor]++;
            calls_claimAchievement++;
        } catch {}
    }

    /// @notice Claim MATURED achievement
    function claimMaturedAchievement(uint256 actorSeed, uint256 vaultSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userVaultIds[actor].length == 0) return;

        uint256 vaultId = userVaultIds[actor][vaultSeed % userVaultIds[actor].length];

        // Check prerequisites
        if (!achievementNFT.hasAchievement(actor, MINTER)) return;
        if (achievementNFT.hasAchievement(actor, MATURED)) return;

        try minter.claimMaturedAchievement(vaultId, address(wbtc)) {
            ghost_achievementsMinted++;
            ghost_userAchievementCount[actor]++;
            calls_claimAchievement++;
        } catch {}
    }

    /// @notice Claim duration achievement
    function claimDurationAchievement(
        uint256 actorSeed,
        uint256 vaultSeed,
        uint256 achievementSeed
    ) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userVaultIds[actor].length == 0) return;

        uint256 vaultId = userVaultIds[actor][vaultSeed % userVaultIds[actor].length];

        // Select achievement type based on seed
        bytes32 achievementType = FIRST_MONTH; // Simplified for now

        if (achievementNFT.hasAchievement(actor, achievementType)) return;

        try minter.claimDurationAchievement(vaultId, address(wbtc), achievementType) {
            ghost_achievementsMinted++;
            ghost_userAchievementCount[actor]++;
            calls_claimAchievement++;
        } catch {}
    }

    // ==================== Time Manipulation ====================

    /// @notice Warp time forward by random amount
    function warpTime(uint256 timeSeed) external {
        uint256 timeToWarp = bound(timeSeed, 1 days, 100 days);
        vm.warp(block.timestamp + timeToWarp);
        calls_warp++;
    }

    /// @notice Warp past vesting period
    function warpPastVesting() external {
        vm.warp(block.timestamp + VESTING_PERIOD + 1);
        calls_warp++;
    }

    /// @notice Warp past withdrawal period
    function warpPastWithdrawal() external {
        vm.warp(block.timestamp + WITHDRAWAL_PERIOD + 1);
        calls_warp++;
    }

    // ==================== Internal Helpers ====================

    function _removeVaultFromUser(address user, uint256 idx) internal {
        uint256 lastIdx = userVaultIds[user].length - 1;
        if (idx != lastIdx) {
            userVaultIds[user][idx] = userVaultIds[user][lastIdx];
        }
        userVaultIds[user].pop();
    }

    // ==================== View Functions ====================

    function getMintedVaultCount() external view returns (uint256) {
        return mintedVaultIds.length;
    }

    function getActorCount() external view returns (uint256) {
        return actors.length;
    }

    function getUserVaultCount(address user) external view returns (uint256) {
        return userVaultIds[user].length;
    }

    function getCallSummary() external view returns (
        uint256 mints,
        uint256 withdraws,
        uint256 redeems,
        uint256 matchClaims,
        uint256 achievementClaims,
        uint256 warps
    ) {
        return (
            calls_mintVault,
            calls_withdraw,
            calls_earlyRedeem,
            calls_claimMatch,
            calls_claimAchievement,
            calls_warp
        );
    }

    function getGhostSummary() external view returns (
        uint256 deposited,
        uint256 withdrawn,
        uint256 forfeited,
        uint256 matchClaimed,
        uint256 achievements,
        uint256 treasures,
        uint256 issuerVaults
    ) {
        return (
            ghost_totalDeposited,
            ghost_totalWithdrawn,
            ghost_totalForfeited,
            ghost_totalMatchClaimed,
            ghost_achievementsMinted,
            ghost_treasuresMinted,
            ghost_vaultsWithIssuerTreasure
        );
    }
}
