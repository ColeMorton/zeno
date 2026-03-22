#!/bin/bash
# Mint a vault via the issuer's mint controller
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "VAULT_MINT_CONTROLLER"
require_contract_set "WBTC"

if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: mint-vault <collateral_amount>"
    echo ""
    echo "Arguments:"
    echo "  collateral_amount  WBTC amount in satoshis (100000000 = 1 BTC)"
    exit 1
fi

AMOUNT="${REMAINING_ARGS[0]}"
EMPTY_BYTES32="0x0000000000000000000000000000000000000000000000000000000000000000"

echo "=== Minting Vault ==="
echo "Network:    $(get_network_name)"
echo "Collateral: $(format_btc "$AMOUNT") BTC ($AMOUNT satoshis)"
echo ""

confirm_non_local_action "mint a vault"

require_balance "$WBTC" "$AMOUNT"
approve_erc20 "$WBTC" "$VAULT_MINT_CONTROLLER" "$AMOUNT"

echo "Minting vault..."
TX_HASH=$(cast_send "$VAULT_MINT_CONTROLLER" "mintVault(bytes32,uint256)" "$EMPTY_BYTES32" "$AMOUNT")

TOKEN_ID=$(parse_token_id_from_log "$TX_HASH")

print_success "Vault minted successfully" "$TX_HASH"
echo "Vault Token ID: $TOKEN_ID"
