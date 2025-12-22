#!/bin/bash
# Early redemption with penalty
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft early-redeem <vault_token_id>"
    echo ""
    echo "Burns the vault and returns pro-rata collateral based on elapsed time."
    echo "Forfeited collateral goes to the match pool."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Early Redemption for Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

# Get vault info
COLLATERAL=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
MINT_TS=$(cast_call "$VAULT" "mintTimestamp(uint256)(uint256)" "$TOKEN_ID")

# Get current timestamp
CURRENT_TS=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')
CURRENT_TS=$((16#${CURRENT_TS:2}))

# Calculate elapsed time and pro-rata return
ELAPSED=$((CURRENT_TS - MINT_TS))
ELAPSED_DAYS=$((ELAPSED / SECONDS_PER_DAY))

if [[ $ELAPSED -ge $VESTING_SECONDS ]]; then
    RETURNED=$COLLATERAL
    FORFEITED=0
else
    RETURNED=$((COLLATERAL * ELAPSED / VESTING_SECONDS))
    FORFEITED=$((COLLATERAL - RETURNED))
fi

echo "Current collateral: $(format_btc "$COLLATERAL") BTC"
echo "Time elapsed:       $ELAPSED_DAYS days (of $VESTING_DAYS)"
echo ""
echo "=== Redemption Preview ==="
echo "You will receive:   $(format_btc "$RETURNED") BTC"
echo "You will forfeit:   $(format_btc "$FORFEITED") BTC"
echo ""

if [[ $FORFEITED -gt 0 ]]; then
    echo "WARNING: This action is irreversible!"
    echo "Forfeited collateral goes to the match pool."
    echo ""
fi

# Interactive confirmation
read -p "Proceed with early redemption? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Confirm on testnet (additional confirmation)
confirm_testnet_action "early redeem vault"

# Execute early redemption
echo ""
echo "Executing early redemption..."
TX_HASH=$(cast_send "$VAULT" "earlyRedeem(uint256)" "$TOKEN_ID")

print_success "Vault redeemed" "$TX_HASH"
echo "Received:  $(format_btc "$RETURNED") BTC"
echo "Forfeited: $(format_btc "$FORFEITED") BTC"
