#!/bin/bash
# Mint a hybrid vault (VaultNFT primary leg + VestingEscrow secondary leg)
set -e

source "$(dirname "$0")/../lib/common.sh"
load_env
require_contract_set "HYBRID_VAULT"
require_contract_set "VESTING_ESCROW"

# Validate arguments
if [[ ${#REMAINING_ARGS[@]} -lt 3 ]]; then
    echo "Usage: ./btcnft hybrid-mint <treasure_token_id> <primary_amount_satoshis> <secondary_amount>"
    echo ""
    echo "Arguments:"
    echo "  treasure_token_id       ID of the Treasure NFT to lock"
    echo "  primary_amount_satoshis Primary collateral (vault token) in satoshis"
    echo "  secondary_amount        Secondary collateral escrowed in the VestingEscrow"
    echo ""
    echo "Withdrawal Rate: Primary $(get_withdrawal_rate), Secondary 100% one-time at vesting"
    echo ""
    echo "Example:"
    echo "  ./btcnft hybrid-mint 0 100000000 50000000"
    echo "  (Mint with Treasure #0, 1 BTC primary, 0.5 secondary)"
    exit 1
fi

TREASURE_ID="${REMAINING_ARGS[0]}"
PRIMARY_AMOUNT="${REMAINING_ARGS[1]}"
SECONDARY_AMOUNT="${REMAINING_ARGS[2]}"

# Resolve leg tokens from the contracts
PRIMARY_TOKEN=$(cast_call "$HYBRID_VAULT" "collateralToken()(address)")
SECONDARY_TOKEN=$(cast_call "$VESTING_ESCROW" "token()(address)")

echo "=== Minting Hybrid Vault ==="
echo "Network:    $(get_network_name)"
echo "Treasure:   #$TREASURE_ID"
echo "Primary:    $(format_btc "$PRIMARY_AMOUNT") BTC ($PRIMARY_AMOUNT satoshis)"
echo "Secondary:  $(format_btc "$SECONDARY_AMOUNT") ($SECONDARY_AMOUNT)"
echo ""

# Confirm on testnet
confirm_non_local_action "mint a hybrid vault"

# Check balances
require_balance "$PRIMARY_TOKEN" "$PRIMARY_AMOUNT"
require_balance "$SECONDARY_TOKEN" "$SECONDARY_AMOUNT"

# Approve primary collateral to the vault
echo "Approving primary collateral..."
cast send "$PRIMARY_TOKEN" "approve(address,uint256)" "$HYBRID_VAULT" "$PRIMARY_AMOUNT" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Approve secondary collateral to the escrow
echo "Approving secondary collateral..."
cast send "$SECONDARY_TOKEN" "approve(address,uint256)" "$VESTING_ESCROW" "$SECONDARY_AMOUNT" \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Approve Treasure NFT
echo "Approving Treasure NFT..."
cast send "$TREASURE" "setApprovalForAll(address,bool)" "$HYBRID_VAULT" true \
    --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" > /dev/null

# Mint the vault (primary leg)
echo "Minting vault (primary leg)..."
TX_HASH=$(cast_send "$HYBRID_VAULT" "mint(address,uint256,address,uint256)" \
    "$TREASURE" "$TREASURE_ID" "$PRIMARY_TOKEN" "$PRIMARY_AMOUNT")

# Extract token ID from logs
TOKEN_ID=$(parse_token_id_from_log "$TX_HASH")

# Bind the escrow as the vault's redeem hook (required before deposit)
echo "Binding VestingEscrow as redeem hook..."
cast_send "$HYBRID_VAULT" "setRedeemHook(uint256,address)" "$TOKEN_ID" "$VESTING_ESCROW" > /dev/null

# Escrow the secondary leg
echo "Depositing secondary leg into escrow..."
cast_send "$VESTING_ESCROW" "deposit(uint256,uint256)" "$TOKEN_ID" "$SECONDARY_AMOUNT" > /dev/null

print_success "Hybrid vault minted successfully" "$TX_HASH"
echo "Vault Token ID: $TOKEN_ID"
echo ""
echo "View vault status: ./btcnft hybrid-status $TOKEN_ID"
