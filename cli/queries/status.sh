#!/bin/bash
# Display comprehensive vault status
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft status <vault_token_id>"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Vault #$TOKEN_ID Status ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Get owner
OWNER=$(cast_call "$VAULT" "ownerOf(uint256)(address)" "$TOKEN_ID")
echo "Owner: $OWNER"
echo ""

# Get vault info
COLLATERAL=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
MINT_TS=$(cast_call "$VAULT" "mintTimestamp(uint256)(uint256)" "$TOKEN_ID")
LAST_WITHDRAWAL=$(cast_call "$VAULT" "lastWithdrawal(uint256)(uint256)" "$TOKEN_ID")
LAST_ACTIVITY=$(cast_call "$VAULT" "lastActivity(uint256)(uint256)" "$TOKEN_ID")
BTC_TOKEN_AMOUNT=$(cast_call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID")
ORIGINAL_AMOUNT=$(cast_call "$VAULT" "originalMintedAmount(uint256)(uint256)" "$TOKEN_ID")

echo "=== Collateral ==="
echo "Current:  $(format_btc "$COLLATERAL") BTC ($COLLATERAL satoshis)"
echo "Original: $(format_btc "$ORIGINAL_AMOUNT") BTC"
echo ""

echo "=== Withdrawal Rate ==="
echo "$(get_withdrawal_rate)"
echo ""

echo "=== Timestamps ==="
echo "Minted:          $(format_timestamp "$MINT_TS")"
echo "Last Withdrawal: $(format_timestamp "$LAST_WITHDRAWAL")"
echo "Last Activity:   $(format_timestamp "$LAST_ACTIVITY")"
echo ""

# Vesting status
IS_VESTED=$(cast_call "$VAULT" "isVested(uint256)(bool)" "$TOKEN_ID")
echo "=== Vesting ==="
if [[ "$IS_VESTED" == "true" ]]; then
    echo "Status: VESTED"
else
    CURRENT_TS=$(date +%s)
    ELAPSED=$((CURRENT_TS - MINT_TS))
    REMAINING=$((VESTING_SECONDS - ELAPSED))
    ELAPSED_DAYS=$((ELAPSED / SECONDS_PER_DAY))
    REMAINING_DAYS=$((REMAINING / SECONDS_PER_DAY))

    echo "Status: NOT VESTED"
    echo "Progress: $ELAPSED_DAYS / $VESTING_DAYS days"
    echo "Remaining: $REMAINING_DAYS days"
fi
echo ""

# Withdrawal status
if [[ "$IS_VESTED" == "true" ]]; then
    WITHDRAWABLE=$(cast_call "$VAULT" "getWithdrawableAmount(uint256)(uint256)" "$TOKEN_ID")
    echo "=== Withdrawal ==="
    if [[ "$WITHDRAWABLE" != "0" ]]; then
        echo "Withdrawable: $(format_btc "$WITHDRAWABLE") BTC"
    else
        if [[ "$LAST_WITHDRAWAL" != "0" ]]; then
            CURRENT_TS=$(date +%s)
            COOLDOWN_END=$((LAST_WITHDRAWAL + WITHDRAWAL_PERIOD_SECONDS))
            if [[ $CURRENT_TS -lt $COOLDOWN_END ]]; then
                REMAINING=$((COOLDOWN_END - CURRENT_TS))
                REMAINING_DAYS=$((REMAINING / SECONDS_PER_DAY))
                echo "Cooldown: $REMAINING_DAYS days remaining"
            fi
        else
            echo "Withdrawable: 0 BTC (no collateral)"
        fi
    fi
    echo ""
fi

# vBTC status
echo "=== vBTC Token ==="
if [[ "$BTC_TOKEN_AMOUNT" != "0" ]]; then
    echo "Status: SEPARATED"
    echo "Amount: $(format_btc "$BTC_TOKEN_AMOUNT") vBTC"
else
    echo "Status: NOT SEPARATED"
fi
echo ""

# Dormancy status
if [[ "$IS_VESTED" == "true" && "$BTC_TOKEN_AMOUNT" != "0" ]]; then
    DORMANCY_INFO=$(cast_call "$VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
    echo "=== Dormancy ==="
    echo "$DORMANCY_INFO"
    echo ""
fi

# Delegation status
TOTAL_DELEGATED=$(cast_call "$VAULT" "totalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")
if [[ "$TOTAL_DELEGATED" != "0" ]]; then
    DELEGATED_PERCENT=$(echo "scale=2; $TOTAL_DELEGATED / 100" | bc)
    echo "=== Delegation ==="
    echo "Total delegated: ${DELEGATED_PERCENT}%"
    echo "View delegates: ./btcnft delegates $TOKEN_ID"
    echo ""
fi
