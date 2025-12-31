#!/bin/bash
# Claim collateral from dormant vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft claim-dormant <vault_token_id>"
    echo ""
    echo "Claims collateral from a dormant vault after grace period expires."
    echo "Requires holding the full vBTC amount for the vault."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Claiming Dormant Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Check dormancy eligibility
DORMANCY_INFO=$(cast_call "$VAULT" "isDormantEligible(uint256)" "$TOKEN_ID")
echo "Dormancy status: $DORMANCY_INFO"

# Get required vBTC amount
BTC_AMOUNT=$(cast_call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID")
if [[ "$BTC_AMOUNT" == "0" ]]; then
    echo "Error: No vBTC minted for this vault" >&2
    echo "Dormant claim requires vBTC to be separated first" >&2
    exit 1
fi

# Check caller's balance
CALLER=$(get_caller_address)
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

echo ""
echo "Required vBTC: $(format_btc "$BTC_AMOUNT")"
echo "Your balance:  $(format_btc "$BALANCE")"
echo ""

require_balance "$BTC_TOKEN" "$BTC_AMOUNT"

# Confirm on testnet
confirm_non_local_action "claim dormant collateral"

# Claim dormant collateral
echo "Claiming dormant collateral..."
TX_HASH=$(cast_send "$VAULT" "claimDormantCollateral(uint256)" "$TOKEN_ID")

print_success "Dormant collateral claimed" "$TX_HASH"
