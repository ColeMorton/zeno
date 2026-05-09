# Root Cause Analysis: SimCurvePool Ratio Ceiling Failure

**Date:** 2026-05-09
**Task:** S2.1 — Audit SimCurvePool ratio ceiling
**File:** `src/mocks/SimCurvePool.sol`
**Status:** RCA complete, fix strategy proposed

---

## 1. Problem Statement

The vBTC/WBTC ratio in the swarm simulation peaked at **12–46×** (recorded max: 46.48e18 in sim_2_seed_123 at tick 167), far exceeding the intended ceiling of **1.0e18** and floor of **0.5e18**.

## 2. Line-by-Line Audit Findings

### Where ratio is computed
- `spotPrice()` (L148): `reserve0 * PRECISION / reserve1` — correct.
- `_updateOracle()` (L192): same formula, EMA-smoothed — correct.
- `exchange()` pre-transfer (L92) and `get_dy()` (L130): same formula — correct.

### Constant-product formula
The AMM implements `k = x * y` correctly:
- `dy = reserveOut * dxAfterFee / (reserveIn + dxAfterFee)` (L75, L115)
- Fee stays in the pool (`dx - dxAfterFee` burned into reserves)
- This is algebraically equivalent to `(reserveIn + dxAfterFee) * (reserveOut - dy) = reserveIn * reserveOut`

### Ratio ceiling enforcement at SWAP time
**ORIGINAL CODE (HEAD):** `exchange()` had **NO** ratio bounds check. It computed `dy`, checked `min_dy`, transferred tokens, updated reserves, and updated the oracle. The ratio could move arbitrarily.

**CURRENT WORKING TREE:** Ratio checks were added post-hoc to `exchange()`, `get_dy()`, and `add_liquidity()`, but the project is currently **uncompilable** due to a struct-arity mismatch in `SwarmOrchestrator.sol:301` (AgentState constructor expects 11 fields, receives 10).

### Initial liquidity provision
- `add_liquidity()` in the original code initialized the pool **without** checking the initial spot ratio.
- In practice, `_execAddLiquidity()` seeds using `INITIAL_VBTC_RATIO = 0.75e18`, so the first ratio is usually ~0.75.
- However, `_execAddLiquidity` caps `wbtcAmount` to the agent's WBTC balance but **does not scale down `vbtcAmount`**. If the agent is WBTC-poor, the first deposit can be severely imbalanced (e.g., [1 WBTC, 100 vBTC] → ratio 0.01), which would fall below the 0.5 floor.

## 3. Root Cause

**The SimCurvePool contract never enforced ratio bounds.** The [0.5, 1.0] constraint existed only in:
1. Post-hoc test assertions (`SwarmSimulation.sim.t.sol`)
2. TWAP-oracle feeder logic (`SwarmOrchestrator.sol:270`), which merely *skipped* updating the oracle when out of bounds

Because the AMM itself permitted unbounded swaps, a **tiny initial pool** (~0.005 WBTC / ~0.007 vBTC at tick 166 in sim_2) combined with **concurrent WBTC→vBTC swaps** by ~20 agents in a single tick drove the ratio to 46×. Each swap increased the WBTC reserve while decreasing the vBTC reserve; with no guardrails, the ratio compounded upward.

## 4. Evidence

| Metric | sim_1_seed_42 | sim_2_seed_123 | sim_3_seed_777 |
|--------|---------------|----------------|----------------|
| Max ratio | 0.75e18 | **46.48e18** | 27.05e18 |
| Tick of peak | — | 167 | — |
| ADD_LIQUIDITY tick | 166 | 166 | — |
| Swaps at peak tick | 0 | 20+ WBTC→vBTC | — |

Agent actions at tick 167 (sim_2): 20 successful `SWAP_WBTC_TO_VBTC` executions, all of which should have reverted under a proper ratio ceiling.

## 5. Fix Strategy (3 options)

### Option A: Hard bounds in SimCurvePool (RECOMMENDED)
**What:** Enforce `_requireRatioInBounds(newRatio)` inside `exchange()` and `add_liquidity()`, as already drafted in the working tree.
**Pros:**
- Guarantees the AMM never leaves the [0.5, 1.0] band
- `get_dy()` returns 0 for out-of-bounds swaps, so agents naturally avoid them
**Cons:**
- Pool can get "stuck" near 1.0 (no WBTC→vBTC swaps possible) or near 0.5 (no vBTC→WBTC swaps possible)
- Requires fixing the current compilation breakage (AgentState arity mismatch)

### Option B: Virtual liquidity floor (minimum pool size)
**What:** Reject `exchange()` if `reserve0 < MIN_RESERVE || reserve1 < MIN_RESERVE`. Also reject `add_liquidity()` if it would leave the pool below the minimum.
**Pros:**
- Prevents the "tiny pool + large relative swap" attack vector that amplified the spike
- Keeps price impact reasonable
**Cons:**
- Does not enforce the 1.0 ceiling directly; ratio could still drift given enough capital
- Adds a new protocol parameter (MIN_RESERVE) that needs tuning

### Option C: Circuit breaker on ratio deviation
**What:** Allow swaps freely, but if the ratio deviates more than ±X% from the EMA oracle price, pause swaps for N ticks.
**Pros:**
- More permissive during normal volatility
- Mimics real-world circuit breakers
**Cons:**
- Complex to implement correctly (needs stateful pause, grace period, admin unpause)
- Does not guarantee the ratio stays in [0.5, 1.0]; merely slows down extreme moves

## 6. Recommended Path

Implement **Option A** (hard bounds) immediately:
1. Fix the compilation error in `SwarmOrchestrator.sol` (add `lastWithdrawTicks` to the AgentState constructor or make it optional)
2. Ensure `add_liquidity` checks bounds both on first seed and on subsequent deposits
3. Ensure `_execAddLiquidity` scales BOTH tokens proportionally when WBTC is capped (or reduce vBTC to match available WBTC)
4. Re-run simulations across seeds 42, 123, 777 to verify ratio stays within [0.5, 1.0]

Consider **Option B** as a follow-up hardening measure if price impact remains excessive even within the ratio band.

## 7. Math Review

The constant-product math is sound. The critical missing piece was the economic guardrail, not the algebraic formula.

**Reviewer:** default (Hermes agent)
**Next step:** Team review of this memo → agreement on Option A → implementation task spawn.
