#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <days>"
    echo ""
    echo "Fast-forwards blockchain time by specified number of days."
    echo "Only works on local anvil testnet."
    echo ""
    echo "Common values:"
    echo "  1093 - Full vesting period"
    echo "  30   - Withdrawal cooldown / Grace period"
    exit 1
fi

DAYS=$1
SECONDS_TO_SKIP=$((DAYS * 86400))

echo "=== Time Skip ==="
echo "Skipping $DAYS days ($SECONDS_TO_SKIP seconds)"

BLOCK_BEFORE=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')
echo "Current timestamp: $BLOCK_BEFORE"

cast rpc evm_increaseTime "$SECONDS_TO_SKIP" --rpc-url "$RPC_URL" > /dev/null
cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null

BLOCK_AFTER=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')
echo "New timestamp: $BLOCK_AFTER"

ACTUAL_SKIP=$((BLOCK_AFTER - BLOCK_BEFORE))
echo ""
echo "Time advanced by $((ACTUAL_SKIP / 86400)) days"
