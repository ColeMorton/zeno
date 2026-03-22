#!/bin/bash
# Mint Hodler Supreme vault
set -e

source "$(dirname "$0")/../lib/issuer-common.sh"
load_env
require_contract_set "ACHIEVEMENT_MINTER"

TOKEN_ALIAS="${1:?Usage: achieve-hodler-supreme.sh <collateral_token_alias> <collateral_amount>}"
COLLATERAL_AMOUNT="${2:?Usage: achieve-hodler-supreme.sh <collateral_token_alias> <collateral_amount>}"

TOKEN_ADDRESS=$(resolve_token_address "$TOKEN_ALIAS")

require_balance "$TOKEN_ADDRESS" "$COLLATERAL_AMOUNT"
approve_erc20 "$TOKEN_ADDRESS" "$ACHIEVEMENT_MINTER" "$COLLATERAL_AMOUNT"

cast_send "$ACHIEVEMENT_MINTER" "mintHodlerSupremeVault(address,uint256)" "$TOKEN_ADDRESS" "$COLLATERAL_AMOUNT"

print_success "Hodler Supreme vault minted with $(format_btc "$COLLATERAL_AMOUNT") collateral"
