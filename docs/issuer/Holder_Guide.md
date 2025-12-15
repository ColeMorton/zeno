# BTCNFT Protocol Holder Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-12
> **Related Documents:**
> - [Product Specification](../protocol/Product_Specification.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [DAO Design](./DAO_Design.md)

---

## TL;DR - The Deal

**Lock BTC + NFT for 3 years. Get perpetual withdrawals forever. Earn bonus BTC from quitters.**

- **Deposit:** Your NFT + BTC collateral
- **Vesting:** 1093 days (~3 years) - no withdrawals
- **Post-vesting:** Withdraw a percentage of your BTC every 30 days, forever
- **Collateral matching:** Early quitters forfeit BTC that gets distributed to holders who stay
- **Achievements:** Earn NFT badges for holding milestones
- **No governance token:** NFTs only, no speculation

| Monthly Withdrawal | Annual Withdrawal | Historical Yearly Stability |
|--------------------|-------------------|----------------------------|
| 0.833% | 10.5% | 100% (2017-2025 data) |

**Why 100% historical stability?** The withdrawal rate is designed around historical BTC performance. BTC has appreciated ~63%/year on average. You withdraw 10.5%/year. The math: historically, your collateral's USD value holds or grows even while you're taking withdrawals.

> **Important:** This is historical analysis, not a guarantee. vBTC is BTC-denominated (not pegged to USD). Past performance does not guarantee future results.

---

## Why 3 Years?

The 1093-day vesting exists because it works.

**Historical BTC performance (2014-2024):**
- 100% of 1093-day holding windows showed positive returns
- Mean return: +313%
- Minimum return: +78%

This covers a full market cycle (bull + bear). The vesting period is what enables the stability guarantee - shorter periods have volatility, longer periods don't.

**The trade-off:** You're exchanging liquidity for certainty. Every historical 3-year BTC hold has been profitable.

| Time Window | Stability Coverage |
|-------------|-------------------|
| Monthly | 92% |
| Yearly | 100% |
| 1093-Day | 100% |

---

## What You Get

### Phase 1: Mint (Day 0)

- Vault any ERC-721 NFT (your "Treasure")
- Deposit BTC (WBTC or cbBTC)
- Receive your Vault NFT (ERC-998 Composable)

### Phase 2: Vesting (Days 1-1093)

**No withdrawals** during this period. But you're not idle:

**Achievements you can earn:**
| Achievement | Requirement |
|-------------|-------------|
| First Month | Hold 30 days |
| Quarter Stack | Hold 91 days |
| Half Year | Hold 182 days |
| Annual | Hold 365 days |
| Diamond Hands | Hold 730 days |
| Hodler Supreme | Hold 1093 days |

Achievement NFTs are transferable and can be used as Treasures for future positions.

### Phase 3: Maturity (Day 1093)

Three things unlock:

1. **Withdrawals:** Start taking 0.833%/month of your BTC
2. **Collateral matching:** Claim your share of forfeited BTC from early quitters
3. **vBTC:** Extract your collateral as liquid vBTC while keeping your Vault and withdrawal rights (see dedicated section below)

### Phase 4: Perpetual (Day 1093+)

Withdraw 0.833% of your remaining BTC every 30 days. Forever.

The math: Because it's percentage-based, your collateral never fully depletes. Even after 100 years, you'd retain ~6.7% of your original BTC.

---

## Collateral Matching: How It Works

When someone exits their NFT early, they forfeit a portion of their BTC. That forfeited BTC goes into a pool distributed to holders who complete the full vesting.

**Formula:**
```
Your bonus = matchPool x (yourCollateral / totalActiveCollateral)
```

**Example:**

```
Day 0:   Alice mints with 1.0 BTC
         Bob mints with 0.5 BTC
         totalActiveCollateral = 1.5 BTC

Day 912: Dave mints 0.5 BTC, then redeems after 365 days held
         Dave gets back:  0.167 BTC (33.4%)
         Dave forfeits:   0.333 BTC -> matchPool

Day 1093: Alice vests and claims
          Alice's share: 0.333 x (1.0 / 1.5) = 0.222 BTC bonus
          Alice's total: 1.0 + 0.222 = 1.222 BTC
```

**Key insight:** The later you enter, the more potential collateral matching from earlier quitters. The longer you hold, the larger your share of the pool.

---

## vBTC: Extract Liquidity, Keep Your Withdrawal Rights

After maturity, you can separate your BTC collateral into **vBTC** (ERC-20) while keeping your Vault and withdrawal rights.

**What you keep:**
- Vault NFT (your position)
- Treasure (your art)
- Withdrawal rights (keep withdrawing 0.833%/month)

**What you get:**
- vBTC tokens (1:1 with your BTC collateral)
- Fully liquid, tradeable on DEXs
- Usable as collateral in Aave, Compound
- Can provide liquidity in vBTC/USDC pools

**Why vBTC?** It's BTC-denominated (not pegged to USD). The name refers to historical stability patterns where 100% of yearly+ holding periods maintained USD value. Your vBTC represents a claim on BTC collateral that historically holds its USD value even as the underlying BTC is withdrawn. Past performance does not guarantee future results.

**The trade-off:** To redeem your Vault and reclaim underlying collateral, you must return the full vBTC amount. This is all-or-nothing - you can't return partial vBTC.

**Use cases:**
| Goal | Action |
|------|--------|
| Need cash now | Sell vBTC on DEX, keep withdrawal rights |
| Leverage | Deposit vBTC in Aave, borrow against it |
| Earn LP fees | Provide vBTC/USDC liquidity |
| Exit completely | Return vBTC, redeem Vault, get BTC back |

---

## Avoiding Dormancy: Protect Your Position

If you separate your vBTC and sell it (or lose access to it), AND you become inactive for 1093+ days, your Vault becomes vulnerable to being claimed by vBTC holders.

### What is Dormancy?

Your Vault becomes **dormant-eligible** when ALL of these are true:
1. You've minted vBTC from your Vault
2. You no longer hold sufficient vBTC at the same wallet
3. You haven't interacted with your Vault for 1093+ days

### The Claim Process

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  You become     │────►│  Anyone can     │────►│  You have 30    │
│  dormant-       │     │  "poke" your    │     │  days to        │
│  eligible       │     │  Vault          │     │  respond        │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                        If you respond:                  │   If you don't:
                        ┌───────────────┐                ▼
                        │ Back to normal│       ┌─────────────────┐
                        │ - Vault safe  │       │ vBTC holder     │
                        └───────────────┘       │ can claim your  │
                                                │ collateral      │
                                                └─────────────────┘
```

### What Happens If Your Collateral Is Claimed?

| You receive | You lose |
|-------------|----------|
| Your Treasure (returned to you) | BTC collateral |

| What happens | Result |
|--------------|--------|
| Your BTC collateral | Transferred to claimer |
| Your Treasure | Returned to you |
| Your Vault NFT | Burned (empty shell) |
| Claimer's vBTC | Burned |

The claimer burns vBTC equal to your original minted amount and receives the BTC collateral directly. Your Vault NFT is burned (it has no value without collateral or Treasure).

### How to Stay Safe

**Activities that reset your dormancy clock:**
| Action | Resets Timer? |
|--------|---------------|
| Withdraw BTC | ✅ Yes |
| Transfer your Vault | ✅ Yes |
| Mint/return vBTC | ✅ Yes |
| Claim collateral matching | ✅ Yes |
| Call `proveActivity()` | ✅ Yes |

**Recommendation:** If you've sold your vBTC, make sure to interact with your Vault at least once every 3 years. A simple withdrawal is enough.

### If You Get Poked

1. **Don't panic** - You have 30 days to respond
2. **Call `proveActivity()`** on your Vault
3. Your Vault returns to ACTIVE state immediately
4. The poke is cleared; you're safe

---

## Risks and Exit Options

### Risks

| Risk | Severity | Reality |
|------|----------|---------|
| **BTC price crash** | Real | Your collateral is BTC. It can go down. Historical 1093-day analysis shows 100% positive returns, but past performance ≠ future results. |
| **Smart contract** | Real | Code is audited, but bugs can exist. This is non-custodial - your keys, your responsibility. |
| **Early exit penalty** | Real | Leave before 1093 days = forfeit a portion of your BTC. |
| **Liquidation** | None | Unlike CDPs, you cannot be liquidated. Your position is yours regardless of BTC price. |

### Early Exit (Redemption)

You can redeem your NFT anytime, but you forfeit a portion based on time held:

| Days Held | Returned | Forfeited |
|-----------|----------|-----------|
| 0 | 0% | 100% |
| 182 (~6 mo) | 16.7% | 83.3% |
| 365 (~1 yr) | 33.4% | 66.6% |
| 547 (~18 mo) | 50% | 50% |
| 730 (~2 yr) | 66.8% | 33.2% |
| 912 (~2.5 yr) | 83.4% | 16.6% |
| 1093 (~3 yr) | 100% | 0% |

**Warning:** Early redemption permanently destroys both your Vault NFT AND your stored Treasure. Your Treasure is gone forever.

---

## How It Compares

### vs Strategy (STRC/STRK/STRF)

| | BTCNFT Protocol | Strategy Preferred |
|-|---------|-------------------|
| BTC backing | Direct (1:1) | Indirect (corporate balance sheet) |
| Counterparty | Smart contract only | Corporate credit risk |
| Liquidity | DEX 24/7 | NYSE market hours |
| Accessibility | Global, permissionless | Regulated markets |
| Custody | Non-custodial | Brokerage |

### vs Holding BTC

| | BTCNFT Protocol | Just hold BTC |
|-|---------|---------------|
| Withdrawals | 10.5% annually | None |
| Discipline | Forced HODL (3yr vest) | Easy to panic sell |
| Collateral matching | Pool from quitters | None |
| Liquidity | Locked (or penalty) | Instant |

### vs DeFi Staking/Farming

| | BTCNFT Protocol | DeFi Staking |
|-|---------|--------------|
| Duration | Perpetual (post-vest) | Epoch-based |
| IL Risk | None | Often present |
| Complexity | One-time mint | Constant management |
| Withdrawal source | Your own collateral | Protocol emissions |

---

## FAQ

### Safety

**Is this a rug?**
No. The smart contract is immutable. Your BTC collateral is yours - the contract cannot take it. There's no team wallet that can drain funds.

**What if the team disappears?**
The code runs without team intervention. Vesting, withdrawals, and match claims are all on-chain and permissionless.

**Who controls the DAO?**
A multisig council (3-of-5 or 5-of-7). They control achievements, campaigns, and gamification - NOT your collateral, NOT withdrawal rates.

### Mechanics

**Do I have to withdraw every month?**
No. Withdrawals accumulate. Withdraw when you want.

**What if I need my BTC early?**
You can redeem anytime, but you forfeit a portion (see early exit schedule above).

**Can I sell my position?**
Yes. The Vault NFT is transferable. Sell it on any NFT marketplace.

### Returns

**What's the annual withdrawal rate?**
10.5% annually, plus potential collateral matching allocation from the pool.

**Is this sustainable?**
Yes. The withdrawals come from your own collateral (percentage-based). There's no "yield from nowhere" - you're withdrawing a portion of your BTC each month, and historically BTC appreciation has more than offset the withdrawals.

**What about taxes?**
Withdrawals represent a transfer of your own property from the smart contract to your wallet. You are not exchanging assets, receiving profit, or paying fees - you're simply retrieving your own BTC collateral.

In general:
- Withdrawals are a transfer of your own property, not an exchange
- No exchange or profit event occurs at the time of withdrawal
- Tax treatment varies by jurisdiction - consult a qualified tax professional
- The BTC remains your property throughout; the smart contract holds it non-custodially

**This is not tax advice.** You are responsible for understanding and complying with tax obligations in your jurisdiction.

### Dormancy

**Can someone steal my collateral?**
Only if you abandon it. To become dormant-eligible you must: (1) have sold your vBTC, AND (2) not interacted with your Vault for 1093+ days. Even then, you get a 30-day grace period to respond before anyone can claim.

**What if I lose access to my wallet?**
If you've separated vBTC and can't access your wallet for 3+ years, your collateral could become claimable. This is by design - it prevents BTC from being permanently locked in abandoned positions.

**I sold my vBTC - am I at risk?**
Only if you go completely inactive for 3+ years. To stay safe, just withdraw BTC, transfer the Vault, or call `proveActivity()` at least once every 3 years.

**What do I get back if my collateral is claimed?**
Your Treasure is returned to your wallet. The claimer gets the BTC collateral directly (not the Vault). Your Vault NFT is burned since it's now empty. This is fair because you already received value when you sold the vBTC.

**Can I claim dormant collateral myself?**
Yes! If you hold vBTC and find a dormant-eligible Vault, you can poke it, wait 30 days (if owner doesn't respond), then claim the BTC collateral by burning your vBTC.

---

## Quick Start

1. **Get BTC:** Acquire WBTC or cbBTC from a CEX or DEX
2. **Get Treasure:** Any ERC-721 works - mint one, buy one, or use existing
3. **Connect wallet:** Go to [dapp URL]
4. **Approve transfers:** Allow the contract to receive your Treasure and BTC
5. **Mint:** Confirm transaction. Your Vault NFT is minted.

Your 1093-day journey begins.

---

## Learn More

- [Product Specification](../protocol/Product_Specification.md) - Withdrawal tiers and stability analysis
- [Technical Specification](../protocol/Technical_Specification.md) - Contract mechanics
- [Collateral Matching](../protocol/Collateral_Matching.md) - Match bonus deep dive
- [DAO Design](./DAO_Design.md) - Achievements, campaigns, gamification
- [Market Analysis](./Market_Analysis.md) - Competitive positioning
