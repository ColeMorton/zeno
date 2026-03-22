# Achievements Specification

> **Version:** 3.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [The Ascent Design](./The_Ascent_Design.md) - Conceptual framework and visual design
> - [Holder Experience](./Holder_Experience.md)
> - [Integration Guide](./Integration_Guide.md)
> - [Technical Specification](../protocol/Technical_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architectural Note](#2-architectural-note)
3. [Achievement Definitions](#3-achievement-definitions)
4. [Contract Interfaces](#4-contract-interfaces)
5. [Claiming Mechanics](#5-claiming-mechanics)
6. [On-Chain Verification](#6-on-chain-verification)
7. [Integration Signals](#7-integration-signals)
8. [Extension Points](#8-extension-points)
9. [Name Mapping Reference](#9-name-mapping-reference)

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
| **Personal journey** | Altitude = days held, starts at mint timestamp |

### Achievement Properties

| Property | Value |
|----------|-------|
| Standard | ERC-5192 (Soulbound) |
| Transferable | No |
| Purpose | Recognize and attest wallet actions |
| Claiming | User-initiated, contract verifies state |
| Duplicate Prevention | One per wallet per achievement type |

### Achievement Summary

| Layer | Count | Purpose |
|-------|-------|---------|
| **Layer 1: The Ascent** | 9 | Personal journey based on holding duration |
| **Layer 2: Cohort Identity** | 0 | Visual only (no achievements) |
| **Layer 3: Launch Exclusives** | 5 | Issuer launch window only |
| **Layer 4: Community Milestones** | 6 | TVL milestones and referrals |
| **Total** | **20** | All issuer-layer contracts |

### Visual Role: Tier 0 Blueprint

Achievement NFTs represent the **base visual form** (Tier 0) of the token taxonomy:

| Property | Description |
|----------|-------------|
| **Simplest SVG** | Foundational artwork without wealth-based embellishments |
| **Design Blueprint** | Establishes visual vocabulary that Treasures inherit |
| **Merit-Only** | Visual enhancements come from actions, not collateral size |

**Important:** Achievements do NOT determine display tiers (Bronze/Silver/Gold). Display tiers are calculated from vault collateral percentile and applied to Treasure NFT visuals. See [Vault Percentile Specification](./Vault_Percentile_Specification.md) for tier details.

---

## 2. Architectural Note

**Critical distinction:** The BTCNFT Protocol is immutable and does NOT have an achievement system. ALL achievements—including those that track protocol-wide metrics like TVL—are deployed and managed by issuers.

```
+-------------------------------------------------------------------+
|  BTCNFT PROTOCOL (Immutable)                                      |
|  +- VaultNFT, BtcToken, etc.                                      |
|  +- No achievement system                                         |
|  +- Provides state that issuers READ (mintTimestamp, TVL, etc.)   |
+-------------------------------------------------------------------+
                              |
                              v reads state from
+-------------------------------------------------------------------+
|  ISSUER LAYER (Per-Issuer Deployment)                             |
|  +- AchievementNFT (issuer's soulbound tokens)                    |
|  +- AchievementMinter (issuer's claim logic)                      |
|  +- LaunchMinter (issuer's launch-window logic)                   |
|  +- ALL achievements are issued here                              |
+-------------------------------------------------------------------+
```

---

## 3. Achievement Definitions

### 3.1 Layer 1: The Ascent (Personal Journey) - 9 Achievements

#### Lifecycle Achievements

| Themed Name | Internal ID | Trigger | Tagline | Difficulty |
|-------------|-------------|---------|---------|------------|
| **CLIMBER** | `MINTER` | Own vault with issuer's Treasure | *"Began the ascent"* | Easy |
| **SUMMITER** | `MATURED` | Vested (1129d) + match claimed | *"Reached the peak"* | Hard |
| **MOUNTAINEER** | `HODLER_SUPREME` | CLIMBER + SUMMITER composite | *"Returns for another summit"* | Elite |

#### Altitude Achievements (Duration-Based)

| Themed Name | Internal ID | Days Held | Altitude | Tagline | Difficulty |
|-------------|-------------|-----------|----------|---------|------------|
| **TRAIL_HEAD** | `FIRST_MONTH` | 30 | 1000m | *"First steps taken"* | Easy |
| **BASE_CAMP** | `QUARTER_STACK` | 91 | 2000m | *"Established your position"* | Easy |
| **RIDGE_WALKER** | `HALF_YEAR` | 182 | 3000m | *"Above the tree line"* | Medium |
| **HIGH_CAMP** | `ANNUAL` | 365 | 4000m | *"Thin air, strong lungs"* | Medium |
| **SUMMIT_PUSH** | `DIAMOND_HANDS` | 730 | 5000m | *"The final ascent begins"* | Hard |
| **SUMMIT** | `TRIPLE_YEAR` | 1129 | 5895m | *"The peak is yours"* | Elite |

### 3.2 Layer 3: Launch Exclusives - 5 Achievements

#### Genesis Recognition

| Themed Name | Internal ID | Trigger | Supply | Tagline |
|-------------|-------------|---------|--------|---------|
| **FIRST_ASCENT** | `GENESIS_MINTER` | vaultId < 100 | Capped: 100 | *"Among the pioneering party"* |

**Genesis Class Sub-Tiers:**

| Class | Vault IDs | Themed Name | Tagline |
|-------|-----------|-------------|---------|
| Founder | 0-9 | **ROUTE_SETTER** | *"Marked the path where none existed"* |
| Early | 10-49 | **LEAD_CLIMBER** | *"Set the pace for those behind"* |
| Genesis | 50-99 | **FIRST_ASCENT** | *"Joined the pioneer party"* |

#### Timing Recognition

| Themed Name | Internal ID | Trigger | Tagline | Difficulty |
|-------------|-------------|---------|---------|------------|
| **DAWN_CLIMBER** | `LAUNCH_PIONEER` | Mint launch days 1-7 | *"Started at first light"* | Medium |
| **SECOND_PARTY** | `LAUNCH_WEEK_TWO` | Mint launch days 8-14 | *"Joined the second wave"* | Easy |
| **SPRING_EXPEDITION** | `LAUNCH_MONTH_ONE` | Mint launch days 1-30 | *"Departed in the first window"* | Easy |

#### Completion Recognition

| Themed Name | Internal ID | Trigger | Tagline | Difficulty |
|-------------|-------------|---------|---------|------------|
| **ACCLIMATIZED** | `LAUNCH_SURVIVOR` | Held vault through full launch period (90 days) | *"Adapted to the altitude"* | Hard |

### 3.3 Layer 4: Community Milestones - 6 Achievements

#### TVL Milestone Achievements

| Themed Name | Internal ID | Trigger | Tagline | Difficulty |
|-------------|-------------|---------|---------|------------|
| **FIRST_CAIRN** | `TVL_WITNESS_10` | Held vault when TVL crossed 10 BTC | *"Witnessed the first waypoint"* | Easy |
| **GROWING_PARTY** | `TVL_WITNESS_50` | Held vault when TVL crossed 50 BTC | *"Witnessed the expedition swell"* | Medium |
| **GRAND_EXPEDITION** | `TVL_WITNESS_100` | Held vault when TVL crossed 100 BTC | *"Witnessed a movement become legend"* | Hard |

#### Referral Achievements

| Themed Name | Internal ID | Trigger | Tagline | Difficulty |
|-------------|-------------|---------|---------|------------|
| **SHERPA** | `REFERRER_1` | Referred 1 new minter | *"Guided another to the mountain"* | Easy |
| **EXPEDITION_LEADER** | `REFERRER_5` | Referred 5 new minters | *"Led a party upward"* | Medium |
| **LEGENDARY_GUIDE** | `REFERRER_10` | Referred 10 new minters | *"Many summits owe their success to you"* | Hard |

---

## 4. Contract Interfaces

### 4.1 AchievementMinter Interface

```solidity
interface IAchievementMinter {
    // Layer 1: The Ascent (Personal Journey)
    function claimClimber(uint256 vaultId) external;
    function claimDurationAchievement(uint256 vaultId, bytes32 achievementType) external;
    function claimSummiter(uint256 vaultId) external;
    function mintMountaineerVault(address collateralToken, uint256 amount) external returns (uint256);

    // Layer 4: Community Milestones
    function claimFirstCairn(uint256 vaultId) external;
    function claimGrowingParty(uint256 vaultId) external;
    function claimGrandExpedition(uint256 vaultId) external;
    function claimSherpa() external;
    function claimExpeditionLeader() external;
    function claimLegendaryGuide() external;

    // Cohort queries (read-only)
    function getCohortId(uint256 vaultId) external view returns (uint256);
    function getCohortName(uint256 cohortId) external pure returns (string memory);

    // View functions
    function canClaimClimber(address wallet, uint256 vaultId)
        external view returns (bool canClaim, string memory reason);
    function canClaimDurationAchievement(address wallet, uint256 vaultId, bytes32 achievementType)
        external view returns (bool canClaim, string memory reason);
    function isDurationAchievement(bytes32 achievementType) external view returns (bool);
    function getDurationThreshold(bytes32 achievementType) external view returns (uint256);
}
```

### 4.2 LaunchMinter Interface

```solidity
interface ILaunchMinter {
    // Launch exclusives (time-limited)
    function launchStart() external view returns (uint256);
    function launchEnd() external view returns (uint256);
    function isLaunchActive() external view returns (bool);

    function claimFirstAscent(uint256 vaultId) external;
    function claimDawnClimber(uint256 vaultId) external;
    function claimSecondParty(uint256 vaultId) external;
    function claimSpringExpedition(uint256 vaultId) external;
    function claimAcclimatized(uint256 vaultId) external;

    // Genesis class
    function getGenesisClass(uint256 vaultId) external pure returns (GenesisClass);
}

enum GenesisClass { NONE, FIRST_ASCENT, LEAD_CLIMBER, ROUTE_SETTER }
```

### 4.3 Cohort Derivation

Cohorts are derived from `mintTimestamp`, not stored separately:

```solidity
function getCohortId(uint256 vaultId) public view returns (uint256) {
    uint256 mintTime = protocol.mintTimestamp(vaultId);
    // Year-month encoding: YYYYMM (e.g., 202510 for October 2025)
    return (timestampToYear(mintTime) * 100) + timestampToMonth(mintTime);
}

function getCohortName(uint256 cohortId) public pure returns (string memory) {
    uint256 year = cohortId / 100;
    uint256 month = cohortId % 100;
    string[12] memory months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return string.concat(months[month - 1], " ", Strings.toString(year), " Climbing Party");
}
```

### 4.4 TVL Recording

```solidity
// State storage in issuer's AchievementMinter contract
uint256 public firstCairnTimestamp;      // FIRST_CAIRN (10 BTC)
uint256 public growingPartyTimestamp;    // GROWING_PARTY (50 BTC)
uint256 public grandExpeditionTimestamp; // GRAND_EXPEDITION (100 BTC)

// Issuer records milestone when TVL threshold crossed
function recordTVLMilestone(uint256 level) external onlyOwner {
    if (level == 10 && firstCairnTimestamp == 0) {
        firstCairnTimestamp = block.timestamp;
        emit TVLMilestoneReached("FIRST_CAIRN", 10, block.timestamp);
    } else if (level == 50 && growingPartyTimestamp == 0) {
        growingPartyTimestamp = block.timestamp;
        emit TVLMilestoneReached("GROWING_PARTY", 50, block.timestamp);
    } else if (level == 100 && grandExpeditionTimestamp == 0) {
        grandExpeditionTimestamp = block.timestamp;
        emit TVLMilestoneReached("GRAND_EXPEDITION", 100, block.timestamp);
    }
}
```

### 4.5 Referral Tracking

```solidity
// Referral tracking in issuer's contract
mapping(address => uint256) public referralCount;
mapping(address => address) public referredBy;

// On successful mint with referral
function mintWithReferral(address referrer, ...) external {
    if (referrer != address(0) && referrer != msg.sender) {
        referralCount[referrer]++;
        referredBy[msg.sender] = referrer;
        emit ReferralRecorded(msg.sender, referrer);
    }
}
```

---

## 5. Claiming Mechanics

### 5.1 Claim Flow

```
1. User mints Vault on PROTOCOL with issuer's TreasureNFT
   +- No achievement yet (just protocol action)

2. User calls ISSUER claimClimber(vaultId)
   +- Contract verifies: vault uses issuer's Treasure
   +- Contract verifies: caller owns the vault
   +- Mints "CLIMBER" soulbound to wallet

3. User holds vault, claims duration achievements as milestones pass
   +- claimDurationAchievement(vaultId, TRAIL_HEAD) after 30 days
   +- claimDurationAchievement(vaultId, BASE_CAMP) after 91 days
   +- ... and so on through SUMMIT at 1129 days

4. After vesting (1129 days), user claims SUMMITER
   +- Contract verifies: wallet has CLIMBER
   +- Contract verifies: vault.isVested() && vault.matchClaimed
   +- Mints "SUMMITER" soulbound to wallet

5. User calls mintMountaineerVault() for composite reward
   +- Contract verifies: has CLIMBER AND SUMMITER
   +- Mints "MOUNTAINEER" soulbound + Treasure + Vault
   +- All atomic in single transaction
```

### 5.2 Prerequisite Rules

| Achievement | Prerequisites |
|-------------|---------------|
| SUMMITER | CLIMBER + vault vested + match claimed |
| MOUNTAINEER | CLIMBER + SUMMITER |
| Duration chain | Each requires previous level |
| ACCLIMATIZED | Held vault through full launch period |

### 5.3 Authorization Flow

```
+-------------------------------------------------------------------+
|                     AUTHORIZATION FLOW                             |
+-------------------------------------------------------------------+
|                                                                   |
|  1. Owner deploys AchievementMinter + LaunchMinter                |
|     +- Constructor: achievements_, treasureNFT_, protocol_        |
|                                                                   |
|  2. Owner authorizes minters on AchievementNFT                    |
|     +- achievements.authorizeMinter(achievementMinter)            |
|     +- achievements.authorizeMinter(launchMinter)                 |
|                                                                   |
|  3. Users claim achievements                                      |
|     +- achievementMinter.claimClimber(vaultId)                    |
|     +- launchMinter.claimFirstAscent(vaultId)                     |
|     +- Minters call achievements.mint(user, type)                 |
|                                                                   |
|  4. AchievementNFT mints soulbound token                          |
|     +- Emits Locked(tokenId) + AchievementEarned(...)             |
|                                                                   |
+-------------------------------------------------------------------+
```

---

## 6. On-Chain Verification

### 6.1 State Requirements

| Achievement | Verification |
|-------------|-------------|
| `CLIMBER` | `ownerOf(vaultId) == caller && treasureContract == issuerTreasure` |
| `SUMMITER` | `hasAchievement(CLIMBER) && isVested(vaultId) && matchClaimed(vaultId)` |
| `FIRST_ASCENT` | `vaultId < 100` |
| `TRAIL_HEAD` | `block.timestamp - mintTimestamp >= 30 days` |
| `BASE_CAMP` | `block.timestamp - mintTimestamp >= 91 days` |
| `RIDGE_WALKER` | `block.timestamp - mintTimestamp >= 182 days` |
| `HIGH_CAMP` | `block.timestamp - mintTimestamp >= 365 days` |
| `SUMMIT_PUSH` | `block.timestamp - mintTimestamp >= 730 days` |
| `SUMMIT` | `block.timestamp - mintTimestamp >= 1129 days` |
| `FIRST_CAIRN` | `mintTimestamp <= firstCairnTimestamp` |
| `SHERPA` | `referralCount[wallet] >= 1` |

### 6.2 Protocol State Available

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

### 6.3 Extended Storage

```solidity
// TVL milestone timestamps (permanent)
uint256 public firstCairnTimestamp;      // FIRST_CAIRN (10 BTC)
uint256 public growingPartyTimestamp;    // GROWING_PARTY (50 BTC)
uint256 public grandExpeditionTimestamp; // GRAND_EXPEDITION (100 BTC)

// Referral tracking
mapping(address => uint256) public referralCount;
mapping(address => address) public referredBy;

// Protocol state
uint256 public protocolLaunchTimestamp;
uint256 public totalMintCount;
```

---

## 7. Integration Signals

### 7.1 External Protocol Queries

```solidity
// Query functions for external integrations
function getAchievementScore(address wallet) external view returns (uint256);
function hasMinimumAchievements(address wallet, bytes32[] calldata required) external view returns (bool);
function getWalletAchievements(address wallet) external view returns (bytes32[] memory);
function hasAchievementOfType(address wallet, bytes32 type_) external view returns (bool);
```

### 7.2 Use Cases

| Protocol | Achievement Signal | Benefit |
|----------|-------------------|---------|
| Lending (Aave) | `SUMMITER` | Better LTV for vestedBTC |
| NFT Marketplaces | Achievement count | Featured seller status |
| DAO Governance | `MOUNTAINEER` | Voting weight multiplier |
| Airdrops | Duration achievements | Allocation tier |
| Gaming/Social | Any achievement | Badge display, profile flair |

### 7.3 Events for Indexing

```solidity
// Achievement events
event AchievementEarned(
    address indexed wallet,
    uint256 indexed tokenId,
    bytes32 indexed achievementType
);

event Locked(uint256 indexed tokenId);  // ERC-5192

// TVL milestone events
event TVLMilestoneReached(
    string indexed milestoneName,
    uint256 level,
    uint256 timestamp
);

// Referral events
event ReferralRecorded(
    address indexed referred,
    address indexed referrer
);
```

### 7.4 Metadata Standards

Achievement tokens expose rich metadata for external consumption:

```json
{
  "name": "BTCNFT Achievement: Summit Push",
  "description": "Held a vault for 730+ days - The final ascent begins",
  "image": "ipfs://Qm.../summit-push.png",
  "attributes": [
    { "trait_type": "Category", "value": "Duration" },
    { "trait_type": "Themed Name", "value": "SUMMIT_PUSH" },
    { "trait_type": "Tagline", "value": "The final ascent begins" },
    { "trait_type": "Difficulty", "value": "Hard" },
    { "trait_type": "Altitude", "value": "5000m" },
    { "trait_type": "Days Held", "display_type": "number", "value": 730 },
    { "trait_type": "Earned At", "display_type": "date", "value": 1703980800 }
  ],
  "external_url": "https://btcnft.protocol/achievements/summit-push"
}
```

---

## 8. Extension Points

### 8.1 Custom Achievement Types

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

### 8.2 Planned Achievements (Future)

#### Extended Duration

```solidity
bytes32 constant FIVE_YEAR = keccak256("FIVE_YEAR");   // 1825 days
bytes32 constant DECADE = keccak256("DECADE");         // 3650 days
```

#### Activity

```solidity
bytes32 constant FIRST_WITHDRAWAL = keccak256("FIRST_WITHDRAWAL");
bytes32 constant WITHDRAWAL_STREAK_3 = keccak256("WITHDRAWAL_STREAK_3");
bytes32 constant WITHDRAWAL_STREAK_6 = keccak256("WITHDRAWAL_STREAK_6");
bytes32 constant WITHDRAWAL_STREAK_12 = keccak256("WITHDRAWAL_STREAK_12");
bytes32 constant COMPOUNDER = keccak256("COMPOUNDER");
```

#### Collection

```solidity
bytes32 constant DUAL_VAULT = keccak256("DUAL_VAULT");     // 2+ vaults
bytes32 constant TRIPLE_VAULT = keccak256("TRIPLE_VAULT"); // 3+ vaults
bytes32 constant COLLECTOR_5 = keccak256("COLLECTOR_5");   // 5+ vaults
```

### 8.3 Authorization Model

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

### 8.4 No-Pay-to-Win Guarantee

All achievements provide cosmetic recognition only:

| What Achievements Provide | What Achievements Do NOT Provide |
|---------------------------|----------------------------------|
| Soulbound NFT attestation | Better withdrawal rates |
| Community prestige | Increased collateral matching |
| Leaderboard eligibility | Priority access |
| External protocol signals | Protocol fee discounts |
| Profile customization | Governance advantages |

---

## 9. Name Mapping Reference

| Internal ID | Themed Name | Tagline |
|-------------|-------------|---------|
| `MINTER` | CLIMBER | *"Began the ascent"* |
| `FIRST_MONTH` | TRAIL_HEAD | *"First steps taken"* |
| `QUARTER_STACK` | BASE_CAMP | *"Established your position"* |
| `HALF_YEAR` | RIDGE_WALKER | *"Above the tree line"* |
| `ANNUAL` | HIGH_CAMP | *"Thin air, strong lungs"* |
| `DIAMOND_HANDS` | SUMMIT_PUSH | *"The final ascent begins"* |
| `TRIPLE_YEAR` | SUMMIT | *"The peak is yours"* |
| `MATURED` | SUMMITER | *"Reached the peak"* |
| `HODLER_SUPREME` | MOUNTAINEER | *"Returns for another summit"* |
| `TVL_WITNESS_10` | FIRST_CAIRN | *"Witnessed the first waypoint"* |
| `TVL_WITNESS_50` | GROWING_PARTY | *"Witnessed the expedition swell"* |
| `TVL_WITNESS_100` | GRAND_EXPEDITION | *"Witnessed a movement become legend"* |
| `REFERRER_1` | SHERPA | *"Guided another to the mountain"* |
| `REFERRER_5` | EXPEDITION_LEADER | *"Led a party upward"* |
| `REFERRER_10` | LEGENDARY_GUIDE | *"Many summits owe their success to you"* |
| `GENESIS_MINTER` | FIRST_ASCENT | *"Among the pioneering party"* |
| `LAUNCH_PIONEER` | DAWN_CLIMBER | *"Started at first light"* |
| `LAUNCH_WEEK_TWO` | SECOND_PARTY | *"Joined the second wave"* |
| `LAUNCH_MONTH_ONE` | SPRING_EXPEDITION | *"Departed in the first window"* |
| `LAUNCH_SURVIVOR` | ACCLIMATIZED | *"Adapted to the altitude"* |

---

## Navigation

[Issuer Layer](./README.md) | [The Ascent Design](./The_Ascent_Design.md) | [Integration Guide](./Integration_Guide.md)
