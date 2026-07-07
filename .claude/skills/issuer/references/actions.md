# Issuer Layer Actions Reference

> **Version:** 1.0.0
> **Status:** Final
> **Last Updated:** 2026-03-22
> **Related Documents:**
> - [CLI Reference](./CLI.md) — command syntax, arguments, contract calls
> - [Integration Guide](./Integration_Guide.md) — issuer onboarding
> - [Achievements Specification](./Achievements_Specification.md) — achievement definitions
> - [Chapter System Specification](./Chapter_System_Specification.md) — chapter mechanics
> - [Hybrid Vault Specification](./Hybrid_Vault_Specification.md) — hybrid vault mechanics

---

## Overview

This document catalogs **every action** available in the issuer layer — organized by actor type and functional domain. It covers CLI-accessible operations, contract-only functions, and multi-step workflows that span multiple transactions.

**How to use with CLI.md:** This document lists *what* actions exist, *who* can perform them, and *what* they require. For command syntax, arguments, and usage examples, see [CLI.md](./CLI.md).

### Table Legend

| Column | Meaning |
|--------|---------|
| **Action** | Human-readable name (verb phrase) |
| **Actor** | Who can perform this: Holder, Admin, Keeper, Anyone |
| **Function** | Contract function signature |
| **CLI** | CLI command name (see CLI.md for syntax), or `--` if contract-only |
| **Prerequisites** | What must be true before calling (reverts otherwise) |
| **Effects** | State changes produced by the action |

---

## Actor Types

| Actor | Identity | Description |
|-------|----------|-------------|
| **Holder** | Wallet owning a VaultNFT | Mints vaults, claims achievements, manages positions, configures streams |
| **Admin** | Contract `owner()` | Configures contracts, creates chapters/auctions, manages minter authorization |
| **Keeper** | Authorized keeper address | Updates tier thresholds on TreasureNFT |
| **Anyone** | Any EOA or contract | Permissionless operations: profile creation, auction settlement, vol settlement, stream creation |

---

## Actions by Domain

### 1. Vault Minting

**Contracts:** `VaultMintController.sol`, `HybridMintController.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Mint standard vault | Anyone | `VaultMintController.mintVault(bytes32, uint256)` | `mint-vault` | WBTC balance >= amount; WBTC approved to controller; amount > 0 | Creates VaultNFT + TreasureNFT, locks WBTC collateral; returns vault ID |
| Mint hybrid vault | Anyone | `HybridMintController.mintHybridVault(uint256)` | `mint-hybrid` | cbBTC balance >= amount; cbBTC approved to controller; amount > 0 | Mints VaultNFT + escrows LP leg in VestingEscrow (redeem hook bound); returns vault ID |
| Update monthly LP config | Admin | `HybridMintController.updateMonthlyConfig(MonthlyConfig)` | `--` | Caller is owner; config update period elapsed since last update | Updates target LP ratio configuration |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Calculate target LP ratio | `HybridMintController.calculateTargetLPRatio()` | `--` | Current target LP ratio |
| Measure slippage | `HybridMintController.measureSlippage()` | `--` | Current slippage measurement |
| Get current config | `HybridMintController.getCurrentConfig()` | `--` | MonthlyConfig struct |

---

### 2. Auctions

**Contracts:** `AuctionController.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Create Dutch auction | Admin | `AuctionController.createDutchAuction(uint256, address, DutchAuctionConfig)` | `auction-create-dutch` | Caller is owner; maxSupply > 0; startTime < endTime; startPrice > floorPrice | Creates auction with declining price curve; returns auction ID |
| Purchase from Dutch auction | Anyone | `AuctionController.purchaseDutch(uint256)` | `auction-purchase` | Auction exists; within time window; supply not exhausted; collateral balance >= current price; collateral approved | Mints VaultNFT to buyer at current price; increments minted count |
| Create English auction | Admin | `AuctionController.createEnglishAuction(uint256, address, EnglishAuctionConfig)` | `auction-create-english` | Caller is owner; maxSupply > 0; startTime < endTime | Creates auction with ascending bid slots; returns auction ID |
| Place bid on slot | Anyone | `AuctionController.placeBid(uint256, uint256, uint256)` | `auction-bid` | Auction exists; slot valid; within time window; bid >= min bid; bid > current highest + increment; collateral balance >= amount; collateral approved | Records bid; refunds previous highest bidder |
| Settle auction slot | Anyone | `AuctionController.settleSlot(uint256, uint256)` | `auction-settle` | Auction ended (past endTime); slot not already settled; slot has a winning bidder | Mints VaultNFT to winning bidder; marks slot settled |
| Finalize auction | Admin | `AuctionController.finalizeAuction(uint256)` | `--` | Caller is owner; auction exists; auction not already finalized | Marks auction as FINALIZED; prevents further operations |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Get auction details | `AuctionController.getAuction(uint256)` | `auction-status` | Auction struct (maxSupply, mintedCount, collateralToken, state) |
| Get auction state | `AuctionController.getAuctionState(uint256)` | `auction-status` | Current state enum |
| Get current Dutch price | `AuctionController.getCurrentPrice(uint256)` | `auction-status` | Current declining price |
| Get Dutch config | `AuctionController.getDutchConfig(uint256)` | `auction-status` | DutchAuctionConfig struct |
| Get English config | `AuctionController.getEnglishConfig(uint256)` | `auction-status` | EnglishAuctionConfig struct |
| Get highest bid on slot | `AuctionController.getHighestBid(uint256, uint256)` | `--` | Bid struct (bidder, amount) |

---

### 3. Perpetuals

**Contracts:** `perpetual/PerpetualVault.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Open leveraged position | Anyone | `PerpetualVault.openPosition(uint256, uint256, Side)` | `perp-open` | vBTC balance >= collateral; vBTC approved to PerpVault; collateral >= MIN_COLLATERAL; leverage within MIN_LEVERAGE_X100..MAX_LEVERAGE_X100 | Creates position with leverage; locks collateral; returns position ID |
| Close position | Holder | `PerpetualVault.closePosition(uint256)` | `perp-close` | Position exists; caller is position owner; position not already closed | Calculates PnL; returns collateral +/- profit to owner; clears position |
| Add collateral to position | Holder | `PerpetualVault.addCollateral(uint256, uint256)` | `perp-add-collateral` | Position exists; caller is position owner; position not closed; amount > 0; vBTC balance >= amount; vBTC approved | Increases position collateral; reduces liquidation risk |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Get current BTC price | `PerpetualVault.getCurrentPrice()` | `perp-market` | vBTC price from Curve EMA oracle |
| Get current funding rate | `PerpetualVault.getCurrentFundingRate()` | `perp-market` | OI-based funding rate |
| Get position details | `PerpetualVault.getPosition(uint256)` | `perp-position` | Position struct (collateral, leverage, side, entry price) |
| Get position owner | `PerpetualVault.getPositionOwner(uint256)` | `perp-position` | Owner address |
| Preview close payout | `PerpetualVault.previewClose(uint256)` | `perp-position` | Estimated payout if closed now |
| Get user positions | `PerpetualVault.getUserPositions(address)` | `--` | Array of position IDs owned by user |

---

### 4. Volatility Pool

**Contracts:** `volatility/VolatilityPool.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Deposit to long pool | Anyone | `VolatilityPool.depositLong(uint256)` | `vol-deposit` | vBTC balance >= assets; vBTC approved to pool; assets >= minDeposit | Mints long shares proportional to deposit; transfers vBTC to pool |
| Deposit to short pool | Anyone | `VolatilityPool.depositShort(uint256)` | `vol-deposit` | vBTC balance >= assets; vBTC approved to pool; assets >= minDeposit | Mints short shares proportional to deposit; transfers vBTC to pool |
| Withdraw from long pool | Holder | `VolatilityPool.withdrawLong(uint256)` | `vol-withdraw` | shares > 0; caller has >= shares in long pool | Burns shares; transfers proportional vBTC back to caller |
| Withdraw from short pool | Holder | `VolatilityPool.withdrawShort(uint256)` | `vol-withdraw` | shares > 0; caller has >= shares in short pool | Burns shares; transfers proportional vBTC back to caller |
| Trigger variance settlement | Anyone | `VolatilityPool.settle()` | `vol-settle` | Settlement interval elapsed since last settlement | Calculates realized variance; transfers premium between pools |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Long pool total assets | `VolatilityPool.longPoolAssets()` | `vol-pool-status` | Total vBTC in long pool |
| Short pool total assets | `VolatilityPool.shortPoolAssets()` | `vol-pool-status` | Total vBTC in short pool |
| Long pool total shares | `VolatilityPool.longPoolShares()` | `vol-pool-status` | Total long shares outstanding |
| Short pool total shares | `VolatilityPool.shortPoolShares()` | `vol-pool-status` | Total short shares outstanding |
| Get current variance | `VolatilityPool.getCurrentVariance()` | `vol-pool-status` | Current calculated variance |
| Is settlement due | `VolatilityPool.isSettlementDue()` | `vol-pool-status` | Boolean |
| Next settlement time | `VolatilityPool.nextSettlementTime()` | `vol-pool-status` | Timestamp of next eligible settlement |
| Last settlement variance | `VolatilityPool.lastSettlementVariance()` | `--` | Variance value from last settlement |
| Last settlement time | `VolatilityPool.lastSettlementTime()` | `--` | Timestamp of last settlement |
| User long shares | `VolatilityPool.longSharesOf(address)` | `vol-position` | User's long share balance |
| User short shares | `VolatilityPool.shortSharesOf(address)` | `vol-position` | User's short share balance |
| Preview long withdrawal | `VolatilityPool.previewWithdrawLong(uint256)` | `vol-position` | vBTC amount for given long shares |
| Preview short withdrawal | `VolatilityPool.previewWithdrawShort(uint256)` | `vol-position` | vBTC amount for given short shares |

---

### 5. Achievements

**Contracts:** `AchievementMinter.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Claim MINTER achievement | Holder | `AchievementMinter.claimMinterAchievement(uint256, address)` | `achieve-minter` | Caller owns vault; vault uses issuer's TreasureNFT; does not already have MINTER achievement | Mints soulbound MINTER AchievementNFT to caller |
| Claim MATURED achievement | Holder | `AchievementMinter.claimMaturedAchievement(uint256, address)` | `achieve-matured` | Caller owns vault; has MINTER achievement; vault is vested (1129 days); match has been claimed | Mints soulbound MATURED AchievementNFT to caller |
| Claim duration achievement | Holder | `AchievementMinter.claimDurationAchievement(uint256, address, bytes32)` | `achieve-duration` | Caller owns vault; achievement type is valid duration type; vault age >= duration threshold | Mints soulbound duration AchievementNFT to caller |
| Mint Hodler Supreme vault | Holder | `AchievementMinter.mintHodlerSupremeVault(address, uint256)` | `achieve-hodler-supreme` | Has MINTER achievement; has MATURED achievement; collateral amount > 0; collateral balance + approval | Mints new vault + HODLER_SUPREME achievement in single tx; returns vault ID |

**Duration Achievement Types and Thresholds:**

| Type | Threshold |
|------|-----------|
| `FIRST_MONTH` | 30 days |
| `QUARTER_STACK` | 90 days |
| `HALF_YEAR` | 180 days |
| `ANNUAL` | 365 days |
| `DIAMOND_HANDS` | 1129 days |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Check minter eligibility | `AchievementMinter.canClaimMinterAchievement(address, uint256, address)` | `achieve-check` | Boolean |
| Check matured eligibility | `AchievementMinter.canClaimMaturedAchievement(address, uint256, address)` | `achieve-check` | Boolean |
| Check duration eligibility | `AchievementMinter.canClaimDurationAchievement(address, uint256, address, bytes32)` | `achieve-check` | Boolean |
| Check Hodler Supreme eligibility | `AchievementMinter.canMintHodlerSupremeVault(address, address)` | `--` | Boolean |
| Is duration achievement | `AchievementMinter.isDurationAchievement(bytes32)` | `--` | Boolean |
| Get duration threshold | `AchievementMinter.getDurationThreshold(bytes32)` | `--` | Threshold in seconds |

---

### 6. Chapters

**Contracts:** `ChapterRegistry.sol`, `ChapterMinter.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Create chapter | Admin | `ChapterRegistry.createChapter(uint8, uint16, uint8, uint48, uint48, uint256, uint256, string)` | `chapter-create` | Caller is owner; chapterNumber 1-TOTAL_CHAPTERS; startTimestamp < endTimestamp; minDaysHeld <= maxDaysHeld; chapter ID not already used | Creates chapter with time window and day-range bounds; returns chapter ID |
| Add achievement to chapter | Admin | `ChapterRegistry.addAchievement(bytes32, string, bytes32[])` | `chapter-add-achievement` | Caller is owner; chapter exists; achievement ID not already used | Adds achievement definition to chapter; returns achievement ID |
| Add achievement with verifier | Admin | `ChapterRegistry.addAchievementWithVerifier(bytes32, string, bytes32[], address)` | `--` | Same as addAchievement | Adds achievement with custom verifier contract; returns achievement ID |
| Add stackable achievement | Admin | `ChapterRegistry.addStackableAchievement(bytes32, string, bytes32[], address)` | `--` | Same as addAchievement | Adds stackable (multi-claim) achievement; returns achievement ID |
| Set chapter active | Admin | `ChapterRegistry.setChapterActive(bytes32, bool)` | `chapter-set-active` | Caller is owner; chapter exists | Toggles chapter active state |
| Claim chapter achievement | Holder | `ChapterMinter.claimChapterAchievement(bytes32, bytes32, uint256, address, bytes)` | `chapter-claim` | Chapter active; within mint window; caller owns vault; vault uses issuer treasure; vault age within chapter day range; all prerequisite achievements held; verification passes (if verifier set) | Mints soulbound chapter AchievementNFT to caller |
| Set protocol for collateral | Admin | `ChapterMinter.setProtocol(address, address)` | `--` | Caller is owner | Maps collateral token to protocol contract address |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Get chapter config | `ChapterRegistry.getChapter(bytes32)` | `chapter-info` | Chapter struct (number, year, quarter, timestamps, day range) |
| Get chapter achievements | `ChapterRegistry.getChapterAchievements(bytes32)` | `chapter-info` | Array of achievement IDs in chapter |
| Get achievement details | `ChapterRegistry.getAchievement(bytes32)` | `--` | Achievement struct (name, prerequisites, verifier, stackable) |
| Get achievement's chapter | `ChapterRegistry.getAchievementChapter(bytes32)` | `--` | Chapter ID |
| Is within mint window | `ChapterRegistry.isWithinMintWindow(bytes32)` | `chapter-info` | Boolean |
| Check chapter claim eligibility | `ChapterMinter.canClaimChapterAchievement(address, bytes32, bytes32, uint256, address, bytes)` | `--` | Boolean |
| Get claimable achievements | `ChapterMinter.getClaimableAchievements(address, bytes32, uint256, address)` | `chapter-claimable` | Array of claimable achievement IDs |

---

### 7. Profile & Dashboard

**Contracts:** `ProfileRegistry.sol`, `DashboardNFT.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Create profile | Anyone | `ProfileRegistry.createProfile()` | `profile-create` | Caller does not already have a profile | Registers on-chain profile with timestamp |
| Purchase dashboard feature | Anyone | `DashboardNFT.mint(bytes32)` | `dashboard-mint` | Feature is active; feature has a price set; msg.value >= price | Mints dashboard feature NFT to caller; collects ETH payment |
| Set feature price | Admin | `DashboardNFT.setMintPrice(bytes32, uint256)` | `--` | Caller is owner | Sets price for a feature type |
| Set feature active | Admin | `DashboardNFT.setFeatureActive(bytes32, bool)` | `--` | Caller is owner | Toggles whether feature can be purchased |
| Set base URI | Admin | `DashboardNFT.setBaseURI(string)` | `--` | Caller is owner | Updates metadata base URI |
| Set revenue receiver | Admin | `DashboardNFT.setRevenueReceiver(address)` | `--` | Caller is owner; receiver != address(0) | Changes address that receives ETH from feature sales |
| Withdraw collected fees | Admin | `DashboardNFT.withdraw()` | `--` | Caller is owner; contract balance > 0 | Transfers accumulated ETH to revenue receiver |

**Dashboard Feature Types:**

| Feature | Description |
|---------|-------------|
| `THEME_DARK` | Dark theme |
| `THEME_NEON` | Neon theme |
| `FRAME_ANIMATED` | Animated frame |
| `AVATAR_CUSTOM` | Custom avatar |
| `ANALYTICS_PRO` | Pro analytics |
| `EXPORT_CSV` | CSV export |
| `ALERTS_ADVANCED` | Advanced alerts |
| `PORTFOLIO_MULTI` | Multi-portfolio |
| `FOUNDERS_BUNDLE` | Founders bundle |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Has profile | `ProfileRegistry.hasProfile(address)` | `profile-status` | Boolean |
| Registration timestamp | `ProfileRegistry.registeredAt(address)` | `profile-status` | Unix timestamp |
| Days registered | `ProfileRegistry.getDaysRegistered(address)` | `profile-status` | Number of days |
| Has feature | `DashboardNFT.hasFeature(address, bytes32)` | `dashboard-features` | Boolean |
| Feature mint price | `DashboardNFT.mintPrice(bytes32)` | `dashboard-features` | Price in wei |
| Feature active status | `DashboardNFT.featureActive(bytes32)` | `dashboard-features` | Boolean |

---

### 8. Streaming

Sablier streaming is research-only; no streaming contract is deployed. See `.claude/skills/research/references/Sablier_Streaming_Integration.md`.

---

### 9. Treasure NFT Management

**Contracts:** `TreasureNFT.sol`

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Mint treasure NFT | Authorized Minter | `TreasureNFT.mint(address)` | `treasure-mint` | Caller is authorized minter | Mints TreasureNFT to recipient; returns token ID |
| Mint with achievement type | Authorized Minter | `TreasureNFT.mintWithAchievement(address, bytes32)` | `--` | Caller is authorized minter | Mints TreasureNFT with achievement type metadata; returns token ID |
| Mint batch | Authorized Minter | `TreasureNFT.mintBatch(address, uint256)` | `treasure-mint` | Caller is authorized minter | Mints multiple TreasureNFTs to recipient; returns token ID array |
| Link treasure to vault | Authorized Minter | `TreasureNFT.linkToVault(uint256, uint256)` | `--` | Caller is authorized minter; treasure not already linked to a vault | Associates treasure token with a vault ID |
| Authorize minter | Admin | `TreasureNFT.authorizeMinter(address)` | `treasure-authorize` | Caller is owner | Grants minting permission to address |
| Revoke minter | Admin | `TreasureNFT.revokeMinter(address)` | `treasure-authorize` | Caller is owner | Removes minting permission from address |
| Set keeper | Admin | `TreasureNFT.setKeeper(address)` | `--` | Caller is owner | Changes keeper address for threshold updates |
| Set protocol | Admin | `TreasureNFT.setProtocol(address)` | `--` | Caller is owner | Sets VaultNFT protocol contract address |
| Update tier thresholds | Keeper | `TreasureNFT.updateThresholds(uint256, uint256, uint256, uint256)` | `--` | Caller is keeper | Updates silver/gold/platinum/diamond collateral thresholds |
| Set image CID | Admin | `TreasureNFT.setImageCID(bytes32, Tier, string)` | `--` | Caller is owner | Sets IPFS CID for achievement type + tier combination |
| Set base URI | Admin | `TreasureNFT.setBaseURI(string)` | `--` | Caller is owner | Updates metadata base URI |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Get tier for token | `TreasureNFT.getTier(uint256)` | `treasure-status` | Tier enum (Bronze, Silver, Gold, Platinum, Diamond) |
| Compute tier from collateral | `TreasureNFT.computeTier(uint256)` | `--` | Tier enum based on collateral amount vs thresholds |
| Get linked vault | `TreasureNFT.treasureVault(uint256)` | `treasure-status` | Vault ID linked to treasure |
| Total supply | `TreasureNFT.totalSupply()` | `treasure-status` | Total TreasureNFTs minted |
| Token URI | `TreasureNFT.tokenURI(uint256)` | `--` | On-chain JSON with tier-based metadata |

---

### 10. Achievement NFT Administration

**Contracts:** `AchievementNFT.sol`

These are internal administration functions. Achievement minting is triggered via `AchievementMinter` (Section 5) and `ChapterMinter` (Section 6), not called directly by users.

#### Write Actions

| Action | Actor | Function | CLI | Prerequisites | Effects |
|--------|-------|----------|-----|---------------|---------|
| Mint achievement NFT | Authorized Minter | `AchievementNFT.mint(address, bytes32, bytes32, bool)` | `--` | Caller is authorized minter; if not stackable, recipient must not already hold this achievement | Mints soulbound achievement NFT; increments count |
| Authorize minter | Admin | `AchievementNFT.authorizeMinter(address)` | `--` | Caller is owner | Grants minting permission (typically to AchievementMinter or ChapterMinter contracts) |
| Revoke minter | Admin | `AchievementNFT.revokeMinter(address)` | `--` | Caller is owner | Removes minting permission |
| Set base URI | Admin | `AchievementNFT.setBaseURI(string)` | `--` | Caller is owner | Updates metadata base URI |
| Toggle on-chain SVG | Admin | `AchievementNFT.setUseOnChainSVG(bool)` | `--` | Caller is owner | Switches between on-chain SVG and external URI for token metadata |

#### Queries

| Query | Function | CLI | Returns |
|-------|----------|-----|---------|
| Has achievement | `AchievementNFT.hasAchievement(address, bytes32)` | `achieve-status` | Boolean |
| Achievement count | `AchievementNFT.achievementCount(address, bytes32)` | `achieve-status` | Count (>1 for stackable) |
| Achievement type for token | `AchievementNFT.achievementType(uint256)` | `--` | bytes32 achievement ID |
| Token chapter | `AchievementNFT.tokenChapter(uint256)` | `--` | bytes32 chapter ID |
| Is soulbound | `AchievementNFT.locked(uint256)` | `--` | Always true |
| Is authorized minter | `AchievementNFT.authorizedMinters(address)` | `--` | Boolean |
| Total supply | `AchievementNFT.totalSupply()` | `--` | Total achievement NFTs minted |

---

## Multi-Step Workflows

### Workflow 1: First Vault Setup

**Goal:** Mint a standard vault and establish holder identity.
**Actor:** Holder (new user)

| Step | Action | CLI Command | Notes |
|------|--------|-------------|-------|
| 1 | Create on-chain profile | `profile-create` | Optional but required for TRAILHEAD verification |
| 2 | Approve WBTC to mint controller | `token-approve` (protocol CLI) | Approve VAULT_MINT_CONTROLLER for collateral amount |
| 3 | Mint standard vault | `mint-vault` | Returns vault ID |
| 4 | Claim MINTER achievement | `achieve-minter` | Uses vault ID from step 3 |

**Verification:** `profile-status`, `treasure-status <token_id>`, `achieve-status <wallet> MINTER`

---

### Workflow 2: Hybrid Vault Setup

**Goal:** Mint a hybrid vault with cbBTC and LP split.
**Actor:** Holder (new user)

| Step | Action | CLI Command | Notes |
|------|--------|-------------|-------|
| 1 | Approve cbBTC to hybrid controller | `token-approve` (protocol CLI) | Approve HYBRID_MINT_CONTROLLER for cbBTC amount |
| 2 | Mint hybrid vault | `mint-hybrid` | Returns vault ID; auto-creates LP position |
| 3 | Claim MINTER achievement | `achieve-minter` | Uses vault ID from step 2 with cbBTC as collateral token |

**Verification:** `hybrid-status <vault_id>` (protocol CLI), `achieve-status <wallet> MINTER`

---

### Workflow 3: Dutch Auction Lifecycle

**Goal:** Run a complete Dutch auction from creation to purchase.
**Actors:** Admin (create), Holder (purchase), Admin (finalize)

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Admin | Create Dutch auction | `auction-create-dutch` | Sets supply, price curve, and duration; returns auction ID |
| 2 | -- | Wait for auction start time | -- | Auction is live when `block.timestamp >= startTime` |
| 3 | Holder | Approve collateral to auction controller | `token-approve` (protocol CLI) | Amount = current price (price declines over time) |
| 4 | Holder | Purchase from auction | `auction-purchase` | Fetches current price, purchases vault at that price |
| 5 | Admin | Finalize auction | `--` (contract-only) | `cast send $AUCTION_CONTROLLER "finalizeAuction(uint256)" <auction_id>` |

**Verification:** `auction-status <auction_id>`

---

### Workflow 4: English Auction Lifecycle

**Goal:** Run a complete English auction with competitive bidding and settlement.
**Actors:** Admin (create/finalize), Holders (bid), Anyone (settle)

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Admin | Create English auction | `auction-create-english` | Sets supply, min bid, increment, slot duration; returns auction ID |
| 2 | -- | Wait for auction start time | -- | Bidding opens at startTime |
| 3 | Holder | Approve collateral | `token-approve` (protocol CLI) | Amount = intended bid |
| 4 | Holder | Place bid on slot | `auction-bid` | Must exceed current highest + increment; previous bidder refunded |
| 5 | -- | Repeat steps 3-4 | -- | Multiple holders bid on multiple slots |
| 6 | -- | Wait for auction end time | -- | Bidding closes at endTime |
| 7 | Anyone | Settle each slot | `auction-settle` | Mints vault to winning bidder; one tx per slot |
| 8 | Admin | Finalize auction | `--` (contract-only) | Marks auction as finalized |

**Verification:** `auction-status <auction_id>`

---

### Workflow 5: Achievement Progression

**Goal:** Earn all duration achievements sequentially over the vault's lifetime.
**Actor:** Holder

| Step | Action | CLI Command | Minimum Vault Age |
|------|--------|-------------|-------------------|
| 1 | Mint vault | `mint-vault` or `mint-hybrid` | Day 0 |
| 2 | Claim MINTER | `achieve-minter` | Day 0 |
| 3 | Claim FIRST_MONTH | `achieve-duration` | 30 days |
| 4 | Claim QUARTER_STACK | `achieve-duration` | 90 days |
| 5 | Claim HALF_YEAR | `achieve-duration` | 180 days |
| 6 | Claim ANNUAL | `achieve-duration` | 365 days |
| 7 | Claim DIAMOND_HANDS | `achieve-duration` | 1129 days |
| 8 | Claim MATURED | `achieve-matured` | 1129 days (vested + match claimed) |
| 9 | Mint Hodler Supreme vault | `achieve-hodler-supreme` | Requires MINTER + MATURED |

**Verification:** `achieve-check <type> <vault_id> <token>`, `achieve-status <wallet> <type>`

---

### Workflow 6: Chapter Campaign

**Goal:** Create a chapter with achievements, then allow holders to claim them.
**Actors:** Admin (setup), Holders (claim)

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Admin | Create chapter | `chapter-create` | Defines time window and vault age range; returns chapter ID |
| 2 | Admin | Add achievements | `chapter-add-achievement` | Repeat for each achievement; optionally set prerequisites |
| 3 | Admin | Add achievements with verifiers | `--` (contract-only) | For achievements requiring custom verification logic |
| 4 | Admin | Activate chapter | `chapter-set-active` | Must be active for claims |
| 5 | Holder | Check claimable achievements | `chapter-claimable` | Shows which achievements the holder is eligible for |
| 6 | Holder | Claim chapter achievement | `chapter-claim` | Must meet all prerequisites and verification |

**Verification:** `chapter-info <chapter_id>`, `chapter-claimable <chapter_id> <vault_id> <token>`, `achieve-status <wallet> <type>`

---

### Workflow 7: Streaming Setup

**Goal:** Configure a vault for continuous Sablier streaming of withdrawals.
**Actors:** Holder (configure), Anyone (create)

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Holder | Configure vault for streaming | `stream-configure` | Sets recipient address and enabled flag |
| 2 | Anyone | Create stream | `stream-create` | Vault must have withdrawable amount > 0 |

**For multiple vaults:**

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Holder | Configure each vault | `stream-configure` | Repeat for each vault |
| 2 | Anyone | Batch create streams | `stream-batch` | Pass comma-separated vault IDs; skips ineligible |

**Verification:** `stream-status <vault_id>`

---

### Workflow 8: Perpetual Trading Cycle

**Goal:** Open, manage, and close a leveraged perpetual position.
**Actor:** Holder

| Step | Action | CLI Command | Notes |
|------|--------|-------------|-------|
| 1 | Check market conditions | `perp-market` | View current price and funding rate |
| 2 | Approve vBTC to PerpetualVault | `token-approve` (protocol CLI) | Amount = collateral |
| 3 | Open position | `perp-open` | Specify collateral, leverage (100-based), and side; returns position ID |
| 4 | Monitor position | `perp-position` | Check unrealized PnL via previewClose |
| 5a | Add collateral (if needed) | `perp-add-collateral` | Requires additional vBTC approval |
| 5b | Close position | `perp-close` | Shows estimated payout before executing |

**Verification:** `perp-position <position_id>`, `perp-market`

---

### Workflow 9: Volatility Pool Participation

**Goal:** Take a long or short variance position in the volatility pool.
**Actor:** Holder (deposit/withdraw), Anyone (settle)

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Holder | Approve vBTC to VolatilityPool | `token-approve` (protocol CLI) | Amount = deposit |
| 2 | Holder | Deposit to pool | `vol-deposit` | Specify `long` or `short` side; receives shares |
| 3 | Anyone | Monitor pool | `vol-pool-status` | Check variance, pool balances, settlement status |
| 4 | Holder | Check position value | `vol-position` | Preview withdrawal amounts |
| 5a | Anyone | Trigger settlement | `vol-settle` | Only when settlement interval has elapsed |
| 5b | Holder | Withdraw from pool | `vol-withdraw` | Redeem shares for vBTC |

**Verification:** `vol-position [address]`, `vol-pool-status`

---

### Workflow 10: Treasure NFT Issuance

**Goal:** Set up treasure NFT minting and link treasures to vaults.
**Actors:** Admin (authorize), Authorized Minter (mint/link)

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Admin | Authorize minter | `treasure-authorize` | Grant minting permission to address |
| 2 | Authorized Minter | Mint treasure NFTs | `treasure-mint` | Specify recipient and count; returns token IDs |
| 3 | Authorized Minter | Link treasures to vaults | `--` (contract-only) | `cast send $TREASURE_NFT "linkToVault(uint256,uint256)" <treasure_id> <vault_id>` |

**For treasures with achievement types (contract-only):**

| Step | Actor | Action | CLI Command | Notes |
|------|-------|--------|-------------|-------|
| 1 | Admin | Authorize minter | `treasure-authorize` | -- |
| 2 | Authorized Minter | Mint with achievement | `--` (contract-only) | `cast send $TREASURE_NFT "mintWithAchievement(address,bytes32)" <to> <type>` |

**Verification:** `treasure-status <token_id>`

---

### Workflow 11: Hodler Supreme Vault

**Goal:** Mint a Hodler Supreme vault (achievement + vault atomically).
**Actor:** Holder (experienced, with MINTER + MATURED achievements)

| Step | Action | CLI Command | Notes |
|------|--------|-------------|-------|
| 1 | Verify eligibility | `achieve-status <wallet> MINTER` | Must hold MINTER |
| 2 | Verify eligibility | `achieve-status <wallet> MATURED` | Must hold MATURED |
| 3 | Approve collateral to AchievementMinter | `token-approve` (protocol CLI) | Any of WBTC/vBTC/cbBTC |
| 4 | Mint Hodler Supreme vault | `achieve-hodler-supreme` | Single tx: mints vault + HODLER_SUPREME achievement |

**Verification:** `achieve-status <wallet> HODLER_SUPREME`, `treasure-status <token_id>`

---

### Workflow 12: Dashboard Customization

**Goal:** Set up profile and purchase dashboard features.
**Actor:** Anyone

| Step | Action | CLI Command | Notes |
|------|--------|-------------|-------|
| 1 | Create profile | `profile-create` | One-time registration |
| 2 | Check feature availability | `dashboard-features <wallet> <feature>` | View price and active status |
| 3 | Purchase feature | `dashboard-mint` | Payable with ETH; specify feature type and value in wei |
| 4 | Repeat step 3 | `dashboard-mint` | Purchase additional features as desired |

**Verification:** `profile-status`, `dashboard-features <wallet> <feature>`

---

## Contract-Only Actions Index

Actions available at the contract level but without CLI wrappers. Call these via `cast send` or etherscan.

### HybridMintController

| Function | Actor | Description |
|----------|-------|-------------|
| `updateMonthlyConfig(MonthlyConfig)` | Admin | Update target LP ratio configuration (rate-limited) |

### AuctionController

| Function | Actor | Description |
|----------|-------|-------------|
| `finalizeAuction(uint256)` | Admin | Mark auction as finalized |

### ChapterRegistry

| Function | Actor | Description |
|----------|-------|-------------|
| `addAchievementWithVerifier(bytes32, string, bytes32[], address)` | Admin | Add chapter achievement with custom verifier contract |
| `addStackableAchievement(bytes32, string, bytes32[], address)` | Admin | Add multi-claimable achievement to chapter |

### ChapterMinter

| Function | Actor | Description |
|----------|-------|-------------|
| `setProtocol(address, address)` | Admin | Map collateral token to protocol contract |

### TreasureNFT

| Function | Actor | Description |
|----------|-------|-------------|
| `mintWithAchievement(address, bytes32)` | Authorized Minter | Mint treasure with achievement type metadata |
| `linkToVault(uint256, uint256)` | Authorized Minter | Associate treasure token with vault ID |
| `setKeeper(address)` | Admin | Change keeper address |
| `setProtocol(address)` | Admin | Set VaultNFT protocol address |
| `updateThresholds(uint256, uint256, uint256, uint256)` | Keeper | Update silver/gold/platinum/diamond tier thresholds |
| `setImageCID(bytes32, Tier, string)` | Admin | Set IPFS CID for achievement type + tier |
| `setBaseURI(string)` | Admin | Update metadata base URI |

### AchievementNFT

| Function | Actor | Description |
|----------|-------|-------------|
| `mint(address, bytes32, bytes32, bool)` | Authorized Minter | Mint soulbound achievement (called by AchievementMinter/ChapterMinter) |
| `authorizeMinter(address)` | Admin | Grant minting permission |
| `revokeMinter(address)` | Admin | Remove minting permission |
| `setBaseURI(string)` | Admin | Update metadata base URI |
| `setUseOnChainSVG(bool)` | Admin | Toggle between on-chain SVG and external URI rendering |

### DashboardNFT

| Function | Actor | Description |
|----------|-------|-------------|
| `setMintPrice(bytes32, uint256)` | Admin | Set purchase price for feature type |
| `setFeatureActive(bytes32, bool)` | Admin | Toggle feature purchasability |
| `setBaseURI(string)` | Admin | Update metadata base URI |
| `setRevenueReceiver(address)` | Admin | Change fee collection address |
| `withdraw()` | Admin | Transfer accumulated ETH to revenue receiver |

### Withdrawal Automation (Read-Only)

Batch eligibility checks for keeper automation are served off-chain by multicalling `VaultNFT.canDelegateWithdraw(tokenId, delegate)`; no on-chain helper contract exists.
