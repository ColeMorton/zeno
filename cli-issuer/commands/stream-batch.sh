#!/bin/bash
# Batch create streams from multiple vaults
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "SABLIER_WRAPPER"

VAULT_IDS="${1:?Usage: stream-batch.sh <vault_ids_comma_separated>}"

VAULT_ARRAY="[${VAULT_IDS}]"

cast_send "$SABLIER_WRAPPER" "batchCreateStreams(uint256[])" "$VAULT_ARRAY"

print_success "Batch streams created for vaults: $VAULT_IDS"
