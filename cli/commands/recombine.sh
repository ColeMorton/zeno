#!/bin/bash
# Return vBTC tokens to vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft recombine <vault_token_id>"
    echo ""
    echo "Returns vBTC tokens to the vault, regaining full collateral control."
    echo "Requires holding the full original vBTC amount."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Recombining vBTC with Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Check if vBTC exists
BTC_AMOUNT=$(cast_call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID")
if [[ "$BTC_AMOUNT" == "0" ]]; then
    echo "Error: No vBTC minted for this vault" >&2
    exit 1
fi

# Check caller's balance
CALLER=$(get_caller_address)
ORIGINAL_AMOUNT=$(cast_call "$VAULT" "originalMintedAmount(uint256)(uint256)" "$TOKEN_ID")
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

echo "Original vBTC amount: $(format_btc "$ORIGINAL_AMOUNT") vBTC"
echo "Your vBTC balance:    $(format_btc "$BALANCE") vBTC"
echo ""

if [[ $BALANCE -lt $ORIGINAL_AMOUNT ]]; then
    echo "Error: Insufficient vBTC balance" >&2
    echo "Required: $(format_btc "$ORIGINAL_AMOUNT") vBTC" >&2
    echo "Have:     $(format_btc "$BALANCE") vBTC" >&2
    exit 1
fi

# Confirm on testnet
confirm_testnet_action "return vBTC to vault"

# Return vBTC
echo "Returning vBTC..."
TX_HASH=$(cast_send "$VAULT" "returnBtcToken(uint256)" "$TOKEN_ID")

print_success "vBTC returned to vault" "$TX_HASH"
print_vault_summary "$TOKEN_ID"
