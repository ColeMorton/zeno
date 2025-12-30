// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title IVarianceVault
/// @notice Interface for ERC-4626 volatility exposure vaults
/// @dev Extends ERC-4626 with variance swap-specific functionality
interface IVarianceVault is IERC4626 {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Vault epoch states
    enum EpochState {
        DEPOSITING,     // Accepting deposits for next epoch
        ACTIVE,         // Variance swap running
        SETTLING,       // Settlement in progress
        WITHDRAWING     // Withdrawals available
    }

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Configuration for a vault epoch
    struct EpochConfig {
        uint256 strikeVariance;         // Strike variance for this epoch (18 decimals)
        uint256 observationPeriod;      // Duration in seconds
        uint256 depositDeadline;        // Timestamp after which deposits close
        uint256 minDeposit;             // Minimum deposit amount
        uint256 maxTotalDeposits;       // Maximum total deposits for epoch
    }

    /// @notice State of a vault epoch
    struct EpochInfo {
        uint256 epochId;                // Unique epoch identifier
        uint256 totalDeposits;          // Total deposits in this epoch
        uint256 swapId;                 // Underlying variance swap ID (0 if not matched)
        uint256 startTime;              // Observation period start
        uint256 endTime;                // Observation period end
        uint256 realizedVariance;       // Final realized variance (after settlement)
        int256 pnl;                     // Settlement PnL
        EpochState state;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new epoch is initialized
    event EpochInitialized(
        uint256 indexed epochId,
        EpochConfig config
    );

    /// @notice Emitted when an epoch is matched with counterparty vault
    event EpochMatched(
        uint256 indexed epochId,
        uint256 indexed swapId,
        address indexed counterpartyVault
    );

    /// @notice Emitted when an epoch is settled
    event EpochSettled(
        uint256 indexed epochId,
        uint256 realizedVariance,
        int256 pnl
    );

    /// @notice Emitted when user deposits to an epoch
    event DepositToEpoch(
        uint256 indexed epochId,
        address indexed depositor,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when user withdraws from a settled epoch
    event WithdrawFromEpoch(
        uint256 indexed epochId,
        address indexed withdrawer,
        uint256 shares,
        uint256 assets
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error EpochNotFound(uint256 epochId);
    error EpochNotInDepositing(uint256 epochId);
    error EpochNotInWithdrawing(uint256 epochId);
    error DepositDeadlinePassed(uint256 deadline);
    error DepositBelowMinimum(uint256 amount, uint256 minimum);
    error DepositExceedsMax(uint256 amount, uint256 remaining);
    error NoActiveEpoch();
    error EpochNotSettled(uint256 epochId);
    error InsufficientShares(uint256 requested, uint256 available);

    /*//////////////////////////////////////////////////////////////
                          EPOCH MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize a new epoch with configuration
    /// @param config Epoch configuration
    /// @return epochId New epoch identifier
    function initializeEpoch(EpochConfig calldata config) external returns (uint256 epochId);

    /// @notice Trigger matching with counterparty vault via router
    /// @param epochId Epoch to match
    /// @dev Called by router when sufficient deposits on both sides
    function matchEpoch(uint256 epochId) external;

    /// @notice Settle an epoch after variance swap matures
    /// @param epochId Epoch to settle
    function settleEpoch(uint256 epochId) external;

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAW OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit assets to current depositing epoch
    /// @param assets Amount of assets to deposit
    /// @param receiver Recipient of vault shares
    /// @return shares Amount of shares minted
    /// @dev Overrides ERC-4626 deposit to target current epoch
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice Withdraw from settled epochs
    /// @param assets Amount of assets to withdraw
    /// @param receiver Recipient of assets
    /// @param owner Owner of shares
    /// @return shares Amount of shares burned
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current epoch accepting deposits
    function currentEpochId() external view returns (uint256);

    /// @notice Get epoch information
    function getEpoch(uint256 epochId) external view returns (EpochInfo memory);

    /// @notice Get epoch configuration
    function getEpochConfig(uint256 epochId) external view returns (EpochConfig memory);

    /// @notice Get user's shares in a specific epoch
    function userEpochShares(address user, uint256 epochId) external view returns (uint256);

    /// @notice Get total epochs created
    function totalEpochs() external view returns (uint256);

    /// @notice Check if vault is long or short volatility
    function isLongVault() external view returns (bool);

    /// @notice Get counterparty vault address
    function counterpartyVault() external view returns (address);

    /// @notice Get variance swap contract address
    function varianceSwap() external view returns (address);

    /// @notice Get router address for matching
    function router() external view returns (address);

    /// @notice Get standard observation period for this vault
    function standardObservationPeriod() external view returns (uint256);

    /// @notice Calculate assets claimable for shares in a settled epoch
    function previewEpochWithdraw(uint256 epochId, uint256 shares) external view returns (uint256 assets);

    /// @notice Calculate shares needed to withdraw assets from settled epoch
    function previewEpochRedeem(uint256 epochId, uint256 assets) external view returns (uint256 shares);
}
