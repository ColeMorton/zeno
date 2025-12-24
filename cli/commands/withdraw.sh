#!/bin/bash
# Withdraw collateral from a vested vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft withdraw <vault_token_id>"
    echo ""
    echo "Withdraws 0.875% of remaining collateral (10.5%/year)."
    echo "Requires vault to be fully vested (1129 days) and 30+ days since last withdrawal."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Withdrawing from Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Verify vesting
require_vested "$TOKEN_ID"

# Check withdrawable amount
WITHDRAWABLE=$(cast_call "$VAULT" "getWithdrawableAmount(uint256)(uint256)" "$TOKEN_ID")

if [[ "$WITHDRAWABLE" == "0" ]]; then
    echo "Error: No withdrawable amount" >&2
    echo "This could mean:" >&2
    echo "  - 30-day cooldown since last withdrawal has not passed" >&2
    echo "  - Collateral is already depleted" >&2
    exit 1
fi

echo "Withdrawable: $(format_btc "$WITHDRAWABLE") BTC ($WITHDRAWABLE satoshis)"

# Confirm on testnet
confirm_testnet_action "withdraw from vault"

# Execute withdrawal
echo ""
echo "Executing withdrawal..."
TX_HASH=$(cast_send "$VAULT" "withdraw(uint256)" "$TOKEN_ID")

# Get new collateral amount
NEW_COLLATERAL=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")

print_success "Withdrawal complete" "$TX_HASH"
echo "Withdrawn:  $(format_btc "$WITHDRAWABLE") BTC"
echo "Remaining:  $(format_btc "$NEW_COLLATERAL") BTC"
print_vault_summary "$TOKEN_ID"
