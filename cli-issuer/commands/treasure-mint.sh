#!/bin/bash
# Mint Treasure NFT(s) to a recipient
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "TREASURE_NFT"

if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: treasure-mint <recipient_address> [count]"
    echo ""
    echo "Arguments:"
    echo "  recipient_address  Address to receive the NFT(s)"
    echo "  count              Number to mint (default: 1)"
    exit 1
fi

RECIPIENT="${REMAINING_ARGS[0]}"
COUNT="${REMAINING_ARGS[1]:-1}"

echo "=== Minting Treasure NFT ==="
echo "Network:   $(get_network_name)"
echo "Recipient: $RECIPIENT"
echo "Count:     $COUNT"
echo ""

confirm_non_local_action "mint treasure NFT(s)"

echo "Minting..."
if [[ "$COUNT" -gt 1 ]]; then
    TX_HASH=$(cast_send "$TREASURE_NFT" "mintBatch(address,uint256)" "$RECIPIENT" "$COUNT")
else
    TX_HASH=$(cast_send "$TREASURE_NFT" "mint(address)" "$RECIPIENT")
fi

print_success "Treasure NFT minted" "$TX_HASH"
