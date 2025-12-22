#!/bin/bash
# Query vault delegation information
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft delegates <vault_token_id> [delegate_address]"
    echo ""
    echo "Shows delegation information for a vault."
    echo "If delegate_address is provided, shows details for that specific delegate."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
DELEGATE="${REMAINING_ARGS[1]:-}"

echo "=== Vault #$TOKEN_ID Delegation ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Get total delegation
TOTAL_DELEGATED=$(cast_call "$VAULT" "totalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")
TOTAL_PERCENT=$(echo "scale=2; $TOTAL_DELEGATED / 100" | bc)

echo "Total delegated: ${TOTAL_PERCENT}% ($TOTAL_DELEGATED bps)"
echo ""

if [[ -n "$DELEGATE" ]]; then
    # Show specific delegate info
    echo "=== Delegate: $DELEGATE ==="

    # Get delegate permission struct
    DELEGATE_INFO=$(cast_call "$VAULT" "getDelegatePermission(uint256,address)" \
        "$TOKEN_ID" "$DELEGATE")

    # Parse struct fields (percentageBPS, lastWithdrawal, grantedAt, active)
    PERCENTAGE_BPS=$(echo "$DELEGATE_INFO" | sed -n '1p')
    LAST_WITHDRAWAL=$(echo "$DELEGATE_INFO" | sed -n '2p')
    GRANTED_AT=$(echo "$DELEGATE_INFO" | sed -n '3p')
    ACTIVE=$(echo "$DELEGATE_INFO" | sed -n '4p')

    if [[ "$ACTIVE" != "true" ]]; then
        echo "Status: NOT ACTIVE"
    else
        PERCENTAGE_DISPLAY=$(echo "scale=2; $PERCENTAGE_BPS / 100" | bc)
        echo "Status:     ACTIVE"
        echo "Percentage: ${PERCENTAGE_DISPLAY}% ($PERCENTAGE_BPS bps)"
        echo "Granted:    $(format_timestamp "$GRANTED_AT")"
        echo "Last Withdrawal: $(format_timestamp "$LAST_WITHDRAWAL")"

        # Check if can withdraw
        CAN_WITHDRAW_INFO=$(cast_call "$VAULT" "canDelegateWithdraw(uint256,address)(bool,uint256)" \
            "$TOKEN_ID" "$DELEGATE")
        CAN_WITHDRAW=$(echo "$CAN_WITHDRAW_INFO" | head -1)
        WITHDRAWABLE=$(echo "$CAN_WITHDRAW_INFO" | tail -1)

        echo ""
        if [[ "$CAN_WITHDRAW" == "true" ]]; then
            echo "Can withdraw: YES"
            echo "Withdrawable: $(format_btc "$WITHDRAWABLE") BTC"
        else
            echo "Can withdraw: NO (cooldown or vault not vested)"
        fi
    fi
else
    echo "Tip: Specify a delegate address to see detailed permissions"
    echo "Example: ./btcnft delegates $TOKEN_ID 0x..."
fi
