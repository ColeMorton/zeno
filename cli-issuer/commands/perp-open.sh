#!/bin/bash
# Open a leveraged perpetual position
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "PERP_VAULT"
require_contract_set "BTC_TOKEN"

if [[ ${#REMAINING_ARGS[@]} -lt 3 ]]; then
    echo "Usage: perp-open <collateral_amount> <leverage_x100> <long|short>"
    echo ""
    echo "Arguments:"
    echo "  collateral_amount  vBTC collateral in satoshis"
    echo "  leverage_x100      Leverage multiplied by 100 (e.g. 200 = 2x)"
    echo "  long|short         Position side"
    exit 1
fi

AMOUNT="${REMAINING_ARGS[0]}"
LEVERAGE="${REMAINING_ARGS[1]}"
SIDE_ARG="${REMAINING_ARGS[2]}"
SIDE=$(parse_side_arg "$SIDE_ARG")

echo "=== Opening Perpetual Position ==="
echo "Network:    $(get_network_name)"
echo "Collateral: $(format_btc "$AMOUNT") vBTC ($AMOUNT satoshis)"
echo "Leverage:   $(echo "scale=2; $LEVERAGE / 100" | bc)x"
echo "Side:       $SIDE_ARG"
echo ""

confirm_non_local_action "open a perpetual position"

require_balance "$BTC_TOKEN" "$AMOUNT"
approve_erc20 "$BTC_TOKEN" "$PERP_VAULT" "$AMOUNT"

echo "Opening position..."
TX_HASH=$(cast_send "$PERP_VAULT" "openPosition(uint256,uint256,uint8)" "$AMOUNT" "$LEVERAGE" "$SIDE")

print_success "Position opened" "$TX_HASH"
