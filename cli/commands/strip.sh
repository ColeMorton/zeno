#!/bin/bash
# Strip active collateral into reserve, minting vBTC
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft strip <vault_token_id> <amount_satoshis>"
    echo ""
    echo "Strips active collateral into an immunized reserve, minting vBTC 1:1."
    echo "Fractional and repeatable; allowed at any time (including during vesting)."
    echo ""
    echo "Arguments:"
    echo "  vault_token_id     Vault to strip from"
    echo "  amount_satoshis    Amount of collateral to move to reserve (100000000 = 1 BTC)"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
AMOUNT="${REMAINING_ARGS[1]}"

echo "=== Stripping Collateral from Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Get active collateral to validate amount
COLLATERAL=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
if [[ $AMOUNT -gt $COLLATERAL ]]; then
    echo "Error: Insufficient active collateral to strip" >&2
    echo "Requested: $(format_btc "$AMOUNT") BTC" >&2
    echo "Available: $(format_btc "$COLLATERAL") BTC" >&2
    exit 1
fi

# Get current reserve status
RESERVE=$(cast_call "$VAULT" "strippedReserve(uint256)(uint256)" "$TOKEN_ID")

echo "Current collateral: $(format_btc "$COLLATERAL") BTC"
echo "Current reserve:    $(format_btc "$RESERVE") BTC"
echo "Amount to strip:    $(format_btc "$AMOUNT") BTC"
echo "vBTC to mint:       $(format_btc "$AMOUNT") vBTC"
echo ""

# Confirm on testnet
confirm_non_local_action "strip collateral from vault"

# Strip collateral
echo "Stripping collateral..."
TX_HASH=$(cast_send "$VAULT" "strip(uint256,uint256)" "$TOKEN_ID" "$AMOUNT")

# Get caller's vBTC balance
CALLER=$(get_caller_address)
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

print_success "Collateral stripped" "$TX_HASH"
echo "Your vBTC balance: $(format_btc "$BALANCE") vBTC"
echo ""
echo "View vault status: ./btcnft status $TOKEN_ID"
