# BTCNFT Protocol Glossary

> **Version:** 1.7
> **Status:** Final
> **Last Updated:** 2026-01-03

Standardized terminology for BTCNFT Protocol documentation.

---

## Core Concepts

### Vault NFT

| Attribute | Value |
|-----------|-------|
| Standard | ERC-998 (Composable) |
| Contains | Treasure NFT + BTC collateral |
| Rights | Withdrawals, redemption, collateral matching |

The primary asset of the protocol. A composable NFT that holds both a Treasure NFT and BTC collateral, granting perpetual withdrawal rights after vesting.

### Treasure NFT

| Attribute | Value |
|-----------|-------|
| Standard | ERC-721 |
| Purpose | Wrapped within Vault NFT |
| Ownership | Vault holder |

Any ERC-721 NFT that can be deposited into a Vault. Issuers define which Treasure contracts are eligible for their minting windows.

### vestedBTC

| Attribute | Value |
|-----------|-------|
| Standard | ERC-20 (Fungible) |
| Decimals | 8 (matches WBTC) |
| Backing | 1:1 with Vault collateral at mint |

**Also known as:** btcToken (internal contract name)

Fungible token representing a claim on BTC collateral. Created by separating collateral from a Vault NFT. Enables DeFi composability (DEX trading, lending, liquidity pools).

#### vestedBTC Variants

Each collateral type has its own vestedBTC token to maintain risk isolation:

| Symbol | Name | Backed By |
|--------|------|-----------|
| vWBTC | vestedBTC-wBTC | Wrapped Bitcoin (BitGo custodial) |
| vCBBTC | vestedBTC-cbBTC | Coinbase Bitcoin (Coinbase custodial) |
| vTBTC | vestedBTC-tBTC | Threshold Bitcoin (decentralized threshold network) |

**Note:** Each variant has independent pricing and risk profile based on its underlying collateral's custody model.

### Hybrid Vault NFT (Protocol Layer)

| Attribute | Value |
|-----------|-------|
| Standard | ERC-721 |
| Layer | Protocol |
| Contains | Primary (cbBTC) + Secondary (any ERC-20) |

Immutable protocol-layer construct that accepts two ERC-20 tokens with asymmetric withdrawal models.

**Key Properties:**
- Primary: 1% monthly withdrawal (Zeno's paradox)
- Secondary: 100% one-time at vesting
- vestedBTC separation (primary only)
- Dual match pools (primary + secondary)
- Ratio-agnostic: caller determines split

**See:** [Protocol HybridVaultNFT Specification](protocol/Hybrid_Vault_Specification.md)

### Hybrid Vault NFT (Issuer Layer)

| Attribute | Value |
|-----------|-------|
| Standard | ERC-721 |
| Layer | Issuer |
| Wraps | Protocol HybridVaultNFT |

Issuer-layer wrapper that adds Curve LP integration, dynamic ratio formulas, and monthly configuration on top of the protocol-layer HybridVaultNFT.

**Key Properties:**
- Dynamic LP ratio (10-50% range, 30% default)
- Curve pool integration (add_liquidity, get_dy)
- Monthly issuer configuration (rate-limited)
- Self-calibrating slippage signal

**See:** [Issuer Hybrid Vault Specification](issuer/Hybrid_Vault_Specification.md)

---

## Protocol Parameters

### Vesting Period

| Value | Description |
|-------|-------------|
| 1129 days | ~3.09 years |

Time before Vault holders can begin withdrawals. Immutable.

### Withdrawal Rate

| Value | Description |
|-------|-------------|
| 1.0%/month | 12%/year |

Maximum BTC that can be withdrawn each period. Immutable.

### Withdrawal Period

| Value | Description |
|-------|-------------|
| 30 days | Monthly cycle |

Interval between withdrawal opportunities.

### Dormancy Threshold

| Value | Description |
|-------|-------------|
| 1129 days | Inactivity period |

Time without activity before a separated Vault becomes dormant-eligible.

---

## Actors

### Issuer

Entity that creates minting opportunities. Controls entry requirements, Treasure design, and campaigns. Cannot modify core protocol parameters.

**Types:**
- Personal Brand
- DAO
- Corporation
- Artist Collective
- Community

### Holder

Owner of a Vault NFT. Has withdrawal rights, Treasure ownership, and (unless separated) redemption rights.

### vestedBTC Holder

Owner of vestedBTC tokens. Has collateral claim but no withdrawal rights or Treasure ownership.

---

## Operations

### Minting

Creating a new Vault NFT by depositing Treasure NFT + BTC collateral.

**Modes:**
- **Instant Mint**: Immediate permissionless minting
- **Window Mint**: Campaign-based coordinated releases

### Separation

Converting Vault collateral into fungible vestedBTC tokens via `mintBtcToken()`.

**Effect:** Vault retains withdrawal rights; vestedBTC represents collateral claim.

### Recombination

Returning vestedBTC to restore full Vault rights via `returnBtcToken()`.

**Requirement:** All-or-nothing (full original amount required).

### Collateral Matching

Pro-rata distribution of forfeited collateral from early redeemers to remaining Vault holders.

### Dormancy Claim

Process by which vestedBTC holders claim collateral from abandoned (dormant) Vaults.

---

## Token Standards

| Token | Standard | Fungibility |
|-------|----------|-------------|
| Vault NFT | ERC-998 | Non-fungible |
| Treasure NFT | ERC-721 | Non-fungible |
| vestedBTC | ERC-20 | Fungible |
| WBTC (collateral) | ERC-20 | Fungible |

---

## Naming Conventions

### In Code vs Documentation

| Code | Documentation | Description |
|------|---------------|-------------|
| `BtcToken` | vestedBTC | Separated collateral token |
| `btcToken` | vestedBTC | Contract instance |
| `mintBtcToken()` | Separation | Function to create vestedBTC |
| `returnBtcToken()` | Recombination | Function to restore Vault rights |
| `vBTC` | vestedBTC | Token symbol |

---

## Delegation System

### WalletDelegatePermission

| Attribute | Value |
|-----------|-------|
| Scope | All vaults owned by wallet |
| Fields | percentageBPS, grantedAt, active |

Struct representing a wallet-level delegation grant that applies to all vaults owned by the granting wallet. Does not expire automatically.

### VaultDelegatePermission

| Attribute | Value |
|-----------|-------|
| Scope | Single specific vault |
| Fields | percentageBPS, grantedAt, expiresAt, active |

Struct representing a vault-specific delegation grant. Includes optional `expiresAt` timestamp for time-limited delegation. Takes precedence over wallet-level delegation.

### DelegationType

| Value | Description |
|-------|-------------|
| None | No delegation active |
| WalletLevel | Using wallet-level delegation |
| VaultSpecific | Using vault-specific delegation |

Enum indicating which delegation type is effective for a vault/delegate pair. Returned by `canDelegateWithdraw()` and `getEffectiveDelegation()`.

**Resolution Priority:** VaultSpecific > WalletLevel > None

---

## Visual & Tier System

### Display Tier

Wealth-based visual tier (Bronze/Silver/Gold/Platinum/Diamond) dynamically computed from collateral percentile. Unlike achievements which are merit-based, display tiers reflect relative collateral position within the protocol.

| Tier | Percentile Range |
|------|-----------------|
| Bronze | 0–50th |
| Silver | 50–75th |
| Gold | 75–90th |
| Platinum | 90–99th |
| Diamond | 99th+ |

**Note:** Thresholds are keeper-updated based on current collateral distribution.

### Keeper

Authorized address that periodically updates on-chain tier thresholds based on current collateral distribution. Ensures Display Tiers remain calibrated to actual protocol TVL.

### ERC-4906

Metadata update extension (EIP-4906). Defines `MetadataUpdate` and `BatchMetadataUpdate` events for signaling NFT metadata changes to marketplaces and indexers.

**Usage:** Emitted when tier thresholds change, triggering marketplace cache invalidation.

---

## Hybrid Collateral Model

### Hybrid Collateral Vault

| Attribute | Value |
|-----------|-------|
| Primary Collateral | cbBTC (70% target) |
| LP Component | vestedCBBTC/cbBTC Curve LP (30% target) |
| Ratio Range | 50-90% cbBTC, 10-50% LP |

A vault that combines direct BTC backing with protocol-owned liquidity. Automatically contributes to vestedBTC/cbBTC LP depth at minting while preserving simple withdrawal UX.

**See:** [Hybrid Collateral Vault Specification](protocol/Dual_Collateral_Vault.md)

### Dual Withdrawal Model

| Component | Withdrawal Type |
|-----------|----------------|
| cbBTC | 1% monthly perpetual (Zeno's paradox) |
| LP | 100% one-time at vesting |

Withdrawal mechanism for hybrid vaults where cbBTC follows perpetual 1% monthly withdrawals while LP tokens are fully released at vesting completion.

### Dynamic LP Ratio (v2.0)

LP allocation percentage that adjusts based on market conditions via a self-calibrating formula. Parameters managed monthly by issuer with rate limits.

| Signal | Effect |
|--------|--------|
| Slippage > target (0.5%) | ↑ More LP (pool needs depth) |
| Slippage < target | ↓ Less LP (excess depth) |
| vestedBTC Discount > threshold | ↑ More LP (absorb selling) |
| Normal conditions | 30% base |

**Self-Calibrating:** No arbitrary dollar thresholds. Scales to any protocol size.

### Monthly Configuration

```solidity
struct MonthlyConfig {
    uint256 baseLPRatioBPS;        // 30% default
    uint256 targetSlippageBPS;     // 0.5% default
    uint256 discountThresholdBPS;  // 10% default
    // ... sensitivities and bounds
}
```

Issuer updates parameters monthly via `updateMonthlyConfig()`. Changes take effect at the start of each month.

### Rate Limits

Maximum parameter change allowed per month to prevent sudden algorithm shifts.

| Parameter | Max Delta/Month |
|-----------|-----------------|
| Base LP Ratio | ±5% |
| Discount Threshold | ±3% |
| Sensitivities | ±5 |

**Protection:** Full migration from defaults to extremes requires ~10 months.

### Slippage-Based Signal

Self-calibrating measurement that replaces arbitrary TVL thresholds. Measures actual trading friction as percentage of a standardized swap (0.1% of protocol TVL).

```
High slippage (2%) → Pool shallow → Increase LP ratio
Low slippage (0.1%) → Pool deep → Decrease LP ratio (slowly)
```

### Structural POL

Protocol-Owned Liquidity automatically created at vault minting. Every new hybrid vault contributes 30% of collateral to the vestedBTC/cbBTC LP pool.

**Flywheel Effect:**
```
New Vault → 30% to LP → Deeper Pool → Tighter Spread → More Minting → Repeat
```

### Zero Rent Extraction

Design principle where protocol and issuer collect zero fees from vault operations.

| Entity | Fee Collection |
|--------|----------------|
| Protocol | $0 |
| Issuer | $0 |
| Owner | 100% (withdrawals + LP fees) |

LP swap fees accrue to the LP position and transfer to owner at vesting.

### LP-as-Bond

Treatment of LP tokens as a time-locked liquidity commitment that releases 100% at maturity, not as perpetually-draining collateral.

| Property | Value |
|----------|-------|
| Release | 100% at vesting (Day 1129) |
| Re-provision | Owner can add LP back to pool |
| Fees | Accumulated fees included in release |

---

## DeFi Integration Terms

### Negative Carry

The structural yield drag on vestedBTC due to the 1% monthly withdrawal rate.

| Metric | Value |
|--------|-------|
| Monthly | -1.0% |
| Annual | -12.0% |

**Implication:** Lending protocols must set base interest rates above 12% APR to prevent arbitrage.

### Dynamic LTV

Loan-to-value ratio that adjusts based on current vestedBTC discount level.

| Discount | vBTC/wBTC | Max LTV |
|----------|-----------|---------|
| 5% | 0.95 | 75% |
| 15% | 0.85 | 55% |
| 25% | 0.75 | 35% |

**Rationale:** Wider discounts indicate higher volatility, requiring more collateral buffer.

### Dutch Auction Liquidation

Time-based liquidation mechanism where bonus increases linearly until a liquidator claims.

| Parameter | Value |
|-----------|-------|
| Start Bonus | 0% |
| End Bonus | 15% |
| Duration | 60 minutes |

**Advantage over circuit breakers:** No queuing, market-driven price discovery, reduced bad debt risk.

### Flash Loan Looping

Atomic recursive borrowing using flash loans to achieve leverage in a single transaction.

**Flow:** Flash loan → Deposit collateral → Borrow → Repay flash loan → Final leveraged position

**Provider:** Balancer V2 (zero-fee flash loans)

**Benefit:** No MEV exposure, gas efficient, single-transaction UX.

### CDP (Collateralized Debt Position)

Over-collateralized borrowing where users deposit collateral and borrow against it.

| Market | Collateral | Borrow |
|--------|------------|--------|
| Short vBTC | wBTC | vBTC |
| Long vBTC | vBTC | USDC |

**See:** [Leveraged Lending Protocol](defi/Leveraged_Lending_Protocol.md)

---

## Volatility Products

### Variance

A statistical measure of price dispersion. Calculated as the average of squared deviations from the mean (log returns squared).

| Formula | Description |
|---------|-------------|
| Variance = (252/N) × Σr(t)² | Annualized variance from N observations |
| r(t) = ln(P(t)/P(t-1)) | Log return between observations |

**Usage:** Variance swap settlement, volatility targeting, risk metrics.

### Realized Variance

Actual variance observed over a specific time period, calculated from price observations.

| Period | Observations | Frequency |
|--------|--------------|-----------|
| 7 days | 7 | Daily |
| 30 days | 30 | Daily |
| 90 days | 90 | Daily |

**Annualization Factor:** 252 trading days (standard)

### Strike Variance

The fixed variance level agreed upon in a variance swap. Determines the breakeven point.

| Example | Implication |
|---------|-------------|
| Strike = 4% | Long profits if realized > 4% |
| Strike = 4% | Short profits if realized < 4% |

**Market Rate:** Determined by supply/demand in variance swap matching.

### Variance Swap

A derivative contract where one party pays fixed (strike variance) and receives floating (realized variance), while the counterparty takes the opposite position.

| Position | Pays | Receives | Profits When |
|----------|------|----------|--------------|
| Long Vol | Strike | Realized | Price moves (either direction) |
| Short Vol | Realized | Strike | Price stable |

**Settlement:** `PnL = Notional × (Realized_Variance - Strike_Variance)`

**See:** [vestedBTC Derivatives Suite](defi/vestedBTC_Derivatives_Suite.md)

### Long Volatility

Position that profits when realized variance exceeds strike variance. Benefits from large price movements in either direction.

**Mechanism:** Pay fixed premium, receive realized variance

**Use Case:** Hedging directional uncertainty, profiting from market turbulence

### Short Volatility

Position that profits when realized variance is below strike variance. Benefits from price stability.

**Mechanism:** Receive fixed premium, pay realized variance

**Use Case:** Earning premium during calm markets, yield enhancement

### Log Return

Natural logarithm of price ratio between two observations. Used for variance calculation.

```
r(t) = ln(P(t) / P(t-1))

Example:
- P(t-1) = 0.90 (vBTC/BTC)
- P(t)   = 0.92 (vBTC/BTC)
- r(t)   = ln(0.92/0.90) = 0.022 (2.2%)
```

**Property:** Log returns are additive over time, making them suitable for variance calculation.

### TWAP (Time-Weighted Average Price)

Price averaged over a time window to reduce manipulation risk.

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Period | 30 minutes | Balance responsiveness vs manipulation resistance |
| Source | Curve/Uniswap pool | On-chain verifiable |
| Staleness | 1 hour max | Fail-fast on illiquid conditions |

**Usage:** Oracle price for lending, variance swap observations.

### Observation Period

Duration over which price observations are collected for variance calculation.

| Standard Periods | Use Case |
|------------------|----------|
| 7 days | Short-term volatility trading |
| 30 days | Standard exposure (options-equivalent) |
| 90 days | Quarterly hedging, longer-term views |

### Observation Frequency

Interval between price observations within an observation period.

| Frequency | Rationale |
|-----------|-----------|
| Daily (86400s) | Standard, sufficient samples |
| Minimum 1 hour | Prevents observation spam |

### MAX_VARIANCE

Upper bound on realized variance for settlement calculation. Caps maximum loss for short volatility positions.

| Value | Implication |
|-------|-------------|
| 100% (1e18) | Short vol max loss = notional × (100% - strike) |

**Rationale:** Prevents unbounded losses from extreme volatility events.

### Volatility Farming

Yield generation strategy that captures returns from market volatility through LP positions.

| Yield Source | Description |
|--------------|-------------|
| Swap fees | 0.04% per trade |
| CRV emissions | Gauge rewards (if approved) |
| Arbitrage | Implicit rebalancing profits |

**Mechanism:** Deposit to Curve LP → Stake in gauge → Harvest rewards → Compound

**See:** [Native Volatility Farming Architecture](research/Native_Volatility_Farming_Architecture.md)

### Yield Vault (yvBTC)

ERC-4626 vault that deploys vestedBTC to yield-generating strategies.

| Property | Value |
|----------|-------|
| Standard | ERC-4626 |
| Strategy | Curve LP + gauge staking |
| Fee | 10% performance (no management fee) |

**Exchange Rate:** `totalAssets / totalSupply` grows as yield accrues

### VarianceVaultLong

ERC-4626 vault providing long volatility exposure through variance swap matching.

| Property | Value |
|----------|-------|
| Exposure | Long realized variance |
| Collateral | Strike × Notional |
| Settlement | End of observation period |

**UX:** Deposit → Auto-match with short vault → Receive shares → Settlement adjusts exchange rate

### VarianceVaultShort

ERC-4626 vault providing short volatility exposure through variance swap matching.

| Property | Value |
|----------|-------|
| Exposure | Short realized variance |
| Collateral | (MAX_VARIANCE - Strike) × Notional |
| Settlement | End of observation period |

**UX:** Deposit → Auto-match with long vault → Receive shares → Settlement adjusts exchange rate

---

## Governance Terms

### Derivatives DAO

Governance layer overseeing vestedBTC derivative products. Controls limited parameters without collecting fees or managing a treasury.

| Property | Value |
|----------|-------|
| Scope | Derivatives layer only |
| Fee Collection | None |
| Treasury | None |
| Transition | 1129-day founder→community |

**See:** [Governance Specification](dao/Governance_Specification.md)

### Organic Voting Power

Voting power derived from a wallet's actual BTC exposure across the protocol.

| Source | Calculation |
|--------|-------------|
| vestedBTC balance | Direct wallet balance |
| Unsplit Vault collateral | Collateral where `mintBtcToken()` not called |
| yvBTC shares | Converted to underlying vestedBTC |
| LP tokens | Converted to underlying vestedBTC |

**Formula:** `organicPower = vBTC + unsplitVaults + derivativePositions`

### Transitional Voting Power

Founder's decaying bonus power that transitions governance control to community over 1129 days.

| Day | Multiplier |
|-----|------------|
| 0 | 100% of totalProtocolBTC |
| 564 | 50% of totalProtocolBTC |
| 1129 | 0% (pure organic) |

**Formula:** `transitionalPower = totalProtocolBTC × (1 - daysSinceLaunch / 1129)`

### Unsplit Vault

VaultNFT where `mintBtcToken()` has not been called. Collateral remains unified with the vault.

**Voting Power:** Full collateral amount counts toward organic voting power.

**Contrast:** Split vaults have collateral represented as vestedBTC tokens.

### ProductRegistry

Whitelist of derivative contracts the DAO can govern, with parameter bounds.

| Field | Purpose |
|-------|---------|
| `minFeeBps` | Minimum fee DAO can set |
| `maxFeeBps` | Maximum fee DAO can set |
| `pausable` | Whether DAO can pause product |

### Parameter Bounds

Min/max limits on adjustable derivative parameters. Enforced by ProductRegistry.

**Purpose:** Limits governance attack surface by constraining parameter changes.

### Quorum

Minimum participation required for proposal validity.

| Parameter | Value |
|-----------|-------|
| BTCNFT DAO | 4% of total voting power |

**Calculation:** `quorum = totalVotingPower × 0.04`

### Execution Delay

Mandatory waiting period between proposal passing and execution.

| Parameter | Value |
|-----------|-------|
| BTCNFT DAO | 2 days |

**Purpose:** Allows users to exit positions before parameter changes take effect

### VotingPowerSourceRegistry

Whitelist of adapter contracts that contribute to governance voting power. Each registered source implements `IVotingPowerSource`.

**Purpose:** Provides separation of concerns - the `VotingPowerCalculator` doesn't need to know about specific derivative implementations.

**Managed By:** DAO proposals (register/unregister sources)

### IVotingPowerSource

Interface for contracts that convert derivative positions to BTC-equivalent voting power.

```solidity
interface IVotingPowerSource {
    function getVotingPower(address holder) external view returns (uint256 btcEquivalent);
}
```

**Implementations:**
- `YvBTCVotingAdapter` - Converts yvBTC shares to underlying vestedBTC
- `CurveLPVotingAdapter` - Converts LP tokens to underlying vestedBTC

### Voting Adapter

A contract implementing `IVotingPowerSource` for a specific derivative product. Adapters bridge the gap between derivative-specific logic and the standard voting power interface.

**Pattern:** Adapter Pattern (GoF) - converts one interface to another

---

## Chapter System (The Ascent)

### Chapter

A quarterly campaign period within The Ascent that unlocks exclusive achievements for holders within a specific journey day range. Each of the 12 chapters corresponds to a ~91-day segment of the 1129-day vesting period.

| Property | Description |
|----------|-------------|
| Duration | 91 days (Chapter 12 extended to 128 days) |
| Content | Unique map, achievements, visual theme |
| Lifecycle | Active during calendar quarter, locked forever after |

**Note:** Chapters layer alongside (not replace) the perpetual personal journey achievements.

### Chapter Achievement

A soulbound NFT earned by completing chapter-specific objectives within the mint window. Unlike perpetual journey achievements, chapter achievements lock forever when the quarter ends.

| Property | Description |
|----------|-------------|
| Standard | ERC-721 + ERC-5192 (soulbound) |
| Minting | During chapter's calendar quarter only |
| Prerequisites | May require other achievements in skill tree |

### Chapter ID

Unique identifier encoding chapter number, year, and quarter.

| Format | Example |
|--------|---------|
| `CH{number}_{year}Q{quarter}` | CH1_2025Q1 |

**On-chain:** `keccak256(abi.encodePacked("CH", chapterNumber, "_", year, "Q", quarter))`

### Achievement ID

Unique identifier for a specific achievement within a chapter version.

| Format | Example |
|--------|---------|
| `{chapterId}_{achievementName}` | CH1_2025Q1_FIRST_STEPS |

**On-chain:** `keccak256(abi.encodePacked(chapterId, "_", name))`

### Hybrid Eligibility

Dual requirement system combining calendar-based mint windows with personal journey progress gates.

| Gate | Requirement |
|------|-------------|
| Time Gate | Current timestamp within chapter's calendar quarter |
| Journey Gate | Holder's days held within chapter's day range |

**Example:** To participate in Chapter 2 (2025Q2), holder must:
1. Be within April-June 2025 (time gate)
2. Have held vault for 91-181 days (journey gate)

### Journey Gate

The personal journey day range required to participate in a chapter. Ensures holders can only engage with chapter content matching their actual journey progress.

| Chapter | Day Range |
|---------|-----------|
| 1 | 0–90 |
| 2 | 91–181 |
| ... | ... |
| 12 | 1001–1129 |

### Mint Window

The calendar period during which chapter achievements can be claimed. Permanently closes at quarter end.

| Property | Description |
|----------|-------------|
| Open | `startTimestamp` (quarter start) |
| Close | `endTimestamp` (quarter end) |
| After Close | Achievements locked forever |

### Chapter Version

A specific instance of a chapter tied to a year and quarter. Each chapter runs annually with fresh content.

| Example | Description |
|---------|-------------|
| CH1_2025Q1 | Chapter 1, Q1 2025 |
| CH1_2026Q1 | Chapter 1, Q1 2026 (different content) |

**Note:** Same chapter number can have multiple versions across years.

### Skill Tree

Achievement dependency graph within a chapter. Some achievements require completing prerequisites first.

| Property | Description |
|----------|-------------|
| Nodes | Individual achievements |
| Edges | Prerequisite relationships |
| Root | Achievements with no prerequisites |

### Permanent Scarcity

Design principle where chapter content becomes permanently unobtainable after the mint window closes. Creates authentic time-limited collectibility without artificial burns.

| Mechanism | Description |
|-----------|-------------|
| Time Lock | `endTimestamp` enforced on-chain |
| No Extensions | Quarter end is final |
| No Rereleases | Each version unique to its year |

### Chapter Map

Visual representation of a chapter's achievements displayed as a skill tree overlay on a thematic landscape background.

| Component | Storage |
|-----------|---------|
| Background image | Static website (`/chapters/ch{N}/{year}q{Q}/`) |
| Skill tree config | Static website (`config.json`) |
| Achievement NFT images | IPFS (high-resolution) |

### ProfileRegistry

On-chain registry for wallet profiles used by chapter verifiers. Stores registration timestamp per wallet.

| Field | Purpose |
|-------|---------|
| `registeredAt` | Timestamp of profile creation |
| `hasProfile()` | Check if wallet has profile |
| `getDaysRegistered()` | Calculate days since registration |

### IAchievementVerifier

Interface for pluggable achievement verification logic. Verifiers implement custom eligibility checks.

```solidity
interface IAchievementVerifier {
    function verify(address wallet, bytes32 achievementId, bytes calldata data)
        external view returns (bool);
}
```

### Verifier Types

| Verifier | Purpose | Used By |
|----------|---------|---------|
| ProfileVerifier | Profile registration check | TRAILHEAD |
| PresenceVerifier | Days registered threshold | Milestone claims |
| InteractionVerifier | Contract interaction count | EXPLORER |
| ReferralVerifier | Referral tracking | GUIDE |
| ApprovalVerifier | Token approval checks | PREPARED |
| SignatureVerifier | EIP-712 signature storage | RESOLUTE |
| IdentityVerifier | Social identity linking | IDENTIFIED |
| AggregateVerifier | Multi-achievement check | CHAPTER_COMPLETE |

---

## Education System

### Education Track

A self-paced learning pathway covering a specific domain of protocol knowledge. Unlike chapters (time-bound cohort experiences), tracks are wallet-based and independent of calendar time.

| Property | Description |
|----------|-------------|
| Progression | Self-paced, user-driven |
| Persistence | localStorage (wallet-based) |
| Completion | Graduation upon all lessons complete |

**Tracks:**
| ID | Focus | Lessons |
|----|-------|---------|
| bitcoin-fundamentals | BTC thesis, SMA research | 6 |
| protocol-mechanics | Vault lifecycle, withdrawals | 7 |
| defi-foundations | AMM, LP, lending basics | 7 |
| advanced-protocol | vestedBTC, delegation | 6 |
| security-risk | Immutability, audits | 5 |
| explorer-operations | Direct contract interaction | 5 |

### Track Lesson

A discrete educational unit within a track containing content sections, a quiz, and optional practical exercises.

| Component | Purpose |
|-----------|---------|
| Sections | Educational content (text, visuals) |
| Quiz | Knowledge verification (100% required) |
| Practical Exercise | On-chain or calculation verification |

### Track Progress

Wallet-scoped record of lesson completion within a track. Stored in localStorage.

| Field | Description |
|-------|-------------|
| trackId | Track identifier |
| completedLessons | Array of completed lesson IDs |
| graduated | Boolean (all lessons complete) |

### Track Graduation

Completion status achieved when all lessons in a track are finished. Indicates mastery of that knowledge domain.

| Requirement | Description |
|-------------|-------------|
| Quiz Pass | 100% correct on all lesson quizzes |
| All Lessons | Every lesson in track completed |

**Graduation Standards by Track:**
| Track | Standard |
|-------|----------|
| Bitcoin Fundamentals | Articulate 1129-day thesis |
| Protocol Mechanics | Execute withdrawal via explorer |
| DeFi Foundations | Evaluate positions independently |
| Advanced Protocol | Use all protocol features |
| Security & Risk | Evaluate protocol risk profile |
| Explorer Operations | Operate protocol without UI |

### Practical Exercise

Optional hands-on verification within a lesson requiring on-chain interaction or calculation.

| Type | Description |
|------|-------------|
| onchain | Execute transaction, verify event |
| explorer | Read contract state |
| calculation | Perform manual calculation |

### Two-Layer Education Architecture

The separation of cohort identity (chapters) from knowledge building (tracks).

| Layer | Purpose | Timing |
|-------|---------|--------|
| Chapters | Cohort identity, achievement NFTs | Time-bound (90 days) |
| Tracks | Knowledge building, graduation | Self-paced |

**Key distinction:** Completing a track lesson does NOT unlock an achievement. Achievements require on-chain actions during chapter windows. Tracks provide knowledge to perform those actions effectively.
