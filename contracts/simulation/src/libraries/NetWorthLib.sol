// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {IPerpetualVault} from "@issuer/perpetual/interfaces/IPerpetualVault.sol";
import {IVolatilityPool} from "@issuer/volatility/interfaces/IVolatilityPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title NetWorthLib - Portfolio valuation across all protocol positions
/// @dev All values returned in WBTC terms (8 decimals)
library NetWorthLib {
    uint256 private constant PRECISION = 1e18;

    struct Contracts {
        VaultNFT vault;
        IERC20 wbtc;
        IERC20 btcToken;
        IPerpetualVault perpVault;
        IVolatilityPool volPool;
    }

    /// @notice Calculate total net worth of an agent in WBTC terms
    /// @param agent Agent address
    /// @param perpPositionIds Agent's perpetual position IDs
    /// @param longVolShares Agent's long vol pool shares
    /// @param shortVolShares Agent's short vol pool shares
    /// @param contracts Protocol contract references
    /// @param vbtcRatio Current vBTC/WBTC ratio (18 decimals)
    /// @param vaultCollaterals Pre-cached collateral per vault (from _buildPortfolio)
    /// @param vaultVested Pre-cached vesting status per vault (from _buildPortfolio)
    /// @return netWorth Total net worth in WBTC (8 decimals)
    function calculateNetWorth(
        address agent,
        uint256[] memory,
        uint256[] memory perpPositionIds,
        uint256 longVolShares,
        uint256 shortVolShares,
        Contracts memory contracts,
        uint256 vbtcRatio,
        uint256[] memory vaultCollaterals,
        bool[] memory vaultVested
    ) internal view returns (uint256 netWorth) {
        // 1. Raw WBTC balance
        netWorth += contracts.wbtc.balanceOf(agent);

        // 2. Vault collateral (use cached values — no duplicate getVaultInfo reads)
        for (uint256 i = 0; i < vaultCollaterals.length; i++) {
            netWorth += vaultCollaterals[i];
        }

        // 3. vBTC balance converted to WBTC terms
        uint256 vbtcBal = contracts.btcToken.balanceOf(agent);
        if (vbtcBal > 0) {
            netWorth += (vbtcBal * vbtcRatio) / PRECISION;
        }

        // 4. Perpetual positions (mark-to-market)
        for (uint256 i = 0; i < perpPositionIds.length; i++) {
            netWorth += _perpValue(perpPositionIds[i], contracts.perpVault, vbtcRatio);
        }

        // 5. Volatility pool shares
        if (longVolShares > 0) {
            uint256 longAssets = contracts.volPool.previewWithdrawLong(longVolShares);
            netWorth += (longAssets * vbtcRatio) / PRECISION;
        }
        if (shortVolShares > 0) {
            uint256 shortAssets = contracts.volPool.previewWithdrawShort(shortVolShares);
            netWorth += (shortAssets * vbtcRatio) / PRECISION;
        }

        // 6. Match pool claim estimate (use cached vesting + collateral data)
        netWorth += _matchClaimEstimate(contracts.vault, vaultCollaterals, vaultVested);
    }

    /// @dev Perpetual position mark-to-market in WBTC terms
    function _perpValue(
        uint256 positionId,
        IPerpetualVault perpVault,
        uint256 vbtcRatio
    ) private view returns (uint256) {
        try perpVault.previewClose(positionId) returns (int256, uint256 payout) {
            return (payout * vbtcRatio) / PRECISION;
        } catch {
            return 0; // position may be closed
        }
    }

    /// @dev Estimate match pool claim: pro-rata based on vault collateral
    function _matchClaimEstimate(
        VaultNFT vault,
        uint256[] memory vaultCollaterals,
        bool[] memory vaultVested
    ) private view returns (uint256 estimate) {
        uint256 matchPool = vault.matchPool();
        uint256 totalActive = vault.totalActiveCollateral();
        if (matchPool == 0 || totalActive == 0) return 0;

        for (uint256 i = 0; i < vaultCollaterals.length; i++) {
            if (vaultVested[i]) {
                estimate += (matchPool * vaultCollaterals[i]) / totalActive;
            }
        }
    }
}
