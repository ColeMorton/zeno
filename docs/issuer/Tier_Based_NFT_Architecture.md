# Tier-Based NFT Architecture

A first-principles engineering specification for dynamic, tier-based NFT visuals.

---

## The Core Problem

```
┌─────────────────────────────────────────────────────────────────┐
│                    DYNAMIC VISUAL PROBLEM                       │
├─────────────────────────────────────────────────────────────────┤
│  Achievement (static)  ×  Tier (dynamic)  =  Visual Output      │
│       8 types              6 levels           48 variants       │
│                                                                 │
│  Tier changes when:                                             │
│  • Holder's collateral changes                                  │
│  • Other holders' collateral changes (distribution shifts)      │
└─────────────────────────────────────────────────────────────────┘
```

The fundamental challenge: **tier is derived from relative wealth**, which changes continuously.

---

## First Principles Analysis

### Invariants

1. **Core visual is on-chain** — survives as long as the blockchain
2. **Tier is dynamic** — computed from current state, not stored
3. **Same achievement, different tiers = different visuals**
4. **Metadata must be queryable by marketplaces**

### Trade-off Spectrum

```
PERMANENCE ←────────────────────────────────→ FLEXIBILITY

Fully On-Chain          Hybrid              Off-Chain Service
• Eternal               • Balanced          • Maximum flex
• Size-limited          • Complexity        • Centralized
• Gas-expensive         • Best of both      • Single point of failure
```

### The Percentile Problem

Computing percentile on-chain is expensive:
- Requires knowing entire collateral distribution
- O(n) storage or complex data structures
- Updates on every deposit/withdrawal

**Solution**: Use **threshold-based tier buckets** updated periodically by a keeper.

---

## Optimal Architecture

### Design: Threshold-Based Dynamic Resolution

```
┌──────────────────────────────────────────────────────────────────┐
│                      ON-CHAIN (Permanent)                        │
├──────────────────────────────────────────────────────────────────┤
│  AchievementNFT Contract                                         │
│  ├── achievements[tokenId] → AchievementType (1 byte)            │
│  ├── thresholds → {whale, diamond, gold, silver} (4 × uint256)   │
│  ├── imageCIDs[achievementType][tier] → bytes32 (48 entries)     │
│  └── coreSVGs[achievementType] → string (8 entries, ~30KB total) │
│                                                                  │
│  VaultNFT Contract (protocol layer)                              │
│  └── collateralOf(address) → uint256                             │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    COMPUTATION (View Function)                    │
├──────────────────────────────────────────────────────────────────┤
│  function tokenURI(uint256 tokenId) view returns (string) {      │
│      address owner = ownerOf(tokenId);                           │
│      uint256 collateral = vaultNFT.collateralOf(owner);          │
│      Tier tier = computeTier(collateral);  // thresholds lookup  │
│      AchievementType achievement = achievements[tokenId];        │
│      return buildMetadata(achievement, tier);                    │
│  }                                                               │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    OFF-CHAIN (Redundant Storage)                  │
├──────────────────────────────────────────────────────────────────┤
│  IPFS + Arweave                                                  │
│  └── 48 pre-composed medallion images                            │
│      ├── bronze-minter.svg    (Qm...)                            │
│      ├── silver-minter.svg    (Qm...)                            │
│      ├── ...                                                     │
│      └── whale-diamond-hands.svg (Qm...)                         │
└──────────────────────────────────────────────────────────────────┘
```

### Why This Architecture

| Decision | Rationale |
|----------|-----------|
| Thresholds on-chain | Gas-efficient reads, keeper updates distribution periodically |
| Tier computed in view | No storage per token, always fresh |
| Image CIDs on-chain | Verifiable, no external dependency for resolution |
| Pre-composed images | Fast, no runtime composition, content-addressed |
| Core SVGs on-chain | Tier 0 fallback if off-chain storage fails |

---

## Contract Design

### Tier Resolution (Gas-Free View)

```solidity
enum Tier { Bronze, Silver, Gold, Diamond, Whale }
enum AchievementType { MINTER, MATURED, HODLER_SUPREME, ... }

struct Thresholds {
    uint256 silver;   // 50th percentile collateral value
    uint256 gold;     // 75th percentile
    uint256 diamond;  // 90th percentile
    uint256 whale;    // 99th percentile
}

function computeTier(uint256 collateral) public view returns (Tier) {
    if (collateral >= thresholds.whale) return Tier.Whale;
    if (collateral >= thresholds.diamond) return Tier.Diamond;
    if (collateral >= thresholds.gold) return Tier.Gold;
    if (collateral >= thresholds.silver) return Tier.Silver;
    return Tier.Bronze;
}
```

### Threshold Updates (Keeper Pattern)

```solidity
// Called periodically (daily/weekly) by authorized keeper
function updateThresholds(
    uint256 silver,
    uint256 gold,
    uint256 diamond,
    uint256 whale
) external onlyKeeper {
    thresholds = Thresholds(silver, gold, diamond, whale);

    // ERC-4906: Signal all metadata updated
    emit BatchMetadataUpdate(0, type(uint256).max);
}
```

### Token URI (Fully On-Chain Metadata)

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    address owner = ownerOf(tokenId);
    uint256 collateral = vaultNFT.collateralOf(owner);
    Tier tier = computeTier(collateral);
    AchievementType achievement = achievements[tokenId];

    // Build JSON metadata on-chain
    return string(abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(bytes(buildJSON(tokenId, achievement, tier)))
    ));
}

function buildJSON(
    uint256 tokenId,
    AchievementType achievement,
    Tier tier
) internal view returns (string memory) {
    return string(abi.encodePacked(
        '{"name":"', achievementNames[achievement], ' - ', tierNames[tier], '",',
        '"description":"Achievement NFT with tier-based visual",',
        '"image":"ipfs://', imageCIDs[achievement][tier], '",',
        '"attributes":[',
            '{"trait_type":"Achievement","value":"', achievementNames[achievement], '"},',
            '{"trait_type":"Tier","value":"', tierNames[tier], '"},',
            '{"trait_type":"Collateral","value":', Strings.toString(collateral), '}',
        '],',
        '"on_chain_core":"data:image/svg+xml;base64,', coreSVGsBase64[achievement], '"',
        '}'
    ));
}
```

---

## Image Strategy

### Pre-Generation Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    BUILD-TIME COMPOSITION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  for each achievement in [MINTER, MATURED, ...]:                │
│    core_svg = load("assets/achievements/{achievement}.svg")     │
│                                                                 │
│    for each tier in [BRONZE, SILVER, GOLD, DIAMOND, WHALE]:     │
│      frame = load("assets/frames/{tier}.svg")                   │
│      background = load("assets/backgrounds/{tier}.svg")         │
│      hoop_chain = load("assets/mounting/{tier}.svg")            │
│                                                                 │
│      composed = compose(background, frame, core_svg, hoop_chain)│
│      optimize(composed)                                         │
│      cid = upload_to_ipfs(composed)                             │
│      upload_to_arweave(composed)                                │
│                                                                 │
│      output: imageCIDs[achievement][tier] = cid                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Storage Redundancy

| Storage | Purpose | Durability |
|---------|---------|------------|
| Contract (CIDs) | Resolution pointers | Blockchain-permanent |
| IPFS + Pinata | Fast CDN-backed access | Pinning-dependent |
| Arweave | Permanent backup | Economic-incentive permanent |
| Contract (core SVGs) | Fallback if off-chain fails | Blockchain-permanent |

---

## Metadata Refresh Strategy

### The Marketplace Cache Problem

Marketplaces cache `tokenURI` responses. When tier changes, cached data is stale.

### Solution: ERC-4906 Metadata Update Events

```solidity
// IERC4906
event MetadataUpdate(uint256 tokenId);
event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

// Emit when thresholds update (affects all tokens)
function updateThresholds(...) external {
    // ...
    emit BatchMetadataUpdate(0, type(uint256).max);
}

// Emit when individual holder's collateral changes significantly
function onCollateralChange(address holder) external {
    uint256[] memory tokenIds = getTokensOfOwner(holder);
    for (uint i = 0; i < tokenIds.length; i++) {
        emit MetadataUpdate(tokenIds[i]);
    }
}
```

---

## Alternative Considered: Fully On-Chain Composition

```solidity
function composeSVG(AchievementType a, Tier t) view returns (string) {
    return string(abi.encodePacked(
        '<svg viewBox="0 0 512 512">',
        backgrounds[t],      // ~2KB
        frames[t],           // ~3KB
        coreSVGs[a],         // ~4KB
        mountings[t],        // ~2KB
        '</svg>'
    ));
}
```

**Rejected because:**
- Contract size limits (~24KB bytecode)
- 5 backgrounds + 5 frames + 8 cores + 5 mountings = ~50KB+ of SVG
- Animations in Whale tier would be size-prohibitive
- Pre-compose at build time and store CIDs instead

---

## Data Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Holder    │────▶│  VaultNFT   │────▶│ Collateral  │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌──────────────────────────┘
                    ▼
┌─────────────────────────────────────────────────────────┐
│                   AchievementNFT                        │
├─────────────────────────────────────────────────────────┤
│  tokenURI(tokenId)                                      │
│    │                                                    │
│    ├─▶ ownerOf(tokenId) → holder                        │
│    ├─▶ vaultNFT.collateralOf(holder) → collateral       │
│    ├─▶ computeTier(collateral) → tier                   │
│    ├─▶ achievements[tokenId] → achievementType          │
│    └─▶ buildMetadata(achievementType, tier) → JSON      │
│            │                                            │
│            └─▶ includes: ipfs://{imageCIDs[type][tier]} │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│                    IPFS / Arweave                        │
├─────────────────────────────────────────────────────────┤
│  Pre-composed medallion SVG for (achievementType, tier) │
│  • Core visual (from on-chain)                          │
│  • Background layer (tier-specific)                     │
│  • Frame layer (tier-specific)                          │
│  • Mounting layer (Gold+: hoop, Diamond+: chain)        │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Contract Updates
- Add `Thresholds` struct and `updateThresholds()` function
- Add `imageCIDs` mapping
- Update `tokenURI()` to compute tier dynamically
- Implement ERC-4906 events

### Phase 2: Asset Generation
- Create tier frame SVG templates (5 variants)
- Create background SVG templates (5 variants)
- Create hoop/chain SVG templates (3 variants: Gold, Diamond, Whale)
- Build composition script
- Generate 48 composed images

### Phase 3: Deployment
- Upload all images to IPFS + Arweave
- Deploy updated contract with CID mappings
- Set initial thresholds
- Deploy keeper for threshold updates

### Phase 4: Integration
- Hook VaultNFT collateral changes to emit MetadataUpdate
- Set up keeper job for periodic threshold recalculation
- Test marketplace refresh behavior

---

## Key Engineering Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Tier storage | Computed, not stored | Always fresh, no update gas |
| Threshold source | On-chain, keeper-updated | Verifiable, gas-efficient reads |
| Metadata format | On-chain JSON, off-chain images | Best of both permanence models |
| Image storage | Pre-composed on IPFS+Arweave | Fast, redundant, content-addressed |
| Fallback | Core SVG on-chain | Tier 0 survives off-chain failure |
| Refresh signal | ERC-4906 events | Standard marketplace support |

---

## Related Documentation

- [Medallion Visual Architecture](./Medallion_Visual_Architecture.md) — Visual design specification
- [Achievement NFT Visual Implementation](./Achievement_NFT_Visual_Implementation.md) — Tier 0 on-chain SVG
- [Visual Assets Guide](./Visual_Assets_Guide.md) — Complete visual standards
