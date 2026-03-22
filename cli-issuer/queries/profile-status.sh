#!/bin/bash
# Show profile registration status
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "PROFILE_REGISTRY"

ADDRESS="${1:-$(get_caller_address)}"

echo "=== Profile Status ==="
echo "Address: $ADDRESS"
echo ""

HAS_PROFILE=$(cast_call "$PROFILE_REGISTRY" "hasProfile(address)(bool)" "$ADDRESS")
echo "Registered: $HAS_PROFILE"

if [[ "$HAS_PROFILE" == "true" ]]; then
    REGISTERED_AT=$(cast_call "$PROFILE_REGISTRY" "registeredAt(address)(uint256)" "$ADDRESS")
    echo "Registered At: $(format_timestamp "$REGISTERED_AT")"

    DAYS=$(cast_call "$PROFILE_REGISTRY" "getDaysRegistered(address)(uint256)" "$ADDRESS")
    echo "Days Registered: $DAYS"
fi
