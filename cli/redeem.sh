#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    echo ""
    echo "WARNING: This will burn the Vault NFT and Treasure NFT!"
    echo "         Forfeited collateral goes to the match pool."
    exit 1
fi

TOKEN_ID=$1

echo "=== Early Redemption for Vault #$TOKEN_ID ==="

COLLATERAL=$(cast call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
MINT_TS=$(cast call "$VAULT" "mintTimestamp(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
CURRENT_TS=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')

ELAPSED=$((CURRENT_TS - MINT_TS))
VESTING_PERIOD=$((1093 * 86400))

if [ $ELAPSED -ge $VESTING_PERIOD ]; then
    RETURNED=$COLLATERAL
    FORFEITED=0
else
    RETURNED=$((COLLATERAL * ELAPSED / VESTING_PERIOD))
    FORFEITED=$((COLLATERAL - RETURNED))
fi

echo "Current collateral: $COLLATERAL satoshis"
echo "Time elapsed: $((ELAPSED / 86400)) days"
echo "Expected return: $RETURNED satoshis"
echo "Expected forfeit: $FORFEITED satoshis"
echo ""

read -p "Proceed with early redemption? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

TX=$(cast send "$VAULT" "earlyRedeem(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"
echo "Vault #$TOKEN_ID has been redeemed and burned"
