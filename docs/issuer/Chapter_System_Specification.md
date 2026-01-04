# Chapter System Specification

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-31
> **Related Documents:**
> - [The Ascent Design](./The_Ascent_Design.md) - Conceptual framework and visual design
> - [Achievements Specification](./Achievements_Specification.md) - Perpetual journey achievements
> - [Glossary](../GLOSSARY.md) - Chapter terminology definitions

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Contract Specifications](#3-contract-specifications)
4. [Chapter-to-Journey Mapping](#4-chapter-to-journey-mapping)
5. [Claiming Mechanics](#5-claiming-mechanics)
6. [Skill Tree Prerequisites](#6-skill-tree-prerequisites)
7. [Map Asset Storage](#7-map-asset-storage)
8. [Chapter 1 Achievements](#8-chapter-1-achievements)
9. [Admin Workflow](#9-admin-workflow)
10. [Verifier Architecture](#10-verifier-architecture)
11. [Education System](#11-education-system)

---

## 1. Overview

### Design Principles

| Principle | Description |
|-----------|-------------|
| **Layered alongside** | Chapters complement (not replace) perpetual personal journey |
| **Hybrid eligibility** | Calendar quarters + journey day range gates |
| **Permanent scarcity** | Achievements lock forever when quarter ends |
| **Soulbound** | ERC-5192 non-transferable tokens |
| **Versioned content** | Each quarter brings fresh achievements for each chapter |

### Chapter Properties

| Property | Value |
|----------|-------|
| Total Chapters | 12 |
| Standard Duration | 91 days (1 quarter) |
| Chapter 12 Duration | 128 days (extended to complete 1129-day journey) |
| Achievement Standard | ERC-721 + ERC-5192 (soulbound) |
| Transferable | No |

### Relationship to Personal Journey

```
+------------------------------------------------------------------+
|  PERPETUAL PERSONAL JOURNEY (Existing System)                     |
|  +- AchievementNFT, AchievementMinter                            |
|  +- Altitude achievements based on days held                      |
|  +- No time windows - claimable any time once earned             |
+------------------------------------------------------------------+
                           ↕ layers alongside
+------------------------------------------------------------------+
|  CHAPTER SYSTEM (New)                                             |
|  +- ChapterAchievementNFT, ChapterMinter, ChapterRegistry        |
|  +- Calendar quarter time windows (permanent lock after)          |
|  +- Journey gates (must be within chapter's day range)           |
|  +- Skill tree prerequisites within each chapter                  |
+------------------------------------------------------------------+
```

---

## 2. Architecture

### Contract Structure

```
contracts/issuer/src/
├── ChapterRegistry.sol          # Chapter configs, versions, achievement definitions
├── ChapterMinter.sol            # Time-window + journey-gate enforcement
├── ChapterAchievementNFT.sol    # ERC-5192 soulbound NFTs
├── ChapterAchievementSVG.sol    # On-chain SVG generation library
└── interfaces/
    ├── IChapterRegistry.sol
    ├── IChapterMinter.sol
    └── IChapterAchievementNFT.sol
```

### Contract Roles

| Contract | Purpose |
|----------|---------|
| **ChapterRegistry** | Stores chapter configs, achievement definitions, and validation logic |
| **ChapterMinter** | Verifies eligibility and triggers minting |
| **ChapterAchievementNFT** | ERC-721 token with soulbound restrictions |
| **ChapterAchievementSVG** | On-chain SVG generation for token metadata |

### Dependencies

```
ChapterMinter
    ├── reads from ChapterRegistry (chapter configs, achievements)
    ├── calls ChapterAchievementNFT.mint()
    ├── reads from VaultNFT (ownership, mint timestamp, treasure contract)
    └── references issuer's TreasureNFT address
```

---

## 3. Contract Specifications

### 3.1 ChapterRegistry

#### ChapterConfig Struct

```solidity
struct ChapterConfig {
    uint8 chapterNumber;       // 1-12
    uint48 startTimestamp;     // Calendar quarter start
    uint48 endTimestamp;       // Calendar quarter end (permanent lock)
    uint16 year;               // Calendar year (e.g., 2025)
    uint8 quarter;             // Calendar quarter (1-4)
    uint256 minDaysHeld;       // Journey gate minimum
    uint256 maxDaysHeld;       // Journey gate maximum
    string achievementBaseURI; // IPFS base URI for high-res images
    bool active;               // Emergency pause flag
}
```

#### ChapterAchievement Struct

```solidity
struct ChapterAchievement {
    bytes32 achievementId;     // Full encoded ID
    string name;               // Display name
    bytes32[] prerequisites;   // Skill-tree dependencies
}
```

#### ID Generation

| Type | Format | Example |
|------|--------|---------|
| Chapter ID | `keccak256("CH", number, "_", year, "Q", quarter)` | CH1_2025Q1 |
| Achievement ID | `keccak256(chapterId, "_", name)` | CH1_2025Q1_FIRST_STEPS |

#### Key Functions

| Function | Purpose |
|----------|---------|
| `createChapter()` | Create a new chapter version |
| `addAchievement()` | Add achievement to chapter |
| `setChapterActive()` | Emergency pause/unpause |
| `isEligible()` | Check journey gate |
| `isWithinMintWindow()` | Check calendar window |

### 3.2 ChapterMinter

#### Verification Flow

```
claimChapterAchievement(chapterId, achievementId, vaultId, collateralToken)
    │
    ├─ 1. Time window check
    │      if (block.timestamp < startTimestamp) revert MintWindowNotOpen
    │      if (block.timestamp > endTimestamp) revert MintWindowClosed
    │
    ├─ 2. Chapter active check
    │      if (!config.active) revert ChapterNotActive
    │
    ├─ 3. Vault ownership check
    │      if (vaultNFT.ownerOf(vaultId) != msg.sender) revert NotVaultOwner
    │
    ├─ 4. Treasure contract check
    │      if (vaultNFT.treasureContract(vaultId) != issuerTreasure) revert VaultNotUsingIssuerTreasure
    │
    ├─ 5. Journey gate check
    │      daysHeld = (block.timestamp - mintTimestamp) / 1 days
    │      if (daysHeld < minDaysHeld) revert JourneyProgressInsufficient
    │      if (daysHeld > maxDaysHeld) revert JourneyProgressExceeded
    │
    ├─ 6. Prerequisites check
    │      for each prerequisite:
    │          if (!achievementNFT.hasAchievement(msg.sender, prereq)) revert PrerequisiteNotMet
    │
    └─ 7. Mint achievement
           achievementNFT.mint(msg.sender, achievementId, chapterId)
```

#### Error Codes

| Error | Cause |
|-------|-------|
| `MintWindowNotOpen` | Current time before chapter start |
| `MintWindowClosed` | Current time after chapter end (permanent) |
| `ChapterNotActive` | Emergency pause enabled |
| `JourneyProgressInsufficient` | Holder hasn't reached chapter's day range |
| `JourneyProgressExceeded` | Holder has progressed beyond chapter's range |
| `PrerequisiteNotMet` | Required achievement not earned |
| `NotVaultOwner` | Caller doesn't own the vault |
| `VaultNotUsingIssuerTreasure` | Vault uses different issuer's treasure |
| `UnsupportedCollateral` | Collateral token not configured |

### 3.3 ChapterAchievementNFT

#### ERC-5192 Soulbound Implementation

| Feature | Implementation |
|---------|----------------|
| Transfer blocking | Overrides `_update()` to revert on transfers |
| Lock status | `locked(tokenId)` always returns `true` |
| Lock event | `Locked(tokenId)` emitted on mint |

#### Key Mappings

```solidity
mapping(uint256 => bytes32) public achievementType;   // tokenId => achievementId
mapping(uint256 => bytes32) public tokenChapter;      // tokenId => chapterId
mapping(address => mapping(bytes32 => bool)) public hasAchievement;
```

#### Metadata

| Mode | Description |
|------|-------------|
| External URI | `{baseURI}{tokenId}` for off-chain metadata |
| On-chain SVG | `ChapterAchievementSVG.generateSVG()` for fully on-chain |

---

## 4. Chapter-to-Journey Mapping

Each chapter corresponds to a segment of the 1129-day vesting period:

| Chapter | Days Held Range | Duration | Calendar Example |
|---------|----------------|----------|------------------|
| 1 | 0–90 | 91 days | 2025Q1 |
| 2 | 91–181 | 91 days | 2025Q2 |
| 3 | 182–272 | 91 days | 2025Q3 |
| 4 | 273–363 | 91 days | 2025Q4 |
| 5 | 364–454 | 91 days | 2026Q1 |
| 6 | 455–545 | 91 days | 2026Q2 |
| 7 | 546–636 | 91 days | 2026Q3 |
| 8 | 637–727 | 91 days | 2026Q4 |
| 9 | 728–818 | 91 days | 2027Q1 |
| 10 | 819–909 | 91 days | 2027Q2 |
| 11 | 910–1000 | 91 days | 2027Q3 |
| 12 | 1001–1129 | 128 days | 2027Q4+ |

### Eligibility Example

A holder with vault minted 150 days ago (day 150):
- **Perpetual achievements:** Can claim all altitude achievements up to day 150 (TRAIL_HEAD, BASE_CAMP)
- **Chapter achievements:** Can only participate in Chapter 2 (91-181 range) during the calendar window

---

## 5. Claiming Mechanics

### Claim Requirements

| Requirement | Verified By |
|-------------|-------------|
| Within mint window | `block.timestamp` vs `start/endTimestamp` |
| Chapter active | `config.active == true` |
| Vault ownership | `vaultNFT.ownerOf(vaultId) == msg.sender` |
| Correct treasure | `vaultNFT.treasureContract(vaultId) == issuerTreasure` |
| Journey progress | `minDaysHeld <= daysHeld <= maxDaysHeld` |
| Prerequisites | `achievementNFT.hasAchievement(msg.sender, prereq)` |

### Helper Functions

```solidity
// Check if wallet can claim (returns reason if not)
function canClaimChapterAchievement(
    address wallet,
    bytes32 chapterId,
    bytes32 achievementId,
    uint256 vaultId,
    address collateralToken
) external view returns (bool canClaim, string memory reason);

// Get all claimable achievements in chapter
function getClaimableAchievements(
    address wallet,
    bytes32 chapterId,
    uint256 vaultId,
    address collateralToken
) external view returns (bytes32[] memory claimable);
```

---

## 6. Skill Tree Prerequisites

### Prerequisite Rules

| Rule | Description |
|------|-------------|
| Intra-chapter only | Prerequisites must be in same chapter |
| Multiple allowed | Achievement can require multiple prerequisites |
| Acyclic | No circular dependencies |
| Cross-version independence | 2025Q1 and 2026Q1 achievements are separate |

### Example Skill Tree

```
Chapter 1: 2025Q1
├── First Steps (no prerequisites)
│   └── Ice Bridge (requires First Steps)
│       └── Glacier Crossing (requires Ice Bridge)
└── Cold Snap (no prerequisites)
    └── Frost Giant (requires Cold Snap + First Steps)
```

---

## 7. Map Asset Storage

### Storage Strategy

| Asset Type | Storage Location | Rationale |
|------------|------------------|-----------|
| Map backgrounds | Static website | Fast loading, CDN-served |
| Skill tree config | Static website | Frontend renders dynamically |
| Achievement NFT images | IPFS | Permanent, decentralized |

### Directory Structure

```
apps/ascent/public/chapters/
├── ch1/
│   ├── 2025q1/
│   │   ├── background.png      # Visual theme
│   │   └── config.json         # Skill tree data
│   └── 2026q1/
│       ├── background.png
│       └── config.json
├── ch2/
│   └── ...
└── ...
```

### Config Schema

```json
{
  "chapter": 1,
  "version": "2025Q1",
  "theme": "Frozen Tundra",
  "colors": {
    "primary": "#4A90A4",
    "secondary": "#E8F4F8"
  },
  "skillTree": {
    "nodes": [
      {
        "id": "CH1_2025Q1_FIRST_STEPS",
        "name": "First Steps",
        "description": "Begin your trek across the frozen wastes",
        "position": { "x": 50, "y": 400 },
        "connections": ["CH1_2025Q1_ICE_BRIDGE"]
      }
    ],
    "layout": "vertical"
  }
}
```

---

## 8. Chapter 1 Achievements

### Overview

Chapter 1 (Days 0-90) contains 13 achievements following a Fibonacci progression (13 → 21 → 34 → 55 across chapters). All achievements are verifiable on-chain and do not require vault ownership.

### Achievement Structure

| Type | Quantity | Timing | Verification |
|------|----------|--------|--------------|
| Registration | 1 | Day 0 | Profile creation |
| Milestones | 3 | Day 15, 30, 60 | Presence claim |
| Weekly Actions | 9 | Weeks 2,4,6-8,10-13 | Category-specific |

### Achievement Definitions

| ID | Week | Day | Name | Category | Action | Verification |
|----|------|-----|------|----------|--------|--------------|
| 1 | 1 | 0 | TRAILHEAD | Registration | Create on-chain profile | Profile contract state |
| 2 | 3 | 15 | FIRST_STEPS | Milestone | Return and claim | Signature + timestamp |
| 3 | 5 | 30 | STEADY_PACE | Milestone | Return and claim | Signature + timestamp |
| 4 | 9 | 60 | COMMITTED | Milestone | Return and claim | Signature + timestamp |
| 5 | 2 | 8 | WALLET_WARMED | Wallet Activity | Interact with core contracts | Contract call event |
| 6 | 4 | 22 | IDENTIFIED | Social Identity | Link ENS/Farcaster/Lens | Identity verification |
| 7 | 6 | 36 | STUDENT | Protocol Learning | Learn achievement value | Quest checkpoint |
| 8 | 7 | 43 | GUIDE | Referral | Refer 1 wallet | Referral contract state |
| 9 | 8 | 50 | EXPLORER | Exploration | Interact with 3+ contracts | Multi-contract count |
| 10 | 10 | 64 | PREPARED | Preparation | Set token approvals | Approval event |
| 11 | 11 | 71 | REGULAR | Consistency | Return 3 separate days | Multi-signature attestation |
| 12 | 12 | 78 | RESOLUTE | Commitment | Sign commitment | Signature stored |
| 13 | 13 | 85 | CHAPTER_COMPLETE | Completion | Complete 10+ achievements | Aggregate check |

### Weekly Calendar

| Week | Days | Achievement | Category |
|------|------|-------------|----------|
| 1 | 0-7 | TRAILHEAD | Registration |
| 2 | 8-14 | WALLET_WARMED | Wallet Activity |
| 3 | 15-21 | FIRST_STEPS | Milestone |
| 4 | 22-28 | IDENTIFIED | Social Identity |
| 5 | 29-35 | STEADY_PACE | Milestone |
| 6 | 36-42 | STUDENT | Protocol Learning |
| 7 | 43-49 | GUIDE | Referral |
| 8 | 50-56 | EXPLORER | Exploration |
| 9 | 57-63 | COMMITTED | Milestone |
| 10 | 64-70 | PREPARED | Preparation |
| 11 | 71-77 | REGULAR | Consistency |
| 12 | 78-84 | RESOLUTE | Commitment |
| 13 | 85-91 | CHAPTER_COMPLETE | Completion |

### Verification Methods

| Method | Achievements | Implementation |
|--------|--------------|----------------|
| Contract state | TRAILHEAD, IDENTIFIED | Read from profile/identity contract |
| Event emission | WALLET_WARMED, PREPARED, STUDENT | Listen for specific events |
| Signature + timestamp | FIRST_STEPS, STEADY_PACE, COMMITTED, RESOLUTE | EIP-712 signed message stored |
| Multi-call counting | EXPLORER, REGULAR | Track distinct interactions |
| Referral state | GUIDE | Referral contract mapping |
| Aggregate check | CHAPTER_COMPLETE | Count minted achievements >= 10 |

### KPI Tuning

Each achievement claim emits:

```solidity
event ChapterAchievementClaimed(
    address indexed wallet,
    bytes32 indexed achievementId,
    uint256 timestamp,
    bytes32 category
);
```

Monthly analysis metrics:
- **Conversion rates**: % of wallets earning each achievement
- **Time-to-claim**: Distribution of days from availability to claim
- **Category completion**: Which categories have highest engagement
- **Mint correlation**: Relationship between achievements and vault minting

---

## 9. Admin Workflow

### Quarterly Setup Process

```solidity
// 1. Create chapter version
bytes32 chapterId = registry.createChapter(
    1,                              // chapterNumber
    2025,                           // year
    1,                              // quarter
    1735689600,                     // startTimestamp (Jan 1, 2025)
    1743552000,                     // endTimestamp (Apr 1, 2025)
    0,                              // minDaysHeld
    90,                             // maxDaysHeld
    "ipfs://Qm.../ch1_2025q1/"      // achievementBaseURI
);

// 2. Add achievements
bytes32 firstSteps = registry.addAchievement(
    chapterId,
    "First Steps",
    new bytes32[](0)                // no prerequisites
);

bytes32[] memory prereqs = new bytes32[](1);
prereqs[0] = firstSteps;
registry.addAchievement(
    chapterId,
    "Ice Bridge",
    prereqs                         // requires First Steps
);

// 3. Deploy static assets
// - Upload background.png to /chapters/ch1/2025q1/
// - Upload config.json to /chapters/ch1/2025q1/
// - Pin achievement images to IPFS
```

### Emergency Controls

| Action | Function |
|--------|----------|
| Pause chapter | `setChapterActive(chapterId, false)` |
| Resume chapter | `setChapterActive(chapterId, true)` |

**Note:** Pausing does not extend the mint window. Once `endTimestamp` passes, achievements are permanently locked regardless of pause status.

---

## 10. Verifier Architecture

### 10.1 Overview

Achievement verification is modular via the `IAchievementVerifier` interface. Each achievement can optionally reference a verifier contract for custom eligibility logic.

### 10.2 Interface

```solidity
interface IAchievementVerifier {
    /// @notice Verify if a wallet is eligible for an achievement
    /// @param wallet The wallet claiming the achievement
    /// @param achievementId The achievement being claimed
    /// @param data Optional verification data (signatures, proofs, etc.)
    /// @return eligible True if wallet meets achievement requirements
    function verify(
        address wallet,
        bytes32 achievementId,
        bytes calldata data
    ) external view returns (bool eligible);
}
```

### 10.3 Verifier Contracts

| Contract | Path | Purpose |
|----------|------|---------|
| `ProfileVerifier` | `verifiers/ProfileVerifier.sol` | Checks `ProfileRegistry.hasProfile()` |
| `PresenceVerifier` | `verifiers/PresenceVerifier.sol` | Checks days registered threshold |
| `InteractionVerifier` | `verifiers/InteractionVerifier.sol` | Counts distinct contract interactions |
| `ReferralVerifier` | `verifiers/ReferralVerifier.sol` | Validates referral relationships |
| `ApprovalVerifier` | `verifiers/ApprovalVerifier.sol` | Checks token approval state |
| `SignatureVerifier` | `verifiers/SignatureVerifier.sol` | Validates EIP-712 signed commitments |
| `IdentityVerifier` | `verifiers/IdentityVerifier.sol` | Verifies social identity links |
| `AggregateVerifier` | `verifiers/AggregateVerifier.sol` | Checks count of other achievements |

### 10.4 Chapter 1 Achievement-to-Verifier Mapping

| Achievement | Verifier | Verification Logic |
|-------------|----------|-------------------|
| TRAILHEAD | ProfileVerifier | `profileRegistry.hasProfile(wallet)` |
| FIRST_STEPS | PresenceVerifier | `getDaysRegistered() >= 15` |
| STEADY_PACE | PresenceVerifier | `getDaysRegistered() >= 30` |
| COMMITTED | PresenceVerifier | `getDaysRegistered() >= 60` |
| WALLET_WARMED | InteractionVerifier | Core contract interaction logged |
| IDENTIFIED | IdentityVerifier | ENS/Farcaster/Lens linked |
| STUDENT | SignatureVerifier | Quest checkpoint signature stored |
| GUIDE | ReferralVerifier | At least 1 referral recorded |
| EXPLORER | InteractionVerifier | `interactionCount >= 3` |
| PREPARED | ApprovalVerifier | Required token approvals set |
| REGULAR | SignatureVerifier | 3 separate day attestations |
| RESOLUTE | SignatureVerifier | Commitment signature stored |
| CHAPTER_COMPLETE | AggregateVerifier | `achievementCount >= 10` |

### 10.5 Custom Verifier Extension

To add a custom verifier for new achievement types:

```solidity
contract CustomVerifier is IAchievementVerifier {
    function verify(
        address wallet,
        bytes32 achievementId,
        bytes calldata data
    ) external view returns (bool) {
        // Custom verification logic
        return _customCheck(wallet, achievementId, data);
    }
}
```

Register with achievement:

```solidity
registry.addAchievementWithVerifier(
    chapterId,
    "CUSTOM_ACHIEVEMENT",
    prerequisites,
    address(customVerifier)
);
```

---

## 11. Education System

### 11.1 Overview

The Chapter system integrates DeFi education through three pillars:
1. **Theory** - Lessons, quizzes, and key points teaching DeFi concepts
2. **Practice** - On-chain verified actions demonstrating understanding
3. **Community** - Transparent progress and participation metrics

### 11.2 Content Architecture

Educational content is stored as static JSON in the frontend codebase:

```
apps/ascent/content/
├── chapters/
│   └── ch1/
│       └── achievements/
│           ├── trailhead.json
│           ├── first_steps.json
│           └── ... (13 files)
└── shared/
    ├── concepts.json      # DeFi concept definitions
    └── glossary.json      # Term definitions
```

### 11.3 Achievement Content Schema

Each achievement has associated educational content:

```json
{
  "achievementId": "TRAILHEAD",
  "week": 1,
  "category": "Registration",
  "defiConcept": "identity",
  "lesson": {
    "title": "Your On-Chain Identity",
    "objective": "Understand wallet addresses and profiles",
    "sections": [
      { "type": "text", "content": "..." },
      { "type": "keyPoints", "content": ["...", "..."] }
    ]
  },
  "quiz": {
    "questions": [
      {
        "question": "What is a wallet address?",
        "options": ["...", "...", "..."],
        "correct": 0
      }
    ],
    "passingScore": 100
  },
  "unlockHint": "Create your on-chain profile",
  "nextSteps": ["After creating your profile, link your ENS..."]
}
```

### 11.4 Educational Mapping

Chapter 1 maps achievements to DeFi foundations:

| Week | Achievement | DeFi Concept | Learning Outcome |
|------|-------------|--------------|------------------|
| 1 | TRAILHEAD | Identity | Understand on-chain identity |
| 2 | FIRST_STEPS | Commitment | Learn time-in-protocol value |
| 3 | WALLET_WARMED | Transactions | Execute smart contract interactions |
| 4 | IDENTIFIED | Social Recovery | Link verifiable identity |
| 5 | STEADY_PACE | Yield Mechanics | Understand time-weighted rewards |
| 6 | EXPLORER | Protocol Diversity | Interact with multiple contracts |
| 7 | GUIDE | Network Effects | Understand referral mechanics |
| 8 | PREPARED | Token Approvals | Master ERC-20 security |
| 9 | REGULAR | Consistency | Learn compound participation benefits |
| 10 | COMMITTED | Vesting | Understand lock mechanisms |
| 11 | RESOLUTE | Attestations | Sign cryptographic commitments |
| 12 | STUDENT | Meta-Learning | Demonstrate quiz-verified understanding |
| 13 | CHAPTER_COMPLETE | Mastery | Comprehensive foundation mastery |

### 11.5 STUDENT Achievement

The STUDENT achievement verifies theory learning:

**Verification Flow:**
1. User reads lesson content for any achievement
2. User completes in-app quiz (100% required to pass)
3. Quiz result signed as EIP-712 attestation
4. SignatureVerifier validates quiz completion
5. STUDENT achievement unlocks

**Purpose:** Ensures users internalize concepts, not just complete actions.

### 11.6 Frontend Components

| Component | Purpose |
|-----------|---------|
| `LessonViewer` | Renders lesson sections (text, key points, media) |
| `QuizCard` | Interactive quiz with scoring and retry |
| `UnlockGuide` | Shows how-to guidance for locked achievements |
| `AchievementDetailModal` | Combines lesson, quiz, and next steps |
| `TrackList` | Grid of available education tracks with progress |
| `TrackProgress` | Individual track viewer with lesson/quiz flow |

### 11.7 Two-Layer Education Architecture

The education system separates into two distinct layers:

#### Layer 1: Chapters (Cohort Identity + Achievement NFTs)
- **Time-bound** (90-day windows aligned with calendar quarters)
- **Thematic art/story/content** tied to shared cohort experience
- **Achievement NFTs** reward valuable behaviors for that chapter period
- **Visual prestige** from shared experience with cohort

#### Layer 2: Education Tracks (Knowledge Building)
- **Wallet-based progression** (not chapter-bound)
- **Self-paced** - users advance at their own discretion
- **Parallel tracks** spanning the full 1129 days
- **Trust-maximizing** - strong truth, transparency, knowledge maximization

**Key Distinction:** Completing a track lesson does NOT unlock a chapter achievement. Achievements require on-chain actions during the chapter window. Tracks provide the knowledge to perform those actions effectively.

### 11.8 Education Tracks

Six parallel tracks enable self-paced learning:

| Track | Focus | Lessons | Graduation Standard |
|-------|-------|---------|---------------------|
| **Bitcoin Fundamentals** | BTC thesis, SMA research, market cycles | 6 | Explain 1129-day thesis |
| **Protocol Mechanics** | Vault lifecycle, withdrawals, Zeno's paradox | 7 | Operate via explorer |
| **DeFi Foundations** | AMM, LP, lending, yields | 7 | Evaluate positions |
| **Advanced Protocol** | vestedBTC, delegation, dormancy | 6 | Full feature usage |
| **Security & Risk** | Immutability, audit reading, risk assessment | 5 | Due diligence |
| **Explorer Operations** | Direct contract interaction | 5 | Execute all functions |

Track content stored in: `apps/ascent/content/tracks/{track-id}.json`

### 11.9 Chapter Curriculum Roadmap

| Chapter | Theme | Educational Focus |
|---------|-------|-------------------|
| 1 | Frozen Tundra | Foundations (wallets, transactions, approvals) |
| 2 | Ice Caves | Trading (DEX swaps, slippage, price impact) |
| 3 | Glacier Fields | Liquidity (AMMs, LP tokens, impermanent loss) |
| 4 | Mountain Base | Lending (collateral, LTV, liquidation) |
| 5 | Forest Trail | Yield (APY/APR, farming, compounding) |
| 6 | Rocky Ascent | Risk (portfolio theory, diversification) |
| 7 | Ridge Line | Governance (DAOs, voting, delegation) |
| 8 | High Camp | Derivatives (options, perps, variance) |
| 9 | Storm Zone | Protocol Design (tokenomics, incentives) |
| 10 | Death Zone | Security (audits, rug detection, due diligence) |
| 11 | Final Ascent | Integration (cross-chain, bridges, aggregators) |
| 12 | Summit | Mastery (building, contributing, governance)

---

## 12. Frontend Integration

### 12.1 Library Modules

Chapter system frontend implementation is in `apps/ascent/lib/chapters.ts`:

```typescript
// Types
interface ChapterConfig {
  number: number;
  minDaysHeld: number;
  maxDaysHeld: number;
  theme: string;
  description: string;
}

type ChapterStatus = 'locked' | 'active' | 'completed' | 'missed';

// Static chapter definitions (CHAPTERS array)
const CHAPTERS: ChapterConfig[] = [
  { number: 1, minDaysHeld: 0, maxDaysHeld: 90, theme: 'Frozen Tundra', ... },
  // ... 12 chapters
];
```

#### Helper Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `getCurrentQuarter()` | Get current year/quarter | `{ year: 2025, quarter: 1 }` |
| `getChapterVersionId(num, year, quarter)` | Generate chapter ID | `"CH1_2025Q1"` |
| `getQuarterStart(year, quarter)` | Get quarter start timestamp | Unix timestamp |
| `getQuarterEnd(year, quarter)` | Get quarter end timestamp | Unix timestamp |
| `getEligibleChapter(daysHeld)` | Find chapter for days held | `ChapterConfig \| null` |
| `getChapterProgress(daysHeld, chapter)` | Calculate progress % | `0-100` |
| `isWithinWindow(start, end, now?)` | Check if in time window | `boolean` |
| `formatTimeRemaining(seconds)` | Format countdown | `"5d 12h"` |

### 12.2 React Hooks

#### `useChapters()`

Fetches all chapter configurations with current quarter status.

```typescript
const { data: chapters, isLoading, error } = useChapters();

// Returns: ChapterVersion[]
interface ChapterVersion {
  chapterId: string;      // "CH1_2025Q1"
  chapter: ChapterConfig; // Static chapter definition
  year: number;
  quarter: number;
  windowStart: number;    // Unix timestamp
  windowEnd: number;
  isActive: boolean;
  isWithinWindow: boolean;
}
```

#### `useChapter(chapterId)`

Get a specific chapter by version ID.

```typescript
const { data: chapter } = useChapter('CH1_2025Q1');
```

#### `useActiveChapter(daysHeld)`

Get the chapter matching current journey progress.

```typescript
const { data: activeChapter } = useActiveChapter(daysHeld);
```

#### `useChapterEligibility()`

Determines eligibility for all chapters based on vault ownership and journey progress.

```typescript
const { data: eligibilities } = useChapterEligibility();

// Returns: ChapterEligibility[]
interface ChapterEligibility {
  chapter: ChapterVersion;
  status: ChapterStatus;    // 'locked' | 'active' | 'completed' | 'missed'
  daysHeld: number;
  progress: number;         // 0-100
  canParticipate: boolean;
  reason: string | null;    // Why can't participate
}
```

**Eligibility Logic:**

| Condition | Status | Reason |
|-----------|--------|--------|
| No vault owned | `locked` | "No vault owned" |
| Before window start | `locked` | "Chapter window not open yet" |
| After window end | `missed` | "Chapter window has closed" |
| Days held < minDaysHeld | `locked` | "Need X more days held" |
| Days held > maxDaysHeld | `completed` | "Journey has progressed past this chapter" |
| All conditions met | `active` | null |

#### `useChapterEligibilityById(chapterId)`

Get eligibility for a specific chapter.

```typescript
const { data: eligibility } = useChapterEligibilityById('CH1_2025Q1');
if (eligibility?.canParticipate) {
  // Show achievement claiming UI
}
```

#### `useCurrentChapter()`

Get the currently active/participatable chapter.

```typescript
const { data: currentChapter } = useCurrentChapter();
```

### 12.3 Achievement Hooks

#### `useChapterAchievements(chapterNumber)`

Fetches achievements for a specific chapter.

```typescript
const { data: achievements } = useChapterAchievements(1);

// Returns chapter achievements from CHAPTER_ACHIEVEMENTS[chapterNumber]
```

#### `useAchievementStatus(achievementId)`

Tracks claimed/eligible status for an achievement.

```typescript
const { data: status } = useAchievementStatus('TRAILHEAD');
// { claimed: boolean, eligible: boolean, reason: string | null }
```

#### `useClaimAchievement()`

Executes achievement claiming transaction.

```typescript
const { mutate: claim, isPending } = useClaimAchievement();

claim({
  chapterId: 'CH1_2025Q1',
  achievementId: 'TRAILHEAD',
  vaultId: 1n,
  collateralToken: '0x...'
});
```

### 12.4 Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  useVaults() → vault ownership & mintTimestamp              │
│       ↓                                                     │
│  Calculate daysHeld = (now - mintTimestamp) / 86400        │
│       ↓                                                     │
│  useChapters() → current quarter chapters                   │
│       ↓                                                     │
│  useChapterEligibility() → combine journey + calendar       │
│       ↓                                                     │
│  useChapterAchievements() → load achievement definitions    │
│       ↓                                                     │
│  useAchievementStatus() → check claimed/eligible per NFT    │
│       ↓                                                     │
│  useClaimAchievement() → execute on-chain claim             │
└─────────────────────────────────────────────────────────────┘
```

### 12.5 Component Integration

| Component | Hook | Purpose |
|-----------|------|---------|
| `ChapterCard` | `useChapterEligibility` | Display chapter status/progress |
| `ChapterProgress` | `useChapterEligibility` | Progress bar through day range |
| `ChapterCountdown` | `useChapters` | Time remaining in window |
| `ActiveChapterCard` | `useCurrentChapter` | Highlight current chapter |
| `AchievementDetailModal` | `useAchievementStatus` | Claim UI for single achievement |

### 12.6 Achievement Content Files

Static content in `apps/ascent/lib/chapters.ts`:

```typescript
interface Chapter1Achievement {
  name: string;
  description: string;
  week: number;
  category: string;
  defiConcept: string;
  learningOutcome: string;
  contentFile: string;
  requiredDays?: number;
}

// CHAPTER_1_ACHIEVEMENTS, CHAPTER_2_ACHIEVEMENTS, CHAPTER_3_ACHIEVEMENTS
// Exported as CHAPTER_ACHIEVEMENTS[chapterNumber]
```

### 12.7 Theme Colors

Chapter visual theming in `CHAPTER_COLORS`:

```typescript
CHAPTER_COLORS[1] = {
  primary: '#4A90A4',   // Main accent
  secondary: '#E8F4F8', // Light background
  bg: 'from-sky-900/30' // Gradient overlay
};
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [The Ascent Design](./The_Ascent_Design.md) | Visual and conceptual framework |
| [Achievements Specification](./Achievements_Specification.md) | Perpetual journey achievements |
| [Integration Guide](./Integration_Guide.md) | Complete issuer integration |
| [SDK Integration Guide](../sdk/Integration_Guide.md) | TypeScript SDK usage |
| [Glossary](../GLOSSARY.md) | Terminology definitions |

---

## Navigation

[Issuer Documentation](./README.md) | [Documentation Home](../README.md)
