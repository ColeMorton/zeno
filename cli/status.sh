#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vault_token_id>"
    exit 1
fi

TOKEN_ID=$1

echo "=== Vault #$TOKEN_ID Status ==="

OWNER=$(cast call "$VAULT" "ownerOf(uint256)(address)" "$TOKEN_ID" --rpc-url "$RPC_URL" 2>/dev/null || echo "NOT_FOUND")

if [ "$OWNER" == "NOT_FOUND" ]; then
    echo "Vault does not exist or has been burned"
    exit 1
fi

echo "Owner: $OWNER"

INFO=$(cast call "$VAULT" "getVaultInfo(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")

COLLATERAL=$(cast call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
MINT_TS=$(cast call "$VAULT" "mintTimestamp(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
TIER=$(cast call "$VAULT" "tier(uint256)(uint8)" "$TOKEN_ID" --rpc-url "$RPC_URL")
LAST_WITHDRAW=$(cast call "$VAULT" "lastWithdrawal(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
LAST_ACTIVITY=$(cast call "$VAULT" "lastActivity(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
BTC_TOKEN_AMT=$(cast call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")
ORIGINAL_MINTED=$(cast call "$VAULT" "originalMintedAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")

IS_VESTED=$(cast call "$VAULT" "isVested(uint256)(bool)" "$TOKEN_ID" --rpc-url "$RPC_URL")
WITHDRAWABLE=$(cast call "$VAULT" "getWithdrawableAmount(uint256)(uint256)" "$TOKEN_ID" --rpc-url "$RPC_URL")

TIER_NAME="Unknown"
case $TIER in
    0) TIER_NAME="Conservative (8.33%)" ;;
    1) TIER_NAME="Balanced (11.40%)" ;;
    2) TIER_NAME="Aggressive (15.90%)" ;;
esac

echo ""
echo "Collateral: $COLLATERAL satoshis ($(echo "scale=8; $COLLATERAL / 100000000" | bc) BTC)"
echo "Tier: $TIER_NAME"
echo "Mint Timestamp: $MINT_TS"
echo "Is Vested: $IS_VESTED"
echo "Withdrawable Now: $WITHDRAWABLE satoshis"
echo ""
echo "Last Withdrawal: $LAST_WITHDRAW"
echo "Last Activity: $LAST_ACTIVITY"
echo ""
echo "BTC Token Amount: $BTC_TOKEN_AMT"
echo "Original Minted Amount: $ORIGINAL_MINTED"

if [ "$BTC_TOKEN_AMT" != "0" ]; then
    DORMANCY=$(cast call "$VAULT" "isDormantEligible(uint256)(bool,uint8)" "$TOKEN_ID" --rpc-url "$RPC_URL")
    echo ""
    echo "Dormancy Status: $DORMANCY"
fi
