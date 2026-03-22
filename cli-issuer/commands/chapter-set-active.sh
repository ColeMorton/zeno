#!/bin/bash
# Toggle chapter active state
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "CHAPTER_REGISTRY"

CHAPTER_ID="${1:?Usage: chapter-set-active.sh <chapter_id> <true|false>}"
ACTIVE="${2:?Usage: chapter-set-active.sh <chapter_id> <true|false>}"

cast_send "$CHAPTER_REGISTRY" "setChapterActive(bytes32,bool)" "$CHAPTER_ID" "$ACTIVE"

print_success "Chapter $CHAPTER_ID active state set to $ACTIVE"
