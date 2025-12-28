# Research Assessment: BTCNFT Protocol Collateral Architecture

> **Version:** 1.0
> **Status:** Research
> **Last Updated:** 2025-12-28

## Research Question

**Whitelist-style multi-collateral (wBTC, cbBTC, tBTC) in single immutable deployment VS 1:1 protocol deployment per BTC backing (vestedWBTC, vestedCBBTC, etc.)**

---

## Current Architecture Analysis

### Existing Implementation

**File:** `contracts/protocol/src/VaultNFT.sol`

```solidity
mapping(address => bool) public acceptedCollateralTokens;  // Line 18

constructor(
    address _btcToken,
    address[] memory _acceptedTokens  // Whitelist configured at deployment
) ERC721("Vault NFT", "VAULT") {
    btcToken = IBtcToken(_btcToken);
    for (uint256 i = 0; i < _acceptedTokens.length; i++) {
        acceptedCollateralTokens[_acceptedTokens[i]] = true;
    }
}
```

**Current design:** Whitelist-based multi-collateral with single vestedBTC (vBTC) token.

**Key observation:** Each vault stores its specific collateral token address (`_collateralToken[tokenId]`), allowing heterogeneous collateral types within the same protocol instance.

---

## Architecture Comparison

### Option A: Single Protocol + Whitelist (Current Design)

```
┌─────────────────────────────────────────────────────────┐
│                    VaultNFT (Single)                     │
│  acceptedTokens: [wBTC, cbBTC, tBTC]                    │
├─────────────────────────────────────────────────────────┤
│  Vault #1: 1.0 wBTC collateral                          │
│  Vault #2: 0.5 cbBTC collateral                         │
│  Vault #3: 2.0 tBTC collateral                          │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   BtcToken (vBTC)     │
              │   Single ERC-20       │
              │   Fungible claims     │
              └───────────────────────┘
```

### Option B: 1:1 Protocol Deployment Per Collateral

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ VaultNFT-WBTC   │  │ VaultNFT-CBBTC  │  │ VaultNFT-TBTC   │
│ accepts: [wBTC] │  │ accepts: [cbBTC]│  │ accepts: [tBTC] │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ vestedWBTC      │  │ vestedCBBTC     │  │ vestedTBTC      │
│ (vWBTC)         │  │ (vCBBTC)        │  │ (vTBTC)         │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## Wrapped BTC Collateral Analysis

### Trust Model Comparison

| Token | Custody Model | Signing | Decentralization | Risk Profile |
|-------|--------------|---------|------------------|--------------|
| **wBTC** | BitGo consortium | 2-of-3 multisig | Low (3 custodians) | Counterparty + Justin Sun concerns |
| **cbBTC** | Coinbase (single) | Centralized | Lowest | Single point of failure, blacklist capability |
| **tBTC** | Threshold Network | 51-of-100 tECDSA | Highest | Threshold cryptography, economic security |

### Recent Market Developments (2024-2025)

- **wBTC:** MakerDAO gradually removing as collateral; Coinbase delisted; Justin Sun involvement raised governance concerns
- **cbBTC:** Launched September 2024; US-regulated; no proof of reserves published; blacklist functionality in smart contract
- **tBTC:** $490M TVL; 0% mint fee, 0.2% redemption; trust-minimized alternative gaining traction

### Sources

- [Cointelegraph Research](https://cointelegraph.com/research/wrapped-bitcoin-in-defi-evaluating-wbtc-cbbtc-and-tbtc)
- [OAK Research](https://oakresearch.io/en/analyses/fundamentals/wrapped-bitcoin-btc-overview-wrapping-alternatives)
- [LX Research](https://www.lxresearch.co/analyzing-tbtc-against-wbtc-and-cbbtc/)

---

## Architecture Decision Matrix

### Dimension 1: vestedBTC Fungibility

| Aspect | Option A (Whitelist) | Option B (1:1 Deployment) |
|--------|---------------------|---------------------------|
| **Fungibility** | Single vBTC pool mixes all collateral risks | Separate tokens isolate risk per backing |
| **Liquidity** | Deeper liquidity in single pool | Fragmented across multiple tokens |
| **Risk clarity** | Holder bears blended risk | Clear backing per token |
| **DeFi integration** | One integration point | Multiple integrations required |

**Critical insight:** With whitelist design, a user holding vBTC cannot know which underlying collateral backs their claim. If cbBTC suffers a blacklist event while wBTC remains sound, the vBTC holder bears correlated risk.

### Dimension 2: Match Pool Economics

| Aspect | Option A (Whitelist) | Option B (1:1 Deployment) |
|--------|---------------------|---------------------------|
| **Pool size** | Single large pool | Multiple smaller pools |
| **Cross-subsidization** | wBTC forfeiture funds cbBTC holders | Isolated per collateral type |
| **Incentive alignment** | Misaligned (risk mixing) | Pure (homogeneous backing) |

**Critical insight:** Match pool creates cross-collateral risk transfer. Early wBTC redeemers fund cbBTC holders' match claims - incentive distortion.

### Dimension 3: Operational Complexity

| Aspect | Option A (Whitelist) | Option B (1:1 Deployment) |
|--------|---------------------|---------------------------|
| **Deployment** | Single contract set | N deployments (N = collateral types) |
| **Gas costs** | Lower (shared infrastructure) | Higher (separate state per deployment) |
| **Upgrade path** | Simpler (one codebase) | Parallel maintenance |
| **Issuer integration** | One protocol address | Multiple protocol addresses |

### Dimension 4: Risk Isolation

| Scenario | Option A Impact | Option B Impact |
|----------|-----------------|-----------------|
| **cbBTC blacklist** | All vBTC holders affected proportionally | Only vestedCBBTC holders affected |
| **wBTC custody failure** | All vBTC holders affected proportionally | Only vestedWBTC holders affected |
| **tBTC threshold breach** | All vBTC holders affected proportionally | Only vestedTBTC holders affected |

---

## Economic Analysis

### Scenario: cbBTC Regulatory Event

**Assumption:** Coinbase blacklists 10% of cbBTC addresses due to compliance.

**Option A (Whitelist):**
```
matchPool composition: 40% wBTC-origin, 60% cbBTC-origin
Affected cbBTC collateral: 6% of matchPool
All vBTC holders bear 6% haircut risk on match claims
```

**Option B (1:1 Deployment):**
```
vestedCBBTC matchPool: 100% cbBTC-origin
vestedCBBTC holders bear 10% haircut risk
vestedWBTC holders: 0% affected
vestedTBTC holders: 0% affected
```

### Risk-Adjusted Value Proposition

The protocol's value is perpetual percentage-based withdrawals. If underlying collateral becomes inaccessible (blacklist, custody failure), withdrawal rights become worthless.

**Whitelist design couples uncorrelated risks.** A holder seeking wBTC exposure inadvertently takes cbBTC counterparty risk through the fungible vBTC token.

---

## Recommendation

### Primary: Option B - 1:1 Protocol Deployment Per Collateral

**Rationale:**

1. **Risk isolation:** Each vestedBTC variant (vWBTC, vCBBTC, vTBTC) has clear, non-blended backing
2. **Market pricing:** DeFi can price each token based on its specific custody risk
3. **Incentive purity:** Match pools redistribute within homogeneous collateral types
4. **Regulatory clarity:** Regulatory action against one wrapper doesn't cascade
5. **User choice:** Holders explicitly select their risk profile by choosing collateral type

**Implementation approach:**
- Deploy identical VaultNFT + BtcToken contract pairs per collateral type
- Configure `acceptedCollateralTokens` with single entry per deployment
- Use distinct token symbols: vWBTC, vCBBTC, vTBTC

### Alternative: Hybrid Approach (If Liquidity Paramount)

If liquidity concentration in single vBTC pool is essential:
- Maintain whitelist design
- Expose collateral breakdown via view functions
- Accept blended risk as protocol characteristic
- Document clearly in user materials

---

## Critical Files for Implementation

If proceeding with Option B:

| File | Change |
|------|--------|
| `contracts/protocol/src/BtcToken.sol` | Parameterize name/symbol in constructor |
| `contracts/protocol/script/Deploy.s.sol` | Create per-collateral deployment scripts |
| `docs/protocol/Technical_Specification.md` | Document 1:1 deployment architecture |
| `contracts/issuer/src/AuctionController.sol` | Accept protocol address as constructor param |

---

## Open Questions for Clarification

1. **Liquidity priority:** Is deep single-pool liquidity essential, or is risk isolation more valuable?
2. **Issuer integration:** Should issuers choose which collateral types to support, or offer all?
3. **tBTC inclusion:** Is tBTC's higher decentralization worth the lower adoption/liquidity tradeoff?
4. **Cross-collateral matching:** Is there a product case for early wBTC forfeiture funding cbBTC holders?

---

## Conclusion

The whitelist approach (Option A) creates hidden risk correlation through fungible vBTC. The 1:1 deployment approach (Option B) provides clean risk isolation at the cost of liquidity fragmentation.

**For a protocol emphasizing trust-minimization and clear value propositions, Option B aligns better with first principles.** Users selecting tBTC collateral are expressing preference for decentralization; they should not be exposed to cbBTC's centralized custody risk through the match pool.

---

## Research Sources

- [Cointelegraph: Wrapped Bitcoin in DeFi](https://cointelegraph.com/research/wrapped-bitcoin-in-defi-evaluating-wbtc-cbbtc-and-tbtc)
- [OAK Research: Wrapped Bitcoin Overview](https://oakresearch.io/en/analyses/fundamentals/wrapped-bitcoin-btc-overview-wrapping-alternatives)
- [LX Research: Analyzing tBTC](https://www.lxresearch.co/analyzing-tbtc-against-wbtc-and-cbbtc/)
- [Threshold Network: tBTC v2 Documentation](https://docs.threshold.network/applications/tbtc-v2)
- [Coinbase: cbBTC](https://www.coinbase.com/cbbtc)

---

*Research completed: 2025-12-28*
