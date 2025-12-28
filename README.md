# BTCNFT Protocol

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Build-F7931A?logo=ethereum)](https://book.getfoundry.sh/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript)](https://www.typescriptlang.org/)
[![Node.js](https://img.shields.io/badge/Node.js-≥18-339933?logo=node.js)](https://nodejs.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

> **Version:** 1.0

Fortify your NFTs with Bitcoin. Built to last generations.

---

## What is BTCNFT Protocol?

Fortify any NFT with Bitcoin collateral to create a Vault, a composable NFT designed to outlast its creator. After a 1129-day commitment period, withdraw 1% of your Bitcoin monthly, forever. The collateral never depletes.

**Core innovation:** vestedBTC (vBTC) tokens let you trade your collateral claim separately from the Vault itself.

---

## Why 1129 Days?

1129 days (~3 years) is the commitment that unlocks perpetual access. This duration comes from Bitcoin's historical data: the 1129-day moving average has shown **100% positive returns across all windows ever measured**. Time itself becomes the trust mechanism—no oracles, no governance, no intermediaries.

See [Vision & Mission](./docs/research/Vision_and_Mission.md) for the full analysis.

---

## Key Features

- **ERC-998 Composable Vaults** — Combine child/subject NFT + BTC collateral in a single transferable vault NFT
- **Perpetual Withdrawals** — Percentage-based withdrawals ensure collateral never depletes
- **vestedBTC (vBTC)** — Fungible ERC-20 tokens representing separated collateral claims
- **Withdrawal Delegation** — Grant third parties permission to withdraw on your behalf

---

## Design Principles

- **Zero Fees** — You own 100% of your collateral
- **Zero Leverage** — No liquidation risk
- **Self-Custody** — Your NFT, your vault
- **Immutable** — No admin keys, no upgrades

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
| Vesting Period and Dormancy Threshold | 1129 days (~3.09 years) |
| Withdrawal Rate | 1.0%/month (12%/year) |
| Withdrawal Period | 30 days |
| BTC Decimals | 8 |

All parameters are immutable—encoded in bytecode with no admin functions.

---

## Token Standards

| Component | Standard | Purpose |
|-----------|----------|---------|
| Vault NFT | ERC-998 | Composable vault holding Treasure + collateral |
| Child/Treasure NFT | ERC-721 | Any ERC-721/ERC-998 or dedicated issuer NFT wrapped in vault |
| vestedBTC | ERC-20 | Fungible collateral claim token |

---

## Documentation

| Audience | Entry Point |
|----------|-------------|
| **Overview** | [Vision & Mission](./docs/research/Vision_and_Mission.md) |
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
