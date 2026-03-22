#!/bin/bash
# Initiate dormancy claim on hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-poke <vault_token_id>"
    echo ""
    echo "Initiates the dormancy recovery process for an inactive hybrid vault."
    echo "Starts a 30-day grace period for the owner to prove activity."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Poking Dormant Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Check dormancy eligibility
DORMANCY_INFO=$(cast_call "$HYBRID_VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
echo "Dormancy status: $DORMANCY_INFO"
echo ""

# Confirm on testnet
confirm_non_local_action "poke dormant hybrid vault"

# Poke dormant
echo "Initiating dormancy process..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "pokeDormant(uint256)" "$TOKEN_ID")

print_success "Dormancy process initiated" "$TX_HASH"
echo ""
echo "A 30-day grace period has started."
echo ""
echo "Next steps:"
echo "  Owner can prove activity: ./btcnft hybrid-prove-activity $TOKEN_ID"
echo "  After grace period:       ./btcnft hybrid-claim-dormant $TOKEN_ID"
