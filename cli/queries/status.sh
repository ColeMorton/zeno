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

# Get vault info (8-field tuple)
# Returns: treasureContract, treasureId, collateralToken, collateralAmount, strippedReserve, mintTimestamp, lastWithdrawal, lastActivity
VAULT_INFO=$(cast_call "$VAULT" "getVaultInfo(uint256)" "$TOKEN_ID")

# Parse the output
TREASURE_CONTRACT=$(echo "$VAULT_INFO" | awk '{print $1}')
TREASURE_ID=$(echo "$VAULT_INFO" | awk '{print $2}')
COLLATERAL_TOKEN=$(echo "$VAULT_INFO" | awk '{print $3}')
COLLATERAL=$(echo "$VAULT_INFO" | awk '{print $4}')
RESERVE=$(echo "$VAULT_INFO" | awk '{print $5}')
MINT_TS=$(echo "$VAULT_INFO" | awk '{print $6}')
LAST_WITHDRAWAL=$(echo "$VAULT_INFO" | awk '{print $7}')
LAST_ACTIVITY=$(echo "$VAULT_INFO" | awk '{print $8}')

echo "=== Collateral ==="
echo "Active:   $(format_btc "$COLLATERAL") BTC ($COLLATERAL satoshis)"
if [[ "$RESERVE" != "0" ]]; then
    echo "Reserve:  $(format_btc "$RESERVE") BTC (immunized, backing vBTC)"
fi
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
echo "=== Stripped Reserve ==="
if [[ "$RESERVE" != "0" ]]; then
    echo "Status: STRIPPED (vBTC outstanding)"
    echo "Amount: $(format_btc "$RESERVE") vBTC"
else
    echo "Status: NOT STRIPPED"
fi
echo ""

# Dormancy status
if [[ "$RESERVE" != "0" ]]; then
    DORMANCY_INFO=$(cast_call "$VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
    ELIGIBLE=$(echo "$DORMANCY_INFO" | cut -d' ' -f1)
    if [[ "$ELIGIBLE" == "true" ]]; then
        echo "=== Dormancy ==="
        echo "$DORMANCY_INFO"
        echo ""
    fi
fi

# Delegation status
WALLET_DELEGATED=$(cast_call "$VAULT" "walletTotalDelegatedBPS(address)(uint256)" "$OWNER")
VAULT_DELEGATED=$(cast_call "$VAULT" "vaultTotalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")
if [[ "$WALLET_DELEGATED" != "0" || "$VAULT_DELEGATED" != "0" ]]; then
    echo "=== Delegation ==="
    if [[ "$WALLET_DELEGATED" != "0" ]]; then
        WALLET_PERCENT=$(echo "scale=2; $WALLET_DELEGATED / 100" | bc)
        echo "Wallet-level: ${WALLET_PERCENT}%"
    fi
    if [[ "$VAULT_DELEGATED" != "0" ]]; then
        VAULT_PERCENT=$(echo "scale=2; $VAULT_DELEGATED / 100" | bc)
        echo "Vault-specific: ${VAULT_PERCENT}%"
    fi
    echo "View delegates: ./btcnft delegates $TOKEN_ID"
    echo ""
fi
