#!/bin/bash
# Claim secondary match pool share for a hybrid vault's escrow position
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"
require_contract_set "VESTING_ESCROW"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-claim-secondary-match <vault_token_id>"
    echo ""
    echo "Settles the escrow position's accrued share of the secondary match pool."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Claiming Secondary Match Pool for Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Check pending match share
PENDING=$(cast_call "$VESTING_ESCROW" "pendingMatch(uint256)(uint256)" "$TOKEN_ID")
if [[ "$PENDING" == "0" ]]; then
    echo "No pending secondary match share. Nothing to claim."
    exit 0
fi

SECONDARY_BEFORE=$(cast_call "$VESTING_ESCROW" "escrowAmount(uint256)(uint256)" "$TOKEN_ID")

echo "Pending match share: $(format_btc "$PENDING") BTC"
echo "Your secondary:      $(format_btc "$SECONDARY_BEFORE") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "claim secondary match pool"

# Claim match
echo "Claiming secondary match pool share..."
TX_HASH=$(cast_send "$VESTING_ESCROW" "claimMatch(uint256)" "$TOKEN_ID")

SECONDARY_AFTER=$(cast_call "$VESTING_ESCROW" "escrowAmount(uint256)(uint256)" "$TOKEN_ID")
CLAIMED=$((SECONDARY_AFTER - SECONDARY_BEFORE))

print_success "Secondary match pool claimed" "$TX_HASH"
echo "Claimed:        $(format_btc "$CLAIMED") BTC"
echo "New secondary:  $(format_btc "$SECONDARY_AFTER") BTC"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
