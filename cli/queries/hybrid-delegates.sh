#!/bin/bash
# Query hybrid vault delegation information
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-delegates <vault_token_id> [delegate_address]"
    echo ""
    echo "Shows delegation information for a hybrid vault."
    echo "If delegate_address is provided, shows details for that specific delegate."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
DELEGATE="${REMAINING_ARGS[1]:-}"

echo "=== Hybrid Vault #$TOKEN_ID Delegation ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Get owner
OWNER=$(cast_call "$HYBRID_VAULT" "ownerOf(uint256)(address)" "$TOKEN_ID")

# Get delegation totals
WALLET_TOTAL=$(cast_call "$HYBRID_VAULT" "walletTotalDelegatedBPS(address)(uint256)" "$OWNER")
VAULT_TOTAL=$(cast_call "$HYBRID_VAULT" "vaultTotalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")

WALLET_PERCENT=$(echo "scale=2; $WALLET_TOTAL / 100" | bc)
VAULT_PERCENT=$(echo "scale=2; $VAULT_TOTAL / 100" | bc)

echo "Wallet-level delegated: ${WALLET_PERCENT}% ($WALLET_TOTAL bps)"
echo "Vault-specific delegated: ${VAULT_PERCENT}% ($VAULT_TOTAL bps)"
echo ""

if [[ -n "$DELEGATE" ]]; then
    echo "=== Delegate: $DELEGATE ==="

    # Get effective delegation (combines wallet + vault level)
    EFFECTIVE_INFO=$(cast_call "$HYBRID_VAULT" "getEffectiveDelegation(uint256,address)" \
        "$TOKEN_ID" "$DELEGATE")

    EFF_BPS=$(echo "$EFFECTIVE_INFO" | sed -n '1p')
    EFF_TYPE=$(echo "$EFFECTIVE_INFO" | sed -n '2p')
    EFF_EXPIRED=$(echo "$EFFECTIVE_INFO" | sed -n '3p')

    if [[ "$EFF_BPS" == "0" ]]; then
        echo "Status: NOT DELEGATED"
    else
        EFF_DISPLAY=$(echo "scale=2; $EFF_BPS / 100" | bc)
        echo "Effective percentage: ${EFF_DISPLAY}%"
        echo "Delegation type: $EFF_TYPE"
        echo "Expired: $EFF_EXPIRED"

        # Check if can withdraw
        CAN_WITHDRAW_INFO=$(cast_call "$HYBRID_VAULT" "canDelegateWithdraw(uint256,address)(bool,uint256,uint8)" \
            "$TOKEN_ID" "$DELEGATE")
        CAN_WITHDRAW=$(echo "$CAN_WITHDRAW_INFO" | sed -n '1p')
        WITHDRAWABLE=$(echo "$CAN_WITHDRAW_INFO" | sed -n '2p')

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
    echo "Example: ./btcnft hybrid-delegates $TOKEN_ID 0x..."
fi
