// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice Minimal interface for protocol vault delegation queries (wallet-level)
interface IVaultDelegation {
    struct WalletDelegatePermission {
        uint256 percentageBPS;
        uint256 grantedAt;
        bool active;
    }

    function ownerOf(uint256 tokenId) external view returns (address);

    function canDelegateWithdraw(
        uint256 tokenId,
        address delegate
    ) external view returns (bool canWithdraw, uint256 amount);

    function getWalletDelegatePermission(
        address owner,
        address delegate
    ) external view returns (WalletDelegatePermission memory);

    function getDelegateCooldown(
        address delegate,
        uint256 tokenId
    ) external view returns (uint256);
}

/// @title WithdrawalAutomationHelper
/// @notice View functions for batch querying withdrawal eligibility across multiple vaults
/// @dev Designed for use with Gelato Web3 Functions and other automation services
contract WithdrawalAutomationHelper {
    IVaultDelegation public immutable vaultNFT;

    uint256 private constant WITHDRAWAL_PERIOD = 30 days;

    error ZeroAddress();
    error ArrayLengthMismatch();

    constructor(address _vaultNFT) {
        if (_vaultNFT == address(0)) revert ZeroAddress();
        vaultNFT = IVaultDelegation(_vaultNFT);
    }

    /// @notice Batch check withdrawal eligibility for multiple vault-delegate pairs
    /// @param tokenIds Array of vault token IDs
    /// @param delegates Array of delegate addresses (parallel with tokenIds)
    /// @return canWithdraw Array of withdrawal eligibility flags
    /// @return amounts Array of available withdrawal amounts
    function batchCanDelegateWithdraw(
        uint256[] calldata tokenIds,
        address[] calldata delegates
    ) external view returns (bool[] memory canWithdraw, uint256[] memory amounts) {
        if (tokenIds.length != delegates.length) revert ArrayLengthMismatch();

        canWithdraw = new bool[](tokenIds.length);
        amounts = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            (canWithdraw[i], amounts[i]) = vaultNFT.canDelegateWithdraw(
                tokenIds[i],
                delegates[i]
            );
        }
    }

    /// @notice Calculate timestamp when next withdrawal is possible for a delegate on a vault
    /// @param tokenId Vault token ID
    /// @param delegate Delegate address
    /// @return nextWithdrawal Timestamp when next withdrawal is possible (0 if can withdraw now)
    function getNextWithdrawalTime(
        uint256 tokenId,
        address delegate
    ) external view returns (uint256 nextWithdrawal) {
        address owner = vaultNFT.ownerOf(tokenId);
        IVaultDelegation.WalletDelegatePermission memory perm = vaultNFT.getWalletDelegatePermission(
            owner,
            delegate
        );

        if (!perm.active) return type(uint256).max;

        uint256 lastWithdrawal = vaultNFT.getDelegateCooldown(delegate, tokenId);
        if (lastWithdrawal == 0) return 0;

        uint256 nextAllowed = lastWithdrawal + WITHDRAWAL_PERIOD;
        if (block.timestamp >= nextAllowed) return 0;

        return nextAllowed;
    }

    /// @notice Get full automation status for a vault-delegate pair
    /// @param tokenId Vault token ID
    /// @param delegate Delegate address
    /// @return canWithdraw Whether withdrawal is possible now
    /// @return amount Available withdrawal amount
    /// @return nextWithdrawal Timestamp of next allowed withdrawal (0 if now)
    /// @return percentageBPS Delegate's percentage allocation in basis points
    function getAutomationStatus(
        uint256 tokenId,
        address delegate
    )
        external
        view
        returns (
            bool canWithdraw,
            uint256 amount,
            uint256 nextWithdrawal,
            uint256 percentageBPS
        )
    {
        (canWithdraw, amount) = vaultNFT.canDelegateWithdraw(tokenId, delegate);

        address owner = vaultNFT.ownerOf(tokenId);
        IVaultDelegation.WalletDelegatePermission memory perm = vaultNFT.getWalletDelegatePermission(
            owner,
            delegate
        );

        percentageBPS = perm.percentageBPS;

        if (!perm.active) {
            nextWithdrawal = type(uint256).max;
        } else {
            uint256 lastWithdrawal = vaultNFT.getDelegateCooldown(delegate, tokenId);
            if (lastWithdrawal == 0) {
                nextWithdrawal = 0;
            } else {
                uint256 nextAllowed = lastWithdrawal + WITHDRAWAL_PERIOD;
                nextWithdrawal = block.timestamp >= nextAllowed ? 0 : nextAllowed;
            }
        }
    }
}
