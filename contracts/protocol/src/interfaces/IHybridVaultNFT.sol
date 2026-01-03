// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IBtcToken} from "./IBtcToken.sol";

/// @title IHybridVaultNFT
/// @notice Interface for dual-collateral vault NFT with asymmetric withdrawal models
/// @dev Primary collateral: 1% monthly perpetual withdrawal (Zeno's paradox)
/// @dev Secondary collateral: 100% one-time withdrawal at full vesting
interface IHybridVaultNFT is IERC721 {
    // ========== Enums ==========

    enum DormancyState {
        ACTIVE,
        POKE_PENDING,
        CLAIMABLE
    }

    // ========== Structs ==========

    /// @notice Wallet-level delegation permission (applies to all vaults owned by wallet)
    struct WalletDelegatePermission {
        uint256 percentageBPS;
        uint256 grantedAt;
        bool active;
    }

    /// @notice Vault-specific delegation permission (applies to a single vault)
    struct VaultDelegatePermission {
        uint256 percentageBPS;
        uint256 grantedAt;
        uint256 expiresAt;
        bool active;
    }

    /// @notice Delegation type for resolution reporting
    enum DelegationType {
        None,
        WalletLevel,
        VaultSpecific
    }

    // ========== Events ==========

    event HybridVaultMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address treasureContract,
        uint256 treasureTokenId,
        uint256 primaryAmount,
        uint256 secondaryAmount
    );

    event PrimaryWithdrawn(uint256 indexed tokenId, address indexed to, uint256 amount);

    event SecondaryWithdrawn(uint256 indexed tokenId, address indexed to, uint256 amount);

    event HybridEarlyRedemption(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 primaryReturned,
        uint256 primaryForfeited,
        uint256 secondaryReturned,
        uint256 secondaryForfeited
    );

    event BtcTokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount);

    event BtcTokenReturned(uint256 indexed tokenId, address indexed from, uint256 amount);

    event PrimaryMatchClaimed(uint256 indexed tokenId, uint256 amount);

    event SecondaryMatchClaimed(uint256 indexed tokenId, uint256 amount);

    event PrimaryMatchPoolFunded(uint256 amount, uint256 newBalance);

    event SecondaryMatchPoolFunded(uint256 amount, uint256 newBalance);

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
        uint256 primaryClaimed,
        uint256 secondaryClaimed
    );

    // Wallet-level delegation events
    event WalletDelegateGranted(address indexed owner, address indexed delegate, uint256 percentageBPS);

    event WalletDelegateUpdated(
        address indexed owner,
        address indexed delegate,
        uint256 oldPercentageBPS,
        uint256 newPercentageBPS
    );

    event WalletDelegateRevoked(address indexed owner, address indexed delegate);

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

    event VaultDelegateRevoked(uint256 indexed tokenId, address indexed delegate);

    // ========== Errors ==========

    error ZeroPrimaryCollateral();
    error ZeroSecondaryCollateral();
    error StillVesting(uint256 tokenId);
    error PrimaryWithdrawalTooSoon(uint256 tokenId, uint256 nextAllowed);
    error SecondaryAlreadyWithdrawn(uint256 tokenId);
    error NotTokenOwner(uint256 tokenId);
    error BtcTokenAlreadyMinted(uint256 tokenId);
    error BtcTokenRequired(uint256 tokenId);
    error InsufficientBtcToken(uint256 required, uint256 available);
    error NotDormantEligible(uint256 tokenId);
    error AlreadyPoked(uint256 tokenId);
    error NotClaimable(uint256 tokenId);
    error NotVested(uint256 tokenId);
    error AlreadyClaimed(uint256 tokenId);
    error NoPoolAvailable();

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

    // ========== Core Functions ==========

    /// @notice Mint a new hybrid vault with dual collateral
    /// @param treasureContract Address of the treasure NFT contract
    /// @param treasureTokenId Token ID of the treasure NFT to deposit
    /// @param primaryAmount Amount of primary collateral (cbBTC)
    /// @param secondaryAmount Amount of secondary collateral (any ERC-20)
    /// @return tokenId The minted vault token ID
    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        uint256 primaryAmount,
        uint256 secondaryAmount
    ) external returns (uint256 tokenId);

    /// @notice Withdraw 1% of primary collateral monthly (Zeno's paradox)
    /// @param tokenId The vault token ID
    /// @return amount Amount of primary collateral withdrawn
    function withdrawPrimary(uint256 tokenId) external returns (uint256 amount);

    /// @notice Withdraw 100% of secondary collateral (one-time at vesting)
    /// @param tokenId The vault token ID
    /// @return amount Amount of secondary collateral withdrawn
    function withdrawSecondary(uint256 tokenId) external returns (uint256 amount);

    /// @notice Early redeem vault before vesting completes
    /// @param tokenId The vault token ID
    /// @return primaryReturned Amount of primary collateral returned
    /// @return primaryForfeited Amount of primary collateral forfeited to match pool
    /// @return secondaryReturned Amount of secondary collateral returned
    /// @return secondaryForfeited Amount of secondary collateral forfeited to match pool
    function earlyRedeem(uint256 tokenId)
        external
        returns (
            uint256 primaryReturned,
            uint256 primaryForfeited,
            uint256 secondaryReturned,
            uint256 secondaryForfeited
        );

    // ========== vestedBTC Separation (Primary Only) ==========

    /// @notice Mint vestedBTC tokens representing primary collateral claim
    /// @param tokenId The vault token ID
    /// @return amount Amount of vestedBTC minted
    function mintBtcToken(uint256 tokenId) external returns (uint256 amount);

    /// @notice Return vestedBTC tokens to recombine with vault
    /// @param tokenId The vault token ID
    function returnBtcToken(uint256 tokenId) external;

    // ========== Match Pool Claims ==========

    /// @notice Claim share of primary match pool
    /// @param tokenId The vault token ID
    /// @return amount Amount of primary collateral claimed
    function claimPrimaryMatch(uint256 tokenId) external returns (uint256 amount);

    /// @notice Claim share of secondary match pool
    /// @param tokenId The vault token ID
    /// @return amount Amount of secondary collateral claimed
    function claimSecondaryMatch(uint256 tokenId) external returns (uint256 amount);

    // ========== Dormancy Functions ==========

    /// @notice Poke a dormant vault to start grace period
    /// @param tokenId The vault token ID
    function pokeDormant(uint256 tokenId) external;

    /// @notice Prove activity to reset dormancy state
    /// @param tokenId The vault token ID
    function proveActivity(uint256 tokenId) external;

    /// @notice Claim collateral from a dormant vault after grace period
    /// @param tokenId The vault token ID
    /// @return primary Amount of primary collateral claimed
    /// @return secondary Amount of secondary collateral claimed
    function claimDormantCollateral(uint256 tokenId) external returns (uint256 primary, uint256 secondary);

    /// @notice Check if vault is dormant eligible
    /// @param tokenId The vault token ID
    /// @return eligible Whether the vault is dormant eligible
    /// @return state The current dormancy state
    function isDormantEligible(uint256 tokenId) external view returns (bool eligible, DormancyState state);

    // ========== Wallet-Level Delegation ==========

    /// @notice Grant withdrawal delegation for all vaults owned by msg.sender
    /// @param delegate Address to delegate to
    /// @param percentageBPS Percentage of monthly pool in basis points
    function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external;

    /// @notice Revoke a specific delegate's permission
    /// @param delegate Address to revoke
    function revokeWithdrawalDelegate(address delegate) external;

    /// @notice Revoke all delegates for msg.sender's wallet
    function revokeAllWithdrawalDelegates() external;

    /// @notice Withdraw primary as an authorized delegate
    /// @param tokenId The vault to withdraw from
    /// @return withdrawnAmount Amount of primary collateral withdrawn
    function withdrawPrimaryAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);

    /// @notice Check if delegate can withdraw from a vault
    /// @param tokenId Vault token ID
    /// @param delegate Delegate address
    /// @return canWithdraw Whether withdrawal is possible
    /// @return amount Available withdrawal amount
    /// @return delegationType The type of delegation
    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount, DelegationType delegationType);

    // ========== Vault-Level Delegation ==========

    /// @notice Grant vault-specific withdrawal delegation
    /// @param tokenId Vault token ID
    /// @param delegate Address to delegate to
    /// @param percentageBPS Percentage of monthly pool in basis points
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

    // ========== View Functions ==========

    function primaryToken() external view returns (address);

    function secondaryToken() external view returns (address);

    function btcToken() external view returns (IBtcToken);

    function primaryAmount(uint256 tokenId) external view returns (uint256);

    function secondaryAmount(uint256 tokenId) external view returns (uint256);

    function isVested(uint256 tokenId) external view returns (bool);

    function secondaryWithdrawn(uint256 tokenId) external view returns (bool);

    function treasureContract(uint256 tokenId) external view returns (address);

    function treasureTokenId(uint256 tokenId) external view returns (uint256);

    function mintTimestamp(uint256 tokenId) external view returns (uint256);

    function lastPrimaryWithdrawal(uint256 tokenId) external view returns (uint256);

    function primaryMatchPool() external view returns (uint256);

    function secondaryMatchPool() external view returns (uint256);

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract_,
            uint256 treasureTokenId_,
            uint256 primaryAmount_,
            uint256 secondaryAmount_,
            uint256 mintTimestamp_,
            uint256 lastPrimaryWithdrawal_,
            bool secondaryWithdrawn_,
            uint256 btcTokenAmount_
        );

    function getWithdrawablePrimary(uint256 tokenId) external view returns (uint256);

    function getWithdrawableSecondary(uint256 tokenId) external view returns (uint256);

    function getWalletDelegatePermission(address owner, address delegate)
        external
        view
        returns (WalletDelegatePermission memory);

    function getVaultDelegatePermission(uint256 tokenId, address delegate)
        external
        view
        returns (VaultDelegatePermission memory);

    function walletTotalDelegatedBPS(address owner) external view returns (uint256);

    function vaultTotalDelegatedBPS(uint256 tokenId) external view returns (uint256);

    function getEffectiveDelegation(uint256 tokenId, address delegate)
        external
        view
        returns (uint256 percentageBPS, DelegationType dtype, bool isExpired);
}
