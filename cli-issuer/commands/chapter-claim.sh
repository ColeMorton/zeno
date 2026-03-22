#!/bin/bash
# Claim chapter achievement
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "CHAPTER_MINTER"

CHAPTER_ID="${1:?Usage: chapter-claim.sh <chapter_id> <achievement_id> <vault_id> <collateral_token_alias>}"
ACHIEVEMENT_ID="${2:?Usage: chapter-claim.sh <chapter_id> <achievement_id> <vault_id> <collateral_token_alias>}"
VAULT_ID="${3:?Usage: chapter-claim.sh <chapter_id> <achievement_id> <vault_id> <collateral_token_alias>}"
TOKEN_ALIAS="${4:?Usage: chapter-claim.sh <chapter_id> <achievement_id> <vault_id> <collateral_token_alias>}"

TOKEN_ADDRESS=$(resolve_token_address "$TOKEN_ALIAS")

cast_send "$CHAPTER_MINTER" "claimChapterAchievement(bytes32,bytes32,uint256,address,bytes)" "$CHAPTER_ID" "$ACHIEVEMENT_ID" "$VAULT_ID" "$TOKEN_ADDRESS" "0x"

print_success "Chapter achievement claimed for vault $VAULT_ID"
