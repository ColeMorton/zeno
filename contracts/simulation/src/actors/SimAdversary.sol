// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {BtcToken} from "@protocol/BtcToken.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";

/// @title SimAdversary - Adversarial actor for security testing
/// @notice Attempts unauthorized operations and edge case exploits
/// @dev Used to verify protocol resilience against malicious actors
contract SimAdversary is IERC721Receiver {
    // ==================== State ====================

    VaultNFT public immutable vault;
    BtcToken public immutable btcToken;
    IERC20 public immutable wbtc;
    TreasureNFT public immutable treasureNFT;
    AchievementMinter public immutable minter;

    address public immutable owner;

    // Attack tracking
    AttackRecord[] public attackHistory;
    uint256 public successfulAttacks;
    uint256 public failedAttacks;

    // ==================== Types ====================

    enum AttackType {
        WITHDRAW_OTHERS_VAULT,
        CLAIM_OTHERS_ACHIEVEMENT,
        DOUBLE_CLAIM_MATCH,
        POKE_ACTIVE_VAULT,
        CLAIM_UNOWNED_DORMANT,
        MINT_WITHOUT_TREASURE,
        BYPASS_VESTING,
        REENTRANCY_ATTEMPT
    }

    struct AttackRecord {
        AttackType attackType;
        uint256 targetVaultId;
        address targetUser;
        uint256 timestamp;
        bool succeeded;
        string result;
    }

    // ==================== Events ====================

    event AttackAttempted(AttackType indexed attackType, bool succeeded);

    // ==================== Constructor ====================

    constructor(
        address vault_,
        address btcToken_,
        address wbtc_,
        address treasureNFT_,
        address minter_
    ) {
        vault = VaultNFT(vault_);
        btcToken = BtcToken(btcToken_);
        wbtc = IERC20(wbtc_);
        treasureNFT = TreasureNFT(treasureNFT_);
        minter = AchievementMinter(minter_);
        owner = msg.sender;
    }

    // ==================== Attack Functions ====================

    /// @notice Attempt to withdraw from another user's vault
    /// @param vaultId Target vault ID
    /// @return succeeded Whether the attack succeeded (should always be false)
    function tryWithdrawOthersVault(uint256 vaultId) external returns (bool succeeded) {
        try vault.withdraw(vaultId) returns (uint256) {
            _recordAttack(AttackType.WITHDRAW_OTHERS_VAULT, vaultId, address(0), true, "CRITICAL: Withdrew from other's vault");
            successfulAttacks++;
            return true;
        } catch Error(string memory reason) {
            _recordAttack(AttackType.WITHDRAW_OTHERS_VAULT, vaultId, address(0), false, reason);
            failedAttacks++;
            return false;
        } catch {
            _recordAttack(AttackType.WITHDRAW_OTHERS_VAULT, vaultId, address(0), false, "Reverted without reason");
            failedAttacks++;
            return false;
        }
    }

    /// @notice Attempt to claim achievement for another user's vault
    /// @param vaultId Target vault ID
    /// @return succeeded Whether the attack succeeded (should always be false)
    function tryClaimOthersAchievement(uint256 vaultId) external returns (bool succeeded) {
        try minter.claimMinterAchievement(vaultId, address(wbtc)) {
            _recordAttack(AttackType.CLAIM_OTHERS_ACHIEVEMENT, vaultId, address(0), true, "CRITICAL: Claimed other's achievement");
            successfulAttacks++;
            return true;
        } catch Error(string memory reason) {
            _recordAttack(AttackType.CLAIM_OTHERS_ACHIEVEMENT, vaultId, address(0), false, reason);
            failedAttacks++;
            return false;
        } catch {
            _recordAttack(AttackType.CLAIM_OTHERS_ACHIEVEMENT, vaultId, address(0), false, "Reverted");
            failedAttacks++;
            return false;
        }
    }

    /// @notice Attempt to claim match twice from same vault
    /// @param vaultId Target vault ID (must be owned by adversary)
    /// @return succeeded Whether the second claim succeeded (should always be false)
    function tryDoubleClaimMatch(uint256 vaultId) external returns (bool succeeded) {
        // First claim should work if we own the vault
        try vault.claimMatch(vaultId) {} catch {}

        // Second claim should fail
        try vault.claimMatch(vaultId) returns (uint256) {
            _recordAttack(AttackType.DOUBLE_CLAIM_MATCH, vaultId, address(0), true, "CRITICAL: Double claimed match");
            successfulAttacks++;
            return true;
        } catch Error(string memory reason) {
            _recordAttack(AttackType.DOUBLE_CLAIM_MATCH, vaultId, address(0), false, reason);
            failedAttacks++;
            return false;
        } catch {
            _recordAttack(AttackType.DOUBLE_CLAIM_MATCH, vaultId, address(0), false, "Reverted");
            failedAttacks++;
            return false;
        }
    }

    /// @notice Attempt to poke an active vault for dormancy claim
    /// @param vaultId Target vault ID
    /// @return succeeded Whether the attack succeeded (should always be false for active vaults)
    function tryPokeActiveVault(uint256 vaultId) external returns (bool succeeded) {
        try vault.pokeDormant(vaultId) {
            _recordAttack(AttackType.POKE_ACTIVE_VAULT, vaultId, address(0), true, "Poked vault (may be valid if inactive)");
            // This isn't necessarily an attack success - could be legitimate
            return true;
        } catch Error(string memory reason) {
            _recordAttack(AttackType.POKE_ACTIVE_VAULT, vaultId, address(0), false, reason);
            failedAttacks++;
            return false;
        } catch {
            _recordAttack(AttackType.POKE_ACTIVE_VAULT, vaultId, address(0), false, "Reverted");
            failedAttacks++;
            return false;
        }
    }

    /// @notice Attempt to claim dormant collateral without owning vBTC
    /// @param vaultId Target vault ID
    /// @return succeeded Whether the attack succeeded (should always be false)
    function tryClaimUnownedDormant(uint256 vaultId) external returns (bool succeeded) {
        try vault.claimDormantCollateral(vaultId) {
            _recordAttack(AttackType.CLAIM_UNOWNED_DORMANT, vaultId, address(0), true, "CRITICAL: Claimed dormant without vBTC");
            successfulAttacks++;
            return true;
        } catch Error(string memory reason) {
            _recordAttack(AttackType.CLAIM_UNOWNED_DORMANT, vaultId, address(0), false, reason);
            failedAttacks++;
            return false;
        } catch {
            _recordAttack(AttackType.CLAIM_UNOWNED_DORMANT, vaultId, address(0), false, "Reverted");
            failedAttacks++;
            return false;
        }
    }

    /// @notice Attempt to withdraw before vesting is complete
    /// @param vaultId Target vault ID (must be owned by adversary)
    /// @return succeeded Whether the attack succeeded (should always be false before vesting)
    function tryBypassVesting(uint256 vaultId) external returns (bool succeeded) {
        // Try to withdraw on an unvested vault
        try vault.withdraw(vaultId) returns (uint256) {
            _recordAttack(AttackType.BYPASS_VESTING, vaultId, address(0), true, "CRITICAL: Withdrew before vesting");
            successfulAttacks++;
            return true;
        } catch Error(string memory reason) {
            _recordAttack(AttackType.BYPASS_VESTING, vaultId, address(0), false, reason);
            failedAttacks++;
            return false;
        } catch {
            _recordAttack(AttackType.BYPASS_VESTING, vaultId, address(0), false, "Reverted");
            failedAttacks++;
            return false;
        }
    }

    // ==================== Batch Attack Functions ====================

    /// @notice Run all attacks against a target vault
    /// @param vaultId Target vault ID
    /// @return results Array of attack results
    function runAllAttacks(uint256 vaultId) external returns (bool[] memory results) {
        results = new bool[](6);

        results[0] = this.tryWithdrawOthersVault(vaultId);
        results[1] = this.tryClaimOthersAchievement(vaultId);
        results[2] = this.tryDoubleClaimMatch(vaultId);
        results[3] = this.tryPokeActiveVault(vaultId);
        results[4] = this.tryClaimUnownedDormant(vaultId);
        results[5] = this.tryBypassVesting(vaultId);

        return results;
    }

    // ==================== View Functions ====================

    /// @notice Get attack history length
    function attackCount() external view returns (uint256) {
        return attackHistory.length;
    }

    /// @notice Get a specific attack record
    function getAttack(uint256 index) external view returns (AttackRecord memory) {
        return attackHistory[index];
    }

    /// @notice Get attack statistics
    function getStats() external view returns (uint256 successful, uint256 failed) {
        return (successfulAttacks, failedAttacks);
    }

    /// @notice Check if any critical attacks succeeded
    /// @return hasCritical True if any attack that should never succeed did succeed
    function hasCriticalVulnerability() external view returns (bool hasCritical) {
        return successfulAttacks > 0;
    }

    // ==================== Internal Helpers ====================

    function _recordAttack(
        AttackType attackType,
        uint256 targetVaultId,
        address targetUser,
        bool succeeded,
        string memory result
    ) internal {
        attackHistory.push(AttackRecord({
            attackType: attackType,
            targetVaultId: targetVaultId,
            targetUser: targetUser,
            timestamp: block.timestamp,
            succeeded: succeeded,
            result: result
        }));

        emit AttackAttempted(attackType, succeeded);
    }

    // ==================== ERC721 Receiver ====================

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
