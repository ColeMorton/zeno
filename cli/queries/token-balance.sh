#!/bin/bash
# Show token balance and optional allowance
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft token-balance <token_alias> [wallet_address] [spender_address]"
    echo ""
    echo "Arguments:"
    echo "  token_alias      Token alias (wbtc, vbtc, cbbtc, or address)"
    echo "  wallet_address   Wallet to check (defaults to caller)"
    echo "  spender_address  If provided, also shows allowance"
    exit 1
fi

TOKEN_ADDR=$(resolve_token_address "${REMAINING_ARGS[0]}")
WALLET="${REMAINING_ARGS[1]:-$(get_caller_address)}"
SPENDER="${REMAINING_ARGS[2]:-}"

echo "=== Token Balance ==="
echo "Network: $(get_network_name)"
echo "Token:   $TOKEN_ADDR"
echo "Wallet:  $WALLET"
echo ""

BALANCE=$(cast_call "$TOKEN_ADDR" "balanceOf(address)(uint256)" "$WALLET")
echo "Balance: $BALANCE"

if [[ -n "$SPENDER" ]]; then
    ALLOWANCE=$(cast_call "$TOKEN_ADDR" "allowance(address,address)(uint256)" "$WALLET" "$SPENDER")
    echo ""
    echo "Spender:   $SPENDER"
    echo "Allowance: $ALLOWANCE"
fi
