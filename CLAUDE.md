# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains research documentation for BTCNFT Protocol, an immutable permissionless smart contract protocol that provides perpetual withdrawals through percentage-based collateral access. This is a documentation-only repository with no code implementation.

## Repository Structure

```
├── README.md                                # Executive summary and quick reference
└── docs/
    ├── protocol/                            # Protocol Layer (Developer-focused)
    │   ├── Technical_Specification.md       # Contract mechanics
    │   ├── Product_Specification.md         # Protocol product definition
    │   ├── Quantitative_Validation.md       # Historical data analysis
    │   └── Collateral_Matching.md           # Protocol mechanism
    │
    └── issuer/                              # Issuer Layer (Organization-focused)
        ├── DAO_Design.md                    # Governance and gamification
        ├── Holder_Guide.md                  # End-user documentation
        ├── Market_Analysis.md               # Competitive positioning
        └── E2E_Competitive_Flow.md          # Capital flows and user journeys
```

## Layer Architecture

- **Protocol Layer** (`docs/protocol/`): BTCNFT Protocol smart contract documentation for developers, auditors, and technical integrators
- **Issuer Layer** (`docs/issuer/`): Documentation for NFT issuers (organizations, brands, businesses) building on the protocol

## Key Concepts

- **Vault NFT (ERC-998)**: Composable NFT holding Treasure NFT + BTC collateral
- **btcToken (ERC-20)**: Fungible token representing collateral claims, branded as **vBTC**
- **1093-day vesting**: Lock period before withdrawals are enabled
- **Withdrawal tiers**: Conservative (10.5%), Balanced (14.6%), Aggressive (20.8%) annual rates
