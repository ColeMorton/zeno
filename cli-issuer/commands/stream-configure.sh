#!/bin/bash
# Configure vault for streaming
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "SABLIER_WRAPPER"

VAULT_ID="${1:?Usage: stream-configure.sh <vault_id> <recipient_address> <true|false>}"
RECIPIENT="${2:?Usage: stream-configure.sh <vault_id> <recipient_address> <true|false>}"
CANCELABLE="${3:?Usage: stream-configure.sh <vault_id> <recipient_address> <true|false>}"

cast_send "$SABLIER_WRAPPER" "configureVault(uint256,address,bool)" "$VAULT_ID" "$RECIPIENT" "$CANCELABLE"

print_success "Vault $VAULT_ID configured for streaming (recipient: $RECIPIENT, cancelable: $CANCELABLE)"
