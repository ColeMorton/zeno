#!/bin/bash
# Purchase from a Dutch auction
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft auction-purchase <auction_id>"
    echo ""
    echo "Arguments:"
    echo "  auction_id  The Dutch auction to purchase from"
    echo ""
    echo "Example:"
    echo "  ./btcnft auction-purchase 0"
    exit 1
fi

AUCTION_ID="${REMAINING_ARGS[0]}"

# Require auction controller
if [[ -z "$AUCTION_CONTROLLER" ]]; then
    echo "Error: AUCTION_CONTROLLER not set in environment" >&2
    echo "Add AUCTION_CONTROLLER=0x... to your .env file" >&2
    exit 1
fi

# Verify auction is Dutch type and active
AUCTION_INFO=$(cast_call "$AUCTION_CONTROLLER" "getAuction(uint256)" "$AUCTION_ID")
AUCTION_TYPE=$(echo "$AUCTION_INFO" | sed -n '1p')
AUCTION_STATE=$(echo "$AUCTION_INFO" | sed -n '2p')
COLLATERAL_TOKEN=$(echo "$AUCTION_INFO" | sed -n '5p')

if [[ "$AUCTION_TYPE" != "0" ]]; then
    echo "Error: Auction #$AUCTION_ID is not a Dutch auction" >&2
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

# Get current price
CURRENT_PRICE=$(cast_call "$AUCTION_CONTROLLER" "getCurrentPrice(uint256)(uint256)" "$AUCTION_ID")

echo "=== Dutch Auction Purchase ==="
echo "Network:     $(get_network_name)"
echo "Auction ID:  $AUCTION_ID"
echo "Price:       $(format_btc "$CURRENT_PRICE") BTC ($CURRENT_PRICE satoshis)"
echo ""

# Confirm on testnet
confirm_testnet_action "purchase from auction at current price"

# Approve collateral token
echo "Approving collateral token..."
cast send "$COLLATERAL_TOKEN" "approve(address,uint256)" "$AUCTION_CONTROLLER" "$CURRENT_PRICE" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Purchase
echo "Purchasing..."
TX_HASH=$(cast_send "$AUCTION_CONTROLLER" "purchaseDutch(uint256)" "$AUCTION_ID")

# Extract vault ID from logs (DutchPurchase event has vaultId as 4th field)
RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json)
VAULT_ID=$(echo "$RECEIPT" | jq -r '.logs[0].topics[1]' 2>/dev/null | xargs printf "%d" 2>/dev/null || echo "")

print_success "Purchase successful" "$TX_HASH"
if [[ -n "$VAULT_ID" && "$VAULT_ID" != "0" ]]; then
    echo "Vault ID: $VAULT_ID"
    echo ""
    echo "View vault status: ./btcnft status $VAULT_ID"
fi
