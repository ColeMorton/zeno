# BTCNFT Derivatives DAO Specification

## Overview

The Derivatives DAO governs vestedBTC financial derivatives without collecting fees or managing a treasury. Governance transitions from founder control to community control over a 1129-day period aligned with the protocol's vesting mechanics.

---

## Governance Model

### Voting Power

Voting power equals a wallet's total BTC exposure across the protocol:

| Source | Calculation |
|--------|-------------|
| vestedBTC balance | `btcToken.balanceOf(voter)` |
| Unsplit Vault collateral | Sum of `collateralAmount` for vaults where `btcTokenAmount == 0` |
| Derivative positions | Via `VotingPowerSourceRegistry` adapters |

```
organicPower = vBTC + unsplitVaultCollateral + sourceRegistry.getAggregatedPower(voter)
```

**Adapter Pattern**: Derivative contracts (yvBTC, Curve LP, etc.) are not hardcoded. Each has an adapter implementing `IVotingPowerSource`. The `VotingPowerSourceRegistry` whitelists these adapters, providing separation of concerns.

### Founder Transition

The founder receives **two sources of voting power**:

1. **Transitional Power**: Decays linearly from 100% to 0% of total protocol BTC over 1129 days
2. **Organic Power**: Standard voting power based on founder's actual holdings (permanent)

```
transitionalPower = totalProtocolBTC × (1 - daysSinceLaunch / 1129)
founderTotalPower = transitionalPower + organicPower
```

| Day | Transitional Multiplier | Example (1000 BTC protocol) |
|-----|------------------------|------------------------------|
| 0 | 100% | 1000 BTC bonus + holdings |
| 282 | 75% | 750 BTC bonus + holdings |
| 564 | 50% | 500 BTC bonus + holdings |
| 847 | 25% | 250 BTC bonus + holdings |
| 1129 | 0% | 0 bonus + holdings only |

**No Veto**: The founder votes with additive power. No special veto mechanism exists.

---

## Scope of Governance

### Governed Functions

| Function | Target | Constraints |
|----------|--------|-------------|
| Adjust performance fee | yvBTC | Within 5-20% bounds |
| Adjust interest rate base | Lending Protocol | Within protocol-defined caps |
| Emergency pause | Registered derivatives | Temporary (auto-unpause after timeout) |
| Whitelist derivative | ProductRegistry | Requires audit attestation |

### Non-Governed (Immutable)

| Function | Reason |
|----------|--------|
| Fee recipient addresses | Set at deployment |
| Protocol layer (VaultNFT, BtcToken) | Immutable core |
| Withdrawal rate (1%) | Protocol constant |
| Vesting period (1129 days) | Protocol constant |
| Strategy contracts | Deploy new contract instead |

---

## Contract Architecture

### Layer Position

```
┌─────────────────────────────────────────────────────────────┐
│                         LAYER 2                              │
│           (All entities building on the protocol)            │
│                                                              │
│  ┌─────────────────────────┐  ┌───────────────────────────┐ │
│  │   DERIVATIVES DAO       │  │    EXTERNAL ISSUERS       │ │
│  │                         │  │                           │ │
│  │  DerivativesDAO.sol     │  │  Brands, Artists, DAOs    │ │
│  │  ├─ VotingPowerCalc     │  │  issuing TreasureNFTs     │ │
│  │  ├─ SourceRegistry      │  │                           │ │
│  │  └─ ProductRegistry     │  │  Uses: Issuer Templates   │ │
│  │                         │  │  (TreasureNFT, EntryBadge, │ │
│  │  Governs:               │  │   AuctionController)      │ │
│  │  ┌─────┐ ┌─────┐ ┌────┐ │  │                           │ │
│  │  │yvBTC│ │Lend │ │Var │ │  └───────────────────────────┘ │
│  │  │Vault│ │ ing │ │Swap│ │                                │
│  │  └─────┘ └─────┘ └────┘ │                                │
│  └─────────────────────────┘                                │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│                  LAYER 1: PROTOCOL (IMMUTABLE)               │
│                  (VaultNFT, BtcToken/vestedBTC)              │
└─────────────────────────────────────────────────────────────┘
```

**Key Insight**: The Derivatives DAO and External Issuers are parallel Layer 2 entities. Both sit directly on the immutable protocol. Neither depends on the other.

### Contracts

| Contract | Purpose |
|----------|---------|
| `VotingPowerCalculator.sol` | Aggregates power from protocol + registered sources |
| `VotingPowerSourceRegistry.sol` | Whitelists adapter contracts for derivative positions |
| `DerivativesDAO.sol` | Proposal creation, voting, execution |
| `ProductRegistry.sol` | Derivative whitelist and parameter bounds |

---

## Proposal Lifecycle

### Parameters

| Parameter | Value |
|-----------|-------|
| Voting Period | 7 days |
| Execution Delay | 2 days |
| Quorum | 4% of total voting power |
| Passing Threshold | Simple majority (forVotes > againstVotes) |

### Flow

```
1. propose(target, callData, descriptionHash)
   └─ Verify target is registered in ProductRegistry
   └─ Record proposal with voting period

2. vote(proposalId, support)
   └─ Check voting period active
   └─ Get voter's power from VotingPowerCalculator
   └─ Add to forVotes or againstVotes

3. execute(proposalId)
   └─ After votingPeriod + executionDelay
   └─ Verify quorum reached
   └─ Verify forVotes > againstVotes
   └─ Call target with callData
```

---

## Product Registry

Derivative products must be registered before the DAO can govern them.

### Registration Parameters

| Field | Description |
|-------|-------------|
| `minFeeBps` | Minimum fee the DAO can set (e.g., 500 = 5%) |
| `maxFeeBps` | Maximum fee the DAO can set (e.g., 2000 = 20%) |
| `pausable` | Whether DAO can pause this product |

### Validation

When a proposal targets a fee change, the registry validates bounds:

```solidity
function validateFeeChange(address product, uint256 newFeeBps) external view {
    ParameterBounds memory b = bounds[product];
    if (newFeeBps < b.minFeeBps || newFeeBps > b.maxFeeBps) {
        revert FeeOutOfBounds();
    }
}
```

---

## Security Considerations

### Attack Mitigations

| Attack Vector | Mitigation |
|---------------|------------|
| Flash loan voting | Snapshot voting power at `block.number - 1` |
| Whale takeover | Founder transitional power counterbalances early |
| Proposal spam | Minimum voting power requirement to propose |
| Malicious parameters | Bounded parameters in ProductRegistry |
| Permanent pause | Auto-unpause timeout |

### Design Constraints

- **No Treasury**: DAO cannot accumulate or spend funds
- **Bounded Parameters**: All adjustable values have min/max caps
- **Registered Targets Only**: DAO can only call whitelisted contracts
- **No Upgrades**: DAO contracts are immutable post-deployment

---

## Voting Power Source Registry

The `VotingPowerSourceRegistry` manages which derivative contracts contribute to voting power.

### IVotingPowerSource Interface

Each derivative needs an adapter implementing this interface:

```solidity
interface IVotingPowerSource {
    /// @notice Convert a holder's position to BTC-equivalent voting power
    /// @param holder Address to check
    /// @return btcEquivalent The BTC-equivalent value of their position
    function getVotingPower(address holder) external view returns (uint256 btcEquivalent);
}
```

### Example Adapters

**yvBTC Adapter**:
```solidity
contract YvBTCVotingAdapter is IVotingPowerSource {
    IERC4626 public immutable yvBTC;

    function getVotingPower(address holder) external view returns (uint256) {
        uint256 shares = yvBTC.balanceOf(holder);
        if (shares == 0) return 0;
        return yvBTC.convertToAssets(shares);
    }
}
```

**Curve LP Adapter**:
```solidity
contract CurveLPVotingAdapter is IVotingPowerSource {
    ICurvePool public immutable pool;
    IERC20 public immutable lpToken;
    int128 public immutable vbtcIndex;

    function getVotingPower(address holder) external view returns (uint256) {
        uint256 lpBalance = lpToken.balanceOf(holder);
        if (lpBalance == 0) return 0;
        return pool.calc_withdraw_one_coin(lpBalance, vbtcIndex);
    }
}
```

### Registration

New derivatives can contribute to voting power by:
1. Deploying an adapter implementing `IVotingPowerSource`
2. DAO proposal to register the adapter in `VotingPowerSourceRegistry`

---

## Integration Requirements

### IGovernable Interface

Derivative contracts governed by the DAO must implement:

```solidity
interface IGovernable {
    function setPerformanceFee(uint256 feeBps) external;
    function pause() external;
    function unpause() external;
    function dao() external view returns (address);

    modifier onlyDAO() {
        if (msg.sender != dao()) revert OnlyDAO();
        _;
    }
}
```

### IVaultNFT Requirements

VotingPowerCalculator requires:

```solidity
interface IVaultNFT {
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
    function collateralAmount(uint256 tokenId) external view returns (uint256);
    function btcTokenAmount(uint256 tokenId) external view returns (uint256);
    function totalActiveCollateral() external view returns (uint256);
}
```

---

## Glossary

| Term | Definition |
|------|------------|
| **Organic Power** | Voting power from actual BTC exposure holdings |
| **Transitional Power** | Founder's decaying bonus power over 1129 days |
| **Unsplit Vault** | VaultNFT where `mintBtcToken()` has not been called |
| **Parameter Bounds** | Min/max limits on adjustable derivative parameters |
| **ProductRegistry** | Whitelist of derivative contracts the DAO can govern |
| **VotingPowerSourceRegistry** | Whitelist of adapter contracts contributing voting power |
| **IVotingPowerSource** | Interface for converting derivative positions to BTC-equivalent |
| **Voting Adapter** | Contract that implements `IVotingPowerSource` for a specific derivative |

---

## Related Documents

- [vestedBTC Derivatives Suite](../defi/vestedBTC_Derivatives_Suite.md)
- [Native Volatility Farming Architecture](../research/Native_Volatility_Farming_Architecture.md)
- [Protocol Technical Specification](../protocol/Technical_Specification.md)
