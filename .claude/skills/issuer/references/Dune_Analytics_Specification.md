# Dune Analytics Dashboard Specification

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-28

This document specifies a comprehensive Dune Analytics dashboard architecture for **Issuers** of the BTCNFT Protocol. The dashboard enables issuers to monitor ecosystem health, track holder engagement, analyze auction performance, and identify community engagement opportunities.

## Table of Contents

1. [Dashboard Architecture](#dashboard-architecture)
2. [On-Chain Events Reference](#on-chain-events-reference)
3. [SQL Query Templates](#sql-query-templates)
4. [Filter Parameters](#filter-parameters)
5. [Visual Design Guidelines](#visual-design-guidelines)

---

## Dashboard Architecture

### Section 1: Executive Summary

**Purpose:** High-level KPIs for quick ecosystem assessment

| Metric | Data Source | Visualization |
|--------|-------------|---------------|
| Total Vaults | `VaultMinted` filtered by `treasureContract` | Counter |
| Total Collateral (BTC) | Sum of `collateral` from `VaultMinted` | Counter + USD |
| Unique Holders | Distinct `owner` addresses | Counter |
| Vesting Progress | Calculated: `mintTimestamp + 1129 days` | Progress bar |
| Achievement Adoption | `AchievementEarned` unique wallets / holders | Counter |
| 30-Day Deltas | All above with time filter | Sparklines |

### Section 2: Growth Analytics

**Purpose:** Track vault creation trends and collateral accumulation

| Visualization | Metric | Query Pattern |
|---------------|--------|---------------|
| Line chart | Cumulative vault count | `VaultMinted` running sum |
| Area chart | Cumulative collateral | Sum of `collateral` running total |
| Bar chart | Weekly/monthly mints | `VaultMinted` grouped by time |
| Histogram | Collateral distribution | `collateralAmount` bucketed |
| Pie chart | Collateral token breakdown | WBTC vs cbBTC |

### Section 3: Vesting Distribution

**Purpose:** Understand holder lifecycle positions

| Visualization | Metric | Query Pattern |
|---------------|--------|---------------|
| Cohort heatmap | Vaults by mint month | `mintTimestamp` grouped |
| Stacked bar | Vesting vs Vested | Calculated from `mintTimestamp + 1129 days` |
| Timeline | Days until maturity waves | Sort by `vestingEndsAt` |
| Table | Top 10 upcoming maturities | Nearest `vestingEndsAt` |

### Section 4: Withdrawal Analytics

**Purpose:** Monitor withdrawal behavior and engagement

| Visualization | Metric | Query Pattern |
|---------------|--------|---------------|
| Line chart | Withdrawal volume over time | `Withdrawn` events summed |
| Bar chart | Withdrawal frequency per vault | Count per `tokenId` |
| Gauge | Actual vs theoretical rate | Withdrawals / eligible vaults |
| Table | Most active withdrawers | Top wallets by count |
| Counter | Compounding rate | Re-mints after withdrawal |

### Section 5: Health Indicators

**Purpose:** Identify risks and monitor ecosystem health

| Visualization | Metric | Query Pattern |
|---------------|--------|---------------|
| Traffic light | Dormancy risk score | Vaults approaching 1129-day threshold |
| Table | At-risk vaults | `lastActivity + 1129 days` approaching |
| Pie chart | vestedBTC separation rate | `BtcTokenMinted` / total vaults |
| Counter | Early redemption rate | `EarlyRedemption` / total mints |
| Bar chart | Match pool status | `MatchPoolFunded` and `MatchClaimed` |

### Section 6: Achievement Analytics

**Purpose:** Track achievement adoption and engagement

| Visualization | Metric | Query Pattern |
|---------------|--------|---------------|
| Funnel | Achievement progression | MINTER → MATURED → HODLER_SUPREME |
| Bar chart | Distribution by type | `AchievementEarned` by `achievementType` |
| Counter per type | Duration achievements | FIRST_MONTH through DIAMOND_HANDS |
| Table | Recent claims | Latest `AchievementEarned` |
| Leaderboard | Top collectors | Wallets by achievement count |

### Section 7: Auction Performance

**Purpose:** Analyze auction effectiveness and price discovery

| Visualization | Metric | Query Pattern |
|---------------|--------|---------------|
| Line chart | Dutch price curve | `DutchPurchase` prices over time |
| Scatter plot | English final bids | `SlotSettled` winning bids |
| Bar chart | Fill rate | `mintedCount / maxSupply` |
| Table | Active auctions | Current auction states |
| Histogram | Bid distribution | `BidPlaced` amounts |

### Section 8: Community Leaderboards

**Purpose:** Recognize top holders and drive engagement

| Leaderboard | Ranking Metric | Columns |
|-------------|---------------|---------|
| Diamond Watch | Total collateral | Wallet, BTC, Percentile, Tier |
| Diamond Hands | Longest hold | Wallet, Vault ID, Days Held |
| Achievement Hunters | Total achievements | Wallet, Count, Types |
| Active Withdrawers | Withdrawal streak | Wallet, Consecutive Months |

**Percentile Tiers:**
- Diamond: 99th+
- Platinum: 90-99th
- Gold: 75-90th
- Silver: 50-75th
- Bronze: 0-50th

### Section 9: Delegation Analytics

**Purpose:** Monitor withdrawal delegation patterns

| Visualization | Metric | Query Pattern |
|---------------|--------|---------------|
| Counter | Total delegated vaults | `totalDelegatedBPS > 0` |
| Pie chart | Delegation % distribution | Average `percentageBPS` |
| Table | Top delegates | `DelegatedWithdrawal` by delegate |
| Line chart | Delegation trends | `WithdrawalDelegateGranted` over time |

---

## On-Chain Events Reference

### Protocol Layer (VaultNFT)

**Contract:** `VaultNFT.sol`

```solidity
event VaultMinted(
    uint256 indexed tokenId,
    address indexed owner,
    address treasureContract,
    uint256 treasureTokenId,
    uint256 collateral
);

event Withdrawn(
    uint256 indexed tokenId,
    address indexed to,
    uint256 amount
);

event EarlyRedemption(
    uint256 indexed tokenId,
    address indexed owner,
    uint256 returned,
    uint256 forfeited
);

event BtcTokenMinted(
    uint256 indexed tokenId,
    address indexed to,
    uint256 amount
);

event BtcTokenReturned(
    uint256 indexed tokenId,
    address indexed from,
    uint256 amount
);

event MatchClaimed(
    uint256 indexed tokenId,
    uint256 amount
);

event MatchPoolFunded(
    uint256 amount,
    uint256 newBalance
);

event DormantPoked(
    uint256 indexed tokenId,
    address indexed owner,
    address indexed poker,
    uint256 graceDeadline
);

event DormancyStateChanged(
    uint256 indexed tokenId,
    DormancyState newState  // 0=ACTIVE, 1=POKE_PENDING, 2=CLAIMABLE
);

event ActivityProven(
    uint256 indexed tokenId,
    address indexed owner
);

event DormantCollateralClaimed(
    uint256 indexed tokenId,
    address indexed originalOwner,
    address indexed claimer,
    uint256 collateralClaimed
);

event WithdrawalDelegateGranted(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 percentageBPS
);

event WithdrawalDelegateRevoked(
    uint256 indexed tokenId,
    address indexed delegate
);

event AllWithdrawalDelegatesRevoked(
    uint256 indexed tokenId
);

event DelegatedWithdrawal(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 amount
);
```

### Issuer Layer (AchievementNFT)

**Contract:** `AchievementNFT.sol`

```solidity
event AchievementEarned(
    address indexed wallet,
    uint256 indexed tokenId,
    bytes32 indexed achievementType
);

event Locked(
    uint256 indexed tokenId
);

event MinterAuthorized(
    address indexed minter
);

event MinterRevoked(
    address indexed minter
);
```

**Achievement Types (bytes32 keccak256):**

| Type | Hash | Duration |
|------|------|----------|
| `MINTER` | `0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9` | - |
| `MATURED` | `0xc08241f99d245a1865125a383bc2c9dfcef3b29558eb8b02ee883b61565a83bb` | - |
| `HODLER_SUPREME` | `0xdda6e013575f7e7db6a37f8350a8f891c70d53854877c9dcbf6d73271b3db46b` | - |
| `FIRST_MONTH` | `0x92b9bd24b1513009df4a5acf31d7b7282271a13b886d746367979adffa401b23` | 30 days |
| `QUARTER_STACK` | `0x5d0ce431820b31c330750440d2ee38924fa95e8718fa1af9c80ae4caeacfefa7` | 91 days |
| `HALF_YEAR` | `0x057b50ab6fb6da7d038cab2b84b7ee55accbd680e9c6c9faaf85fd0ec3469bed` | 182 days |
| `ANNUAL` | `0x8e5c41880d36050b537c699aa5a031fb23422e63ce6a14ac878aa8a5a670337e` | 365 days |
| `DIAMOND_HANDS` | `0x98a6d6dee6fa0ea5a6b97abf79dde0f26a4cc92eba88a7737416eeeb74fa20c6` | 730 days |

### Issuer Layer (AchievementMinter)

**Contract:** `AchievementMinter.sol`

```solidity
event MinterAchievementClaimed(
    address indexed wallet,
    uint256 indexed vaultId
);

event MaturedAchievementClaimed(
    address indexed wallet,
    uint256 indexed vaultId
);

event DurationAchievementClaimed(
    address indexed wallet,
    uint256 indexed vaultId,
    bytes32 indexed achievementType
);

event HodlerSupremeVaultMinted(
    address indexed wallet,
    uint256 indexed vaultId,
    uint256 treasureId,
    uint256 collateralAmount
);
```

### Issuer Layer (AuctionController)

**Contract:** `AuctionController.sol`

```solidity
event DutchAuctionCreated(
    uint256 indexed auctionId,
    uint256 maxSupply,
    uint256 startPrice,
    uint256 floorPrice,
    uint256 startTime,
    uint256 endTime
);

event DutchPurchase(
    uint256 indexed auctionId,
    address indexed buyer,
    uint256 price,
    uint256 vaultId,
    uint256 treasureId
);

event EnglishAuctionCreated(
    uint256 indexed auctionId,
    uint256 maxSupply,
    uint256 reservePrice,
    uint256 startTime,
    uint256 endTime
);

event BidPlaced(
    uint256 indexed auctionId,
    uint256 indexed slot,
    address indexed bidder,
    uint256 amount
);

event BidRefunded(
    uint256 indexed auctionId,
    uint256 indexed slot,
    address indexed bidder,
    uint256 amount
);

event SlotSettled(
    uint256 indexed auctionId,
    uint256 indexed slot,
    address indexed winner,
    uint256 vaultId,
    uint256 treasureId,
    uint256 winningBid
);

event AuctionFinalized(
    uint256 indexed auctionId
);
```

---

## SQL Query Templates

### Base Issuer Filter

All queries should filter by issuer's TreasureNFT contract address:

```sql
-- Parameter: {{issuer_treasure_contract}}
WHERE treasureContract = {{issuer_treasure_contract}}
```

### 1. Executive Summary Metrics

```sql
-- Total vaults, collateral, and unique holders
SELECT
    COUNT(*) as total_vaults,
    SUM(collateral) / 1e8 as total_btc,
    COUNT(DISTINCT owner) as unique_holders
FROM vaultnft_evt_VaultMinted
WHERE treasureContract = {{issuer_treasure_contract}}
```

### 2. Cumulative Growth Over Time

```sql
SELECT
    date_trunc('day', block_time) as date,
    COUNT(*) as daily_mints,
    SUM(collateral) / 1e8 as daily_btc,
    SUM(COUNT(*)) OVER (ORDER BY date_trunc('day', block_time)) as cumulative_vaults,
    SUM(SUM(collateral)) OVER (ORDER BY date_trunc('day', block_time)) / 1e8 as cumulative_btc
FROM vaultnft_evt_VaultMinted
WHERE treasureContract = {{issuer_treasure_contract}}
GROUP BY 1
ORDER BY 1
```

### 3. Vesting Status Distribution

```sql
WITH vaults AS (
    SELECT
        tokenId,
        owner,
        collateral / 1e8 as btc_amount,
        block_time as mintTimestamp,
        block_time + INTERVAL '1129 days' as vestingEndsAt,
        CASE
            WHEN NOW() >= block_time + INTERVAL '1129 days' THEN 'Vested'
            ELSE 'Vesting'
        END as status,
        GREATEST(0, EXTRACT(DAY FROM (block_time + INTERVAL '1129 days' - NOW()))) as days_remaining
    FROM vaultnft_evt_VaultMinted
    WHERE treasureContract = {{issuer_treasure_contract}}
)
SELECT
    status,
    COUNT(*) as vault_count,
    SUM(btc_amount) as total_btc,
    AVG(days_remaining) as avg_days_remaining
FROM vaults
GROUP BY status
```

### 4. Percentile Tier Ranking

```sql
WITH ranked AS (
    SELECT
        tokenId,
        owner,
        collateral / 1e8 as btc_amount,
        PERCENT_RANK() OVER (ORDER BY collateral DESC) * 100 as percentile
    FROM vaultnft_evt_VaultMinted
    WHERE treasureContract = {{issuer_treasure_contract}}
)
SELECT
    tokenId,
    owner,
    btc_amount,
    percentile,
    CASE
        WHEN percentile >= 99 THEN 'Diamond'
        WHEN percentile >= 90 THEN 'Platinum'
        WHEN percentile >= 75 THEN 'Gold'
        WHEN percentile >= 50 THEN 'Silver'
        ELSE 'Bronze'
    END as tier
FROM ranked
ORDER BY btc_amount DESC
```

### 5. Withdrawal Analytics

```sql
WITH issuer_vaults AS (
    SELECT tokenId, owner
    FROM vaultnft_evt_VaultMinted
    WHERE treasureContract = {{issuer_treasure_contract}}
)
SELECT
    w.tokenId,
    iv.owner,
    COUNT(*) as withdrawal_count,
    SUM(w.amount) / 1e8 as total_withdrawn_btc,
    MIN(w.block_time) as first_withdrawal,
    MAX(w.block_time) as last_withdrawal
FROM vaultnft_evt_Withdrawn w
INNER JOIN issuer_vaults iv ON w.tokenId = iv.tokenId
GROUP BY w.tokenId, iv.owner
ORDER BY withdrawal_count DESC
```

### 6. Early Redemption Analysis

```sql
WITH issuer_vaults AS (
    SELECT tokenId, block_time as mintTimestamp
    FROM vaultnft_evt_VaultMinted
    WHERE treasureContract = {{issuer_treasure_contract}}
)
SELECT
    date_trunc('month', er.block_time) as month,
    COUNT(*) as redemption_count,
    SUM(er.returned) / 1e8 as total_returned_btc,
    SUM(er.forfeited) / 1e8 as total_forfeited_btc,
    AVG(EXTRACT(DAY FROM er.block_time - iv.mintTimestamp)) as avg_days_held,
    AVG(er.forfeited / (er.returned + er.forfeited)) * 100 as avg_forfeiture_pct
FROM vaultnft_evt_EarlyRedemption er
INNER JOIN issuer_vaults iv ON er.tokenId = iv.tokenId
GROUP BY 1
ORDER BY 1
```

### 7. Achievement Distribution

```sql
SELECT
    CASE achievementType
        WHEN 0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9 THEN 'MINTER'
        WHEN 0xc08241f99d245a1865125a383bc2c9dfcef3b29558eb8b02ee883b61565a83bb THEN 'MATURED'
        WHEN 0xdda6e013575f7e7db6a37f8350a8f891c70d53854877c9dcbf6d73271b3db46b THEN 'HODLER_SUPREME'
        WHEN 0x92b9bd24b1513009df4a5acf31d7b7282271a13b886d746367979adffa401b23 THEN 'FIRST_MONTH'
        WHEN 0x5d0ce431820b31c330750440d2ee38924fa95e8718fa1af9c80ae4caeacfefa7 THEN 'QUARTER_STACK'
        WHEN 0x057b50ab6fb6da7d038cab2b84b7ee55accbd680e9c6c9faaf85fd0ec3469bed THEN 'HALF_YEAR'
        WHEN 0x8e5c41880d36050b537c699aa5a031fb23422e63ce6a14ac878aa8a5a670337e THEN 'ANNUAL'
        WHEN 0x98a6d6dee6fa0ea5a6b97abf79dde0f26a4cc92eba88a7737416eeeb74fa20c6 THEN 'DIAMOND_HANDS'
        ELSE 'UNKNOWN'
    END as achievement_name,
    COUNT(DISTINCT wallet) as unique_holders,
    COUNT(*) as total_claims,
    MIN(block_time) as first_claim,
    MAX(block_time) as latest_claim
FROM achievementnft_evt_AchievementEarned
WHERE contract_address = {{issuer_achievement_contract}}
GROUP BY achievementType
ORDER BY unique_holders DESC
```

### 8. Achievement Funnel

```sql
WITH holder_achievements AS (
    SELECT
        wallet,
        MAX(CASE WHEN achievementType = 0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9 THEN 1 ELSE 0 END) as has_minter,
        MAX(CASE WHEN achievementType = 0xc08241f99d245a1865125a383bc2c9dfcef3b29558eb8b02ee883b61565a83bb THEN 1 ELSE 0 END) as has_matured,
        MAX(CASE WHEN achievementType = 0xdda6e013575f7e7db6a37f8350a8f891c70d53854877c9dcbf6d73271b3db46b THEN 1 ELSE 0 END) as has_hodler_supreme
    FROM achievementnft_evt_AchievementEarned
    WHERE contract_address = {{issuer_achievement_contract}}
    GROUP BY wallet
)
SELECT 'MINTER' as stage, 1 as stage_order, COUNT(*) as count FROM holder_achievements WHERE has_minter = 1
UNION ALL
SELECT 'MATURED', 2, COUNT(*) FROM holder_achievements WHERE has_matured = 1
UNION ALL
SELECT 'HODLER_SUPREME', 3, COUNT(*) FROM holder_achievements WHERE has_hodler_supreme = 1
ORDER BY stage_order
```

### 9. Dutch Auction Performance

```sql
SELECT
    auctionId,
    buyer,
    price / 1e8 as price_btc,
    vaultId,
    treasureId,
    block_time,
    ROW_NUMBER() OVER (PARTITION BY auctionId ORDER BY block_time) as purchase_order
FROM auctioncontroller_evt_DutchPurchase
WHERE contract_address = {{issuer_auction_contract}}
ORDER BY auctionId, block_time
```

### 10. English Auction Bidding

```sql
SELECT
    auctionId,
    slot,
    COUNT(*) as total_bids,
    MAX(amount) / 1e8 as winning_bid_btc,
    MIN(amount) / 1e8 as opening_bid_btc,
    (MAX(amount) - MIN(amount)) / NULLIF(MIN(amount), 0) * 100 as price_increase_pct
FROM auctioncontroller_evt_BidPlaced
WHERE contract_address = {{issuer_auction_contract}}
GROUP BY auctionId, slot
ORDER BY auctionId, slot
```

### 11. Dormancy Risk Detection

```sql
WITH vault_activity AS (
    SELECT
        vm.tokenId,
        vm.owner,
        vm.collateral / 1e8 as btc_amount,
        COALESCE(
            GREATEST(
                (SELECT MAX(block_time) FROM vaultnft_evt_Withdrawn w WHERE w.tokenId = vm.tokenId),
                (SELECT MAX(block_time) FROM erc721_evt_Transfer t WHERE t.tokenId = vm.tokenId)
            ),
            vm.block_time
        ) as last_activity
    FROM vaultnft_evt_VaultMinted vm
    WHERE vm.treasureContract = {{issuer_treasure_contract}}
)
SELECT
    tokenId,
    owner,
    btc_amount,
    last_activity,
    EXTRACT(DAY FROM NOW() - last_activity) as days_inactive,
    1129 - EXTRACT(DAY FROM NOW() - last_activity) as days_until_dormant,
    CASE
        WHEN EXTRACT(DAY FROM NOW() - last_activity) >= 1099 THEN 'CRITICAL'
        WHEN EXTRACT(DAY FROM NOW() - last_activity) >= 1000 THEN 'HIGH'
        WHEN EXTRACT(DAY FROM NOW() - last_activity) >= 730 THEN 'MEDIUM'
        ELSE 'LOW'
    END as risk_level
FROM vault_activity
WHERE EXTRACT(DAY FROM NOW() - last_activity) >= 730
ORDER BY days_inactive DESC
```

### 12. Cohort Retention Analysis

```sql
WITH cohorts AS (
    SELECT
        tokenId,
        owner,
        date_trunc('month', block_time) as cohort_month,
        collateral / 1e8 as initial_btc
    FROM vaultnft_evt_VaultMinted
    WHERE treasureContract = {{issuer_treasure_contract}}
),
cohort_status AS (
    SELECT
        c.cohort_month,
        c.tokenId,
        c.initial_btc,
        CASE WHEN er.tokenId IS NOT NULL THEN 'Redeemed' ELSE 'Active' END as status
    FROM cohorts c
    LEFT JOIN vaultnft_evt_EarlyRedemption er ON c.tokenId = er.tokenId
)
SELECT
    cohort_month,
    COUNT(*) as total_mints,
    SUM(CASE WHEN status = 'Active' THEN 1 ELSE 0 END) as active_count,
    SUM(CASE WHEN status = 'Redeemed' THEN 1 ELSE 0 END) as redeemed_count,
    SUM(CASE WHEN status = 'Active' THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as retention_rate,
    SUM(initial_btc) as cohort_btc
FROM cohort_status
GROUP BY cohort_month
ORDER BY cohort_month
```

### 13. vestedBTC Separation Analysis

```sql
WITH issuer_vaults AS (
    SELECT tokenId FROM vaultnft_evt_VaultMinted WHERE treasureContract = {{issuer_treasure_contract}}
)
SELECT
    date_trunc('month', btm.block_time) as month,
    COUNT(*) as separations,
    SUM(btm.amount) / 1e8 as separated_btc,
    COUNT(DISTINCT btm.to) as unique_separators
FROM vaultnft_evt_BtcTokenMinted btm
INNER JOIN issuer_vaults iv ON btm.tokenId = iv.tokenId
GROUP BY 1
ORDER BY 1
```

### 14. Delegation Patterns

```sql
WITH issuer_vaults AS (
    SELECT tokenId, owner FROM vaultnft_evt_VaultMinted WHERE treasureContract = {{issuer_treasure_contract}}
)
SELECT
    dg.tokenId,
    iv.owner as vault_owner,
    dg.delegate,
    dg.percentageBPS / 100.0 as percentage,
    dg.block_time as granted_at,
    CASE WHEN dr.tokenId IS NOT NULL THEN 'Revoked' ELSE 'Active' END as status
FROM vaultnft_evt_WithdrawalDelegateGranted dg
INNER JOIN issuer_vaults iv ON dg.tokenId = iv.tokenId
LEFT JOIN vaultnft_evt_WithdrawalDelegateRevoked dr
    ON dg.tokenId = dr.tokenId AND dg.delegate = dr.delegate AND dr.block_time > dg.block_time
ORDER BY dg.block_time DESC
```

---

## Filter Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `issuer_treasure_contract` | address | TreasureNFT contract address |
| `issuer_achievement_contract` | address | AchievementNFT contract address |
| `issuer_auction_contract` | address | AuctionController contract address |
| `vault_contract` | address | VaultNFT protocol contract address |

### Optional Filters

| Filter | Type | Options | Default |
|--------|------|---------|---------|
| `time_range` | dropdown | 7d, 30d, 90d, 1y, All | All |
| `vesting_status` | dropdown | All, Vesting, Vested | All |
| `tier_filter` | multi-select | Diamond, Platinum, Gold, Silver, Bronze | All |
| `collateral_token` | dropdown | All, WBTC, cbBTC | All |
| `min_collateral` | number | 0.01 - 100 BTC | 0 |

---

## Visual Design Guidelines

### Color Scheme

| Element | Hex | Usage |
|---------|-----|-------|
| Diamond | `#E8F4FF` | 99th+ percentile tier |
| Platinum | `#E5E4E2` | 90-99th percentile tier |
| Gold | `#FFD700` | 75-90th percentile tier |
| Silver | `#C0C0C0` | 50-75th percentile tier |
| Bronze | `#CD7F32` | 0-50th percentile tier |
| Success | `#22c55e` | Positive metrics |
| Warning | `#f59e0b` | Attention needed |
| Danger | `#ef4444` | Critical issues |

### Refresh Rates

| Section | Rate | Rationale |
|---------|------|-----------|
| Executive Summary | 15 min | High visibility KPIs |
| Growth/Vesting | 1 hour | Slower changing metrics |
| Withdrawals/Health | 30 min | Risk monitoring |
| Auctions | 5 min | Active bidding activity |
| Leaderboards | 1 hour | Less volatile rankings |

### Dashboard Layout

```
+------------------------------------------+
|           EXECUTIVE SUMMARY               |
| [Counters: Vaults | BTC | Holders | %]   |
+------------------------------------------+
|                                          |
|   GROWTH          |    VESTING           |
|   [Charts]        |    [Charts]          |
|                   |                      |
+-------------------+----------------------+
|                                          |
|   WITHDRAWALS     |    HEALTH            |
|   [Charts]        |    [Charts/Tables]   |
|                   |                      |
+-------------------+----------------------+
|                                          |
|          ACHIEVEMENTS                    |
|          [Funnel + Distribution]         |
|                                          |
+------------------------------------------+
|                                          |
|          AUCTION PERFORMANCE             |
|          [Charts + Tables]               |
|                                          |
+------------------------------------------+
|                                          |
|          LEADERBOARDS                    |
|          [Tables]                        |
|                                          |
+------------------------------------------+
```

---

## Protocol Constants

| Constant | Value | Usage |
|----------|-------|-------|
| Vesting Period | 1129 days | `mintTimestamp + 1129 days` = vested |
| Withdrawal Rate | 1.0% monthly | 12% annually |
| Withdrawal Cooldown | 30 days | Minimum between withdrawals |
| Dormancy Threshold | 1129 days | Inactivity trigger for poke |
| Grace Period | 30 days | After poke, before claimable |
| BTC Decimals | 8 | Divide raw values by 1e8 |

---

## SDK Query Equivalents

The `@btcnft/vault-analytics` SDK provides TypeScript equivalents for all Dune queries, enabling local simulation analytics and programmatic access.

### Installation

```bash
npm install @btcnft/vault-analytics
```

### Quick Start

```typescript
import {
  createAnvilIndexer,
  createAnvilAdapter,
  createAnalyticsAPI,
} from '@btcnft/vault-analytics';

// Initialize for local simulation
const indexer = createAnvilIndexer('http://localhost:8545');
const adapter = createAnvilAdapter(indexer);
const api = createAnalyticsAPI({ adapter });

// Start indexing events
await indexer.startIndexing({
  vaultNFT: '0x...',
  btcToken: '0x...',
  achievementMinter: '0x...',
});
```

### Query Mapping

| Dune Query | SDK Method | Return Type |
|------------|------------|-------------|
| Executive Summary | `api.getPortfolioStats()` | `PortfolioStats` |
| Cumulative Growth | `api.getGrowthTimeSeries('day')` | `GrowthTimeSeriesPoint[]` |
| Vesting Distribution | `api.getVestingDistribution()` | `VestingDistribution` |
| Percentile Ranking | `api.getRankedVaults()` | `RankedVault[]` |
| Withdrawal Analytics | `api.getWithdrawalTimeSeries('day')` | `WithdrawalTimeSeriesPoint[]` |
| Early Redemption | `api.getRedemptionTimeSeries('month')` | `RedemptionTimeSeriesPoint[]` |
| Achievement Distribution | `api.getAchievementDistribution()` | `AchievementDistribution[]` |
| Achievement Funnel | `api.getAchievementFunnel()` | `AchievementFunnel` |
| Dormancy Risk | `api.getDormancyRisks('MEDIUM')` | `DormancyRisk[]` |
| Ecosystem Health | `api.getEcosystemHealth()` | `EcosystemHealth` |
| Cohort Retention | `api.getCohortAnalysis()` | `CohortAnalysis` |
| Collateral Leaderboard | `api.getCollateralLeaderboard({ limit: 10 })` | `RankedVault[]` |
| Achievement Leaderboard | `api.getAchievementLeaderboard({ limit: 10 })` | `WalletAchievementProfile[]` |

### Example: Portfolio Statistics

```typescript
// SDK equivalent of Executive Summary metrics
const stats = await api.getPortfolioStats();

console.log(`Total Vaults: ${stats.totalVaults}`);
console.log(`Total Collateral: ${stats.totalCollateral} satoshis`);
console.log(`Unique Holders: ${stats.uniqueHolders}`);
console.log(`Average Collateral: ${stats.averageCollateral} satoshis`);
```

### Example: Achievement Funnel

```typescript
// SDK equivalent of Achievement Funnel query
const funnel = await api.getAchievementFunnel();

console.log(`MINTER: ${funnel.minterCount} wallets`);
console.log(`  ↓ ${funnel.minterToMaturedRate.toFixed(1)}%`);
console.log(`MATURED: ${funnel.maturedCount} wallets`);
console.log(`  ↓ ${funnel.maturedToHodlerRate.toFixed(1)}%`);
console.log(`HODLER_SUPREME: ${funnel.hodlerSupremeCount} wallets`);
console.log(`Overall: ${funnel.completionRate.toFixed(2)}%`);
```

### Example: Dormancy Risk Detection

```typescript
// SDK equivalent of Dormancy Risk Detection query
const risks = await api.getDormancyRisks('MEDIUM');

for (const risk of risks) {
  console.log(`Vault ${risk.tokenId}: ${risk.riskLevel}`);
  console.log(`  Days inactive: ${risk.daysInactive.toFixed(1)}`);
  console.log(`  Days until dormant: ${risk.daysUntilDormant.toFixed(1)}`);
}
```

### Export to CSV/JSON

```typescript
import {
  exportVaults,
  exportPortfolioStats,
  exportAchievementDistribution,
} from '@btcnft/vault-analytics';

// Export vaults to CSV
const vaults = await api.getVaults();
const csv = exportVaults(vaults, { format: 'csv' });

// Export stats to JSON
const stats = await api.getPortfolioStats();
const json = exportPortfolioStats(stats, { format: 'json', prettyPrint: true });
```

---

## Simulation Analytics

The SDK provides specialized tools for analyzing protocol behavior during local Foundry simulations.

### Simulation Reporter

```typescript
import {
  createAnvilIndexer,
  createSimulationReporter,
} from '@btcnft/vault-analytics';

const indexer = createAnvilIndexer('http://localhost:8545');
const reporter = createSimulationReporter({ indexer });

// Start indexing before running tests
await indexer.startIndexing({
  vaultNFT: '0x...',
  btcToken: '0x...',
});

// Run your Foundry tests...

// Generate report
const report = await reporter.generateReport();

console.log(`Vaults Minted: ${report.summary.vaultsMinted}`);
console.log(`Total Collateral: ${report.summary.totalCollateral}`);
console.log(`Withdrawals: ${report.summary.withdrawalsExecuted}`);
console.log(`Achievements: ${report.summary.achievementsClaimed}`);
```

### Ghost Variable Integration

For invariant testing with Foundry's CrossLayerHandler:

```typescript
import { readGhostVariables, formatGhostVariables } from '@btcnft/vault-analytics';

// Read ghost variables from handler contract
const ghosts = await readGhostVariables(publicClient, handlerAddress);

// Format for display
console.log(formatGhostVariables(ghosts));

// Verify conservation laws
const { isConserved, delta } = calculateConservation(ghosts);
if (!isConserved) {
  throw new Error(`Conservation violation: ${delta}`);
}
```

### Event Type Reference

The SDK captures all 27 protocol and issuer events:

**Protocol Events:** `VaultMinted`, `Withdrawn`, `EarlyRedemption`, `BtcTokenMinted`, `BtcTokenReturned`, `MatchClaimed`, `MatchPoolFunded`, `DormantPoked`, `DormancyStateChanged`, `ActivityProven`, `DormantCollateralClaimed`, `WithdrawalDelegateGranted`, `WithdrawalDelegateRevoked`, `AllWithdrawalDelegatesRevoked`, `DelegatedWithdrawal`

**Achievement Events:** `MinterAchievementClaimed`, `MaturedAchievementClaimed`, `DurationAchievementClaimed`, `HodlerSupremeVaultMinted`

**Auction Events:** `DutchAuctionCreated`, `DutchPurchase`, `EnglishAuctionCreated`, `BidPlaced`, `BidRefunded`, `SlotSettled`, `AuctionFinalized`
