// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PriceSimulator - Price state struct for simulation
/// @dev WBTC/USDC prices are loaded from a canonical CSV via loadPriceSeries().
///      GBM generation is handled externally by scripts/generate_price_series.py.
library PriceSimulator {
    struct PriceState {
        uint256 price; // WBTC/USDC (18 decimals)
        uint8 regime; // 0=low-vol, 1=high-vol
        uint256 seed; // unused (retained for storage compatibility)
    }
}
