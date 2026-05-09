#!/bin/bash
set -e

cd "$(dirname "$0")"

# Ensure reports dir exists
mkdir -p reports

# Use existing price series (320 points)
if [ ! -f reports/price_series.csv ]; then
    echo "ERROR: reports/price_series.csv not found. Generate it first."
    exit 1
fi

echo "========================================="
echo "SIMULATION 1: Full Swarm, Seed 42"
echo "========================================="
SIMULATION_SEED=42 forge test --match-test 'test_swarm\b' -vvv --gas-limit 999999999999
python3 scripts/generate_report.py || true
mkdir -p sim_results/sim_1_seed_42
cp reports/* sim_results/sim_1_seed_42/

echo "========================================="
echo "SIMULATION 2: Full Swarm, Seed 123"
echo "========================================="
SIMULATION_SEED=123 forge test --match-test 'test_swarm\b' -vvv --gas-limit 999999999999
python3 scripts/generate_report.py || true
mkdir -p sim_results/sim_2_seed_123
cp reports/* sim_results/sim_2_seed_123/

echo "========================================="
echo "SIMULATION 3: Full Swarm, Seed 777"
echo "========================================="
SIMULATION_SEED=777 forge test --match-test 'test_swarm\b' -vvv --gas-limit 999999999999
python3 scripts/generate_report.py || true
mkdir -p sim_results/sim_3_seed_777
cp reports/* sim_results/sim_3_seed_777/

echo "========================================="
echo "ALL 3 SIMULATIONS COMPLETE"
echo "========================================="
ls -la sim_results/sim_*/
