#!/bin/bash
# Early redemption of hybrid vault with penalty
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"
require_contract_set "VESTING_ESCROW"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft hybrid-early-redeem <vault_token_id>"
    echo ""
    echo "Burns the vault and returns pro-rata collateral based on elapsed time."
    echo "The escrowed secondary leg settles automatically in the same transaction"
    echo "via the vault's redeem hook, with the same forfeiture curve."
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"

echo "=== Early Redemption for Hybrid Vault #$TOKEN_ID ==="
echo "Network: $(get_network_name)"
echo ""

# Verify vault exists
require_hybrid_vault_exists "$TOKEN_ID"

# Get vault info
PRIMARY=$(cast_call "$HYBRID_VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
SECONDARY=$(cast_call "$VESTING_ESCROW" "escrowAmount(uint256)(uint256)" "$TOKEN_ID")
MINT_TS=$(cast_call "$HYBRID_VAULT" "mintTimestamp(uint256)(uint256)" "$TOKEN_ID")

# Check for outstanding stripped reserve (must be zero)
RESERVE=$(cast_call "$HYBRID_VAULT" "strippedReserve(uint256)(uint256)" "$TOKEN_ID")
if [[ "$RESERVE" != "0" ]]; then
    echo "Error: Hybrid vault has outstanding stripped reserve" >&2
    echo "Outstanding reserve: $(format_btc "$RESERVE") BTC" >&2
    echo "You must recombine the full reserve before early redemption" >&2
    exit 1
fi

# Get current timestamp
CURRENT_TS=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')
CURRENT_TS=$((16#${CURRENT_TS:2}))

# Calculate elapsed time
ELAPSED=$((CURRENT_TS - MINT_TS))
ELAPSED_DAYS=$((ELAPSED / SECONDS_PER_DAY))

if [[ $ELAPSED -ge $VESTING_SECONDS ]]; then
    PRIMARY_RETURNED=$PRIMARY
    PRIMARY_FORFEITED=0
    SECONDARY_RETURNED=$SECONDARY
    SECONDARY_FORFEITED=0
else
    PRIMARY_RETURNED=$((PRIMARY * ELAPSED / VESTING_SECONDS))
    PRIMARY_FORFEITED=$((PRIMARY - PRIMARY_RETURNED))
    SECONDARY_RETURNED=$((SECONDARY * ELAPSED / VESTING_SECONDS))
    SECONDARY_FORFEITED=$((SECONDARY - SECONDARY_RETURNED))
fi

echo "Primary collateral:   $(format_btc "$PRIMARY") BTC"
echo "Secondary collateral: $(format_btc "$SECONDARY") BTC"
echo "Time elapsed:         $ELAPSED_DAYS days (of $VESTING_DAYS)"
echo ""
echo "=== Redemption Preview ==="
echo "Primary returned:     $(format_btc "$PRIMARY_RETURNED") BTC"
echo "Primary forfeited:    $(format_btc "$PRIMARY_FORFEITED") BTC"
echo "Secondary returned:   $(format_btc "$SECONDARY_RETURNED") BTC"
echo "Secondary forfeited:  $(format_btc "$SECONDARY_FORFEITED") BTC"
echo ""

if [[ $PRIMARY_FORFEITED -gt 0 || $SECONDARY_FORFEITED -gt 0 ]]; then
    echo "WARNING: This action is irreversible!"
    echo "Forfeited collateral goes to the respective match pools."
    echo ""
fi

# Interactive confirmation
read -p "Proceed with early redemption? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Confirm on testnet
confirm_non_local_action "early redeem hybrid vault"

# Execute early redemption (escrow leg settles automatically via redeem hook)
echo ""
echo "Executing early redemption..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "earlyRedeem(uint256)" "$TOKEN_ID")

print_success "Hybrid vault redeemed (both legs settled in one transaction)" "$TX_HASH"
echo "Primary received:    $(format_btc "$PRIMARY_RETURNED") BTC"
echo "Primary forfeited:   $(format_btc "$PRIMARY_FORFEITED") BTC"
echo "Secondary received:  $(format_btc "$SECONDARY_RETURNED") BTC"
echo "Secondary forfeited: $(format_btc "$SECONDARY_FORFEITED") BTC"
