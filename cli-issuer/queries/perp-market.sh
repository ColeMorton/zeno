#!/bin/bash
# Show perpetual vault market state
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "PERP_VAULT"

echo "=== Perpetual Market State ==="
echo ""

PRICE=$(cast_call "$PERP_VAULT" "getCurrentPrice()(uint256)")
echo "Current Price: $(format_btc "$PRICE") BTC"

FUNDING_RATE=$(cast_call "$PERP_VAULT" "getCurrentFundingRate()(int256)")
echo "Current Funding Rate: $FUNDING_RATE"
