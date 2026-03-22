#!/bin/bash
# Purchase from a Dutch auction
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "AUCTION_CONTROLLER"

if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: auction-purchase <auction_id>"
    echo ""
    echo "Arguments:"
    echo "  auction_id  ID of the Dutch auction"
    exit 1
fi

AUCTION_ID="${REMAINING_ARGS[0]}"

echo "=== Purchasing from Dutch Auction #$AUCTION_ID ==="
echo "Network: $(get_network_name)"
echo ""

CURRENT_PRICE=$(cast_call "$AUCTION_CONTROLLER" "getCurrentPrice(uint256)(uint256)" "$AUCTION_ID")
echo "Current Price: $(format_btc "$CURRENT_PRICE") BTC ($CURRENT_PRICE satoshis)"

confirm_non_local_action "purchase from Dutch auction"

COLLATERAL_TOKEN=$(cast_call "$AUCTION_CONTROLLER" "collateralToken(uint256)(address)" "$AUCTION_ID")
require_balance "$COLLATERAL_TOKEN" "$CURRENT_PRICE"
approve_erc20 "$COLLATERAL_TOKEN" "$AUCTION_CONTROLLER" "$CURRENT_PRICE"

echo "Purchasing..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "purchaseDutch(uint256)" "$AUCTION_ID")

print_success "Dutch auction purchase complete" "$TX_HASH"
