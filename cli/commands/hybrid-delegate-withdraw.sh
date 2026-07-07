#!/bin/bash
# Withdraw primary from hybrid vault as a delegate
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-delegate-withdraw <vault_token_id>"
    echo ""
    echo "Withdraws primary collateral from a hybrid vault as a delegated address."
    echo "Amount is based on your delegation percentage."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
CALLER=$(get_caller_address)

echo "=== Delegated Withdrawal from Hybrid Vault #$TOKEN_ID ==="
echo "Network:  $(get_network_name)"
echo "Delegate: $CALLER"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Check if caller can withdraw as delegate
CAN_WITHDRAW_INFO=$(cast_call "$HYBRID_VAULT" "canDelegateWithdraw(uint256,address)(bool,uint256,uint8)" \
    "$TOKEN_ID" "$CALLER")

CAN_WITHDRAW=$(echo "$CAN_WITHDRAW_INFO" | sed -n '1p')
WITHDRAWABLE=$(echo "$CAN_WITHDRAW_INFO" | sed -n '2p')

if [[ "$CAN_WITHDRAW" != "true" ]]; then
    echo "Error: Cannot withdraw as delegate" >&2
    echo "This could mean:" >&2
    echo "  - You are not a delegate for this vault" >&2
    echo "  - 30-day cooldown since last delegation withdrawal" >&2
    echo "  - Vault is not vested" >&2
    exit 1
fi

echo "Withdrawable: $(format_btc "$WITHDRAWABLE") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "withdraw as delegate from hybrid vault"

# Execute delegated withdrawal
echo "Executing delegated withdrawal..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "withdrawAsDelegate(uint256)" "$TOKEN_ID")

print_success "Delegated withdrawal complete" "$TX_HASH"
echo "Withdrawn: $(format_btc "$WITHDRAWABLE") BTC"
