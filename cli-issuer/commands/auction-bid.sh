#!/bin/bash
# Place a bid on an English auction
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "AUCTION_CONTROLLER"

if [[ ${#REMAINING_ARGS[@]} -lt 3 ]]; then
    echo "Usage: auction-bid <auction_id> <slot> <amount>"
    echo ""
    echo "Arguments:"
    echo "  auction_id  ID of the English auction"
    echo "  slot        Slot number to bid on"
    echo "  amount      Bid amount in satoshis"
    exit 1
fi

AUCTION_ID="${REMAINING_ARGS[0]}"
SLOT="${REMAINING_ARGS[1]}"
AMOUNT="${REMAINING_ARGS[2]}"

echo "=== Bidding on English Auction #$AUCTION_ID ==="
echo "Network: $(get_network_name)"
echo "Slot:    $SLOT"
echo "Amount:  $(format_btc "$AMOUNT") BTC ($AMOUNT satoshis)"
echo ""

confirm_non_local_action "place a bid"

COLLATERAL_TOKEN=$(cast_call "$AUCTION_CONTROLLER" "collateralToken(uint256)(address)" "$AUCTION_ID")
require_balance "$COLLATERAL_TOKEN" "$AMOUNT"
approve_erc20 "$COLLATERAL_TOKEN" "$AUCTION_CONTROLLER" "$AMOUNT"

echo "Placing bid..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "placeBid(uint256,uint256,uint256)" "$AUCTION_ID" "$SLOT" "$AMOUNT")

print_success "Bid placed successfully" "$TX_HASH"
