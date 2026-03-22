#!/bin/bash
# Claim duration achievement for a vault
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "ACHIEVEMENT_MINTER"

VAULT_ID="${1:?Usage: achieve-duration.sh <vault_id> <collateral_token_alias> <achievement_type>}"
TOKEN_ALIAS="${2:?Usage: achieve-duration.sh <vault_id> <collateral_token_alias> <achievement_type>}"
ACHIEVEMENT_TYPE="${3:?Usage: achieve-duration.sh <vault_id> <collateral_token_alias> <achievement_type>}"

TOKEN_ADDRESS=$(resolve_token_address "$TOKEN_ALIAS")
ACHIEVEMENT_BYTES=$(resolve_achievement_type "$ACHIEVEMENT_TYPE")

cast_send "$ACHIEVEMENT_MINTER" "claimDurationAchievement(uint256,address,bytes32)" "$VAULT_ID" "$TOKEN_ADDRESS" "$ACHIEVEMENT_BYTES"

print_success "Duration achievement ($ACHIEVEMENT_TYPE) claimed for vault $VAULT_ID"
