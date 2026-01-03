// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICurveStableSwap - Interface for Curve StableSwap pools
/// @notice Minimal interface for interacting with Curve vestedBTC/cbBTC pool
interface ICurveStableSwap {
    /// @notice Add liquidity to the pool
    /// @param amounts Array of amounts [coin0, coin1] to deposit
    /// @param min_mint_amount Minimum LP tokens to receive
    /// @return LP tokens minted
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);

    /// @notice Remove liquidity from the pool (single coin)
    /// @param burn_amount LP tokens to burn
    /// @param i Index of coin to receive (0 = cbBTC, 1 = vestedBTC)
    /// @param min_received Minimum tokens to receive
    /// @return Tokens received
    function remove_liquidity_one_coin(uint256 burn_amount, int128 i, uint256 min_received)
        external
        returns (uint256);

    /// @notice Swap tokens
    /// @param i Index of input coin
    /// @param j Index of output coin
    /// @param dx Amount to swap
    /// @param min_dy Minimum output
    /// @return Output amount
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);

    /// @notice Get virtual price of LP token
    /// @return Virtual price scaled by 1e18
    function get_virtual_price() external view returns (uint256);

    /// @notice Get pool balances
    /// @param i Coin index
    /// @return Balance of coin i
    function balances(uint256 i) external view returns (uint256);

    /// @notice Get expected output for swap (view function for slippage calculation)
    /// @param i Index of input coin
    /// @param j Index of output coin
    /// @param dx Amount to swap
    /// @return Expected output
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);

    /// @notice Get expected LP tokens for adding liquidity
    /// @param amounts Array of amounts to deposit
    /// @return Expected LP tokens
    function calc_token_amount(uint256[2] memory amounts, bool is_deposit) external view returns (uint256);
}
