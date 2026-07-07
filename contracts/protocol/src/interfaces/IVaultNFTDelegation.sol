// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVaultNFTDelegation
/// @notice Interface for withdrawal delegation functionality, supporting both wallet-level
/// (all vaults owned by a wallet) and vault-specific (single vault) permission grants.
/// @dev Delegates may claim their BPS-proportional share of each 1.0% monthly withdrawal pool.
/// Vault-specific delegations take precedence over wallet-level delegations when both exist.
interface IVaultNFTDelegation {
    /// @notice Wallet-level delegation permission, granting withdrawal rights across all vaults owned by a wallet.
    /// @param percentageBPS Basis points share of each 1.0% withdrawal pool (100 = 1%, 10 000 = 100%).
    /// @param epoch The owner's delegation epoch at grant time; permissions from earlier epochs
    /// (invalidated by `revokeAllWithdrawalDelegates`) are inert.
    /// @param active Whether the delegation is currently active.
    struct WalletDelegatePermission {
        uint256 percentageBPS;
        uint256 epoch;
        bool active;
    }

    /// @notice Vault-specific delegation permission, granting withdrawal rights for a single vault.
    /// @param percentageBPS Basis points share of each 1.0% withdrawal pool (100 = 1%, 10 000 = 100%).
    /// @param expiresAt Expiry timestamp; 0 = no expiry, non-zero = auto-expires at this timestamp.
    /// @param active Whether the delegation is currently active.
    struct VaultDelegatePermission {
        uint256 percentageBPS;
        uint256 expiresAt;
        bool active;
    }

    /// @notice Identifies the source of an effective delegation when resolving precedence.
    /// @dev None = no active delegation; WalletLevel = applies to all owner vaults;
    /// VaultSpecific = scoped to a single vault and takes precedence over WalletLevel.
    enum DelegationType { None, WalletLevel, VaultSpecific }

    // ========== Wallet-Level Delegation Events ==========

    /// @notice Emitted when a new wallet-level withdrawal delegate is granted.
    /// @param owner The wallet owner granting the delegation.
    /// @param delegate The address receiving withdrawal delegation rights.
    /// @param percentageBPS The delegated share in basis points.
    event WalletDelegateGranted(
        address indexed owner,
        address indexed delegate,
        uint256 percentageBPS
    );

    /// @notice Emitted when an existing wallet-level delegation percentage is updated.
    /// @param owner The wallet owner updating the delegation.
    /// @param delegate The delegate whose permission is being changed.
    /// @param oldPercentageBPS The previous delegated share in basis points.
    /// @param newPercentageBPS The new delegated share in basis points.
    event WalletDelegateUpdated(
        address indexed owner,
        address indexed delegate,
        uint256 oldPercentageBPS,
        uint256 newPercentageBPS
    );

    /// @notice Emitted when a wallet-level delegation is individually revoked.
    /// @param owner The wallet owner revoking the delegation.
    /// @param delegate The delegate whose permission was revoked.
    event WalletDelegateRevoked(
        address indexed owner,
        address indexed delegate
    );

    /// @notice Emitted when all wallet-level delegations are revoked at once via `revokeAllWithdrawalDelegates`.
    /// @param owner The wallet owner who revoked all delegates.
    event AllWalletDelegatesRevoked(address indexed owner);

    /// @notice Emitted when a delegate executes a withdrawal on behalf of a vault owner.
    /// @param tokenId The vault token ID the withdrawal was made from.
    /// @param delegate The address that executed the delegated withdrawal.
    /// @param owner The vault owner on whose behalf the withdrawal was made.
    /// @param amount The amount of collateral transferred to the delegate.
    event DelegatedWithdrawal(
        uint256 indexed tokenId,
        address indexed delegate,
        address indexed owner,
        uint256 amount
    );

    // ========== Vault-Level Delegation Events ==========

    /// @notice Emitted when a new vault-specific withdrawal delegate is granted.
    /// @param tokenId The vault token ID the delegation applies to.
    /// @param delegate The address receiving delegation rights.
    /// @param percentageBPS The delegated share in basis points.
    /// @param expiresAt The expiry timestamp (0 = no expiry).
    event VaultDelegateGranted(
        uint256 indexed tokenId,
        address indexed delegate,
        uint256 percentageBPS,
        uint256 expiresAt
    );

    /// @notice Emitted when an existing vault-specific delegation percentage is updated.
    /// @param tokenId The vault token ID.
    /// @param delegate The delegate whose permission is being changed.
    /// @param oldPercentageBPS The previous delegated share in basis points.
    /// @param newPercentageBPS The new delegated share in basis points.
    /// @param expiresAt The updated expiry timestamp (0 = no expiry).
    event VaultDelegateUpdated(
        uint256 indexed tokenId,
        address indexed delegate,
        uint256 oldPercentageBPS,
        uint256 newPercentageBPS,
        uint256 expiresAt
    );

    /// @notice Emitted when a vault-specific delegation is revoked.
    /// @param tokenId The vault token ID.
    /// @param delegate The address whose delegation was revoked.
    event VaultDelegateRevoked(
        uint256 indexed tokenId,
        address indexed delegate
    );

    // ========== Delegation Errors ==========

    /// @notice Thrown when a zero address is provided where a non-zero address is required.
    error ZeroAddress();

    /// @notice Thrown when an owner attempts to delegate withdrawal rights to themselves.
    error CannotDelegateSelf();

    /// @notice Thrown when a delegation basis points value is zero or exceeds 10 000 (100%).
    /// @param percentage The invalid percentage value provided.
    error InvalidPercentage(uint256 percentage);

    /// @notice Thrown when granting a wallet-level delegation would push `walletTotalDelegatedBPS` above 10 000.
    error ExceedsDelegationLimit();

    /// @notice Thrown when attempting to revoke a wallet-level delegate that has no active permission.
    /// @param owner The wallet owner address.
    /// @param delegate The delegate that has no active permission.
    error DelegateNotActive(address owner, address delegate);

    /// @notice Thrown when a delegate attempts to withdraw from a vault for which it has no active permission.
    /// @param tokenId The vault token ID.
    /// @param delegate The address attempting the withdrawal.
    error NotActiveDelegate(uint256 tokenId, address delegate);

    /// @notice Thrown when a delegate attempts to withdraw before the 30-day cooldown since its last withdrawal has elapsed.
    /// @param tokenId The vault token ID.
    /// @param delegate The delegate address still in cooldown.
    error WithdrawalPeriodNotMet(uint256 tokenId, address delegate);

    /// @notice Thrown when the caller is not the owner of the specified vault.
    /// @param tokenId The vault token ID.
    error NotVaultOwner(uint256 tokenId);

    /// @notice Thrown when granting a vault-specific delegation would push `vaultTotalDelegatedBPS` above 10 000.
    /// @param tokenId The vault token ID whose delegation cap would be exceeded.
    error ExceedsVaultDelegationLimit(uint256 tokenId);

    /// @notice Thrown when attempting to revoke a vault-specific delegate that has no active permission.
    /// @param tokenId The vault token ID.
    /// @param delegate The delegate address with no active permission.
    error VaultDelegateNotActive(uint256 tokenId, address delegate);

    // ========== Wallet-Level Delegation Functions ==========

    /// @notice Grant a wallet-level withdrawal delegation, applying to all vaults currently owned by the caller.
    /// @dev Total delegated BPS across all wallet-level delegates cannot exceed 10 000. If a permission
    /// already exists for this delegate, it is replaced and the aggregate BPS is adjusted accordingly.
    /// @param delegate The address to receive delegation rights.
    /// @param percentageBPS The share of each 1.0% withdrawal pool the delegate may claim, in basis points.
    function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external;

    /// @notice Revoke a specific wallet-level delegate's withdrawal permission.
    /// @dev Decrements `walletTotalDelegatedBPS` by the revoked amount and marks the permission inactive.
    /// @param delegate The address of the delegate to revoke.
    function revokeWithdrawalDelegate(address delegate) external;

    /// @notice Revoke all wallet-level delegates for the caller's wallet in a single transaction.
    /// @dev Increments the caller's delegation epoch, invalidating every existing wallet-level
    /// permission, and resets `walletTotalDelegatedBPS` to zero. Fresh grants start clean.
    function revokeAllWithdrawalDelegates() external;

    /// @notice Execute a withdrawal from a vault as an authorized delegate.
    /// @dev Vault-specific delegations take precedence over wallet-level delegations. The delegate
    /// receives their BPS-proportional share of the 1.0% monthly withdrawal pool. Subject to the
    /// same 30-day per-delegate cooldown tracked in `delegateVaultCooldown`.
    /// @param tokenId The vault token ID to withdraw from.
    /// @return withdrawnAmount The amount of collateral transferred to the caller.
    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);

    /// @notice Check whether a delegate can currently withdraw from a vault and compute the amount.
    /// @param tokenId The vault token ID to check.
    /// @param delegate The delegate address to evaluate.
    /// @return canWithdraw True if the delegate has an active, non-expired permission and its cooldown has elapsed.
    /// @return amount The collateral amount the delegate would receive if they withdrew now.
    /// @return delegationType Whether the effective permission is WalletLevel, VaultSpecific, or None.
    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount, DelegationType delegationType);

    /// @notice Get the stored wallet-level delegation permission for an owner-delegate pair.
    /// @param owner The wallet owner address.
    /// @param delegate The delegate address.
    /// @return The `WalletDelegatePermission` struct for this pair.
    function getWalletDelegatePermission(address owner, address delegate)
        external
        view
        returns (WalletDelegatePermission memory);

    /// @notice Get the timestamp of a delegate's last withdrawal from a specific vault.
    /// @param delegate The delegate address.
    /// @param tokenId The vault token ID.
    /// @return The last withdrawal timestamp (0 if the delegate has never withdrawn from this vault).
    function getDelegateCooldown(address delegate, uint256 tokenId)
        external
        view
        returns (uint256);

    /// @notice Get the total delegated basis points across all wallet-level delegates for an owner.
    /// @param owner The wallet owner address.
    /// @return The aggregate delegated BPS (max 10 000 = 100%).
    function walletTotalDelegatedBPS(address owner) external view returns (uint256);

    /// @notice Get the current delegation epoch for a wallet owner.
    /// @dev Incremented by `revokeAllWithdrawalDelegates`; wallet-level permissions granted in
    /// earlier epochs are inert.
    /// @param owner The wallet owner address.
    /// @return The current delegation epoch.
    function walletDelegationEpoch(address owner) external view returns (uint256);

    // ========== Vault-Level Delegation Functions ==========

    /// @notice Grant a vault-specific withdrawal delegation scoped to a single vault.
    /// @dev Vault-specific delegations take precedence over wallet-level delegations when both exist.
    /// Total vault-specific delegated BPS cannot exceed 10 000. Pass 0 for `durationSeconds` for no expiry.
    /// @param tokenId The vault token ID to grant delegation for.
    /// @param delegate The address to receive delegation rights.
    /// @param percentageBPS The share of each 1.0% withdrawal pool the delegate may claim, in basis points.
    /// @param durationSeconds The delegation duration in seconds (0 = no expiry).
    function grantVaultDelegate(
        uint256 tokenId,
        address delegate,
        uint256 percentageBPS,
        uint256 durationSeconds
    ) external;

    /// @notice Revoke a vault-specific delegate's withdrawal permission.
    /// @dev Decrements `vaultTotalDelegatedBPS` by the revoked amount and marks the permission inactive.
    /// @param tokenId The vault token ID to revoke delegation from.
    /// @param delegate The address of the delegate to revoke.
    function revokeVaultDelegate(uint256 tokenId, address delegate) external;

    /// @notice Get the total delegated basis points across all vault-specific delegates for a vault.
    /// @param tokenId The vault token ID.
    /// @return The aggregate vault-specific delegated BPS (max 10 000 = 100%).
    function vaultTotalDelegatedBPS(uint256 tokenId) external view returns (uint256);

    /// @notice Resolve and return the effective delegation for a vault-delegate pair.
    /// @dev Vault-specific delegation takes precedence over wallet-level. If a vault-specific
    /// permission exists (even if expired), it is returned for full visibility; callers should
    /// inspect `isExpired` before acting on the result.
    /// @param tokenId The vault token ID.
    /// @param delegate The delegate address.
    /// @return percentageBPS The effective delegated share in basis points (0 if none active).
    /// @return dtype The delegation type in effect: VaultSpecific, WalletLevel, or None.
    /// @return isExpired True if a vault-specific permission exists but its `expiresAt` has passed.
    function getEffectiveDelegation(uint256 tokenId, address delegate)
        external
        view
        returns (uint256 percentageBPS, DelegationType dtype, bool isExpired);
}
