#!/bin/bash
# Show Sablier stream configuration for a vault
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "SABLIER_WRAPPER"

VAULT_ID="${1:?Usage: stream-status.sh <vault_id>}"

echo "=== Stream Status for Vault #$VAULT_ID ==="
echo ""

CAN_CREATE=$(cast_call "$SABLIER_WRAPPER" "canCreateStream(uint256)(bool,uint256)" "$VAULT_ID")
echo "Can Create Stream: $CAN_CREATE"
echo ""

echo "Vault Config:"
CONFIG=$(cast_call "$SABLIER_WRAPPER" "getVaultConfig(uint256)" "$VAULT_ID")
echo "$CONFIG"
echo ""

echo "Vault Streams:"
STREAMS=$(cast_call "$SABLIER_WRAPPER" "getVaultStreams(uint256)" "$VAULT_ID")
echo "$STREAMS"
