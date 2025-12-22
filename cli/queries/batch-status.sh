#!/bin/bash
# Query multiple vaults at once
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft batch-status <token_id1> [token_id2] [token_id3] ..."
    echo ""
    echo "Shows summary status for multiple vaults."
    exit 1
fi

echo "=== Batch Vault Status ==="
echo "Network: $(get_network_name)"
echo ""

# Print header
printf "%-8s %-12s %-15s %-10s %-12s %-10s\n" \
    "ID" "Collateral" "Tier" "Vested" "vBTC" "Delegated"
printf "%-8s %-12s %-15s %-10s %-12s %-10s\n" \
    "--------" "------------" "---------------" "----------" "------------" "----------"

for TOKEN_ID in "${REMAINING_ARGS[@]}"; do
    # Check if vault exists
    if ! cast call "$VAULT" "ownerOf(uint256)(address)" "$TOKEN_ID" --rpc-url "$RPC_URL" > /dev/null 2>&1; then
        printf "%-8s %-12s\n" "$TOKEN_ID" "NOT FOUND"
        continue
    fi

    # Get vault info
    COLLATERAL=$(cast_call "$VAULT" "collateralAmount(uint256)(uint256)" "$TOKEN_ID")
    TIER=$(cast_call "$VAULT" "tier(uint256)(uint8)" "$TOKEN_ID")
    IS_VESTED=$(cast_call "$VAULT" "isVested(uint256)(bool)" "$TOKEN_ID")
    BTC_TOKEN_AMOUNT=$(cast_call "$VAULT" "btcTokenAmount(uint256)(uint256)" "$TOKEN_ID")
    TOTAL_DELEGATED=$(cast_call "$VAULT" "totalDelegatedBPS(uint256)(uint256)" "$TOKEN_ID")

    # Format values
    COLLATERAL_BTC=$(format_btc "$COLLATERAL")
    TIER_NAME="${TIER_NAMES[$TIER]:-Unknown}"
    VESTED_STATUS="No"
    [[ "$IS_VESTED" == "true" ]] && VESTED_STATUS="Yes"
    VBTC_STATUS="No"
    [[ "$BTC_TOKEN_AMOUNT" != "0" ]] && VBTC_STATUS="Yes"
    DELEGATED_PCT="0%"
    [[ "$TOTAL_DELEGATED" != "0" ]] && DELEGATED_PCT=$(echo "scale=1; $TOTAL_DELEGATED / 100" | bc)"%"

    printf "%-8s %-12s %-15s %-10s %-12s %-10s\n" \
        "$TOKEN_ID" "${COLLATERAL_BTC} BTC" "$TIER_NAME" "$VESTED_STATUS" "$VBTC_STATUS" "$DELEGATED_PCT"
done

echo ""
echo "For detailed status: ./btcnft status <token_id>"
