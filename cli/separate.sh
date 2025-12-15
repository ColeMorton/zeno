#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    echo ""
    echo "Mints btcToken (vBTC) representing the collateral claim."
    echo "Requires vault to be fully vested."
    exit 1
fi

TOKEN_ID=$1

echo "=== Separating Collateral from Vault #$TOKEN_ID ==="

IS_VESTED=$(cast call "$VAULT" "isVested(uint256)(bool)" "$TOKEN_ID" --rpc-url "$RPC_URL")
if [ "$IS_VESTED" != "true" ]; then
    echo "Error: Vault is not yet vested"
    exit 1
fi

BTC_TOKEN_AMT=$(cast call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
if [ "$BTC_TOKEN_AMT" != "0" ]; then
    echo "Error: btcToken already minted for this vault"
    exit 1
fi

COLLATERAL=$(cast call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
echo "Collateral to separate: $COLLATERAL satoshis"

TX=$(cast send "$VAULT" "mintBtcToken(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"

OWNER=$(cast call "$VAULT" "ownerOf(uint256)(address)" "$TOKEN_ID" --rpc-url "$RPC_URL")
BALANCE=$(cast call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$OWNER" --rpc-url "$RPC_URL")

echo ""
echo "btcToken minted!"
echo "vBTC balance: $BALANCE"
echo ""
echo "Note: Vault can be recombined with: ./cli/recombine.sh $TOKEN_ID"
