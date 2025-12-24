#!/bin/bash
# Fast-forward time on local Anvil (development only)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft time-skip <days>"
    echo ""
    echo "Fast-forwards blockchain time on local Anvil."
    echo "Only works on local network."
    echo ""
    echo "Common values:"
    echo "  30    - One withdrawal period"
    echo "  1129  - Full vesting period"
    exit 1
fi

DAYS="${REMAINING_ARGS[0]}"
SECONDS_TO_SKIP=$((DAYS * SECONDS_PER_DAY))

echo "=== Time Skip ==="
echo "Skipping: $DAYS days ($SECONDS_TO_SKIP seconds)"
echo ""

# Get timestamp before
BEFORE_TS=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')
BEFORE_TS=$((16#${BEFORE_TS:2}))
echo "Before: $(format_timestamp "$BEFORE_TS")"

# Increase time
cast rpc evm_increaseTime "$SECONDS_TO_SKIP" --rpc-url "$RPC_URL" > /dev/null

# Mine a block to apply
cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null

# Get timestamp after
AFTER_TS=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')
AFTER_TS=$((16#${AFTER_TS:2}))
echo "After:  $(format_timestamp "$AFTER_TS")"

ACTUAL_SKIP=$((AFTER_TS - BEFORE_TS))
ACTUAL_DAYS=$((ACTUAL_SKIP / SECONDS_PER_DAY))

echo ""
echo "Skipped $ACTUAL_DAYS days"
