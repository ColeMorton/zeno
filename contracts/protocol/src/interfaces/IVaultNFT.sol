// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVaultNFT is IERC721 {
    enum DormancyState {
        ACTIVE,
        POKE_PENDING,
        CLAIMABLE
    }

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

    event VaultMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address treasureContract,
        uint256 treasureTokenId,
        uint256 collateral
    );
    event Withdrawn(uint256 indexed tokenId, address indexed to, uint256 amount);
    event EarlyRedemption(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 returned,
        uint256 forfeited
    );
    event BtcTokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event BtcTokenReturned(uint256 indexed tokenId, address indexed from, uint256 amount);
    event MatchClaimed(uint256 indexed tokenId, uint256 amount);
    event MatchPoolFunded(uint256 amount, uint256 newBalance);
    event DormantPoked(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed poker,
        uint256 graceDeadline
    );
    event DormancyStateChanged(uint256 indexed tokenId, DormancyState newState);
    event ActivityProven(uint256 indexed tokenId, address indexed owner);
    event DormantCollateralClaimed(
        uint256 indexed tokenId,
        address indexed originalOwner,
        address indexed claimer,
        uint256 collateralClaimed
    );

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

    error NotTokenOwner(uint256 tokenId);
    error StillVesting(uint256 tokenId);
    error WithdrawalTooSoon(uint256 tokenId, uint256 nextAllowed);
    error ZeroCollateral();
    error BtcTokenAlreadyMinted(uint256 tokenId);
    error BtcTokenRequired(uint256 tokenId);
    error InsufficientBtcToken(uint256 required, uint256 available);
    error NotVested(uint256 tokenId);
    error AlreadyClaimed(uint256 tokenId);
    error NoPoolAvailable();
    error NotDormantEligible(uint256 tokenId);
    error AlreadyPoked(uint256 tokenId);
    error NotClaimable(uint256 tokenId);
    error InvalidCollateralToken(address token);
    error TokenDoesNotExist(uint256 tokenId);

    // Wallet-level delegation errors
    error ZeroAddress();
    error CannotDelegateSelf();
    error InvalidPercentage(uint256 percentage);
    error ExceedsDelegationLimit();
    error DelegateNotActive(address owner, address delegate);
    error NotActiveDelegate(uint256 tokenId, address delegate);
    error WithdrawalPeriodNotMet(uint256 tokenId, address delegate);

    // Vault-level delegation errors
    error NotVaultOwner(uint256 tokenId);
    error ExceedsVaultDelegationLimit(uint256 tokenId);
    error VaultDelegateNotActive(uint256 tokenId, address delegate);

    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 tokenId);

    function withdraw(uint256 tokenId) external returns (uint256 amount);

    function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited);

    function mintBtcToken(uint256 tokenId) external returns (uint256 amount);

    function returnBtcToken(uint256 tokenId) external;

    function claimMatch(uint256 tokenId) external returns (uint256 amount);

    function pokeDormant(uint256 tokenId) external;

    function proveActivity(uint256 tokenId) external;

    function claimDormantCollateral(uint256 tokenId) external returns (uint256 collateral);

    function isDormantEligible(uint256 tokenId)
        external
        view
        returns (bool eligible, DormancyState state);

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract,
            uint256 treasureTokenId,
            address collateralToken,
            uint256 collateralAmount,
            uint256 mintTimestamp,
            uint256 lastWithdrawal,
            uint256 lastActivity,
            uint256 btcTokenAmount,
            uint256 originalMintedAmount
        );

    function isVested(uint256 tokenId) external view returns (bool);

    function getWithdrawableAmount(uint256 tokenId) external view returns (uint256);

    function getCollateralClaim(uint256 tokenId) external view returns (uint256);

    function getClaimValue(address holder, uint256 tokenId) external view returns (uint256);

    function collateralToken() external view returns (address);

    // ========== Wallet-Level Withdrawal Delegation Functions ==========

    /// @notice Grant withdrawal delegation for all vaults owned by msg.sender
    /// @param delegate Address to delegate to
    /// @param percentageBPS Percentage of monthly pool in basis points (100 = 1%)
    function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external;

    /// @notice Revoke a specific delegate's permission
    /// @param delegate Address to revoke
    function revokeWithdrawalDelegate(address delegate) external;

    /// @notice Revoke all delegates for msg.sender's wallet
    function revokeAllWithdrawalDelegates() external;

    /// @notice Withdraw from a vault as an authorized delegate
    /// @param tokenId The vault to withdraw from
    /// @return withdrawnAmount Amount of collateral withdrawn
    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);

    /// @notice Check if delegate can withdraw from a vault and how much
    /// @param tokenId Vault token ID
    /// @param delegate Delegate address
    /// @return canWithdraw Whether withdrawal is possible now
    /// @return amount Available withdrawal amount
    /// @return delegationType The type of delegation (None, WalletLevel, VaultSpecific)
    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount, DelegationType delegationType);

    /// @notice Get wallet-level delegate permission
    /// @param owner Wallet owner address
    /// @param delegate Delegate address
    /// @return WalletDelegatePermission struct
    function getWalletDelegatePermission(address owner, address delegate)
        external
        view
        returns (WalletDelegatePermission memory);

    /// @notice Get delegate's cooldown for a specific vault
    /// @param delegate Delegate address
    /// @param tokenId Vault token ID
    /// @return Timestamp of last withdrawal by this delegate for this vault
    function getDelegateCooldown(address delegate, uint256 tokenId)
        external
        view
        returns (uint256);

    /// @notice Get total delegated BPS for a wallet
    /// @param owner Wallet owner address
    /// @return Total basis points delegated
    function walletTotalDelegatedBPS(address owner) external view returns (uint256);

    // ========== Vault-Level Delegation Functions ==========

    /// @notice Grant vault-specific withdrawal delegation
    /// @param tokenId Vault token ID
    /// @param delegate Address to delegate to
    /// @param percentageBPS Percentage of monthly pool in basis points (100 = 1%)
    /// @param durationSeconds Duration in seconds (0 = indefinite)
    function grantVaultDelegate(
        uint256 tokenId,
        address delegate,
        uint256 percentageBPS,
        uint256 durationSeconds
    ) external;

    /// @notice Revoke a vault-specific delegate's permission
    /// @param tokenId Vault token ID
    /// @param delegate Address to revoke
    function revokeVaultDelegate(uint256 tokenId, address delegate) external;

    /// @notice Get vault-specific delegate permission
    /// @param tokenId Vault token ID
    /// @param delegate Delegate address
    /// @return VaultDelegatePermission struct
    function getVaultDelegatePermission(uint256 tokenId, address delegate)
        external
        view
        returns (VaultDelegatePermission memory);

    /// @notice Get total delegated BPS for a specific vault
    /// @param tokenId Vault token ID
    /// @return Total basis points delegated for this vault
    function vaultTotalDelegatedBPS(uint256 tokenId) external view returns (uint256);

    /// @notice Get effective delegation for a vault/delegate pair (resolves precedence)
    /// @param tokenId Vault token ID
    /// @param delegate Delegate address
    /// @return percentageBPS Effective delegation percentage
    /// @return dtype Delegation type (None, WalletLevel, VaultSpecific)
    /// @return isExpired Whether the vault-specific delegation has expired
    function getEffectiveDelegation(uint256 tokenId, address delegate)
        external
        view
        returns (uint256 percentageBPS, DelegationType dtype, bool isExpired);
}
