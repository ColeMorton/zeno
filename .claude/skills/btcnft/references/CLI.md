# BTCNFT Protocol CLI Reference

> **Version:** 2.0.0
> **Status:** Final
> **Last Updated:** 2026-03-22
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Hybrid Vault Specification](./Hybrid_Vault_Specification.md)
> - [Withdrawal Delegation](./Withdrawal_Delegation.md)

---

## Overview

Bash CLI wrapping Foundry's `cast` for interacting with the BTCNFT Protocol smart contracts.

- **Entry point:** `./cli/btcnft`
- **Usage:** `./btcnft [--network <network>] <command> [args...]`
- **Networks:** local (Anvil, default), sepolia, holesky, base
- **Ethereum mainnet:** Explicitly rejected

## Prerequisites

- Foundry toolchain: `cast`, `anvil`, `forge`
- `jq` and `bc`
- For local: Anvil running on `http://127.0.0.1:8545`

## Environment Setup

Each network uses its own `.env` file: `.env` (local), `.env.sepolia`, `.env.holesky`, `.env.base`.

```bash
# Required
PRIVATE_KEY=0x...
TREASURE=0x...              # TreasureNFT address

# WBTC Collateral Stack
WBTC=0x...                  # WBTC token address
BTC_TOKEN_WBTC=0x...        # vBTC for WBTC stack
VAULT_WBTC=0x...            # VaultNFT for WBTC stack

# cbBTC Collateral Stack
CBBTC=0x...                 # cbBTC token address
BTC_TOKEN_CBBTC=0x...       # vBTC for cbBTC stack
VAULT_CBBTC=0x...           # VaultNFT for cbBTC stack

# Legacy aliases (point to active stack)
BTC_TOKEN=0x...
VAULT=0x...

# Optional
HYBRID_VAULT=0x...          # HybridVaultNFT address
```

**Token aliases:** Commands accepting token references resolve aliases via `resolve_token_address()`:
- `wbtc` → `$WBTC`
- `vbtc` → `$BTC_TOKEN`
- `cbbtc` → `$CBBTC`
- Raw `0x...` addresses pass through unchanged

## Global Options

| Flag | Description |
|------|-------------|
| `--network <name>` | Target network: local, sepolia, holesky, base (default: local) |
| `--help`, `-h` | Show usage |
| `--version`, `-v` | Show version (2.0.0) |

Non-local networks prompt for interactive confirmation before state-changing operations.

## Protocol Constants

| Constant | Value | Description |
|----------|-------|-------------|
| Vesting period | 1129 days | Lock before withdrawals enabled |
| Withdrawal rate | 1.0%/month (12%/year) | 1000 basis points |
| Withdrawal cooldown | 30 days | Minimum between withdrawals |
| Dormancy grace period | 30 days | Owner response window after poke |
| Dormancy threshold | 1129 days | Inactivity period triggering dormancy |
| Max delegation | 10000 bps (100%) | Maximum total delegation per vault |
| BTC decimals | 8 | Satoshis to BTC conversion |

---

## Setup & Deployment

### `setup`

Local-only idempotent development setup.

```bash
./btcnft setup
```

Steps: checks Foundry deps → manages Anvil → deploys protocol contracts (dual collateral stacks) → deploys issuer contracts (VaultMintController) → generates `.env` → seeds 5 test vaults (1100 days old) → resets time to epoch baseline (Jan 1 2024).

---

## Single-Collateral Vault Commands

### `mint`

Create a vault by depositing collateral and a Treasure NFT.

```bash
./btcnft mint <treasure_token_id> <btc_amount_satoshis>
```

| Arg | Description |
|-----|-------------|
| `treasure_token_id` | Treasure NFT token ID to wrap |
| `btc_amount_satoshis` | WBTC collateral amount in satoshis |

**Preconditions:** Sufficient WBTC balance. Approves WBTC and Treasure NFT, then calls `mint(address,uint256,address,uint256)` on VAULT. Returns the minted vault token ID.

### `withdraw`

Withdraw 1.0% of collateral (monthly rate).

```bash
./btcnft withdraw <vault_token_id>
```

**Preconditions:** Vault must be vested (1129 days elapsed). 30+ days since last withdrawal. Calls `getWithdrawableAmount(uint256)` then `withdraw(uint256)`. Shows withdrawn and remaining collateral.

### `early-redeem`

Exit vault early with pro-rata penalty.

```bash
./btcnft early-redeem <vault_token_id>
```

Returns `(elapsed / 1129 days)` of collateral. Forfeited amount goes to match pool. Burns the vault NFT. Interactive confirmation required. Calls `earlyRedeem(uint256)`.

### `separate`

Mint vBTC tokens from a vested vault's collateral.

```bash
./btcnft separate <vault_token_id>
```

**Preconditions:** Vault must be vested. vBTC not yet minted (`btcTokenAmount == 0`). Calls `mintBtcToken(uint256)`. vBTC amount equals collateral amount. Enables dormancy mechanics and independent vBTC transfer.

### `recombine`

Return vBTC tokens back to the vault.

```bash
./btcnft recombine <vault_token_id>
```

**Preconditions:** Must hold full original vBTC amount. Calls `returnBtcToken(uint256)`. Disables dormancy mechanics.

### `claim-match`

Claim pro-rata share of the match pool.

```bash
./btcnft claim-match <vault_token_id>
```

**Preconditions:** Vault must be vested. Match pool must have balance (populated by early redemption forfeitures). Calls `claimMatch(uint256)`. Shows claimed amount and new collateral balance.

---

## Hybrid Vault Commands (Dual-Collateral)

Hybrid vaults hold two collateral types: primary (WBTC, 1.0%/month withdrawal) and secondary (cbBTC, 100% one-time withdrawal after vesting).

### `hybrid-mint`

Create a hybrid vault with dual collateral.

```bash
./btcnft hybrid-mint <treasure_token_id> <primary_satoshis> <secondary_satoshis>
```

| Arg | Description |
|-----|-------------|
| `treasure_token_id` | Treasure NFT token ID |
| `primary_satoshis` | WBTC amount (satoshis) |
| `secondary_satoshis` | cbBTC amount (satoshis) |

**Env requires:** `HYBRID_VAULT`, `WBTC`, `CBBTC`, `TREASURE`. Approves both tokens and Treasure NFT, calls `mint(address,uint256,uint256,uint256)`.

### `hybrid-withdraw-primary`

Withdraw 1.0%/month from primary collateral.

```bash
./btcnft hybrid-withdraw-primary <vault_token_id>
```

**Preconditions:** Vested + 30 days since last primary withdrawal. Calls `withdrawPrimary(uint256)`.

### `hybrid-withdraw-secondary`

Withdraw 100% of secondary collateral (one-time).

```bash
./btcnft hybrid-withdraw-secondary <vault_token_id>
```

**Preconditions:** Vested + not already withdrawn. Calls `withdrawSecondary(uint256)`.

### `hybrid-early-redeem`

Exit hybrid vault with pro-rata penalty on both collaterals.

```bash
./btcnft hybrid-early-redeem <vault_token_id>
```

Pro-rata calculation applies independently to primary and secondary. Forfeitures go to respective match pools. Burns vault. Calls `earlyRedeem(uint256)`.

### `hybrid-separate`

Mint vBTC from hybrid vault's primary collateral.

```bash
./btcnft hybrid-separate <vault_token_id>
```

**Preconditions:** Vested. Calls `mintBtcToken(uint256)`.

### `hybrid-recombine`

Return vBTC to hybrid vault.

```bash
./btcnft hybrid-recombine <vault_token_id>
```

Calls `returnBtcToken(uint256)`.

### `hybrid-claim-primary-match`

Claim pro-rata share of primary match pool.

```bash
./btcnft hybrid-claim-primary-match <vault_token_id>
```

**Preconditions:** Vested. Calls `claimPrimaryMatch(uint256)`.

### `hybrid-claim-secondary-match`

Claim pro-rata share of secondary match pool.

```bash
./btcnft hybrid-claim-secondary-match <vault_token_id>
```

**Preconditions:** Vested. Calls `claimSecondaryMatch(uint256)`.

---

## Delegation Commands

Two delegation models: **wallet-level** (persistent, tied to owner address) and **vault-specific** (time-limited, tied to vault ID).

### `delegate-grant`

Grant wallet-level withdrawal delegation.

```bash
./btcnft delegate-grant <vault_token_id> <delegate_address> <percentage_bps>
```

| Arg | Description |
|-----|-------------|
| `vault_token_id` | Vault to delegate from |
| `delegate_address` | Delegate wallet address |
| `percentage_bps` | 1–10000 basis points (100 bps = 1%) |

Total delegation across all delegates cannot exceed 10000 bps (100%). Calls `grantWithdrawalDelegate(uint256,address,uint256)`.

### `delegate-revoke`

Revoke wallet-level delegation.

```bash
./btcnft delegate-revoke <vault_token_id> <delegate_address>
./btcnft delegate-revoke <vault_token_id> --all
```

Single delegate: `revokeWithdrawalDelegate(uint256,address)`. All delegates: `revokeAllWithdrawalDelegates(uint256)`.

### `delegate-withdraw`

Withdraw as a delegated address.

```bash
./btcnft delegate-withdraw <vault_token_id>
```

**Preconditions:** Caller is registered delegate, vault is vested, 30+ days since delegate's last withdrawal. Withdrawal amount = vault's withdrawable amount × delegate's percentage. Calls `withdrawAsDelegate(uint256)`.

### `vault-delegate-grant`

Grant vault-specific time-limited delegation.

```bash
./btcnft vault-delegate-grant <vault_token_id> <delegate_address> <percentage_bps> <duration_seconds>
```

| Arg | Description |
|-----|-------------|
| `duration_seconds` | Delegation duration (e.g., 2592000 = 30 days) |

Works with both VAULT and HYBRID_VAULT. Calls `grantVaultDelegate(uint256,address,uint256,uint256)`.

### `vault-delegate-revoke`

Revoke vault-specific delegation.

```bash
./btcnft vault-delegate-revoke <vault_token_id> <delegate_address>
```

Calls `revokeVaultDelegate(uint256,address)`.

### `hybrid-delegate-withdraw`

Withdraw primary collateral as a hybrid vault delegate.

```bash
./btcnft hybrid-delegate-withdraw <vault_token_id>
```

**Preconditions:** Caller is registered delegate, vault is vested. Calls `withdrawPrimaryAsDelegate(uint256)`.

---

## Dormancy Commands

Dormancy lifecycle: **poke** (start 30-day grace) → **prove-activity** (owner resets) OR **claim-dormant** (claimant takes collateral after grace expires).

### `poke`

Initiate dormancy claim process on a single-collateral vault.

```bash
./btcnft poke <vault_token_id>
```

Any address can poke a dormant-eligible vault. Starts 30-day grace period. Calls `pokeDormant(uint256)`.

### `prove-activity`

Prove vault activity to prevent dormancy claim.

```bash
./btcnft prove-activity <vault_token_id>
```

**Must be called by vault owner.** Resets dormancy timer. Calls `proveActivity(uint256)`.

### `claim-dormant`

Claim collateral from a dormant vault.

```bash
./btcnft claim-dormant <vault_token_id>
```

**Preconditions:** Grace period expired. vBTC must be separated. Caller must hold full vBTC amount. Transfers vault collateral to caller. Calls `claimDormantCollateral(uint256)`.

### `hybrid-poke`

Initiate dormancy on hybrid vault.

```bash
./btcnft hybrid-poke <vault_token_id>
```

Same as `poke` but targets HYBRID_VAULT.

### `hybrid-prove-activity`

Prove hybrid vault activity.

```bash
./btcnft hybrid-prove-activity <vault_token_id>
```

Same as `prove-activity` but targets HYBRID_VAULT.

### `hybrid-claim-dormant`

Claim dormant hybrid vault collateral (both primary and secondary).

```bash
./btcnft hybrid-claim-dormant <vault_token_id>
```

Claims both primary and secondary collateral. Calls `claimDormantCollateral(uint256)`.

---

## Token Commands

### `token-approve`

Approve ERC-20 token spending.

```bash
./btcnft token-approve <token_alias> <spender_address> <amount>
```

Token aliases: `wbtc`, `vbtc`, `cbbtc`, or raw `0x...` address. Calls `approve(address,uint256)`.

---

## Queries (Read-Only)

### `status`

Display comprehensive single-collateral vault status.

```bash
./btcnft status <vault_token_id>
```

**Output:** Owner, collateral (current + original), withdrawal rate, timestamps (minted, last withdrawal, last activity), vesting progress, withdrawable amount or cooldown remaining, vBTC separation status, dormancy eligibility, total delegation percentage.

### `hybrid-status`

Display comprehensive hybrid vault status.

```bash
./btcnft hybrid-status <vault_token_id>
```

**Output:** Owner, primary + secondary collateral, withdrawal rates (primary 1.0%/month, secondary 100% one-time), timestamps, vesting progress, primary withdrawable + secondary status, match pool balances, dormancy status, wallet-level + vault-specific delegation totals.

### `delegates`

Query vault delegation information.

```bash
./btcnft delegates <vault_token_id>                    # Summary
./btcnft delegates <vault_token_id> <delegate_address>  # Detailed
```

**Summary:** Total delegated percentage. **Detailed:** Status, percentage, granted timestamp, last withdrawal, can-withdraw flag, withdrawable amount.

### `hybrid-delegates`

Query hybrid vault delegation.

```bash
./btcnft hybrid-delegates <vault_token_id>                    # Summary
./btcnft hybrid-delegates <vault_token_id> <delegate_address>  # Detailed
```

**Summary:** Wallet-level + vault-specific delegation totals. **Detailed:** Effective percentage, delegation type, expiration status, withdrawable amount.

### `batch-status`

Query multiple vaults in tabular format.

```bash
./btcnft batch-status <id1> [id2] [id3] ...
```

**Output columns:** ID, Collateral (BTC), Vested (Yes/No), vBTC (Yes/No), Delegated (%).

### `token-balance`

Show token balance and optional allowance.

```bash
./btcnft token-balance <token_alias>                                # Caller's balance
./btcnft token-balance <token_alias> <wallet_address>               # Specific wallet
./btcnft token-balance <token_alias> <wallet_address> <spender>     # With allowance
```

---

## Development Tools (Local Only)

### `time-skip`

Fast-forward blockchain time.

```bash
./btcnft time-skip <days>
```

Local network only. Uses `evm_increaseTime` + `evm_mine`. Common values: 30 (one withdrawal period), 1129 (full vesting).

---

## Common Workflows

### Local Development Loop

```bash
./btcnft setup                    # Deploy contracts, seed data
./btcnft mint 1 100000000         # Create vault with 1 BTC
./btcnft time-skip 1129           # Fast-forward through vesting
./btcnft withdraw 1               # First withdrawal (1.0%)
./btcnft time-skip 30             # Wait one cooldown
./btcnft withdraw 1               # Second withdrawal
```

### Delegation Flow

```bash
./btcnft mint 1 100000000                           # Create vault
./btcnft delegate-grant 1 0xDelegate... 5000        # Grant 50%
# Delegate runs:
./btcnft delegate-withdraw 1                        # Withdraw as delegate
```

### vBTC Lifecycle

```bash
./btcnft mint 1 100000000         # Create vault
./btcnft time-skip 1129           # Vest
./btcnft separate 1               # Mint vBTC
# ... trade vBTC ...
./btcnft recombine 1              # Return vBTC to vault
```

### Dormancy Claim

```bash
# Inactive vault detected:
./btcnft poke 1                   # Start 30-day grace
./btcnft time-skip 30             # Grace period expires
./btcnft claim-dormant 1          # Claim collateral (requires vBTC)
```

### Hybrid Vault Flow

```bash
./btcnft hybrid-mint 1 80000000 20000000     # 0.8 WBTC + 0.2 cbBTC
./btcnft time-skip 1129                      # Vest
./btcnft hybrid-withdraw-primary 1           # 1.0%/month from primary
./btcnft hybrid-withdraw-secondary 1         # 100% of secondary (one-time)
```

---

## Architecture

```
cli/
├── btcnft                  # Entry point: parses --network, routes to command/query/dev
├── commands/               # State-changing operations (28 scripts)
├── queries/                # Read-only operations (6 scripts)
├── dev/                    # Development tools (time-skip)
├── lib/
│   ├── common.sh           # Shared helpers: cast_call, cast_send, format_btc, require_vested, etc.
│   ├── constants.sh        # Protocol constants: vesting period, rates, thresholds
│   └── network.sh          # Network config: RPC URLs, env file resolution, confirmation prompts
├── .env                    # Generated by setup (local)
├── .env.example            # Template for all networks
└── .env.base.example       # Base mainnet template (cbBTC address pre-filled)
```

All commands source `lib/common.sh` which sources `lib/constants.sh` and `lib/network.sh`. Helper functions: `cast_call()` (read-only), `cast_send()` (transactions), `require_vested()`, `require_vault_exists()`, `require_hybrid_vault_exists()`, `format_btc()`, `resolve_token_address()`, `approve_erc20()`, `get_caller_address()`.
