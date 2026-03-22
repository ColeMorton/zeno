// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICurveCryptoSwap} from "@issuer/interfaces/ICurveCryptoSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SimCurvePool - Constant-product AMM implementing ICurveCryptoSwap for simulation
/// @dev coin[0] = WBTC, coin[1] = vBTC. Price = reserve0 * 1e18 / reserve1 (vBTC price in WBTC terms).
///      Pool starts empty and is seeded by agents via add_liquidity() after first vesting.
contract SimCurvePool is ICurveCryptoSwap {
    IERC20 public immutable coin0; // WBTC
    IERC20 public immutable coin1; // vBTC

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public oraclePrice; // EMA price for price_oracle()
    uint256 public lastSpotPrice; // raw spot for last_prices()

    bool public initialized;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant FEE_BPS = 30; // 0.3%
    uint256 private constant BPS = 10000;
    uint256 private constant EMA_ALPHA = 1e17; // 10% weight to new observation

    error NotInitialized();
    error InvalidCoinIndex(int128 i);
    error InsufficientOutput(uint256 dy, uint256 min_dy);
    error ZeroAmount();

    constructor(address _coin0, address _coin1) {
        coin0 = IERC20(_coin0);
        coin1 = IERC20(_coin1);
    }

    // ==================== Liquidity Provision ====================

    /// @notice Add liquidity to the pool. First call with both tokens initializes it.
    function add_liquidity(uint256[2] memory amounts, uint256) external override returns (uint256) {
        if (amounts[0] > 0) coin0.transferFrom(msg.sender, address(this), amounts[0]);
        if (amounts[1] > 0) coin1.transferFrom(msg.sender, address(this), amounts[1]);

        reserve0 = coin0.balanceOf(address(this));
        reserve1 = coin1.balanceOf(address(this));

        if (!initialized && reserve0 > 0 && reserve1 > 0) {
            initialized = true;
            uint256 spot = reserve0 * PRECISION / reserve1;
            oraclePrice = spot;
            lastSpotPrice = spot;
        } else if (initialized) {
            _updateOracle();
        }

        return 0; // LP tokens not tracked (simulation-only)
    }

    // ==================== Core AMM ====================

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external override returns (uint256 dy) {
        if (!initialized) revert NotInitialized();
        if (dx == 0) revert ZeroAmount();

        (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = _getReserves(i, j);

        // Constant-product: dy = reserveOut * dx_after_fee / (reserveIn + dx_after_fee)
        uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
        dy = reserveOut * dxAfterFee / (reserveIn + dxAfterFee);

        if (dy < min_dy) revert InsufficientOutput(dy, min_dy);

        // Transfer
        tokenIn.transferFrom(msg.sender, address(this), dx);
        tokenOut.transfer(msg.sender, dy);

        // Update reserves
        reserve0 = coin0.balanceOf(address(this));
        reserve1 = coin1.balanceOf(address(this));

        // Update oracle
        _updateOracle();

        return dy;
    }

    function get_dy(int128 i, int128 j, uint256 dx) external view override returns (uint256) {
        if (!initialized || dx == 0) return 0;
        (, , uint256 reserveIn, uint256 reserveOut) = _getReserves(i, j);
        uint256 dxAfterFee = dx * (BPS - FEE_BPS) / BPS;
        return reserveOut * dxAfterFee / (reserveIn + dxAfterFee);
    }

    // ==================== Oracle ====================

    function price_oracle() external view override returns (uint256) {
        return oraclePrice;
    }

    function last_prices() external view override returns (uint256) {
        return lastSpotPrice;
    }

    /// @notice Current spot price (returns 0 if pool not initialized)
    function spotPrice() external view returns (uint256) {
        if (reserve1 == 0) return 0;
        return reserve0 * PRECISION / reserve1;
    }

    function balances(uint256 i) external view override returns (uint256) {
        if (i == 0) return reserve0;
        if (i == 1) return reserve1;
        revert InvalidCoinIndex(int128(int256(i)));
    }

    // ==================== Stubs ====================

    function remove_liquidity_one_coin(uint256, int128, uint256) external pure override returns (uint256) {
        revert("SimCurvePool: not implemented");
    }

    function get_virtual_price() external pure override returns (uint256) {
        return PRECISION;
    }

    function calc_token_amount(uint256[2] memory, bool) external pure override returns (uint256) {
        return 0;
    }

    function lp_price() external pure override returns (uint256) {
        return PRECISION;
    }

    // ==================== Internal ====================

    function _getReserves(int128 i, int128 j)
        private
        view
        returns (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut)
    {
        if (i == 0 && j == 1) {
            return (coin0, coin1, reserve0, reserve1);
        } else if (i == 1 && j == 0) {
            return (coin1, coin0, reserve1, reserve0);
        }
        revert InvalidCoinIndex(i);
    }

    function _updateOracle() private {
        if (reserve1 == 0) return;
        uint256 spot = reserve0 * PRECISION / reserve1;
        oraclePrice = (EMA_ALPHA * spot + (PRECISION - EMA_ALPHA) * oraclePrice) / PRECISION;
        lastSpotPrice = spot;
    }
}
