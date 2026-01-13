// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVolatilityPool
/// @notice Interface for perpetual volatility pool with socialized P&L
/// @dev Enables long/short volatility exposure via pool-based model
interface IVolatilityPool {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Side of volatility exposure
    enum Side {
        LONG,   // Profits when realized variance > strike
        SHORT   // Profits when realized variance < strike
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when user deposits to long pool
    event DepositedLong(
        address indexed user,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when user deposits to short pool
    event DepositedShort(
        address indexed user,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when user withdraws from long pool
    event WithdrawnLong(
        address indexed user,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when user withdraws from short pool
    event WithdrawnShort(
        address indexed user,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when variance P&L is settled between pools
    event Settled(
        uint256 indexed timestamp,
        uint256 realizedVariance,
        int256 pnlTransferred
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientShares(uint256 requested, uint256 available);
    error SettlementNotDue(uint256 nextSettlement);
    error InsufficientObservations(uint256 required, uint256 available);

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit vBTC to long volatility pool
    /// @param assets Amount of vBTC to deposit
    /// @return shares Pool shares received
    function depositLong(uint256 assets) external returns (uint256 shares);

    /// @notice Deposit vBTC to short volatility pool
    /// @param assets Amount of vBTC to deposit
    /// @return shares Pool shares received
    function depositShort(uint256 assets) external returns (uint256 shares);

    /*//////////////////////////////////////////////////////////////
                         WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw from long volatility pool
    /// @param shares Amount of shares to redeem
    /// @return assets vBTC received
    function withdrawLong(uint256 shares) external returns (uint256 assets);

    /// @notice Withdraw from short volatility pool
    /// @param shares Amount of shares to redeem
    /// @return assets vBTC received
    function withdrawShort(uint256 shares) external returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                         SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settle variance P&L between pools (permissionless)
    /// @dev Transfers assets between pools based on realized vs strike variance
    function settle() external;

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Preview withdrawal amount for long pool
    /// @param shares Amount of shares to preview
    /// @return assets Estimated vBTC to receive
    function previewWithdrawLong(uint256 shares) external view returns (uint256 assets);

    /// @notice Preview withdrawal amount for short pool
    /// @param shares Amount of shares to preview
    /// @return assets Estimated vBTC to receive
    function previewWithdrawShort(uint256 shares) external view returns (uint256 assets);

    /// @notice Get current rolling realized variance from oracle
    /// @return variance Annualized variance (18 decimals)
    function getCurrentVariance() external view returns (uint256 variance);

    /// @notice Get user's long pool share balance
    /// @param user User address
    /// @return shares Long pool shares held
    function longSharesOf(address user) external view returns (uint256 shares);

    /// @notice Get user's short pool share balance
    /// @param user User address
    /// @return shares Short pool shares held
    function shortSharesOf(address user) external view returns (uint256 shares);

    /// @notice Get total assets in long pool
    function longPoolAssets() external view returns (uint256);

    /// @notice Get total assets in short pool
    function shortPoolAssets() external view returns (uint256);

    /// @notice Get total shares in long pool
    function longPoolShares() external view returns (uint256);

    /// @notice Get total shares in short pool
    function shortPoolShares() external view returns (uint256);

    /// @notice Get timestamp of last settlement
    function lastSettlementTime() external view returns (uint256);

    /// @notice Get variance recorded at last settlement
    function lastSettlementVariance() external view returns (uint256);

    /// @notice Check if settlement is due
    function isSettlementDue() external view returns (bool);

    /// @notice Get next settlement timestamp
    function nextSettlementTime() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          IMMUTABLE GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice vestedBTC token address
    function vBTC() external view returns (address);

    /// @notice Variance oracle address
    function varianceOracle() external view returns (address);

    /// @notice Strike variance (18 decimals, e.g., 4e16 = 4%)
    function strikeVariance() external view returns (uint256);

    /// @notice Settlement interval in seconds
    function settlementInterval() external view returns (uint256);

    /// @notice Rolling variance window size in seconds
    function varianceWindow() external view returns (uint256);

    /// @notice Minimum deposit amount
    function minDeposit() external view returns (uint256);
}
