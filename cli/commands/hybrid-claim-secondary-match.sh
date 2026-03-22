#!/bin/bash
# Claim secondary match pool share from hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-claim-secondary-match <vault_token_id>"
    echo ""
    echo "Claims a pro-rata share of the secondary match pool."
    echo "Requires vault to be fully vested."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Claiming Secondary Match Pool for Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists and is vested
require_hybrid_vault_exists "$TOKEN_ID"
require_hybrid_vested "$TOKEN_ID"

# Check match pool
MATCH_POOL=$(cast_call "$HYBRID_VAULT" "secondaryMatchPool()(uint256)")
if [[ "$MATCH_POOL" == "0" ]]; then
    echo "Secondary match pool is empty. Nothing to claim."
    exit 0
fi

SECONDARY_BEFORE=$(cast_call "$HYBRID_VAULT" "secondaryAmount(uint256)(uint256)" "$TOKEN_ID")

echo "Secondary match pool: $(format_btc "$MATCH_POOL") BTC"
echo "Your secondary:       $(format_btc "$SECONDARY_BEFORE") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "claim secondary match pool"

# Claim match
echo "Claiming secondary match pool share..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "claimSecondaryMatch(uint256)" "$TOKEN_ID")

SECONDARY_AFTER=$(cast_call "$HYBRID_VAULT" "secondaryAmount(uint256)(uint256)" "$TOKEN_ID")
CLAIMED=$((SECONDARY_AFTER - SECONDARY_BEFORE))

print_success "Secondary match pool claimed" "$TX_HASH"
echo "Claimed:        $(format_btc "$CLAIMED") BTC"
echo "New secondary:  $(format_btc "$SECONDARY_AFTER") BTC"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
