#!/bin/bash
# Trigger variance settlement on the volatility pool
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "VOL_POOL"

echo "=== Volatility Pool Settlement ==="
echo "Network: $(get_network_name)"
echo ""

IS_DUE=$(cast_call "$VOL_POOL" "isSettlementDue()(bool)")

if [[ "$IS_DUE" != "true" ]]; then
    echo "Error: Settlement is not yet due" >&2
    exit 1
fi

echo "Settlement is due. Triggering..."

confirm_non_local_action "trigger settlement"

TX_HASH=$(cast_send "$VOL_POOL" "settle()")

print_success "Settlement complete" "$TX_HASH"
