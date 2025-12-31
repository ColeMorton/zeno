# Issuer Deployment Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Integration Guide](./Integration_Guide.md)
> - [Achievements Specification](./Achievements_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Environment Configuration](#3-environment-configuration)
4. [Deployment Commands](#4-deployment-commands)
5. [Deployment Output](#5-deployment-output)
6. [Post-Deployment Verification](#6-post-deployment-verification)
7. [Additional Minter Authorization](#7-additional-minter-authorization)
8. [AuctionController Deployment](#8-auctioncontroller-deployment)
9. [Common Issues](#9-common-issues)
10. [Next Steps](#10-next-steps)

---

## 1. Overview

The issuer deployment script deploys three contracts:

| Contract | Standard | Purpose |
|----------|----------|---------|
| **AchievementNFT** | ERC-5192 | Soulbound achievement attestations |
| **TreasureNFT** | ERC-721 | Issuer-branded NFTs stored in Vaults |
| **AchievementMinter** | - | Claim verification and minting logic |

All contracts are owned by the deployer address. The AchievementMinter is automatically authorized to mint on both NFT contracts.

**Not included:** AuctionController (optional, see [Section 8](#8-auctioncontroller-deployment)).

For conceptual details on issuer capabilities, see [Integration Guide](./Integration_Guide.md).

---

## 2. Prerequisites

### Foundry

Install Foundry if not already installed:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Protocol Addresses

Obtain these addresses from the protocol deployment:

| Address Type | Description |
|--------------|-------------|
| Collateral tokens | WBTC, cbBTC, tBTC contract addresses |
| VaultNFT contracts | Protocol VaultNFT address per collateral type |

### Deployer Account

- Private key with control over issuer contracts
- ETH balance sufficient for gas (deployment costs ~2-3M gas)

---

## 3. Environment Configuration

Create a `.env` file in `contracts/issuer/`:

```bash
# Achievement NFT Configuration
ACHIEVEMENT_NAME="Your Achievements"
ACHIEVEMENT_SYMBOL="ACH"
ACHIEVEMENT_BASE_URI="https://api.yourdomain.com/achievements/"

# Treasure NFT Configuration
TREASURE_NAME="Your Treasures"
TREASURE_SYMBOL="TRE"
TREASURE_BASE_URI="https://api.yourdomain.com/treasures/"

# Collateral Token Addresses
WBTC=0x...
CBBTC=0x...
TBTC=0x...

# Protocol VaultNFT Addresses (per collateral)
VAULT_WBTC=0x...
VAULT_CBBTC=0x...
VAULT_TBTC=0x...

# Deployer
PRIVATE_KEY=0x...

# Network
RPC_URL=https://...
```

### Variable Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `ACHIEVEMENT_NAME` | Yes | ERC-721 name for achievement collection |
| `ACHIEVEMENT_SYMBOL` | Yes | ERC-721 symbol (e.g., "ACH") |
| `ACHIEVEMENT_BASE_URI` | Yes | Metadata URI base (unused if on-chain SVG enabled) |
| `TREASURE_NAME` | Yes | ERC-721 name for Treasure collection |
| `TREASURE_SYMBOL` | Yes | ERC-721 symbol (e.g., "TRE") |
| `TREASURE_BASE_URI` | Yes | Metadata URI base for Treasure NFTs |
| `WBTC` | Yes | WBTC token contract address |
| `CBBTC` | Yes | cbBTC token contract address |
| `TBTC` | Yes | tBTC token contract address |
| `VAULT_WBTC` | Yes | VaultNFT deployment for WBTC collateral |
| `VAULT_CBBTC` | Yes | VaultNFT deployment for cbBTC collateral |
| `VAULT_TBTC` | Yes | VaultNFT deployment for tBTC collateral |
| `PRIVATE_KEY` | Yes | Deployer private key (with 0x prefix) |
| `RPC_URL` | Yes | Network RPC endpoint |

---

## 4. Deployment Commands

### Build

```bash
cd contracts/issuer
forge build
```

### Deploy

**Mainnet:**

```bash
source .env
forge script script/DeployIssuer.s.sol:DeployIssuer \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

**Testnet (Sepolia):**

```bash
source .env
forge script script/DeployIssuer.s.sol:DeployIssuer \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Base Mainnet:**

```bash
source .env.base
forge script script/DeployIssuer.s.sol:DeployIssuer \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url https://base.blockscout.com/api/
```

**Local (Anvil):**

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy
forge script script/DeployIssuer.s.sol:DeployIssuer \
  --rpc-url http://localhost:8545 \
  --broadcast
```

---

## 5. Deployment Output

The script logs deployed addresses:

```
Deploying issuer contracts with deployer: 0x...
AchievementNFT deployed at: 0x...
TreasureNFT deployed at: 0x...
AchievementMinter deployed at: 0x...
AchievementMinter authorized on AchievementNFT
AchievementMinter authorized on TreasureNFT

=== Issuer Deployment Complete ===
ACHIEVEMENT_NFT: 0x...
TREASURE_NFT: 0x...
ACHIEVEMENT_MINTER: 0x...
VAULT_WBTC: 0x...
VAULT_CBBTC: 0x...
VAULT_TBTC: 0x...
```

**Record these addresses.** You will need them for frontend integration and additional configuration.

---

## 6. Post-Deployment Verification

Verify deployment succeeded using `cast`:

```bash
# Set deployed addresses
export ACHIEVEMENT_NFT=0x...
export TREASURE_NFT=0x...
export ACHIEVEMENT_MINTER=0x...

# Verify ownership
cast call $ACHIEVEMENT_NFT "owner()(address)" --rpc-url $RPC_URL
cast call $TREASURE_NFT "owner()(address)" --rpc-url $RPC_URL

# Verify minter authorization
cast call $ACHIEVEMENT_NFT "authorizedMinters(address)(bool)" $ACHIEVEMENT_MINTER --rpc-url $RPC_URL
# Expected: true

cast call $TREASURE_NFT "authorizedMinters(address)(bool)" $ACHIEVEMENT_MINTER --rpc-url $RPC_URL
# Expected: true

# Verify protocol mapping
cast call $ACHIEVEMENT_MINTER "protocols(address)(address)" $WBTC --rpc-url $RPC_URL
# Expected: $VAULT_WBTC address
```

---

## 7. Additional Minter Authorization

After deployment, you may need to authorize additional minters:

**Use cases:**
- Deploying AuctionController separately
- Custom minter contracts for launch-exclusive achievements

**Authorize a new minter:**

```bash
# On AchievementNFT
cast send $ACHIEVEMENT_NFT "authorizeMinter(address)" $NEW_MINTER \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL

# On TreasureNFT
cast send $TREASURE_NFT "authorizeMinter(address)" $NEW_MINTER \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

**Revoke a minter:**

```bash
cast send $ACHIEVEMENT_NFT "revokeMinter(address)" $MINTER_TO_REVOKE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 8. AuctionController Deployment

AuctionController is not included in the base deployment script. Deploy separately if needed.

### Constructor Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `treasureNFT_` | address | Deployed TreasureNFT address |
| `collateralTokens_` | address[] | [WBTC, CBBTC, TBTC] |
| `protocols_` | address[] | [VAULT_WBTC, VAULT_CBBTC, VAULT_TBTC] |

### Deploy via forge create

```bash
forge create src/AuctionController.sol:AuctionController \
  --constructor-args $TREASURE_NFT "[$WBTC,$CBBTC,$TBTC]" "[$VAULT_WBTC,$VAULT_CBBTC,$VAULT_TBTC]" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --verify
```

### Post-Deployment

Authorize AuctionController to mint Treasures:

```bash
cast send $TREASURE_NFT "authorizeMinter(address)" $AUCTION_CONTROLLER \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

For auction configuration, see [Integration Guide Section 4](./Integration_Guide.md#4-minting-modes).

---

## 9. Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| `Missing environment variable` | Required env var not set | Verify all variables in Section 3 are defined |
| `Insufficient gas` | Deployer account underfunded | Fund deployer with ETH |
| `EvmError: Revert` during deploy | Invalid protocol address | Verify VaultNFT addresses match collateral tokens |
| `NotAuthorizedMinter` post-deployment | Authorization transaction failed | Re-run authorization (Section 7) |
| Contract not verified | Missing Etherscan API key | Add `--etherscan-api-key` flag |

---

## 10. Next Steps

After successful deployment:

1. **Configure metadata service** - Implement base URI endpoints for NFT metadata
2. **Create auctions** - See [Integration Guide Section 4](./Integration_Guide.md#4-minting-modes) for Dutch/English auction setup
3. **Set up achievements** - See [Achievements Specification](./Achievements_Specification.md) for claiming mechanics
4. **Frontend integration** - Connect deployed contracts to your dApp

---

## Navigation

← [Issuer Layer](./README.md) | [Integration Guide](./Integration_Guide.md) →
