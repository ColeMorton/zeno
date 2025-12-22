#!/bin/bash
# Network configuration for BTCNFT CLI
# Supported: local (Anvil), sepolia, holesky
# Mainnet is explicitly NOT supported

# Default network
readonly DEFAULT_NETWORK="local"

# Current network (set by parse_network_args or defaults)
CURRENT_NETWORK="${DEFAULT_NETWORK}"

# Get RPC URL for network
_get_rpc_url() {
    case "$1" in
        local)   echo "http://localhost:8545" ;;
        sepolia) echo "https://rpc.sepolia.org" ;;
        holesky) echo "https://rpc.holesky.ethpandaops.io" ;;
        *)       echo "" ;;
    esac
}

# Get chain ID for network
_get_chain_id() {
    case "$1" in
        local)   echo "31337" ;;
        sepolia) echo "11155111" ;;
        holesky) echo "17000" ;;
        *)       echo "" ;;
    esac
}

# Get display name for network
_get_network_display_name() {
    case "$1" in
        local)   echo "Local (Anvil)" ;;
        sepolia) echo "Sepolia Testnet" ;;
        holesky) echo "Holesky Testnet" ;;
        *)       echo "Unknown" ;;
    esac
}

# Validate network name, reject mainnet
validate_network() {
    local network="$1"

    # Reject mainnet attempts
    if [[ "$network" == "mainnet" || "$network" == "ethereum" || "$network" == "1" ]]; then
        echo "Error: Mainnet is not supported by this CLI" >&2
        exit 1
    fi

    # Check if network exists in our configuration
    local rpc_url
    rpc_url=$(_get_rpc_url "$network")
    if [[ -z "$rpc_url" ]]; then
        echo "Error: Unknown network '$network'" >&2
        echo "Supported networks: local, sepolia, holesky" >&2
        exit 1
    fi

    return 0
}

# Get RPC URL for network (public API)
get_rpc_url() {
    local network="${1:-$CURRENT_NETWORK}"
    validate_network "$network"
    _get_rpc_url "$network"
}

# Get chain ID for network (public API)
get_chain_id() {
    local network="${1:-$CURRENT_NETWORK}"
    validate_network "$network"
    _get_chain_id "$network"
}

# Get display name for network (public API)
get_network_name() {
    local network="${1:-$CURRENT_NETWORK}"
    validate_network "$network"
    _get_network_display_name "$network"
}

# Check if network is local (Anvil)
is_local_network() {
    local network="${1:-$CURRENT_NETWORK}"
    [[ "$network" == "local" ]]
}

# Check if network is a testnet
is_testnet() {
    local network="${1:-$CURRENT_NETWORK}"
    [[ "$network" == "sepolia" || "$network" == "holesky" ]]
}

# Get environment file path for network
get_env_file() {
    local network="${1:-$CURRENT_NETWORK}"
    local cli_dir="${2:-$(dirname "${BASH_SOURCE[0]}")/..}"

    if [[ "$network" == "local" ]]; then
        echo "$cli_dir/.env"
    else
        echo "$cli_dir/.env.$network"
    fi
}

# Parse --network flag from arguments
# Returns remaining arguments after removing network flag
# Sets CURRENT_NETWORK global variable
parse_network_args() {
    local args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --network)
                if [[ -z "$2" ]]; then
                    echo "Error: --network requires a value" >&2
                    exit 1
                fi
                CURRENT_NETWORK="$2"
                validate_network "$CURRENT_NETWORK"
                shift 2
                ;;
            --network=*)
                CURRENT_NETWORK="${1#*=}"
                validate_network "$CURRENT_NETWORK"
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # Return remaining arguments
    echo "${args[@]}"
}

# Prompt for confirmation on testnets
confirm_testnet_action() {
    local action="$1"

    if is_testnet; then
        echo "WARNING: You are about to $action on $(get_network_name)" >&2
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted." >&2
            exit 1
        fi
    fi
}
