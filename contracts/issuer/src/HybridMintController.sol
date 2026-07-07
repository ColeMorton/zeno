// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVaultNFT} from "@protocol/interfaces/IVaultNFT.sol";
import {VestingEscrow} from "@protocol/VestingEscrow.sol";
import {ITreasureNFT} from "./interfaces/ITreasureNFT.sol";
import {ICurveCryptoSwap} from "./interfaces/ICurveCryptoSwap.sol";

/// @title HybridMintController
/// @notice Issuer-layer controller that composes a dual-collateral position from the protocol's
/// single vault primitive: a VaultNFT holding the cbBTC leg (1% monthly perpetual withdrawal)
/// and a VestingEscrow holding the Curve LP leg (100% at vesting), bound together by the vault's
/// redeem hook for atomic early exit.
/// @dev Thin orchestration: handles cbBTC→LP conversion, delegates vault mechanics to protocol
contract HybridMintController is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==================== Types ====================

    /// @notice Monthly configuration for dynamic LP ratio calculation
    struct MonthlyConfig {
        uint256 baseLPRatioBPS; // Default: 3000 (30%)
        uint256 minLPRatioBPS; // Default: 1000 (10%)
        uint256 maxLPRatioBPS; // Default: 5000 (50%)
        uint256 discountThresholdBPS; // Default: 1000 (10%)
        uint256 discountSensitivity; // Default: 2
        uint256 targetSlippageBPS; // Default: 50 (0.5%)
        uint256 slippageSensitivity; // Default: 20
        uint256 standardSwapBPS; // Default: 10 (0.1% of TVL)
        uint256 effectiveTimestamp; // When this config became active
    }

    event HybridVaultMinted(
        uint256 indexed vaultId,
        address indexed owner,
        uint256 cbBTCToVault,
        uint256 lpMinted,
        uint256 lpRatioBPS
    );

    event MonthlyConfigUpdated(uint256 baseLPRatioBPS, uint256 effectiveTimestamp);

    error ZeroAmount();
    error ZeroAddress();
    error ConfigUpdateTooFrequent();
    error RateLimitExceeded(string param);

    // ==================== Immutables ====================

    /// @notice Protocol VaultNFT contract holding the cbBTC leg
    IVaultNFT public immutable vaultNFT;

    /// @notice Protocol VestingEscrow holding the LP leg, keyed to the vault's clock
    VestingEscrow public immutable vestingEscrow;

    /// @notice TreasureNFT contract for vault treasures
    ITreasureNFT public immutable treasureNFT;

    /// @notice cbBTC collateral token (primary leg in the protocol vault)
    IERC20 public immutable cbBTC;

    /// @notice Curve LP token (secondary leg in the vesting escrow)
    IERC20 public immutable lpToken;

    /// @notice Curve pool for cbBTC/vestedBTC (CryptoSwap V2 for non-pegged pairs)
    ICurveCryptoSwap public immutable curvePool;

    // ==================== Monthly Configuration ====================

    /// @notice Current monthly configuration
    MonthlyConfig public currentConfig;

    /// @notice Previous monthly configuration (for rate limit checks)
    MonthlyConfig public previousConfig;

    // ==================== Constants ====================

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant CONFIG_UPDATE_PERIOD = 30 days;

    // Rate limits for monthly config changes
    uint256 public constant MAX_BASE_RATIO_DELTA = 500; // 5%
    uint256 public constant MAX_DISCOUNT_DELTA = 300; // 3%
    uint256 public constant MAX_SENSITIVITY_DELTA = 5;
    uint256 public constant MAX_SLIPPAGE_DELTA = 25; // 0.25%

    // ==================== Constructor ====================

    constructor(
        address vaultNFT_,
        address vestingEscrow_,
        address treasureNFT_,
        address cbBTC_,
        address lpToken_,
        address curvePool_
    ) Ownable(msg.sender) {
        if (vaultNFT_ == address(0)) revert ZeroAddress();
        if (vestingEscrow_ == address(0)) revert ZeroAddress();
        if (treasureNFT_ == address(0)) revert ZeroAddress();
        if (cbBTC_ == address(0)) revert ZeroAddress();
        if (lpToken_ == address(0)) revert ZeroAddress();
        if (curvePool_ == address(0)) revert ZeroAddress();
        vaultNFT = IVaultNFT(vaultNFT_);
        vestingEscrow = VestingEscrow(vestingEscrow_);
        treasureNFT = ITreasureNFT(treasureNFT_);
        cbBTC = IERC20(cbBTC_);
        lpToken = IERC20(lpToken_);
        curvePool = ICurveCryptoSwap(curvePool_);

        // Initialize default config
        currentConfig = MonthlyConfig({
            baseLPRatioBPS: 3000, // 30%
            minLPRatioBPS: 1000, // 10%
            maxLPRatioBPS: 5000, // 50%
            discountThresholdBPS: 1000, // 10%
            discountSensitivity: 2,
            targetSlippageBPS: 50, // 0.5%
            slippageSensitivity: 20,
            standardSwapBPS: 10, // 0.1% of TVL
            effectiveTimestamp: block.timestamp
        });
    }

    // ==================== Core Functions ====================

    /// @notice Mint a dual-collateral position: a protocol vault (cbBTC leg) plus an escrowed
    /// LP leg, atomically bound via the vault's redeem hook
    /// @param cbBTCAmount Total cbBTC to deposit (splits per current LP ratio)
    /// @return vaultId Protocol VaultNFT token ID (user owns directly)
    function mintHybridVault(uint256 cbBTCAmount) external nonReentrant returns (uint256 vaultId) {
        if (cbBTCAmount == 0) revert ZeroAmount();

        // 1. Calculate LP ratio at mint time
        uint256 lpRatioBPS = calculateTargetLPRatio();

        // 2. Calculate split
        uint256 lpPortionCBBTC = (cbBTCAmount * lpRatioBPS) / BASIS_POINTS;
        uint256 vaultPortionCBBTC = cbBTCAmount - lpPortionCBBTC;

        // 3. Transfer cbBTC from caller
        cbBTC.safeTransferFrom(msg.sender, address(this), cbBTCAmount);

        // 4. Mint TreasureNFT for the vault
        uint256 treasureId = treasureNFT.mint(address(this));

        // 5. Add cbBTC to Curve pool to get LP tokens (single-sided)
        cbBTC.forceApprove(address(curvePool), lpPortionCBBTC);
        uint256[2] memory amounts = [lpPortionCBBTC, 0]; // cbBTC only
        uint256 lpReceived = curvePool.add_liquidity(amounts, 0);

        // 6. Mint the protocol vault with the cbBTC leg
        IERC721(address(treasureNFT)).approve(address(vaultNFT), treasureId);
        cbBTC.forceApprove(address(vaultNFT), vaultPortionCBBTC);
        vaultId = vaultNFT.mint(address(treasureNFT), treasureId, address(cbBTC), vaultPortionCBBTC);

        // 7. Bind the escrow as the vault's redeem hook (controller owns the vault here),
        // then escrow the LP leg against it — deposit requires the binding
        vaultNFT.setRedeemHook(vaultId, address(vestingEscrow));
        lpToken.forceApprove(address(vestingEscrow), lpReceived);
        vestingEscrow.deposit(vaultId, lpReceived);

        // 8. Transfer vault NFT to caller (user owns protocol vault directly)
        IERC721(address(vaultNFT)).transferFrom(address(this), msg.sender, vaultId);

        emit HybridVaultMinted(vaultId, msg.sender, vaultPortionCBBTC, lpReceived, lpRatioBPS);
    }

    // ==================== View Functions ====================

    /// @notice Calculate current target LP ratio based on market conditions
    /// @return ratioBPS LP ratio in basis points
    function calculateTargetLPRatio() public view returns (uint256 ratioBPS) {
        MonthlyConfig memory config = currentConfig;

        int256 ratio = int256(config.baseLPRatioBPS);

        // Signal 1: Slippage-based adjustment
        ratio += _calculateSlippageAdjustment(config);

        // Signal 2: Discount-based adjustment
        ratio += _calculateDiscountAdjustment(config);

        // Clamp to bounds
        if (ratio < int256(config.minLPRatioBPS)) return config.minLPRatioBPS;
        if (ratio > int256(config.maxLPRatioBPS)) return config.maxLPRatioBPS;
        return uint256(ratio);
    }

    /// @notice Measure current slippage for standard swap size
    /// @return slippageBPS Slippage in basis points
    function measureSlippage() public view returns (uint256 slippageBPS) {
        MonthlyConfig memory config = currentConfig;

        // Get pool balances for depth measurement
        uint256 poolBalance0 = curvePool.balances(0); // cbBTC
        uint256 poolBalance1 = curvePool.balances(1); // vestedBTC
        uint256 totalPoolValue = poolBalance0 + poolBalance1;

        if (totalPoolValue == 0) return 0;

        uint256 swapAmount = (totalPoolValue * config.standardSwapBPS) / BASIS_POINTS;
        if (swapAmount == 0) return 0;

        // Reference output (1:1 baseline, not expected market price)
        uint256 expectedOut = swapAmount;

        // Actual output from Curve (cbBTC -> vestedBTC)
        uint256 actualOut = curvePool.get_dy(0, 1, swapAmount);

        if (actualOut >= expectedOut) return 0;
        return ((expectedOut - actualOut) * BASIS_POINTS) / expectedOut;
    }

    /// @notice Get current monthly configuration
    /// @return Current MonthlyConfig
    function getCurrentConfig() external view returns (MonthlyConfig memory) {
        return currentConfig;
    }

    // ==================== Admin Functions ====================

    /// @notice Update monthly configuration (rate-limited)
    /// @param newConfig New configuration values
    function updateMonthlyConfig(MonthlyConfig calldata newConfig) external onlyOwner {
        // Rate limit: at least 30 days since last update
        if (block.timestamp < currentConfig.effectiveTimestamp + CONFIG_UPDATE_PERIOD) {
            revert ConfigUpdateTooFrequent();
        }

        // Validate rate limits
        _validateRateLimits(currentConfig, newConfig);

        // Store previous config
        previousConfig = currentConfig;

        // Apply new config
        currentConfig = MonthlyConfig({
            baseLPRatioBPS: newConfig.baseLPRatioBPS,
            minLPRatioBPS: newConfig.minLPRatioBPS,
            maxLPRatioBPS: newConfig.maxLPRatioBPS,
            discountThresholdBPS: newConfig.discountThresholdBPS,
            discountSensitivity: newConfig.discountSensitivity,
            targetSlippageBPS: newConfig.targetSlippageBPS,
            slippageSensitivity: newConfig.slippageSensitivity,
            standardSwapBPS: newConfig.standardSwapBPS,
            effectiveTimestamp: block.timestamp
        });

        emit MonthlyConfigUpdated(newConfig.baseLPRatioBPS, block.timestamp);
    }

    // ==================== Internal Functions ====================

    function _calculateSlippageAdjustment(MonthlyConfig memory config) internal view returns (int256) {
        uint256 currentSlippage = measureSlippage();

        if (currentSlippage > config.targetSlippageBPS) {
            // High slippage -> increase LP allocation
            uint256 excess = currentSlippage - config.targetSlippageBPS;
            return int256(excess * config.slippageSensitivity);
        } else {
            // Low slippage -> decrease LP allocation (slower rate)
            uint256 margin = config.targetSlippageBPS - currentSlippage;
            return -int256((margin * config.slippageSensitivity) / 2);
        }
    }

    /// @notice Calculates LP allocation adjustment based on vBTC discount from reference price
    /// @dev vBTC is a floating principal strip backed 1:1 by immunized reserve collateral
    ///      (protocol invariant: totalStrippedReserve == vBTC totalSupply). Par (1:1) is
    ///      therefore the exact on-chain NAV floor, not an expected peg: the market discount
    ///      below par prices recombination timing and control, and this measures it.
    function _calculateDiscountAdjustment(MonthlyConfig memory config) internal view returns (int256) {
        // Get vestedBTC/cbBTC price from Curve pool
        // 1 vestedBTC -> how much cbBTC?
        uint256 vestedBTCPrice = curvePool.get_dy(1, 0, 1e8); // 1 vestedBTC (8 decimals) -> cbBTC
        uint256 referencePrice = 1e8; // NAV floor: reserve backs vBTC 1:1

        if (vestedBTCPrice >= referencePrice) return 0;

        uint256 discountBPS = ((referencePrice - vestedBTCPrice) * BASIS_POINTS) / referencePrice;

        if (discountBPS > config.discountThresholdBPS) {
            // Significant discount -> increase LP to absorb selling pressure
            uint256 excess = discountBPS - config.discountThresholdBPS;
            return int256(excess * config.discountSensitivity);
        }

        return 0;
    }

    function _validateRateLimits(MonthlyConfig memory current, MonthlyConfig memory next) internal pure {
        if (_absDiff(current.baseLPRatioBPS, next.baseLPRatioBPS) > MAX_BASE_RATIO_DELTA) {
            revert RateLimitExceeded("baseLPRatioBPS");
        }
        if (_absDiff(current.discountThresholdBPS, next.discountThresholdBPS) > MAX_DISCOUNT_DELTA) {
            revert RateLimitExceeded("discountThresholdBPS");
        }
        if (_absDiff(current.discountSensitivity, next.discountSensitivity) > MAX_SENSITIVITY_DELTA) {
            revert RateLimitExceeded("discountSensitivity");
        }
        if (_absDiff(current.slippageSensitivity, next.slippageSensitivity) > MAX_SENSITIVITY_DELTA) {
            revert RateLimitExceeded("slippageSensitivity");
        }
        if (_absDiff(current.targetSlippageBPS, next.targetSlippageBPS) > MAX_SLIPPAGE_DELTA) {
            revert RateLimitExceeded("targetSlippageBPS");
        }
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
}
