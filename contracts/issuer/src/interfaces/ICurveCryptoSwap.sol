// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICurveCryptoSwap - Interface for Curve CryptoSwap V2 pools
/// @notice Interface for interacting with Curve vestedBTC/cbBTC CryptoSwap pool
/// @dev CryptoSwap is designed for non-pegged volatile pairs (unlike StableSwap).
///      vBTC is a subordinated residual claim that trades at a structural discount to BTC.
///      CryptoSwap's EMA oracle tracks evolving fair value without assuming a peg.
///      See docs/research/Time_Preference_Primer.md for why CryptoSwap is appropriate.
interface ICurveCryptoSwap {
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
    /// @dev Note: This returns actual expected output based on CryptoSwap math,
    ///      which accounts for non-pegged price dynamics. Do not assume 1:1 baseline.
    /// @param i Index of input coin
    /// @param j Index of output coin
    /// @param dx Amount to swap
    /// @return Expected output
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);

    /// @notice Get expected LP tokens for adding liquidity
    /// @param amounts Array of amounts to deposit
    /// @param is_deposit True for deposit, false for withdrawal
    /// @return Expected LP tokens
    function calc_token_amount(uint256[2] memory amounts, bool is_deposit) external view returns (uint256);

    /// @notice Get the EMA price oracle value (CryptoSwap-specific)
    /// @dev Returns the exponential moving average of the price, used for rebalancing decisions.
    ///      This oracle tracks the evolving market price without assuming a peg.
    /// @return EMA price scaled by 1e18
    function price_oracle() external view returns (uint256);

    /// @notice Get the last recorded price (CryptoSwap-specific)
    /// @return Last price scaled by 1e18
    function last_prices() external view returns (uint256);

    /// @notice Get the LP token price (CryptoSwap-specific)
    /// @return LP token price scaled by 1e18
    function lp_price() external view returns (uint256);
}
