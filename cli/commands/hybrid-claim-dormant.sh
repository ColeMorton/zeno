#!/bin/bash
# Claim collateral from dormant hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-claim-dormant <vault_token_id>"
    echo ""
    echo "Claims both primary and secondary collateral from a dormant hybrid vault."
    echo "Requires grace period to have expired."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Claiming Dormant Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Check dormancy eligibility
DORMANCY_INFO=$(cast_call "$HYBRID_VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
echo "Dormancy status: $DORMANCY_INFO"

# Show collateral amounts
PRIMARY=$(cast_call "$HYBRID_VAULT" "primaryAmount(uint256)(uint256)" "$TOKEN_ID")
SECONDARY=$(cast_call "$HYBRID_VAULT" "secondaryAmount(uint256)(uint256)" "$TOKEN_ID")

echo ""
echo "Primary collateral:   $(format_btc "$PRIMARY") BTC"
echo "Secondary collateral: $(format_btc "$SECONDARY") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "claim dormant hybrid collateral"

# Claim dormant collateral
echo "Claiming dormant collateral..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "claimDormantCollateral(uint256)" "$TOKEN_ID")

print_success "Dormant hybrid collateral claimed" "$TX_HASH"
