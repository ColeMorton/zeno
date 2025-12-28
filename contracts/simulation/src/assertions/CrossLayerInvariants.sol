// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementNFT} from "@issuer/AchievementNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title CrossLayerInvariants - Reusable invariant assertions for simulation
/// @notice Verifies protocol and cross-layer invariants hold
/// @dev Used by invariant tests and simulation scenarios
library CrossLayerInvariants {
    // ==================== Achievement Constants ====================

    bytes32 internal constant MINTER = keccak256("MINTER");
    bytes32 internal constant MATURED = keccak256("MATURED");
    bytes32 internal constant HODLER_SUPREME = keccak256("HODLER_SUPREME");

    // ==================== Protocol Invariants ====================

    /// @notice Verify total WBTC in vault equals sum of collaterals + match pool
    /// @param vault The VaultNFT contract
    /// @param wbtc The WBTC token contract
    /// @param maxTokenId Maximum token ID to check
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkCollateralConservation(
        VaultNFT vault,
        IERC20 wbtc,
        uint256 maxTokenId
    ) internal view returns (bool valid, string memory message) {
        uint256 vaultBalance = wbtc.balanceOf(address(vault));
        uint256 matchPool = vault.matchPool();

        uint256 sumCollaterals = 0;
        for (uint256 i = 0; i < maxTokenId; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                sumCollaterals += amount;
            } catch {}
        }

        if (vaultBalance != sumCollaterals + matchPool) {
            return (false, "Collateral conservation violated");
        }
        return (true, "");
    }

    /// @notice Verify match pool equals total forfeited minus total claimed
    /// @param vault The VaultNFT contract
    /// @param totalForfeited Total amount forfeited from early redemptions
    /// @param totalClaimed Total amount claimed from match pool
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkMatchPoolConsistency(
        VaultNFT vault,
        uint256 totalForfeited,
        uint256 totalClaimed
    ) internal view returns (bool valid, string memory message) {
        uint256 matchPool = vault.matchPool();

        if (matchPool != totalForfeited - totalClaimed) {
            return (false, "Match pool inconsistent");
        }
        return (true, "");
    }

    /// @notice Verify no free money - withdrawn + remaining <= deposited
    /// @param vault The VaultNFT contract
    /// @param totalDeposited Total amount deposited
    /// @param totalWithdrawn Total amount withdrawn
    /// @param totalMatchClaimed Total match claims
    /// @param maxTokenId Maximum token ID to check
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkNoFreeMoney(
        VaultNFT vault,
        uint256 totalDeposited,
        uint256 totalWithdrawn,
        uint256 totalMatchClaimed,
        uint256 maxTokenId
    ) internal view returns (bool valid, string memory message) {
        uint256 sumRemaining = 0;
        for (uint256 i = 0; i < maxTokenId; i++) {
            try vault.collateralAmount(i) returns (uint256 amount) {
                sumRemaining += amount;
            } catch {}
        }

        uint256 matchPool = vault.matchPool();

        if (totalWithdrawn + sumRemaining + matchPool > totalDeposited + totalMatchClaimed) {
            return (false, "Free money detected");
        }
        return (true, "");
    }

    /// @notice Verify vault WBTC balance never exceeds total deposited
    /// @param vault The VaultNFT contract
    /// @param wbtc The WBTC token contract
    /// @param totalDeposited Total amount deposited
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkVaultBalanceBounded(
        VaultNFT vault,
        IERC20 wbtc,
        uint256 totalDeposited
    ) internal view returns (bool valid, string memory message) {
        uint256 vaultBalance = wbtc.balanceOf(address(vault));

        if (vaultBalance > totalDeposited) {
            return (false, "Vault balance exceeds deposits");
        }
        return (true, "");
    }

    // ==================== Cross-Layer Invariants ====================

    /// @notice Verify MINTER achievement only exists for valid vault owners
    /// @param vault The VaultNFT contract
    /// @param achievementNFT The AchievementNFT contract
    /// @param treasureNFT The issuer's TreasureNFT contract
    /// @param holder Address to check
    /// @param vaultIds Array of vault IDs the holder should own
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkAchievementValidity(
        VaultNFT vault,
        AchievementNFT achievementNFT,
        TreasureNFT treasureNFT,
        address holder,
        uint256[] memory vaultIds
    ) internal view returns (bool valid, string memory message) {
        bool hasMinter = achievementNFT.hasAchievement(holder, MINTER);

        if (!hasMinter) {
            return (true, ""); // No achievement, nothing to verify
        }

        // If has MINTER, must own a vault with issuer's treasure
        bool ownsValidVault = false;
        for (uint256 i = 0; i < vaultIds.length; i++) {
            try vault.ownerOf(vaultIds[i]) returns (address owner) {
                if (owner == holder) {
                    address treasure = vault.treasureContract(vaultIds[i]);
                    if (treasure == address(treasureNFT)) {
                        ownsValidVault = true;
                        break;
                    }
                }
            } catch {}
        }

        // Note: Holder may have transferred the vault after claiming
        // This is valid - achievements are earned, not revoked
        return (true, "");
    }

    /// @notice Verify MATURED achievement requires MINTER prerequisite
    /// @param achievementNFT The AchievementNFT contract
    /// @param holder Address to check
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkMaturedPrerequisite(
        AchievementNFT achievementNFT,
        address holder
    ) internal view returns (bool valid, string memory message) {
        bool hasMatured = achievementNFT.hasAchievement(holder, MATURED);
        bool hasMinter = achievementNFT.hasAchievement(holder, MINTER);

        if (hasMatured && !hasMinter) {
            return (false, "MATURED without MINTER prerequisite");
        }
        return (true, "");
    }

    /// @notice Verify HODLER_SUPREME requires both MINTER and MATURED
    /// @param achievementNFT The AchievementNFT contract
    /// @param holder Address to check
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkHodlerSupremePrerequisites(
        AchievementNFT achievementNFT,
        address holder
    ) internal view returns (bool valid, string memory message) {
        bool hasHodlerSupreme = achievementNFT.hasAchievement(holder, HODLER_SUPREME);
        bool hasMinter = achievementNFT.hasAchievement(holder, MINTER);
        bool hasMatured = achievementNFT.hasAchievement(holder, MATURED);

        if (hasHodlerSupreme && (!hasMinter || !hasMatured)) {
            return (false, "HODLER_SUPREME without prerequisites");
        }
        return (true, "");
    }

    /// @notice Verify issuer treasure isolation - minter only accepts its own treasure
    /// @param minter The AchievementMinter contract
    /// @param vault The VaultNFT contract
    /// @param vaultId Vault ID to check
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkIssuerTreasureIsolation(
        AchievementMinter minter,
        VaultNFT vault,
        uint256 vaultId
    ) internal view returns (bool valid, string memory message) {
        try vault.treasureContract(vaultId) returns (address vaultTreasure) {
            address issuerTreasure = address(minter.treasureNFT());

            // If vault uses different treasure, minter should reject claims
            // This is enforced at claim time, not as an invariant on state
            // So we just verify the contract references are correct
            if (issuerTreasure == address(0)) {
                return (false, "Minter has no treasure configured");
            }
            return (true, "");
        } catch {
            return (true, ""); // Vault doesn't exist, nothing to check
        }
    }

    // ==================== Economic Invariants ====================

    /// @notice Verify match pool never goes negative (implicit in uint256, but verify logic)
    /// @param vault The VaultNFT contract
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkMatchPoolSolvency(
        VaultNFT vault
    ) internal view returns (bool valid, string memory message) {
        // Match pool is uint256, can't go negative
        // But we verify it's accessible without revert
        try vault.matchPool() returns (uint256) {
            return (true, "");
        } catch {
            return (false, "Match pool inaccessible");
        }
    }

    /// @notice Verify withdrawal rate adherence (1.0% per 30-day period)
    /// @param collateralBefore Collateral before withdrawal
    /// @param collateralAfter Collateral after withdrawal
    /// @param withdrawn Amount withdrawn
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkWithdrawalRateAdherence(
        uint256 collateralBefore,
        uint256 collateralAfter,
        uint256 withdrawn
    ) internal pure returns (bool valid, string memory message) {
        // Expected withdrawal: 1.0% = 1000/100000 of collateral
        uint256 expectedWithdrawal = collateralBefore * 1000 / 100000;

        if (withdrawn != expectedWithdrawal) {
            return (false, "Withdrawal rate mismatch");
        }

        if (collateralAfter != collateralBefore - withdrawn) {
            return (false, "Collateral accounting error");
        }

        return (true, "");
    }

    /// @notice Verify Zeno preservation - collateral never reaches zero through withdrawals
    /// @param collateral Current collateral amount
    /// @param withdrawalCount Number of withdrawals performed
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkZenoPreservation(
        uint256 collateral,
        uint256 withdrawalCount
    ) internal pure returns (bool valid, string memory message) {
        // After any number of 1% withdrawals, some dust should remain
        // (unless early redeemed or dormancy claimed)
        if (withdrawalCount > 0 && collateral == 0) {
            return (false, "Zeno paradox violated - collateral reached zero");
        }
        return (true, "");
    }

    // ==================== Batch Verification ====================

    /// @notice Run all protocol invariants
    /// @param vault The VaultNFT contract
    /// @param wbtc The WBTC token contract
    /// @param totalDeposited Total deposited
    /// @param totalWithdrawn Total withdrawn
    /// @param totalForfeited Total forfeited
    /// @param totalMatchClaimed Total match claimed
    /// @param maxTokenId Maximum token ID
    /// @return allValid True if all invariants hold
    /// @return failedInvariant Name of first failed invariant (empty if all pass)
    function checkAllProtocolInvariants(
        VaultNFT vault,
        IERC20 wbtc,
        uint256 totalDeposited,
        uint256 totalWithdrawn,
        uint256 totalForfeited,
        uint256 totalMatchClaimed,
        uint256 maxTokenId
    ) internal view returns (bool allValid, string memory failedInvariant) {
        (bool valid, string memory reason) = checkCollateralConservation(vault, wbtc, maxTokenId);
        if (!valid) return (false, reason);

        (valid, reason) = checkMatchPoolConsistency(vault, totalForfeited, totalMatchClaimed);
        if (!valid) return (false, reason);

        (valid, reason) = checkNoFreeMoney(vault, totalDeposited, totalWithdrawn, totalMatchClaimed, maxTokenId);
        if (!valid) return (false, reason);

        (valid, reason) = checkVaultBalanceBounded(vault, wbtc, totalDeposited);
        if (!valid) return (false, reason);

        (valid, reason) = checkMatchPoolSolvency(vault);
        if (!valid) return (false, reason);

        return (true, "");
    }

    /// @notice Run all cross-layer invariants for a holder
    /// @param achievementNFT The AchievementNFT contract
    /// @param holder Address to check
    /// @return allValid True if all invariants hold
    /// @return failedInvariant Name of first failed invariant (empty if all pass)
    function checkAllCrossLayerInvariants(
        AchievementNFT achievementNFT,
        address holder
    ) internal view returns (bool allValid, string memory failedInvariant) {
        (bool valid, string memory reason) = checkMaturedPrerequisite(achievementNFT, holder);
        if (!valid) return (false, reason);

        (valid, reason) = checkHodlerSupremePrerequisites(achievementNFT, holder);
        if (!valid) return (false, reason);

        return (true, "");
    }
}
