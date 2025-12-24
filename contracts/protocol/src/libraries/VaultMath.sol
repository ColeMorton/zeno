// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library VaultMath {
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;
    uint256 internal constant DORMANCY_THRESHOLD = 1129 days;
    uint256 internal constant GRACE_PERIOD = 30 days;
    uint256 internal constant BASIS_POINTS = 100000;
    uint256 internal constant WITHDRAWAL_RATE = 1000;

    function calculateWithdrawal(uint256 collateral) internal pure returns (uint256) {
        return (collateral * WITHDRAWAL_RATE) / BASIS_POINTS;
    }

    function calculateEarlyRedemption(
        uint256 collateral,
        uint256 mintTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256 returned, uint256 forfeited) {
        if (currentTimestamp <= mintTimestamp) {
            return (0, collateral);
        }

        uint256 elapsed = currentTimestamp - mintTimestamp;

        if (elapsed >= VESTING_PERIOD) {
            return (collateral, 0);
        }

        returned = (collateral * elapsed) / VESTING_PERIOD;
        forfeited = collateral - returned;
    }

    function calculateMatchShare(
        uint256 pool,
        uint256 holderCollateral,
        uint256 totalActiveCollateral
    ) internal pure returns (uint256) {
        if (totalActiveCollateral == 0 || pool == 0) {
            return 0;
        }
        return (pool * holderCollateral) / totalActiveCollateral;
    }

    function isVested(uint256 mintTimestamp, uint256 currentTimestamp) internal pure returns (bool) {
        return currentTimestamp >= mintTimestamp + VESTING_PERIOD;
    }

    function canWithdraw(
        uint256 lastWithdrawal,
        uint256 currentTimestamp
    ) internal pure returns (bool) {
        return currentTimestamp >= lastWithdrawal + WITHDRAWAL_PERIOD;
    }

    function isDormant(uint256 lastActivity, uint256 currentTimestamp) internal pure returns (bool) {
        return currentTimestamp >= lastActivity + DORMANCY_THRESHOLD;
    }

    function isGracePeriodExpired(
        uint256 pokeTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (bool) {
        return pokeTimestamp != 0 && currentTimestamp >= pokeTimestamp + GRACE_PERIOD;
    }
}
