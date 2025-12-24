#!/bin/bash
# Mint a new Vault NFT (after minting window closes)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft mint <treasure_token_id> <btc_amount_satoshis>"
    echo ""
    echo "Arguments:"
    echo "  treasure_token_id   ID of the Treasure NFT to lock"
    echo "  btc_amount_satoshis Collateral amount in satoshis (100000000 = 1 BTC)"
    echo ""
    echo "Withdrawal Rate: $(get_withdrawal_rate)"
    echo ""
    echo "Example:"
    echo "  ./btcnft mint 0 100000000"
    echo "  (Mint vault with Treasure #0, 1 BTC)"
    exit 1
fi

TREASURE_ID="${REMAINING_ARGS[0]}"
BTC_AMOUNT="${REMAINING_ARGS[1]}"

echo "=== Minting Vault NFT ==="
echo "Network:         $(get_network_name)"
echo "Treasure ID:     $TREASURE_ID"
echo "Collateral:      $(format_btc "$BTC_AMOUNT") BTC ($BTC_AMOUNT satoshis)"
echo "Withdrawal Rate: $(get_withdrawal_rate)"
echo ""

# Confirm on testnet
confirm_testnet_action "mint a vault"

# Approve WBTC
echo "Approving WBTC..."
cast send "$WBTC" "approve(address,uint256)" "$VAULT" "$BTC_AMOUNT" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Approve Treasure NFT
echo "Approving Treasure NFT..."
cast send "$TREASURE" "setApprovalForAll(address,bool)" "$VAULT" true \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Mint vault
echo "Minting vault..."
TX_HASH=$(cast_send "$VAULT" "mint(address,uint256,address,uint256)" \
    "$TREASURE" "$TREASURE_ID" "$WBTC" "$BTC_AMOUNT")

# Extract token ID from logs
TOKEN_ID=$(parse_token_id_from_log "$TX_HASH")

print_success "Vault minted successfully" "$TX_HASH"
echo "Vault Token ID: $TOKEN_ID"
print_vault_summary "$TOKEN_ID"
