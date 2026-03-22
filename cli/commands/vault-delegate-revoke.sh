#!/bin/bash
# Revoke vault-specific withdrawal delegation
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: ./btcnft vault-delegate-revoke <vault_token_id> <delegate_address>"
    echo ""
    echo "Revokes a vault-specific delegation."
    echo ""
    echo "Example:"
    echo "  ./btcnft vault-delegate-revoke 1 0x742d...bEb1"
    exit 1
fi

TOKEN_ID="${REMAINING_ARGS[0]}"
DELEGATE="${REMAINING_ARGS[1]}"

echo "=== Revoking Vault Delegation ==="
echo "Network:  $(get_network_name)"
echo "Vault:    #$TOKEN_ID"
echo "Delegate: $DELEGATE"
echo ""

# Determine which contract to use
CONTRACT=""
if [[ -n "$HYBRID_VAULT" ]]; then
    CONTRACT="$HYBRID_VAULT"
elif [[ -n "$VAULT" ]]; then
    CONTRACT="$VAULT"
else
    echo "Error: No vault contract configured" >&2
    exit 1
fi

# Confirm on testnet
confirm_non_local_action "revoke vault delegation"

# Revoke delegation
echo "Revoking delegation..."
TX_HASH=$(cast_send "$CONTRACT" "revokeVaultDelegate(uint256,address)" "$TOKEN_ID" "$DELEGATE")

print_success "Vault delegation revoked" "$TX_HASH"
echo "Delegate $DELEGATE can no longer withdraw from vault #$TOKEN_ID"
