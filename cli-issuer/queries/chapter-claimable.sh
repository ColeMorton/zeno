#!/bin/bash
# Show claimable achievements for a chapter
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "CHAPTER_MINTER"

CHAPTER_ID="${1:?Usage: chapter-claimable.sh <chapter_id> <vault_id> <collateral_token_alias>}"
VAULT_ID="${2:?Usage: chapter-claimable.sh <chapter_id> <vault_id> <collateral_token_alias>}"
TOKEN_ALIAS="${3:?Usage: chapter-claimable.sh <chapter_id> <vault_id> <collateral_token_alias>}"

CALLER=$(get_caller_address)
TOKEN_ADDR=$(resolve_token_address "$TOKEN_ALIAS")

echo "=== Claimable Chapter Achievements ==="
echo "Chapter: $CHAPTER_ID"
echo "Vault:   $VAULT_ID"
echo "Token:   $TOKEN_ADDR"
echo "Caller:  $CALLER"
echo ""

CLAIMABLE=$(cast_call "$CHAPTER_MINTER" "getClaimableAchievements(address,bytes32,uint256,address)" "$CALLER" "$CHAPTER_ID" "$VAULT_ID" "$TOKEN_ADDR")
echo "Claimable Achievements:"
echo "$CLAIMABLE"
