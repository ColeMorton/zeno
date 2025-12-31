#!/bin/bash
# Withdraw from vault as a delegate
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft delegate-withdraw <vault_token_id>"
    echo ""
    echo "Withdraws collateral from a vault as a delegated address."
    echo "Amount is based on your delegation percentage."
    echo "Requires 30+ days since your last delegated withdrawal."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
CALLER=$(get_caller_address)

echo "=== Delegated Withdrawal from Vault #$TOKEN_ID ==="
echo "Network:  $(get_network_name)"
echo "Delegate: $CALLER"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Check if caller can withdraw as delegate
CAN_WITHDRAW_INFO=$(cast_call "$VAULT" "canDelegateWithdraw(uint256,address)(bool,uint256)" \
    "$TOKEN_ID" "$CALLER")

# Parse the tuple response (bool, uint256)
CAN_WITHDRAW=$(echo "$CAN_WITHDRAW_INFO" | head -1)
WITHDRAWABLE=$(echo "$CAN_WITHDRAW_INFO" | tail -1)

if [[ "$CAN_WITHDRAW" != "true" ]]; then
    echo "Error: Cannot withdraw as delegate" >&2

    # Get delegation info
    DELEGATE_INFO=$(cast_call "$VAULT" "getDelegatePermission(uint256,address)" \
        "$TOKEN_ID" "$CALLER")

    echo "This could mean:" >&2
    echo "  - You are not a delegate for this vault" >&2
    echo "  - 30-day cooldown since last delegation withdrawal" >&2
    echo "  - Vault is not vested" >&2
    exit 1
fi

# Get delegation percentage for display
DELEGATE_INFO=$(cast_call "$VAULT" "getDelegatePermission(uint256,address)" \
    "$TOKEN_ID" "$CALLER")
PERCENTAGE_BPS=$(echo "$DELEGATE_INFO" | head -1)
PERCENTAGE_DISPLAY=$(echo "scale=2; $PERCENTAGE_BPS / 100" | bc)

echo "Your delegation: ${PERCENTAGE_DISPLAY}%"
echo "Withdrawable:    $(format_btc "$WITHDRAWABLE") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "withdraw as delegate"

# Execute delegated withdrawal
echo "Executing delegated withdrawal..."
TX_HASH=$(cast_send "$VAULT" "withdrawAsDelegate(uint256)" "$TOKEN_ID")

# Get actual withdrawn amount from logs
# The Withdrawn event includes the amount
print_success "Delegated withdrawal complete" "$TX_HASH"
echo "Withdrawn: $(format_btc "$WITHDRAWABLE") BTC"
