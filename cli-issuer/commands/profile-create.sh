#!/bin/bash
# Create on-chain profile
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "PROFILE_REGISTRY"

cast_send "$PROFILE_REGISTRY" "createProfile()"

print_success "Profile created for $(get_caller_address)"
