#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <pending_mint_id> <additional_amount_satoshis>"
    echo ""
    echo "Example: $0 1 50000000"
    echo "  (Add 0.5 BTC to pending mint #1)"
    echo ""
    echo "Note: Can only be called during the minting window."
    exit 1
fi

PENDING_ID=$1
ADDITIONAL=$2

echo "=== Increasing Pending Collateral ==="
echo "Pending Mint ID: $PENDING_ID"
echo "Additional Amount: $ADDITIONAL satoshis"

WINDOW_END=$(cast call "$VAULT" "mintingWindowEnd()(uint256)" --rpc-url "$RPC_URL")
CURRENT_TIME=$(date +%s)

if [ "$WINDOW_END" != "0" ] && [ "$CURRENT_TIME" -gt "$WINDOW_END" ]; then
    echo ""
    echo "Error: Minting window has ended."
    exit 1
fi

echo ""
echo "Approving additional WBTC..."
cast send "$WBTC" "approve(address,uint256)" "$VAULT" "$ADDITIONAL" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

echo "Increasing collateral..."
TX=$(cast send "$VAULT" "increasePendingCollateral(uint256,uint256)" \
    "$PENDING_ID" "$ADDITIONAL" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"

PENDING_INFO=$(cast call "$VAULT" "getPendingMint(uint256)" "$PENDING_ID" --rpc-url "$RPC_URL")
echo ""
echo "Updated pending mint info:"
echo "$PENDING_INFO"
