// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IHybridMintController} from "./interfaces/IHybridMintController.sol";
import {IProtocolHybridVaultNFT} from "./interfaces/IProtocolHybridVaultNFT.sol";
import {ITreasureNFT} from "./interfaces/ITreasureNFT.sol";
import {ICurveCryptoSwap} from "./interfaces/ICurveCryptoSwap.sol";

/// @title HybridMintController
/// @notice Issuer-layer controller that mints Protocol HybridVaultNFTs with Curve LP integration
/// @dev Thin orchestration: handles cbBTC→LP conversion, delegates vault mechanics to protocol
contract HybridMintController is IHybridMintController, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==================== Immutables ====================

    /// @notice Protocol HybridVaultNFT contract
    IProtocolHybridVaultNFT public immutable hybridVaultNFT;

    /// @notice TreasureNFT contract for vault treasures
    ITreasureNFT public immutable treasureNFT;

    /// @notice cbBTC collateral token (primary collateral in protocol vault)
    IERC20 public immutable cbBTC;

    /// @notice Curve LP token (secondary collateral in protocol vault)
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
        address hybridVaultNFT_,
        address treasureNFT_,
        address cbBTC_,
        address lpToken_,
        address curvePool_
    ) Ownable(msg.sender) {
        if (hybridVaultNFT_ == address(0)) revert ZeroAddress();
        if (treasureNFT_ == address(0)) revert ZeroAddress();
        if (cbBTC_ == address(0)) revert ZeroAddress();
        if (lpToken_ == address(0)) revert ZeroAddress();
        if (curvePool_ == address(0)) revert ZeroAddress();
        hybridVaultNFT = IProtocolHybridVaultNFT(hybridVaultNFT_);
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

    /// @inheritdoc IHybridMintController
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

        // 6. Approve and mint on Protocol HybridVaultNFT
        IERC721(address(treasureNFT)).approve(address(hybridVaultNFT), treasureId);
        cbBTC.forceApprove(address(hybridVaultNFT), vaultPortionCBBTC);
        lpToken.forceApprove(address(hybridVaultNFT), lpReceived);

        // Protocol HybridVaultNFT.mint(treasureContract, treasureTokenId, primaryAmount, secondaryAmount)
        // primaryAmount = cbBTC (1% monthly withdrawal)
        // secondaryAmount = LP tokens (100% at vesting)
        vaultId = hybridVaultNFT.mint(address(treasureNFT), treasureId, vaultPortionCBBTC, lpReceived);

        // 7. Transfer vault NFT to caller (user owns protocol vault directly)
        IERC721(address(hybridVaultNFT)).transferFrom(address(this), msg.sender, vaultId);

        emit HybridVaultMinted(vaultId, msg.sender, vaultPortionCBBTC, lpReceived, lpRatioBPS);
    }

    // ==================== View Functions ====================

    /// @inheritdoc IHybridMintController
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

    /// @inheritdoc IHybridMintController
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

    /// @inheritdoc IHybridMintController
    function getCurrentConfig() external view returns (MonthlyConfig memory) {
        return currentConfig;
    }

    // ==================== Admin Functions ====================

    /// @inheritdoc IHybridMintController
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
    /// @dev vBTC is a subordinated residual claim that trades at a structural discount to BTC.
    ///      This discount is NOT a "depeg" - it reflects time value, subordination, and decay.
    ///      The reference price (1:1) is used as a measurement baseline, not an expected peg.
    ///      See docs/research/Time_Preference_Primer.md for detailed explanation.
    function _calculateDiscountAdjustment(MonthlyConfig memory config) internal view returns (int256) {
        // Get vestedBTC/cbBTC price from Curve pool
        // 1 vestedBTC -> how much cbBTC?
        uint256 vestedBTCPrice = curvePool.get_dy(1, 0, 1e8); // 1 vestedBTC (8 decimals) -> cbBTC
        uint256 referencePrice = 1e8; // Baseline for discount measurement, NOT an expected peg

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
