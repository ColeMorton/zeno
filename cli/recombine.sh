#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    echo ""
    echo "Returns btcToken (vBTC) to the vault, restoring full redemption rights."
    echo "Requires holding the full original minted amount."
    exit 1
fi

TOKEN_ID=$1

echo "=== Recombining btcToken with Vault #$TOKEN_ID ==="

BTC_TOKEN_AMT=$(cast call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
if [ "$BTC_TOKEN_AMT" == "0" ]; then
    echo "Error: No btcToken exists for this vault"
    exit 1
fi

ORIGINAL=$(cast call "$VAULT" "originalMintedAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
OWNER=$(cast call "$VAULT" "ownerOf(uint256)(address)" "$TOKEN_ID" --rpc-url "$RPC_URL")
BALANCE=$(cast call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$OWNER" --rpc-url "$RPC_URL")

echo "Original minted: $ORIGINAL"
echo "Current balance: $BALANCE"

if [ "$BALANCE" -lt "$ORIGINAL" ]; then
    echo "Error: Insufficient btcToken balance"
    echo "Required: $ORIGINAL, Available: $BALANCE"
    exit 1
fi

TX=$(cast send "$VAULT" "returnBtcToken(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"
echo ""
echo "btcToken returned and burned!"
echo "Full redemption rights restored."
