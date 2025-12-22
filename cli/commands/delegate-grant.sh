#!/bin/bash
# Grant withdrawal delegation to an address
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 3 ]]; then
    echo "Usage: ./btcnft delegate-grant <vault_token_id> <delegate_address> <percentage_bps>"
    echo ""
    echo "Grants withdrawal rights to a delegate address."
    echo ""
    echo "Arguments:"
    echo "  vault_token_id    ID of the vault to delegate"
    echo "  delegate_address  Ethereum address of the delegate"
    echo "  percentage_bps    Percentage in basis points (100 = 1%, 5000 = 50%, 10000 = 100%)"
    echo ""
    echo "Examples:"
    echo "  ./btcnft delegate-grant 1 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1 5000"
    echo "  (Grants 50% withdrawal rights to the address)"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
DELEGATE="${REMAINING_ARGS[1]}"
PERCENTAGE_BPS="${REMAINING_ARGS[2]}"

# Validate percentage
if [[ $PERCENTAGE_BPS -lt 1 || $PERCENTAGE_BPS -gt $MAX_DELEGATION_BPS ]]; then
    echo "Error: Percentage must be between 1 and $MAX_DELEGATION_BPS basis points" >&2
    exit 1
fi

# Calculate display percentage
PERCENTAGE_DISPLAY=$(echo "scale=2; $PERCENTAGE_BPS / 100" | bc)

echo "=== Granting Withdrawal Delegation ==="
echo "Network:    $(get_network_name)"
echo "Vault:      #$TOKEN_ID"
echo "Delegate:   $DELEGATE"
echo "Percentage: ${PERCENTAGE_DISPLAY}% ($PERCENTAGE_BPS bps)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Check current total delegation
CURRENT_TOTAL=$(cast_call "$VAULT" "totalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")
NEW_TOTAL=$((CURRENT_TOTAL + PERCENTAGE_BPS))

if [[ $NEW_TOTAL -gt $MAX_DELEGATION_BPS ]]; then
    CURRENT_DISPLAY=$(echo "scale=2; $CURRENT_TOTAL / 100" | bc)
    echo "Error: Total delegation would exceed 100%" >&2
    echo "Current total: ${CURRENT_DISPLAY}%" >&2
    echo "Requested:     ${PERCENTAGE_DISPLAY}%" >&2
    exit 1
fi

# Confirm on testnet
confirm_testnet_action "grant withdrawal delegation"

# Grant delegation
echo "Granting delegation..."
TX_HASH=$(cast_send "$VAULT" "grantWithdrawalDelegate(uint256,address,uint256)" \
    "$TOKEN_ID" "$DELEGATE" "$PERCENTAGE_BPS")

print_success "Delegation granted" "$TX_HASH"
echo "Delegate:   $DELEGATE"
echo "Percentage: ${PERCENTAGE_DISPLAY}%"
echo ""
echo "View delegates: ./btcnft delegates $TOKEN_ID"
