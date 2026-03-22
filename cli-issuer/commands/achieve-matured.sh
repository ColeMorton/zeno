#!/bin/bash
# Claim matured achievement for a vault
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "ACHIEVEMENT_MINTER"

VAULT_ID="${1:?Usage: achieve-matured.sh <vault_id> <collateral_token_alias>}"
TOKEN_ALIAS="${2:?Usage: achieve-matured.sh <vault_id> <collateral_token_alias>}"

TOKEN_ADDRESS=$(resolve_token_address "$TOKEN_ALIAS")

cast_send "$ACHIEVEMENT_MINTER" "claimMaturedAchievement(uint256,address)" "$VAULT_ID" "$TOKEN_ADDRESS"

print_success "Matured achievement claimed for vault $VAULT_ID"
