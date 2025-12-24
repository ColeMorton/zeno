# BTCNFT Protocol

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Build-F7931A?logo=ethereum)](https://book.getfoundry.sh/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript)](https://www.typescriptlang.org/)
[![Node.js](https://img.shields.io/badge/Node.js-≥18-339933?logo=node.js)](https://nodejs.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

> **Version:** 1.0

Immutable, permissionless smart contracts for perpetual BTC withdrawals.

---

## What is BTCNFT Protocol?

BTCNFT Protocol enables perpetual withdrawals through percentage-based collateral access. Vault your Treasure NFT + BTC collateral to receive a composable Vault NFT. After a 1129-day vesting period, withdraw a percentage of remaining BTC every 30 days—collateral never depletes.

**Core innovation:** vestedBTC (vBTC) ERC-20 tokens enable separation of collateral claims from the Vault NFT, creating tradeable principal positions.

---

## Key Features

- **ERC-998 Composable Vaults** — Hold Treasure NFT + BTC collateral in a single transferable NFT
- **Perpetual Withdrawals** — Percentage-based withdrawals ensure collateral never depletes
- **vestedBTC (vBTC)** — Fungible ERC-20 tokens representing separated collateral claims
- **Withdrawal Delegation** — Grant third parties permission to withdraw on your behalf
- **Achievement System** — ERC-5192 soulbound badges for protocol participation
- **Auction Support** — Dutch and English auction mechanics for vault distribution

---

## Quick Start

```bash
# Protocol contracts
cd contracts/protocol && forge build && forge test

# Issuer contracts
cd contracts/issuer && forge build && forge test

# TypeScript SDK
cd packages/vault-analytics && npm install && npm run build

# CLI (local network)
./cli/btcnft setup && ./cli/btcnft status 1
```

---

## Repository Structure

```
├── contracts/
│   ├── protocol/           # Immutable core (VaultNFT, BtcToken)
│   └── issuer/             # Templates (TreasureNFT, AchievementNFT, AuctionController)
├── packages/
│   └── vault-analytics/    # TypeScript SDK (@btcnft/vault-analytics)
├── cli/                    # Bash CLI tools (20+ commands)
└── docs/                   # Documentation layers
    ├── protocol/           # Developer/auditor specs
    ├── issuer/             # Integration guides
    └── sdk/                # SDK documentation
```

---

## Protocol Parameters

| Parameter | Value |
|-----------|-------|
| Vesting Period | 1129 days (~3.09 years) |
| Withdrawal Rate | 0.875%/month (10.5%/year) |
| Withdrawal Period | 30 days |
| Dormancy Threshold | 1129 days |
| BTC Decimals | 8 |

All parameters are immutable—encoded in bytecode with no admin functions.

---

## Token Standards

| Component | Standard | Purpose |
|-----------|----------|---------|
| Vault NFT | ERC-998 | Composable vault holding Treasure + collateral |
| Treasure NFT | ERC-721 | Issuer-branded collectible wrapped in vault |
| vestedBTC | ERC-20 | Fungible collateral claim token |
| Achievement NFT | ERC-5192 | Soulbound participation attestation |

---

## Documentation

| Audience | Entry Point |
|----------|-------------|
| **Developers** | [Technical Specification](./docs/protocol/Technical_Specification.md) |
| **Auditors** | [Technical Specification](./docs/protocol/Technical_Specification.md) |
| **Issuers** | [Integration Guide](./docs/issuer/Integration_Guide.md) |
| **End Users** | [Holder Experience](./docs/issuer/Holder_Experience.md) |

See [docs/README.md](./docs/README.md) for complete navigation and [docs/GLOSSARY.md](./docs/GLOSSARY.md) for terminology.

---

## Contributing

Report issues at [GitHub Issues](https://github.com/anthropics/btcnft-protocol/issues).

---

## License

MIT
