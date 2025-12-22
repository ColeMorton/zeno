#!/bin/bash
# Create an English auction (owner only)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 7 ]]; then
    echo "Usage: ./btcnft auction-create-english <max_supply> <reserve_price> <min_bid_bps> <start_time> <end_time> <extension_window> <extension_duration> [tier]"
    echo ""
    echo "Arguments:"
    echo "  max_supply           Maximum number of slots (vaults)"
    echo "  reserve_price        Minimum bid in satoshis"
    echo "  min_bid_bps          Minimum bid increment in basis points (100 = 1%)"
    echo "  start_time           Unix timestamp when auction starts"
    echo "  end_time             Unix timestamp when auction ends"
    echo "  extension_window     Seconds before end that triggers extension"
    echo "  extension_duration   Seconds to extend when bid placed near end"
    echo "  tier                 (Optional) Vault tier: 0=Conservative, 1=Balanced, 2=Aggressive (default: 0)"
    echo ""
    echo "Example:"
    echo "  ./btcnft auction-create-english 10 100000000 500 1735689600 1735776000 300 600"
    echo "  (10 slots, 1 BTC reserve, 5% min increment, 5min/10min anti-snipe)"
    exit 1
fi

MAX_SUPPLY="${REMAINING_ARGS[0]}"
RESERVE_PRICE="${REMAINING_ARGS[1]}"
MIN_BID_BPS="${REMAINING_ARGS[2]}"
START_TIME="${REMAINING_ARGS[3]}"
END_TIME="${REMAINING_ARGS[4]}"
EXTENSION_WINDOW="${REMAINING_ARGS[5]}"
EXTENSION_DURATION="${REMAINING_ARGS[6]}"
TIER="${REMAINING_ARGS[7]:-0}"

# Require auction controller
if [[ -z "$AUCTION_CONTROLLER" ]]; then
    echo "Error: AUCTION_CONTROLLER not set in environment" >&2
    echo "Add AUCTION_CONTROLLER=0x... to your .env file" >&2
    exit 1
fi

# Validate tier
if [[ $TIER -lt 0 || $TIER -gt 2 ]]; then
    echo "Error: Invalid tier. Must be 0, 1, or 2" >&2
    exit 1
fi

echo "=== Create English Auction ==="
echo "Network:             $(get_network_name)"
echo "Max Supply:          $MAX_SUPPLY slots"
echo "Reserve Price:       $(format_btc "$RESERVE_PRICE") BTC"
echo "Min Bid Increment:   $MIN_BID_BPS bps ($(echo "scale=2; $MIN_BID_BPS / 100" | bc)%)"
echo "Start Time:          $(format_timestamp "$START_TIME")"
echo "End Time:            $(format_timestamp "$END_TIME")"
echo "Extension Window:    $EXTENSION_WINDOW seconds"
echo "Extension Duration:  $EXTENSION_DURATION seconds"
echo "Tier:                $(get_tier_name "$TIER")"
echo ""

# Confirm on testnet
confirm_testnet_action "create English auction"

# Create auction
# Function signature: createEnglishAuction(uint256 maxSupply, address collateralToken, uint8 tier, (uint256 reservePrice, uint256 minBidIncrement, uint256 startTime, uint256 endTime, uint256 extensionWindow, uint256 extensionDuration) config)
echo "Creating auction..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "createEnglishAuction(uint256,address,uint8,(uint256,uint256,uint256,uint256,uint256,uint256))" \
    "$MAX_SUPPLY" "$WBTC" "$TIER" "($RESERVE_PRICE,$MIN_BID_BPS,$START_TIME,$END_TIME,$EXTENSION_WINDOW,$EXTENSION_DURATION)")

# Extract auction ID from logs
RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json)
AUCTION_ID=$(echo "$RECEIPT" | jq -r '.logs[0].topics[1]' 2>/dev/null | xargs printf "%d" 2>/dev/null || echo "")

print_success "English auction created" "$TX_HASH"
if [[ -n "$AUCTION_ID" ]]; then
    echo "Auction ID: $AUCTION_ID"
    echo ""
    echo "View auction: ./btcnft auction-status $AUCTION_ID"
fi
