#!/bin/bash
# Check achievement eligibility
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "ACHIEVEMENT_MINTER"

TYPE="${1:?Usage: achieve-check.sh <minter|matured|duration> <vault_id> <collateral_token_alias> [achievement_name]}"
VAULT_ID="${2:?Usage: achieve-check.sh <minter|matured|duration> <vault_id> <collateral_token_alias> [achievement_name]}"
TOKEN_ALIAS="${3:?Usage: achieve-check.sh <minter|matured|duration> <vault_id> <collateral_token_alias> [achievement_name]}"
ACHIEVEMENT_NAME="${4:-}"

CALLER=$(get_caller_address)
TOKEN_ADDR=$(resolve_token_address "$TOKEN_ALIAS")

echo "=== Achievement Eligibility Check ==="
echo "Type:    $TYPE"
echo "Vault:   $VAULT_ID"
echo "Token:   $TOKEN_ADDR"
echo "Caller:  $CALLER"
echo ""

case "$TYPE" in
    minter)
        RESULT=$(cast_call "$ACHIEVEMENT_MINTER" "canClaimMinterAchievement(address,uint256,address)(bool,string)" "$CALLER" "$VAULT_ID" "$TOKEN_ADDR")
        echo "Eligible: $RESULT"
        ;;
    matured)
        RESULT=$(cast_call "$ACHIEVEMENT_MINTER" "canClaimMaturedAchievement(address,uint256,address)(bool,string)" "$CALLER" "$VAULT_ID" "$TOKEN_ADDR")
        echo "Eligible: $RESULT"
        ;;
    duration)
        if [[ -z "$ACHIEVEMENT_NAME" ]]; then
            echo "Error: duration type requires achievement_name argument" >&2
            echo "Usage: achieve-check.sh duration <vault_id> <collateral_token_alias> <achievement_name>" >&2
            exit 1
        fi
        ACHIEVEMENT_BYTES=$(resolve_achievement_type "$ACHIEVEMENT_NAME")
        RESULT=$(cast_call "$ACHIEVEMENT_MINTER" "canClaimDurationAchievement(address,uint256,address,bytes32)(bool,string)" "$CALLER" "$VAULT_ID" "$TOKEN_ADDR" "$ACHIEVEMENT_BYTES")
        echo "Eligible: $RESULT"
        ;;
    *)
        echo "Error: Unknown type '$TYPE'. Use minter, matured, or duration" >&2
        exit 1
        ;;
esac
