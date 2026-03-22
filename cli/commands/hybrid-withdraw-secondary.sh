#!/bin/bash
# Withdraw secondary collateral from a vested hybrid vault (one-time)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-withdraw-secondary <vault_token_id>"
    echo ""
    echo "Withdraws 100% of secondary collateral (one-time withdrawal)."
    echo "Requires vault to be fully vested."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Withdrawing Secondary from Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists and is vested
require_hybrid_vault_exists "$TOKEN_ID"
require_hybrid_vested "$TOKEN_ID"

# Check if already withdrawn
SECONDARY=$(cast_call "$HYBRID_VAULT" "secondaryAmount(uint256)(uint256)" "$TOKEN_ID")
ALREADY_WITHDRAWN=$(cast_call "$HYBRID_VAULT" "secondaryWithdrawn(uint256)(bool)" "$TOKEN_ID")

if [[ "$ALREADY_WITHDRAWN" == "true" ]]; then
    echo "Error: Secondary collateral already withdrawn" >&2
    exit 1
fi

echo "Secondary amount: $(format_btc "$SECONDARY") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "withdraw secondary from hybrid vault"

# Execute withdrawal
echo "Executing withdrawal..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "withdrawSecondary(uint256)" "$TOKEN_ID")

print_success "Secondary withdrawal complete" "$TX_HASH"
echo "Withdrawn: $(format_btc "$SECONDARY") BTC"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
