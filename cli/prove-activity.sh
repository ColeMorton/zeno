#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    echo ""
    echo "Owner proves activity to exit dormancy state."
    echo "Resets activity timestamp and cancels dormancy claim."
    exit 1
fi

TOKEN_ID=$1

echo "=== Proving Activity for Vault #$TOKEN_ID ==="

TX=$(cast send "$VAULT" "proveActivity(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"
echo ""
echo "Activity proven! Vault returned to active state."
