#!/bin/bash
# Add collateral to an existing perpetual position
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "PERP_VAULT"
require_contract_set "BTC_TOKEN"

if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: perp-add-collateral <position_id> <amount>"
    echo ""
    echo "Arguments:"
    echo "  position_id  ID of the position"
    echo "  amount       vBTC amount in satoshis to add"
    exit 1
fi

POSITION_ID="${REMAINING_ARGS[0]}"
AMOUNT="${REMAINING_ARGS[1]}"

echo "=== Adding Collateral to Position #$POSITION_ID ==="
echo "Network: $(get_network_name)"
echo "Amount:  $(format_btc "$AMOUNT") vBTC ($AMOUNT satoshis)"
echo ""

confirm_non_local_action "add collateral"

require_balance "$BTC_TOKEN" "$AMOUNT"
approve_erc20 "$BTC_TOKEN" "$PERP_VAULT" "$AMOUNT"

echo "Adding collateral..."
TX_HASH=$(cast_send "$PERP_VAULT" "addCollateral(uint256,uint256)" "$POSITION_ID" "$AMOUNT")

print_success "Collateral added" "$TX_HASH"
