#!/bin/bash
# Create stream from vault
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "SABLIER_WRAPPER"

VAULT_ID="${1:?Usage: stream-create.sh <vault_id>}"

cast_send "$SABLIER_WRAPPER" "createStreamFromVault(uint256)" "$VAULT_ID"

print_success "Stream created for vault $VAULT_ID"
