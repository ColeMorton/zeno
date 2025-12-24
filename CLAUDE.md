# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BTCNFT Protocol is an immutable permissionless smart contract protocol that provides perpetual withdrawals through percentage-based collateral access. The repository contains both protocol-level smart contracts and issuer-level templates.

## Repository Structure

```
├── contracts/
│   ├── protocol/                           # Immutable core (single deployment)
│   │   ├── foundry.toml                    # Protocol workspace config
│   │   ├── src/
│   │   │   ├── VaultNFT.sol                # ERC-998 composable vault
│   │   │   ├── BtcToken.sol                # vestedBTC ERC-20
│   │   │   ├── interfaces/                 # Protocol interfaces
│   │   │   └── libraries/                  # Shared libraries
│   │   ├── test/                           # Protocol tests
│   │   └── script/                         # Deployment scripts
│   │
│   └── issuer/                             # Reusable templates (per-issuer deployment)
│       ├── foundry.toml                    # Issuer workspace config
│       ├── src/
│       │   ├── EntryBadge.sol              # ERC-5192 soulbound badge
│       │   ├── TreasureNFT.sol             # ERC-721 issuer NFT
│       │   ├── BadgeRedemptionController.sol  # Atomic redemption
│       │   └── interfaces/                 # Issuer interfaces
│       ├── test/                           # Issuer tests
│       └── script/                         # Deployment scripts
│
├── lib/                                    # Shared dependencies
│   ├── forge-std/
│   └── openzeppelin-contracts/
│
├── docs/
│   ├── protocol/                           # Protocol Layer (Developer-focused)
│   ├── issuer/                             # Issuer Layer (Organization-focused)
│   └── sdk/                                # SDK Documentation (Future)
│
├── packages/                               # TypeScript packages
│   └── vault-analytics/                    # Analytics library
│
└── cli/                                    # CLI tools
```

## Workspace Commands

```bash
# Protocol workspace
cd contracts/protocol && forge build && forge test

# Issuer workspace
cd contracts/issuer && forge build && forge test
```

## Layer Architecture

- **Protocol Layer** (`contracts/protocol/`): Immutable core contracts deployed once. VaultNFT, BtcToken, and supporting libraries.
- **Issuer Layer** (`contracts/issuer/`): Reusable contract templates for issuers. EntryBadge, TreasureNFT, BadgeRedemptionController.
- **Documentation** (`docs/`): Protocol and issuer integration documentation.

## Key Concepts

- **Vault NFT (ERC-998)**: Composable NFT holding Treasure NFT + BTC collateral
- **vestedBTC (vBTC)**: ERC-20 fungible token representing collateral claims
- **Treasure NFT (ERC-721)**: NFT wrapped within a Vault
- **1129-day vesting**: Lock period before withdrawals are enabled
- **Withdrawal rate**: 10.5% annually (0.875% monthly)
