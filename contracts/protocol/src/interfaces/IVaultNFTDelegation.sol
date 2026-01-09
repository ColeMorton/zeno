// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVaultNFTDelegation
/// @notice Interface for withdrawal delegation functionality
interface IVaultNFTDelegation {
    /// @notice Wallet-level delegation permission (applies to all vaults owned by wallet)
    struct WalletDelegatePermission {
        uint256 percentageBPS;      // Basis points (100 = 1%, 10000 = 100%)
        uint256 grantedAt;          // When permission was granted
        bool active;                // Permission status
    }

    /// @notice Vault-specific delegation permission (applies to a single vault)
    struct VaultDelegatePermission {
        uint256 percentageBPS;      // Basis points (100 = 1%, 10000 = 100%)
        uint256 grantedAt;          // When permission was granted
        uint256 expiresAt;          // 0 = no expiry, >0 = auto-expires at timestamp
        bool active;                // Permission status
    }

    /// @notice Delegation type for resolution reporting
    enum DelegationType { None, WalletLevel, VaultSpecific }

    // Wallet-level delegation events
    event WalletDelegateGranted(
        address indexed owner,
        address indexed delegate,
        uint256 percentageBPS
    );
    event WalletDelegateUpdated(
        address indexed owner,
        address indexed delegate,
        uint256 oldPercentageBPS,
        uint256 newPercentageBPS
    );
    event WalletDelegateRevoked(
        address indexed owner,
        address indexed delegate
    );
    event AllWalletDelegatesRevoked(address indexed owner);
    event DelegatedWithdrawal(
        uint256 indexed tokenId,
        address indexed delegate,
        address indexed owner,
        uint256 amount
    );

    // Vault-level delegation events
    event VaultDelegateGranted(
        uint256 indexed tokenId,
        address indexed delegate,
        uint256 percentageBPS,
        uint256 expiresAt
    );
    event VaultDelegateUpdated(
        uint256 indexed tokenId,
        address indexed delegate,
        uint256 oldPercentageBPS,
        uint256 newPercentageBPS,
        uint256 expiresAt
    );
    event VaultDelegateRevoked(
        uint256 indexed tokenId,
        address indexed delegate
    );

    // Delegation errors
    error ZeroAddress();
    error CannotDelegateSelf();
    error InvalidPercentage(uint256 percentage);
    error ExceedsDelegationLimit();
    error DelegateNotActive(address owner, address delegate);
    error NotActiveDelegate(uint256 tokenId, address delegate);
    error WithdrawalPeriodNotMet(uint256 tokenId, address delegate);
    error NotVaultOwner(uint256 tokenId);
    error ExceedsVaultDelegationLimit(uint256 tokenId);
    error VaultDelegateNotActive(uint256 tokenId, address delegate);

    // ========== Wallet-Level Delegation Functions ==========

    /// @notice Grant withdrawal delegation for all vaults owned by msg.sender
    function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external;

    /// @notice Revoke a specific delegate's permission
    function revokeWithdrawalDelegate(address delegate) external;

    /// @notice Revoke all delegates for msg.sender's wallet
    function revokeAllWithdrawalDelegates() external;

    /// @notice Withdraw from a vault as an authorized delegate
    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);

    /// @notice Check if delegate can withdraw from a vault and how much
    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount, DelegationType delegationType);

    /// @notice Get wallet-level delegate permission
    function getWalletDelegatePermission(address owner, address delegate)
        external
        view
        returns (WalletDelegatePermission memory);

    /// @notice Get delegate's cooldown for a specific vault
    function getDelegateCooldown(address delegate, uint256 tokenId)
        external
        view
        returns (uint256);

    /// @notice Get total delegated BPS for a wallet
    function walletTotalDelegatedBPS(address owner) external view returns (uint256);

    // ========== Vault-Level Delegation Functions ==========

    /// @notice Grant vault-specific withdrawal delegation
    function grantVaultDelegate(
        uint256 tokenId,
        address delegate,
        uint256 percentageBPS,
        uint256 durationSeconds
    ) external;

    /// @notice Revoke a vault-specific delegate's permission
    function revokeVaultDelegate(uint256 tokenId, address delegate) external;

    /// @notice Get vault-specific delegate permission
    function getVaultDelegatePermission(uint256 tokenId, address delegate)
        external
        view
        returns (VaultDelegatePermission memory);

    /// @notice Get total delegated BPS for a specific vault
    function vaultTotalDelegatedBPS(uint256 tokenId) external view returns (uint256);

    /// @notice Get effective delegation for a vault/delegate pair (resolves precedence)
    function getEffectiveDelegation(uint256 tokenId, address delegate)
        external
        view
        returns (uint256 percentageBPS, DelegationType dtype, bool isExpired);
}
