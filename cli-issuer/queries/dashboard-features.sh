#!/bin/bash
# Show dashboard feature details for a wallet
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "DASHBOARD_NFT"

WALLET="${1:?Usage: dashboard-features.sh <wallet_address> <feature_type>}"
FEATURE_TYPE="${2:?Usage: dashboard-features.sh <wallet_address> <feature_type>}"

FEATURE_BYTES=$(resolve_feature_type "$FEATURE_TYPE")

echo "=== Dashboard Feature ==="
echo "Wallet:  $WALLET"
echo "Feature: $FEATURE_TYPE"
echo ""

HAS=$(cast_call "$DASHBOARD_NFT" "hasFeature(address,bytes32)(bool)" "$WALLET" "$FEATURE_BYTES")
echo "Has Feature: $HAS"

PRICE=$(cast_call "$DASHBOARD_NFT" "mintPrice(bytes32)(uint256)" "$FEATURE_BYTES")
echo "Mint Price: $(format_btc "$PRICE") BTC"

ACTIVE=$(cast_call "$DASHBOARD_NFT" "featureActive(bytes32)(bool)" "$FEATURE_BYTES")
echo "Feature Active: $ACTIVE"
