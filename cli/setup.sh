#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$SCRIPT_DIR/.env"

cd "$PROJECT_DIR"

echo "=== BTCNFT Protocol CLI Setup ==="

if pgrep -f "anvil" > /dev/null; then
    echo "Anvil is already running. Killing existing instance..."
    pkill -f "anvil" || true
    sleep 2
fi

echo "Starting Anvil..."
anvil --block-time 1 > /dev/null 2>&1 &
ANVIL_PID=$!
sleep 3

if ! kill -0 $ANVIL_PID 2>/dev/null; then
    echo "Error: Failed to start Anvil"
    exit 1
fi
echo "Anvil started (PID: $ANVIL_PID)"

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

echo "Deploying contracts..."
OUTPUT=$(forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --broadcast 2>&1)

WBTC=$(echo "$OUTPUT" | grep "WBTC:" | awk '{print $2}')
TREASURE=$(echo "$OUTPUT" | grep "TREASURE:" | awk '{print $2}')
BTC_TOKEN=$(echo "$OUTPUT" | grep "BTC_TOKEN:" | awk '{print $2}')
VAULT=$(echo "$OUTPUT" | grep "VAULT:" | awk '{print $2}')

if [ -z "$VAULT" ]; then
    echo "Error: Failed to parse deployment addresses"
    echo "$OUTPUT"
    exit 1
fi

cat > "$ENV_FILE" << EOF
RPC_URL=http://localhost:8545
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
WBTC=$WBTC
TREASURE=$TREASURE
BTC_TOKEN=$BTC_TOKEN
VAULT=$VAULT
ANVIL_PID=$ANVIL_PID
EOF

echo ""
echo "=== Deployment Complete ==="
echo "WBTC:      $WBTC"
echo "TREASURE:  $TREASURE"
echo "BTC_TOKEN: $BTC_TOKEN"
echo "VAULT:     $VAULT"
echo ""
echo "Environment saved to: $ENV_FILE"
echo ""
echo "To stop Anvil: kill $ANVIL_PID"
echo ""
echo "Next steps:"
echo "  ./cli/mint.sh <treasure_id> <btc_amount_satoshis> <tier>"
echo "  ./cli/status.sh <vault_token_id>"
