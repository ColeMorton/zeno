# BTCNFT Protocol Research

> **Version:** 1.5
> **Status:** Draft
> **Last Updated:** 2025-12-12

---

## Executive Summary

BTCNFT Protocol provides perpetual withdrawals through percentage-based collateral access, designed to maintain USD-denominated value stability based on historical Bitcoin performance.

**Key Mechanism:**
1. Vault your Treasure NFT + BTC → Receive Vault NFT (ERC-998)
2. 1093-day vesting period (no withdrawals)
3. Post-vesting: Withdraw X% of remaining BTC per 30-day period
4. Collateral never depletes (percentage-based)

**Core Innovation:** btcToken (ERC-20) enables separation of collateral claim from withdrawal rights, creating tradeable principal-only positions branded as **vBTC** for Conservative-tier tokens.

---

## Documentation

### Protocol Layer (Developer-focused)

| Document | Audience | Description |
|----------|----------|-------------|
| [Product Specification](./docs/protocol/Product_Specification.md) | Business, Investors | What it is, withdrawal tiers, vBTC branding |
| [Technical Specification](./docs/protocol/Technical_Specification.md) | Developers, Auditors | Token lifecycle, btcToken mechanics, contract parameters |
| [Quantitative Validation](./docs/protocol/Quantitative_Validation.md) | Researchers, Risk | Historical data analysis, stability constraints |
| [Collateral Matching](./docs/protocol/Collateral_Matching.md) | Tokenomics, Incentives | Forfeited BTC → match pool for vested holder rewards |

### Issuer Layer (Organization-focused)

| Document | Audience | Description |
|----------|----------|-------------|
| [DAO Design](./docs/issuer/DAO_Design.md) | Protocol, Governance | POL DAO, achievements, campaigns, gamification |
| [E2E Competitive Flow](./docs/issuer/E2E_Competitive_Flow.md) | Strategy, DeFi | Capital flows, user journeys, Olympus-style bonding |
| [Market Analysis](./docs/issuer/Market_Analysis.md) | Business Development | Competitive positioning vs STRC/SATA |
| [Holder Guide](./docs/issuer/Holder_Guide.md) | End Users | User-facing documentation |

---

## Quick Reference

### Withdrawal Tiers

| Tier | Monthly | Annual | Historical Yearly Stability |
|------|---------|--------|----------------------------|
| Conservative | 0.875% | 10.5% | **100%** (2017-2025 data) |
| Balanced | 1.14% | 14.6% | **100%** (2017-2025 data) |
| Aggressive | 1.59% | 20.8% | 74% (2017-2025 data) |

> **Note:** vBTC is BTC-denominated. "Historical stability" refers to periods where USD value was maintained. Past performance does not guarantee future results.

### Token Standards

| Component | Standard |
|-----------|----------|
| Vault NFT | ERC-998 (Composable) |
| Treasure NFT | ERC-721 |
| BTC Collateral | ERC-20 (WBTC/cbBTC) |
| btcToken | ERC-20 (Fungible) |

### Historical Performance (1093-Day MA)

| Metric | Value |
|--------|-------|
| Mean Return | 313.07% |
| Min Return | 77.78% |
| Data Points | 2,930 days |
