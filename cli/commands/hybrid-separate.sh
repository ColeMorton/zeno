#!/bin/bash
# Mint vBTC tokens from a vested hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-separate <vault_token_id>"
    echo ""
    echo "Mints vBTC tokens representing the hybrid vault's primary collateral claim."
    echo "Requires vault to be fully vested."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Separating vBTC from Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists and is vested
require_hybrid_vault_exists "$TOKEN_ID"
require_hybrid_vested "$TOKEN_ID"

# Get primary collateral to show expected vBTC
PRIMARY=$(cast_call "$HYBRID_VAULT" "primaryAmount(uint256)(uint256)" "$TOKEN_ID")
echo "Primary collateral: $(format_btc "$PRIMARY") BTC"
echo "vBTC to mint:       $(format_btc "$PRIMARY") vBTC"
echo ""

# Confirm on testnet
confirm_non_local_action "mint vBTC from hybrid vault"

# Mint vBTC
echo "Minting vBTC..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "mintBtcToken(uint256)" "$TOKEN_ID")

# Get caller's vBTC balance
CALLER=$(get_caller_address)
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

print_success "vBTC minted from hybrid vault" "$TX_HASH"
echo "Your vBTC balance: $(format_btc "$BALANCE") vBTC"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
