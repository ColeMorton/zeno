#!/bin/bash
# Create an English auction via the auction controller
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "AUCTION_CONTROLLER"

if [[ ${#REMAINING_ARGS[@]} -lt 5 ]]; then
    echo "Usage: auction-create-english <max_supply> <collateral_token_alias> <min_bid> <bid_increment> <slot_duration>"
    echo ""
    echo "Arguments:"
    echo "  max_supply              Maximum number of vaults"
    echo "  collateral_token_alias  Token alias (wbtc, vbtc, cbbtc)"
    echo "  min_bid                 Minimum bid in satoshis"
    echo "  bid_increment           Minimum bid increment in satoshis"
    echo "  slot_duration           Duration per slot in seconds"
    exit 1
fi

MAX_SUPPLY="${REMAINING_ARGS[0]}"
TOKEN_ALIAS="${REMAINING_ARGS[1]}"
MIN_BID="${REMAINING_ARGS[2]}"
BID_INCREMENT="${REMAINING_ARGS[3]}"
SLOT_DURATION="${REMAINING_ARGS[4]}"

TOKEN_ADDRESS=$(resolve_token_address "$TOKEN_ALIAS")

echo "=== Creating English Auction ==="
echo "Network:       $(get_network_name)"
echo "Max Supply:    $MAX_SUPPLY"
echo "Token:         $TOKEN_ALIAS ($TOKEN_ADDRESS)"
echo "Min Bid:       $(format_btc "$MIN_BID") BTC"
echo "Bid Increment: $(format_btc "$BID_INCREMENT") BTC"
echo "Slot Duration: $SLOT_DURATION seconds"
echo ""

confirm_non_local_action "create an English auction"

echo "Creating auction..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" \
    "createEnglishAuction(uint256,address,(uint256,uint256,uint256))" \
    "$MAX_SUPPLY" "$TOKEN_ADDRESS" "($MIN_BID,$BID_INCREMENT,$SLOT_DURATION)")

print_success "English auction created" "$TX_HASH"
