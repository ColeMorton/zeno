# Simulation Result Review Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2026-03-22
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Collateral Matching](./Collateral_Matching.md)
> - [Withdrawal Delegation](./Withdrawal_Delegation.md)

---

## Table of Contents

1. [How to Run](#1-how-to-run)
2. [Result Data Schema](#2-result-data-schema)
3. [Ghost Variables — Protocol Conservation](#3-ghost-variables--protocol-conservation)
4. [Protocol Invariant Checks](#4-protocol-invariant-checks)
5. [Issue Detection Framework](#5-issue-detection-framework)
6. [CSV Analysis Patterns](#6-csv-analysis-patterns)
7. [Known Limitations](#7-known-limitations)
8. [Cross-Reference Map](#8-cross-reference-map)

---

## 1. How to Run

### Forge Commands

All commands run from `contracts/simulation/`:

```bash
cd contracts/simulation

# Smoke test (20 weeks) — quick validation
forge test --match-test test_swarm_smoke -vvv --gas-limit 999999999999

# Default simulation (320 weeks) — live price generation
forge test --match-test test_swarm -vvv --gas-limit 999999999999

# Full simulation (512 weeks)
SIMULATION_WEEKS=512 forge test --match-test test_swarm -vvv --gas-limit 999999999999

# Custom duration (override via SIMULATION_WEEKS env var)
SIMULATION_WEEKS=100 forge test --match-test test_swarm -vvv --gas-limit 999999999999

# Simulation with pre-loaded prices
forge test --match-test test_swarm_preloaded -vvv --gas-limit 999999999999
```

### Slash Commands

- `/simulation:run:smoke` — 20-week smoke test
- `/simulation:run:320` — 320-week default simulation
- `/simulation:run:512` — 512-week full simulation

### Output Location

Tests write 7 files to `contracts/simulation/reports/`:

| File | Format |
|------|--------|
| `simulation.html` | Interactive Chart.js dashboard |
| `market_data.csv` | Per-tick market state |
| `agent_net_worth.csv` | Per-tick net worth per agent |
| `agent_actions.csv` | Every action taken |
| `agent_configs.json` | 100 agent configurations |
| `simulation_summary.json` | Ghost variables and final state |
| `summary.md` | Human-readable overview with leaderboard |

### Archiving Results

After a successful run, archive to a timestamped directory:

```bash
RUN_ID=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=".claude/skills/simulation-results/${RUN_ID}"
mkdir -p "${RESULTS_DIR}"
cp contracts/simulation/reports/* "${RESULTS_DIR}/"
```

Append to the index at `.claude/skills/simulation-results/index.md`:

```
| <RUN_ID> | <date> | <test_name> | <ticks> | 42 | 100 | success |
```

### Price Data

Pre-generated price series at `.claude/skills/simulation/data/price_series.csv` (seed 42, 521 ticks). Copy to `contracts/simulation/reports/price_series.csv` before running `_preloaded` tests. Use `--regenerate-prices` to generate fresh data.

---

## 2. Result Data Schema

### File Schemas

**`market_data.csv`**

| Column | Type | Unit |
|--------|------|------|
| `tick` | int | Week number (0-indexed) |
| `price` | uint256 | WBTC/USDC in 18-decimal wei (divide by 1e18 for USD) |
| `vbtcRatio` | uint256 | vBTC/WBTC ratio in 18-decimal (0 = no AMM liquidity) |
| `tvl` | uint256 | Total value locked in satoshis (divide by 1e8 for BTC) |
| `matchPool` | uint256 | Match pool balance in satoshis |
| `regime` | uint8 | 0 = low-volatility, 1 = high-volatility |

**`agent_actions.csv`**

| Column | Type | Unit |
|--------|------|------|
| `tick` | int | Week number |
| `agentId` | int | Agent index (0-99) |
| `action` | uint8 | Action enum (see mapping below) |
| `actionName` | string | Human-readable action name |
| `amount` | uint256 | Satoshis for vault operations |
| `success` | bool | `true` if action succeeded, `false` if reverted |

**Action enum mapping:**

| Value | Action | Value | Action |
|-------|--------|-------|--------|
| 0 | NONE | 9 | OPEN_PERP_SHORT |
| 1 | MINT_VAULT | 10 | CLOSE_PERP |
| 2 | WITHDRAW | 11 | ADD_PERP_COLLATERAL |
| 3 | EARLY_REDEEM | 12 | DEPOSIT_VOL_LONG |
| 4 | MINT_BTC_TOKEN | 13 | DEPOSIT_VOL_SHORT |
| 5 | RETURN_BTC_TOKEN | 14 | WITHDRAW_VOL_LONG |
| 6 | CLAIM_MATCH | 15 | WITHDRAW_VOL_SHORT |
| 7 | PROVE_ACTIVITY | 16 | POKE_DORMANT |
| 8 | OPEN_PERP_LONG | 17 | CLAIM_DORMANT |

**`agent_net_worth.csv`** — Wide format: `tick, agent_0, agent_1, ..., agent_99`. Values in satoshis.

**`agent_configs.json`** — Array of 100 objects:

```json
{
  "agentId": 0,
  "archetype": "DIAMOND_HANDS",
  "riskTolerance": 15,
  "patience": 90,
  "leveragePreference": 100,
  "volBias": 0,
  "rebalanceFrequency": 8,
  "initialCapitalWbtc": 706999455
}
```

**`simulation_summary.json`**:

```json
{
  "seed": 42,
  "agentCount": 100,
  "tickCount": 20,
  "tickDuration": "1 week",
  "ghostVariables": {
    "totalDeposited": "33589907185",
    "totalWithdrawn": "0",
    "totalForfeited": "1470582346",
    "totalMatchClaimed": "0",
    "totalActions": "249",
    "totalFailedActions": "113",
    "totalSwaps": "0"
  },
  "finalState": {
    "price": "68062674417011864886219",
    "vbtcRatio": "0",
    "tvl": "33433410249",
    "matchPool": "1470582346"
  }
}
```

### Index File

Located at `.claude/skills/simulation-results/index.md`:

| Column | Description |
|--------|-------------|
| ID | Timestamp `YYYYMMDD_HHMMSS` |
| Date | Run date |
| Test | Forge test name |
| Ticks | Number of weekly ticks |
| Seed | Random seed (42 = canonical) |
| Agents | Agent count |
| Status | `success` or `failure` |

---

## 3. Ghost Variables — Protocol Conservation

### Conservation Equation

```
totalDeposited = totalWithdrawn + totalForfeited + currentTVL
```

Tolerance: 5% (integer arithmetic rounding across 100 agents).

### Variable Definitions

| Variable | Meaning |
|----------|---------|
| `ghost_totalDeposited` | Cumulative WBTC (sats) locked via vault minting |
| `ghost_totalWithdrawn` | Cumulative WBTC extracted by vested vault holders |
| `ghost_totalForfeited` | Cumulative WBTC forfeited via early redemption (feeds match pool) |
| `ghost_totalMatchClaimed` | Cumulative match pool claims by vested holders (subset of TVL redistribution, not system outflow) |
| `ghost_totalActions` | Total agent actions attempted (success + failure) |
| `ghost_totalFailedActions` | Actions that reverted |
| `ghost_totalSwaps` | AMM swap count |

### Expected Ranges and Violation Indicators

| Observation | Interpretation |
|-------------|----------------|
| `totalWithdrawn = 0` | Normal for runs < ~162 ticks (vesting requires 1129 days) |
| `totalForfeited > 0` | Expected when Panic Seller agents exist (agents 85-94) |
| `totalMatchClaimed = 0` | Normal when no vaults have both vested and claimed |
| Failure rate > 60% | Investigate — may indicate misconfigured agents or protocol bug |
| Failure rate < 50% | Typical for healthy simulation |
| Conservation violation > 5% | **Protocol accounting bug** — investigate immediately |

### Verification Formula

```
residual = abs(totalDeposited - totalWithdrawn - totalForfeited - currentTVL)
toleranceSats = totalDeposited * 5 / 100
assert(residual <= toleranceSats)
```

Source: `ProtocolInvariants.checkSystemConservation()` in `contracts/simulation/src/assertions/ProtocolInvariants.sol`

---

## 4. Protocol Invariant Checks

Checked every 50 ticks during swarm simulation.

### Protocol-Level Invariants

| # | Invariant | Assertion | Failure Means |
|---|-----------|-----------|---------------|
| 1 | Vault solvency | `wbtc.balanceOf(vault) >= matchPool` | Vault cannot cover match pool obligations |
| 2 | Delegation bounds (wallet) | Per-wallet total delegated BPS <= 10,000 | Delegation overflow — more than 100% delegated |
| 3 | Delegation bounds (vault) | Per-vault delegated BPS <= 10,000 | Vault-level delegation overflow |
| 4 | vBTC conservation | vBTC total supply backed by vault collateral | vBTC minted without corresponding collateral |
| 5 | System conservation | See [Section 3](#3-ghost-variables--protocol-conservation) | Accounting mismatch — collateral leaked or created |

### DeFi-Level Invariants (Full-Stack Only)

| # | Invariant | Assertion | Failure Means |
|---|-----------|-----------|---------------|
| 6 | Perp vault solvency | `vBTC.balanceOf(perpVault) >= sum(previewClose(positionId))` | Perp vault undercollateralized |
| 7 | Vol pool solvency | `vBTC.balanceOf(volPool) >= longPoolAssets + shortPoolAssets` | Volatility pool undercollateralized |
| 8 | System value conservation | Sum of agent net worths ≈ system value (1-5% tolerance) | Value created or destroyed outside protocol rules |

---

## 5. Issue Detection Framework

### Vesting

- Vaults reach ACTIVE state at tick ~162 (1129 days / 7 days per tick = 161.3)
- WITHDRAW actions before tick 162 **must** have `success=false`
- After tick 162, WITHDRAW should start succeeding for vested vaults
- Cross-ref: [Technical Specification §1.3](./Technical_Specification.md)

### Withdrawals

- Rate: 1.0% of remaining collateral per month (`collateral * 1000 / 100000`)
- Cooldown: 30 days = ~4.3 ticks
- Same agent withdrawing more frequently → `success=false`
- Cross-ref: [Technical Specification §1.4](./Technical_Specification.md)

### Early Redemption

- Pro-rata return: `collateral * elapsed / 1129 days`
- Forfeited amount: `collateral - proRataReturn`
- Match pool growth in `market_data.csv` must equal cumulative forfeited amounts
- Cross-ref: [Technical Specification §3](./Technical_Specification.md), [Collateral Matching §2](./Collateral_Matching.md)

### Match Pool

- Should be monotonically non-decreasing (forfeitures add, claims subtract)
- Distribution proportional to collateral among vested holders
- No double-claims per vault
- Cross-ref: [Collateral Matching](./Collateral_Matching.md)

### Dormancy

- Grace period: 30 days (~4.3 ticks)
- Only separated vaults are eligible (vBTC must be minted first)
- POKE_DORMANT before separation → `success=false`
- CLAIM_DORMANT before grace expiry → `success=false`
- Cross-ref: [Technical Specification §5](./Technical_Specification.md)

### Delegation

- BPS sum per wallet/vault must be <= 10,000
- Time-limited delegations (vault-specific) must stop working after expiry
- Delegate withdrawals respect the granted BPS percentage
- Cross-ref: [Withdrawal Delegation](./Withdrawal_Delegation.md)

---

## 6. CSV Analysis Patterns

### market_data.csv

| Pattern | Meaning |
|---------|---------|
| TVL drop at tick N | Correlate with EARLY_REDEEM or WITHDRAW in `agent_actions.csv` at same tick |
| `matchPool` decreases | Match pool claim occurred — verify claimant is vested |
| `matchPool` unexpected growth | Cross-check forfeiture amounts from early redemptions |
| `vbtcRatio = 0` throughout | No AMM liquidity seeded (normal for basic simulations) |
| `regime` switches | ~10% of ticks should switch (9.82% probability per tick) |
| Price in wei | Divide by 1e18 for USD value |

### agent_actions.csv

| Pattern | Meaning |
|---------|---------|
| High failure rate on one action across all agents | Protocol constraint working correctly (e.g., WITHDRAW before vesting) |
| High failure rate for a single agent | Agent config issue or edge case |
| SWAP actions all failing | No AMM liquidity — expected when `vbtcRatio = 0` |
| MINT_VAULT at tick 0 for all agents | Normal — agents initialize by minting vaults |
| EARLY_REDEEM clusters after price drops | Panic Seller archetype behavior (agents 85-94) |
| No WITHDRAW actions in runs < 162 ticks | Expected — no vaults have vested |

### agent_net_worth.csv

| Pattern | Meaning |
|---------|---------|
| Flat net worth across many ticks | Agent holding vault without active DeFi positions (Diamond Hands) |
| Sudden drop | Correlate with EARLY_REDEEM (pro-rata loss) or perp losses |
| All agents identical net worth at tick 0 | **Bug** — each agent has different `initialCapitalWbtc` |
| Net worth change without agent action | Price movement affecting perp/vol positions (expected) |

### simulation_summary.json

| Check | Formula |
|-------|---------|
| Conservation | `totalDeposited - totalWithdrawn - totalForfeited ≈ tvl` (within 5%) |
| Failure rate | `totalFailedActions / totalActions` — healthy range: 30-50% |

### agent_configs.json

| Check | Expected |
|-------|----------|
| Archetype distribution | 30 DIAMOND_HANDS (0-29), 20 YIELD_FARMER (30-49), 15 MOMENTUM_TRADER (50-64), 10 VOLATILITY_PLAYER (65-74), 10 ARBITRAGEUR (75-84), 10 PANIC_SELLER (85-94), 5 PREDATOR (95-99) |
| `initialCapitalWbtc` | Varies by archetype; all values in satoshis |

---

## 7. Known Limitations

| Limitation | Impact |
|------------|--------|
| Smoke tests (20 ticks) too short for vesting | `totalWithdrawn = 0` and `totalMatchClaimed = 0` are expected |
| `vbtcRatio = 0` without AMM liquidity | SWAP actions will all fail; vBTC-denominated positions cannot be valued via AMM |
| Deterministic seed (42) | Same seed produces identical outcomes; run with different seeds to test robustness |
| Price model is GBM with regime switching | Extreme price paths are possible but rare for canonical seed |
| Net worth uses mock oracle prices | Perp/vol position valuations are simulated, not real market prices |
| 5% conservation tolerance | Allows for integer arithmetic rounding across 100 agents |
| 1-week tick granularity | Intra-week dynamics (flash loans, MEV) not captured |

---

## 8. Cross-Reference Map

| Simulation Metric | Protocol Spec Reference |
|-------------------|------------------------|
| Vesting timing (~162 ticks) | [Technical Specification §1.3](./Technical_Specification.md) |
| Withdrawal rate (1.0%/month) | [Technical Specification §1.4](./Technical_Specification.md) |
| Early redemption pro-rata | [Technical Specification §3](./Technical_Specification.md) |
| Match pool mechanics | [Collateral Matching §2](./Collateral_Matching.md) |
| Dormancy grace period (30 days) | [Technical Specification §5](./Technical_Specification.md) |
| Delegation BPS limits | [Withdrawal Delegation §1](./Withdrawal_Delegation.md) |
| Hybrid vault mechanics | [Hybrid Vault Specification](./Hybrid_Vault_Specification.md) |

For simulation infrastructure questions (adding agents, changing price model, modifying invariants), use the `/simulation` skill.
