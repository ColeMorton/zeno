# BTCNFT Protocol Glossary

> **Version:** 1.2
> **Status:** Final
> **Last Updated:** 2025-12-30

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
