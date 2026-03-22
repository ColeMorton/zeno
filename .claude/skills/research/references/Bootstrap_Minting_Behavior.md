# Bootstrap Minting Behavior: Temporal Distribution During the 1129-Day Bootstrap Phase

> **Version:** 1.0
> **Status:** Research
> **Last Updated:** 2026-03-22
> **Related Documents:**
> - [Minting Economics](./Minting_Economics.md)
> - [vBTC Pricing Model](./vBTC_Pricing_Model.md)
> - [Long Duration Capital Strategies](./Long_Duration_Capital_Strategies.md)
> - [Competitive Positioning](./Competitive_Positioning.md)
> - [Vesting Period](./Vesting_Period.md)
> - [Time Preference Primer](./Time_Preference_Primer.md)

---

## Executive Summary

This document models the temporal distribution of vault minting activity across the 1129-day bootstrap phase. The hypothesis proposes three distinct phases:

1. **Initial Surge (Days 0-30):** Front-loaded demand from the pre-launch community, decaying as the accessible audience exhausts.
2. **Punctuated Trough (Days 31-1098):** Low baseline activity punctuated by irregular sub-peaks from external catalysts (BTC price movements, xBTC DeFi integrations, match pool milestones, issuer launches).
3. **Terminal Rally (Days 1099-1128):** Renewed minting driven primarily by narrative/attention around the approaching vBTC launch, with a secondary structural component from Day 0 minters publicly approaching their unlock.

Hypothesis strength varies by phase: Phase I is strongly supported by universal DeFi launch patterns. Phase II is reasonable but the 36-month duration means external catalysts dominate over intrinsic incentive gradients. Phase III is the weakest leg -- it depends on attention and marketing execution rather than protocol-intrinsic mechanics, though the structural effect of a large Day 0 cohort approaching unlock provides a floor.

The xBTC incentive gradient decays linearly across the bootstrap but is unlikely to be the primary driver in any phase beyond Phase I. The vesting head-start advantage for early minters is quantifiable but modest in practical terms.

---

## Table of Contents

1. [Research Question and Hypothesis](#1-research-question-and-hypothesis)
2. [Phase I: Initial Surge (Days 0-30)](#2-phase-i--initial-surge-days-0-30)
3. [Phase II: Punctuated Trough (Days 31-1098)](#3-phase-ii--punctuated-trough-days-31-1098)
4. [Phase III: Terminal Rally (Days 1099-1128)](#4-phase-iii--terminal-rally-days-1099-1128)
5. [The xBTC Incentive Gradient](#5-the-xbtc-incentive-gradient)
6. [Vesting Head-Start Advantage](#6-vesting-head-start-advantage)
7. [DeFi Precedent Analysis](#7-defi-precedent-analysis)
8. [Failure Modes and Alternative Patterns](#8-failure-modes-and-alternative-patterns)
9. [Quantitative Framework](#9-quantitative-framework)

---

## 1. Research Question and Hypothesis

**Research question:** How does vault minting volume distribute across the 1129-day bootstrap phase, and what incentive structures drive minting at each stage?

**Hypothesis:** Minting follows a three-phase pattern:

| Phase | Days | Duration | Expected Behavior |
|-------|------|----------|-------------------|
| I. Initial Surge | 0-30 | 1 month | High volume, decaying daily as early adopters exhaust |
| II. Punctuated Trough | 31-1098 | ~35 months | Low baseline with catalyst-driven sub-peaks |
| III. Terminal Rally | 1099-1128 | ~1 month | Rising volume from vBTC launch attention |

**Measurable predictions:**
- Daily mint count peaks on Day 0-1, declines monotonically through Day 30
- Days 31-1098 average daily mints are <10% of Day 1 volume, with sporadic spikes
- Days 1099-1128 daily mints exceed the trough average by 2-5x

**Scope distinction:** This document covers *temporal* minting behavior (when people mint). [Minting Economics](./Minting_Economics.md) covers *micro-economic* behavior (how much they mint per vault).

---

## 2. Phase I -- Initial Surge (Days 0-30)

### Incentive Structure

Day 0-30 minters face the strongest combined incentive set in the entire bootstrap:

| Incentive | Strength | Mechanism |
|-----------|----------|-----------|
| xBTC utility | Maximum (1099-1129 days) | Longest DeFi participation window |
| Novelty | Maximum | First-mover narrative, launch excitement |
| Match pool positioning | Maximum | Earliest collateral-weighted claim accumulation |
| Vesting head-start | Maximum | First to unlock withdrawals on Day 1129 |

### Expected Behavior

The surge follows a standard **launch attention curve**: social media amplification, influencer coverage, and community coordination drive concentrated minting in the first days. This decays exponentially as the pre-launch audience -- those who were already aware and decided to participate -- exhausts.

Multi-vault minting (see [Minting Economics](./Minting_Economics.md) Section 5) amplifies apparent volume: a single participant creating 10 vaults at 0.005 WBTC each registers as 10 mints, inflating the count relative to unique minters.

### xBTC Differential Within Phase I

The xBTC utility difference between Day 0 and Day 30 is small:

| Mint Day | xBTC Utility (days) | % of Maximum |
|----------|--------------------:|-------------:|
| 0 | 1129 | 100.0% |
| 7 | 1122 | 99.4% |
| 14 | 1115 | 98.8% |
| 30 | 1099 | 97.3% |

A 2.7% reduction in xBTC utility is not a meaningful differentiator within Phase I. The decay in minting volume during this phase is driven by **audience exhaustion**, not incentive degradation.

---

## 3. Phase II -- Punctuated Trough (Days 31-1098)

### Baseline Condition

During the trough, the protocol offers:
- No vBTC (blocked by `StillVesting` check in `VaultNFT.sol`)
- No withdrawals
- No match pool claims
- Declining xBTC utility (97.3% → 2.7% of maximum)

This creates a low-motivation environment for new minters. The protocol is functionally dormant from an external observer's perspective -- vaults exist but produce no visible output.

### Punctuation Model

The trough is not uniform. Four categories of external catalyst create irregular sub-peaks:

**1. BTC Price Movements**

BTC price spikes renew retail interest in Bitcoin-exposure products. A minter who discovers the protocol during a bull run faces the same value proposition as a Day 0 minter -- percentage-based mechanics are scale-invariant. Price-correlated minting spikes are the most likely punctuation source, as they are exogenous to the protocol.

**2. xBTC DeFi Integrations**

When whitelisted protocols (per `ExpeditionCredits.sol` whitelist) integrate xBTC -- lending markets, LP pools, governance tokens -- new minting is incentivized to farm those opportunities. Each integration creates a step-function increase in xBTC utility, potentially triggering a minting sub-peak.

**3. Match Pool Milestones**

The match pool accumulates visibly on-chain from early redeemer forfeitures. As the pool grows, rational minters recognize that each new vault increases their pro-rata claim on that pool (claimable after their own vesting completes). Key milestones (e.g., match pool reaching 10 BTC, 50 BTC) may attract attention.

**4. Issuer Launches**

New issuer deployments introduce new Treasure NFTs. Minting tied to a specific issuer's campaign creates demand independent of the protocol's bootstrap timeline. Each issuer launch is a localized minting event.

### Trough Minter Profiles

| Profile | Motivation | Minting Pattern |
|---------|-----------|----------------|
| **The Strategist** | Understands vBTC pricing model; mints to start vesting clock for future vBTC arbitrage | Single deliberate entry, typically larger vaults |
| **The Accumulator** | Dollar-cost-averages into vaults over time for staggered vesting schedules | Regular small mints (monthly/quarterly) |
| **The Match Pool Watcher** | Monitors on-chain match pool growth; mints when pro-rata returns look attractive | Sporadic, correlated with early redemption events |
| **The Latecomer** | Discovers the protocol organically through word-of-mouth, aggregators, or DeFi exploration | Random, uncorrelated with protocol timeline |

The Latecomer is likely the dominant trough minter by volume -- organic discovery is continuous while strategic minting is front-loaded to Phase I. However, the Accumulator's pattern (regular, predictable, small) may represent the most consistent baseline activity.

---

## 4. Phase III -- Terminal Rally (Days 1099-1128)

### Driver Analysis

Two forces could drive terminal minting, weighted by likelihood:

**Primary Driver: Narrative and Attention (weighted higher)**

As Day 1129 approaches, the first vBTC minting event generates coverage:
- Protocol dashboards display countdown timers
- Day 0 minters publicly discuss their approaching unlock on social media
- Media covers the "first vBTC" event as a milestone
- vBTC speculation begins on secondary markets before the token exists

This attention draws new participants who view the protocol as **proven** (3+ years of operation, no exploits, growing match pool). They are not bootstrap participants in mindset -- they are the first cohort of the post-bootstrap era, minting during the terminal window by coincidence of timing.

**Contingency:** This driver requires active marketing or a sufficiently large Day 0 cohort to generate organic buzz. Without either, the terminal rally may not materialize.

**Secondary Driver: Structural Protocol Effect (weighted lower)**

The approaching vBTC unlock is a protocol milestone that generates organic attention independent of marketing:
- On-chain data shows vaults approaching vesting completion
- DeFi protocols prepare vBTC integrations (Curve pools, lending markets)
- Arbitrageurs position for the vBTC discount opportunity (see [vBTC Pricing Model](./vBTC_Pricing_Model.md))

**Contingency:** This effect requires DeFi ecosystem awareness of the protocol. If the protocol remains niche, structural effects are insufficient alone.

### Conditions for Driver Dominance

| Condition | Dominant Driver |
|-----------|----------------|
| Large Day 0 cohort (>1000 vaults) | Structural -- organic buzz from existing holders |
| Small Day 0 cohort (<100 vaults) | Attention -- requires active marketing to create rally |
| Active DeFi integrations of xBTC | Structural -- ecosystem already aware |
| No DeFi integrations | Attention -- protocol unknown to broader DeFi |
| Bull market at Day 1099 | Both -- price momentum amplifies attention effects |
| Bear market at Day 1099 | Neither -- suppressed activity regardless |

### Terminal Minter Economics

Late minters face significant disadvantages relative to Day 0 minters:

| Metric | Day 0 Minter | Day 1100 Minter |
|--------|-------------:|----------------:|
| xBTC utility | 1129 days | 29 days |
| First withdrawal | Day 1129 | Day 2229 |
| First match pool claim | Day 1129 | Day 2229 |
| Vesting advantage | 1100 days of withdrawals before Day 1100 minter starts | None |

The near-zero xBTC utility (29 days vs 1129) confirms that **xBTC is not the driver for Phase III minting**. Terminal minters are motivated by the protocol's proven track record and future vBTC economics, not bootstrap incentives.

The "next cohort" framing: these minters see a 3-year-old protocol with a growing match pool, imminent vBTC liquidity, and a track record of security. Their decision calculus is forward-looking, identical to post-bootstrap minting with the minor bonus of 29 days of xBTC.

---

## 5. The xBTC Incentive Gradient

### Formal Model

xBTC utility at mint day `t` within bootstrap:

```
U(t) = bootstrapEnd - t    (in days)
```

Linear decay from 1129 days (Day 0) to 0 days (Day 1129):

| Mint Day | xBTC Utility (days) | % of Maximum | Phase |
|----------|--------------------:|-------------:|-------|
| 0 | 1129 | 100.0% | I |
| 30 | 1099 | 97.3% | I |
| 90 | 1039 | 92.0% | II |
| 365 | 764 | 67.7% | II |
| 730 | 399 | 35.3% | II |
| 1000 | 129 | 11.4% | II |
| 1099 | 30 | 2.7% | III |
| 1128 | 1 | 0.1% | III |

### Duration-Dependent vs Binary Value

Whether the xBTC gradient matters depends on how xBTC derives value:

**If duration-dependent** (e.g., xBTC staking rewards accrue daily): The gradient is a meaningful differentiator. Day 0 minters earn 39x more xBTC-derived value than Day 1099 minters. This strongly favors Phase I minting and creates genuine urgency.

**If binary** (e.g., xBTC grants access to a governance vote or airdrop snapshot): The gradient is irrelevant. Having xBTC for 1 day provides the same access as having it for 1129 days. This eliminates urgency entirely.

The protocol's current design (restricted ERC-20 with whitelisted transfers per `ExpeditionCredits.sol`) is agnostic -- xBTC's value depends on what whitelisted integrations emerge. The gradient's importance is therefore **contingent on the DeFi ecosystem's treatment of xBTC**.

---

## 6. Vesting Head-Start Advantage

### Model

A Day 0 minter begins withdrawals on Day 1129 at 1% monthly. By the time a Day-t minter reaches their own Day 1129 (i.e., on absolute day `t + 1129`), the Day 0 minter has already withdrawn:

```
H(t) = 1 - 0.99^(t/30)
```

Where `H(t)` = fraction of original collateral the Day 0 minter has withdrawn before the Day-t minter starts.

| Late Minter's Day | Months of Head-Start | Day 0 Withdrawal Head-Start | % of Original Collateral |
|------------------:|---------------------:|----------------------------:|-------------------------:|
| 90 | 3 | 0.000149 WBTC | 2.97% |
| 365 | 12.2 | 0.000568 WBTC | 11.36% |
| 730 | 24.3 | 0.001076 WBTC | 21.52% |
| 1098 | 36.6 | 0.001537 WBTC | 30.74% |

*Withdrawal amounts based on 0.005 WBTC initial vault per [Minting Economics](./Minting_Economics.md).*

### Practical Significance

The head-start is real but modest: a Day 365 minter "loses" 11.36% of collateral value relative to a Day 0 minter's cumulative withdrawals. However, both minters face identical percentage-based economics from their respective start dates. The head-start is a one-time opportunity cost, not a compounding disadvantage.

For the [Long Duration Capital Strategies](./Long_Duration_Capital_Strategies.md) roll-forward model, the head-start shifts the entire multiplication timeline by `t` days but does not change the terminal multiplier (6.55x). A Day 365 minter achieves 6.55x multiplication one year later than a Day 0 minter -- an opportunity cost, but not a structural penalty.

---

## 7. DeFi Precedent Analysis

| Protocol | Lock Duration | Yield During Lock | Pre-Unlock Pattern | Relevance |
|----------|:------------:|:-----------------:|:------------------:|:---------:|
| **ETH 2.0 Beacon Chain** | ~18 months (Dec 2020 - Apr 2023) | Validator rewards (~4-5% APR) | Steady growth, no three-phase pattern | High |
| **Pendle Fixed-Term YT/PT** | Variable (weeks to months) | Yield tokenization | Volume concentrates near maturity | Moderate |
| **Curve veCRV** | Up to 4 years | Governance power + boost | Catalyst-driven (Convex, governance wars) | Moderate |
| **Olympus OHM Bonding** | 5 days (short) | Extreme APY (>1000%) | Explosive surge → sustained → collapse | Low |

### ETH 2.0 Beacon Chain (Most Relevant)

The beacon chain required one-way ETH deposits with no withdrawal mechanism until the Shanghai upgrade (~18 months later). Staking grew from ~500K ETH at genesis to ~16M ETH by Shanghai, following a **relatively steady growth curve** rather than a three-phase pattern.

**Key difference:** ETH staking offered continuous yield (validator rewards) from Day 1, providing an ongoing incentive throughout the lock period. BTCNFT's bootstrap offers xBTC but no direct yield -- a weaker continuous incentive. This suggests the BTCNFT trough may be more pronounced than ETH's steady growth, supporting the three-phase hypothesis.

### Pendle Fixed-Term Tokenization (Supports Phase III)

Pendle's yield tokens (YT) and principal tokens (PT) show increased trading activity as maturity approaches. This "maturity effect" directly parallels the terminal rally hypothesis -- approaching a known unlock event generates speculative and positioning activity.

**Key difference:** Pendle maturities are weeks to months, not 3+ years. The attention span required for a 1129-day terminal rally is qualitatively different from a 30-day maturity trade.

### Curve veCRV Locking (Supports Punctuated Trough)

veCRV lock volume was driven primarily by external catalysts -- the launch of Convex Finance, the "Curve Wars" governance battles, and periodic gauge weight votes. The lock duration itself was less important than what happened *during* the lock.

**Implication:** The BTCNFT trough will be punctuated by similar external catalysts (xBTC integrations, issuer launches, BTC price movements) rather than following a smooth decay curve. Protocol-exogenous events matter more than the intrinsic incentive gradient over a 36-month timeframe.

---

## 8. Failure Modes and Alternative Patterns

### Alternative 1: Monotonic Decay

**Pattern:** Phase I surge followed by continuously declining activity with no terminal rally.

**Conditions:** Protocol fails to generate Day 1129 awareness. The vBTC launch passes without significant coverage. This is the most likely failure mode for Phase III.

**Probability assessment:** Moderate if Day 0 cohort is small (<100 vaults) and no active marketing. Low if Day 0 cohort is large (>1000 vaults) -- organic social media from approaching-unlock holders provides a floor.

### Alternative 2: External Catalyst Dominance

**Pattern:** Minting activity correlates primarily with BTC price and market sentiment, overriding the three-phase structure entirely.

**Conditions:** Protocol minting tracks crypto market cycles rather than its own bootstrap timeline. Historical DeFi data strongly supports this -- most protocol activity correlates with market cycles regardless of protocol-specific mechanics.

**Implication:** The three-phase model may be a useful theoretical framework that is observationally dominated by market noise. The phases exist in the incentive structure but are invisible in the data.

### Alternative 3: Slow Build (No Phase I Surge)

**Pattern:** Without a pre-built community, Phase I is underwhelming. Activity grows gradually through organic discovery with no clear phase boundaries.

**Conditions:** Protocol launches without significant marketing, pre-launch waitlists, or influencer partnerships. This produces a "slow drip" pattern rather than a surge-trough-rally.

### Alternative 4: Match Pool Feedback Loop

**Pattern:** Mid-bootstrap minting spike not predicted by the three-phase model.

**Mechanism:** Early redeemers during months 6-18 forfeit collateral, growing the match pool. The visible on-chain match pool attracts new minters who want pro-rata claims, creating a positive feedback loop. This could produce a "second wind" in the middle of the hypothesized trough.

### Alternative 5: xBTC DeFi Catalyst

**Pattern:** Mid-bootstrap minting spike correlated with an xBTC integration, not the protocol timeline.

**Mechanism:** A whitelisted lending protocol or LP pool offers attractive xBTC yields. New minting is motivated by farming the integration, not by vault economics. The spike's magnitude and timing are determined by the integration, not the bootstrap calendar.

### Hypothesis Strength Assessment

| Phase | Confidence | Rationale |
|-------|:----------:|-----------|
| I. Initial Surge | **Strong** | Universal DeFi launch pattern; no known counter-examples |
| II. Punctuated Trough | **Moderate** | Baseline low activity is well-supported; punctuation timing is unpredictable |
| III. Terminal Rally | **Weak-Moderate** | Contingent on attention/marketing; structural effect provides a floor but may be insufficient alone |

---

## 9. Quantitative Framework

### Composite Minting Incentive Score

A minter on Day `t` faces a composite incentive:

```
I(t) = w₁ × U(t) + w₂ × V(t) + w₃ × M(t) + w₄ × A(t)
```

Where:
- `U(t) = (1129 - t) / 1129` — normalized xBTC utility (1.0 → 0.0)
- `V(t) = 1 / (1 + t/365)` — vesting advantage decay (earlier = more head-start)
- `M(t)` — match pool attractiveness (observable on-chain, grows monotonically)
- `A(t)` — attention/awareness factor (exogenous, peaks at Day 0 and Day ~1100+)
- `w₁...w₄` — weights reflecting relative importance of each factor

The three-phase hypothesis implies `A(t)` is bimodal (high at Phase I and Phase III), `U(t)` and `V(t)` are monotonically declining, and `M(t)` is monotonically increasing. The interaction of these curves produces the predicted pattern.

### Sensitivity Analysis

The shape of the minting curve `m(t)` varies under different assumptions:

| Assumption | Phase I | Trough | Phase III |
|------------|---------|--------|-----------|
| xBTC highly valuable (duration-dependent) | Amplified surge | Steeper decline | No effect (utility ≈ 0) |
| xBTC low value (binary/negligible) | Unchanged (novelty-driven) | Slightly higher baseline | No effect |
| BTC bull market during trough | Unchanged | Significant sub-peaks | Possible amplification |
| BTC bear market at Day 1099 | N/A | N/A | Rally suppressed |
| Large Day 0 cohort (>1000 vaults) | Higher peak | Higher baseline (network effects) | Structural rally likely |
| Small Day 0 cohort (<100 vaults) | Lower peak | Lower baseline | Rally requires marketing |
| Strong xBTC DeFi integrations | Amplified | Sub-peaks from integrations | Minor effect |

### Key Metric: Phase Transition Ratios

Observable metrics to validate or falsify the hypothesis post-launch:

| Metric | Predicted Value | Falsification Threshold |
|--------|:--------------:|:-----------------------:|
| Day 30 mints / Day 1 mints | < 0.2 | > 0.8 (no decay) |
| Trough average / Day 1 mints | < 0.1 | > 0.3 (no trough) |
| Day 1100 mints / Trough average | > 2.0 | < 0.5 (no rally) |
| Trough CV (coefficient of variation) | > 1.5 (punctuated) | < 0.5 (uniform) |

---

## References

### Internal
- `contracts/protocol/src/VaultNFT.sol` — Mint function, vesting gate (`StillVesting` revert)
- `contracts/protocol/src/ExpeditionCredits.sol` — xBTC mechanics, bootstrap-only minting, whitelist transfers
- `contracts/protocol/src/libraries/VaultMath.sol` — `VESTING_PERIOD = 1129 days`, withdrawal rate constants
- [Minting Economics](./Minting_Economics.md) — Vault sizing (0.005 WBTC), multi-vault strategy, gas thresholds
- [vBTC Pricing Model](./vBTC_Pricing_Model.md) — Option-theoretic pricing, break-even periods, discount factor
- [Long Duration Capital Strategies](./Long_Duration_Capital_Strategies.md) — 6.55x roll-forward multiplication
- [Vesting Period](./Vesting_Period.md) — 1129-day derivation, early redemption formula, match pool mechanics
- [Competitive Positioning](./Competitive_Positioning.md) — Why users choose BTCNFT over alternatives
- [Time Preference Primer](./Time_Preference_Primer.md) — Discount rates underlying minter patience

### External
- Ethereum 2.0 beacon chain staking data (Dec 2020 - Apr 2023): steady growth pattern under one-way deposit constraint
- Pendle Finance maturity concentration patterns: trading volume increases near fixed-term expiry
- Curve Wars / veCRV lock dynamics (2020-2023): external catalyst dominance over intrinsic lock incentives
