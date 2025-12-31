#!/bin/bash
# Mint vBTC tokens from a vested vault
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft separate <vault_token_id>"
    echo ""
    echo "Mints vBTC tokens representing the vault's collateral claim."
    echo "After separation, vBTC can be transferred independently from the Vault NFT."
    echo "Requires vault to be fully vested."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Separating vBTC from Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Verify vesting
require_vested "$TOKEN_ID"

# Check if vBTC already minted
EXISTING_BTC_AMOUNT=$(cast_call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID")
if [[ "$EXISTING_BTC_AMOUNT" != "0" ]]; then
    echo "Error: vBTC already minted for this vault" >&2
    echo "Current vBTC amount: $(format_btc "$EXISTING_BTC_AMOUNT") BTC" >&2
    exit 1
fi

# Get collateral to show expected vBTC
COLLATERAL=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
echo "Collateral: $(format_btc "$COLLATERAL") BTC"
echo "vBTC to mint: $(format_btc "$COLLATERAL") vBTC"
echo ""

# Confirm on testnet
confirm_non_local_action "mint vBTC tokens"

# Mint vBTC
echo "Minting vBTC..."
TX_HASH=$(cast_send "$VAULT" "mintBtcToken(uint256)" "$TOKEN_ID")

# Get caller's vBTC balance
CALLER=$(get_caller_address)
BALANCE=$(cast_call "$BTC_TOKEN" "balanceOf(address)(uint256)" "$CALLER")

print_success "vBTC minted" "$TX_HASH"
echo "Your vBTC balance: $(format_btc "$BALANCE") vBTC"
print_vault_summary "$TOKEN_ID"
