#!/bin/bash
# Display comprehensive hybrid vault status
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"
require_contract_set "VESTING_ESCROW"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-status <vault_token_id>"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Hybrid Vault #$TOKEN_ID Status ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Get owner
OWNER=$(cast_call "$HYBRID_VAULT" "ownerOf(uint256)(address)" "$TOKEN_ID")
echo "Owner: $OWNER"
echo ""

# Get collateral amounts (primary from the vault, secondary from the escrow)
PRIMARY=$(cast_call "$HYBRID_VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
SECONDARY=$(cast_call "$VESTING_ESCROW" "escrowAmount(uint256)(uint256)" "$TOKEN_ID")
RESERVE=$(cast_call "$HYBRID_VAULT" "strippedReserve(uint256)(uint256)" "$TOKEN_ID")
MINT_TS=$(cast_call "$HYBRID_VAULT" "mintTimestamp(uint256)(uint256)" "$TOKEN_ID")
LAST_PRIMARY_WD=$(cast_call "$HYBRID_VAULT" "lastWithdrawal(uint256)(uint256)" "$TOKEN_ID")

echo "=== Collateral ==="
echo "Primary:   $(format_btc "$PRIMARY") BTC ($PRIMARY satoshis)"
echo "Secondary: $(format_btc "$SECONDARY") BTC ($SECONDARY satoshis)"
if [[ "$RESERVE" != "0" ]]; then
    echo "Stripped reserve: $(format_btc "$RESERVE") BTC"
fi
echo ""

echo "=== Withdrawal Rate ==="
echo "Primary:   $(get_withdrawal_rate)"
echo "Secondary: 100% one-time (after vesting)"
echo ""

echo "=== Timestamps ==="
echo "Minted:               $(format_timestamp "$MINT_TS")"
echo "Last Primary Withdrawal: $(format_timestamp "$LAST_PRIMARY_WD")"
echo ""

# Vesting status
IS_VESTED=$(cast_call "$HYBRID_VAULT" "isVested(uint256)(bool)" "$TOKEN_ID")
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
    WITHDRAWABLE_PRIMARY=$(cast_call "$HYBRID_VAULT" "getWithdrawableAmount(uint256)(uint256)" "$TOKEN_ID")
    echo "=== Withdrawals ==="
    echo "Primary withdrawable: $(format_btc "$WITHDRAWABLE_PRIMARY") BTC"

    if [[ "$SECONDARY" == "0" ]]; then
        echo "Secondary: ALREADY WITHDRAWN"
    else
        WITHDRAWABLE_SECONDARY=$(cast_call "$VESTING_ESCROW" "claimable(uint256)(uint256)" "$TOKEN_ID")
        echo "Secondary withdrawable: $(format_btc "$WITHDRAWABLE_SECONDARY") BTC"
    fi
    echo ""
fi

# Match pools (primary on the vault, secondary on the escrow)
PRIMARY_MATCH=$(cast_call "$HYBRID_VAULT" "matchPool()(uint256)")
SECONDARY_MATCH=$(cast_call "$VESTING_ESCROW" "matchPool()(uint256)")
if [[ "$PRIMARY_MATCH" != "0" || "$SECONDARY_MATCH" != "0" ]]; then
    echo "=== Match Pools ==="
    echo "Primary pool:   $(format_btc "$PRIMARY_MATCH") BTC"
    echo "Secondary pool: $(format_btc "$SECONDARY_MATCH") BTC"
    echo ""
fi

# Dormancy status
if [[ "$IS_VESTED" == "true" ]]; then
    DORMANCY_INFO=$(cast_call "$HYBRID_VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
    echo "=== Dormancy ==="
    echo "$DORMANCY_INFO"
    echo ""
fi

# Delegation status
WALLET_DELEGATED=$(cast_call "$HYBRID_VAULT" "walletTotalDelegatedBPS(address)(uint256)" "$OWNER")
VAULT_DELEGATED=$(cast_call "$HYBRID_VAULT" "vaultTotalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")
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
    echo "View delegates: ./btcnft hybrid-delegates $TOKEN_ID"
    echo ""
fi
