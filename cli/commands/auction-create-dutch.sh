#!/bin/bash
# Create a Dutch auction (owner only)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 6 ]]; then
    echo "Usage: ./btcnft auction-create-dutch <max_supply> <start_price> <floor_price> <decay_rate> <start_time> <end_time>"
    echo ""
    echo "Arguments:"
    echo "  max_supply    Maximum number of vaults to mint"
    echo "  start_price   Starting price in satoshis"
    echo "  floor_price   Minimum price in satoshis"
    echo "  decay_rate    Price decrease per second in satoshis"
    echo "  start_time    Unix timestamp when auction starts"
    echo "  end_time      Unix timestamp when auction ends"
    echo ""
    echo "Withdrawal Rate: $(get_withdrawal_rate)"
    echo ""
    echo "Example:"
    echo "  ./btcnft auction-create-dutch 100 200000000 100000000 100 1735689600 1735776000"
    echo "  (100 vaults, 2 BTC start, 1 BTC floor, 100 sat/sec decay)"
    exit 1
fi

MAX_SUPPLY="${REMAINING_ARGS[0]}"
START_PRICE="${REMAINING_ARGS[1]}"
FLOOR_PRICE="${REMAINING_ARGS[2]}"
DECAY_RATE="${REMAINING_ARGS[3]}"
START_TIME="${REMAINING_ARGS[4]}"
END_TIME="${REMAINING_ARGS[5]}"

# Require auction controller
if [[ -z "$AUCTION_CONTROLLER" ]]; then
    echo "Error: AUCTION_CONTROLLER not set in environment" >&2
    echo "Add AUCTION_CONTROLLER=0x... to your .env file" >&2
    exit 1
fi

# Validate price config
if [[ $START_PRICE -le $FLOOR_PRICE ]]; then
    echo "Error: Start price must be greater than floor price" >&2
    exit 1
fi

echo "=== Create Dutch Auction ==="
echo "Network:         $(get_network_name)"
echo "Max Supply:      $MAX_SUPPLY vaults"
echo "Start Price:     $(format_btc "$START_PRICE") BTC"
echo "Floor Price:     $(format_btc "$FLOOR_PRICE") BTC"
echo "Decay Rate:      $DECAY_RATE satoshis/second"
echo "Start Time:      $(format_timestamp "$START_TIME")"
echo "End Time:        $(format_timestamp "$END_TIME")"
echo "Withdrawal Rate: $(get_withdrawal_rate)"
echo ""

# Confirm on testnet
confirm_non_local_action "create Dutch auction"

# Create auction
# Function signature: createDutchAuction(uint256 maxSupply, address collateralToken, (uint256 startPrice, uint256 floorPrice, uint256 decayRate, uint256 startTime, uint256 endTime) config)
echo "Creating auction..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "createDutchAuction(uint256,address,(uint256,uint256,uint256,uint256,uint256))" \
    "$MAX_SUPPLY" "$WBTC" "($START_PRICE,$FLOOR_PRICE,$DECAY_RATE,$START_TIME,$END_TIME)")

# Extract auction ID from logs
RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json)
AUCTION_ID=$(echo "$RECEIPT" | jq -r '.logs[0].topics[1]' 2>/dev/null | xargs printf "%d" 2>/dev/null || echo "")

print_success "Dutch auction created" "$TX_HASH"
if [[ -n "$AUCTION_ID" ]]; then
    echo "Auction ID: $AUCTION_ID"
    echo ""
    echo "View auction: ./btcnft auction-status $AUCTION_ID"
fi
