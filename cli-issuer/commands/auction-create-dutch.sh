#!/bin/bash
# Create a Dutch auction via the auction controller
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "AUCTION_CONTROLLER"

if [[ ${#REMAINING_ARGS[@]} -lt 5 ]]; then
    echo "Usage: auction-create-dutch <max_supply> <collateral_token_alias> <start_price> <end_price> <duration_seconds>"
    echo ""
    echo "Arguments:"
    echo "  max_supply              Maximum number of vaults"
    echo "  collateral_token_alias  Token alias (wbtc, vbtc, cbbtc)"
    echo "  start_price             Starting price in satoshis"
    echo "  end_price               Ending price in satoshis"
    echo "  duration_seconds        Auction duration in seconds"
    exit 1
fi

MAX_SUPPLY="${REMAINING_ARGS[0]}"
TOKEN_ALIAS="${REMAINING_ARGS[1]}"
START_PRICE="${REMAINING_ARGS[2]}"
END_PRICE="${REMAINING_ARGS[3]}"
DURATION="${REMAINING_ARGS[4]}"

TOKEN_ADDRESS=$(resolve_token_address "$TOKEN_ALIAS")

echo "=== Creating Dutch Auction ==="
echo "Network:    $(get_network_name)"
echo "Max Supply: $MAX_SUPPLY"
echo "Token:      $TOKEN_ALIAS ($TOKEN_ADDRESS)"
echo "Start:      $(format_btc "$START_PRICE") BTC"
echo "End:        $(format_btc "$END_PRICE") BTC"
echo "Duration:   $DURATION seconds"
echo ""

confirm_non_local_action "create a Dutch auction"

echo "Creating auction..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" \
    "createDutchAuction(uint256,address,(uint256,uint256,uint256))" \
    "$MAX_SUPPLY" "$TOKEN_ADDRESS" "($START_PRICE,$END_PRICE,$DURATION)")

print_success "Dutch auction created" "$TX_HASH"
