#!/bin/bash
# Settle an English auction slot (mint vault to winner)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft auction-settle <auction_id> <slot>"
    echo ""
    echo "Arguments:"
    echo "  auction_id  The English auction"
    echo "  slot        Slot number to settle"
    echo ""
    echo "Example:"
    echo "  ./btcnft auction-settle 0 5"
    exit 1
fi

AUCTION_ID="${REMAINING_ARGS[0]}"
SLOT="${REMAINING_ARGS[1]}"

# Require auction controller
if [[ -z "$AUCTION_CONTROLLER" ]]; then
    echo "Error: AUCTION_CONTROLLER not set in environment" >&2
    echo "Add AUCTION_CONTROLLER=0x... to your .env file" >&2
    exit 1
fi

# Verify auction is English type and ended
AUCTION_INFO=$(cast_call "$AUCTION_CONTROLLER" "getAuction(uint256)" "$AUCTION_ID")
AUCTION_TYPE=$(echo "$AUCTION_INFO" | sed -n '1p')
AUCTION_STATE=$(echo "$AUCTION_INFO" | sed -n '2p')
MAX_SUPPLY=$(echo "$AUCTION_INFO" | sed -n '3p')

if [[ "$AUCTION_TYPE" != "1" ]]; then
    echo "Error: Auction #$AUCTION_ID is not an English auction" >&2
    exit 1
fi

if [[ "$AUCTION_STATE" != "2" && "$AUCTION_STATE" != "3" ]]; then
    case "$AUCTION_STATE" in
        0) echo "Error: Auction has not started yet" >&2 ;;
        1) echo "Error: Auction is still active" >&2 ;;
        *) echo "Error: Auction state not valid for settlement (state: $AUCTION_STATE)" >&2 ;;
    esac
    exit 1
fi

# Validate slot
if [[ $SLOT -ge $MAX_SUPPLY ]]; then
    echo "Error: Slot $SLOT is out of range (max: $((MAX_SUPPLY - 1)))" >&2
    exit 1
fi

# Check if already settled
IS_SETTLED=$(cast_call "$AUCTION_CONTROLLER" "isSlotSettled(uint256,uint256)(bool)" "$AUCTION_ID" "$SLOT")
if [[ "$IS_SETTLED" == "true" ]]; then
    echo "Error: Slot $SLOT is already settled" >&2
    exit 1
fi

# Get winning bid info
BID_INFO=$(cast_call "$AUCTION_CONTROLLER" "getHighestBid(uint256,uint256)" "$AUCTION_ID" "$SLOT")
WINNER=$(echo "$BID_INFO" | sed -n '1p')
WINNING_BID=$(echo "$BID_INFO" | sed -n '2p')

if [[ "$WINNER" == "0x0000000000000000000000000000000000000000" ]]; then
    echo "Error: No bids on slot $SLOT" >&2
    exit 1
fi

echo "=== Settle Auction Slot ==="
echo "Network:     $(get_network_name)"
echo "Auction ID:  $AUCTION_ID"
echo "Slot:        $SLOT"
echo "Winner:      $WINNER"
echo "Winning Bid: $(format_btc "$WINNING_BID") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "settle auction slot"

# Settle slot
echo "Settling..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "settleSlot(uint256,uint256)" "$AUCTION_ID" "$SLOT")

# Extract vault ID from logs
RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json)
VAULT_ID=$(echo "$RECEIPT" | jq -r '.logs[0].topics[1]' 2>/dev/null | xargs printf "%d" 2>/dev/null || echo "")

print_success "Slot settled successfully" "$TX_HASH"
echo "Winner: $WINNER"
if [[ -n "$VAULT_ID" && "$VAULT_ID" != "0" ]]; then
    echo "Vault ID: $VAULT_ID"
    echo ""
    echo "View vault status: ./btcnft status $VAULT_ID"
fi
