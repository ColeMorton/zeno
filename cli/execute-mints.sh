#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

echo "=== Executing Pending Mints ==="

WINDOW_END=$(cast call "$VAULT" "mintingWindowEnd()(uint256)" --rpc-url "$RPC_URL")
CURRENT_TIME=$(date +%s)

if [ "$WINDOW_END" != "0" ] && [ "$CURRENT_TIME" -le "$WINDOW_END" ]; then
    echo "Error: Minting window is still active."
    echo "Window ends at: $WINDOW_END"
    echo "Current time: $CURRENT_TIME"
    exit 1
fi

PENDING_COUNT=$(cast call "$VAULT" "getPendingMintCount()(uint256)" --rpc-url "$RPC_URL")
echo "Pending mints to execute: $PENDING_COUNT"

if [ "$PENDING_COUNT" == "0" ]; then
    echo "No pending mints to execute."
    exit 0
fi

echo ""
echo "Executing all pending mints..."
TX=$(cast send "$VAULT" "executeMints()" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"
echo ""
echo "Successfully executed $PENDING_COUNT pending mints."
echo ""
echo "View individual vault status: ./cli/status.sh <token_id>"
