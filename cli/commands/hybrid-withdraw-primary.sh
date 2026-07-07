#!/bin/bash
# Withdraw primary collateral from a vested hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-withdraw-primary <vault_token_id>"
    echo ""
    echo "Withdraws 1.0% of remaining primary collateral (12%/year)."
    echo "Requires vault to be fully vested (1129 days) and 30+ days since last withdrawal."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Withdrawing Primary from Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists and is vested
require_hybrid_vault_exists "$TOKEN_ID"
require_hybrid_vested "$TOKEN_ID"

# Check withdrawable amount
WITHDRAWABLE=$(cast_call "$HYBRID_VAULT" "getWithdrawableAmount(uint256)(uint256)" "$TOKEN_ID")

if [[ "$WITHDRAWABLE" == "0" ]]; then
    echo "Error: No withdrawable primary amount" >&2
    echo "30-day cooldown since last withdrawal may not have passed" >&2
    exit 1
fi

echo "Withdrawable: $(format_btc "$WITHDRAWABLE") BTC ($WITHDRAWABLE satoshis)"

# Confirm on testnet
confirm_non_local_action "withdraw primary from hybrid vault"

# Execute withdrawal
echo ""
echo "Executing withdrawal..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "withdraw(uint256)" "$TOKEN_ID")

# Get new primary amount
NEW_PRIMARY=$(cast_call "$HYBRID_VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")

print_success "Primary withdrawal complete" "$TX_HASH"
echo "Withdrawn:  $(format_btc "$WITHDRAWABLE") BTC"
echo "Remaining:  $(format_btc "$NEW_PRIMARY") BTC"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
