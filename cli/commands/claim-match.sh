#!/bin/bash
# Settle and claim accrued match pool share
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft claim-match <vault_token_id>"
    echo ""
    echo "Settles the vault's accrued match pool share into active collateral."
    echo "Match pool is funded by early redemption forfeitures."
    echo "No vesting gate; settlement also happens automatically on collateral operations."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Claiming Match Pool for Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Get pending match amount (unsettled share)
PENDING=$(cast_call "$VAULT" "pendingMatch(uint256)(uint256)" "$TOKEN_ID")

if [[ "$PENDING" == "0" ]]; then
    echo "No pending match pool share to claim."
    exit 0
fi

# Get current collateral (for showing change)
COLLATERAL_BEFORE=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")

echo "Pending match share: $(format_btc "$PENDING") BTC"
echo "Current collateral:  $(format_btc "$COLLATERAL_BEFORE") BTC"
echo ""

# Confirm on testnet
confirm_non_local_action "settle match pool share"

# Claim match
echo "Settling match pool share..."
TX_HASH=$(cast_send "$VAULT" "claimMatch(uint256)" "$TOKEN_ID")

# Get new collateral to confirm claimed amount
COLLATERAL_AFTER=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
CLAIMED=$((COLLATERAL_AFTER - COLLATERAL_BEFORE))

print_success "Match pool settled" "$TX_HASH"
echo "Claimed:         $(format_btc "$CLAIMED") BTC"
echo "New collateral:  $(format_btc "$COLLATERAL_AFTER") BTC"
echo ""
echo "View vault status: ./btcnft status $TOKEN_ID"
