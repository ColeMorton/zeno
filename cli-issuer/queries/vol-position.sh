#!/bin/bash
# Show user's volatility pool position
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "VOL_POOL"

ADDRESS="${1:-$(get_caller_address)}"

echo "=== Volatility Position for $ADDRESS ==="
echo ""

LONG_SHARES=$(cast_call "$VOL_POOL" "longSharesOf(address)(uint256)" "$ADDRESS")
SHORT_SHARES=$(cast_call "$VOL_POOL" "shortSharesOf(address)(uint256)" "$ADDRESS")

echo "Long Shares:  $LONG_SHARES"
echo "Short Shares: $SHORT_SHARES"

if [[ "$LONG_SHARES" != "0" ]]; then
    LONG_VALUE=$(cast_call "$VOL_POOL" "previewWithdrawLong(uint256)(uint256)" "$LONG_SHARES")
    echo "Long Value:   $(format_btc "$LONG_VALUE") BTC"
fi

if [[ "$SHORT_SHARES" != "0" ]]; then
    SHORT_VALUE=$(cast_call "$VOL_POOL" "previewWithdrawShort(uint256)(uint256)" "$SHORT_SHARES")
    echo "Short Value:  $(format_btc "$SHORT_VALUE") BTC"
fi
