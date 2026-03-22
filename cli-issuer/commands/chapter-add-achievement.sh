#!/bin/bash
# Add achievement to a chapter (admin)
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "CHAPTER_REGISTRY"

CHAPTER_ID="${1:?Usage: chapter-add-achievement.sh <chapter_id> <name> [prerequisites_comma_separated]}"
NAME="${2:?Usage: chapter-add-achievement.sh <chapter_id> <name> [prerequisites_comma_separated]}"
PREREQUISITES="${3:-}"

if [ -z "$PREREQUISITES" ]; then
  PREREQ_ARRAY="[]"
else
  PREREQ_ARRAY="[${PREREQUISITES}]"
fi

cast_send "$CHAPTER_REGISTRY" "addAchievement(bytes32,string,bytes32[])" "$CHAPTER_ID" "$NAME" "$PREREQ_ARRAY"

print_success "Achievement '$NAME' added to chapter $CHAPTER_ID"
