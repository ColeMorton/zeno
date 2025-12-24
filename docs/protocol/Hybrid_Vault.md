# Hybrid Vault Specification

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-17
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Integration Guide](../issuer/Integration_Guide.md)

---

## Table of Contents

1. [Protocol Architecture](#1-protocol-architecture)
2. [Hybrid Vault Design](#2-hybrid-vault-design)
3. [Withdrawal Mechanics](#3-withdrawal-mechanics)
4. [vBTC Supply Dynamics](#4-vbtc-supply-dynamics)
5. [Benefits](#5-benefits)

---

## 1. Protocol Architecture

### Vault Types

The BTCNFT Protocol supports two vault types:

```
BTCNFT Protocol:

BTCNFTProtocol (Core)
├─ Collateral: WBTC, cbBTC
├─ Vested Token: vestedBTC (vBTC)
├─ Launch: Genesis (Day 0)
└─ Role: Bootstrap, simple onramp, ground truth

HybridNFTProtocol (Extension)
├─ Collateral: 60% vBTC + 40% LP
├─ Vested Token: vestedHybrid (vHybrid)
├─ Withdrawal: Priority (vBTC first, then LP)
├─ Launch: Post-vesting (Day 1129+)
└─ Role: Balanced yield, sustainable LP commitment
```

### Comparison

| Aspect | BTC-Vault | Hybrid-Vault |
|--------|-----------|--------------|
| **Collateral** | 100% BTC | 60% vBTC + 40% LP |
| **Pool risk** | 0% | 40% |
| **IL exposure** | 0% | 40% |
| **Bootstrap** | Self-sufficient | Requires BTC-Vault |
| **Ground truth** | BTC | vBTC (60%) |
| **Launch timing** | Genesis (Day 0) | Post-vesting (Day 1129+) |

---

## 2. Hybrid Vault Design

### Timing Constraint

**Hybrid-Vaults cannot launch at genesis.**

```
Timeline:
Day 0:        BTC-Vaults launch (genesis)
              Users deposit BTC → Vault NFT
              NO vBTC exists yet

Day 1129:     First BTC-Vaults vest
              mintVestedBTC() becomes callable
              vBTC enters circulation

Day 1129+:    vBTC/WBTC LP pools can form
              Hybrid-Vaults become possible
              Self-coordination by issuers
```

**Implication:** Hybrid-Vaults are a **Phase 2** product, launched organically after vBTC supply exists.

### Collateral Composition

```
Collateral Composition:
├─ 60% vestedBTC (vBTC)
└─ 40% LP tokens (vBTC/WBTC LP)
```

### Effective BTC Exposure

```
60% vBTC + 40% LP (which is 50% vBTC + 50% WBTC)
= 60% vBTC + 20% vBTC exposure + 20% WBTC
= 80% vBTC-equivalent + 20% WBTC
```

### 60/40 Ratio Rationale

| Property | Value |
|----------|-------|
| Direct vBTC requirement | 60% |
| Pool exposure | 40% |
| Total vBTC exposure | 80% (60% direct + 20% in LP) |
| vBTC scarcity sustainability | Moderate |
| IOL commitment | 40% |

**Rationale:** Balances safety with accessibility. Lower vBTC requirement accounts for deflationary vBTC supply while maintaining meaningful ground truth backing.

---

## 3. Withdrawal Mechanics

### Priority Withdrawal: vBTC First, Then LP

```solidity
function withdraw(uint256 tokenId) external {
    require(msg.sender == ownerOf(tokenId));
    require(isVested(tokenId));
    require(block.timestamp >= lastWithdrawal[tokenId] + WITHDRAWAL_PERIOD);

    uint256 totalValue = vBTCCollateral[tokenId] + lpCollateral[tokenId];
    uint256 withdrawAmount = totalValue * WITHDRAWAL_RATE / 100000;

    uint256 vBTCWithdrawal;
    uint256 lpWithdrawal;

    // Priority 1: Withdraw from vBTC first
    if (vBTCCollateral[tokenId] >= withdrawAmount) {
        vBTCWithdrawal = withdrawAmount;
        lpWithdrawal = 0;
    } else {
        // Priority 2: Exhaust vBTC, then draw from LP
        vBTCWithdrawal = vBTCCollateral[tokenId];
        lpWithdrawal = withdrawAmount - vBTCWithdrawal;
    }

    vBTCCollateral[tokenId] -= vBTCWithdrawal;
    lpCollateral[tokenId] -= lpWithdrawal;

    if (vBTCWithdrawal > 0) vBTC.transfer(msg.sender, vBTCWithdrawal);
    if (lpWithdrawal > 0) lpToken.transfer(msg.sender, lpWithdrawal);

    lastWithdrawal[tokenId] = block.timestamp;
}
```

### Withdrawal Phases

```
Phase 1: vBTC Exhaustion (~69 months)
├─ Monthly withdrawal: 0.875% of total collateral
├─ Source: 100% from vBTC portion
├─ LP portion: Untouched (continues earning fees)
└─ Ends when: vBTC depleted

Phase 2: LP Withdrawal (perpetual)
├─ Monthly withdrawal: 0.875% of remaining LP
├─ Source: 100% from LP portion
├─ User receives: LP tokens (can unwrap to vBTC + WBTC)
└─ Continues: Perpetually (Zeno's paradox)
```

### Collateral Ratio Evolution

```
Initial:     60% vBTC │ 40% LP
             ████████████████│██████████

Month 35:    ~30% vBTC │ 40% LP (unchanged)
             ████████│██████████

Month 69:    0% vBTC │ 40% LP
             │██████████ (vBTC exhausted)

Month 120:   0% vBTC │ ~24% LP
             │██████ (LP being withdrawn)
```

---

## 4. vBTC Supply Dynamics

### Why the Ratio Matters Long-Term

vBTC is **deflationary**. Understanding supply dynamics is critical for ratio selection.

### Supply Sources (Creation)

| Event | Mechanism | When |
|-------|-----------|------|
| `mintVestedBTC()` | Vault holder separation | After 1129-day vesting |

### Supply Sinks (Destruction)

| Event | Mechanism | Result |
|-------|-----------|--------|
| `returnVestedBTC()` | Recombination | Burns full vBTC amount |
| `claimDormantCollateral()` | Dormancy claim | Burns proportional vBTC |

### Deflationary Pressure Over Time

```
Year 3 (vBTC enters circulation):
├─ Initial minting wave
├─ Supply: Growing (many new separations)
└─ Hybrid-Vaults: Easy to collateralize

Year 5+:
├─ Recombinations begin (returnVestedBTC burns)
├─ Dormancy claims (claimDormantCollateral burns)
├─ Supply: Potentially shrinking
└─ Hybrid-Vaults: Harder to collateralize

Year 10+:
├─ Significant burn accumulation
├─ vBTC increasingly scarce
├─ Higher ratios become prohibitive
└─ Lower ratios more sustainable
```

### Ratio Selection Impact

| Ratio | vBTC Scarcity Impact |
|-------|---------------------|
| 75:25 | High barrier during scarcity |
| **60:40** | **Balanced - sustainable long-term** |
| 50:50 | Low barrier, but higher pool risk |

**60:40 selected** because it balances:
- Sufficient ground truth backing (60% direct vBTC)
- Meaningful IOL commitment (40% LP locked)
- Sustainable accessibility as vBTC becomes scarce

---

## 5. Benefits

### Priority Withdrawal Benefits

| Benefit | Description |
|---------|-------------|
| **Simpler user experience** | Single asset type per withdrawal (usually) |
| **LP fee accumulation** | LP untouched longer → more fees accrue |
| **Liquidity preservation** | LP stays in pool longer → deeper liquidity |
| **Gas efficiency** | Often only one transfer per withdrawal |
| **Predictable phases** | Clear transition point from vBTC to LP |

### User Options

| User Goal | Vault Type | Available |
|-----------|------------|-----------|
| Simple BTC exposure | BTC-Vault | Genesis (Day 0) |
| Balanced yield + LP | Hybrid-Vault | Post-vesting (Day 1129+) |
