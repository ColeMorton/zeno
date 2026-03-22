#!/bin/bash
# Deposit to the volatility pool
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "VOL_POOL"
require_contract_set "BTC_TOKEN"

if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: vol-deposit <long|short> <amount>"
    echo ""
    echo "Arguments:"
    echo "  long|short  Pool side to deposit into"
    echo "  amount      vBTC amount in satoshis"
    exit 1
fi

SIDE_ARG="${REMAINING_ARGS[0]}"
AMOUNT="${REMAINING_ARGS[1]}"
SIDE=$(parse_side_arg "$SIDE_ARG")

echo "=== Depositing to Volatility Pool ==="
echo "Network: $(get_network_name)"
echo "Side:    $SIDE_ARG"
echo "Amount:  $(format_btc "$AMOUNT") vBTC ($AMOUNT satoshis)"
echo ""

confirm_non_local_action "deposit to volatility pool"

require_balance "$BTC_TOKEN" "$AMOUNT"
approve_erc20 "$BTC_TOKEN" "$VOL_POOL" "$AMOUNT"

echo "Depositing..."
if [[ "$SIDE" == "0" ]]; then
    TX_HASH=$(cast_send "$VOL_POOL" "depositLong(uint256)" "$AMOUNT")
else
    TX_HASH=$(cast_send "$VOL_POOL" "depositShort(uint256)" "$AMOUNT")
fi

print_success "Deposit complete" "$TX_HASH"
