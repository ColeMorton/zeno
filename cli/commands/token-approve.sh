#!/bin/bash
# Approve ERC-20 token spending
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

if [[ ${#REMAINING_ARGS[@]} -lt 3 ]]; then
    echo "Usage: ./btcnft token-approve <token_alias> <spender_address> <amount>"
    echo ""
    echo "Arguments:"
    echo "  token_alias      Token alias (wbtc, vbtc, cbbtc, or address)"
    echo "  spender_address  Address to approve spending for"
    echo "  amount           Amount to approve (in token base units)"
    exit 1
fi

TOKEN_ADDR=$(resolve_token_address "${REMAINING_ARGS[0]}")
SPENDER="${REMAINING_ARGS[1]}"
AMOUNT="${REMAINING_ARGS[2]}"

echo "=== Approving Token Spend ==="
echo "Network: $(get_network_name)"
echo "Token:   $TOKEN_ADDR"
echo "Spender: $SPENDER"
echo "Amount:  $AMOUNT"
echo ""

confirm_non_local_action "approve token spending"

echo "Approving..."
TX_HASH=$(cast_send "$TOKEN_ADDR" "approve(address,uint256)" "$SPENDER" "$AMOUNT")

print_success "Token approval set" "$TX_HASH"
