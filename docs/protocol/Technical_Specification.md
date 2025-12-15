# BTCNFT Protocol Technical Specification

> **Version:** 1.5
> **Status:** Draft
> **Last Updated:** 2025-12-12
> **Related Documents:**
> - [Product Specification](./Product_Specification.md)
> - [Quantitative Validation](./Quantitative_Validation.md)
> - [Market Analysis](../issuer/Market_Analysis.md)

---

## Table of Contents

1. [Token Lifecycle](#1-token-lifecycle)
   - 1.1 [Minting](#11-minting)
   - 1.2 [Minting Window (Optional)](#12-minting-window-optional)
   - 1.3 [Vesting Period](#13-vesting-period)
   - 1.4 [Post-Vesting Withdrawals](#14-post-vesting-withdrawals)
   - 1.5 [Early Redemption](#15-early-redemption)
2. [Collateral Separation (btcToken)](#2-collateral-separation-btctoken)
   - 2.1 [Purpose](#21-purpose)
   - 2.2 [btcToken Properties](#22-btctoken-properties)
   - 2.3 [Value Proposition](#23-value-proposition)
   - 2.4 [Minting btcToken](#24-minting-btctoken)
   - 2.5 [Rights Comparison](#25-rights-comparison)
   - 2.6 [Recombination](#26-recombination)
   - 2.7 [DeFi Advantages](#27-defi-advantages)
   - 2.8 [Use Cases](#28-use-cases)
3. [Early Redemption](#3-early-redemption)
   - 3.1 [Linear Unlock Formula](#31-linear-unlock-formula)
   - 3.2 [Redemption Schedule](#32-redemption-schedule)
   - 3.3 [Forfeited Collateral Destination](#33-forfeited-collateral-destination)
4. [Contract Parameters](#4-contract-parameters)
   - 4.1 [Immutable Parameters](#41-immutable-parameters)
   - 4.2 [Per-Token Parameters](#42-per-token-parameters)
   - 4.3 [btcToken Parameters](#43-btctoken-parameters)
   - 4.4 [Dormancy Parameters](#44-dormancy-parameters)
5. [Dormant NFT Claim](#5-dormant-nft-claim)
   - 5.1 [Purpose](#51-purpose)
   - 5.2 [Dormancy Criteria](#52-dormancy-criteria)
   - 5.3 [State Machine](#53-state-machine)
   - 5.4 [Activity Tracking](#54-activity-tracking)
   - 5.5 [Functions](#55-functions)
   - 5.6 [Events](#56-events)
   - 5.7 [Errors](#57-errors)
   - 5.8 [Security Considerations](#58-security-considerations)
6. [Design Decisions](#6-design-decisions)

---

## 1. Token Lifecycle

### 1.1 Minting

**Required Inputs:**
1. Treasure NFT (ERC-721) - transferred to Vault
2. BTC collateral (WBTC or cbBTC) - locked in Vault
3. Withdrawal tier selection (immutable)

**Process:**
1. User approves Treasure NFT transfer
2. User approves BTC collateral transfer
3. Contract mints ERC-998 Vault NFT
4. Treasure stored in Vault (ERC-998 ownership)
5. BTC collateral stored in Vault (ERC-20 balance)

**Result:**
- Vault NFT minted with:
  - Treasure stored (provides identity/art)
  - BTC collateral stored (provides backing)
  - Mint timestamp recorded
  - Withdrawal tier locked

### 1.2 Minting Window (Optional)

For series/time-based NFT releases, an optional minting window can be configured.

**Configuration (Set at Deployment):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `mintingWindowEnd` | uint256 | Block number or timestamp when minting executes (0 = instant mint) |

**Behavior when `mintingWindowEnd` is set:**

```
┌─────────────────────────────────────────────────────────────────┐
│                      MINTING WINDOW                             │
│  ┌─────────────────────────────────────┐  ┌─────────────────┐  │
│  │  Window Open                        │  │  Mint Execution │  │
│  │  - Accept pending mints             │  │  - All pending  │  │
│  │  - Lock Treasure + BTC              │  │    mints execute│  │
│  │  - Allow collateral increases       │  │  - NFTs minted  │  │
│  │  - No withdrawals                   │  │  - Vesting starts│  │
│  └─────────────────────────────────────┘  └─────────────────┘  │
│  ◄──────────── Window Period ───────────►│◄── Execution ────►  │
│  Deployment                          mintingWindowEnd           │
└─────────────────────────────────────────────────────────────────┘
```

**Pending Mint Process:**

1. User calls `pendingMint()` during window
2. Child NFT transferred and held by contract
3. BTC collateral transferred and held by contract
4. Withdrawal tier selection recorded
5. Pending mint entry created

**Collateral Increase:**

| Action | Allowed During Window | Allowed After Window |
|--------|----------------------|---------------------|
| Increase BTC collateral | Yes | No |
| Withdraw BTC collateral | No | No |
| Withdraw Treasure | No | No |
| Cancel pending mint | Yes (returns all assets) | No |

**Mint Execution:**

When `block.number >= mintingWindowEnd` (or timestamp):
- Any address can call `executeMints()`
- All pending mints finalize simultaneously
- Each pending mint becomes a minted ERC-998 token
- Vesting period begins from execution timestamp
- All mints in series share same `mintTimestamp`

**Pending Mint State:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `pendingMinter` | address | Address that initiated pending mint |
| `pendingTreasure` | (address, uint256) | Held Treasure NFT contract + tokenId |
| `pendingCollateral` | uint256 | Accumulated BTC collateral |
| `pendingTier` | uint8 | Selected withdrawal tier |
| `pendingTimestamp` | uint256 | When pending mint was created |

### 1.3 Vesting Period

- **Duration:** 1093 days (~3 years)
- **Withdrawals:** Not permitted during vesting
- **Rationale:** Ensures holder experiences at least one full BTC market cycle

### 1.4 Post-Vesting Withdrawals

- **Frequency:** Once per 30-day period
- **Amount:** Fixed percentage of remaining collateral (tier-dependent)
- **Property:** Collateral never fully depletes (Zeno's paradox)

### 1.5 Early Redemption

- Available at any time during vesting
- Burns (permanently destroys) the Vault NFT including the stored Treasure
- Returns:
  - Partial BTC collateral based on time elapsed
- Destroys:
  - Treasure (burned with Vault NFT - not recoverable)
- See [Section 3](#3-early-redemption) for details
- **Constraint:** If btcToken exists, Vault can only be redeemed when full btcToken amount is held at same address

---

## 2. Collateral Separation (btcToken)

Enables separation of collateral claim from withdrawal rights and Treasure ownership via a fungible ERC-20 token.

### 2.1 Purpose

- Separates principal (collateral) from withdrawal rights - analogous to bond stripping in traditional finance
- Enables collateral to be used as DeFi collateral while retaining withdrawal rights
- Creates tradeable principal-only and withdrawal-rights-only positions
- Fungible design enables DEX liquidity, fractional sales, and DeFi composability

### 2.2 btcToken Properties

| Property | Value |
|----------|-------|
| Token Standard | ERC-20 (Fungible) |
| Ratio | 1:1 with underlying BTC collateral |
| Collateral Claim | Dynamic (tracks current remaining collateral) |
| Withdrawal Rights | None |
| Treasure Ownership | None |
| Redemption | All-or-nothing (full amount required to restore redemption rights) |

### 2.3 Value Proposition

The btcToken represents a claim on **current remaining collateral**, which decreases as withdrawals are taken. However, historical BTC performance suggests USD-denominated value stability:

```
btcToken USD Value = remaining_collateral × BTC_price

Over time:
├─ remaining_collateral ↓ (withdrawals reduce it)
├─ BTC_price ↑ (historical expectation: +313% mean over 1093 days)
└─ Net effect: USD value expected to remain stable or grow
```

| Time Window | BTC Appreciation | Withdrawal Impact | Net USD Stability |
|-------------|------------------|-------------------|-------------------|
| Monthly | +4.61% mean | -0.83% to -1.59% | Variable |
| Yearly | +63.11% mean | -10.5% to -20.8% | **100%** (Conservative/Balanced) |
| 1093-Day | +313.07% mean | -27% to -47%* | **100%** (All tiers) |

*Cumulative withdrawal impact varies by tier and compounding

### 2.4 Minting btcToken

```
┌─────────────────────────────────────────────────────────────────┐
│                    COLLATERAL SEPARATION                        │
│                                                                 │
│  ┌──────────────────────┐      ┌──────────────────────┐        │
│  │  Vault NFT           │      │  Vault NFT           │        │
│  │  ┌────────┬────────┐ │      │  ┌────────┬────────┐ │        │
│  │  │Treasure│  0.5   │ │      │  │Treasure│  0.5   │ │        │
│  │  │        │  BTC   │ │ ──►  │  │        │(locked)│ │        │
│  │  └────────┴────────┘ │      │  └────────┴────────┘ │        │
│  │  + Withdrawal Rights │      │  + Withdrawal Rights │        │
│  │  + Redemption Rights │      │  - Redemption Rights*│        │
│  └──────────────────────┘      └──────────────────────┘        │
│                                          +                      │
│                                ┌──────────────────────┐        │
│                                │  0.5 btcToken        │        │
│                                │  (ERC-20 Fungible)   │        │
│                                │  - No withdrawals    │        │
│                                │  - No Treasure       │        │
│                                │  - Collateral claim  │        │
│                                └──────────────────────┘        │
│                                                                 │
│  * Redemption requires full btcToken balance at same address   │
└─────────────────────────────────────────────────────────────────┘
```

**Process:**

1. Vault holder calls `mintBtcToken(vaultTokenId)`
2. Contract verifies caller owns Vault NFT
3. Contract verifies no existing btcToken issued for this Vault
4. btcToken minted to caller (amount = Vault collateral amount)
5. Vault redemption rights locked
6. Mapping: `vaultTokenId → btcTokenAmount` recorded

**Function Specification:**

```solidity
function mintBtcToken(uint256 vaultTokenId) external returns (uint256 amount) {
    // Validation
    if (ownerOf(vaultTokenId) != msg.sender) revert NotTokenOwner(vaultTokenId);
    if (btcTokenAmount[vaultTokenId] > 0) revert BtcTokenAlreadyMinted(vaultTokenId);
    if (block.timestamp < mintTimestamp[vaultTokenId] + VESTING_PERIOD) revert StillVesting(vaultTokenId);

    // Record original minted amount (required for all-or-nothing return)
    uint256 currentCollateral = collateralAmount[vaultTokenId];
    btcTokenAmount[vaultTokenId] = currentCollateral;
    originalMintedAmount[vaultTokenId] = currentCollateral;

    // Mint btcToken to caller
    btcToken.mint(msg.sender, currentCollateral);

    // Update activity timestamp
    _updateActivity(vaultTokenId);

    emit BtcTokenMinted(vaultTokenId, msg.sender, currentCollateral);
    return currentCollateral;
}
```

**Collateral Claim Tracking:**

btcToken represents a claim on the **current remaining collateral** of the Vault NFT. As withdrawals occur, the underlying collateral decreases.

```solidity
// View function: returns btcToken holder's current claim value
function getCollateralClaim(uint256 vaultTokenId) external view returns (uint256) {
    if (btcTokenAmount[vaultTokenId] == 0) return 0;
    return collateralAmount[vaultTokenId]; // Current remaining collateral
}

// btcToken holders can query their proportional claim
function getClaimValue(address holder, uint256 vaultTokenId) external view returns (uint256) {
    uint256 holderBalance = btcToken.balanceOf(holder);
    uint256 originalAmount = originalMintedAmount[vaultTokenId];
    if (originalAmount == 0 || holderBalance == 0) return 0;

    // Proportional claim on current collateral
    uint256 currentCollateral = collateralAmount[vaultTokenId];
    return (currentCollateral * holderBalance) / originalAmount;
}
```

**State After Separation:**

| State Variable | Before mintBtcToken | After mintBtcToken |
|----------------|---------------------|-------------------|
| `btcTokenAmount[tokenId]` | 0 | original collateral amount |
| `originalMintedAmount[tokenId]` | 0 | original collateral amount |
| `collateralAmount[tokenId]` | X BTC | X BTC (unchanged) |
| Vault redemption rights | Enabled | Disabled* |
| BTC withdrawal rights | Enabled | Enabled |

*Redemption rights re-enabled when full btcToken amount returned

### 2.5 Rights Comparison

| Right | Vault (no btcToken) | Vault (btcToken exists) | btcToken Holder |
|-------|---------------------|-------------------------|-----------------|
| BTC withdrawals | Yes | Yes | No |
| Treasure ownership | Yes | Yes | No |
| Redeem collateral | Yes | Only with full btcToken* | No |
| Transfer | Yes | Yes | Yes (fungible) |
| Collateral claim | Yes | No (transferred to btcToken) | Yes |

*Vault can only be redeemed when full btcToken amount is held at same address

### 2.6 Recombination

btcToken can be returned to restore full rights to Vault:

1. Holder calls `returnBtcToken(vaultTokenId, amount)`
2. Contract verifies `amount == originalMintedAmount` (all-or-nothing)
3. Contract verifies caller holds Vault at same address
4. btcToken burned (permanently destroyed)
5. Vault redemption rights restored

### 2.7 DeFi Advantages

| Feature | btcToken (ERC-20) | btcNFT (ERC-721) |
|---------|-------------------|------------------|
| DEX trading | Native (Uniswap, Curve) | Requires NFT marketplaces |
| Liquidity pools | Deep, automated | Fragmented, manual |
| Fractional sales | Native | Requires fractionalization protocol |
| Lending protocols | Direct (Aave, Compound) | Limited support |
| Price discovery | Continuous, transparent | Floor price mechanics |
| Gas efficiency | Lower | Higher |

### 2.8 Use Cases

| Use Case | Mechanism |
|----------|-----------|
| Liquidity access | Sell btcToken on DEX, retain Vault for withdrawal rights |
| DeFi collateral | Deposit btcToken in Aave/Compound |
| Partial liquidation | Sell portion of btcToken while retaining rest |
| Liquidity provision | Add btcToken to DEX liquidity pool |
| Structured products | Create principal-only and withdrawal-rights-only tranches |

---

## 3. Early Redemption

### 3.1 Linear Unlock Formula

```
redeemable(d) = collateral × (d / 1093)
forfeited(d) = collateral × (1 - d / 1093)
```

Where `d` = days since mint (0 to 1093)

### 3.2 Redemption Schedule

| Day | Elapsed | Forfeited | Returned |
|-----|---------|-----------|----------|
| 0 | 0% | 100% | 0% |
| 182 | ~6 mo | 83.3% | 16.7% |
| 365 | ~1 yr | 66.6% | 33.4% |
| 547 | ~18 mo | 50.0% | 50.0% |
| 730 | ~2 yr | 33.2% | 66.8% |
| 912 | ~2.5 yr | 16.6% | 83.4% |
| 1093 | ~3 yr | 0% | 100% |

### 3.3 Forfeited Collateral Destination

Configured at contract deployment (immutable):

| Destination | Description |
|-------------|-------------|
| `ISSUER` | Sent to issuer wallet address |
| `TREASURY` | Sent to protocol treasury address |
| `SERIES_HOLDERS` | Redistributed pro-rata among same NFT series |
| `ALL_HOLDERS` | Redistributed pro-rata among all NFT holders |

**Redistribution Logic:**
- Forfeited collateral added to redistribution pool
- Claimable pro-rata based on holder's collateral share

**Redistribution Claim Function (for SERIES_HOLDERS/ALL_HOLDERS):**

```solidity
// State variables for redistribution
mapping(uint256 => uint256) public redistributionPool; // seriesId => pool amount (or 0 for ALL_HOLDERS)
mapping(uint256 => uint256) public totalActiveCollateralAtSnapshot; // seriesId => snapshot
mapping(uint256 => mapping(uint256 => bool)) public hasClaimed; // seriesId => tokenId => claimed

function claimRedistribution(uint256 tokenId) external returns (uint256 claimed) {
    // Validation
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
    if (block.timestamp < mintTimestamp[tokenId] + VESTING_PERIOD) revert StillVesting(tokenId);

    uint256 seriesId = penaltyDestinationType == PenaltyDestination.ALL_HOLDERS ? 0 : series[tokenId];
    if (hasClaimed[seriesId][tokenId]) revert AlreadyClaimed(tokenId);

    uint256 pool = redistributionPool[seriesId];
    if (pool == 0) revert NoPoolAvailable(seriesId);

    // Calculate pro-rata share using snapshot denominator
    uint256 holderCollateral = collateralAmount[tokenId];
    uint256 denominator = totalActiveCollateralAtSnapshot[seriesId];
    claimed = (pool * holderCollateral) / denominator;

    // Mark as claimed and transfer
    hasClaimed[seriesId][tokenId] = true;
    collateralToken[tokenId].transfer(msg.sender, claimed);

    // Update activity timestamp
    _updateActivity(tokenId);

    emit RedistributionClaimed(tokenId, seriesId, claimed);
    return claimed;
}
```

**Rounding Direction:**

All calculations use floor rounding (round down) for user-facing amounts to prevent protocol insolvency:

| Calculation | Rounding | Rationale |
|-------------|----------|-----------|
| Withdrawal amount | Floor | User receives ≤ entitled amount |
| Early redemption | Floor | User receives ≤ entitled amount |
| Redistribution claim | Floor | User receives ≤ entitled share |
| btcToken minting | Exact | 1:1 with collateral (no rounding) |

```solidity
// Standard rounding pattern (floor division)
uint256 amount = (numerator * multiplier) / denominator; // Solidity default: floor
```

---

## 4. Contract Parameters

### 4.1 Immutable Parameters (Set at Deployment)

| Parameter | Type | Description |
|-----------|------|-------------|
| `vestingPeriod` | uint256 | 1093 days (constant) |
| `withdrawalPeriod` | uint256 | 30 days (constant) |
| `penaltyDestinationType` | enum | ISSUER, TREASURY, SERIES_HOLDERS, ALL_HOLDERS |
| `penaltyDestinationAddress` | address | Target for ISSUER/TREASURY types |
| `tierRates` | uint256[3] | [833, 1140, 1590] (basis points × 100) |
| `acceptedBTCTokens` | address[] | [WBTC, cbBTC] accepted collateral tokens |
| `mintingWindowEnd` | uint256 | Block/timestamp for deferred minting (0 = instant mint) |

### 4.2 Per-Token Parameters (Set at Mint)

| Parameter | Type | Description |
|-----------|------|-------------|
| `treasureContract` | address | ERC-721 contract of stored Treasure |
| `treasureTokenId` | uint256 | Token ID of stored Treasure |
| `collateralToken` | address | WBTC or cbBTC address used |
| `collateralAmount` | uint256 | BTC amount deposited |
| `mintTimestamp` | uint256 | Block timestamp at mint |
| `tier` | uint8 | 0=Conservative, 1=Balanced, 2=Aggressive |
| `lastWithdrawal` | uint256 | Timestamp of last withdrawal |
| `btcTokenAmount` | uint256 | Amount of btcToken minted (0 if none exists) |

### 4.3 btcToken Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `vaultTokenId` | uint256 | Token ID of Vault NFT |
| `vaultContract` | address | Address of Vault NFT contract |
| `originalAmount` | uint256 | Amount minted (required for all-or-nothing return) |
| `mintTimestamp` | uint256 | When btcToken was minted |

### 4.4 Dormancy Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `DORMANCY_THRESHOLD` | uint256 | 1093 days (constant) - Inactivity period before dormant-eligible |
| `GRACE_PERIOD` | uint256 | 30 days (immutable) - Time for owner to respond after poke |
| `lastActivity` | mapping(uint256 => uint256) | Per-token timestamp of last activity |
| `pokeTimestamp` | mapping(uint256 => uint256) | Per-token timestamp when poked (0 = not poked) |

---

## 5. Dormant Vault Claim

Prevents permanently locked BTC by allowing vBTC holders to claim abandoned Vaults.

### 5.1 Purpose

When a Vault holder:
1. Separates collateral into btcToken (vBTC)
2. Sells or transfers the btcToken away
3. Becomes inactive for an extended period (1093+ days)

The underlying BTC collateral becomes inaccessible - the Vault holder cannot redeem (lacks btcToken), and btcToken holders cannot recombine (lack the Vault). This mechanism allows btcToken holders to reclaim dormant positions.

### 5.2 Dormancy Criteria

A Vault is **dormant-eligible** when ALL conditions are met:

| Condition | Requirement | Rationale |
|-----------|-------------|-----------|
| btcToken Exists | `btcTokenAmount[tokenId] > 0` | Collateral must be separated |
| btcToken Not at Owner | `btcToken.balanceOf(owner) < btcTokenAmount[tokenId]` | Owner sold/transferred their claim |
| Inactivity Period | `block.timestamp >= lastActivity[tokenId] + DORMANCY_THRESHOLD` | 1093 days without any interaction |

### 5.3 State Machine

```
                                    ┌─────────────────────────────────┐
                                    │  Any activity (withdraw,        │
                                    │  transfer, proveActivity, etc.) │
                                    └────────────────┬────────────────┘
                                                     │
                                                     ▼
┌─────────────────┐                         ┌─────────────────┐
│                 │   1093+ days inactive   │                 │
│     ACTIVE      │   + btcToken separated  │ DORMANT_ELIGIBLE│
│                 │ ◄────────────────────── │ (logical state) │
│  lastActivity   │                         │                 │
│    updated      │                         └────────┬────────┘
└─────────────────┘                                  │
        ▲                                            │ pokeDormant()
        │                                            │
        │   Owner calls                              ▼
        │   proveActivity()              ┌─────────────────┐
        │   or any activity              │                 │
        │                                │  POKE_PENDING   │
        └────────────────────────────────│                 │
                                         │  Grace period   │
                                         │  (30 days)      │
                                         └────────┬────────┘
                                                  │
                                                  │ Grace period expires
                                                  │ (owner did not respond)
                                                  ▼
                                         ┌─────────────────┐
                                         │                 │
                                         │   CLAIMABLE     │
                                         │                 │
                                         └────────┬────────┘
                                                  │
                                                  │ claimDormantVault()
                                                  ▼
                                         ┌─────────────────┐
                                         │ CLAIM RESULT:   │
                                         │                 │
                                         │ Claimer gets:   │
                                         │ - Vault NFT     │
                                         │ - Collateral    │
                                         │ - Withdrawal rights │
                                         │                 │
                                         │ Original gets:  │
                                         │ - Treasure      │
                                         │                 │
                                         │ vBTC:           │
                                         │ - Burned        │
                                         └─────────────────┘
```

**Dormancy States:**

| State | pokeTimestamp | Condition |
|-------|---------------|-----------|
| `ACTIVE` | 0 | Not dormant-eligible OR poke cleared by activity |
| `POKE_PENDING` | > 0 | Poked, within grace period |
| `CLAIMABLE` | > 0 | Poked, grace period expired |

### 5.4 Activity Tracking

The `lastActivity` timestamp is updated on ALL meaningful interactions:

| Function | Activity Update |
|----------|-----------------|
| `mint()` | Initialize `lastActivity[tokenId] = block.timestamp` |
| `withdraw()` | Update `lastActivity` at function start |
| `transfer()` / `safeTransferFrom()` | Update via ERC-721 `_beforeTokenTransfer` hook |
| `mintBtcToken()` | Update `lastActivity` |
| `returnBtcToken()` | Update `lastActivity` |
| `claimMatch()` | Update `lastActivity` |
| `proveActivity()` | Update `lastActivity` (explicit activity proof) |

**Internal Activity Update:**

```solidity
function _updateActivity(uint256 tokenId) internal {
    lastActivity[tokenId] = block.timestamp;

    // Clear any pending poke state when activity is proven
    if (pokeTimestamp[tokenId] != 0) {
        pokeTimestamp[tokenId] = 0;
        emit DormancyStateChanged(tokenId, DormancyState.ACTIVE);
    }
}
```

### 5.5 Functions

#### `isDormantEligible(tokenId)` - View

Returns dormancy eligibility and current state.

```solidity
function isDormantEligible(uint256 tokenId) public view
    returns (bool eligible, DormancyState state)
{
    // Requirement 1: btcToken must exist for this Vault
    if (btcTokenAmount[tokenId] == 0) {
        return (false, DormancyState.ACTIVE);
    }

    // Requirement 2: btcToken NOT held at same address as Vault owner
    address vaultOwner = ownerOf(tokenId);
    if (btcToken.balanceOf(vaultOwner) >= btcTokenAmount[tokenId]) {
        return (false, DormancyState.ACTIVE);
    }

    // Requirement 3: No activity for DORMANCY_THRESHOLD (1093 days)
    if (block.timestamp < lastActivity[tokenId] + DORMANCY_THRESHOLD) {
        return (false, DormancyState.ACTIVE);
    }

    // Check poke state
    if (pokeTimestamp[tokenId] == 0) {
        return (true, DormancyState.ACTIVE); // Eligible but not yet poked
    }

    // Grace period check
    if (block.timestamp < pokeTimestamp[tokenId] + GRACE_PERIOD) {
        return (true, DormancyState.POKE_PENDING);
    }

    // Grace period expired
    return (true, DormancyState.CLAIMABLE);
}
```

#### `pokeDormant(tokenId)` - Initiate Grace Period

Marks a dormant-eligible NFT as poke-pending, starting the grace period.

```solidity
function pokeDormant(uint256 tokenId) external {
    (bool eligible, DormancyState state) = isDormantEligible(tokenId);

    if (!eligible) revert NotDormantEligible(tokenId);
    if (state != DormancyState.ACTIVE) revert AlreadyPoked(tokenId);

    pokeTimestamp[tokenId] = block.timestamp;

    address owner = ownerOf(tokenId);
    emit DormantPoked(tokenId, owner, msg.sender, block.timestamp + GRACE_PERIOD);
    emit DormancyStateChanged(tokenId, DormancyState.POKE_PENDING);
}
```

#### `proveActivity(tokenId)` - Owner Response

Owner proves activity to exit dormancy state.

```solidity
function proveActivity(uint256 tokenId) external {
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

    _updateActivity(tokenId);

    emit ActivityProven(tokenId, msg.sender);
}
```

#### `claimDormantCollateral(tokenId)` - vBTC Holder Claims Collateral

Claims BTC collateral from a dormant Vault by burning the required vBTC amount.

```solidity
function claimDormantCollateral(uint256 tokenId) external {
    (bool eligible, DormancyState state) = isDormantEligible(tokenId);

    if (!eligible) revert NotDormantEligible(tokenId);
    if (state != DormancyState.CLAIMABLE) revert NotClaimable(tokenId);

    uint256 requiredStableBTC = btcTokenAmount[tokenId];
    if (btcToken.balanceOf(msg.sender) < requiredStableBTC) {
        revert InsufficientBtcToken(requiredStableBTC, btcToken.balanceOf(msg.sender));
    }

    address originalOwner = ownerOf(tokenId);
    uint256 collateralToClaim = collateralAmount[tokenId];

    // Step 1: Burn vBTC from claimer (permanent destruction)
    btcToken.burnFrom(msg.sender, requiredStableBTC);

    // Step 2: Extract Treasure and return to original owner
    (address treasureContract, uint256 treasureTokenId) = getTreasure(tokenId);
    _extractTreasure(tokenId, originalOwner);

    // Step 3: Transfer BTC collateral to claimer
    collateralToken[tokenId].transfer(msg.sender, collateralToClaim);

    // Step 4: Burn the Vault NFT (now empty - no value)
    _burn(tokenId);

    emit DormantCollateralClaimed(
        tokenId,
        originalOwner,
        msg.sender,
        treasureContract,
        treasureTokenId,
        collateralToClaim,
        requiredStableBTC
    );
}
```

### 5.6 Events

```solidity
event DormantPoked(
    uint256 indexed tokenId,
    address indexed owner,
    address indexed poker,
    uint256 graceDeadline
);

event DormancyStateChanged(
    uint256 indexed tokenId,
    DormancyState newState
);

event ActivityProven(
    uint256 indexed tokenId,
    address indexed owner
);

event DormantCollateralClaimed(
    uint256 indexed tokenId,
    address indexed originalOwner,
    address indexed claimer,
    address treasureContract,
    uint256 treasureTokenId,
    uint256 collateralClaimed,
    uint256 vBTCBurned
);
```

### 5.7 Errors

```solidity
error NotDormantEligible(uint256 tokenId);
error AlreadyPoked(uint256 tokenId);
error NotClaimable(uint256 tokenId);
error NotTokenOwner(uint256 tokenId);
error InsufficientBtcToken(uint256 required, uint256 available);
```

### 5.8 Security Considerations

| Attack Vector | Mitigation |
|--------------|------------|
| Flash loan attack | Balance check is atomic; claimer must actually hold tokens |
| Front-running poke | Poke caller has no advantage; anyone can poke |
| Malicious poke spam | No harm to owner; they can respond anytime during grace period |
| Self-poke then claim | Requires vBTC amount; if owner has it, not dormant-eligible |
| Race condition (claim vs prove) | Atomic state: first valid transaction wins, second reverts |

**Race Condition Resolution (claim vs prove):**

When both `claimDormantCollateral()` and `proveActivity()` are pending in the mempool:

```
Scenario: Both transactions submitted simultaneously

Transaction A: proveActivity(tokenId)
Transaction B: claimDormantCollateral(tokenId)

Outcome depends on which transaction is mined first:

Case 1: proveActivity() executes first
├─ Updates lastActivity[tokenId]
├─ Clears pokeTimestamp[tokenId]
├─ NFT returns to ACTIVE state
└─ claimDormantCollateral() reverts with NotClaimable(tokenId)

Case 2: claimDormantCollateral() executes first
├─ Burns vBTC from claimer
├─ Extracts Child NFT to original owner
├─ Transfers BTC collateral to claimer
├─ Burns Parent NFT
└─ proveActivity() reverts with NotTokenOwner(tokenId) (NFT burned)
```

**Design Choice:** No special ordering guarantees. Both transactions check state atomically. The first valid transaction to execute wins. This is fair because:

1. **Owner has 30-day grace period** - ample time to respond before claiming is possible
2. **proveActivity() is instant** - owner can respond immediately when poked
3. **claimDormantCollateral() requires vBTC** - claimer must hold tokens
4. **Standard EVM semantics** - consistent with other DeFi protocols

**Recommended Owner Behavior:**
- Use `proveActivity()` as soon as possible after being poked
- Use a priority fee if concerned about timing
- Any activity (withdraw, transfer) also clears dormancy state

**Edge Cases:**

| Edge Case | Handling |
|-----------|----------|
| btcToken partially at owner address | Not dormant-eligible unless owner holds < required amount |
| Owner transfers Vault during POKE_PENDING | Transfer calls `_updateActivity()`, resets to ACTIVE |
| Multiple people try to poke | First poke sets timestamp; subsequent reverts with `AlreadyPoked` |
| Owner responds at last second | `proveActivity()` clears poke state regardless of timing |
| btcToken repurchased during grace | Claimer no longer meets criteria; `isDormantEligible` returns false |
| Treasure contract refuses transfer | Fail-fast: revert if Treasure extraction fails |

---

## 6. Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Early exit | Redeem with linear unlock | Discourages early exit, fair value return |
| Treasure on early redemption | Burned with Vault NFT | Commitment mechanism; disincentivizes early exit |
| Penalty destination | Issuer-configured | Flexibility for different use cases |
| Minting window | Optional (0 = instant) | Supports series/time-based releases |
| Collateral increase | Allowed during window | Enables DCA-style accumulation |
| Collateral withdrawal | Never during window | Prevents gaming/front-running |
| Cancel pending mint | Allowed during window | User protection before commitment |
| btcToken standard | ERC-20 (fungible) | DEX liquidity, DeFi composability, fractional sales |
| btcToken ratio | 1:1 with collateral | Simple valuation, direct BTC price tracking |
| btcToken collateral claim | Dynamic (current) | Simplifies mechanics, no replenishment required |
| btcToken withdrawal rights | None | Clear separation of principal from withdrawal rights |
| btcToken recombination | All-or-nothing | Prevents partial redemption gaming |
| Redemption lock mechanism | Requires full btcToken balance | Prevents unauthorized collateral redemption |
| Dormancy threshold | 1093 days (same as vesting) | Full market cycle of inactivity |
| Grace period | 30 days | One withdrawal period; reasonable response time |
| Poke mechanism | Anyone can initiate | Decentralized detection, no privileged actor |
| Owner notification | Grace period before claim | Fair warning to recover position |
| Treasure on dormant claim | Returned to original owner | Preserves user's original property |
| vBTC on dormant claim | Burned | Economic equivalence with normal recombination |
| Collateral on dormant claim | Transferred to claimer | Claimer receives BTC directly |
| Vault NFT on dormant claim | Burned | Empty shell after extraction - no value |
| Claim amount required | Original btcTokenAmount | Full amount ensures economic fairness |
