#!/bin/bash
# Prove hybrid vault activity to prevent dormancy claim
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-prove-activity <vault_token_id>"
    echo ""
    echo "Proves vault activity to reset the dormancy timer."
    echo "Must be called by the vault owner."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Proving Activity for Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Confirm on testnet
confirm_non_local_action "prove hybrid vault activity"

# Prove activity
echo "Proving activity..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "proveActivity(uint256)" "$TOKEN_ID")

print_success "Activity proven" "$TX_HASH"
echo "Dormancy timer has been reset."
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
