#!/bin/bash
# Authorize or revoke a minter on the Treasure NFT contract
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "TREASURE_NFT"

if [[ ${#REMAINING_ARGS[@]} -lt 2 ]]; then
    echo "Usage: treasure-authorize <grant|revoke> <minter_address>"
    echo ""
    echo "Arguments:"
    echo "  grant|revoke    Action to perform"
    echo "  minter_address  Address to authorize or revoke"
    exit 1
fi

ACTION="${REMAINING_ARGS[0]}"
MINTER="${REMAINING_ARGS[1]}"

echo "=== Treasure NFT Minter Authorization ==="
echo "Network: $(get_network_name)"
echo "Action:  $ACTION"
echo "Minter:  $MINTER"
echo ""

confirm_non_local_action "$ACTION minter"

case "$ACTION" in
    grant)
        echo "Authorizing minter..."
        TX_HASH=$(cast_send "$TREASURE_NFT" "authorizeMinter(address)" "$MINTER")
        print_success "Minter authorized" "$TX_HASH"
        ;;
    revoke)
        echo "Revoking minter..."
        TX_HASH=$(cast_send "$TREASURE_NFT" "revokeMinter(address)" "$MINTER")
        print_success "Minter revoked" "$TX_HASH"
        ;;
    *)
        echo "Error: Invalid action '$ACTION'. Use 'grant' or 'revoke'" >&2
        exit 1
        ;;
esac
