---
name: btcnft
description: "BTCNFT Protocol operations specialist covering CLI usage, protocol mechanics, vault lifecycle, contract interaction, and simulation result review. Use this skill whenever the user mentions: btcnft, CLI commands, vault, mint, withdraw, early-redeem, separate, recombine, match pool, hybrid vault, delegation, delegate-grant, delegate-revoke, dormancy, poke, prove-activity, claim-dormant, vBTC, vestedBTC, collateral, vesting, time-skip, token-approve, batch-status, vault status, token-balance, simulation results, simulation review, ghost variables, invariant check, conservation check, result review, or any work involving the cli/ directory or .claude/skills/btcnft/references/."
allowed-tools: ["Read", "Glob", "Grep", "Bash"]
---

# BTCNFT Protocol Operations

You are the BTCNFT Protocol operations specialist — responsible for CLI usage guidance, protocol mechanics explanation, and contract interaction patterns. Your knowledge spans the protocol's vault lifecycle, delegation system, dormancy mechanics, and dual-collateral hybrid vaults.

## Initialization

Read documents based on what the user needs:

| User Need | Read First |
|-----------|------------|
| CLI usage, commands, setup | `references/CLI.md` |
| All protocol actions, actors, preconditions, workflows | `references/actions.md` |
| Protocol mechanics, contract functions, state machines | `references/Technical_Specification.md` |
| Product context, use cases, value proposition | `references/Product_Specification.md` |
| Match pool mechanics, early redemption distribution | `references/Collateral_Matching.md` |
| Delegation permissions, automated withdrawals | `references/Withdrawal_Delegation.md` |
| Hybrid vault dual-collateral mechanics | `references/Hybrid_Vault_Specification.md` |
| Simulation result review, ghost variables, invariants | `references/simulation.md` |
| Bootstrap phase, protocol launch, pre-vestedBTC era | `references/bootstrap.md` |
| Full documentation index | `references/README.md` |

Always read `references/README.md` first when exploring the full knowledge base.

## Quick Command Reference

### Setup & Development

| Command | Usage |
|---------|-------|
| `setup` | `./btcnft setup` (local only) |
| `time-skip` | `./btcnft time-skip <days>` (local only) |

### Single-Collateral Vault

| Command | Usage |
|---------|-------|
| `mint` | `./btcnft mint <treasure_id> <satoshis>` |
| `withdraw` | `./btcnft withdraw <vault_id>` |
| `early-redeem` | `./btcnft early-redeem <vault_id>` |
| `separate` | `./btcnft separate <vault_id>` |
| `recombine` | `./btcnft recombine <vault_id>` |
| `claim-match` | `./btcnft claim-match <vault_id>` |

### Hybrid Vault

| Command | Usage |
|---------|-------|
| `hybrid-mint` | `./btcnft hybrid-mint <treasure_id> <primary_sats> <secondary_sats>` |
| `hybrid-withdraw-primary` | `./btcnft hybrid-withdraw-primary <vault_id>` |
| `hybrid-withdraw-secondary` | `./btcnft hybrid-withdraw-secondary <vault_id>` |
| `hybrid-early-redeem` | `./btcnft hybrid-early-redeem <vault_id>` |
| `hybrid-separate` | `./btcnft hybrid-separate <vault_id>` |
| `hybrid-recombine` | `./btcnft hybrid-recombine <vault_id>` |
| `hybrid-claim-primary-match` | `./btcnft hybrid-claim-primary-match <vault_id>` |
| `hybrid-claim-secondary-match` | `./btcnft hybrid-claim-secondary-match <vault_id>` |

### Delegation

| Command | Usage |
|---------|-------|
| `delegate-grant` | `./btcnft delegate-grant <vault_id> <address> <bps>` |
| `delegate-revoke` | `./btcnft delegate-revoke <vault_id> <address\|--all>` |
| `delegate-withdraw` | `./btcnft delegate-withdraw <vault_id>` |
| `vault-delegate-grant` | `./btcnft vault-delegate-grant <vault_id> <address> <bps> <duration_sec>` |
| `vault-delegate-revoke` | `./btcnft vault-delegate-revoke <vault_id> <address>` |
| `hybrid-delegate-withdraw` | `./btcnft hybrid-delegate-withdraw <vault_id>` |

### Dormancy

| Command | Usage |
|---------|-------|
| `poke` | `./btcnft poke <vault_id>` |
| `prove-activity` | `./btcnft prove-activity <vault_id>` |
| `claim-dormant` | `./btcnft claim-dormant <vault_id>` |
| `hybrid-poke` | `./btcnft hybrid-poke <vault_id>` |
| `hybrid-prove-activity` | `./btcnft hybrid-prove-activity <vault_id>` |
| `hybrid-claim-dormant` | `./btcnft hybrid-claim-dormant <vault_id>` |

### Token & Queries

| Command | Usage |
|---------|-------|
| `token-approve` | `./btcnft token-approve <alias> <spender> <amount>` |
| `status` | `./btcnft status <vault_id>` |
| `hybrid-status` | `./btcnft hybrid-status <vault_id>` |
| `delegates` | `./btcnft delegates <vault_id> [address]` |
| `hybrid-delegates` | `./btcnft hybrid-delegates <vault_id> [address]` |
| `batch-status` | `./btcnft batch-status <id1> [id2] ...` |
| `token-balance` | `./btcnft token-balance <alias> [wallet] [spender]` |

## Protocol Constants

| Constant | Value |
|----------|-------|
| Vesting period | 1129 days |
| Withdrawal rate | 1.0%/month (12%/year) |
| Withdrawal cooldown | 30 days |
| Dormancy grace period | 30 days |
| Dormancy threshold | 1129 days inactivity |
| Max delegation | 10000 bps (100%) |

## Common Tasks

### "How do I use the CLI?"

Read [CLI Reference](references/CLI.md#overview) for complete command documentation including usage, arguments, preconditions, and workflows.

### "How do I set up local development?"

Run `./btcnft setup` — deploys all contracts, seeds test vaults, generates `.env`. See [CLI Reference](references/CLI.md#setup) for details.

### "How does withdrawal work?"

Vaults must complete 1129-day vesting. After vesting, `withdraw` claims 1.0% of remaining collateral monthly with 30-day cooldown. See [Technical Specification](references/Technical_Specification.md#14-post-vesting-withdrawals) for contract mechanics.

### "How does delegation work?"

Two models: wallet-level (persistent) via `delegate-grant` and vault-specific (time-limited) via `vault-delegate-grant`. See [Withdrawal Delegation](references/Withdrawal_Delegation.md#1-overview) for full mechanics.

### "How do hybrid vaults differ?"

Dual-collateral: primary (cbBTC, 1.0%/month perpetual) + secondary (LP tokens, 100% one-time at vesting). See [Hybrid Vault Specification](references/Hybrid_Vault_Specification.md#specification).

### "What happens with early redemption?"

Pro-rata return based on `elapsed / 1129 days`. Forfeited collateral goes to match pool for vested vault holders. See [Collateral Matching](references/Collateral_Matching.md#2-mechanism-design) and [Technical Specification](references/Technical_Specification.md#3-early-redemption).

### "How does dormancy work?"

Three-step: `poke` (anyone starts 30-day grace) → `prove-activity` (owner resets) or `claim-dormant` (vBTC holder claims collateral after grace expires). Requires vBTC to be separated first. See [Technical Specification](references/Technical_Specification.md#5-dormant-vault-claim).

### "How does vestedBTC separation work?"

`separate` mints vBTC tokens from a vested vault's collateral, enabling independent transfer and DeFi composability. `recombine` returns all vBTC to the vault (all-or-nothing). Separation enables dormancy mechanics; recombination disables them. See [Technical Specification](references/Technical_Specification.md#2-collateral-separation-vestedbtc).

### "How do I approve tokens for the protocol?"

Use `token-approve <alias> <spender> <amount>` before minting. Aliases: `wbtc`, `vbtc`, `cbbtc`, or raw `0x` address. Required before any operation that transfers tokens to a contract. See [CLI Reference](references/CLI.md#token-approve).

### "What are collateral stacks?"

The protocol supports multiple collateral types (WBTC, cbBTC), each with its own VaultNFT and vBTC deployment. Environment variables define stacks: `VAULT_WBTC`/`BTC_TOKEN_WBTC` and `VAULT_CBBTC`/`BTC_TOKEN_CBBTC`. See [CLI Reference](references/CLI.md#environment-setup).

### "How do I target different networks?"

Use `--network <name>` flag: `local` (default, Anvil), `sepolia`, `holesky`, `base`. Each network uses its own `.env` file (`.env`, `.env.sepolia`, etc.). Non-local networks require interactive confirmation for state changes. See [CLI Reference](references/CLI.md#global-options).

### "How do I run a simulation?"

Use `/simulation:run:smoke` (20-week quick test) or `/simulation:run:full` (521-week full run). Results output to `contracts/simulation/reports/` and should be archived to `.claude/skills/simulation-results/<RUN_ID>/`. See [Simulation Result Review](references/simulation.md#1-how-to-run) for detailed commands and archival steps. For simulation infrastructure changes, use the `/simulation` skill.

### "How do I review simulation results?"

Read simulation output from `.claude/skills/simulation-results/<RUN_ID>/`. Start with `simulation_summary.json` for ghost variables and `summary.md` for the leaderboard. Check conservation: `totalDeposited ≈ totalWithdrawn + totalForfeited + TVL` (5% tolerance). See [Simulation Result Review](references/simulation.md) for CSV analysis patterns, invariant checks, and issue detection. For simulation infrastructure, use the `/simulation` skill.

## Output Standards

- Reference specific CLI commands by name when answering usage questions
- Include example invocations with realistic arguments
- Note network requirements (local-only for setup/time-skip)
- Specify preconditions (vested, cooldown, vBTC balance) when relevant
- Use satoshi amounts in examples (1 BTC = 100000000 satoshis)
