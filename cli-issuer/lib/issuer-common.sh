#!/bin/bash
# Issuer CLI helper functions - extends protocol CLI common.sh
set -e

# Source shared protocol CLI infrastructure
ISSUER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ISSUER_LIB_DIR/../../cli/lib/common.sh"

# Override CLI_DIR to point to issuer CLI root
CLI_DIR="$(dirname "$ISSUER_LIB_DIR")"

# Resolve achievement type name to bytes32 via on-chain constant getter
# Usage: resolve_achievement_type <"MINTER"|"MATURED"|"FIRST_MONTH"|...>
resolve_achievement_type() {
    local type_name="$1"
    require_contract_set "ACHIEVEMENT_MINTER"

    case "$type_name" in
        MINTER|MATURED|HODLER_SUPREME|FIRST_MONTH|QUARTER_STACK|HALF_YEAR|ANNUAL|DIAMOND_HANDS)
            cast_call "$ACHIEVEMENT_MINTER" "${type_name}()(bytes32)"
            ;;
        *)
            echo "Error: Unknown achievement type '$type_name'" >&2
            echo "Valid types: MINTER, MATURED, HODLER_SUPREME, FIRST_MONTH, QUARTER_STACK, HALF_YEAR, ANNUAL, DIAMOND_HANDS" >&2
            exit 1
            ;;
    esac
}

# Resolve dashboard feature type name to bytes32 via on-chain constant getter
# Usage: resolve_feature_type <"THEME_DARK"|"ANALYTICS_PRO"|...>
resolve_feature_type() {
    local type_name="$1"
    require_contract_set "DASHBOARD_NFT"

    case "$type_name" in
        THEME_DARK|THEME_NEON|FRAME_ANIMATED|AVATAR_CUSTOM|ANALYTICS_PRO|EXPORT_CSV|ALERTS_ADVANCED|PORTFOLIO_MULTI|FOUNDERS_BUNDLE)
            cast_call "$DASHBOARD_NFT" "${type_name}()(bytes32)"
            ;;
        *)
            echo "Error: Unknown feature type '$type_name'" >&2
            echo "Valid types: THEME_DARK, THEME_NEON, FRAME_ANIMATED, AVATAR_CUSTOM, ANALYTICS_PRO, EXPORT_CSV, ALERTS_ADVANCED, PORTFOLIO_MULTI, FOUNDERS_BUNDLE" >&2
            exit 1
            ;;
    esac
}

# Parse side argument (long/short) to uint8 enum value
# Usage: parse_side_arg <"long"|"short">
parse_side_arg() {
    local side="$1"
    case "$side" in
        long|LONG)   echo "0" ;;
        short|SHORT) echo "1" ;;
        *)
            echo "Error: Invalid side '$side'. Use 'long' or 'short'" >&2
            exit 1
            ;;
    esac
}
