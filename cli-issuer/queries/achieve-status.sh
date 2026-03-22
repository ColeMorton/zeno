#!/bin/bash
# Show achievement status for a wallet
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "ACHIEVEMENT_NFT"

WALLET="${1:?Usage: achieve-status.sh <wallet_address> <achievement_type>}"
ACHIEVEMENT_TYPE="${2:?Usage: achieve-status.sh <wallet_address> <achievement_type>}"

ACHIEVEMENT_BYTES=$(resolve_achievement_type "$ACHIEVEMENT_TYPE")

echo "=== Achievement Status ==="
echo "Wallet: $WALLET"
echo "Type:   $ACHIEVEMENT_TYPE"
echo ""

HAS=$(cast_call "$ACHIEVEMENT_NFT" "hasAchievement(address,bytes32)(bool)" "$WALLET" "$ACHIEVEMENT_BYTES")
echo "Has Achievement: $HAS"

COUNT=$(cast_call "$ACHIEVEMENT_NFT" "achievementCount(address,bytes32)(uint256)" "$WALLET" "$ACHIEVEMENT_BYTES")
echo "Count: $COUNT"
