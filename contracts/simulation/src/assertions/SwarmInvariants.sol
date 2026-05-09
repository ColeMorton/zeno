// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPerpetualVault} from "@issuer/perpetual/interfaces/IPerpetualVault.sol";
import {IVolatilityPool} from "@issuer/volatility/interfaces/IVolatilityPool.sol";

/// @title SwarmInvariants - System-wide solvency and conservation checks for swarm simulation
/// @dev Extends CrossLayerInvariants with DeFi-layer assertions
library SwarmInvariants {
    /// @notice Verify PerpetualVault holds enough vBTC to cover all position payouts
    /// @param perpVault The PerpetualVault contract
    /// @param btcToken The vBTC token contract
    /// @param positionIds All active position IDs to check
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkPerpVaultSolvency(
        IPerpetualVault perpVault,
        IERC20 btcToken,
        uint256[] memory positionIds
    ) internal view returns (bool valid, string memory message) {
        uint256 vbtcBalance = btcToken.balanceOf(address(perpVault));
        uint256 totalPayouts = 0;

        for (uint256 i = 0; i < positionIds.length; i++) {
            try perpVault.previewClose(positionIds[i]) returns (int256, uint256 payout) {
                totalPayouts += payout;
            } catch {
                // Position may not exist or be closed
            }
        }

        if (vbtcBalance < totalPayouts) {
            return (false, "PerpVault insolvent: payouts exceed balance");
        }
        return (true, "");
    }

    /// @notice Verify VolatilityPool holds enough vBTC for both pool assets
    /// @param volPool The VolatilityPool contract
    /// @param btcToken The vBTC token contract
    /// @return valid True if invariant holds
    /// @return message Error message if invalid
    function checkVolPoolSolvency(
        IVolatilityPool volPool,
        IERC20 btcToken
    ) internal view returns (bool valid, string memory message) {
        uint256 vbtcBalance = btcToken.balanceOf(address(volPool));
        uint256 longAssets = volPool.longPoolAssets();
        uint256 shortAssets = volPool.shortPoolAssets();

        if (vbtcBalance < longAssets + shortAssets) {
            return (false, "VolPool insolvent: pool assets exceed balance");
        }
        return (true, "");
    }

    /// @notice Verify total system value conservation (agent net worth ≈ system value)
    /// @param totalAgentNetWorth Sum of all agent net worths
    /// @param systemValue Total value locked in protocol
    /// @param toleranceBps Tolerance in basis points (e.g., 100 = 1%)
    /// @return valid True if within tolerance
    /// @return message Error message if invalid
    function checkSystemValueConservation(
        uint256 totalAgentNetWorth,
        uint256 systemValue,
        uint256 toleranceBps
    ) internal pure returns (bool valid, string memory message) {
        if (systemValue == 0 && totalAgentNetWorth == 0) return (true, "");

        uint256 larger = totalAgentNetWorth > systemValue ? totalAgentNetWorth : systemValue;
        uint256 smaller = totalAgentNetWorth > systemValue ? systemValue : totalAgentNetWorth;
        uint256 diff = larger - smaller;

        if (diff * 10000 > larger * toleranceBps) {
            return (false, "System value conservation violated");
        }
        return (true, "");
    }

    /// @notice Standalone fuzz invariant: vBTC ratio must stay within [0.5, 1.0]
    /// @param vbtcRatio The current vBTC/WBTC ratio (18 decimals)
    /// @return valid True if within bounds
    /// @return message Error message if out of bounds
    function invariant_vbtcRatioBounds(uint256 vbtcRatio) internal pure returns (bool valid, string memory message) {
        if (vbtcRatio > 1.0e18) {
            return (false, "Ratio ceiling breached");
        }
        if (vbtcRatio < 0.5e18) {
            return (false, "Ratio floor breached");
        }
        return (true, "");
    }
}
