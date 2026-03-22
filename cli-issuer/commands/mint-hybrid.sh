#!/bin/bash
# Mint a hybrid vault via the issuer's hybrid mint controller
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "HYBRID_MINT_CONTROLLER"
require_contract_set "CBBTC"

if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: mint-hybrid <cbbtc_amount>"
    echo ""
    echo "Arguments:"
    echo "  cbbtc_amount  cbBTC amount in satoshis (100000000 = 1 BTC)"
    exit 1
fi

AMOUNT="${REMAINING_ARGS[0]}"

echo "=== Minting Hybrid Vault ==="
echo "Network:    $(get_network_name)"
echo "Collateral: $(format_btc "$AMOUNT") cbBTC ($AMOUNT satoshis)"
echo ""

confirm_non_local_action "mint a hybrid vault"

require_balance "$CBBTC" "$AMOUNT"
approve_erc20 "$CBBTC" "$HYBRID_MINT_CONTROLLER" "$AMOUNT"

echo "Minting hybrid vault..."
TX_HASH=$(cast_send "$HYBRID_MINT_CONTROLLER" "mintHybridVault(uint256)" "$AMOUNT")

TOKEN_ID=$(parse_token_id_from_log "$TX_HASH")

print_success "Hybrid vault minted successfully" "$TX_HASH"
echo "Vault Token ID: $TOKEN_ID"
