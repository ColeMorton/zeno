#!/bin/bash
# Query auction details by auction ID
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "AUCTION_CONTROLLER"

AUCTION_ID="${1:?Usage: auction-status.sh <auction_id>}"

echo "=== Auction #$AUCTION_ID ==="
echo ""

AUCTION=$(cast_call "$AUCTION_CONTROLLER" "getAuction(uint256)" "$AUCTION_ID")
echo "Auction Data:"
echo "$AUCTION"
echo ""

STATE=$(cast_call "$AUCTION_CONTROLLER" "getAuctionState(uint256)" "$AUCTION_ID")
echo "State: $STATE"
echo ""

if [[ "$STATE" == *"Dutch"* || "$STATE" == *"0"* ]]; then
    CURRENT_PRICE=$(cast_call "$AUCTION_CONTROLLER" "getCurrentPrice(uint256)(uint256)" "$AUCTION_ID")
    echo "Current Price: $(format_btc "$CURRENT_PRICE") BTC"

    echo ""
    echo "Dutch Config:"
    DUTCH_CONFIG=$(cast_call "$AUCTION_CONTROLLER" "getDutchConfig(uint256)" "$AUCTION_ID")
    echo "$DUTCH_CONFIG"
elif [[ "$STATE" == *"English"* || "$STATE" == *"1"* ]]; then
    echo "English Config:"
    ENGLISH_CONFIG=$(cast_call "$AUCTION_CONTROLLER" "getEnglishConfig(uint256)" "$AUCTION_ID")
    echo "$ENGLISH_CONFIG"
fi
