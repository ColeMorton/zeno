#!/bin/bash
# Strip primary collateral into reserve, minting vBTC
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft hybrid-strip <vault_token_id> <amount_satoshis>"
    echo ""
    echo "Strips primary collateral into an immunized reserve, minting vBTC 1:1."
    echo "Fractional and repeatable; allowed at any time (including during vesting)."
    echo ""
    echo "Arguments:"
    echo "  vault_token_id     Hybrid vault to strip from"
    echo "  amount_satoshis    Amount of primary collateral to move to reserve"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
AMOUNT="${REMAINING_ARGS[1]}"

echo "=== Stripping Primary Collateral from Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Get primary collateral to validate amount
PRIMARY=$(cast_call "$HYBRID_VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
if [[ $AMOUNT -gt $PRIMARY ]]; then
    echo "Error: Insufficient primary collateral to strip" >&2
    echo "Requested: $(format_btc "$AMOUNT") BTC" >&2
    echo "Available: $(format_btc "$PRIMARY") BTC" >&2
    exit 1
fi

# Get current reserve status
RESERVE=$(cast_call "$HYBRID_VAULT" "strippedReserve(uint256)(uint256)" "$TOKEN_ID")

echo "Current primary collateral: $(format_btc "$PRIMARY") BTC"
echo "Current reserve:            $(format_btc "$RESERVE") BTC"
echo "Amount to strip:            $(format_btc "$AMOUNT") BTC"
echo "vBTC to mint:               $(format_btc "$AMOUNT") vBTC"
echo ""

# Confirm on testnet
confirm_non_local_action "strip primary collateral from hybrid vault"

# Strip collateral
echo "Stripping primary collateral..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "strip(uint256,uint256)" "$TOKEN_ID" "$AMOUNT")

# Get caller's vBTC balance (the hybrid vault's own BtcToken)
CALLER=$(get_caller_address)
HYBRID_BTC_TOKEN=$(cast_call "$HYBRID_VAULT" "btcToken()(address)")
BALANCE=$(cast_call "$HYBRID_BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

print_success "Primary collateral stripped" "$TX_HASH"
echo "Your vBTC balance: $(format_btc "$BALANCE") vBTC"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
