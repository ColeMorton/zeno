// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {TreasureNFT} from "@issuer/TreasureNFT.sol";
import {AchievementMinter} from "@issuer/AchievementMinter.sol";

/// @title SimUser - Simulated user actor for testing
/// @notice Encapsulates user actions and state for simulation scenarios
/// @dev Implements IERC721Receiver to receive vault NFTs
contract SimUser is IERC721Receiver {
    // ==================== State ====================

    VaultNFT public immutable vault;
    IERC20 public immutable wbtc;
    TreasureNFT public immutable treasureNFT;
    AchievementMinter public immutable minter;

    address public immutable owner;
    string public name;

    // User's vault holdings
    uint256[] public vaultIds;
    mapping(uint256 => bool) public ownsVault;

    // Action history for replay/debugging
    ActionRecord[] public actionHistory;

    // ==================== Types ====================

    enum ActionType {
        MINT_VAULT,
        WITHDRAW,
        EARLY_REDEEM,
        CLAIM_MATCH,
        CLAIM_ACHIEVEMENT,
        SEPARATE_VBTC,
        RECOMBINE_VBTC
    }

    struct ActionRecord {
        ActionType actionType;
        uint256 vaultId;
        uint256 amount;
        uint256 timestamp;
        bool success;
    }

    // ==================== Events ====================

    event ActionExecuted(ActionType indexed actionType, uint256 vaultId, bool success);

    // ==================== Errors ====================

    error OnlyOwner();
    error InsufficientBalance(uint256 required, uint256 available);

    // ==================== Constructor ====================

    constructor(
        address vault_,
        address wbtc_,
        address treasureNFT_,
        address minter_,
        string memory name_
    ) {
        vault = VaultNFT(vault_);
        wbtc = IERC20(wbtc_);
        treasureNFT = TreasureNFT(treasureNFT_);
        minter = AchievementMinter(minter_);
        owner = msg.sender;
        name = name_;
    }

    // ==================== Modifiers ====================

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    // ==================== Setup ====================

    /// @notice Approve contracts to spend user's tokens
    function approveAll() external onlyOwner {
        wbtc.approve(address(vault), type(uint256).max);
        wbtc.approve(address(minter), type(uint256).max);
        treasureNFT.setApprovalForAll(address(vault), true);
    }

    // ==================== Vault Actions ====================

    /// @notice Mint a new vault with treasure and collateral
    /// @param treasureId The treasure NFT ID to deposit
    /// @param collateralAmount Amount of WBTC to deposit
    /// @return vaultId The minted vault ID
    function mintVault(
        uint256 treasureId,
        uint256 collateralAmount
    ) external onlyOwner returns (uint256 vaultId) {
        uint256 balanceBefore = wbtc.balanceOf(address(this));
        if (balanceBefore < collateralAmount) {
            revert InsufficientBalance(collateralAmount, balanceBefore);
        }

        vaultId = vault.mint(
            address(treasureNFT),
            treasureId,
            address(wbtc),
            collateralAmount
        );

        vaultIds.push(vaultId);
        ownsVault[vaultId] = true;

        _recordAction(ActionType.MINT_VAULT, vaultId, collateralAmount, true);
    }

    /// @notice Withdraw from a vested vault
    /// @param vaultId The vault to withdraw from
    /// @return amount Amount withdrawn
    function withdraw(uint256 vaultId) external onlyOwner returns (uint256 amount) {
        if (!ownsVault[vaultId]) {
            _recordAction(ActionType.WITHDRAW, vaultId, 0, false);
            return 0;
        }

        try vault.withdraw(vaultId) returns (uint256 withdrawn) {
            _recordAction(ActionType.WITHDRAW, vaultId, withdrawn, true);
            return withdrawn;
        } catch {
            _recordAction(ActionType.WITHDRAW, vaultId, 0, false);
            return 0;
        }
    }

    /// @notice Early redeem a vault before vesting
    /// @param vaultId The vault to redeem
    /// @return returned Amount returned to user
    /// @return forfeited Amount forfeited to match pool
    function earlyRedeem(uint256 vaultId) external onlyOwner returns (uint256 returned, uint256 forfeited) {
        if (!ownsVault[vaultId]) {
            _recordAction(ActionType.EARLY_REDEEM, vaultId, 0, false);
            return (0, 0);
        }

        try vault.earlyRedeem(vaultId) returns (uint256 r, uint256 f) {
            _removeVault(vaultId);
            _recordAction(ActionType.EARLY_REDEEM, vaultId, r, true);
            return (r, f);
        } catch {
            _recordAction(ActionType.EARLY_REDEEM, vaultId, 0, false);
            return (0, 0);
        }
    }

    /// @notice Claim match pool share for a vested vault
    /// @param vaultId The vault to claim for
    /// @return amount Amount claimed
    function claimMatch(uint256 vaultId) external onlyOwner returns (uint256 amount) {
        if (!ownsVault[vaultId]) {
            _recordAction(ActionType.CLAIM_MATCH, vaultId, 0, false);
            return 0;
        }

        try vault.claimMatch(vaultId) returns (uint256 claimed) {
            _recordAction(ActionType.CLAIM_MATCH, vaultId, claimed, true);
            return claimed;
        } catch {
            _recordAction(ActionType.CLAIM_MATCH, vaultId, 0, false);
            return 0;
        }
    }

    // ==================== Achievement Actions ====================

    /// @notice Claim MINTER achievement for a vault
    /// @param vaultId The vault to claim for
    function claimMinterAchievement(uint256 vaultId) external onlyOwner returns (bool success) {
        try minter.claimMinterAchievement(vaultId, address(wbtc)) {
            _recordAction(ActionType.CLAIM_ACHIEVEMENT, vaultId, 0, true);
            return true;
        } catch {
            _recordAction(ActionType.CLAIM_ACHIEVEMENT, vaultId, 0, false);
            return false;
        }
    }

    /// @notice Claim MATURED achievement for a vault
    /// @param vaultId The vault to claim for
    function claimMaturedAchievement(uint256 vaultId) external onlyOwner returns (bool success) {
        try minter.claimMaturedAchievement(vaultId, address(wbtc)) {
            _recordAction(ActionType.CLAIM_ACHIEVEMENT, vaultId, 1, true);
            return true;
        } catch {
            _recordAction(ActionType.CLAIM_ACHIEVEMENT, vaultId, 1, false);
            return false;
        }
    }

    /// @notice Claim a duration achievement
    /// @param vaultId The vault to claim for
    /// @param achievementType The achievement type to claim
    function claimDurationAchievement(
        uint256 vaultId,
        bytes32 achievementType
    ) external onlyOwner returns (bool success) {
        try minter.claimDurationAchievement(vaultId, address(wbtc), achievementType) {
            _recordAction(ActionType.CLAIM_ACHIEVEMENT, vaultId, 2, true);
            return true;
        } catch {
            _recordAction(ActionType.CLAIM_ACHIEVEMENT, vaultId, 2, false);
            return false;
        }
    }

    // ==================== View Functions ====================

    /// @notice Get user's vault count
    function vaultCount() external view returns (uint256) {
        return vaultIds.length;
    }

    /// @notice Get user's WBTC balance
    function wbtcBalance() external view returns (uint256) {
        return wbtc.balanceOf(address(this));
    }

    /// @notice Get action history length
    function actionCount() external view returns (uint256) {
        return actionHistory.length;
    }

    /// @notice Get a specific action record
    function getAction(uint256 index) external view returns (ActionRecord memory) {
        return actionHistory[index];
    }

    // ==================== Internal Helpers ====================

    function _recordAction(
        ActionType actionType,
        uint256 vaultId,
        uint256 amount,
        bool success
    ) internal {
        actionHistory.push(ActionRecord({
            actionType: actionType,
            vaultId: vaultId,
            amount: amount,
            timestamp: block.timestamp,
            success: success
        }));

        emit ActionExecuted(actionType, vaultId, success);
    }

    function _removeVault(uint256 vaultId) internal {
        ownsVault[vaultId] = false;

        // Find and remove from array
        for (uint256 i = 0; i < vaultIds.length; i++) {
            if (vaultIds[i] == vaultId) {
                vaultIds[i] = vaultIds[vaultIds.length - 1];
                vaultIds.pop();
                break;
            }
        }
    }

    // ==================== ERC721 Receiver ====================

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // Track received vaults
        if (msg.sender == address(vault)) {
            vaultIds.push(tokenId);
            ownsVault[tokenId] = true;
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
