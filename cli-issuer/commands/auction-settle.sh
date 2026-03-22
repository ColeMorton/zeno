#!/bin/bash
# Settle an English auction slot
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "AUCTION_CONTROLLER"

if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: auction-settle <auction_id> <slot>"
    echo ""
    echo "Arguments:"
    echo "  auction_id  ID of the English auction"
    echo "  slot        Slot number to settle"
    exit 1
fi

AUCTION_ID="${REMAINING_ARGS[0]}"
SLOT="${REMAINING_ARGS[1]}"

echo "=== Settling English Auction #$AUCTION_ID, Slot #$SLOT ==="
echo "Network: $(get_network_name)"
echo ""

confirm_non_local_action "settle auction slot"

echo "Settling..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "settleSlot(uint256,uint256)" "$AUCTION_ID" "$SLOT")

print_success "Auction slot settled" "$TX_HASH"
