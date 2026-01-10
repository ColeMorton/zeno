# BTCNFT Protocol: A Comprehensive Guide

> **Version:** 1.0
> **Status:** Final
> **Last Updated:** 2026-01-05

---

## Table of Contents

1. [Introduction: What BTCNFT Protocol Is](#1-introduction-what-btcnft-protocol-is)
2. [The Core Thesis: Why It Works](#2-the-core-thesis-why-it-works)
3. [Protocol Architecture Overview](#3-protocol-architecture-overview)
4. [The Vault Lifecycle](#4-the-vault-lifecycle)
5. [vestedBTC: The Composability Layer](#5-vestedbtc-the-composability-layer)
6. [Dormancy Protection](#6-dormancy-protection)
7. [Withdrawal Delegation](#7-withdrawal-delegation)
8. [For Vault Holders](#8-for-vault-holders)
9. [For Issuers](#9-for-issuers)
10. [For DeFi Integrators](#10-for-defi-integrators)
11. [For Developers](#11-for-developers)
12. [For Market Participants](#12-for-market-participants)
13. [For Institutional and Treasury Managers](#13-for-institutional-and-treasury-managers)
14. [When to Use the Protocol: Decision Framework](#14-when-to-use-the-protocol-decision-framework)
15. [Example Scenarios with Real Numbers](#15-example-scenarios-with-real-numbers)
16. [Exit Strategy Matrix](#16-exit-strategy-matrix)
17. [Summary: Protocol Value Proposition](#17-summary-protocol-value-proposition)
18. [Risk Summary and Disclaimers](#18-risk-summary-and-disclaimers)

---

## Part I: Foundation

### 1. Introduction: What BTCNFT Protocol Is

Bitcoin presents a paradox. It is simultaneously the hardest money ever created and one of the most volatile major asset classes. Monthly swings of ±30% are routine. Bear markets deliver 70-80% drawdowns. Bull markets produce 300-900% gains. This volatility makes Bitcoin unsuitable for retirement planning, fixed-income replacement, or stable yield generation—the very use cases where hard money should excel.

BTCNFT Protocol resolves this paradox through a single insight: **time is the only trust-free smoothing mechanism.**

The protocol is an immutable smart contract system that transforms Bitcoin's volatility into perpetual income. It accomplishes this through two mechanisms:

1. **1129-day vesting period**: A commitment window calibrated to Bitcoin's historical price cycles
2. **1.0% monthly withdrawals**: A sustainable extraction rate that never depletes principal

The result: a financial primitive that has demonstrated 100% positive returns across all historical rolling windows while requiring zero oracles, zero governance, and zero admin keys.

**Key Differentiators:**

| Property | BTCNFT Protocol | Traditional DeFi |
|----------|-----------------|------------------|
| Custody | Self-custodial (Vault NFT) | Pool-based |
| Upgradeability | Immutable (no admin keys) | Upgradeable proxies |
| Liquidation Risk | None | Collateral-based |
| Oracle Dependency | None | Price feeds required |
| Governance | None (core parameters) | Token voting |

The protocol does not promise returns. It provides access to a mathematical property of Bitcoin that has historically never failed: the 1129-day simple moving average has never declined in any recorded window.

**The Deal in Plain Terms:**

Lock your Bitcoin and an NFT for approximately three years. After that waiting period, withdraw 1% of your remaining Bitcoin every month, forever. Your Bitcoin principal never fully depletes because each withdrawal is percentage-based, not fixed. Meanwhile, if others quit early, their forfeited Bitcoin gets distributed to you as a bonus.

No company holds your Bitcoin. No governance can change the rules. No oracle feeds prices. The contract is immutable—what deploys is what runs forever.

### 2. The Core Thesis: Why It Works

The 1129-day vesting period is not arbitrary. It emerges from quantitative analysis of Bitcoin's price history.

**The Observation:**

The Bitcoin 1129-day Simple Moving Average (SMA) has demonstrated 100% positive returns across all historical windows from 2017 to 2025. Across 1,837 rolling daily samples, not a single window produced a negative return.

**The Mathematics:**

The SMA formula smooths daily price volatility:

```
SMA_1129(t) = (1/1129) × Σ[i=0 to 1128] Price(t-i)
```

Each day's price movement impacts the average by approximately 0.089% (1/1129). For the SMA to decline over a 30-day period, cumulative negative impact must exceed all positive contributions—a condition that Bitcoin's long-term positive drift has historically prevented.

**Historical Validation:**

| Window | Samples | Mean Return | Minimum | Maximum |
|--------|---------|-------------|---------|---------|
| Monthly | 96 | +4.61% | +0.18% | +35.54% |
| Yearly | 2,565 | +63.11% | +14.75% | +346.81% |
| 1129-Day | 1,837 | +313.07% | +77.78% | +902.96% |

The minimum 1129-day return of +77.78% provides substantial margin above the 12% annual withdrawal rate.

**Calibration Logic:**

| Metric | Value |
|--------|-------|
| Mean annual appreciation | +63.11% |
| Withdrawal rate | -12.00% |
| Structural surplus | +51.11% |

The breakeven threshold requires Bitcoin to appreciate 12% annually to maintain USD value. Historical data shows even the worst-performing window (+14.75% yearly minimum) exceeded this threshold.

**The Transformation:**

```
Input:  High-volatility speculative asset (BTC)
Process: 1129-day commitment + percentage-based extraction
Output: Historically-validated perpetual income stream
```

The protocol does not track an SMA index or require oracle feeds. It uses time itself as the averaging mechanism. A holder who deposits at time `t` and waits 1129 days has effectively "averaged" their entry across an entire market cycle.

**Understanding the Sensitivity Analysis:**

What happens if future Bitcoin returns fall below historical averages?

| Scenario | Yearly Return | After 12% Withdrawal | Net USD Change |
|----------|---------------|---------------------|----------------|
| Historical mean | +63.11% | -12% | +51.11% |
| 50% of mean | +31.6% | -12% | +19.6% |
| 25% of mean | +15.8% | -12% | +3.8% |
| Breakeven | +12% | -12% | 0% |
| Below breakeven | <+12% | -12% | Negative |

The breakeven point—where USD value remains constant—requires Bitcoin to appreciate 12% annually. Below this threshold, USD value decreases even as BTC-denominated withdrawals continue. Historical data shows the worst-performing yearly window still exceeded this threshold (+14.75%), but past performance does not guarantee future results.

**The Philosophical Foundation:**

The protocol embodies Zeno's paradox as financial design. The withdrawal mechanism—1.0% of remaining collateral—mathematically never reaches zero. This creates a philosophical inversion: instead of "how much can I extract?", the question becomes "how long can I sustain?"

The vesting period functions as a commitment device:
- Early exit carries forfeiture penalty
- Forfeited collateral rewards patient holders
- Patience becomes economically optimal

This game-theoretic equilibrium aligns individual incentives with protocol health.

### 3. Protocol Architecture Overview

The protocol employs a two-layer architecture that separates immutable infrastructure from customizable experiences.

**Layer 1: Protocol (Immutable Core)**

The protocol layer consists of contracts deployed once with parameters embedded in bytecode. No upgrade mechanism exists. No admin functions exist. The code that deploys is the code that runs forever.

Core contracts:
- **VaultNFT**: ERC-998 composable NFT holding Treasure + BTC collateral
- **BtcToken**: ERC-20 vestedBTC representing separated collateral claims
- **VaultMath**: Library containing all calculations with immutable constants

**Layer 2: Issuer (Customizable Templates)**

The issuer layer provides reusable templates that issuers deploy independently. Issuers control entry requirements, Treasure design, and minting campaigns—but cannot modify core protocol parameters.

Issuer contracts include:
- **TreasureNFT**: ERC-721 issuer-branded NFTs
- **AchievementNFT**: ERC-5192 soulbound achievement tokens
- **VaultMintController**: Atomic minting orchestration
- **AuctionController**: Dutch and English auction mechanisms

**Token Standards:**

| Token | Standard | Fungibility | Purpose |
|-------|----------|-------------|---------|
| Vault NFT | ERC-998 | Non-fungible | Primary asset, holds collateral |
| Treasure NFT | ERC-721 | Non-fungible | Identity/art within Vault |
| vestedBTC | ERC-20 | Fungible | Separated collateral claim |

**Multi-Deployment Architecture:**

Each BTC collateral type (wBTC, cbBTC, tBTC) receives independent deployments with:
- Separate VaultNFT contracts
- Separate vestedBTC variants (vWBTC, vCBBTC, vTBTC)
- Isolated match pools
- Independent risk profiles

This isolation ensures that custody risk in one wrapped BTC variant does not contaminate others.

---

## Part II: Mechanism Deep Dive

### 4. The Vault Lifecycle

#### 4.1 Minting

Creating a Vault requires two inputs:
1. **Treasure NFT**: Any ERC-721 token eligible for the issuer's program
2. **BTC Collateral**: wBTC, cbBTC, or tBTC in the supported denomination

The minting process:
1. Approve Treasure NFT transfer to protocol
2. Approve BTC collateral transfer to protocol
3. Call `mint()` function
4. Receive Vault NFT containing both assets

The collateral is not pooled with other users. It remains isolated within your specific Vault, identified by token ID. Only you can access it.

#### 4.2 Vesting Period: Days 0-1129

The vesting period spans 1129 days (approximately 3.09 years). During this window:

- **No withdrawals permitted**: The `withdraw()` function reverts
- **Vault remains transferable**: Sell on secondary markets if needed
- **Achievements available**: Claim duration milestones (30 days, 91 days, 182 days, 365 days, 730 days)

**Early Redemption Option:**

Holders requiring liquidity before vesting can invoke early redemption with linear unlock:

```
returned = collateral × (elapsed_days / 1129)
forfeited = collateral - returned
```

Example at day 565 (50% through vesting):
- Collateral: 1.0 BTC
- Returned: 0.5 BTC (50%)
- Forfeited: 0.5 BTC (to match pool)
- Treasure NFT: Burned (permanent loss)

The forfeit penalty creates a strong incentive to complete vesting.

#### 4.3 Post-Vesting: Perpetual Withdrawals

After day 1129, withdrawals become available with the following mechanics:

**Rate:** 1.0% of remaining collateral per 30-day period

**Formula:**
```
withdrawal = remainingCollateral × 0.01
```

**Frequency:** Once per 30 days (cumulative, not forced)

**Zeno's Paradox Property:**

The percentage-based formula ensures collateral never fully depletes:

| Period | Remaining | Withdrawn | Cumulative Withdrawn |
|--------|-----------|-----------|---------------------|
| Month 1 | 0.9900 BTC | 0.0100 BTC | 0.0100 BTC |
| Month 2 | 0.9801 BTC | 0.0099 BTC | 0.0199 BTC |
| Month 3 | 0.9703 BTC | 0.0098 BTC | 0.0297 BTC |
| Year 1 | 0.8864 BTC | - | 0.1136 BTC |
| Year 10 | 0.3010 BTC | - | 0.6990 BTC |
| Year 100 | 0.0000006 BTC | - | 0.9999994 BTC |

Mathematically: `remaining = initial × (0.99)^n` where n = number of 30-day periods.

#### 4.4 Match Pool Mechanics

Early redemptions forfeit collateral to a shared pool distributed among remaining holders.

**Source:** Forfeited collateral from all early redemptions

**Distribution Formula:**
```
matchShare = matchPool × (holderCollateral / totalActiveCollateral)
```

**Example:**
- Total match pool: 10 BTC (from early redeemers)
- Your collateral: 1 BTC
- Total active collateral: 100 BTC
- Your match share: 10 × (1/100) = 0.1 BTC bonus

**Flywheel Effect:**

More early redemptions increase the match pool, creating greater rewards for patient holders. This game-theoretic dynamic aligns incentives: patience is economically optimal.

**Claim Timing:** Match claims become available post-vesting via `claimMatch(tokenId)`.

### 5. vestedBTC: The Composability Layer

#### 5.1 Separation Mechanics

Post-vesting, holders can convert collateral into fungible ERC-20 tokens:

**Process:** Call `mintVestedBTC(vaultTokenId)`

**Result:** Receive vestedBTC tokens equal to your collateral amount (1:1 at separation)

**What You Retain:**
- Vault NFT ownership
- Treasure NFT (remains in Vault)
- Withdrawal rights (unchanged)

**What You Forfeit:**
- Direct redemption rights (until recombined)
- Match pool claims require vestedBTC

**Recombination:**

Restoring full Vault rights requires returning the exact original vestedBTC amount:

```solidity
returnVestedBTC(vaultTokenId, amount) // amount must equal original
```

This is all-or-nothing. Partial recombination is not supported.

#### 5.2 Rights Comparison

| Right | Vault (no vBTC) | Vault (vBTC exists) | vBTC Holder |
|-------|-----------------|---------------------|-------------|
| Monthly Withdrawals | Yes | Yes | No |
| Treasure Ownership | Yes | Yes | No |
| Full Redemption | Yes | Requires vBTC | No |
| Transfer | Yes (NFT) | Yes (NFT) | Yes (fungible) |
| Collateral Claim | Implicit | Via vBTC | Yes |
| Match Pool Claim | Yes | Requires vBTC | No |

#### 5.3 Value Proposition

vestedBTC trades at a structural discount to underlying BTC due to:

1. **Shrinking collateral**: 1% monthly withdrawal impact
2. **No direct withdrawal rights**: Holder cannot extract BTC
3. **Redemption friction**: Requires Vault recombination

**Expected Trading Range:** 0.70-0.95 of underlying BTC value

**Use Cases:**

| Goal | Strategy |
|------|----------|
| Liquidity access | Sell vestedBTC on DEX, continue withdrawing from Vault |
| DeFi collateral | Deposit vestedBTC in lending protocols |
| Yield stacking | LP vestedBTC in Curve pools + keep withdrawals |
| Partial exit | Sell portion of vestedBTC, retain rest |

### 6. Dormancy Protection

#### 6.1 The Problem

A critical edge case exists when:
1. Holder separates vestedBTC from Vault
2. Holder sells vestedBTC to third party
3. Holder loses access to wallet or abandons position

Result: The BTC collateral becomes inaccessible. The Vault holder cannot redeem (lacks vestedBTC). The vestedBTC holder cannot access collateral (lacks Vault). The BTC is permanently locked.

#### 6.2 The Solution

The dormancy mechanism provides a recovery path for abandoned positions.

**Dormancy Criteria (all must be true):**
1. vestedBTC has been separated from Vault
2. Current Vault owner does not hold required vestedBTC
3. No Vault activity for 1129+ days

**Recovery Process:**

| Step | Action | Duration |
|------|--------|----------|
| 1 | Anyone calls `pokeDormant(tokenId)` | Instant |
| 2 | Grace period for owner response | 30 days |
| 3 | vestedBTC holder calls `claimDormantCollateral(tokenId)` | After grace |

**Outcomes:**

| Party | Result |
|-------|--------|
| vestedBTC Holder | Burns vestedBTC, receives BTC collateral |
| Original Vault Owner | Loses Vault NFT and Treasure (burned) |
| Vault NFT | Burned (empty shell) |

**Prevention:**

Interact with your Vault at least once every 1129 days:
- Execute a withdrawal
- Transfer the Vault
- Call `proveActivity(tokenId)`

Any of these actions resets the dormancy timer.

### 7. Withdrawal Delegation

#### 7.1 Purpose

Delegation enables third-party withdrawals without transferring Vault custody. Use cases include:

- **Automation**: Grant to a bot for monthly DCA
- **Treasury management**: DAO operations key for expenses
- **Estate planning**: Pre-authorize beneficiaries

#### 7.2 Two-Level System

**Wallet-Level Delegation:**

A single grant covering all Vaults owned by a wallet.

```solidity
grantWithdrawalDelegate(delegate, percentageBPS)
```

- Applies to current and future Vaults
- Does not expire automatically
- Revocable at any time

**Vault-Level Delegation:**

Granular control for specific Vaults with optional expiry.

```solidity
grantVaultDelegate(tokenId, delegate, percentageBPS, durationSeconds)
```

- Applies to single Vault only
- Optional `expiresAt` timestamp
- Takes precedence over wallet-level

**Resolution Priority:** Vault-specific > Wallet-level > None

**Percentage Allocation Example:**

```
Vault: 1 BTC collateral, post-vesting
Monthly withdrawal pool: 0.01 BTC (1%)

Delegation:
- Delegate A: 60% (6000 BPS) → 0.006 BTC
- Delegate B: 40% (4000 BPS) → 0.004 BTC
- Owner retains: 0% (delegates take full withdrawal)
```

Each delegate has an independent 30-day cooldown per Vault.

---

## Part III: Stakeholder Value Propositions

### 8. For Vault Holders

**The Proposition:**

Convert Bitcoin's volatility from liability to asset. Lock capital for 1129 days, then withdraw 12% annually forever. Earn bonus BTC from others' impatience via the match pool.

**Decision Framework:**

| Your Situation | Recommended Action |
|----------------|-------------------|
| Long-term BTC conviction (3+ years) | Mint Vault |
| Need liquidity within 3 years | Consider alternatives |
| Want passive income from BTC | Hold through vesting, automate withdrawals |
| Want maximum DeFi flexibility | Separate vestedBTC post-vesting |
| Uncertain about commitment | Start with smaller position |

**Example: Conservative Holder**

Profile: 1 BTC, long-term hold
- Day 0: Mint Vault with 1 BTC
- Day 1129: Vesting complete, withdrawals begin
- Year 4: Withdraw ~0.12 BTC ($12,000 at $100K/BTC)
- Bonus: Claim 0.03 BTC from match pool (early redeemer forfeitures)
- Year 10: ~0.30 BTC remaining, ~0.73 BTC withdrawn total

**Example: Active DeFi User**

Profile: 1 BTC, yield optimization
- Day 1129: Separate 0.95 BTC as vestedBTC (after withdrawals)
- Strategy: LP vestedBTC/WBTC in Curve pool
- Returns: 12% withdrawals + 5-10% LP rewards
- Flexibility: Sell vestedBTC for liquidity, continue withdrawals

**Risk Acknowledgment:**

- **BTC price risk**: Collateral is BTC-denominated; USD value fluctuates
- **Early exit penalty**: Linear forfeit to match pool
- **Smart contract risk**: Audited but not guaranteed
- **No liquidation risk**: Position persists regardless of price

**Understanding the Trust Model:**

What you trust:
- Immutable smart contract code (audited, open source)
- Ethereum network consensus
- Your own private key security

What you do not need to trust:
- Any company, team, or organization
- Oracle price feeds
- Governance decisions
- Custodians (for protocol layer)
- Counterparties

The protocol cannot be paused, upgraded, or modified. This immutability is not a policy—it is a technical impossibility enforced by the absence of any admin functions in the deployed bytecode.

**Long-Term Holder Projection:**

A detailed projection for a 1 BTC Vault over 20 years (assuming constant $100K/BTC for illustration):

| Year | BTC Remaining | BTC Withdrawn That Year | Cumulative BTC Withdrawn | Cumulative USD |
|------|---------------|------------------------|-------------------------|----------------|
| 4 | 0.886 | 0.114 | 0.114 | $11,400 |
| 5 | 0.787 | 0.099 | 0.213 | $21,300 |
| 6 | 0.698 | 0.089 | 0.302 | $30,200 |
| 7 | 0.619 | 0.079 | 0.381 | $38,100 |
| 8 | 0.550 | 0.069 | 0.450 | $45,000 |
| 9 | 0.488 | 0.062 | 0.512 | $51,200 |
| 10 | 0.433 | 0.055 | 0.567 | $56,700 |
| 15 | 0.235 | - | 0.765 | $76,500 |
| 20 | 0.128 | - | 0.872 | $87,200 |

After 20 years: 87.2% of original BTC withdrawn, 12.8% remains for continued withdrawals.

### 9. For Issuers

**What Issuers Can Do:**

| Capability | Description |
|------------|-------------|
| Entry requirements | Open minting or badge-gated access |
| Treasure design | Custom art, metadata, editions |
| Minting windows | Campaign timing, coordinated releases |
| Auction mechanisms | Dutch (descending) or English (ascending) |
| Achievement extensions | Custom milestone definitions |
| Gamification | Leaderboards, tiers, progression |

**What Issuers Cannot Do:**

| Constraint | Reason |
|------------|--------|
| Modify withdrawal rate | Immutable in bytecode |
| Change vesting period | Immutable in bytecode |
| Access user collateral | No extraction function exists |
| Cancel executed mints | State is final |
| Upgrade protocol contracts | No upgrade mechanism |

**Revenue Models:**

The protocol extracts zero fees from minting or withdrawals. Issuer revenue sources:

| Source | Model |
|--------|-------|
| Premium services | Analytics, automation, reporting |
| Membership tiers | Subscription access levels |
| Partner integrations | DeFi protocol revenue shares |
| LP fee capture | Protocol-owned liquidity trading fees |

**Integration Patterns:**

| Auction Type | Mechanism | Best For |
|--------------|-----------|----------|
| Dutch | Descending price over time | Fair distribution, price discovery |
| English | Ascending bids with extension | Maximum extraction, competitive |
| Instant | Fixed price, first-come | Simple UX, known cost |

**Operational Costs (L2):**

| Operation | Gas Cost |
|-----------|----------|
| Vault mint | ~$0.15-0.50 |
| Withdrawal | ~$0.05-0.15 |
| Delegate grant | ~$0.04-0.12 |

**Recommended Initial Liquidity:** 10-50 BTC equivalent per Curve pool for adequate depth.

### 10. For DeFi Integrators

**vestedBTC Properties:**

| Property | Value |
|----------|-------|
| Standard | ERC-20 |
| Decimals | 8 (matches wBTC) |
| Backing | 1:1 with Vault collateral at separation |
| Negative carry | -12% annually (collateral shrinks from withdrawals) |

**Integration Stack:**

**Layer 2 - Liquidity (Curve CryptoSwap V2):**
- Pool: vWBTC/WBTC
- A parameter: 50-100 (non-pegged volatile pair)
- Expected price range: 0.50-0.95
- Impermanent loss: Minimized via profit-offset rule (~2% at 25% discount)

**Layer 3 - Lending (CDP Markets):**
- Base rate requirement: >14% APR (exceeds 12% drainage)
- Dynamic LTV scaling:

| Discount | vBTC/wBTC | Max LTV |
|----------|-----------|---------|
| 5% | 0.95 | 75% |
| 15% | 0.85 | 55% |
| 25% | 0.75 | 35% |

- Liquidation: Dutch auction (0-15% bonus over 60 minutes)

**Layer 4 - Yield (Convex/Yearn):**
- Auto-compound LP positions
- Boosted CRV rewards via gauge voting
- Performance fees: 10% (no management fee)

**Critical Parameters:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Negative carry | -1.0%/month | Must be priced into lending rates |
| Lending floor rate | 14%+ APR | Prevents arbitrage vs withdrawal |
| LTV scaling | Dynamic | Wider discount = more buffer required |

**Yield Stacking Example:**

A sophisticated DeFi user combining multiple yield sources:

```
Base Vault: 1 BTC
├── Zeno Withdrawals: 12% annually (0.12 BTC/year)
│
└── Separated: 0.9 vBTC
    └── Curve LP: vBTC/wBTC
        ├── Trading fees: 3% APY
        ├── CRV rewards: 5% APY
        └── CVX boost: 3% APY

Total yield on 1 BTC position:
- From Vault: 12% (on full BTC)
- From LP: ~11% × 0.9 = 9.9% (on vBTC portion)
- Gross: ~22% (before negative carry)
- Net: ~22% - 12% vBTC drainage = ~10% real yield
```

Note: The vBTC LP position experiences -12% drainage, which must be factored into total returns. However, you continue withdrawing from the Vault regardless of what happens to the vBTC.

**Flash Loan Integration:**

vestedBTC supports standard ERC-20 flash loans via Balancer V2:

```solidity
// Flash loan vBTC for arbitrage
flashLoan(
    recipient: address(this),
    tokens: [vBTC],
    amounts: [1e8], // 1 vBTC
    userData: abi.encode(...)
)
```

Use cases:
- Liquidation bots for vBTC lending markets
- Arbitrage between vBTC/wBTC pools
- One-transaction leverage positions

### 11. For Developers

**Contract Architecture:**

```
contracts/protocol/
├── src/
│   ├── VaultNFT.sol         # ERC-998 composable vault
│   ├── BtcToken.sol         # ERC-20 vestedBTC
│   ├── HybridVaultNFT.sol   # Dual-collateral variant
│   └── libraries/
│       └── VaultMath.sol    # Immutable calculations
└── interfaces/
    ├── IVaultNFT.sol
    ├── IBtcToken.sol
    └── IVaultNFTDelegation.sol
```

**Key Immutable Constants:**

```solidity
// contracts/protocol/src/libraries/VaultMath.sol
uint256 internal constant VESTING_PERIOD = 1129 days;
uint256 internal constant WITHDRAWAL_PERIOD = 30 days;
uint256 internal constant WITHDRAWAL_RATE = 1000;  // 1.0% = 1000/100000
uint256 internal constant BASIS_POINTS = 100000;
uint256 internal constant DORMANCY_THRESHOLD = 1129 days;
uint256 internal constant GRACE_PERIOD = 30 days;
```

**Critical Functions:**

| Function | Access | Purpose |
|----------|--------|---------|
| `mint(treasure, tokenId, collateral, amount)` | Public | Create Vault |
| `withdraw(tokenId)` | Owner | Extract 1% monthly |
| `withdrawAsDelegate(tokenId)` | Delegate | Extract delegate share |
| `mintVestedBTC(tokenId)` | Owner | Separate collateral |
| `returnVestedBTC(tokenId, amount)` | Owner | Recombine (all-or-nothing) |
| `claimMatch(tokenId)` | Owner | Claim match pool share |
| `pokeDormant(tokenId)` | Public | Initiate dormancy |
| `claimDormantCollateral(tokenId)` | vBTC Holder | Recover dormant collateral |

**Events for Indexing:**

```solidity
event VaultMinted(uint256 indexed tokenId, address indexed owner, address treasureContract, uint256 treasureTokenId, uint256 collateral);
event Withdrawal(uint256 indexed tokenId, uint256 amount, uint256 remaining);
event VestedBTCMinted(uint256 indexed tokenId, address indexed holder, uint256 amount);
event MatchClaimed(uint256 indexed tokenId, uint256 amount);
event DormantPoked(uint256 indexed tokenId, address owner, address poker, uint256 deadline);
event DormantClaimed(uint256 indexed tokenId, address indexed claimer, uint256 collateral);
```

### 12. For Market Participants

Secondary markets emerge for both Vault NFTs and vestedBTC, creating opportunities for traders, arbitrageurs, and liquidity providers.

**Vault NFT Secondary Market:**

Vault NFTs trade as standard ERC-998 tokens on NFT marketplaces. Key pricing factors:

| Factor | Impact on Price |
|--------|-----------------|
| Collateral amount | Direct correlation |
| Time to vesting | Premium for closer-to-vested |
| Match pool eligibility | Higher if claims available |
| Treasure rarity | Depends on issuer market |
| Delegation status | Discount if heavily delegated |

**Arbitrage Opportunities:**

| Scenario | Mechanism | Risk |
|----------|-----------|------|
| vBTC discount exceeds early redemption penalty | Buy vBTC, recombine, redeem | Requires Vault ownership |
| Vault underpriced vs collateral | Buy Vault, wait/withdraw | Time risk, market risk |
| vBTC premium (rare) | Separate and sell | Lose redemption rights |

**Liquidity Provision:**

Curve pools for vestedBTC/wBTC pairs offer:
- Trading fees: 0.04% per swap
- CRV gauge rewards (if approved)
- Minimal impermanent loss (correlated assets)

**Expected LP Returns:**
| Source | Range |
|--------|-------|
| Base swap fees | 2-5% APY |
| CRV emissions | 3-8% APY |
| CVX boost | 2-4% APY |
| **Total** | **7-17% APY** |

Note: vestedBTC LP positions face the same -12% negative carry as direct holdings when the LP contains significant vestedBTC weight.

**Market Making Considerations:**

vestedBTC presents unique market making challenges:
- Negative carry (-1%/month) requires factoring into bid-ask spreads
- Illiquidity during vesting periods (no new supply until vesting)
- Price discovery complicated by varying Vault ages

Professional market makers should model vestedBTC as a declining-balance asset with known drainage rate.

### 13. For Institutional and Treasury Managers

**Delegation Patterns:**

**Multi-Sig Treasury:**
```
Vault ownership: 3-of-5 multi-sig
Wallet-level delegation:
  - Operations key: 50% (daily expenses)
  - Grants committee: 30% (ecosystem funding)
  - Emergency reserve: 20% (held by multi-sig)
```

**Family Office:**
```
Vault ownership: Parent wallet
Vault-level delegation per Vault:
  - Child A: 33% (expires: 18th birthday)
  - Child B: 33% (expires: 18th birthday)
  - Child C: 34% (expires: 18th birthday)
```

**Automation Integration:**

| Component | Implementation |
|-----------|----------------|
| Account abstraction | ERC-4337 smart accounts |
| Session keys | Scoped to `withdrawAsDelegate()` |
| Execution | Gelato Web3 Functions (monthly cron) |
| Gas costs | ~$0.60-0.90 per vault per year |

**Compliance Considerations:**

| Aspect | Treatment |
|--------|-----------|
| Withdrawals | Return of capital, not profit distribution |
| Custody | Self-custodial, no third-party risk |
| Audit trail | All operations on-chain, verifiable |
| Reporting | Event logs provide complete history |

---

## Part IV: Practical Application

### 14. When to Use the Protocol: Decision Framework

**Use Cases by Goal:**

| Goal | Strategy | Protocol Feature |
|------|----------|------------------|
| Perpetual BTC income | Hold Vault, withdraw monthly | 1.0%/month withdrawals |
| Liquidity access | Separate vestedBTC, sell on DEX | vestedBTC composability |
| Estate planning | Delegate to beneficiaries | Wallet/vault delegation |
| Treasury management | DAO holds Vaults, delegates to ops | Multi-party delegation |
| Yield stacking | LP vestedBTC + keep withdrawals | Separation + DeFi |
| Long-term savings | Hold through vesting, claim match | Match pool rewards |

**Not Suitable For:**

| Situation | Reason |
|-----------|--------|
| Short-term trading | 1129-day vesting lock |
| Immediate liquidity needs | Early redemption penalty |
| Risk-averse capital only | BTC price exposure remains |
| Oracle-dependent strategies | No price feeds |
| Yield farming (emissions) | No token incentives |

**Comparative Analysis:**

| vs. Alternative | BTCNFT Advantage | BTCNFT Disadvantage |
|-----------------|------------------|---------------------|
| BTC HODL | Generates yield (12%/year) | 3-year lock before access |
| CDP stablecoins | No liquidation risk | Lower capital efficiency |
| LP farming | Sustainable (BTC-backed) | Lower APY than incentivized |
| MSTR preferred | Non-custodial, on-chain | Less liquid secondary |
| Treasury bonds | Inflation hedge (BTC) | Higher volatility |

### 15. Example Scenarios with Real Numbers

**Scenario 1: Individual Retirement Planning**

Profile: Age 35, 10 BTC, 30-year horizon

Strategy:
- Mint 10 Vaults (1 BTC each) for diversification
- Hold through vesting (3.09 years)
- Begin withdrawals at age 38

Projection (assuming $100,000/BTC constant for illustration):

| Year | Age | Remaining BTC | Annual Withdrawal | Cumulative |
|------|-----|---------------|-------------------|------------|
| 4 | 38 | 8.86 | 1.14 BTC ($114K) | 1.14 BTC |
| 10 | 44 | 3.01 | 0.36 BTC ($36K) | 6.99 BTC |
| 20 | 54 | 0.91 | 0.11 BTC ($11K) | 9.09 BTC |
| 30 | 64 | 0.27 | 0.03 BTC ($3K) | 9.73 BTC |

Match pool bonus (assuming 5% of total TVL forfeited): +0.5 BTC

Note: BTC appreciation historically exceeds 12%/year, potentially increasing USD values significantly.

**Scenario 2: DAO Treasury Management**

Profile: Protocol DAO with 100 BTC treasury

Structure:
- 20 Vaults (5 BTC each) for granular control
- Wallet-level delegation split:
  - Operations: 50% (ongoing expenses)
  - Grants: 30% (ecosystem funding)
  - Reserve: 20% (emergency, multi-sig held)

Monthly Distribution (post-vesting):
- Total pool: 1 BTC (1% of 100 BTC)
- Operations: 0.5 BTC
- Grants: 0.3 BTC
- Reserve: 0.2 BTC (accumulates in multi-sig)

**Scenario 3: DeFi Protocol Integration**

Profile: Lending protocol seeking BTC collateral

Integration:
- Accept vestedBTC as collateral asset
- Set base interest rate: 15% APR (exceeds 12% drainage)
- Implement dynamic LTV based on discount level
- Dutch auction liquidations (0-15% over 60 minutes)

Risk Parameters:
| Discount | Price | LTV | Liquidation Threshold |
|----------|-------|-----|----------------------|
| 5% | 0.95 | 75% | 80% |
| 15% | 0.85 | 55% | 60% |
| 25% | 0.75 | 35% | 40% |

**Scenario 4: Issuer Personal Brand Launch**

Profile: Content creator with 10K engaged followers

Launch Strategy:
- Design 1,000-edition Treasure collection
- Dutch auction: 0.1 BTC start, 0.05 BTC floor, 7-day duration
- Estimated participation: 500 Vaults, 50 BTC total TVL
- Seed liquidity: 5 BTC to vWBTC/WBTC Curve pool

Revenue Model (zero from minting):
- Premium analytics subscription: $20/month × 200 subscribers = $4K/month
- Automation service: $10/month × 300 users = $3K/month
- Partner integrations: Revenue share agreements

### 16. Exit Strategy Matrix

**All Exit Options:**

| Strategy | Timing | Cost | Outcome |
|----------|--------|------|---------|
| Hold perpetual | Infinite | Gas only | Withdraw forever |
| Early redemption | Anytime | Linear forfeit + Treasure loss | Partial BTC return |
| Sell Vault NFT | Immediate | Market spread | Full exit, buyer assumes position |
| Sell vestedBTC | Post-vesting | DEX slippage (5-30%) | Principal access, keep withdrawals |
| Recombine + redeem | Post-vesting | Gas only | Full BTC return |
| Claim dormant | 30+ days after poke | vestedBTC burned | Recover abandoned collateral |

**Decision Tree:**

```
Need to Exit?
│
├─ Immediate Need
│  ├─ Before Vesting → Early Redeem (accept forfeit) or Sell Vault NFT
│  └─ After Vesting → Sell vestedBTC (keep withdrawals) or Sell Vault NFT
│
├─ No Immediate Need
│  ├─ Want Income → Hold, withdraw monthly
│  ├─ Want Principal → Recombine + Redeem (requires all vBTC)
│  └─ Want Both → Partial vestedBTC sale + continue withdrawals
│
└─ Holding vestedBTC (no Vault)
   └─ Monitor dormant positions → Claim if eligible
```

**Exit Calculations:**

**Early Redemption at Day 565 (50% vested):**
- Collateral: 1.0 BTC
- Return: 0.5 BTC (50% of collateral)
- Forfeit: 0.5 BTC (to match pool)
- Treasure: Burned
- Net: 0.5 BTC, lost Treasure permanently

**vestedBTC Sale at 15% Discount:**
- Vault: 1 BTC collateral, post-vesting
- Separate: Receive 1 vBTC
- Sell: 0.85 BTC equivalent per vBTC
- Keep: Vault with 12%/year withdrawals
- Payback: ~7 years of withdrawals to recover discount loss

---

## Part V: Conclusion

### 17. Summary: Protocol Value Proposition

**For Vault Holders:**

Transform Bitcoin from speculative holding to income-generating asset. The 1129-day commitment aligns with Bitcoin's historical price cycles, smoothing volatility through time rather than financial engineering. Post-vesting, extract 12% annually forever while your principal persists indefinitely. Early redeemers fund your match pool bonus. Non-custodial, non-liquidatable, permissionless.

**For Issuers:**

Build on immutable infrastructure without inheriting upgrade risk or governance overhead. Control the holder experience (entry, art, campaigns) while the protocol handles collateral safety. Generate revenue through services, not extraction. Your reputation and brand drive adoption; the protocol handles the trust layer.

**For DeFi Integrators:**

A new BTC-backed primitive enters the ecosystem. vestedBTC's structural discount and negative carry create unique dynamics for lending, liquidity provision, and structured products. Integrate with CDP markets requiring >14% APR floors. Build yield strategies that compound Zeno withdrawals with LP rewards.

**For Developers:**

Minimal, audited contract surface. No governance attack vector. Deterministic calculations from on-chain state. All parameters embedded in bytecode, eliminating runtime configuration risk. ERC-998/721/20 standards ensure broad compatibility.

**For Institutional Managers:**

Delegation enables treasury patterns without custody transfer. ERC-4337 automation reduces operational overhead. Complete on-chain audit trail for compliance. Non-custodial structure eliminates counterparty risk.

**For Market Participants:**

Secondary markets for Vault NFTs and vestedBTC provide liquidity for those needing exit before natural withdrawal cycles. Arbitrage opportunities exist when price dislocations occur between Vault intrinsic value and market price. Liquidity provision in Curve pools generates sustainable yield from correlated-asset trading. Professional market makers must account for vestedBTC's -12% negative carry in their pricing models.

**The Core Innovation:**

Time is the only averaging mechanism requiring no external input. A 1129-day commitment period, combined with a 12% annual withdrawal rate calibrated to conservative BTC appreciation, creates a financial primitive that has never existed: a trustless, self-custodied instrument backed by Bitcoin that has demonstrated positive returns across all historical windows.

**Why This Matters:**

Traditional financial instruments require trust in institutions, counterparties, or governance systems. BTCNFT Protocol requires trust only in:
1. Mathematics (Zeno's paradox, historical statistics)
2. Code (audited, immutable, open source)
3. Bitcoin (hardest money ever created)

The protocol does not promise returns. It provides access to a mathematical property that has historically never failed. Whether that property continues to hold is a bet on Bitcoin's long-term trajectory—a bet that every participant in the protocol is explicitly making.

### 18. Risk Summary and Disclaimers

**Acknowledged Risks:**

| Risk Category | Description |
|---------------|-------------|
| BTC price | Collateral is BTC-denominated; extended bear markets reduce USD value |
| Sample period | Historical analysis (2017-2025) may not represent future conditions |
| Smart contract | Audited but bugs can exist; no upgrades possible to fix |
| Regulatory | Not captured in price data or protocol design |
| Custody (wrapped BTC) | wBTC/cbBTC have custodian dependencies |

**What the Protocol Does NOT Guarantee:**

- USD value preservation (historical patterns, not forward guarantee)
- Specific returns (12% withdrawal rate is maximum extraction, not yield promise)
- Future BTC appreciation (past performance not indicative)
- Protection from regulatory action
- Recovery from smart contract exploits

**User Responsibilities:**

1. Understand the 1129-day commitment before depositing
2. Accept BTC price exposure as inherent to the instrument
3. Conduct independent research and due diligence
4. Consult financial and legal advisors for personal situation
5. Only commit capital you can lock for 3+ years
6. Maintain wallet security (private keys, hardware wallet)
7. Interact with Vault at least once every 3 years to prevent dormancy

**Historical Context for Risk Assessment:**

Individual calendar years have shown significant variation:

| Year | BTC Return | Would 12% Withdrawal Preserve USD Value? |
|------|------------|------------------------------------------|
| 2018 | -73% | No |
| 2019 | +95% | Yes |
| 2020 | +303% | Yes |
| 2021 | +60% | Yes |
| 2022 | -64% | No |
| 2023 | +155% | Yes |
| 2024 | +121% | Yes |

The 1129-day vesting period is specifically designed to smooth across these yearly variations. A holder who enters at the worst possible moment (peak of 2021) would still experience the recovery through 2023-2024 before withdrawals begin.

However, this historical pattern does not guarantee future outcomes. Extended bear markets exceeding 3 years, fundamental changes to Bitcoin's adoption trajectory, or black swan events not captured in historical data could all impact the protocol's effectiveness.

**What Happens in Worst-Case Scenarios:**

| Scenario | Protocol Behavior | User Outcome |
|----------|------------------|--------------|
| BTC drops 80% | Vault continues normally | USD value of withdrawals reduced |
| BTC goes to zero | Vault becomes worthless | Total loss (same as holding BTC) |
| Smart contract exploit | No recovery possible | Potential total loss |
| Wallet compromise | Attacker gains Vault | User loses position |
| Network failure | Vaults inaccessible | Temporary or permanent loss |

The protocol does not protect against BTC price decline—it only transforms the access pattern. If you believe Bitcoin will fail long-term, this protocol is not for you.

**The Immutability Promise:**

The protocol's core parameters are embedded in contract bytecode using Solidity's `constant` keyword. No upgrade mechanism exists. No admin functions exist. No governance can modify the 1129-day vesting period, the 1.0% monthly withdrawal rate, or any other core parameter.

This is not a policy decision—it is a technical impossibility.

What deploys is what runs. Forever.

**Final Considerations:**

Before participating, ask yourself:
- Do I have a 3+ year time horizon for this capital?
- Do I understand that BTC price exposure remains throughout?
- Am I comfortable with smart contract risk despite audits?
- Have I secured my private keys properly?
- Do I accept that historical patterns may not repeat?

If the answer to any of these is "no," reconsider participation. The protocol is designed for long-term Bitcoin believers who want to transform their holdings into a perpetual income stream without counterparty risk.

For those who proceed: the mathematics, the game theory, and the historical data all align toward a single conclusion—patience is rewarded, and time smooths what volatility creates.

---

> **Disclaimer:** This document is for informational purposes only and does not constitute financial, legal, or investment advice. Historical performance does not guarantee future results. Users should conduct their own research and consult appropriate advisors before participating in the protocol.
