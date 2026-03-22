#!/bin/bash
# Return vBTC tokens to hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-recombine <vault_token_id>"
    echo ""
    echo "Returns vBTC tokens to the hybrid vault, regaining full primary collateral control."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Recombining vBTC with Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Check caller's balance
CALLER=$(get_caller_address)
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")
PRIMARY=$(cast_call "$HYBRID_VAULT" "primaryAmount(uint256)(uint256)" "$TOKEN_ID")

echo "Primary collateral: $(format_btc "$PRIMARY") BTC"
echo "Your vBTC balance:  $(format_btc "$BALANCE") vBTC"
echo ""

# Confirm on testnet
confirm_non_local_action "return vBTC to hybrid vault"

# Return vBTC
echo "Returning vBTC..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "returnBtcToken(uint256)" "$TOKEN_ID")

print_success "vBTC returned to hybrid vault" "$TX_HASH"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
