#!/bin/bash
# Common helper functions for BTCNFT CLI
set -e

# Get the directory containing this script
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$(dirname "$LIB_DIR")"

# Source dependencies
source "$LIB_DIR/constants.sh"
source "$LIB_DIR/network.sh"

# Environment variables (set after load_env)
RPC_URL=""
PRIVATE_KEY=""
WBTC=""
TREASURE=""
BTC_TOKEN=""
VAULT=""

# Load environment file based on current network
load_env() {
    local env_file
    env_file=$(get_env_file "$CURRENT_NETWORK" "$CLI_DIR")

    if [[ ! -f "$env_file" ]]; then
        echo "Error: Environment file not found: $env_file" >&2
        if is_local_network; then
            echo "Run './btcnft setup' to deploy contracts locally" >&2
        else
            echo "Create $env_file with contract addresses for $(get_network_name)" >&2
        fi
        exit 1
    fi

    source "$env_file"

    # Set RPC_URL based on network if not overridden in env
    if [[ -z "$RPC_URL" ]]; then
        RPC_URL=$(get_rpc_url)
    fi

    # Validate required variables
    local required_vars=("PRIVATE_KEY" "VAULT")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "Error: $var not set in $env_file" >&2
            exit 1
        fi
    done
}

# Validate argument count
# Usage: require_args <min_count> <arg_names...>
require_args() {
    local min_count="$1"
    shift
    local arg_names=("$@")
    local actual_count="${#REMAINING_ARGS[@]}"

    if [[ $actual_count -lt $min_count ]]; then
        echo "Error: Missing required arguments" >&2
        echo "Usage: $COMMAND_NAME ${arg_names[*]}" >&2
        exit 1
    fi
}

# Cast call wrapper with error handling
# Usage: cast_call <contract> <signature> [args...]
cast_call() {
    local contract="$1"
    local signature="$2"
    shift 2

    local result
    if ! result=$(cast call "$contract" "$signature" "$@" --rpc-url "$RPC_URL" 2>&1); then
        echo "Error: Contract call failed" >&2
        echo "$result" >&2
        exit 1
    fi
    echo "$result"
}

# Cast send wrapper with JSON output and tx hash extraction
# Usage: cast_send <contract> <signature> [args...]
# Returns: transaction hash
cast_send() {
    local contract="$1"
    local signature="$2"
    shift 2

    local output
    if ! output=$(cast send "$contract" "$signature" "$@" \
        --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        --json 2>&1); then
        echo "Error: Transaction failed" >&2
        parse_revert_reason "$output"
        exit 1
    fi

    parse_tx_hash "$output"
}

# Extract transaction hash from cast send JSON output
parse_tx_hash() {
    local json="$1"
    echo "$json" | jq -r '.transactionHash // empty'
}

# Parse and display revert reason from failed transaction
parse_revert_reason() {
    local output="$1"

    # Try to extract revert reason
    if echo "$output" | grep -q "revert"; then
        local reason
        reason=$(echo "$output" | grep -oP '(?<=revert: ).*' | head -1)
        if [[ -n "$reason" ]]; then
            echo "Revert reason: $reason" >&2
            return
        fi
    fi

    # Fallback: show raw output
    echo "$output" >&2
}

# Get transaction receipt and extract event logs
# Usage: get_tx_logs <tx_hash>
get_tx_logs() {
    local tx_hash="$1"
    cast receipt "$tx_hash" --rpc-url "$RPC_URL" --json | jq -r '.logs'
}

# Extract token ID from event log topic
# Usage: parse_token_id_from_log <tx_hash> [log_index]
parse_token_id_from_log() {
    local tx_hash="$1"
    local log_index="${2:-0}"

    local topic
    topic=$(cast receipt "$tx_hash" --rpc-url "$RPC_URL" --json | \
        jq -r ".logs[$log_index].topics[1] // empty")

    if [[ -z "$topic" || "$topic" == "null" ]]; then
        echo "Error: Could not parse token ID from transaction logs" >&2
        exit 1
    fi

    # Convert hex to decimal (remove 0x prefix)
    echo "$((16#${topic:2}))"
}

# Format satoshi amount to BTC for display
# Usage: format_btc <satoshis>
format_btc() {
    local satoshis="$1"
    echo "scale=8; $satoshis / $SATOSHI_PER_BTC" | bc
}

# Format timestamp to readable date
# Usage: format_timestamp <unix_timestamp>
format_timestamp() {
    local timestamp="$1"
    if [[ "$timestamp" == "0" ]]; then
        echo "Never"
    else
        date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
            date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
            echo "$timestamp"
    fi
}

# Format duration in days
# Usage: format_days <seconds>
format_days() {
    local seconds="$1"
    echo "$((seconds / SECONDS_PER_DAY)) days"
}

# Get withdrawal rate display
get_withdrawal_rate() {
    echo "$WITHDRAWAL_RATE_MONTHLY/month ($WITHDRAWAL_RATE_ANNUAL/year)"
}

# Check if vault is vested
# Usage: require_vested <token_id>
require_vested() {
    local token_id="$1"

    local is_vested
    is_vested=$(cast_call "$VAULT" "isVested(uint256)(bool)" "$token_id")

    if [[ "$is_vested" != "true" ]]; then
        echo "Error: Vault $token_id is not yet vested" >&2

        # Show remaining time
        local mint_ts
        mint_ts=$(cast_call "$VAULT" "mintTimestamp(uint256)(uint256)" "$token_id")
        local current_ts
        current_ts=$(cast block latest --rpc-url "$RPC_URL" --json | jq -r '.timestamp')
        current_ts=$((16#${current_ts:2}))

        local elapsed=$((current_ts - mint_ts))
        local remaining=$((VESTING_SECONDS - elapsed))

        if [[ $remaining -gt 0 ]]; then
            echo "Vesting completes in $(format_days $remaining)" >&2
        fi
        exit 1
    fi
}

# Check if caller has sufficient balance
# Usage: require_balance <token_address> <required_amount> [holder_address]
require_balance() {
    local token="$1"
    local required="$2"
    local holder="${3:-$(get_caller_address)}"

    local balance
    balance=$(cast_call "$token" "balanceOf(address)(uint256)" "$holder")

    if [[ $balance -lt $required ]]; then
        echo "Error: Insufficient balance" >&2
        echo "Required: $(format_btc "$required") BTC" >&2
        echo "Available: $(format_btc "$balance") BTC" >&2
        exit 1
    fi
}

# Get caller address from private key
get_caller_address() {
    cast wallet address --private-key "$PRIVATE_KEY"
}

# Check if vault exists
require_vault_exists() {
    local token_id="$1"

    local owner
    if ! owner=$(cast call "$VAULT" "ownerOf(uint256)(address)" "$token_id" --rpc-url "$RPC_URL" 2>&1); then
        echo "Error: Vault $token_id does not exist" >&2
        exit 1
    fi
}

# Print success message with transaction hash
print_success() {
    local message="$1"
    local tx_hash="$2"

    echo ""
    echo "=== Success ==="
    echo "$message"
    if [[ -n "$tx_hash" ]]; then
        echo "Transaction: $tx_hash"
    fi
    echo ""
}

# Print vault status summary
print_vault_summary() {
    local token_id="$1"
    echo ""
    echo "View vault status: ./btcnft status $token_id"
}
