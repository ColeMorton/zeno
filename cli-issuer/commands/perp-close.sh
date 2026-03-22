#!/bin/bash
# Close a perpetual position
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "PERP_VAULT"

if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: perp-close <position_id>"
    echo ""
    echo "Arguments:"
    echo "  position_id  ID of the position to close"
    exit 1
fi

POSITION_ID="${REMAINING_ARGS[0]}"

echo "=== Closing Perpetual Position #$POSITION_ID ==="
echo "Network: $(get_network_name)"
echo ""

PAYOUT=$(cast_call "$PERP_VAULT" "previewClose(uint256)(uint256)" "$POSITION_ID")
echo "Estimated Payout: $(format_btc "$PAYOUT") vBTC ($PAYOUT satoshis)"

confirm_non_local_action "close position"

echo "Closing position..."
TX_HASH=$(cast_send "$PERP_VAULT" "closePosition(uint256)" "$POSITION_ID")

print_success "Position closed" "$TX_HASH"
echo "Payout: $(format_btc "$PAYOUT") vBTC"
