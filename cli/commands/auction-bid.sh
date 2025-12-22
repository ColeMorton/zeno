#!/bin/bash
# Place a bid on an English auction slot
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 3 ]]; then
    echo "Usage: ./btcnft auction-bid <auction_id> <slot> <amount_satoshis>"
    echo ""
    echo "Arguments:"
    echo "  auction_id       The English auction to bid on"
    echo "  slot             Slot number (0 to maxSupply-1)"
    echo "  amount_satoshis  Bid amount in satoshis"
    echo ""
    echo "Example:"
    echo "  ./btcnft auction-bid 0 5 150000000"
    echo "  (Bid 1.5 BTC on slot 5 of auction 0)"
    exit 1
fi

AUCTION_ID="${REMAINING_ARGS[0]}"
SLOT="${REMAINING_ARGS[1]}"
BID_AMOUNT="${REMAINING_ARGS[2]}"

# Require auction controller
if [[ -z "$AUCTION_CONTROLLER" ]]; then
    echo "Error: AUCTION_CONTROLLER not set in environment" >&2
    echo "Add AUCTION_CONTROLLER=0x... to your .env file" >&2
    exit 1
fi

# Verify auction is English type and active
AUCTION_INFO=$(cast_call "$AUCTION_CONTROLLER" "getAuction(uint256)" "$AUCTION_ID")
AUCTION_TYPE=$(echo "$AUCTION_INFO" | sed -n '1p')
AUCTION_STATE=$(echo "$AUCTION_INFO" | sed -n '2p')
MAX_SUPPLY=$(echo "$AUCTION_INFO" | sed -n '3p')
COLLATERAL_TOKEN=$(echo "$AUCTION_INFO" | sed -n '5p')

if [[ "$AUCTION_TYPE" != "1" ]]; then
    echo "Error: Auction #$AUCTION_ID is not an English auction" >&2
    exit 1
fi

if [[ "$AUCTION_STATE" != "1" ]]; then
    case "$AUCTION_STATE" in
        0) echo "Error: Auction has not started yet" >&2 ;;
        2) echo "Error: Auction has ended" >&2 ;;
        3) echo "Error: Auction is finalized" >&2 ;;
        *) echo "Error: Auction is not active (state: $AUCTION_STATE)" >&2 ;;
    esac
    exit 1
fi

# Validate slot
if [[ $SLOT -ge $MAX_SUPPLY ]]; then
    echo "Error: Slot $SLOT is out of range (max: $((MAX_SUPPLY - 1)))" >&2
    exit 1
fi

# Get current highest bid
BID_INFO=$(cast_call "$AUCTION_CONTROLLER" "getHighestBid(uint256,uint256)" "$AUCTION_ID" "$SLOT")
CURRENT_BIDDER=$(echo "$BID_INFO" | sed -n '1p')
CURRENT_BID=$(echo "$BID_INFO" | sed -n '2p')

echo "=== English Auction Bid ==="
echo "Network:     $(get_network_name)"
echo "Auction ID:  $AUCTION_ID"
echo "Slot:        $SLOT"
echo "Your Bid:    $(format_btc "$BID_AMOUNT") BTC ($BID_AMOUNT satoshis)"
echo ""

if [[ "$CURRENT_BIDDER" != "0x0000000000000000000000000000000000000000" ]]; then
    echo "Current Bid: $(format_btc "$CURRENT_BID") BTC by $CURRENT_BIDDER"
    echo ""
fi

# Confirm on testnet
confirm_testnet_action "place bid on auction slot"

# Approve collateral token
echo "Approving collateral token..."
cast send "$COLLATERAL_TOKEN" "approve(address,uint256)" "$AUCTION_CONTROLLER" "$BID_AMOUNT" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Place bid
echo "Placing bid..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "placeBid(uint256,uint256,uint256)" "$AUCTION_ID" "$SLOT" "$BID_AMOUNT")

print_success "Bid placed successfully" "$TX_HASH"
echo "Slot: $SLOT"
echo "Amount: $(format_btc "$BID_AMOUNT") BTC"
echo ""
echo "View auction: ./btcnft auction-status $AUCTION_ID $SLOT"
