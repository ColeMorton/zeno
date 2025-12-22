#!/bin/bash
# Prove vault activity to prevent dormancy claim
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft prove-activity <vault_token_id>"
    echo ""
    echo "Proves vault activity to reset the dormancy timer."
    echo "Must be called by the vault owner."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Proving Activity for Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Confirm on testnet
confirm_testnet_action "prove vault activity"

# Prove activity
echo "Proving activity..."
TX_HASH=$(cast_send "$VAULT" "proveActivity(uint256)" "$TOKEN_ID")

print_success "Activity proven" "$TX_HASH"
echo "Dormancy timer has been reset."
print_vault_summary "$TOKEN_ID"
