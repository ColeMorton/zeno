#!/bin/bash
# Claim reserve collateral from a dormant vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft claim-dormant <vault_token_id> <amount_satoshis>"
    echo ""
    echo "Burns vBTC to claim reserve collateral 1:1 from a dormant vault."
    echo "Vault must be in CLAIMABLE state (poked + grace period expired)."
    echo "Fractional and repeatable; vault itself and active collateral untouched."
    echo ""
    echo "Arguments:"
    echo "  vault_token_id     Vault to claim from"
    echo "  amount_satoshis    Amount of vBTC to burn (100000000 = 1 BTC)"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
AMOUNT="${REMAINING_ARGS[1]}"

echo "=== Claiming Dormant Collateral from Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Check dormancy eligibility and state
DORMANCY_INFO=$(cast_call "$VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
ELIGIBLE=$(echo "$DORMANCY_INFO" | cut -d' ' -f1)
if [[ "$ELIGIBLE" != "true" ]]; then
    echo "Error: Vault is not dormant eligible" >&2
    echo "Status: $DORMANCY_INFO" >&2
    exit 1
fi

# Get reserve balance
RESERVE=$(cast_call "$VAULT" "strippedReserve(uint256)(uint256)" "$TOKEN_ID")
if [[ "$RESERVE" == "0" ]]; then
    echo "Error: No reserve to claim for this vault" >&2
    exit 1
fi

if [[ $AMOUNT -gt $RESERVE ]]; then
    echo "Error: Insufficient reserve to claim" >&2
    echo "Requested: $(format_btc "$AMOUNT") BTC" >&2
    echo "Available: $(format_btc "$RESERVE") BTC" >&2
    exit 1
fi

# Check caller's vBTC balance
CALLER=$(get_caller_address)
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

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
confirm_non_local_action "claim dormant collateral"

# Claim dormant collateral
echo "Claiming dormant collateral..."
TX_HASH=$(cast_send "$VAULT" "claimDormantCollateral(uint256,uint256)" "$TOKEN_ID" "$AMOUNT")

print_success "Dormant collateral claimed" "$TX_HASH"
echo "Collateral received: $(format_btc "$AMOUNT") BTC"
