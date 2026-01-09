// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IHybridMintController
/// @notice Interface for issuer-layer controller that mints Protocol HybridVaultNFTs with Curve LP integration
/// @dev Thin orchestration layer: handles cbBTC→LP conversion, delegates vault mechanics to protocol
interface IHybridMintController {
    // ==================== Structs ====================

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

    // ==================== Events ====================

    event HybridVaultMinted(
        uint256 indexed vaultId,
        address indexed owner,
        uint256 cbBTCToVault,
        uint256 lpMinted,
        uint256 lpRatioBPS
    );

    event MonthlyConfigUpdated(uint256 baseLPRatioBPS, uint256 effectiveTimestamp);

    // ==================== Errors ====================

    error ZeroAmount();
    error ZeroAddress();
    error ConfigUpdateTooFrequent();
    error RateLimitExceeded(string param);

    // ==================== Core Functions ====================

    /// @notice Mint a Protocol HybridVaultNFT with automatic LP creation
    /// @param cbBTCAmount Total cbBTC to deposit (splits per current LP ratio)
    /// @return vaultId Protocol HybridVaultNFT token ID (user owns directly)
    function mintHybridVault(uint256 cbBTCAmount) external returns (uint256 vaultId);

    // ==================== View Functions ====================

    /// @notice Calculate current target LP ratio based on market conditions
    /// @return ratioBPS LP ratio in basis points
    function calculateTargetLPRatio() external view returns (uint256 ratioBPS);

    /// @notice Measure current slippage for standard swap size
    /// @return slippageBPS Slippage in basis points
    function measureSlippage() external view returns (uint256 slippageBPS);

    /// @notice Get current monthly configuration
    /// @return Current MonthlyConfig
    function getCurrentConfig() external view returns (MonthlyConfig memory);

    // ==================== Admin Functions ====================

    /// @notice Update monthly configuration (rate-limited)
    /// @param newConfig New configuration values
    function updateMonthlyConfig(MonthlyConfig calldata newConfig) external;

}
