#!/bin/bash
# Grant vault-specific withdrawal delegation with expiration
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 4 ]]; then
    echo "Usage: ./btcnft vault-delegate-grant <vault_token_id> <delegate_address> <percentage_bps> <duration_seconds>"
    echo ""
    echo "Grants time-limited vault-specific withdrawal delegation."
    echo ""
    echo "Arguments:"
    echo "  vault_token_id    ID of the vault"
    echo "  delegate_address  Ethereum address of the delegate"
    echo "  percentage_bps    Percentage in basis points (100 = 1%, 5000 = 50%)"
    echo "  duration_seconds  Duration in seconds (2592000 = 30 days)"
    echo ""
    echo "Examples:"
    echo "  ./btcnft vault-delegate-grant 1 0x742d...bEb1 5000 2592000"
    echo "  (Grant 50% for 30 days)"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
DELEGATE="${REMAINING_ARGS[1]}"
PERCENTAGE_BPS="${REMAINING_ARGS[2]}"
DURATION="${REMAINING_ARGS[3]}"

# Validate percentage
if [[ $PERCENTAGE_BPS -lt 1 || $PERCENTAGE_BPS -gt $MAX_DELEGATION_BPS ]]; then
    echo "Error: Percentage must be between 1 and $MAX_DELEGATION_BPS basis points" >&2
    exit 1
fi

PERCENTAGE_DISPLAY=$(echo "scale=2; $PERCENTAGE_BPS / 100" | bc)
DURATION_DAYS=$((DURATION / SECONDS_PER_DAY))

echo "=== Granting Vault-Specific Delegation ==="
echo "Network:    $(get_network_name)"
echo "Vault:      #$TOKEN_ID"
echo "Delegate:   $DELEGATE"
echo "Percentage: ${PERCENTAGE_DISPLAY}% ($PERCENTAGE_BPS bps)"
echo "Duration:   $DURATION_DAYS days ($DURATION seconds)"
echo ""

# Determine which contract to use (check both HYBRID_VAULT and VAULT)
CONTRACT=""
if [[ -n "$HYBRID_VAULT" ]]; then
    CONTRACT="$HYBRID_VAULT"
elif [[ -n "$VAULT" ]]; then
    CONTRACT="$VAULT"
else
    echo "Error: No vault contract configured" >&2
    exit 1
fi

# Check current vault delegation total
CURRENT_TOTAL=$(cast_call "$CONTRACT" "vaultTotalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")
NEW_TOTAL=$((CURRENT_TOTAL + PERCENTAGE_BPS))

if [[ $NEW_TOTAL -gt $MAX_DELEGATION_BPS ]]; then
    CURRENT_DISPLAY=$(echo "scale=2; $CURRENT_TOTAL / 100" | bc)
    echo "Error: Total vault delegation would exceed 100%" >&2
    echo "Current total: ${CURRENT_DISPLAY}%" >&2
    echo "Requested:     ${PERCENTAGE_DISPLAY}%" >&2
    exit 1
fi

# Confirm on testnet
confirm_non_local_action "grant vault-specific delegation"

# Grant delegation
echo "Granting vault delegation..."
TX_HASH=$(cast_send "$CONTRACT" "grantVaultDelegate(uint256,address,uint256,uint256)" \
    "$TOKEN_ID" "$DELEGATE" "$PERCENTAGE_BPS" "$DURATION")

print_success "Vault delegation granted" "$TX_HASH"
echo "Delegate:   $DELEGATE"
echo "Percentage: ${PERCENTAGE_DISPLAY}%"
echo "Duration:   $DURATION_DAYS days"
