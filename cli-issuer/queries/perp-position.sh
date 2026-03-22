#!/bin/bash
# Show perpetual vault position details
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "PERP_VAULT"

POSITION_ID="${1:?Usage: perp-position.sh <position_id>}"

echo "=== Perpetual Position #$POSITION_ID ==="
echo ""

echo "Position Data:"
POSITION=$(cast_call "$PERP_VAULT" "getPosition(uint256)" "$POSITION_ID")
echo "$POSITION"
echo ""

OWNER=$(cast_call "$PERP_VAULT" "getPositionOwner(uint256)(address)" "$POSITION_ID")
echo "Owner: $OWNER"
echo ""

echo "PnL Preview (close):"
PNL=$(cast_call "$PERP_VAULT" "previewClose(uint256)" "$POSITION_ID")
echo "$PNL"
