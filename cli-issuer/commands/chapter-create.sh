#!/bin/bash
# Create a new chapter (admin)
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "CHAPTER_REGISTRY"

CHAPTER_NUMBER="${1:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"
YEAR="${2:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"
QUARTER="${3:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"
START_TIMESTAMP="${4:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"
END_TIMESTAMP="${5:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"
MIN_DAYS="${6:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"
MAX_DAYS="${7:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"
BASE_URI="${8:?Usage: chapter-create.sh <chapter_number> <year> <quarter> <start_timestamp> <end_timestamp> <min_days> <max_days> <base_uri>}"

cast_send "$CHAPTER_REGISTRY" "createChapter(uint8,uint16,uint8,uint48,uint48,uint256,uint256,string)" \
  "$CHAPTER_NUMBER" "$YEAR" "$QUARTER" "$START_TIMESTAMP" "$END_TIMESTAMP" "$MIN_DAYS" "$MAX_DAYS" "$BASE_URI"

print_success "Chapter $CHAPTER_NUMBER created (Q${QUARTER} ${YEAR})"
