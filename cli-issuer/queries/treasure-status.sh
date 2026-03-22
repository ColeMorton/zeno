#!/bin/bash
# Show treasure NFT status
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "TREASURE_NFT"

TOKEN_ID="${1:?Usage: treasure-status.sh <token_id>}"

echo "=== Treasure NFT #$TOKEN_ID ==="
echo ""

TIER=$(cast_call "$TREASURE_NFT" "getTier(uint256)" "$TOKEN_ID")
echo "Tier: $TIER"

VAULT_ID=$(cast_call "$TREASURE_NFT" "treasureVault(uint256)(uint256)" "$TOKEN_ID")
echo "Vault ID: $VAULT_ID"

TOTAL=$(cast_call "$TREASURE_NFT" "totalSupply()(uint256)")
echo "Total Supply: $TOTAL"
