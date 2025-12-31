#!/bin/bash
# Claim share from match pool
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft claim-match <vault_token_id>"
    echo ""
    echo "Claims a pro-rata share of the match pool based on vault collateral."
    echo "Match pool is funded by early redemption forfeitures."
    echo "Requires vault to be fully vested."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Claiming Match Pool for Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Verify vesting
require_vested "$TOKEN_ID"

# Check match pool balance
MATCH_POOL=$(cast_call "$VAULT" "matchPool()(uint256)")
if [[ "$MATCH_POOL" == "0" ]]; then
    echo "Match pool is empty. Nothing to claim."
    exit 0
fi

# Get current collateral (for showing change)
COLLATERAL_BEFORE=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")

echo "Match pool balance: $(format_btc "$MATCH_POOL") BTC"
echo "Your collateral:    $(format_btc "$COLLATERAL_BEFORE") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "claim from match pool"

# Claim match
echo "Claiming match pool share..."
TX_HASH=$(cast_send "$VAULT" "claimMatch(uint256)" "$TOKEN_ID")

# Get new collateral to calculate claimed amount
COLLATERAL_AFTER=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
CLAIMED=$((COLLATERAL_AFTER - COLLATERAL_BEFORE))

print_success "Match pool claimed" "$TX_HASH"
echo "Claimed:         $(format_btc "$CLAIMED") BTC"
echo "New collateral:  $(format_btc "$COLLATERAL_AFTER") BTC"
print_vault_summary "$TOKEN_ID"
