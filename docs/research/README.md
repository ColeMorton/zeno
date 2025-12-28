# Research Documentation

> **Status:** Reference Archive
> **Last Updated:** 2025-12-28

Research documents that informed protocol design decisions. These are reference materials, not specifications.

---

## Navigation

### Foundational Research

| Document | Purpose | Status |
|----------|---------|--------|
| [Vision and Mission](./Vision_and_Mission.md) | Protocol philosophy and goals | Final |
| [Vesting Period](./Vesting_Period.md) | 1129-day vesting period rationale | Final |
| [Withdrawal Rate Stability](./Withdrawal_Rate_Stability.md) | 12% annual rate analysis | Final |

### Parameter Optimization

| Document | Purpose | Status |
|----------|---------|--------|
| [Quantitative Validation](./Quantitative_Validation.md) | Historical BTC data (2017-2025) supporting design constraints | Final |
| [Optimal Vesting Window](./Optimal_Vesting_Window.md) | Vesting period sensitivity analysis | Research |
| [Optimal Withdrawal Rate](./Optimal_Withdrawal_Rate.md) | USD stability analysis | Research |
| [Return Regime Analysis](./Return_Regime_Analysis.md) | BTC appreciation sustainability | Research |

### Deployment Feasibility

| Document | Purpose | Status |
|----------|---------|--------|
| [Protocol Lifespan Assessment](./Protocol_Lifespan_Assessment.md) | 20-year Ethereum viability | Research |
| [L2 Deployment Viability](./L2_Deployment_Viability.md) | Base, Arbitrum, Optimism analysis | Research |
| [Bitcoin Deployment Feasibility](./Bitcoin_Deployment_Feasibility.md) | Native Bitcoin deployment options | Research |
| [RGB Viability Assessment](./RGB_Viability_Assessment.md) | RGB protocol evaluation | Research |

### Architecture

| Document | Purpose | Status |
|----------|---------|--------|
| [Collateral Architecture](./Collateral_Architecture.md) | Multi-collateral vs single deployment | Research |

### Market Analysis

| Document | Purpose | Status |
|----------|---------|--------|
| [Competitive Positioning](./Competitive_Positioning.md) | Market research, target segments, competitive matrix | Final |

### Visual Assets

| Document | Purpose | Status |
|----------|---------|--------|
| [SVG Layer Isolation Plan](./SVG_Layer_Isolation_Plan.md) | Diamond Hands medallion layer extraction | Technical |

### Archived

| Document | Purpose | Status |
|----------|---------|--------|
| [Withdrawal Tier](./Withdrawal_Tier.md) | Superseded by fixed 12% rate | Archived |

---

## Relationship to Specifications

Research documents explore options and trade-offs. Final decisions are reflected in:

- **Protocol Specifications:** [../protocol/](../protocol/)
- **Issuer Integration:** [../issuer/](../issuer/)

Research conclusions that became protocol parameters:
- Vesting period: 1129 days
- Withdrawal rate: 12% annually (1.0% monthly)
- Single withdrawal tier (no tiered rates)

---

## Navigation

← [Documentation Home](../README.md)
