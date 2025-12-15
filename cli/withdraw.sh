#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    exit 1
fi

TOKEN_ID=$1

echo "=== Withdrawing from Vault #$TOKEN_ID ==="

IS_VESTED=$(cast call "$VAULT" "isVested(uint256)(bool)" "$TOKEN_ID" --rpc-url "$RPC_URL")
if [ "$IS_VESTED" != "true" ]; then
    echo "Error: Vault is not yet vested"
    exit 1
fi

WITHDRAWABLE=$(cast call "$VAULT" "getWithdrawableAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
if [ "$WITHDRAWABLE" == "0" ]; then
    echo "Error: No withdrawable amount (30-day cooldown may apply)"
    exit 1
fi

echo "Withdrawable amount: $WITHDRAWABLE satoshis"

TX=$(cast send "$VAULT" "withdraw(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo "Transaction: $TX_HASH"

NEW_COLLATERAL=$(cast call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
echo ""
echo "Withdrawal complete!"
echo "Remaining collateral: $NEW_COLLATERAL satoshis"
