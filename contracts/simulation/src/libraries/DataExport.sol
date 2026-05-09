// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";

/// @title DataExport - CSV/JSON string builders for simulation data export
/// @dev Stateless library. All functions build strings; callers handle vm.writeFile().
library DataExport {
    // ==================== Action Names ====================

    function actionName(uint8 action) internal pure returns (string memory) {
        if (action == 0) return "NONE";
        if (action == 1) return "MINT_VAULT";
        if (action == 2) return "WITHDRAW";
        if (action == 3) return "EARLY_REDEEM";
        if (action == 4) return "MINT_BTC_TOKEN";
        if (action == 5) return "RETURN_BTC_TOKEN";
        if (action == 6) return "CLAIM_MATCH";
        if (action == 7) return "PROVE_ACTIVITY";
        if (action == 8) return "OPEN_PERP_LONG";
        if (action == 9) return "OPEN_PERP_SHORT";
        if (action == 10) return "CLOSE_PERP";
        if (action == 11) return "ADD_PERP_COLLATERAL";
        if (action == 12) return "DEPOSIT_VOL_LONG";
        if (action == 13) return "DEPOSIT_VOL_SHORT";
        if (action == 14) return "WITHDRAW_VOL_LONG";
        if (action == 15) return "WITHDRAW_VOL_SHORT";
        if (action == 16) return "POKE_DORMANT";
        if (action == 17) return "CLAIM_DORMANT";
        if (action == 18) return "SWAP_VBTC_TO_WBTC";
        if (action == 19) return "SWAP_WBTC_TO_VBTC";
        if (action == 20) return "GRANT_WALLET_DELEGATE";
        if (action == 21) return "ADD_LIQUIDITY";
        return "UNKNOWN";
    }

    // ==================== Archetype Names ====================

    function archetypeName(uint8 archetype) internal pure returns (string memory) {
        if (archetype == 0) return "DIAMOND_HANDS";
        if (archetype == 1) return "YIELD_FARMER";
        if (archetype == 2) return "MOMENTUM_TRADER";
        if (archetype == 3) return "VOLATILITY_PLAYER";
        if (archetype == 4) return "ARBITRAGEUR";
        if (archetype == 5) return "PANIC_SELLER";
        if (archetype == 6) return "PREDATOR";
        return "UNKNOWN";
    }

    // ==================== CSV Builders ====================

    /// @notice Build a CSV row from uint256 values
    function csvRow(Vm vm, uint256[] memory values) internal pure returns (string memory row) {
        for (uint256 i = 0; i < values.length; i++) {
            row = i == 0
                ? vm.toString(values[i])
                : string.concat(row, ",", vm.toString(values[i]));
        }
        row = string.concat(row, "\n");
    }

    /// @notice Build a CSV header from column names
    function csvHeader(string[] memory headers) internal pure returns (string memory row) {
        for (uint256 i = 0; i < headers.length; i++) {
            row = i == 0
                ? headers[i]
                : string.concat(row, ",", headers[i]);
        }
        row = string.concat(row, "\n");
    }
}
