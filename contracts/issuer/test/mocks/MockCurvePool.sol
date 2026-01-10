// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock Curve CryptoSwap V2 pool for testing
/// @dev CryptoSwap is designed for non-pegged volatile pairs (unlike StableSwap).
///      vBTC is a subordinated residual claim that trades at a structural discount to BTC.
contract MockCurvePool is ERC20 {
    IERC20 public coin0; // cbBTC
    IERC20 public coin1; // vestedBTC

    uint256 public balance0;
    uint256 public balance1;

    // Slippage simulation (in BPS)
    uint256 public slippageBPS;

    // CryptoSwap-specific: EMA price oracle (scaled by 1e18)
    uint256 public priceOracleValue = 0.85e18; // Default 15% discount

    // CryptoSwap-specific: Last recorded price (scaled by 1e18)
    uint256 public lastPriceValue = 0.85e18;

    constructor(address cbBTC_, address vestedBTC_) ERC20("Mock Curve LP", "crvLP") {
        coin0 = IERC20(cbBTC_);
        coin1 = IERC20(vestedBTC_);
    }

    function add_liquidity(uint256[2] memory amounts, uint256) external returns (uint256 lpMinted) {
        if (amounts[0] > 0) {
            coin0.transferFrom(msg.sender, address(this), amounts[0]);
            balance0 += amounts[0];
        }
        if (amounts[1] > 0) {
            coin1.transferFrom(msg.sender, address(this), amounts[1]);
            balance1 += amounts[1];
        }

        // Simple LP minting: 1:1 for both coins
        lpMinted = amounts[0] + amounts[1];
        _mint(msg.sender, lpMinted);
    }

    function remove_liquidity_one_coin(uint256 burn_amount, int128 i, uint256) external returns (uint256 received) {
        _burn(msg.sender, burn_amount);

        // Simple 1:1 removal
        received = burn_amount;

        if (i == 0) {
            balance0 -= received;
            coin0.transfer(msg.sender, received);
        } else {
            balance1 -= received;
            coin1.transfer(msg.sender, received);
        }
    }

    function exchange(int128 i, int128 j, uint256 dx, uint256) external returns (uint256 dy) {
        dy = get_dy(i, j, dx);

        if (i == 0) {
            coin0.transferFrom(msg.sender, address(this), dx);
            balance0 += dx;
            balance1 -= dy;
            coin1.transfer(msg.sender, dy);
        } else {
            coin1.transferFrom(msg.sender, address(this), dx);
            balance1 += dx;
            balance0 -= dy;
            coin0.transfer(msg.sender, dy);
        }
    }

    function get_virtual_price() external pure returns (uint256) {
        return 1e18; // 1:1
    }

    function balances(uint256 i) external view returns (uint256) {
        return i == 0 ? balance0 : balance1;
    }

    function get_dy(int128, int128, uint256 dx) public view returns (uint256) {
        // Apply slippage
        uint256 slippage = (dx * slippageBPS) / 10000;
        return dx - slippage;
    }

    function calc_token_amount(uint256[2] memory amounts, bool) external pure returns (uint256) {
        return amounts[0] + amounts[1];
    }

    // ==================== CryptoSwap-specific Functions ====================

    /// @notice Get the EMA price oracle value (CryptoSwap-specific)
    /// @return EMA price scaled by 1e18
    function price_oracle() external view returns (uint256) {
        return priceOracleValue;
    }

    /// @notice Get the last recorded price (CryptoSwap-specific)
    /// @return Last price scaled by 1e18
    function last_prices() external view returns (uint256) {
        return lastPriceValue;
    }

    /// @notice Get the LP token price (CryptoSwap-specific)
    /// @return LP token price scaled by 1e18
    function lp_price() external view returns (uint256) {
        // Simplified: LP price based on total value / supply
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return 1e18;
        return ((balance0 + balance1) * 1e18) / totalSupply_;
    }

    // ==================== Test Helpers ====================

    function setSlippage(uint256 bps) external {
        slippageBPS = bps;
    }

    function setBalances(uint256 bal0, uint256 bal1) external {
        balance0 = bal0;
        balance1 = bal1;
    }

    /// @notice Set the EMA price oracle value (for testing discount scenarios)
    /// @param price Price scaled by 1e18 (e.g., 0.85e18 for 15% discount)
    function setPriceOracle(uint256 price) external {
        priceOracleValue = price;
    }

    /// @notice Set the last price value (for testing)
    /// @param price Price scaled by 1e18
    function setLastPrice(uint256 price) external {
        lastPriceValue = price;
    }
}
