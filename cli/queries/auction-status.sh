#!/bin/bash
# Display auction status and details
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft auction-status <auction_id> [slot]"
    echo ""
    echo "Arguments:"
    echo "  auction_id  The auction to query"
    echo "  slot        (Optional) For English auctions, query specific slot bid"
    echo ""
    echo "Example:"
    echo "  ./btcnft auction-status 0"
    echo "  ./btcnft auction-status 0 5  (view bid on slot 5)"
    exit 1
fi

AUCTION_ID="${REMAINING_ARGS[0]}"
SLOT="${REMAINING_ARGS[1]:-}"

# Require auction controller
if [[ -z "$AUCTION_CONTROLLER" ]]; then
    echo "Error: AUCTION_CONTROLLER not set in environment" >&2
    echo "Add AUCTION_CONTROLLER=0x... to your .env file" >&2
    exit 1
fi

echo "=== Auction #$AUCTION_ID Status ==="
echo "Network: $(get_network_name)"
echo ""

# Get auction info
# Returns: (AuctionType auctionType, AuctionState state, uint256 maxSupply, uint256 mintedCount, address collateralToken, uint8 tier)
AUCTION_INFO=$(cast_call "$AUCTION_CONTROLLER" "getAuction(uint256)" "$AUCTION_ID")

# Parse the struct fields (each on a new line)
AUCTION_TYPE=$(echo "$AUCTION_INFO" | sed -n '1p')
AUCTION_STATE=$(echo "$AUCTION_INFO" | sed -n '2p')
MAX_SUPPLY=$(echo "$AUCTION_INFO" | sed -n '3p')
MINTED_COUNT=$(echo "$AUCTION_INFO" | sed -n '4p')
COLLATERAL_TOKEN=$(echo "$AUCTION_INFO" | sed -n '5p')
TIER=$(echo "$AUCTION_INFO" | sed -n '6p')

# Map enum values to names
case "$AUCTION_TYPE" in
    0) TYPE_NAME="DUTCH" ;;
    1) TYPE_NAME="ENGLISH" ;;
    *) TYPE_NAME="UNKNOWN($AUCTION_TYPE)" ;;
esac

case "$AUCTION_STATE" in
    0) STATE_NAME="PENDING" ;;
    1) STATE_NAME="ACTIVE" ;;
    2) STATE_NAME="ENDED" ;;
    3) STATE_NAME="FINALIZED" ;;
    *) STATE_NAME="UNKNOWN($AUCTION_STATE)" ;;
esac

echo "=== Basic Info ==="
echo "Type:       $TYPE_NAME"
echo "State:      $STATE_NAME"
echo "Supply:     $MINTED_COUNT / $MAX_SUPPLY"
echo "Collateral: $COLLATERAL_TOKEN"
echo "Tier:       $(get_tier_name "$TIER")"
echo ""

# Get type-specific config
if [[ "$AUCTION_TYPE" == "0" ]]; then
    # Dutch auction
    CONFIG=$(cast_call "$AUCTION_CONTROLLER" "getDutchConfig(uint256)" "$AUCTION_ID")
    START_PRICE=$(echo "$CONFIG" | sed -n '1p')
    FLOOR_PRICE=$(echo "$CONFIG" | sed -n '2p')
    DECAY_RATE=$(echo "$CONFIG" | sed -n '3p')
    START_TIME=$(echo "$CONFIG" | sed -n '4p')
    END_TIME=$(echo "$CONFIG" | sed -n '5p')

    echo "=== Dutch Auction Config ==="
    echo "Start Price:  $(format_btc "$START_PRICE") BTC"
    echo "Floor Price:  $(format_btc "$FLOOR_PRICE") BTC"
    echo "Decay Rate:   $DECAY_RATE satoshis/second"
    echo "Start Time:   $(format_timestamp "$START_TIME")"
    echo "End Time:     $(format_timestamp "$END_TIME")"
    echo ""

    # Show current price if active
    if [[ "$AUCTION_STATE" == "1" ]]; then
        CURRENT_PRICE=$(cast_call "$AUCTION_CONTROLLER" "getCurrentPrice(uint256)(uint256)" "$AUCTION_ID")
        echo "=== Current Price ==="
        echo "Price: $(format_btc "$CURRENT_PRICE") BTC ($CURRENT_PRICE satoshis)"
        echo ""
    fi

else
    # English auction
    CONFIG=$(cast_call "$AUCTION_CONTROLLER" "getEnglishConfig(uint256)" "$AUCTION_ID")
    RESERVE_PRICE=$(echo "$CONFIG" | sed -n '1p')
    MIN_BID_INCREMENT=$(echo "$CONFIG" | sed -n '2p')
    START_TIME=$(echo "$CONFIG" | sed -n '3p')
    END_TIME=$(echo "$CONFIG" | sed -n '4p')
    EXTENSION_WINDOW=$(echo "$CONFIG" | sed -n '5p')
    EXTENSION_DURATION=$(echo "$CONFIG" | sed -n '6p')

    echo "=== English Auction Config ==="
    echo "Reserve Price:     $(format_btc "$RESERVE_PRICE") BTC"
    echo "Min Bid Increment: $MIN_BID_INCREMENT bps ($(echo "scale=2; $MIN_BID_INCREMENT / 100" | bc)%)"
    echo "Start Time:        $(format_timestamp "$START_TIME")"
    echo "End Time:          $(format_timestamp "$END_TIME")"
    echo "Extension Window:  $EXTENSION_WINDOW seconds"
    echo "Extension Duration: $EXTENSION_DURATION seconds"
    echo ""

    # If slot provided, show bid info
    if [[ -n "$SLOT" ]]; then
        BID_INFO=$(cast_call "$AUCTION_CONTROLLER" "getHighestBid(uint256,uint256)" "$AUCTION_ID" "$SLOT")
        BIDDER=$(echo "$BID_INFO" | sed -n '1p')
        BID_AMOUNT=$(echo "$BID_INFO" | sed -n '2p')
        BID_TIMESTAMP=$(echo "$BID_INFO" | sed -n '3p')

        IS_SETTLED=$(cast_call "$AUCTION_CONTROLLER" "isSlotSettled(uint256,uint256)(bool)" "$AUCTION_ID" "$SLOT")

        echo "=== Slot #$SLOT ==="
        if [[ "$BIDDER" == "0x0000000000000000000000000000000000000000" ]]; then
            echo "Status: No bids"
        else
            echo "Highest Bidder: $BIDDER"
            echo "Bid Amount:     $(format_btc "$BID_AMOUNT") BTC"
            echo "Bid Time:       $(format_timestamp "$BID_TIMESTAMP")"
            echo "Settled:        $IS_SETTLED"
        fi
        echo ""
    fi
fi

# Time remaining
CURRENT_TS=$(date +%s)
if [[ "$AUCTION_STATE" == "0" && $CURRENT_TS -lt $START_TIME ]]; then
    REMAINING=$((START_TIME - CURRENT_TS))
    echo "Starts in: $((REMAINING / 86400)) days, $(((REMAINING % 86400) / 3600)) hours"
elif [[ "$AUCTION_STATE" == "1" && $CURRENT_TS -lt $END_TIME ]]; then
    REMAINING=$((END_TIME - CURRENT_TS))
    echo "Ends in: $((REMAINING / 86400)) days, $(((REMAINING % 86400) / 3600)) hours"
fi
