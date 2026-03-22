#!/bin/bash
# Withdraw from the volatility pool
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "VOL_POOL"

if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: vol-withdraw <long|short> <shares>"
    echo ""
    echo "Arguments:"
    echo "  long|short  Pool side to withdraw from"
    echo "  shares      Number of shares to redeem"
    exit 1
fi

SIDE_ARG="${REMAINING_ARGS[0]}"
SHARES="${REMAINING_ARGS[1]}"
SIDE=$(parse_side_arg "$SIDE_ARG")

echo "=== Withdrawing from Volatility Pool ==="
echo "Network: $(get_network_name)"
echo "Side:    $SIDE_ARG"
echo "Shares:  $SHARES"
echo ""

confirm_non_local_action "withdraw from volatility pool"

echo "Withdrawing..."
if [[ "$SIDE" == "0" ]]; then
    TX_HASH=$(cast_send "$VOL_POOL" "withdrawLong(uint256)" "$SHARES")
else
    TX_HASH=$(cast_send "$VOL_POOL" "withdrawShort(uint256)" "$SHARES")
fi

print_success "Withdrawal complete" "$TX_HASH"
