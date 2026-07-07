// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultNFT} from "@protocol/VaultNFT.sol";
import {IVaultNFTDelegation} from "@protocol/interfaces/IVaultNFTDelegation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ProtocolInvariants - Protocol-level solvency and constraint checks
/// @dev Checks vault balance, match pool, delegation bounds, and vBTC conservation
library ProtocolInvariants {
    /// @notice Verify vault contract holds enough WBTC to cover match pool
    function checkVaultSolvency(
        VaultNFT vault,
        IERC20 wbtc
    ) internal view returns (bool valid, string memory message) {
        uint256 wbtcBalance = wbtc.balanceOf(address(vault));
        uint256 matchPool = vault.matchPool();

        if (wbtcBalance < matchPool) {
            return (false, "Vault insolvent: WBTC balance < match pool");
        }
        return (true, "");
    }

    /// @notice Verify total delegated BPS never exceeds 10000 for any wallet
    function checkDelegationBounds(
        VaultNFT vault,
        address[] memory wallets
    ) internal view returns (bool valid, string memory message) {
        IVaultNFTDelegation delegation = IVaultNFTDelegation(address(vault));

        for (uint256 i = 0; i < wallets.length; i++) {
            uint256 totalBps = delegation.walletTotalDelegatedBPS(wallets[i]);
            if (totalBps > 10000) {
                return (false, "Delegation exceeds 10000 BPS for wallet");
            }
        }
        return (true, "");
    }

    /// @notice Verify total delegated BPS for specific vaults never exceeds 10000
    function checkVaultDelegationBounds(
        VaultNFT vault,
        uint256[] memory vaultIds
    ) internal view returns (bool valid, string memory message) {
        IVaultNFTDelegation delegation = IVaultNFTDelegation(address(vault));

        for (uint256 i = 0; i < vaultIds.length; i++) {
            uint256 totalBps = delegation.vaultTotalDelegatedBPS(vaultIds[i]);
            if (totalBps > 10000) {
                return (false, "Vault delegation exceeds 10000 BPS");
            }
        }
        return (true, "");
    }

    /// @notice Verify vBTC total supply equals sum of stripped reserves
    function checkVbtcConservation(
        VaultNFT vault,
        IERC20 btcToken
    ) internal view returns (bool valid, string memory message) {
        uint256 totalSupply = btcToken.totalSupply();
        uint256 totalStrippedReserve = vault.totalStrippedReserve();

        // vBTC total supply should equal total stripped reserve (1:1 backing)
        // The vault mints vBTC on strip() and burns on recombine()/claimDormantCollateral()
        // Conservation: totalSupply == totalStrippedReserve (reserve is immunized)
        if (totalSupply != totalStrippedReserve) {
            return (false, "vBTC supply not backed by stripped reserves");
        }
        return (true, "");
    }

    /// @notice Verify system value conservation
    /// @dev deposited = withdrawn + matchClaimed + returned + currentTvl
    ///      where currentTvl = wbtc.balanceOf(vault) includes active collateral + match pool
    ///      and returned = pro-rata collateral returned to early redeemers
    function checkSystemConservation(
        uint256 totalDeposited,
        uint256 totalWithdrawn,
        uint256 totalReturned,
        uint256 totalMatchClaimed,
        uint256 currentTvl,
        uint256 toleranceBps
    ) internal pure returns (bool valid, string memory message) {
        uint256 totalOutflows = totalWithdrawn + totalMatchClaimed + totalReturned;
        uint256 totalAccounted = totalOutflows + currentTvl;

        if (totalDeposited == 0) return (true, "");

        uint256 larger = totalDeposited > totalAccounted ? totalDeposited : totalAccounted;
        uint256 smaller = totalDeposited > totalAccounted ? totalAccounted : totalDeposited;
        uint256 diff = larger - smaller;

        if (diff * 10000 > larger * toleranceBps) {
            return (false, "System conservation violated");
        }
        return (true, "");
    }
}
