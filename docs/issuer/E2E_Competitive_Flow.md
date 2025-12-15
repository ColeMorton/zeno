# BTCNFT Protocol E2E Competitive Flow

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-12
> **Related Documents:**
> - [Product Specification](../protocol/Product_Specification.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Market Analysis](./Market_Analysis.md)

---

## Table of Contents

1. [Capital Formation Comparison](#1-capital-formation-comparison)
2. [User Journey: Investor Perspective](#2-user-journey-investor-perspective)
3. [User Journey: Withdrawal Recipient](#3-user-journey-withdrawal-recipient)
4. [Capital Flow Diagrams](#4-capital-flow-diagrams)
5. [DeFi Composability Layer](#5-defi-composability-layer)
6. [Olympus-Style Bonding Mechanism](#6-olympus-style-bonding-mechanism)
7. [Risk Comparison Matrix](#7-risk-comparison-matrix)
8. [Operational Mechanics](#8-operational-mechanics)
9. [Scale Comparison](#9-scale-comparison)
10. [Dormant NFT Recovery Flow](#10-dormant-nft-recovery-flow)

---

## 1. Capital Formation Comparison

### Strategy (MicroStrategy) Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    STRATEGY CAPITAL FLOW                        │
│                                                                 │
│  Investor USD                                                   │
│       ↓                                                         │
│  NYSE/Nasdaq Purchase (STRC/STRK/STRF)                         │
│       ↓                                                         │
│  Strategy Inc. Corporate Treasury                               │
│       ↓                                                         │
│  BTC Purchase (via OTC/Exchange)                               │
│       ↓                                                         │
│  Corporate Balance Sheet                                        │
│       ↓                                                         │
│  Dividend Distribution (quarterly)                              │
│       ↓                                                         │
│  Investor USD (taxed as dividend income)                       │
└─────────────────────────────────────────────────────────────────┘
```

**Overhead:**
- SEC registration costs
- Underwriter fees (2-7%)
- Corporate structure maintenance
- Quarterly reporting requirements
- Custody fees (institutional)
- Legal/compliance costs

### BTCNFT Protocol Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    BTCNFT PROTOCOL CAPITAL FLOW                 │
│                                                                 │
│  Investor USD                                                   │
│       ↓                                                         │
│  CEX → WBTC (or cbBTC)                                         │
│       ↓                                                         │
│  Approve + Mint Vault NFT                                       │
│       ↓                                                         │
│  Smart Contract (100% to collateral)                           │
│       ↓                                                         │
│  Post-Vesting: withdraw() every 30 days                        │
│       ↓                                                         │
│  BTC directly to wallet (taxed as property disposition)        │
└─────────────────────────────────────────────────────────────────┘
```

**Overhead:**
- Gas costs only (~$5-50 per transaction)
- No intermediaries
- No corporate structure
- Real-time transparency

### Capital Efficiency Comparison

| Metric | Strategy (STRC) | BTCNFT Protocol |
|--------|-----------------|---------|
| Capital to BTC | ~93-98% (after fees) | ~100% (minus gas) |
| Time to deployment | Days-weeks (settlement) | Minutes (on-chain) |
| Reporting overhead | Quarterly SEC filings | Real-time on-chain |
| Custodial layer | Coinbase Custody (corporate) | Non-custodial |

---

## 2. User Journey: Investor Perspective

### Entry Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    INVESTOR ENTRY FLOW                          │
│                                                                 │
│  Step 1: Acquire BTC Collateral                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Option A: CEX → WBTC withdraw to wallet                │   │
│  │  Option B: DEX swap ETH → WBTC                          │   │
│  │  Option C: Bridge BTC → WBTC (RenBridge, WBTC.cafe)     │   │
│  │  Option D: Coinbase → cbBTC (native)                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 2: Acquire Treasure                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Option A: Mint from partner collection                 │   │
│  │  Option B: Purchase on OpenSea/Blur                     │   │
│  │  Option C: Use existing NFT from wallet                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 3: Mint Vault NFT                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  1. Approve Treasure transfer                           │   │
│  │  2. Approve WBTC/cbBTC transfer                         │   │
│  │  3. Select withdrawal tier (Conservative/Balanced/Aggressive)│
│  │  4. Call mint() → Receive ERC-998 Vault NFT             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 4: Vesting Period (1093 days)                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  - No withdrawals permitted                             │   │
│  │  - NFT transferable (secondary market)                  │   │
│  │  - Optional: mintBtcToken() for collateral separation   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

Note: "Vault your Treasure" means depositing your ERC-721 NFT into the Vault NFT (ERC-998).
```

### Tier Selection Decision Tree

```
                    ┌─────────────────────┐
                    │  Investment Goal?   │
                    └─────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ↓                   ↓                   ↓
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │ Max Stability│    │  Balanced   │    │Max Withdrawal│
   │   (100%)    │    │   (100%)    │    │   (100%*)   │
   └─────────────┘    └─────────────┘    └─────────────┘
          ↓                   ↓                   ↓
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │Conservative │    │  Balanced   │    │ Aggressive  │
   │ 0.833%/mo   │    │  1.14%/mo   │    │  1.59%/mo   │
   │ 10.5%/yr    │    │  14.6%/yr   │    │  20.8%/yr   │
   └─────────────┘    └─────────────┘    └─────────────┘

   * Aggressive tier: 100% stability on 1093-day window only
```

---

## 3. User Journey: Withdrawal Recipient

### Post-Vesting Withdrawal Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    WITHDRAWAL FLOW                              │
│                                                                 │
│  Day 1094+ (Post-Vesting)                                      │
│       ↓                                                         │
│  Call withdraw(tokenId)                                         │
│       ↓                                                         │
│  Contract calculates: remainingCollateral × tierRate           │
│       ↓                                                         │
│  BTC transferred to holder wallet                              │
│       ↓                                                         │
│  30-day cooldown begins                                        │
│       ↓                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Holder Options:                                        │   │
│  │  A) Hold BTC (long-term appreciation)                   │   │
│  │  B) Sell BTC → USD (realize gains)                      │   │
│  │  C) Compound: Mint new Vault NFT                        │   │
│  │  D) Use in DeFi (Aave, LP, etc.)                        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Tax Treatment Comparison

| Event | Strategy (STRC) | BTCNFT Protocol |
|-------|-----------------|---------|
| Withdrawal Receipt | Dividend income (ordinary) | Transfer of own property |
| Subsequent Sale | N/A (already USD) | Capital gains on BTC |
| Holding Period | N/A | Long-term if held >1 year |
| Tax Efficiency | N/A | No taxable event at withdrawal |

---

## 4. Capital Flow Diagrams

### Strategy Model (Centralized)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│    Investors              Strategy Inc.           BTC Markets   │
│    ┌──────┐              ┌───────────┐           ┌──────────┐  │
│    │ USD  │──IPO/ATM────►│ Treasury  │───OTC────►│   BTC    │  │
│    │      │              │           │           │          │  │
│    │      │◄──Dividend───│           │◄──Custody─│          │  │
│    └──────┘              └───────────┘           └──────────┘  │
│                                │                               │
│                         SEC Reporting                          │
│                         Board Governance                       │
│                         Audit Requirements                     │
│                                                                 │
│    Trust Chain: Investor → Strategy Inc. → Custodian           │
└─────────────────────────────────────────────────────────────────┘
```

### BTCNFT Protocol Model (Decentralized)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│    Investors              Smart Contract          BTC (WBTC)    │
│    ┌──────┐              ┌───────────┐           ┌──────────┐  │
│    │ WBTC │───mint()────►│  ERC-998  │◄──locked──│ Collateral│  │
│    │      │              │  Vault    │           │          │  │
│    │      │◄──withdraw()─│   NFT     │───────────│          │  │
│    └──────┘              └───────────┘           └──────────┘  │
│                                │                               │
│                         Immutable Code                         │
│                         On-chain Audit                         │
│                         Real-time Transparency                 │
│                                                                 │
│    Trust Chain: Investor → Smart Contract (audited)            │
└─────────────────────────────────────────────────────────────────┘
```

### vBTC Secondary Market Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 vBTC SECONDARY MARKET                           │
│                                                                 │
│  Vault Holder                                                   │
│       │                                                         │
│       ├──► mintBtcToken() ──► vBTC (ERC-20)                    │
│       │                              │                          │
│       │    (Withdrawal rights retained)│                        │
│       │                              ↓                          │
│       │                    ┌─────────────────────┐              │
│       │                    │  DEX (Uniswap/Curve)│              │
│       │                    │  vBTC/USDC LP  │              │
│       │                    └─────────────────────┘              │
│       │                              │                          │
│       │                    ┌─────────┴─────────┐                │
│       │                    ↓                   ↓                │
│       │           ┌──────────────┐    ┌──────────────┐          │
│       │           │  Trade for   │    │  Use as      │          │
│       │           │  USDC/ETH    │    │  Collateral  │          │
│       │           └──────────────┘    │  (Aave)      │          │
│       │                               └──────────────┘          │
│       │                                                         │
│       └──► withdraw() ──► BTC withdrawal (perpetual)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. DeFi Composability Layer

### vBTC Integration Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    DeFi COMPOSABILITY                           │
│                                                                 │
│  Layer 1: Base Asset                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  vBTC (ERC-20) - Conservative-tier btcToken        │   │
│  │  Properties: BTC-denominated, 100% historical yearly    │   │
│  │              stability (not a USD peg)                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Layer 2: Liquidity                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Uniswap V3: vBTC/USDC concentrated liquidity      │   │
│  │  Curve: vBTC/USDC stable swap                      │   │
│  │  Balancer: vBTC/WBTC/USDC weighted pool            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Layer 3: Lending                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Aave: vBTC as collateral (borrow USDC/ETH)        │   │
│  │  Compound: vBTC market                             │   │
│  │  Morpho: Optimized vBTC lending                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Layer 4: Yield Strategies                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Yearn: vBTC vault auto-compound                   │   │
│  │  Convex: Boosted Curve vBTC LP                     │   │
│  │  Pendle: vBTC yield tokenization                   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Withdrawal Stacking Example

```
Base: Vault NFT (Conservative tier)
├─ BTC Withdrawals: 10.5% annually
│
Separation: mintBtcToken() → vBTC
├─ Retain: Withdrawal rights (10.5%)
├─ vBTC → Curve LP → Convex boost
│   └─ LP fees: ~2-5% APY
│   └─ CRV rewards: ~3-8% APY
│   └─ CVX boost: ~2-4% APY
│
Total Stack: 10.5% + 7-17% = 17.5-27.5% APY
```

---

## 6. Olympus-Style Bonding Mechanism

### Protocol-Owned Liquidity (POL)

Olympus DAO pioneered POL through bonding:
- Users sell LP tokens to protocol at discount
- Protocol owns liquidity permanently
- LP fees flow to treasury (not mercenary LPs)

### vBTC Bonding Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    vBTC BONDING                            │
│                                                                 │
│  Step 1: User Provides Liquidity                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  vBTC + USDC → Uniswap/Curve → LP Tokens           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 2: User Bonds LP                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Call bond(lpTokenAmount)                               │   │
│  │  Protocol quotes: 5-15% discount, 5-7 day vesting       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 3: Protocol Receives LP                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LP tokens → Protocol Treasury                          │   │
│  │  Protocol earns all trading fees                        │   │
│  │  Liquidity is permanent (no mercenary flight)           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 4: User Receives Discounted Position                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  After vesting: Claim Vault NFT (pre-funded with BTC)   │   │
│  │  Effective entry: 5-15% below market                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Bond Pricing (Sequential Dutch Auction)

| Parameter | Value |
|-----------|-------|
| **Discount Range** | 5-15% below market |
| **Vesting Period** | 5-7 days |
| **Capacity** | Limited by treasury BTC reserves |
| **Price Discovery** | Market-driven (no oracle) |

### Why This Works for vBTC (vs OHM's Issues)

| Factor | OHM (Failed) | vBTC (Robust) |
|--------|--------------|-------------------|
| **Backing** | Reflexive (OHM backs OHM) | Non-reflexive (actual BTC) |
| **Intrinsic Value** | Protocol-dependent | BTC market price |
| **Death Spiral Risk** | High (circular) | Low (BTC floor) |
| **Withdrawal Source** | Emissions (dilutive) | Own collateral (non-dilutive) |

### Protocol Revenue Model

```
Revenue Sources:
├─ vBTC/USDC LP Fees (0.3% per trade)
├─ vBTC/ETH LP Fees (0.3% per trade)
└─ Treasury BTC Appreciation (~63% annually historical)

Note: Early redemption forfeitures flow to Collateral Matching Pool (not treasury).
See: ../protocol/Collateral_Matching.md

Revenue Uses:
├─ Fund discounted bond emissions (sustainable)
├─ Range-Bound Stability operations (price defense)
├─ Protocol development (grants)
└─ DAO governance distributions (if applicable)
```

---

## 7. Risk Comparison Matrix

| Risk Category | Strategy (STRC) | BTCNFT Protocol (vBTC) |
|---------------|-----------------|---------------------|
| **Counterparty** | Strategy Inc. solvency | Smart contract only |
| **Smart Contract** | N/A | Audit risk (mitigated by formal verification) |
| **Regulatory** | SEC-registered (compliant) | DeFi primitive (regulatory uncertainty) |
| **Liquidity** | NYSE depth | DEX depth (protocol-owned via bonding) |
| **Custody** | Coinbase (institutional) | Non-custodial (user responsibility) |
| **Operational** | Corporate governance | Immutable code |
| **Key Person** | Michael Saylor dependency | No key person |
| **BTC Price** | Indirect (balance sheet) | Direct (1:1 collateral) |

### Risk Severity Assessment

```
                    Low Risk ◄─────────────────────► High Risk

Counterparty:
  Strategy:     ████████░░░░░░░░░░░░ (Corporate solvency)
  BTCNFT:       ██░░░░░░░░░░░░░░░░░░ (Smart contract only)

Regulatory:
  Strategy:     ██░░░░░░░░░░░░░░░░░░ (SEC-registered)
  BTCNFT:       ████████████░░░░░░░░ (DeFi uncertainty)

Liquidity:
  Strategy:     ██░░░░░░░░░░░░░░░░░░ (NYSE)
  BTCNFT:       ████████░░░░░░░░░░░░ (DEX, mitigated by POL)

Smart Contract:
  Strategy:     ░░░░░░░░░░░░░░░░░░░░ (N/A)
  BTCNFT:       ██████░░░░░░░░░░░░░░ (Audit mitigated)
```

---

## 8. Operational Mechanics

### Gas Cost Analysis (Ethereum Mainnet)

| Operation | Gas Units | Cost @ 30 gwei | Cost @ 100 gwei |
|-----------|-----------|----------------|-----------------|
| Mint Parent NFT | ~250,000 | ~$15 | ~$50 |
| Withdraw BTC | ~80,000 | ~$5 | ~$16 |
| mintBtcToken | ~120,000 | ~$7 | ~$24 |
| Bond LP | ~150,000 | ~$9 | ~$30 |

### L2 Deployment Consideration

| Chain | Gas Reduction | Trade-off |
|-------|---------------|-----------|
| Arbitrum | 90%+ | Security assumptions |
| Base | 90%+ | Coinbase ecosystem |
| Optimism | 90%+ | OP token incentives |

### Withdrawal Automation

```
┌─────────────────────────────────────────────────────────────────┐
│                    WITHDRAWAL AUTOMATION                        │
│                                                                 │
│  Option A: Manual                                              │
│  └─ Holder calls withdraw() every 30 days                      │
│                                                                 │
│  Option B: Gelato Automation                                   │
│  └─ Automated transaction execution                            │
│  └─ Pay gas in ETH or task-specific token                      │
│                                                                 │
│  Option C: Account Abstraction (ERC-4337)                      │
│  └─ Scheduled withdrawals via smart account                    │
│  └─ Gas sponsorship options                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Scale Comparison

### Strategy: Corporate Structure

| Metric | Value |
|--------|-------|
| STRC IPO | $2.521 billion |
| Corporate overhead | ~2-5% annually |
| Regulatory compliance | ~$10M+ annually (estimate) |
| Scalability | Limited by SEC filings |
| Geographic reach | US-centric (accredited investors) |

### BTCNFT Protocol: Permissionless Protocol

| Metric | Value |
|--------|-------|
| Protocol overhead | Near-zero (gas only) |
| Regulatory compliance | N/A (DeFi primitive) |
| Scalability | Infinite (smart contract) |
| Geographic reach | Global, permissionless |
| Minimum investment | Any amount (fractional) |

### TVL Projection Model

```
Assumptions:
├─ Target: 1% of STRC market ($25M equivalent)
├─ Average position: 0.1 BTC (~$10,000)
├─ Bonding discount: 10%
├─ LP fees: 0.3% per trade

Year 1 Projection:
├─ Positions minted: 2,500
├─ TVL: $25M in BTC collateral
├─ Protocol-owned LP: $5M (from bonding)
├─ Annual LP fees: ~$150K (at $50M volume)
└─ Treasury growth: Fees + BTC appreciation
```

---

## Exit Strategy Matrix

| Strategy | Mechanism | Time | Cost |
|----------|-----------|------|------|
| **Hold Perpetual** | Withdraw forever (Zeno) | Infinite | Gas only |
| **Early Redemption** | Linear unlock | Any time | Forfeiture penalty |
| **Sell Vault NFT** | Secondary market | Immediate | Market spread |
| **Sell vBTC** | DEX trade | Immediate | Slippage + gas |
| **Sell btcToken, Keep Withdrawals** | DEX trade | Immediate | Principal only |
| **Claim Dormant Collateral** | Burn vBTC to claim abandoned BTC | 30+ days | vBTC burned |

---

## 10. Dormant NFT Recovery Flow

### Problem: Permanently Locked BTC

When a Vault holder separates vBTC and sells it, then becomes inactive, BTC can become permanently inaccessible:

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOCKED BTC SCENARIO                          │
│                                                                 │
│  Original Owner               vBTC Holder                       │
│  ┌──────────────┐            ┌──────────────┐                  │
│  │ Vault NFT    │            │  vBTC        │                  │
│  │ (no vBTC)    │            │  (no Vault)  │                  │
│  │              │            │              │                  │
│  │ ✗ Can't      │            │ ✗ Can't      │                  │
│  │   redeem     │            │   recombine  │                  │
│  │ (lacks vBTC) │            │ (lacks Vault)│                  │
│  └──────────────┘            └──────────────┘                  │
│                                                                 │
│  If owner inactive for 3+ years → BTC locked forever           │
└─────────────────────────────────────────────────────────────────┘
```

### Solution: Dormant Claim Mechanism

vBTC holders can claim abandoned Vaults through a poke-and-claim process:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DORMANT CLAIM FLOW                           │
│                                                                 │
│  Step 1: Detect Dormant Vault                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Requirements for dormant-eligible:                     │   │
│  │  ✓ vBTC minted from Vault                               │   │
│  │  ✓ vBTC NOT at owner's wallet                           │   │
│  │  ✓ No activity for 1093+ days                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 2: Poke                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Anyone calls pokeDormant(tokenId)                      │   │
│  │  → Starts 30-day grace period                          │   │
│  │  → Owner notified via on-chain event                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 3: Grace Period (30 days)                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Owner Options:                                         │   │
│  │  A) proveActivity() → NFT returns to ACTIVE             │   │
│  │  B) Do nothing → NFT becomes CLAIMABLE                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 4: Claim (if owner didn't respond)                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  vBTC holder calls claimDormantCollateral(tokenId) │   │
│  │  → Burns vBTC (original minted amount)                  │   │
│  │  → Receives BTC collateral directly                     │   │
│  │  → Treasure returned to original owner                  │   │
│  │  → Vault NFT burned (empty shell)                       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Outcome Distribution

| Party | Receives | Rationale |
|-------|----------|-----------|
| **Claimer** | BTC collateral | Burned equivalent vBTC value |
| **Original Owner** | Treasure (returned) | Original property preserved |
| **Vault NFT** | Burned | Empty shell - no value after extraction |
| **vBTC** | Permanently burned | Economic equivalence maintained |

### Comparison: Standard Recombination vs Dormant Claim

| Aspect | Standard Recombination | Dormant Claim |
|--------|------------------------|---------------|
| **Requirement** | Own both Vault + vBTC | Own vBTC only |
| **Target** | Your own Vault | Abandoned Vault |
| **Process** | returnBtcToken() | pokeDormant() → wait → claimDormantCollateral() |
| **Time** | Immediate | 30+ days (grace period) |
| **Treasure** | Stays stored | Extracted to original owner |
| **Vault NFT** | Redemption rights restored | Burned (no value) |
| **Claimer receives** | Redemption rights | BTC collateral directly |

### vBTC Holder Opportunity

For vBTC holders seeking to recover BTC:

```
┌─────────────────────────────────────────────────────────────────┐
│                 vBTC → BTC RECOVERY                             │
│                                                                 │
│  Current: vBTC (fungible, no withdrawals)                      │
│       ↓                                                         │
│  Scan for dormant-eligible Vaults                               │
│       ↓                                                         │
│  Poke → Wait 30 days → Claim                                   │
│       ↓                                                         │
│  Result: BTC collateral (direct ownership)                     │
│                                                                 │
│  Trade-off:                                                     │
│  ├─ Give up: Fungible vBTC (claim on future BTC)               │
│  └─ Receive: Actual BTC collateral (immediate ownership)       │
└─────────────────────────────────────────────────────────────────┘
```
