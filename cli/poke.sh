#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    echo ""
    echo "Initiates dormancy claim process."
    echo "Starts 30-day grace period for owner to prove activity."
    exit 1
fi

TOKEN_ID=$1

echo "=== Poking Dormant Vault #$TOKEN_ID ==="

DORMANCY=$(cast call "$VAULT" "isDormantEligible(uint256)(bool,uint8)" "$TOKEN_ID" --rpc-url "$RPC_URL")
echo "Dormancy status: $DORMANCY"

TX=$(cast send "$VAULT" "pokeDormant(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"
echo ""
echo "Vault poked! 30-day grace period started."
echo "Owner can prove activity with: ./cli/prove-activity.sh $TOKEN_ID"
echo "After grace period: ./cli/claim-dormant.sh $TOKEN_ID"
