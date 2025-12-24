# Achievements Specification

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-22
> **Related Documents:**
> - [Holder Experience](./Holder_Experience.md)
> - [Integration Guide](./Integration_Guide.md)
> - [Technical Specification](../protocol/Technical_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Achievement Types](#2-achievement-types)
3. [Achievement Mechanics](#3-achievement-mechanics)
4. [On-Chain Verification](#4-on-chain-verification)
5. [Campaigns & Seasons](#5-campaigns--seasons)
6. [Integration Signals](#6-integration-signals)
7. [Extension Points](#7-extension-points)

---

## 1. Overview

### Design Principles

| Principle | Description |
|-----------|-------------|
| **Soulbound** | ERC-5192 non-transferable tokens |
| **Merit-based** | Earned through on-chain actions, not purchased |
| **Cosmetic-only** | No rate/reward advantages |
| **Verifiable** | All claims verified against on-chain state |
| **Extensible** | bytes32 identifiers enable new types without redeployment |

### Achievement Properties

| Property | Value |
|----------|-------|
| Standard | ERC-5192 (Soulbound) |
| Transferable | No |
| Purpose | Recognize and attest wallet actions |
| Claiming | User-initiated, contract verifies state |
| Duplicate Prevention | One per wallet per achievement type |

### Achievement Categories

| Category | Focus | Issuer Objective |
|----------|-------|------------------|
| **Lifecycle** | Vault creation/maturation | Increase demand |
| **Duration** | Time-based holding | Reduce dormancy |
| **Activity** | Withdrawal/engagement | Increase usage |
| **Social** | Delegation/community | Build services |
| **Collection** | Multi-vault ownership | Platform integration |
| **Campaign** | Time-limited seasonal | Tactical participation |

### Visual Role: Tier 0 Blueprint

Achievement NFTs represent the **base visual form** (Tier 0) of the token taxonomy:

| Property | Description |
|----------|-------------|
| **Simplest SVG** | Foundational artwork without wealth-based embellishments |
| **Design Blueprint** | Establishes visual vocabulary that Treasures inherit |
| **Merit-Only** | Visual enhancements come from actions, not collateral size |

**Important:** Achievements do NOT determine display tiers (Bronze/Silver/Gold). Display tiers are calculated from vault collateral percentile and applied to Treasure NFT visuals. See [Vault Percentile Specification](./Vault_Percentile_Specification.md) for tier details.

Merit (achievements) and wealth (percentile tiers) are **orthogonal** systems.

---

## 2. Achievement Types

### 2.1 Implemented Achievements

#### Core Achievements

| Achievement | Requirement | Claim Function |
|-------------|-------------|----------------|
| **MINTER** | Own vault with issuer's Treasure | `claimMinterAchievement(vaultId)` |
| **MATURED** | MINTER + vault vested + match claimed | `claimMaturedAchievement(vaultId)` |
| **HODLER_SUPREME** | MINTER + MATURED (composite) | `mintHodlerSupremeVault(...)` |

#### Duration Achievements

| Achievement | Duration | Claim Function |
|-------------|----------|----------------|
| **FIRST_MONTH** | 30 days | `claimDurationAchievement(vaultId, FIRST_MONTH)` |
| **QUARTER_STACK** | 91 days | `claimDurationAchievement(vaultId, QUARTER_STACK)` |
| **HALF_YEAR** | 182 days | `claimDurationAchievement(vaultId, HALF_YEAR)` |
| **ANNUAL** | 365 days | `claimDurationAchievement(vaultId, ANNUAL)` |
| **DIAMOND_HANDS** | 730 days | `claimDurationAchievement(vaultId, DIAMOND_HANDS)` |

### 2.2 Planned Achievements

#### Lifecycle Achievements

```solidity
bytes32 constant GENESIS_MINTER = keccak256("GENESIS_MINTER");   // First 100 minters
bytes32 constant EARLY_ADOPTER = keccak256("EARLY_ADOPTER");     // First 30 days of protocol
bytes32 constant MATCH_CLAIMER = keccak256("MATCH_CLAIMER");     // Claimed collateral match
bytes32 constant FULL_CYCLE = keccak256("FULL_CYCLE");           // Completed 12 withdrawal cycles
```

#### Extended Duration Achievements

```solidity
bytes32 constant TRIPLE_YEAR = keccak256("TRIPLE_YEAR");         // 1129 days
bytes32 constant FIVE_YEAR = keccak256("FIVE_YEAR");             // 1825 days
bytes32 constant DECADE = keccak256("DECADE");                   // 3650 days
```

#### Activity Achievements

```solidity
bytes32 constant FIRST_WITHDRAWAL = keccak256("FIRST_WITHDRAWAL");       // First post-vesting withdrawal
bytes32 constant WITHDRAWAL_STREAK_3 = keccak256("WITHDRAWAL_STREAK_3"); // 3 consecutive monthly withdrawals
bytes32 constant WITHDRAWAL_STREAK_6 = keccak256("WITHDRAWAL_STREAK_6"); // 6 consecutive
bytes32 constant WITHDRAWAL_STREAK_12 = keccak256("WITHDRAWAL_STREAK_12"); // 12 consecutive
bytes32 constant COMPOUNDER = keccak256("COMPOUNDER");                   // Re-minted vault using withdrawals
bytes32 constant VESTEDBTC_MINTER = keccak256("VESTEDBTC_MINTER");       // Minted vestedBTC from vault
bytes32 constant VESTEDBTC_RETURNER = keccak256("VESTEDBTC_RETURNER");   // Returned vestedBTC to vault
bytes32 constant ACTIVITY_PROVEN = keccak256("ACTIVITY_PROVEN");         // Responded to dormancy poke
```

#### Social/Delegation Achievements

```solidity
bytes32 constant DELEGATOR = keccak256("DELEGATOR");                     // Granted withdrawal delegation
bytes32 constant MULTI_DELEGATOR = keccak256("MULTI_DELEGATOR");         // Delegated to 3+ addresses
bytes32 constant BENEFACTOR = keccak256("BENEFACTOR");                   // Delegated >50% withdrawal rights
bytes32 constant DELEGATE_RECEIVER = keccak256("DELEGATE_RECEIVER");     // Received delegation
bytes32 constant DELEGATE_WITHDRAWER = keccak256("DELEGATE_WITHDRAWER"); // Executed delegated withdrawal
bytes32 constant POKER = keccak256("POKER");                             // Poked a dormant vault
bytes32 constant DORMANT_CLAIMER = keccak256("DORMANT_CLAIMER");         // Claimed dormant collateral
```

#### Collection Achievements

```solidity
bytes32 constant DUAL_VAULT = keccak256("DUAL_VAULT");                   // 2+ vaults
bytes32 constant TRIPLE_VAULT = keccak256("TRIPLE_VAULT");               // 3+ vaults
bytes32 constant COLLECTOR_5 = keccak256("COLLECTOR_5");                 // 5+ vaults
bytes32 constant COLLECTOR_10 = keccak256("COLLECTOR_10");               // 10+ vaults
bytes32 constant COLLATERAL_MILESTONE_1 = keccak256("COLLATERAL_MILESTONE_1");   // >= 1 BTC total
bytes32 constant COLLATERAL_MILESTONE_10 = keccak256("COLLATERAL_MILESTONE_10"); // >= 10 BTC total
```

#### Campaign/Seasonal Achievements

```solidity
bytes32 constant SEASON_1_PARTICIPANT = keccak256("SEASON_1_PARTICIPANT");     // Active during S1 (Days 0-365)
bytes32 constant SEASON_1_SURVIVOR = keccak256("SEASON_1_SURVIVOR");           // Held through S1
bytes32 constant FIRST_MATURITY_WITNESS = keccak256("FIRST_MATURITY_WITNESS"); // Present when first vault matured
bytes32 constant TVL_MILESTONE_WITNESS = keccak256("TVL_MILESTONE_WITNESS");   // Present at TVL milestone
```

---

## 3. Achievement Mechanics

### 3.1 Claiming Process

#### Claim Flow

```
1. User mints Vault on PROTOCOL with issuer's TreasureNFT
   └─ No achievement yet (just protocol action)

2. User calls ISSUER claimMinterAchievement(vaultId)
   ├─ Contract verifies: vault uses issuer's Treasure
   ├─ Contract verifies: caller owns the vault
   └─ Mints "MINTER" soulbound to wallet

3. User holds vault, claims duration achievements as milestones pass
   └─ claimDurationAchievement(vaultId, FIRST_MONTH) after 30 days
   └─ claimDurationAchievement(vaultId, QUARTER_STACK) after 91 days
   └─ ... and so on

4. After vesting (1129 days), user claims MATURED
   ├─ Contract verifies: wallet has MINTER
   ├─ Contract verifies: vault.isVested() && vault.matchClaimed
   └─ Mints "MATURED" soulbound to wallet

5. User calls mintHodlerSupremeVault() for composite reward
   ├─ Contract verifies: has MINTER AND MATURED
   ├─ Mints "HODLER_SUPREME" soulbound + Treasure + Vault
   └─ All atomic in single transaction
```

#### AchievementMinter Interface

```solidity
interface IAchievementMinter {
    // Achievement claiming
    function claimMinterAchievement(uint256 vaultId) external;
    function claimMaturedAchievement(uint256 vaultId) external;
    function claimDurationAchievement(uint256 vaultId, bytes32 achievementType) external;

    // Composite vault minting
    function mintHodlerSupremeVault(
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 vaultId);

    // View functions
    function canClaimMinterAchievement(address wallet, uint256 vaultId)
        external view returns (bool canClaim, string memory reason);
    function canClaimMaturedAchievement(address wallet, uint256 vaultId)
        external view returns (bool canClaim, string memory reason);
    function canClaimDurationAchievement(address wallet, uint256 vaultId, bytes32 achievementType)
        external view returns (bool canClaim, string memory reason);
    function canMintHodlerSupremeVault(address wallet)
        external view returns (bool canMint, string memory reason);

    // Duration helpers
    function isDurationAchievement(bytes32 achievementType) external view returns (bool);
    function getDurationThreshold(bytes32 achievementType) external view returns (uint256);
}
```

### 3.2 Dependencies

#### Dependency Graph

```
                            MINTER
                               │
                ┌──────────────┼──────────────┐
                │              │              │
           FIRST_MONTH    DELEGATOR      GENESIS_MINTER
                │              │         (if vaultId < 100)
                ▼              ▼
         QUARTER_STACK    MULTI_DELEGATOR
                │         (3+ delegates)
                ▼
           HALF_YEAR
                │
                ▼
            ANNUAL
                │
                ▼
         DIAMOND_HANDS
                │
    ┌───────────┼───────────┐
    │           │           │
    ▼           ▼           ▼
MATURED    TRIPLE_YEAR  FIRST_WITHDRAWAL
    │           │           │
    │           ▼           ▼
    │      FIVE_YEAR  WITHDRAWAL_STREAK_3
    │           │           │
    │           ▼           ▼
    │       DECADE    WITHDRAWAL_STREAK_6
    │                       │
    │                       ▼
    │               WITHDRAWAL_STREAK_12
    │                       │
    └───────────┬───────────┘
                ▼
         HODLER_SUPREME
                │
                ▼
         (Unlocks new vault minting)
```

#### Prerequisite Rules

| Achievement | Prerequisites |
|-------------|---------------|
| MATURED | MINTER + vault vested + match claimed |
| HODLER_SUPREME | MINTER + MATURED |
| FIRST_WITHDRAWAL | Vault must be vested |
| WITHDRAWAL_STREAK_3 | FIRST_WITHDRAWAL + 3 consecutive withdrawals |
| WITHDRAWAL_STREAK_6 | WITHDRAWAL_STREAK_3 |
| WITHDRAWAL_STREAK_12 | WITHDRAWAL_STREAK_6 |
| MULTI_DELEGATOR | DELEGATOR |
| TRIPLE_VAULT | DUAL_VAULT |
| COLLECTOR_5 | TRIPLE_VAULT |
| COLLECTOR_10 | COLLECTOR_5 |
| Duration chain | Each requires previous level |

### 3.3 Vault Stacking Flywheel

```
┌─────────────────────────────────────────────────────────────────┐
│                    VAULT STACKING FLYWHEEL                      │
│                                                                 │
│  ┌──────────┐   ┌─────────────┐   ┌─────────────┐               │
│  │ Mint     │──▶│ Vault #1    │──▶│ Claim       │               │
│  │ Vault    │   │ + Treasure  │   │ Achievements│               │
│  └──────────┘   └─────────────┘   └──────┬──────┘               │
│       ▲                                  │                      │
│       │                                  ▼                      │
│       │         ┌─────────────────────────────────┐             │
│       └─────────│ mintHodlerSupremeVault()        │             │
│                 │ → Requires MINTER + MATURED     │             │
│                 │ → Mints new Vault atomically    │             │
│                 └─────────────────────────────────┘             │
│                                                                 │
│  Growth Mechanics:                                              │
│  ├─ Each Vault generates achievements over time                │
│  ├─ Achievements unlock composite minting opportunities        │
│  └─ Compounding: more time = more achievements = more Vaults   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. On-Chain Verification

### 4.1 State Requirements

| Achievement | Verification |
|-------------|-------------|
| `MINTER` | `ownerOf(vaultId) == caller && treasureContract == issuerTreasure` |
| `MATURED` | `hasAchievement(MINTER) && isVested(vaultId) && matchClaimed(vaultId)` |
| `GENESIS_MINTER` | `vaultId < 100` |
| `EARLY_ADOPTER` | `mintTimestamp < protocolLaunch + 30 days` |
| `MATCH_CLAIMER` | `matchClaimed[vaultId] == true` |
| `FIRST_WITHDRAWAL` | `lastWithdrawal > 0 AND isVested` |
| `WITHDRAWAL_STREAK_*` | Counter per vault tracking consecutive withdrawals |
| `DELEGATOR` | `totalDelegatedBPS[vaultId] > 0` |
| `MULTI_DELEGATOR` | Active delegate count >= 3 |
| `DUAL_VAULT` | `vaultCountByOwner[wallet] >= 2` |

### 4.2 Protocol State Available

```solidity
// From IVaultState (protocol)
function getVaultInfo(uint256 tokenId) external view returns (
    address treasureContract,
    uint256 treasureTokenId,
    address collateralToken,
    uint256 collateralAmount,
    uint256 mintTimestamp,
    uint256 lastWithdrawal,
    uint256 lastActivity,
    uint256 btcTokenAmount,
    uint256 originalMintedAmount
);

function isVested(uint256 tokenId) external view returns (bool);
function matchClaimed(uint256 tokenId) external view returns (bool);
function ownerOf(uint256 tokenId) external view returns (address);
```

### 4.3 Extended Storage (for planned achievements)

```solidity
// Streak tracking
mapping(uint256 => uint256) public withdrawalStreakCount;
mapping(uint256 => uint256) public lastStreakWithdrawal;

// Collection tracking
mapping(address => uint256[]) public walletVaults;

// Protocol state
uint256 public protocolLaunchTimestamp;
uint256 public totalMintCount;
```

---

## 5. Campaigns & Seasons

### 5.1 Campaign System

#### Campaign Structure

```solidity
struct Campaign {
    bytes32 campaignId;
    uint256 startTimestamp;
    uint256 endTimestamp;
    bytes32 achievementType;
    bytes32 requiredBaseAchievement;
    uint256 targetCount;
    bool isActive;
}
```

#### Campaign Types

| Type | Trigger | Example Reward |
|------|---------|----------------|
| **Milestone** | TVL reaches target | Commemorative badge |
| **First-N** | First N to complete action | "Pioneer" badge |
| **Seasonal** | Time-limited competition | "Top Referrer" badge |
| **Partner** | Use vestedBTC in partner protocol | Token airdrop + "DeFi Pioneer" badge |

#### Campaign Examples

| Campaign | Metric | Reward |
|----------|--------|--------|
| TVL Milestone | Total collateral reaches target | Commemorative badge |
| First Maturity | First Vault completes vesting | "Witness" badge |
| Referral Race | Referral code usage | "Top Referrer" badge |
| Retention Royale | Lowest % referrals that redeem early | "Quality Connector" badge |
| Compound Championship | % withdrawals re-minted | "Master Compounder" badge |

### 5.2 Seasons

#### Season Alignment with Vesting

| Season | Days | Focus |
|--------|------|-------|
| Genesis (S1) | 0-365 | Early adoption |
| Conviction (S2) | 366-730 | Retention |
| Maturity (S3) | 731-1129 | First maturities |
| Perpetual (S4+) | 1130+ | Sustainable growth |

Seasons align with the 1129-day vesting period to create natural engagement cadences.

### 5.3 Leaderboards

#### Merit vs Vanity Separation

| Leaderboard | Metric | Type |
|-------------|--------|------|
| Longest Hold | Days held (single vault) | Merit |
| Achievement Hunter | Total achievements earned | Merit |
| Streak Master | Longest withdrawal streak | Merit |
| Collector | Number of vaults owned | Merit |
| Whale Watch | Total BTC collateral | Vanity (separate) |

**Critical:** Merit and vanity leaderboards must be SEPARATE.

> **Note:** Vanity tiers (Bronze/Silver/Gold/Diamond/Whale) are NOT achievements. They are automatically assigned based on collateral percentile ranking and are documented in the [Vault Percentile Specification](./Vault_Percentile_Specification.md).

---

## 6. Integration Signals

### 6.1 External Protocol Queries

```solidity
// Query functions for external integrations
function getAchievementScore(address wallet) external view returns (uint256);
function hasMinimumAchievements(address wallet, bytes32[] calldata required) external view returns (bool);
function getWalletAchievements(address wallet) external view returns (bytes32[] memory);
function hasAchievementOfType(address wallet, bytes32 type_) external view returns (bool);
```

### 6.2 Use Cases

| Protocol | Achievement Signal | Benefit |
|----------|-------------------|---------|
| Lending (Aave) | `MATURED` | Better LTV for vestedBTC |
| NFT Marketplaces | Achievement count | Featured seller status |
| DAO Governance | `HODLER_SUPREME` | Voting weight multiplier |
| Airdrops | Duration achievements | Allocation tier |
| Gaming/Social | Any achievement | Badge display, profile flair |

### 6.3 Events for Indexing

```solidity
// Achievement events
event AchievementEarned(
    address indexed wallet,
    uint256 indexed tokenId,
    bytes32 indexed achievementType
);

event Locked(uint256 indexed tokenId);  // ERC-5192

// Extended tracking events (planned)
event WithdrawalStreakUpdated(uint256 indexed vaultId, uint256 newStreakCount);
event CollectionMilestoneReached(address indexed wallet, bytes32 indexed milestoneType, uint256 vaultCount);
event CampaignAchievementClaimed(address indexed wallet, bytes32 indexed campaignId, bytes32 indexed achievementType);
```

### 6.4 Metadata Standards

Achievement tokens expose rich metadata for external consumption:

```json
{
  "name": "BTCNFT Achievement: Diamond Hands",
  "description": "Held a vault for 730+ days",
  "image": "ipfs://Qm.../diamond-hands.png",
  "attributes": [
    { "trait_type": "Category", "value": "Duration" },
    { "trait_type": "Rarity", "value": "Uncommon" },
    { "trait_type": "Earned At", "display_type": "date", "value": 1703980800 }
  ],
  "external_url": "https://btcnft.protocol/achievements/diamond-hands"
}
```

---

## 7. Extension Points

### 7.1 Custom Achievement Types

Issuers can extend achievements using the bytes32-based system:

```solidity
// Define new achievement type
bytes32 constant CUSTOM_ACHIEVEMENT = keccak256("CUSTOM_ACHIEVEMENT");

// Add to authorized minter
function claimCustomAchievement(uint256 vaultId) external {
    // Custom verification logic
    require(customConditionMet(vaultId), "Condition not met");

    // Mint via AchievementNFT
    achievements.mint(msg.sender, CUSTOM_ACHIEVEMENT);
}
```

### 7.2 Issuer Deployment Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                      ISSUER ACHIEVEMENT STACK                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Protocol Layer (Shared):                                       │
│  └─ VaultNFT (state source for verification)                   │
│                                                                 │
│  Issuer Layer (Per-Issuer Deployment):                         │
│  ├─ AchievementNFT (issuer's soulbound tokens)                 │
│  ├─ AchievementMinter (issuer's claim logic)                   │
│  │   ├─ Core achievements (MINTER, MATURED, etc.)              │
│  │   ├─ Duration achievements                                   │
│  │   └─ Custom issuer-specific achievements                    │
│  └─ TreasureNFT (issuer's treasure collection)                 │
│                                                                 │
│  Configuration:                                                 │
│  ├─ achievements: Address of AchievementNFT                    │
│  ├─ treasureNFT: Address of issuer's TreasureNFT               │
│  └─ protocol: Address of VaultNFT (shared)                     │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 Authorization Model

```solidity
// AchievementNFT authorizes minters
function authorizeMinter(address minter) external onlyOwner;
function revokeMinter(address minter) external onlyOwner;

// Only authorized minters can mint achievements
modifier onlyAuthorizedMinter() {
    if (!authorizedMinters[msg.sender]) {
        revert NotAuthorizedMinter(msg.sender);
    }
    _;
}
```

### 7.4 No-Pay-to-Win Guarantee

All achievements provide cosmetic recognition only:

| What Achievements Provide | What Achievements Do NOT Provide |
|---------------------------|----------------------------------|
| Soulbound NFT attestation | Better withdrawal rates |
| Community prestige | Increased collateral matching |
| Leaderboard eligibility | Priority access |
| External protocol signals | Protocol fee discounts |
| Profile customization | Governance advantages |

---

## Related Documents

| Topic | Document |
|-------|----------|
| User journey with achievements | [Holder Experience](./Holder_Experience.md) |
| Issuer integration patterns | [Integration Guide](./Integration_Guide.md) |
| Contract mechanics | [Technical Specification](../protocol/Technical_Specification.md) |
