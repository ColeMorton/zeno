# Delegation Marketplace: Research Assessment

> **Version:** 1.0
> **Status:** Research
> **Last Updated:** 2025-12-30
> **Author:** Research Team
> **Related Documents:**
> - [Withdrawal_Delegation.md](../protocol/Withdrawal_Delegation.md)
> - [Technical_Specification.md](../protocol/Technical_Specification.md)

---

## 1. Executive Summary

This assessment evaluates the feasibility and design of a **Delegation Marketplace** for the BTCNFT Protocol—an on-chain orderbook enabling vault owners to monetize withdrawal delegation rights and buyers to acquire predictable Bitcoin yield streams.

**Key Findings:**

1. **Market Opportunity:** The protocol's wallet-level delegation system creates a novel asset class—time-bound withdrawal rights—with no existing marketplace for price discovery or trading.

2. **Technical Feasibility:** A marketplace can be implemented at the issuer layer without modifying the immutable protocol, using a two-step activation pattern where sellers grant delegation after payment confirmation.

3. **Economic Viability:** Fair value pricing models based on present value calculations suggest delegation rights trade at 85-95% of expected withdrawal value, creating sustainable buyer returns of 15-25% annualized.

4. **Implementation Complexity:** Estimated 800-1200 lines of Solidity with medium complexity, requiring integration with keeper networks for term expiry enforcement.

5. **Recommendation:** Proceed with development of an escrow-based marketplace with two-step activation, prioritizing simple listing mechanics before orderbook sophistication.

---

## 2. Problem Statement & Market Opportunity

### 2.1 Current State

The BTCNFT Protocol implements wallet-level withdrawal delegation through three core mappings in `VaultNFT.sol`:

```solidity
mapping(address => mapping(address => WalletDelegatePermission)) public walletDelegates;
mapping(address => uint256) public walletTotalDelegatedBPS;
mapping(address => mapping(uint256 => uint256)) public delegateVaultCooldown;
```

This system enables vault owners to grant percentage-based withdrawal rights to delegate addresses. However, the current implementation has significant limitations:

| Limitation | Impact |
|------------|--------|
| **No time-bound delegation** | Sellers cannot commit to fixed terms; revocable anytime |
| **No payment mechanism** | Delegation is free; no value exchange |
| **No marketplace** | Direct grant/revoke only; no price discovery |
| **Wallet-level only** | Cannot differentiate between vaults |

### 2.2 Market Opportunity

**Addressable Market Size:**

The protocol targets high-net-worth individuals and institutional treasuries holding significant Bitcoin positions. Assuming:

- 1,000 vaults with average 10 BTC collateral = 10,000 BTC TVL
- Average delegation of 30% = 3,000 BTC equivalent in delegation rights
- Annual turnover of 2x = 6,000 BTC in potential marketplace volume
- 1% protocol fee = 60 BTC annual revenue potential

**Demand Drivers:**

1. **Yield Seekers:** Buyers seeking predictable BTC-denominated returns without principal exposure
2. **Liquidity Needs:** Vault owners wanting immediate capital without early redemption penalties
3. **Treasury Automation:** Institutions delegating to operational wallets for expense management
4. **Passive Income:** Holders monetizing unused delegation capacity

### 2.3 Competitive Landscape

No direct competitors exist for withdrawal delegation trading. Adjacent markets include:

| Market | Similarity | Key Difference |
|--------|------------|----------------|
| **NFT Lending (Blur, NFTfi)** | Collateralized loans | Delegation preserves ownership |
| **Yield Trading (Pendle)** | Tokenized future yields | vestedBTC has perpetual, shrinking principal |
| **Options Markets (Dopex)** | Time-bound rights | Delegation is deterministic, not speculative |

The unique mechanics of vestedBTC—1.0% monthly withdrawals from shrinking collateral—create a novel market with no existing competition.

---

## 3. Technical Architecture

### 3.1 Design Constraints

The marketplace must operate within protocol constraints:

1. **Immutability:** Protocol cannot be modified; marketplace is issuer-layer only
2. **Wallet-Level Delegation:** Protocol grants apply to ALL vaults, not specific ones
3. **No On-Chain Enforcement:** Protocol has no concept of term expiry
4. **Independent Cooldowns:** Each delegate has 30-day per-vault cooldowns

### 3.2 Architecture Pattern: Escrow-Based Marketplace

```
┌─────────────────────────────────────────────────────────────┐
│                   DELEGATION MARKETPLACE                     │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ ListingRegistry  │         │  OrderbookEngine │          │
│  │                  │         │                  │          │
│  │ - Create/cancel  │         │ - Price discovery│          │
│  │ - Validate owner │         │ - Order matching │          │
│  └────────┬─────────┘         └────────┬─────────┘          │
│           │                            │                     │
│           └────────────┬───────────────┘                     │
│                        │                                     │
│               ┌────────┴────────┐                            │
│               │  TermController  │                            │
│               │                  │                            │
│               │ - Payment escrow │                            │
│               │ - Term tracking  │                            │
│               │ - Expiry events  │                            │
│               └────────┬─────────┘                            │
└────────────────────────┼────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 PROTOCOL LAYER (IMMUTABLE)                   │
│                                                              │
│  grantWithdrawalDelegate(delegate, percentageBPS)           │
│  revokeWithdrawalDelegate(delegate)                         │
│  withdrawAsDelegate(tokenId) → collateral                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 Integration Pattern: Two-Step Activation

Since the marketplace cannot call `grantWithdrawalDelegate()` on behalf of sellers, we implement a two-step flow:

**Step 1: Purchase**
```
Buyer → purchaseDelegation(listingId, durationMonths)
         │
         ├── Validate listing active
         ├── Validate seller still owns vault
         ├── Validate delegation capacity available
         ├── Transfer payment to escrow
         └── Create pending DelegationTerm
```

**Step 2: Activation**
```
Seller → grantWithdrawalDelegate(buyer, percentageBPS)  // Protocol call
         │
Seller → activateTerm(termId)  // Marketplace call
         │
         ├── Verify delegation granted on protocol
         ├── Mark term as activated
         └── Release payment to seller
```

**Step 3: Expiry**
```
Keeper → processExpiredTerms([termIds])
          │
          └── Mark terms as expired, emit events

Seller → revokeWithdrawalDelegate(buyer)  // Protocol call
          │
Seller → confirmRevocation(termId)  // Marketplace call
          │
          └── Verify revocation, update status
```

This pattern maintains protocol immutability while enabling marketplace functionality through social consensus and economic incentives.

---

## 4. Smart Contract Design

### 4.1 Core Data Structures

```solidity
struct DelegationListing {
    uint256 listingId;
    address seller;              // Vault owner
    uint256 vaultId;             // 0 = all vaults, >0 = specific vault
    uint256 percentageBPS;       // Delegation percentage (100 = 1%)
    uint256 pricePerMonth;       // WBTC price for 1 month
    uint256 minDurationMonths;   // Minimum commitment
    uint256 maxDurationMonths;   // Maximum commitment
    uint256 createdAt;
    ListingStatus status;        // Active, Paused, Cancelled
}

struct DelegationTerm {
    uint256 termId;
    uint256 listingId;
    address buyer;               // Delegate
    address seller;              // Vault owner
    uint256 vaultId;
    uint256 percentageBPS;
    uint256 startTime;
    uint256 endTime;
    uint256 totalPaid;
    TermStatus status;           // Pending, Active, Expired, Terminated
}
```

### 4.2 Key Functions

**Listing Management:**
- `createListing(vaultId, percentageBPS, pricePerMonth, minDuration, maxDuration)`
- `updateListing(listingId, pricePerMonth, minDuration, maxDuration)`
- `pauseListing(listingId)` / `resumeListing(listingId)`
- `cancelListing(listingId)`

**Purchase Flow:**
- `purchaseDelegation(listingId, durationMonths)` → Creates pending term
- `activateTerm(termId)` → Seller confirms delegation granted
- `cancelPendingTerm(termId)` → Buyer cancels if seller doesn't activate

**Term Management:**
- `processExpiredTerms(termIds[])` → Keeper marks expired terms
- `confirmRevocation(termId)` → Seller confirms delegation revoked
- `requestEarlyTermination(termId)` → Buyer exits with penalty
- `sellerTerminate(termId)` → Seller exits with refund to buyer

**View Functions:**
- `getActiveListing(listingId)` → Listing details
- `getSellerListings(seller)` → All listings by seller
- `getBuyerTerms(buyer)` → All terms held by buyer
- `getMarketStats()` → Volume, active listings, average price

### 4.3 Fee Structure

```solidity
uint256 constant LISTING_FEE = 0;              // Free to list
uint256 constant PROTOCOL_FEE_BPS = 100;       // 1% on successful trades
uint256 constant EARLY_TERMINATION_FEE = 500;  // 5% penalty for early exit
uint256 constant ACTIVATION_TIMEOUT = 7 days;  // Buyer can cancel if not activated
```

---

## 5. Economic Model

### 5.1 Fair Value Pricing

The fair value of delegation rights equals the present value of expected withdrawal streams:

```
PV = Σ (W_t × D) / (1 + r)^t

Where:
- W_t = Monthly withdrawal at time t = Collateral_t × 1%
- D = Delegation percentage (e.g., 50%)
- r = Monthly discount rate (e.g., 0.5-1%)
- Collateral_t = Collateral_{t-1} × 99% (shrinking principal)
```

**Example: 12-Month 50% Delegation on 10 BTC Vault**

| Month | Collateral | Withdrawal (1%) | Delegate Share (50%) | PV Factor (1%/mo) | Present Value |
|-------|------------|-----------------|---------------------|------------------|---------------|
| 1 | 10.00 BTC | 0.100 BTC | 0.050 BTC | 0.990 | 0.0495 BTC |
| 2 | 9.90 BTC | 0.099 BTC | 0.0495 BTC | 0.980 | 0.0485 BTC |
| 3 | 9.80 BTC | 0.098 BTC | 0.049 BTC | 0.971 | 0.0476 BTC |
| ... | ... | ... | ... | ... | ... |
| 12 | 8.86 BTC | 0.089 BTC | 0.0445 BTC | 0.887 | 0.0395 BTC |
| **Total** | | | **0.573 BTC** | | **~0.54 BTC** |

**Fair price for 12-month 50% delegation: 0.50-0.55 BTC**

### 5.2 Pricing Factors

| Factor | Impact on Price | Rationale |
|--------|-----------------|-----------|
| **Collateral Size** | Proportional | Larger vaults = larger absolute withdrawals |
| **Vault Age** | Negative | Older vaults have less remaining collateral |
| **Delegation %** | Proportional | Higher % = higher share of withdrawals |
| **Duration** | Diminishing | Longer terms have lower marginal value |
| **Seller Reputation** | Premium | Reliable sellers command higher prices |
| **Market Conditions** | Variable | Bull markets increase demand |

### 5.3 Buyer Returns

Assuming purchase at fair value (PV = 0.54 BTC) for expected withdrawals (0.573 BTC):

```
Buyer IRR = (Total Withdrawals / Purchase Price)^(1/Years) - 1
         = (0.573 / 0.54)^(1/1) - 1
         = 6.1% annual

With 10% discount to fair value (Purchase = 0.49 BTC):
Buyer IRR = (0.573 / 0.49)^1 - 1 = 17.0% annual
```

Buyers purchasing at 85-95% of fair value can expect 15-25% annualized returns, competitive with DeFi yield farming but with deterministic cash flows.

### 5.4 Seller Economics

Sellers receive immediate liquidity in exchange for future withdrawal rights:

```
Seller receives: 0.54 BTC upfront (at fair value)
Seller forgoes: 0.573 BTC over 12 months

Effective cost of capital:
= (Forgone / Received)^(1/Years) - 1
= (0.573 / 0.54)^1 - 1
= 6.1% annual borrowing cost
```

This is significantly cheaper than:
- Early redemption (linear forfeit of remaining collateral)
- DeFi lending (8-15% APR on WBTC)
- Centralized exchange loans (10-20% APR)

---

## 6. Security Analysis

### 6.1 Threat Model

| Threat | Attack Vector | Likelihood | Impact | Mitigation |
|--------|--------------|------------|--------|------------|
| **Front-running** | MEV bots purchase before legitimate buyers | Medium | Low | Commit-reveal for large orders |
| **Vault Transfer** | Seller transfers vault after sale | Medium | High | Verify ownership on activation |
| **Over-delegation** | Seller lists >100% total | Low | Medium | Check capacity on purchase |
| **Non-activation** | Seller takes payment, never grants | Medium | High | Activation timeout with refund |
| **Non-revocation** | Seller doesn't revoke after expiry | Medium | Medium | Reputation system, keeper alerts |
| **Sybil Listings** | Seller floods orderbook | Low | Low | Rate limits, deposit requirements |
| **Price Manipulation** | Wash trading to set false prices | Low | Medium | Volume-weighted pricing |

### 6.2 Invariants

The marketplace must maintain these invariants:

1. **Delegation Capacity:** `walletTotalDelegatedBPS[seller] + pending <= 10000`
2. **Payment Integrity:** `term.totalPaid == listing.pricePerMonth × durationMonths`
3. **Ownership Consistency:** `ownerOf(listing.vaultId) == listing.seller` (checked on activation)
4. **Term Lifecycle:** Expired terms cannot be reactivated

### 6.3 Access Control

| Function | Caller Requirement |
|----------|-------------------|
| `createListing` | Vault owner |
| `purchaseDelegation` | Any address with payment token |
| `activateTerm` | Listing seller only |
| `cancelPendingTerm` | Term buyer only (after timeout) |
| `requestEarlyTermination` | Term buyer only |
| `sellerTerminate` | Term seller only |
| `processExpiredTerms` | Any address (keeper-callable) |

---

## 7. Implementation Roadmap

### Phase 1: Minimal Viable Marketplace (4-6 weeks)

**Scope:**
- Simple listing creation and management
- Fixed-price purchases (no orderbook)
- Two-step activation flow
- Manual term expiry tracking

**Deliverables:**
- `DelegationMarketplace.sol` (~400 LOC)
- Basic frontend for listing/purchasing
- Subgraph for indexing

**Success Metrics:**
- 10+ listings created
- 5+ successful term activations
- <1 failed activation (non-grant)

### Phase 2: Orderbook & Price Discovery (4-6 weeks)

**Scope:**
- Limit orders (buy bids)
- Order matching engine
- Price history tracking
- Volume-weighted average pricing

**Deliverables:**
- `OrderbookEngine.sol` (~300 LOC)
- Price chart UI
- Market depth visualization

**Success Metrics:**
- Bid-ask spread <5%
- 50+ matched orders
- Price stability within 10% of fair value

### Phase 3: Automation & Keeper Integration (2-4 weeks)

**Scope:**
- Gelato Web3 Function for term expiry
- Automated activation reminders
- Reputation scoring

**Deliverables:**
- `DelegationKeeper.ts` (Gelato function)
- Notification system
- Seller/buyer dashboards

**Success Metrics:**
- 95%+ terms processed within 24h of expiry
- Seller response time <48h average

### Phase 4: Advanced Features (Ongoing)

**Potential Extensions:**
- Dutch auctions for time-sensitive listings
- Bundle purchases (multiple listings)
- Secondary market for active terms
- Cross-chain marketplace (Arbitrum)

---

## 8. Competitive Positioning

### 8.1 Unique Value Proposition

The Delegation Marketplace creates a new asset class with properties not found in existing DeFi:

| Property | Delegation Rights | Yield Tokens (Pendle) | Options (Dopex) |
|----------|------------------|----------------------|-----------------|
| **Underlying** | BTC withdrawal stream | Yield-bearing tokens | Asset price |
| **Determinism** | Fixed 1% monthly | Variable yield | Speculative |
| **Principal** | Shrinking | Fixed until maturity | N/A |
| **Risk Profile** | Low (protocol risk only) | Medium (yield risk) | High (price risk) |
| **Liquidity** | Medium (orderbook) | High (AMM) | Medium (options chain) |

### 8.2 Market Positioning

**Target Users:**

1. **Institutional Treasuries:** Seek predictable BTC yield for operational expenses
2. **Family Offices:** Long-term BTC holders wanting passive income without selling
3. **Yield Farmers:** DeFi natives seeking deterministic returns
4. **Automation Services:** Custody providers offering managed withdrawal services

**Go-to-Market:**

1. Seed marketplace with issuer-sponsored listings (reduced fees)
2. Partner with custody providers for institutional access
3. Integrate with portfolio trackers (DeBank, Zapper)
4. Build SDK for third-party marketplace frontends

---

## 9. Risks & Mitigations

### 9.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Smart contract bug | Low | Critical | Audit, formal verification, bug bounty |
| Keeper network failure | Medium | High | Multiple keeper providers, manual fallback |
| Subgraph indexing lag | Medium | Medium | Multiple indexers, direct RPC fallback |

### 9.2 Economic Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Low liquidity | High (initial) | Medium | Issuer-seeded listings, incentivized LPs |
| Price manipulation | Low | Medium | Volume-weighted pricing, time delays |
| Seller default (non-activation) | Medium | Medium | Activation timeout, reputation system |

### 9.3 Regulatory Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Securities classification | Medium | High | Legal opinion, jurisdiction analysis |
| AML/KYC requirements | Medium | Medium | Optional compliance module, address attestations |

---

## 10. Conclusion & Recommendations

### 10.1 Summary

The Delegation Marketplace represents a novel DeFi primitive enabling price discovery and trading of withdrawal delegation rights. The design is technically feasible within protocol constraints, economically viable for both buyers and sellers, and addresses a genuine market need for predictable BTC yield instruments.

### 10.2 Recommendations

1. **Proceed with Phase 1 development** using the escrow-based, two-step activation pattern.

2. **Prioritize seller experience** in initial release—simple listing creation with minimal friction.

3. **Implement activation timeout** (7 days) with automatic refund to protect buyers from non-responsive sellers.

4. **Build reputation system** from day one to incentivize seller compliance with term lifecycle.

5. **Defer orderbook complexity** until basic marketplace achieves product-market fit.

6. **Engage legal counsel** on securities classification before public launch.

### 10.3 Open Questions for Future Research

1. Should the protocol add native time-bound delegation to eliminate trust in seller revocation?

2. Can EIP-712 permits enable single-transaction purchases without protocol modification?

3. What is the optimal minimum term duration to balance liquidity vs. transaction costs?

4. Should the marketplace support cross-chain terms for Arbitrum-bridged vestedBTC?

5. How should reputation scores weight different factors (activation speed, revocation compliance, volume)?

---

## 11. Future Evolution

### 11.1 Protocol Enhancement Candidates

While the marketplace is designed to operate without protocol modifications, the protocol is currently in development phase. The following enhancements should be integrated directly into `VaultNFT.sol` before mainnet deployment to significantly improve marketplace functionality.

#### 11.1.1 Hybrid Delegation: Wallet-Level + Vault-Specific

The current wallet-level-only delegation creates marketplace friction:

| Limitation | Marketplace Impact |
|------------|-------------------|
| **Wallet-level only** | Sellers cannot offer different terms per vault |
| **No vault isolation** | Multi-vault owners must delegate all or none |
| **Buyer over-exposure** | Purchasing delegation exposes buyer to all seller vaults |
| **No granular pricing** | Cannot price by vault characteristics (age, collateral) |

**Solution: Vault-Specific Delegation with Override Semantics**

```solidity
// ═══════════════════════════════════════════════════════════════
// EXISTING (wallet-level) - unchanged
// ═══════════════════════════════════════════════════════════════
mapping(address => mapping(address => WalletDelegatePermission)) public walletDelegates;
mapping(address => uint256) public walletTotalDelegatedBPS;

// ═══════════════════════════════════════════════════════════════
// NEW (vault-specific)
// ═══════════════════════════════════════════════════════════════
struct VaultDelegatePermission {
    uint256 percentageBPS;      // Basis points (100 = 1%, 10000 = 100%)
    uint256 grantedAt;          // Timestamp when granted
    uint256 expiresAt;          // 0 = no expiry, >0 = auto-expires
    bool active;                // Permission status
}

mapping(uint256 => mapping(address => VaultDelegatePermission)) public vaultDelegates;
mapping(uint256 => uint256) public vaultTotalDelegatedBPS;
```

**Delegation Resolution Logic:**

```
Resolution Priority:
1. Check vaultDelegates[tokenId][delegate] → if active and not expired, USE THIS
2. Else check walletDelegates[ownerOf(tokenId)][delegate] → if active, USE THIS
3. Else → NO PERMISSION
```

Vault-specific is explicit intent—when set, it overrides implicit wallet-level. This matches user expectation: "I granted Bob 50% on vault #42" should mean exactly that.

**Capacity Model:**
- `walletTotalDelegatedBPS[owner] <= 10000` — 100% cap across wallet-level grants
- `vaultTotalDelegatedBPS[tokenId] <= 10000` — 100% cap per vault-specific grants
- **Not Additive**: When vault-specific is active, wallet-level is ignored for that vault/delegate pair

**Transfer Semantics:**

| Scenario | Wallet-Level | Vault-Specific |
|----------|--------------|----------------|
| **On Transfer** | Stops applying (new owner's permissions apply) | **Travels with vault** |
| **Rationale** | Permission is to `ownerOf()`, which changes | Permission is to `tokenId`, which doesn't change |

This is critical—vault-specific delegation represents a **property of the vault itself**, not the owner. Marketplace buyers retain access even if vault changes hands.

**Grant Function:**

```solidity
function grantVaultDelegate(
    uint256 tokenId,
    address delegate,
    uint256 percentageBPS,
    uint256 durationSeconds  // 0 = indefinite, >0 = time-bound
) external {
    if (ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);
    if (delegate == address(0)) revert ZeroAddress();
    if (delegate == msg.sender) revert CannotDelegateSelf();
    if (percentageBPS == 0 || percentageBPS > 10000) revert InvalidPercentage(percentageBPS);

    uint256 currentVaultDelegated = vaultTotalDelegatedBPS[tokenId];
    VaultDelegatePermission storage existing = vaultDelegates[tokenId][delegate];

    if (existing.active) {
        currentVaultDelegated -= existing.percentageBPS;
    }
    if (currentVaultDelegated + percentageBPS > 10000) revert ExceedsVaultDelegationLimit(tokenId);

    uint256 expiresAt = durationSeconds > 0 ? block.timestamp + durationSeconds : 0;
    vaultDelegates[tokenId][delegate] = VaultDelegatePermission({
        percentageBPS: percentageBPS,
        grantedAt: block.timestamp,
        expiresAt: expiresAt,
        active: true
    });
    vaultTotalDelegatedBPS[tokenId] = currentVaultDelegated + percentageBPS;

    emit VaultDelegateGranted(tokenId, delegate, percentageBPS, expiresAt);
}
```

**Modified Withdrawal Resolution:**

```solidity
function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount) {
    _requireOwned(tokenId);
    address vaultOwner = ownerOf(tokenId);

    if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
        revert StillVesting(tokenId);
    }

    // RESOLUTION: Vault-specific takes precedence over wallet-level
    uint256 effectivePercentageBPS;

    VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][msg.sender];
    if (vaultPerm.active && (vaultPerm.expiresAt == 0 || vaultPerm.expiresAt > block.timestamp)) {
        effectivePercentageBPS = vaultPerm.percentageBPS;
    } else {
        WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][msg.sender];
        if (!walletPerm.active || walletTotalDelegatedBPS[vaultOwner] == 0) {
            revert NotActiveDelegate(tokenId, msg.sender);
        }
        effectivePercentageBPS = walletPerm.percentageBPS;
    }

    // Cooldown check (unchanged - already per-vault)
    uint256 delegateLastWithdrawal = delegateVaultCooldown[msg.sender][tokenId];
    if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
        revert WithdrawalPeriodNotMet(tokenId, msg.sender);
    }

    uint256 currentCollateral = _collateralAmount[tokenId];
    uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
    withdrawnAmount = (totalPool * effectivePercentageBPS) / 10000;

    if (withdrawnAmount == 0) return 0;

    _collateralAmount[tokenId] = currentCollateral - withdrawnAmount;
    delegateVaultCooldown[msg.sender][tokenId] = block.timestamp;
    _updateActivity(tokenId);

    IERC20(collateralToken).safeTransfer(msg.sender, withdrawnAmount);
    emit DelegatedWithdrawal(tokenId, msg.sender, vaultOwner, withdrawnAmount);

    return withdrawnAmount;
}
```

**Enhanced Eligibility Check with Type Reporting:**

```solidity
enum DelegationType { None, WalletLevel, VaultSpecific }

function canDelegateWithdraw(uint256 tokenId, address delegate)
    external
    view
    returns (bool canWithdraw, uint256 amount, DelegationType delegationType)
{
    address vaultOwner;
    try this.ownerOf(tokenId) returns (address owner_) {
        vaultOwner = owner_;
    } catch {
        return (false, 0, DelegationType.None);
    }

    if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
        return (false, 0, DelegationType.None);
    }

    uint256 effectivePercentageBPS;
    DelegationType dtype;

    VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][delegate];
    if (vaultPerm.active && (vaultPerm.expiresAt == 0 || vaultPerm.expiresAt > block.timestamp)) {
        effectivePercentageBPS = vaultPerm.percentageBPS;
        dtype = DelegationType.VaultSpecific;
    } else {
        WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][delegate];
        if (!walletPerm.active || walletTotalDelegatedBPS[vaultOwner] == 0) {
            return (false, 0, DelegationType.None);
        }
        effectivePercentageBPS = walletPerm.percentageBPS;
        dtype = DelegationType.WalletLevel;
    }

    uint256 delegateLastWithdrawal = delegateVaultCooldown[delegate][tokenId];
    if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
        return (false, 0, dtype);
    }

    uint256 currentCollateral = _collateralAmount[tokenId];
    uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
    amount = (totalPool * effectivePercentageBPS) / 10000;

    return (amount > 0, amount, dtype);
}
```

#### 11.1.2 Native Time-Bound Delegation

The `expiresAt` field in `VaultDelegatePermission` enables time-bound delegation **without seller action**:

```solidity
// During withdrawal resolution:
if (vaultPerm.active && (vaultPerm.expiresAt == 0 || vaultPerm.expiresAt > block.timestamp)) {
    // Permission valid
}
// Expired permissions are ignored but not deleted—gas efficient, no keeper required
```

**Expiry Semantics:**
- **No fallback**: When vault-specific delegation expires, it does NOT fall back to wallet-level
- **Rationale**: Clean semantics—buyer knows exactly when access ends, no ambiguity
- **Gas efficiency**: Expired permissions remain in storage but are ignored during resolution

**Marketplace Integration:**

```
Seller → grantVaultDelegate(vaultId, buyer, 50%, 365 days)
         │
         └── Buyer receives 12-month delegation
             │
             ├── Buyer withdraws monthly (50% of 1% pool)
             └── After 365 days, permission auto-expires
                 └── No seller action required
```

This eliminates the trust assumption around seller revocation compliance, enabling fully trustless term lifecycle management.

#### 11.1.3 EIP-712 Permit for Atomic Delegation

Enable single-transaction marketplace purchases where buyer payment and seller delegation grant occur atomically:

```solidity
bytes32 constant VAULT_DELEGATION_TYPEHASH = keccak256(
    "VaultDelegation(uint256 tokenId,address delegate,uint256 percentageBPS,uint256 durationSeconds,uint256 nonce,uint256 deadline)"
);

function grantVaultDelegateWithPermit(
    uint256 tokenId,
    address delegate,
    uint256 percentageBPS,
    uint256 durationSeconds,
    uint256 deadline,
    bytes calldata signature
) external {
    address owner = ownerOf(tokenId);
    bytes32 structHash = keccak256(abi.encode(
        VAULT_DELEGATION_TYPEHASH,
        tokenId,
        delegate,
        percentageBPS,
        durationSeconds,
        nonces[owner]++,
        deadline
    ));
    bytes32 digest = _hashTypedDataV4(structHash);
    address signer = ECDSA.recover(digest, signature);

    if (signer != owner) revert InvalidSignature();
    if (block.timestamp > deadline) revert ExpiredSignature();

    _grantVaultDelegate(tokenId, delegate, percentageBPS, durationSeconds);
}
```

**Atomic Purchase Flow:**

```
Buyer → marketplace.purchaseDelegation(listingId)
         │
         ├── Transfer payment from buyer
         ├── Call grantVaultDelegateWithPermit() with seller's signature
         └── Delegation active immediately (no Step 2)
```

This eliminates the two-step activation flow, reducing friction and trust assumptions.

**Security Considerations:**
- **Replay prevention**: Include chainId in EIP-712 domain separator
- **Front-running mitigation**: Include delegate address in signed message
- **Nonce management**: Per-owner nonces prevent signature reuse

#### 11.1.4 New Interface Elements

**Events:**

```solidity
event VaultDelegateGranted(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 percentageBPS,
    uint256 expiresAt
);

event VaultDelegateUpdated(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 oldPercentageBPS,
    uint256 newPercentageBPS,
    uint256 expiresAt
);

event VaultDelegateRevoked(uint256 indexed tokenId, address indexed delegate);
```

**Errors:**

```solidity
error NotVaultOwner(uint256 tokenId);
error ExceedsVaultDelegationLimit(uint256 tokenId);
error VaultDelegateNotActive(uint256 tokenId, address delegate);
error InvalidSignature();
error ExpiredSignature();
```

**View Functions:**

```solidity
function getVaultDelegatePermission(uint256 tokenId, address delegate)
    external view returns (VaultDelegatePermission memory);

function vaultTotalDelegatedBPS(uint256 tokenId) external view returns (uint256);

function getEffectiveDelegation(uint256 tokenId, address delegate)
    external view returns (uint256 percentageBPS, DelegationType dtype, bool isExpired);
```

#### 11.1.5 Security Invariants

```solidity
// Wallet-level invariant (existing)
assert(walletTotalDelegatedBPS[owner] <= 10000);

// Vault-level invariant (new)
assert(vaultTotalDelegatedBPS[tokenId] <= 10000);

// Resolution invariant
assert(effectivePercentage == vaultSpecific.active ? vaultSpecific.percentageBPS : walletLevel.percentageBPS);

// Expiry invariant
assert(vaultPerm.active && vaultPerm.expiresAt > 0 && block.timestamp > vaultPerm.expiresAt => cannotWithdraw);
```

**Attack Vectors & Mitigations:**

| Vector | Risk | Mitigation |
|--------|------|------------|
| **Vault-specific spam** | Attacker grants many delegations to burn gas | Only owner can grant; storage cost deters spam |
| **Permit replay** | Signature reused across chains | ChainId in EIP-712 domain |
| **Permit front-running** | Attacker uses permit before intended recipient | Delegate address in signed message |

#### 11.1.6 Open Questions

1. **Should wallet-level grants be deprecated long-term?** Or maintain both indefinitely for different use cases?

2. **Cap coordination**: Should there be a combined cap across wallet + vault-specific for a given tokenId?

3. **Permit scope**: Should permits support batch grants (multiple vaults in one signature)?

4. **Delegation chaining**: Should marketplace receive 100% delegation and sub-delegate to buyers?

### 11.2 Cross-Chain Considerations

With vestedBTC bridging to Arbitrum via LayerZero, the marketplace must consider multi-chain scenarios:

**Single-Chain Deployment (Recommended Initially):**
- Marketplace deployed on Ethereum mainnet only
- Delegation rights valid for mainnet vaults only
- Simpler UX, lower complexity

**Multi-Chain Deployment (Future):**
- Separate marketplace instances per chain
- Cross-chain term synchronization challenges
- Bridge latency affects activation flow

**Unified Cross-Chain (Advanced):**
- Single marketplace contract with cross-chain messaging
- LayerZero OFT pattern for term NFTs
- Complex but optimal UX

### 11.3 Institutional Integration Paths

**Custody Provider Integration:**
- Fireblocks, BitGo, Anchorage could offer delegation management as a service
- Institutional API for programmatic listing/purchasing
- Compliance attestation integration

**Fund Structures:**
- Delegation rights could be packaged into fund vehicles
- Yield-focused ETPs backed by delegation portfolios
- Regulatory considerations for fund classification

---

## Appendix A: Gas Estimates

| Operation | Estimated Gas | Cost @ 30 gwei |
|-----------|--------------|----------------|
| createListing | ~150,000 | ~0.0045 ETH |
| purchaseDelegation | ~200,000 | ~0.006 ETH |
| activateTerm | ~100,000 | ~0.003 ETH |
| processExpiredTerms (10) | ~300,000 | ~0.009 ETH |
| confirmRevocation | ~80,000 | ~0.0024 ETH |

## Appendix B: Subgraph Entity Relationships

```
DelegationListing (1) ──< DelegationTerm (many)
                              │
                              └──< DelegatedWithdrawal (many)

MarketStats (1) ── aggregates ── All entities
```

## Appendix C: Integration with Existing Infrastructure

**Protocol Layer:**
- `VaultNFT.grantWithdrawalDelegate()` - Seller grants delegation
- `VaultNFT.revokeWithdrawalDelegate()` - Seller revokes delegation
- `VaultNFT.withdrawAsDelegate()` - Buyer claims withdrawals
- `VaultNFT.canDelegateWithdraw()` - Check eligibility

**Issuer Layer:**
- `WithdrawalAutomationHelper.batchCanDelegateWithdraw()` - Batch eligibility checks
- `WithdrawalAutomationHelper.getAutomationStatus()` - Detailed status

**External Dependencies:**
- Gelato Web3 Functions - Term expiry automation
- The Graph - Event indexing
- WBTC ERC-20 - Payment token
