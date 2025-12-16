#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <treasure_token_id> <btc_amount_satoshis> <tier>"
    echo "  tier: 0=Conservative, 1=Balanced, 2=Aggressive"
    echo ""
    echo "Example: $0 0 100000000 0"
    echo "  (Create pending mint with Treasure #0, 1 BTC, Conservative tier)"
    echo ""
    echo "Note: Pending mints can only be created during the minting window."
    echo "      Use execute-mints.sh after the window ends to finalize."
    exit 1
fi

TREASURE_ID=$1
BTC_AMOUNT=$2
TIER=$3

echo "=== Creating Pending Mint ==="
echo "Treasure Token ID: $TREASURE_ID"
echo "BTC Amount: $BTC_AMOUNT satoshis"
echo "Tier: $TIER"

WINDOW_END=$(cast call "$VAULT" "mintingWindowEnd()(uint256)" --rpc-url "$RPC_URL")
CURRENT_TIME=$(date +%s)

if [ "$WINDOW_END" != "0" ] && [ "$CURRENT_TIME" -gt "$WINDOW_END" ]; then
    echo ""
    echo "Error: Minting window has ended."
    exit 1
fi

echo ""
echo "Approving WBTC..."
cast send "$WBTC" "approve(address,uint256)" "$VAULT" "$BTC_AMOUNT" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

echo "Approving Treasure NFT..."
cast send "$TREASURE" "setApprovalForAll(address,bool)" "$VAULT" true \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

echo "Creating pending mint..."
TX=$(cast send "$VAULT" "pendingMint(address,uint256,address,uint256,uint8)" \
    "$TREASURE" "$TREASURE_ID" "$WBTC" "$BTC_AMOUNT" "$TIER" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"

LOGS=$(cast receipt "$TX_HASH" --rpc-url "$RPC_URL" --json | jq -r '.logs[0].topics[1]')
PENDING_ID=$((16#${LOGS:2}))

echo "Pending Mint ID: $PENDING_ID"
echo ""
echo "Increase collateral: ./cli/increase-collateral.sh $PENDING_ID <amount>"
echo "Execute mints: ./cli/execute-mints.sh"
