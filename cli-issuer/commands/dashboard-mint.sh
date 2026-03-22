#!/bin/bash
# Purchase dashboard feature (payable)
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "DASHBOARD_REGISTRY"

FEATURE_TYPE="${1:?Usage: dashboard-mint.sh <feature_type> <value_wei>}"
VALUE_WEI="${2:?Usage: dashboard-mint.sh <feature_type> <value_wei>}"

FEATURE_BYTES=$(resolve_feature_type "$FEATURE_TYPE")

cast send "$DASHBOARD_REGISTRY" "purchaseFeature(bytes32)" "$FEATURE_BYTES" \
  --value "$VALUE_WEI" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY"

print_success "Dashboard feature $FEATURE_TYPE purchased"
