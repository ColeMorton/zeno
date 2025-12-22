#!/bin/bash
# Initiate dormancy claim process
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft poke <vault_token_id>"
    echo ""
    echo "Initiates the dormancy recovery process for an inactive vault."
    echo "Starts a 30-day grace period for the owner to prove activity."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Poking Dormant Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Check dormancy eligibility
DORMANCY_INFO=$(cast_call "$VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
echo "Dormancy status: $DORMANCY_INFO"
echo ""

# Confirm on testnet
confirm_testnet_action "poke dormant vault"

# Poke dormant
echo "Initiating dormancy process..."
TX_HASH=$(cast_send "$VAULT" "pokeDormant(uint256)" "$TOKEN_ID")

print_success "Dormancy process initiated" "$TX_HASH"
echo ""
echo "A 30-day grace period has started."
echo ""
echo "Next steps:"
echo "  Owner can prove activity: ./btcnft prove-activity $TOKEN_ID"
echo "  After grace period:       ./btcnft claim-dormant $TOKEN_ID"
