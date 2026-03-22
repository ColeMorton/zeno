#!/bin/bash
# Mint a new Hybrid Vault NFT (dual-collateral)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 3 ]]; then
    echo "Usage: ./btcnft hybrid-mint <treasure_token_id> <primary_amount_satoshis> <secondary_amount_satoshis>"
    echo ""
    echo "Arguments:"
    echo "  treasure_token_id         ID of the Treasure NFT to lock"
    echo "  primary_amount_satoshis   Primary collateral (WBTC) in satoshis"
    echo "  secondary_amount_satoshis Secondary collateral (cbBTC) in satoshis"
    echo ""
    echo "Withdrawal Rate: Primary $(get_withdrawal_rate), Secondary 100% one-time"
    echo ""
    echo "Example:"
    echo "  ./btcnft hybrid-mint 0 100000000 50000000"
    echo "  (Mint with Treasure #0, 1 WBTC primary, 0.5 cbBTC secondary)"
    exit 1
fi

TREASURE_ID="${REMAINING_ARGS[0]}"
PRIMARY_AMOUNT="${REMAINING_ARGS[1]}"
SECONDARY_AMOUNT="${REMAINING_ARGS[2]}"

echo "=== Minting Hybrid Vault ==="
echo "Network:    $(get_network_name)"
echo "Treasure:   #$TREASURE_ID"
echo "Primary:    $(format_btc "$PRIMARY_AMOUNT") WBTC ($PRIMARY_AMOUNT satoshis)"
echo "Secondary:  $(format_btc "$SECONDARY_AMOUNT") cbBTC ($SECONDARY_AMOUNT satoshis)"
echo ""

# Confirm on testnet
confirm_non_local_action "mint a hybrid vault"

# Check balances
require_balance "$WBTC" "$PRIMARY_AMOUNT"
require_contract_set "CBBTC"
require_balance "$CBBTC" "$SECONDARY_AMOUNT"

# Approve primary (WBTC)
echo "Approving WBTC..."
cast send "$WBTC" "approve(address,uint256)" "$HYBRID_VAULT" "$PRIMARY_AMOUNT" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Approve secondary (cbBTC)
echo "Approving cbBTC..."
cast send "$CBBTC" "approve(address,uint256)" "$HYBRID_VAULT" "$SECONDARY_AMOUNT" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Approve Treasure NFT
echo "Approving Treasure NFT..."
cast send "$TREASURE" "setApprovalForAll(address,bool)" "$HYBRID_VAULT" true \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Mint hybrid vault
echo "Minting hybrid vault..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "mint(address,uint256,uint256,uint256)" \
    "$TREASURE" "$TREASURE_ID" "$PRIMARY_AMOUNT" "$SECONDARY_AMOUNT")

# Extract token ID from logs
TOKEN_ID=$(parse_token_id_from_log "$TX_HASH")

print_success "Hybrid vault minted successfully" "$TX_HASH"
echo "Vault Token ID: $TOKEN_ID"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
