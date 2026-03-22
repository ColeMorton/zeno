#!/bin/bash
# Show volatility pool state
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "VOL_POOL"

echo "=== Volatility Pool Status ==="
echo ""

LONG_ASSETS=$(cast_call "$VOL_POOL" "longPoolAssets()(uint256)")
SHORT_ASSETS=$(cast_call "$VOL_POOL" "shortPoolAssets()(uint256)")
LONG_SHARES=$(cast_call "$VOL_POOL" "longPoolShares()(uint256)")
SHORT_SHARES=$(cast_call "$VOL_POOL" "shortPoolShares()(uint256)")

echo "Long Pool:  $(format_btc "$LONG_ASSETS") BTC assets / $LONG_SHARES shares"
echo "Short Pool: $(format_btc "$SHORT_ASSETS") BTC assets / $SHORT_SHARES shares"
echo ""

VARIANCE=$(cast_call "$VOL_POOL" "getCurrentVariance()(uint256)")
echo "Current Variance: $VARIANCE"
echo ""

SETTLEMENT_DUE=$(cast_call "$VOL_POOL" "isSettlementDue()(bool)")
NEXT_SETTLEMENT=$(cast_call "$VOL_POOL" "nextSettlementTime()(uint256)")
echo "Settlement Due: $SETTLEMENT_DUE"
echo "Next Settlement: $(format_timestamp "$NEXT_SETTLEMENT")"
