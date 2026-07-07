#!/bin/bash
# Claim primary match pool share for a hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-claim-primary-match <vault_token_id>"
    echo ""
    echo "Settles the vault's accrued share of the primary match pool."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Claiming Primary Match Pool for Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Check pending match share
PENDING=$(cast_call "$HYBRID_VAULT" "pendingMatch(uint256)(uint256)" "$TOKEN_ID")
if [[ "$PENDING" == "0" ]]; then
    echo "No pending primary match share. Nothing to claim."
    exit 0
fi

PRIMARY_BEFORE=$(cast_call "$HYBRID_VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")

echo "Pending match share: $(format_btc "$PENDING") BTC"
echo "Your primary:        $(format_btc "$PRIMARY_BEFORE") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "claim primary match pool"

# Claim match
echo "Claiming primary match pool share..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "claimMatch(uint256)" "$TOKEN_ID")

PRIMARY_AFTER=$(cast_call "$HYBRID_VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
CLAIMED=$((PRIMARY_AFTER - PRIMARY_BEFORE))

print_success "Primary match pool claimed" "$TX_HASH"
echo "Claimed:      $(format_btc "$CLAIMED") BTC"
echo "New primary:  $(format_btc "$PRIMARY_AFTER") BTC"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
