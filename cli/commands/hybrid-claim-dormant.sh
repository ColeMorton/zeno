#!/bin/bash
# Claim reserve collateral from a dormant hybrid vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft hybrid-claim-dormant <vault_token_id> <amount_satoshis>"
    echo ""
    echo "Burns vBTC to claim reserve collateral 1:1 from a dormant hybrid vault."
    echo "Vault must be in CLAIMABLE state (poked + grace period expired)."
    echo "Fractional and repeatable; vault itself and active collateral untouched."
    echo ""
    echo "Arguments:"
    echo "  vault_token_id     Hybrid vault to claim from"
    echo "  amount_satoshis    Amount of vBTC to burn (100000000 = 1 BTC)"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
AMOUNT="${REMAINING_ARGS[1]}"

echo "=== Claiming Dormant Collateral from Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Check dormancy eligibility
DORMANCY_INFO=$(cast_call "$HYBRID_VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
echo "Dormancy status: $DORMANCY_INFO"

# Show reserve and caller's vBTC balance
RESERVE=$(cast_call "$HYBRID_VAULT" "strippedReserve(uint256)(uint256)" "$TOKEN_ID")
if [[ $AMOUNT -gt $RESERVE ]]; then
    echo "Error: Insufficient reserve to claim" >&2
    echo "Requested: $(format_btc "$AMOUNT") BTC" >&2
    echo "Available: $(format_btc "$RESERVE") BTC" >&2
    exit 1
fi

CALLER=$(get_caller_address)
HYBRID_BTC_TOKEN=$(cast_call "$HYBRID_VAULT" "btcToken()(address)")
BALANCE=$(cast_call "$HYBRID_BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

echo ""
echo "Reserve to claim:    $(format_btc "$RESERVE") BTC"
echo "Amount requested:    $(format_btc "$AMOUNT") BTC"
echo "Your vBTC balance:   $(format_btc "$BALANCE") vBTC"
echo ""

if [[ $BALANCE -lt $AMOUNT ]]; then
    echo "Error: Insufficient vBTC balance" >&2
    echo "Required: $(format_btc "$AMOUNT") vBTC" >&2
    echo "Have:     $(format_btc "$BALANCE") vBTC" >&2
    exit 1
fi

# Confirm on testnet
confirm_non_local_action "claim dormant hybrid collateral"

# Claim dormant collateral
echo "Claiming dormant collateral..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "claimDormantCollateral(uint256,uint256)" "$TOKEN_ID" "$AMOUNT")

print_success "Dormant hybrid collateral claimed" "$TX_HASH"
