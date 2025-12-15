#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    echo ""
    echo "Claims pro-rata share from the match pool."
    echo "Requires vault to be fully vested."
    exit 1
fi

TOKEN_ID=$1

echo "=== Claiming Match Pool Share for Vault #$TOKEN_ID ==="

IS_VESTED=$(cast call "$VAULT" "isVested(uint256)(bool)" "$TOKEN_ID" --rpc-url "$RPC_URL")
if [ "$IS_VESTED" != "true" ]; then
    echo "Error: Vault is not yet vested"
    exit 1
fi

MATCH_POOL=$(cast call "$VAULT" "matchPool()(uint256)" --rpc-url "$RPC_URL")
echo "Current match pool: $MATCH_POOL satoshis"

if [ "$MATCH_POOL" == "0" ]; then
    echo "Error: Match pool is empty"
    exit 1
fi

COLLATERAL_BEFORE=$(cast call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")

TX=$(cast send "$VAULT" "claimMatch(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"

COLLATERAL_AFTER=$(cast call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
CLAIMED=$((COLLATERAL_AFTER - COLLATERAL_BEFORE))

echo ""
echo "Match claimed!"
echo "Amount received: $CLAIMED satoshis"
echo "New collateral: $COLLATERAL_AFTER satoshis"
