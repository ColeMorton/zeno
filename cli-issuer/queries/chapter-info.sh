#!/bin/bash
# Show chapter info
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "CHAPTER_REGISTRY"

CHAPTER_ID="${1:?Usage: chapter-info.sh <chapter_id>}"

echo "=== Chapter Info ==="
echo "Chapter ID: $CHAPTER_ID"
echo ""

echo "Chapter Data:"
CHAPTER=$(cast_call "$CHAPTER_REGISTRY" "getChapter(bytes32)" "$CHAPTER_ID")
echo "$CHAPTER"
echo ""

IN_WINDOW=$(cast_call "$CHAPTER_REGISTRY" "isWithinMintWindow(bytes32)(bool)" "$CHAPTER_ID")
echo "Within Mint Window: $IN_WINDOW"
echo ""

echo "Chapter Achievements:"
ACHIEVEMENTS=$(cast_call "$CHAPTER_REGISTRY" "getChapterAchievements(bytes32)" "$CHAPTER_ID")
echo "$ACHIEVEMENTS"
