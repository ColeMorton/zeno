# [BRAND_NAME] Holder Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-16
> **Related Documents:**
> - [Brand Design](./Brand_Design.md)
> - [Holder Experience](../issuer/Holder_Experience.md)
> - [Product Specification](../protocol/Product_Specification.md)

---

## Welcome

This guide covers how to participate in [BRAND_NAME] specifically. For general protocol mechanics, see [Holder Experience](../issuer/Holder_Experience.md).

---

## How to Join

### Step 1: Acquire Treasure NFT

Get a [BRAND_NAME] Treasure NFT through:
- Auction (Dutch or English)
- Direct mint (if available)
- Secondary market

[Placeholder: Current acquisition options]

### Step 2: Acquire BTC

Get WBTC or cbBTC from:
- Centralized exchange (CEX) withdrawal
- DEX swap (ETH → WBTC)
- Coinbase → cbBTC

### Step 3: Mint Vault

1. Approve Treasure + BTC transfers
2. Call protocol `mint()` with your Treasure and BTC
3. Receive Vault NFT

### Step 4: Claim MINTER Achievement

After minting your vault:
1. Call `claimMinterAchievement(vaultId)` on AchievementMinter
2. Contract verifies you own the vault and it uses [BRAND_NAME] Treasure
3. Receive soulbound MINTER achievement NFT

This achievement is permanently bound to your wallet and cannot be transferred.

---

## Your Vault

### What You Get

| Component | Description |
|-----------|-------------|
| Vault NFT | ERC-998 containing your position |
| Treasure | Unique art based on your Entry Badge type |
| BTC Collateral | Your locked BTC |
| Withdrawal Rate | 10.5% annual (0.875% monthly) |

### Vesting Period

**1093 days (~3 years)** - no withdrawals during this period.

During vesting, you can:
- Earn achievements
- Transfer your Vault
- View your position

### Post-Vesting

After 1093 days:
- **Withdraw** 0.875% of BTC monthly
- **Claim** collateral matching from early quitters
- **Mint vestedBTC** for liquidity access

---

## Vault Stacking

### How It Works

Each Vault generates achievements over time. With MINTER + MATURED achievements, you can mint additional Vaults:

```
Mint Vault #1 → Claim MINTER achievement
                      ↓
               Claim duration achievements as you hold
                      ↓
               After vesting: Claim MATURED achievement
                      ↓
               Call mintHodlerSupremeVault() → Vault #2
                      ↓
               New vault earns its own achievements...
```

### Available Achievements

| Achievement | Requirement | Claim Function |
|-------------|-------------|----------------|
| MINTER | Own vault with issuer's Treasure | `claimMinterAchievement(vaultId)` |
| FIRST_MONTH | Hold 30 days | `claimDurationAchievement(vaultId, FIRST_MONTH)` |
| QUARTER_STACK | Hold 91 days | `claimDurationAchievement(vaultId, QUARTER_STACK)` |
| HALF_YEAR | Hold 182 days | `claimDurationAchievement(vaultId, HALF_YEAR)` |
| ANNUAL | Hold 365 days | `claimDurationAchievement(vaultId, ANNUAL)` |
| DIAMOND_HANDS | Hold 730 days | `claimDurationAchievement(vaultId, DIAMOND_HANDS)` |
| MATURED | Vault vested + match claimed | `claimMaturedAchievement(vaultId)` |
| HODLER_SUPREME | MINTER + MATURED | `mintHodlerSupremeVault(...)` |

### Benefits of Stacking

- Multiple withdrawal streams post-vesting
- Each Vault generates its own duration achievements
- Compounding: more time = more achievements = more Vaults

---

## Series Information

### Bitcoin Series (Active)

| Property | Value |
|----------|-------|
| Status | Ongoing |
| Entry | Badge-gated |
| Withdrawal Rate | 10.5% annual |
| Treasure | Unique art per badge type |

### Future Series

[Coming soon]

---

## [BRAND_NAME] Specific FAQ

### Entry

**How do I get a Treasure NFT?**
Acquire a [BRAND_NAME] Treasure through auction, direct mint, or secondary market. Details at [placeholder].

**How do achievements work?**
Achievements are soulbound NFTs (ERC-5192) that attest your on-chain actions. You claim them by calling functions on the AchievementMinter contract.

**Can I transfer my achievements?**
No. All achievements are soulbound (non-transferable). They permanently attest your wallet's participation.

### Participation

**Why [BRAND_NAME] vs open minting?**
- Unique Treasure art exclusive to [BRAND_NAME]
- Community of aligned participants
- Brand-specific achievements and gamification
- Access to `mintHodlerSupremeVault()` after earning MINTER + MATURED

**Can I participate without a [BRAND_NAME] Treasure?**
You can mint a vault with any ERC-721, but only vaults using [BRAND_NAME] Treasures are eligible for achievements through this issuer.

### Series

**What is a series?**
Series are themed collections of Treasures. Bitcoin Series is ongoing; future series may be limited edition.

**Can I choose which series to join?**
Yes, if you have an eligible badge for that series.

---

## Support

For [BRAND_NAME] specific questions:
- [Discord/Community link placeholder]
- [Support contact placeholder]

For protocol questions, see:
- [Holder Experience](../issuer/Holder_Experience.md)
- [Product Specification](../protocol/Product_Specification.md)

---

## Legal

This guide is for informational purposes only. See [BRAND_NAME] terms of service for full legal terms.

Not financial, tax, or legal advice. Consult qualified professionals for your specific situation.
