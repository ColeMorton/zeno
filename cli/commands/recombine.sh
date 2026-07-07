#!/bin/bash
# Burn vBTC to reactivate reserve collateral
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft recombine <vault_token_id> <amount_satoshis>"
    echo ""
    echo "Burns vBTC to move reserve back into active collateral (1:1)."
    echo "Fractional and repeatable; can be called until reserve reaches zero."
    echo ""
    echo "Arguments:"
    echo "  vault_token_id     Vault to recombine into"
    echo "  amount_satoshis    Amount of vBTC to burn (100000000 = 1 BTC)"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
AMOUNT="${REMAINING_ARGS[1]}"

echo "=== Recombining vBTC into Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Get reserve balance
RESERVE=$(cast_call "$VAULT" "strippedReserve(uint256)(uint256)" "$TOKEN_ID")
if [[ "$RESERVE" == "0" ]]; then
    echo "Error: No reserve to recombine for this vault" >&2
    exit 1
fi

if [[ $AMOUNT -gt $RESERVE ]]; then
    echo "Error: Insufficient reserve to recombine" >&2
    echo "Requested: $(format_btc "$AMOUNT") BTC" >&2
    echo "Available: $(format_btc "$RESERVE") BTC" >&2
    exit 1
fi

# Check caller's vBTC balance
CALLER=$(get_caller_address)
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

echo "Reserve to recombine: $(format_btc "$RESERVE") BTC"
echo "Amount requested:     $(format_btc "$AMOUNT") BTC"
echo "Your vBTC balance:    $(format_btc "$BALANCE") vBTC"
echo ""

if [[ $BALANCE -lt $AMOUNT ]]; then
    echo "Error: Insufficient vBTC balance" >&2
    echo "Required: $(format_btc "$AMOUNT") vBTC" >&2
    echo "Have:     $(format_btc "$BALANCE") vBTC" >&2
    exit 1
fi

# Confirm on testnet
confirm_non_local_action "recombine vBTC into vault"

# Recombine vBTC
echo "Burning vBTC and reactivating reserve..."
TX_HASH=$(cast_send "$VAULT" "recombine(uint256,uint256)" "$TOKEN_ID" "$AMOUNT")

print_success "vBTC recombined" "$TX_HASH"
echo ""
echo "View vault status: ./btcnft status $TOKEN_ID"
