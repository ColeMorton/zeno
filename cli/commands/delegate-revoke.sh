#!/bin/bash
# Revoke withdrawal delegation from an address
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 1 ]]; then
    echo "Usage: ./btcnft delegate-revoke <vault_token_id> [delegate_address]"
    echo "       ./btcnft delegate-revoke <vault_token_id> --all"
    echo ""
    echo "Revokes withdrawal rights from a delegate."
    echo ""
    echo "Options:"
    echo "  delegate_address  Revoke specific delegate"
    echo "  --all             Revoke all delegates at once"
    echo ""
    echo "Examples:"
    echo "  ./btcnft delegate-revoke 1 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1"
    echo "  ./btcnft delegate-revoke 1 --all"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
DELEGATE="${REMAINING_ARGS[1]:-}"

echo "=== Revoking Withdrawal Delegation ==="
echo "Network: $(get_network_name)"
echo "Vault:   #$TOKEN_ID"
echo ""

# Verify vault exists
require_vault_exists "$TOKEN_ID"

if [[ "$DELEGATE" == "--all" ]]; then
    # Revoke all delegates
    echo "Revoking ALL delegates..."

    # Confirm on testnet
    confirm_non_local_action "revoke all delegates"

    TX_HASH=$(cast_send "$VAULT" "revokeAllWithdrawalDelegates(uint256)" "$TOKEN_ID")

    print_success "All delegates revoked" "$TX_HASH"
elif [[ -n "$DELEGATE" ]]; then
    # Revoke specific delegate
    echo "Delegate: $DELEGATE"

    # Confirm on testnet
    confirm_non_local_action "revoke delegate"

    echo "Revoking delegation..."
    TX_HASH=$(cast_send "$VAULT" "revokeWithdrawalDelegate(uint256,address)" "$TOKEN_ID" "$DELEGATE")

    print_success "Delegate revoked" "$TX_HASH"
    echo "Revoked: $DELEGATE"
else
    echo "Error: Must specify delegate address or --all" >&2
    exit 1
fi

echo ""
echo "View delegates: ./btcnft delegates $TOKEN_ID"
