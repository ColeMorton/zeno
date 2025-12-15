#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    echo ""
    echo "Claims dormant vault collateral as btcToken holder."
    echo "Requires vault to be in CLAIMABLE state and caller to hold full btcToken amount."
    exit 1
fi

TOKEN_ID=$1

echo "=== Claiming Dormant Collateral from Vault #$TOKEN_ID ==="

DORMANCY=$(cast call "$VAULT" "isDormantEligible(uint256)(bool,uint8)" "$TOKEN_ID" --rpc-url "$RPC_URL")
echo "Dormancy status: $DORMANCY"

ORIGINAL=$(cast call "$VAULT" "originalMintedAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
echo "Required btcToken: $ORIGINAL"

DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
BALANCE=$(cast call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC_URL")
echo "Your btcToken balance: $BALANCE"

if [ "$BALANCE" -lt "$ORIGINAL" ]; then
    echo "Error: Insufficient btcToken balance"
    exit 1
fi

COLLATERAL=$(cast call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
echo "Collateral to receive: $COLLATERAL satoshis"

TX=$(cast send "$VAULT" "claimDormantCollateral(uint256)" "$TOKEN_ID" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$TX" | jq -r '.transactionHash')
echo ""
echo "Transaction: $TX_HASH"
echo ""
echo "Dormant collateral claimed!"
echo "btcToken burned, collateral transferred to you."
echo "Treasure NFT returned to original owner."
