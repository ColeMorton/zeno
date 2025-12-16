# BTCNFT Protocol Holder Experience

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-16
> **Related Documents:**
> - [Product Specification](../protocol/Product_Specification.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Issuer Guide](./Issuer_Guide.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [User Journey](#2-user-journey)
3. [Withdrawal Experience](#3-withdrawal-experience)
4. [vestedBTC Options](#4-vestedbtc-options)
5. [Risk Awareness](#5-risk-awareness)
6. [FAQ](#6-faq)

---

## 1. Overview

### The Deal

**Lock BTC + NFT for 3 years. Get perpetual withdrawals forever. Earn bonus BTC from quitters.**

| Element | Details |
|---------|---------|
| Deposit | Treasure NFT + BTC collateral |
| Vesting | 1093 days (~3 years) - no withdrawals |
| Post-vesting | Withdraw percentage of BTC every 30 days, forever |
| Collateral matching | Early quitters forfeit BTC distributed to holders who stay |
| Achievements | Earn NFT badges for holding milestones |

### Withdrawal Rate

| Monthly | Annual | Historical Yearly Stability |
|---------|--------|---------------------------|
| 0.875% | 10.5% | 100% (2017-2025 data) |

> **Important:** Historical analysis, not a guarantee. BTC-denominated (not pegged to USD). Past performance does not guarantee future results.

---

## 2. User Journey

### Phase 1: Mint (Day 0)

**Open Minting:**
1. Acquire BTC (WBTC or cbBTC)
2. Acquire or create Treasure NFT
3. Approve transfers
4. Call mint → Receive Vault NFT

**Badge-Gated Minting (if applicable):**
1. Engage with issuer
2. Earn Entry Badge
3. Acquire BTC
4. Redeem Badge + BTC → Receive Vault NFT with unique Treasure

### Phase 2: Vesting (Days 1-1093)

**No withdrawals** during this period. Activities available:

| Activity | Description |
|----------|-------------|
| Earn achievements | Duration badges as you hold |
| Transfer Vault | Sell or gift your position |
| Mint vestedBTC | Separate collateral claim (post-vesting only) |

**Achievement Milestones:**

| Achievement | Requirement |
|-------------|-------------|
| First Month | Hold 30 days |
| Quarter Stack | Hold 91 days |
| Half Year | Hold 182 days |
| Annual | Hold 365 days |
| Diamond Hands | Hold 730 days |
| Hodler Supreme | Hold 1093 days |

### Phase 3: Maturity (Day 1093)

Three things unlock:

1. **Withdrawals:** Start taking percentage of BTC monthly
2. **Collateral matching:** Claim share of forfeited BTC from early quitters
3. **vestedBTC:** Extract collateral as liquid token while keeping withdrawal rights

### Phase 4: Perpetual (Day 1093+)

Withdraw percentage of remaining BTC every 30 days. Forever.

**Math:** Because it's percentage-based, collateral never fully depletes. Even after 100 years, you'd retain ~6.7% of original BTC.

---

## 3. Withdrawal Experience

### How Withdrawals Work

```
Day 1094+ (Post-Vesting)
       ↓
Call withdraw(vaultId)
       ↓
Contract calculates: remainingCollateral × 0.875%
       ↓
BTC transferred to your wallet
       ↓
30-day cooldown begins
       ↓
Repeat next month
```

### Withdrawal Options

| Action | Description |
|--------|-------------|
| Hold BTC | Long-term appreciation |
| Sell BTC → USD | Realize gains |
| Compound | Mint new Vault with withdrawal BTC |
| Use in DeFi | Aave, LP, etc. |

### Withdrawal Schedule

Withdrawals accumulate. You don't have to withdraw every month - withdraw when convenient.

---

## 4. vestedBTC Options

### What is vestedBTC?

After maturity, you can separate your BTC collateral into vestedBTC (ERC-20) while keeping your Vault and withdrawal rights.

**What you keep:**
- Vault NFT (your position)
- Treasure (your art)
- Withdrawal rights (keep withdrawing monthly)

**What you get:**
- vestedBTC tokens (1:1 with your BTC collateral)
- Fully liquid, tradeable on DEXs
- Usable as collateral in DeFi

### Use Cases

| Goal | Action |
|------|--------|
| Need cash now | Sell vestedBTC on DEX, keep withdrawal rights |
| Leverage | Deposit vestedBTC in Aave, borrow against it |
| Earn LP fees | Provide vestedBTC/USDC liquidity |
| Exit completely | Return vestedBTC, redeem Vault, get BTC back |

### Trade-off

To redeem your Vault and reclaim underlying collateral, you must return the full vestedBTC amount. This is all-or-nothing.

---

## 5. Risk Awareness

### Risks

| Risk | Severity | Reality |
|------|----------|---------|
| **BTC price crash** | Real | Collateral is BTC. It can go down. Historical 1093-day analysis shows 100% positive returns, but past ≠ future. |
| **Smart contract** | Real | Code is audited, but bugs can exist. Non-custodial - your keys, your responsibility. |
| **Early exit penalty** | Real | Leave before 1093 days = forfeit portion of BTC + lose Treasure forever. |
| **Liquidation** | None | Unlike CDPs, you cannot be liquidated. Position is yours regardless of BTC price. |

### Early Exit (Redemption)

You can redeem anytime, but you forfeit a portion based on time held:

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

### Dormancy Risk

If you separate vestedBTC and sell it, AND become inactive for 1093+ days, your Vault becomes vulnerable:

1. Anyone can "poke" your Vault
2. You have 30 days to respond
3. If you don't respond, vestedBTC holder can claim your collateral
4. You receive your Treasure back; they receive the BTC

**Prevention:** Interact with your Vault at least once every 3 years. A simple withdrawal is enough.

---

## 6. FAQ

### Getting Started

**How do I get started?**
1. Acquire BTC (WBTC or cbBTC from a CEX or DEX)
2. Acquire or create a Treasure NFT (any ERC-721)
3. Connect wallet to the dapp
4. Approve transfers and mint

**What can I use as Treasure?**
Any ERC-721 NFT. It becomes "stored" in your Vault and provides the visual identity.

### During Vesting

**Can I withdraw during vesting?**
No. 1093-day lock is absolute. You can only redeem early (with penalty).

**Can I sell my position?**
Yes. The Vault NFT is transferable. Sell on any NFT marketplace.

**Do I earn anything during vesting?**
You earn achievements as you hold. Achievements can be used as Treasures for future Vaults.

### Post-Vesting

**Do I have to withdraw every month?**
No. Withdrawals accumulate. Withdraw when convenient.

**What's collateral matching?**
When others exit early, they forfeit BTC. That BTC is distributed pro-rata to vested holders.

**Can I ever get my full BTC back?**
Yes. After vesting, you can redeem your Vault to reclaim remaining collateral. If you've minted vestedBTC, you must return it first.

### vestedBTC

**What is vestedBTC?**
An ERC-20 token representing your collateral claim. You can separate it from your Vault while keeping withdrawal rights.

**Can I sell vestedBTC and keep withdrawing?**
Yes. You retain withdrawal rights even after selling vestedBTC.

**What happens if I lose my vestedBTC?**
You cannot redeem your Vault without returning the full vestedBTC amount. But you keep withdrawal rights forever.

### Safety

**Is this a rug?**
No. Smart contract is immutable. Your BTC is non-custodial - the contract cannot take it.

**What if the team disappears?**
Code runs without team intervention. Vesting, withdrawals, and claims are all on-chain and permissionless.

**Can someone steal my collateral?**
Only if you abandon it (sell vestedBTC + 3+ years inactive + don't respond to 30-day poke). Otherwise, impossible.

### Taxes

**How are withdrawals taxed?**
Withdrawals represent transfer of your own property from smart contract to wallet. No exchange or profit event at withdrawal time. Tax treatment varies by jurisdiction - consult a qualified tax professional.

**This is not tax advice.** You are responsible for understanding and complying with tax obligations in your jurisdiction.

---

## Learn More

| Topic | Document |
|-------|----------|
| Contract mechanics | [Technical Specification](../protocol/Technical_Specification.md) |
| Product definition | [Product Specification](../protocol/Product_Specification.md) |
| Collateral matching details | [Collateral Matching](../protocol/Collateral_Matching.md) |
| Issuer options | [Issuer Guide](./Issuer_Guide.md) |
