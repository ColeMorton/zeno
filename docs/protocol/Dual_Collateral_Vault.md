# Dual-Collateral Vault Specification

> **Version:** 1.0
> **Status:** Canonical
> **Last Updated:** 2025-12-28
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Integration Guide](../issuer/Integration_Guide.md)

---

## Overview

The Dual-Collateral Vault is the protocol's liquidity expansion mechanism. It combines ground-truth BTC backing with time-locked LP provision to create a sustainable liquidity flywheel.

```
Dual-Collateral Vault:
├─ Collateral: 80% WBTC + 20% vBTC/WBTC LP
├─ LP Treatment: Bond (full release at maturity)
├─ Launch: Post-vesting (Day 1129+)
└─ Role: Liquidity expansion, ground truth growth
```

---

## Design Principles

### 1. Ground Truth Backing

Primary collateral is WBTC (80%), providing direct BTC exposure without recursive claims.

```
WBTC → BTC (1 hop)

vs. deprecated approach:
vBTC → Vault → WBTC → BTC (3 hops, recursive)
```

### 2. LP-as-Bond

LP tokens are treated as a **time-locked liquidity commitment**, not depleting collateral:
- LP releases 100% at maturity
- Enables flywheel: users can re-provide LP after release
- Separates "backing" (BTC) from "liquidity commitment" (LP)

### 3. Separation of Concerns

| Component | Purpose |
|-----------|---------|
| 80% WBTC | Value backing (perpetual withdrawal) |
| 20% LP | Liquidity commitment (maturity release) |

---

## Specification

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Primary Collateral | WBTC (80%) | Ground truth, no recursion |
| LP Collateral | vBTC/WBTC LP (20%) | Stable pair, minimal IL |
| LP Treatment | Full release at maturity | Enables flywheel |
| Maturity | 1129 days | Matches BTC vesting |
| LP Beneficiary | Current vault owner | Full composability |

### Effective Exposure

```
Direct WBTC:     80%
vBTC from LP:    10% (half of 20% LP)
WBTC from LP:    10% (half of 20% LP)
─────────────────────
Total WBTC exposure: 90%
Total vBTC exposure: 10%
```

---

## Withdrawal Mechanics

### Timeline

```
Day 0:      Vault created
            80% WBTC deposited to protocol VaultNFT
            20% LP deposited to LPEscrow

Day 0-1129: Vesting period
            WBTC: Locked in protocol vault
            LP: Locked in escrow, fees accruing

Day 1129:   Maturity
            WBTC: Perpetual 1%/month withdrawals begin
            LP: Releases 100% to current vault owner

Day 1129+:  Post-maturity
            WBTC: Continues asymptotic depletion (Zeno)
            LP: Released (vault continues on WBTC only)
```

### Collateral Evolution

```
Month 0:   80% WBTC │ 20% LP (locked)
           ████████████████│████

Month 37:  80% WBTC │ 20% LP releases
           ████████████████│→ to owner

Month 37+: 80% WBTC │ 0% LP
           ████████████████│ (standard vault)

Month 120: ~44% WBTC │ 0% LP
           ████████│ (perpetual via Zeno)
```

---

## Flywheel Effect

The LP-as-bond design creates a self-reinforcing liquidity cycle:

```
1. New vault creation requires 20% LP provision
         ↓
2. LP locked 1129 days → TVL increases in vBTC/WBTC pool
         ↓
3. Deeper liquidity → tighter spreads, better price discovery
         ↓
4. Better price discovery → vBTC trades closer to NAV
         ↓
5. vBTC stability → more confidence in vault creation
         ↓
6. At maturity: LP releases → user can re-provide
         ↓
7. New vaults created with re-provided LP → repeat
```

---

## Implementation Architecture

### Contract Structure

```
contracts/issuer/src/
├── DualCollateralController.sol    # Orchestrates minting
│   ├── mint(btcAmount, lpAmount, lpToken)
│   ├── withdrawLP(vaultId)
│   └── validateRatio(...)
│
├── LPEscrow.sol                    # LP custody
│   ├── createPosition(vaultId, lpToken, amount, maturity)
│   ├── release(positionId)
│   └── getBeneficiary(positionId)
│
└── interfaces/
    ├── IDualCollateralController.sol
    └── ILPEscrow.sol
```

### Minting Flow

```
User provides: 0.8 WBTC + 0.2 BTC value in vBTC/WBTC LP
                    │
                    ▼
         ┌─────────────────────────┐
         │ DualCollateralController│
         │ 1. Validate 80:20 ratio │
         │ 2. Transfer assets      │
         └─────────────────────────┘
                    │
       ┌────────────┴────────────┐
       ▼                         ▼
┌─────────────┐           ┌─────────────┐
│  VaultNFT   │           │  LPEscrow   │
│  (Protocol) │           │  (Issuer)   │
│  0.8 WBTC   │           │  0.2 LP     │
│  + Treasure │           │  maturity:  │
└─────────────┘           │  1129 days  │
       │                  └─────────────┘
       ▼
User receives: VaultNFT (owns Treasure + WBTC collateral)
               LP claim (releases at maturity)
```

### LP Beneficiary Tracking

LP beneficiary follows current vault owner:

```solidity
function release(uint256 positionId) external {
    EscrowPosition storage pos = positions[positionId];
    require(block.timestamp >= pos.maturityTimestamp, "NotMatured");
    require(!pos.released, "AlreadyReleased");

    // Current vault owner, not original depositor
    address beneficiary = protocol.ownerOf(pos.linkedVaultId);

    pos.released = true;
    IERC20(pos.lpToken).safeTransfer(beneficiary, pos.lpAmount);
}
```

This enables full vault composability—vault sales transfer LP claim rights.

---

## Risk Analysis

### Robustness to vBTC Depeg

| Scenario | Vault Impact |
|----------|-------------|
| vBTC at 0.9x WBTC (10% discount) | 1% loss (10% vBTC exposure) |
| vBTC at 0.8x WBTC (20% discount) | 2% loss |
| vBTC at 0.5x WBTC (50% discount) | 5% loss |

90% WBTC exposure provides strong downside protection.

### LP Impermanent Loss

vBTC/WBTC is a correlated pair—IL is minimal:
- Both assets track BTC value
- Curve stable-like pools further minimize IL
- IL only materializes if vBTC significantly depegs

### Maturity Liquidity Risk

If many vaults mature simultaneously:
- Mass LP withdrawal could thin pool temporarily
- Mitigated by natural staggering of vault creation dates
- Rational actors re-provide if yields remain attractive

---

## Comparison: Vault Types

| Property | BTC-Vault | Dual-Collateral Vault |
|----------|-----------|----------------------|
| Primary Collateral | 100% WBTC | 80% WBTC |
| LP Requirement | None | 20% vBTC/WBTC LP |
| Available | Genesis (Day 0) | Post-vesting (Day 1129+) |
| Liquidity Contribution | None | Contributes to vBTC/WBTC pool |
| Withdrawal | 1%/month on WBTC | 1%/month on WBTC; 100% LP at maturity |

---

## Design Rationale

### Why 80:20?

| Ratio | Ground Truth | Liquidity | Accessibility | Assessment |
|-------|-------------|-----------|---------------|------------|
| 90:10 | Maximum | Minimal | Easy | Insufficient liquidity |
| **80:20** | **Strong** | **Meaningful** | **Moderate** | **Optimal balance** |
| 70:30 | Adequate | High | Difficult | Barrier too high |

### Why WBTC Primary (Not vBTC)?

1. **No Recursion**: WBTC is direct BTC exposure, vBTC is claim-on-claim
2. **Protocol Growth**: Each vault adds new BTC collateral
3. **Robustness**: 90% ground truth exposure vs 20% with vBTC primary
4. **vBTC Demand**: Better achieved through external DeFi (Aave, Curve, lending)

### Why LP-as-Bond (Not LP-as-Collateral)?

1. **Flywheel**: LP releases enable re-provision cycle
2. **Clean Exit**: 100% release vs perpetual depletion
3. **Separation**: Distinguishes backing from liquidity commitment
4. **Sustainability**: LP can return to pool, not permanently extracted
