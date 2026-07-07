# Monorepo Architecture Optimization Plan

## Executive Summary

This plan establishes a rational roadmap to:
1. **Optimize** the current monorepo structure (immediate)
2. **Prepare** for BTCNFT Protocol isolation (near-term)
3. **Extract** protocol as standalone repository (future)

## Current State

**Hybrid Foundry + TypeScript monorepo** with no centralized orchestration:

```
zeno/
├── contracts/
│   ├── protocol/       # Immutable core (3 contracts, 10k fuzz runs)
│   ├── issuer/         # Templates (52+ files, poorly organized)
│   └── simulation/     # Integration testing
├── apps/
│   ├── ascent/         # Next.js (uses vault-analytics via file:)
│   └── vector/         # Next.js (standalone)
├── packages/
│   └── vault-analytics/ # TypeScript SDK
├── cli/                # Bash CLI
├── lib/                # Git submodules (forge-std, openzeppelin)
└── docs/
```

### Current Protocol Coupling Analysis

| Consumer | Import | Type |
|----------|--------|------|
| `issuer/TreasureNFT.sol` | `@protocol/interfaces/IVaultNFT.sol` | Interface only |
| `issuer/test/mocks/MockVaultNFTForHybrid.sol` | `@protocol/interfaces/IVaultNFT.sol` | Test mock |
| `simulation/*` | `@protocol/VaultNFT.sol`, `BtcToken.sol`, `VaultMath.sol` | Full contracts (expected) |

**Key insight:** Issuer has minimal source coupling (1 interface import). This makes isolation straightforward.

## Issues Identified

| Issue | Location | Impact |
|-------|----------|--------|
| **DRY Violation** | Constants duplicated in VaultMath.sol, protocol.ts, constants.sh | Maintenance burden, drift risk |
| **No Build Orchestration** | Manual `cd && forge build` per workspace | No caching, no parallel builds |
| **Issuer Directory Sprawl** | 18 top-level .sol files with mixed concerns | Poor discoverability |
| **File Protocol References** | `file:../../packages/vault-analytics` | Fragile, no version management |
| **Repeated Foundry Config** | Same remappings in 3 foundry.toml files | DRY violation |

## Proposed Architecture

### 1. Workspace Orchestration: pnpm + Turborepo

**Why:** pnpm provides efficient disk usage via hard links; Turborepo adds task caching and parallel execution.

**Root files to create:**

```yaml
# pnpm-workspace.yaml
packages:
  - 'packages/*'
  - 'apps/*'
  - 'contracts/*'
```

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**"]
    },
    "test": { "dependsOn": ["build"] },
    "forge:build": { "outputs": ["out/**"], "cache": true },
    "forge:test": { "dependsOn": ["forge:build"] }
  }
}
```

### 2. Shared Constants Package

**Create `packages/constants/`** as single source of truth:

```typescript
// packages/constants/src/protocol.ts
export const PROTOCOL = {
  VESTING_PERIOD_DAYS: 1129,
  WITHDRAWAL_PERIOD_DAYS: 30,
  GRACE_PERIOD_DAYS: 30,
  DORMANCY_THRESHOLD_DAYS: 1129,
  WITHDRAWAL_RATE_BPS: 1000,
  BASIS_POINTS: 100000,
  BTC_DECIMALS: 8,
} as const;
```

**Integration:**
- `vault-analytics` imports from `@btcnft/constants`
- CLI generates `cli/.generated/constants.sh` from package
- Solidity `VaultMath.sol` remains canonical on-chain; test validates parity

### 3. Issuer Directory Reorganization

**From:** 18 top-level files + 4 subdirectories
**To:** Organized by concern

```
contracts/issuer/src/
├── core/           # TreasureNFT, AchievementNFT, DashboardNFT
├── registry/       # ChapterRegistry, ProfileRegistry
├── minting/        # VaultMintController, HybridMintController, *Minter, AuctionController
├── visual/         # AchievementSVG
├── verifiers/      # (existing)
├── volatility/     # (existing)
├── perpetual/      # (existing)
├── interfaces/     # (existing)
└── libraries/      # (existing)
```

### 4. Foundry Workspace Integration

Add `package.json` to each contract workspace for Turbo compatibility:

```json
// contracts/protocol/package.json
{
  "name": "@btcnft/contracts-protocol",
  "private": true,
  "scripts": {
    "forge:build": "forge build",
    "forge:test": "forge test",
    "clean": "rm -rf out cache"
  }
}
```

### 5. Dependency Graph (Target State)

```
@btcnft/constants
       │
       ├─────────────────┬─────────────────┐
       ▼                 ▼                 ▼
@btcnft/vault-analytics  cli/           contracts/protocol
       │                                       │
       ▼                                       ▼
apps/ascent, apps/vector              contracts/issuer
                                              │
                                              ▼
                                     contracts/simulation
```

## Implementation Steps

### Phase 1: Workspace Orchestration
1. Create `pnpm-workspace.yaml`
2. Create root `package.json` with workspace scripts
3. Create `turbo.json` with task definitions
4. Add `package.json` to each contract workspace
5. Convert `file:` references to `workspace:*`

### Phase 2: Shared Constants
1. Create `packages/constants/` package
2. Migrate constants from `vault-analytics/src/constants/protocol.ts`
3. Add generation script for `cli/.generated/constants.sh`
4. Add cross-validation test (TypeScript ↔ Solidity parity)
5. Update `vault-analytics` to import from `@btcnft/constants`

### Phase 3: Issuer Reorganization
1. Create subdirectories: `core/`, `registry/`, `minting/`, `visual/`, `automation/`
2. Move contracts to appropriate directories
3. Update all import paths
4. Verify `forge build` and `forge test` pass

### Phase 4: Protocol Interface Package (Isolation Prep)
1. Create `packages/protocol-interfaces/`
2. Copy protocol interfaces: `IVaultNFT.sol`, `IBtcToken.sol`
3. Generate TypeScript types from ABIs
4. Update issuer remapping to use interface package
5. Verify issuer builds without `@protocol/` source remapping

## Files to Modify

| File | Action |
|------|--------|
| `/package.json` (root) | Create - workspace config |
| `/pnpm-workspace.yaml` | Create - workspace definitions |
| `/turbo.json` | Create - task pipeline |
| `/contracts/protocol/package.json` | Create - Turbo integration |
| `/contracts/issuer/package.json` | Create - Turbo integration |
| `/contracts/simulation/package.json` | Create - Turbo integration |
| `/packages/constants/` | Create - new package |
| `/packages/protocol-interfaces/` | Create - interface artifact package |
| `/packages/vault-analytics/package.json` | Update - use workspace dep |
| `/apps/ascent/package.json` | Update - use workspace:* |
| `/contracts/issuer/src/**/*.sol` | Move - reorganize directories |
| `/contracts/issuer/foundry.toml` | Update - change protocol remapping |

## Verification

### Phase 1-3 Verification
1. `pnpm install` completes without errors
2. `pnpm turbo build` builds all workspaces in correct order
3. `pnpm turbo forge:build` builds all contracts
4. `pnpm turbo forge:test` runs all contract tests
5. `pnpm turbo test` runs all TypeScript tests
6. Apps start successfully: `pnpm -F @btcnft/ascent dev`

### Phase 4 Verification (Protocol Isolation)
1. `contracts/issuer/foundry.toml` has no `@protocol/` remapping
2. `pnpm -F @btcnft/contracts-issuer forge:build` succeeds using interface package
3. `pnpm -F @btcnft/contracts-issuer forge:test` passes
4. `contracts/protocol/` can be moved to separate directory without breaking issuer
5. Protocol interfaces match deployed contract ABIs

---

## Protocol Isolation Roadmap

### Milestone 1: Boundary Hardening (Current Sprint)

**Goal:** Enforce clean separation boundaries while remaining in monorepo.

**Actions:**
1. **Extract protocol interfaces** to `contracts/protocol/src/interfaces/`
   - Already done: `IVaultNFT.sol`, `IBtcToken.sol`, `IVaultNFTDormancy.sol`, `IVaultNFTDelegation.sol`

2. **Create protocol artifact package** (`packages/protocol-interfaces/`)
   - TypeScript types generated from ABIs
   - Solidity interfaces for downstream consumers
   - Version-locked exports

3. **Update issuer remapping** from source to artifact:
   ```diff
   - @protocol/=../protocol/src/
   + @btcnft-protocol/=../../packages/protocol-interfaces/solidity/
   ```

4. **Simulation exception:** Simulation workspace retains source access for integration testing (intentional coupling).

### Milestone 2: Protocol Independence (Future)

**Goal:** Protocol compiles and tests with zero monorepo dependencies.

**Protocol repo structure:**
```
btcnft-protocol/               # Standalone repository
├── contracts/
│   ├── VaultNFT.sol
│   ├── BtcToken.sol
│   ├── interfaces/
│   └── libraries/
├── test/
├── script/
├── lib/                       # Own submodules
├── foundry.toml
└── package.json               # Publishes @btcnft/protocol-interfaces
```

**Zeno monorepo after extraction:**
```
zeno/
├── contracts/
│   ├── issuer/                # Consumes @btcnft/protocol-interfaces
│   └── simulation/            # Consumes protocol via npm/forge install
├── apps/
├── packages/
│   └── vault-analytics/       # Consumes @btcnft/protocol-interfaces
└── cli/
```

### Milestone 3: Artifact-Only Integration

**Goal:** Issuer and apps interact with protocol via deployed addresses only.

**Changes:**
- No source imports from protocol
- Protocol interfaces published as npm package
- Deployed contract addresses configured via environment
- Integration tests use forked mainnet or testnet

### Isolation Dependency Graph (Target)

```
┌─────────────────────────────────────┐
│     btcnft-protocol (standalone)    │
│  ┌───────────────────────────────┐  │
│  │ VaultNFT, BtcToken, VaultMath │  │
│  └───────────────┬───────────────┘  │
│                  │ publishes        │
│  ┌───────────────▼───────────────┐  │
│  │ @btcnft/protocol-interfaces   │  │
│  │ (npm package)                 │  │
│  └───────────────────────────────┘  │
└──────────────────┬──────────────────┘
                   │ npm install
     ┌─────────────┼─────────────┐
     ▼             ▼             ▼
┌─────────┐  ┌──────────┐  ┌──────────┐
│ zeno/   │  │ zeno/    │  │ zeno/    │
│ issuer  │  │ apps/*   │  │ packages │
└─────────┘  └──────────┘  └──────────┘
```

---

## What This Plan Excludes (YAGNI)

- **Nx** - Overkill for project size
- **Lerna** - Deprecated, pnpm sufficient
- **Shared Foundry profile inheritance** - Foundry lacks this; current config works
- **Monorepo-wide linting config** - Each workspace maintains its own
- **Backwards compatibility shims** - Clean migration only
- **Immediate protocol extraction** - Premature; boundary hardening first
