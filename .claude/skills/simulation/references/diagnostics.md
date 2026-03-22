# Simulation Diagnostics

Authoritative reference for all errors, failures, and debugging methodology encountered during simulation execution.

---

## 1. Protocol Error Catalog

Every custom error from VaultNFT that simulation agents can trigger, organized by action.

### Vault Lifecycle Errors

| Error | Parameters | Triggered By | Condition |
|-------|-----------|-------------|-----------|
| `ZeroCollateral()` | — | `mint()` | `collateralAmount_ == 0` |
| `InvalidCollateralToken(address)` | token | `mint()` | Token != contract's collateralToken |
| `NotTokenOwner(uint256)` | tokenId | `withdraw`, `earlyRedeem`, `mintBtcToken`, `returnBtcToken`, `proveActivity` | `ownerOf(tokenId) != msg.sender` |
| `StillVesting(uint256)` | tokenId | `withdraw`, `mintBtcToken`, `withdrawAsDelegate` | Vault not past 1129-day vesting |
| `WithdrawalTooSoon(uint256, uint256)` | tokenId, nextAllowed | `withdraw()` | 30-day cooldown not elapsed |
| `BtcTokenAlreadyMinted(uint256)` | tokenId | `mintBtcToken()` | vBTC already separated from this vault |
| `BtcTokenRequired(uint256)` | tokenId | `returnBtcToken()` | No vBTC was ever separated (`_btcTokenAmount == 0`) |
| `InsufficientBtcToken(uint256, uint256)` | required, available | `earlyRedeem`, `returnBtcToken`, `claimDormantCollateral` | Caller vBTC balance < required amount |
| `NotVested(uint256)` | tokenId | `claimMatch()` | Vault not past 1129-day vesting |
| `AlreadyClaimed(uint256)` | tokenId | `claimMatch()` | `matchClaimed[tokenId] == true` |
| `NoPoolAvailable()` | — | `claimMatch()` | `matchPool == 0` OR denominator == 0 OR share rounds to 0 |

### Dormancy Errors

| Error | Parameters | Triggered By | Condition |
|-------|-----------|-------------|-----------|
| `NotDormantEligible(uint256)` | tokenId | `pokeDormant()` | `isDormantEligible()` returns false |
| `AlreadyPoked(uint256)` | tokenId | `pokeDormant()` | State != `ACTIVE` (already in grace period) |
| `NotClaimable(uint256)` | tokenId | `claimDormantCollateral()` | State != `CLAIMABLE` (grace period not expired) |

### Delegation Errors

| Error | Parameters | Triggered By | Condition |
|-------|-----------|-------------|-----------|
| `ZeroAddress()` | — | `grantWithdrawalDelegate`, `grantVaultDelegate` | `delegate == address(0)` |
| `CannotDelegateSelf()` | — | `grantWithdrawalDelegate`, `grantVaultDelegate` | `delegate == msg.sender` |
| `InvalidPercentage(uint256)` | percentage | `grantWithdrawalDelegate`, `grantVaultDelegate` | BPS == 0 or BPS > 10000 |
| `ExceedsDelegationLimit()` | — | `grantWithdrawalDelegate()` | Wallet total delegated + new BPS > 10000 |
| `ExceedsVaultDelegationLimit(uint256)` | tokenId | `grantVaultDelegate()` | Vault total delegated + new BPS > 10000 |
| `DelegateNotActive(address, address)` | owner, delegate | `revokeWithdrawalDelegate()` | Permission not active |
| `VaultDelegateNotActive(uint256, address)` | tokenId, delegate | `revokeVaultDelegate()` | Permission not active |
| `NotActiveDelegate(uint256, address)` | tokenId, delegate | `withdrawAsDelegate()` | No valid delegation exists |
| `WithdrawalPeriodNotMet(uint256, address)` | tokenId, delegate | `withdrawAsDelegate()` | 30-day delegate cooldown not elapsed |
| `NotVaultOwner(uint256)` | tokenId | `grantVaultDelegate`, `revokeVaultDelegate` | `ownerOf(tokenId) != msg.sender` |

### ERC-721 Implicit Errors

| Error | Triggered By | Condition |
|-------|-------------|-----------|
| `ERC721NonexistentToken(uint256)` | Any function with `_requireOwned()` | Token ID does not exist (burned or never minted) |

---

## 2. Failure Root Causes

Five systemic categories cause the majority of failed actions in swarm simulations.

### A. Aggregate Portfolio vs Vault-Specific Requirements

The decision logic historically used aggregate boolean flags (`hasVestedVault`, `canWithdraw`) but selected a specific vault (e.g., `vaultIds[0]`). The selected vault may not satisfy the condition that was checked in aggregate.

**Example:** `portfolio.hasVestedVault` is true because vault #2 is vested, but `vaultIds[0]` is unvested. Agent attempts `WITHDRAW` on vault #0 → `StillVesting`.

**Mitigation (applied):** Portfolio now provides vault-specific IDs (`withdrawableVaultId`, `matchClaimableVaultId`, `unvestedVaultId`, `vestedVaultId`). Decision logic targets the specific eligible vault.

### B. Cooldown/One-Shot Retry Spam

Actions with cooldowns or one-time semantics are reattempted every rebalance interval:

- `CLAIM_MATCH` — once per vault per epoch, but agents retry every tick while `matchPoolSize > 0` (other agents' unclaimed shares)
- `WITHDRAW` — 30-day cooldown, but rebalance interval is 1-14 weeks (7-98 days)
- `WITHDRAW_AS_DELEGATE` — same 30-day cooldown as owner withdrawal

**Mitigation (applied):** `_vaultMatchClaimed[vaultId]` tracking in orchestrator; `matchClaimableVaultId` in portfolio skips already-claimed vaults.

### C. Multi-Agent Race Conditions

All 100 agents execute sequentially within a single tick. Portfolio snapshots are built at the start of each agent's turn but become stale as earlier agents modify state:

- Multiple agents find the same dormant vault → first pokes it, rest get `AlreadyPoked`
- Multiple agents target the same claimable vault → first claims, rest get `NotClaimable`
- Match pool drains as agents claim → later agents find pool depleted

**Mitigation:** Inherent to sequential execution. Not fully solvable without randomized agent ordering.

### D. Stale Vault IDs

`_agentVaultIds[agentId]` is only cleaned on `earlyRedeem`. If a vault is burned through dormancy claim, the owner's vault ID array retains the stale entry. Subsequent actions on that vault ID revert with `ERC721NonexistentToken` or `NotTokenOwner`.

**Mitigation (applied):** `_buildPortfolio` now calls `ownerOf(vid)` to verify vault ownership, skipping burned/transferred vaults. Stale IDs are not removed from storage but are effectively ignored.

### E. Delegation BPS Overflow

Multiple grantors deterministically pick the same delegate agent. Cumulative BPS across multiple `grantWithdrawalDelegate` calls can exceed 10000.

**Mitigation (applied):** Decision logic checks `currentWalletDelegatedBps + grantBps <= 10000` before attempting grant. Portfolio reads `walletTotalDelegatedBPS()` to provide accurate capacity.

---

## 3. Per-Action Failure Matrix

For each protocol action: errors it can hit, what decision logic checks, expected failure frequency.

| Action | Protocol Errors | Decision Logic Checks | Decision Logic Gaps | Failure Rate |
|--------|----------------|----------------------|---------------------|-------------|
| `MINT_VAULT` | `ZeroCollateral`, token transfer | `vaultIds.length == 0`, `wbtcBalance > 0` | Treasure NFT exhaustion (multi-vault agents) | Low |
| `WITHDRAW` | `StillVesting`, `WithdrawalTooSoon`, `NotTokenOwner` | `withdrawableVaultId > 0` (vault-specific) | Stale vault IDs not pruned from storage | Low |
| `EARLY_REDEEM` | `NotTokenOwner`, `InsufficientBtcToken` | `unvestedVaultId > 0`, drawdown threshold | Vault already redeemed (stale ID) | Medium |
| `MINT_BTC_TOKEN` | `StillVesting`, `BtcTokenAlreadyMinted`, `NotTokenOwner` | `vestedVaultId > 0`, `!hasSeparatedVbtc` | Global flag vs per-vault state | Low |
| `RETURN_BTC_TOKEN` | `BtcTokenRequired`, `InsufficientBtcToken`, `NotTokenOwner` | `hasSeparatedVbtc`, `vbtcBalance > 0` | vBTC balance may be < required for vault | Medium |
| `CLAIM_MATCH` | `NotVested`, `AlreadyClaimed`, `NoPoolAvailable` | `matchClaimableVaultId > 0`, `matchPoolSize > 0` | Race condition (pool drained by earlier agents) | Medium |
| `PROVE_ACTIVITY` | `NotTokenOwner` | `anyValidVaultId > 0`, tick interval | Vault burned between snapshot and execution | Very Low |
| `POKE_DORMANT` | `NotDormantEligible`, `AlreadyPoked` | `dormantTargetId > 0`, `!dormantClaimable` | Race condition (another agent poked first) | High |
| `CLAIM_DORMANT` | `NotClaimable`, `InsufficientBtcToken` | `dormantClaimable`, `vbtcBalance > 0` | Race condition + vBTC amount mismatch | High |
| `GRANT_WALLET_DELEGATE` | `ExceedsDelegationLimit`, `CannotDelegateSelf` | `delegatedBps + grant <= 10000` | Duplicate grants to same delegate | Low |
| `GRANT_VAULT_DELEGATE` | `ExceedsVaultDelegationLimit`, `NotVaultOwner` | `vestedVaultId > 0` | Vault burned, vault BPS overflow | Medium |
| `REVOKE_WALLET_DELEGATE` | `DelegateNotActive` | — | Not yet triggered in current decision logic | N/A |
| `WITHDRAW_AS_DELEGATE` | `NotActiveDelegate`, `WithdrawalPeriodNotMet`, `StillVesting` | `canDelegateWithdraw`, `delegateTargetVaultId > 0` | 30-day cooldown between portfolio check and execution | High |

---

## 4. Debugging Methodology

### Identifying Failure Categories

**Step 1: Check overall failure rate**
```
ghost_totalFailedActions / ghost_totalActions
```
- <20%: Healthy — mostly race conditions
- 20-40%: Moderate — check cooldown retry patterns
- \>40%: High — likely aggregate/specific mismatch or stale state issues

**Step 2: Check per-action failure distribution**
Use `agentActionCounts[agentId][actionType]` to see which actions succeed vs the action log to count attempts. High-failure actions indicate specific precondition gaps.

**Step 3: Trace specific failures**
Use `-vvvv` verbosity to see revert reasons:
```bash
forge test --match-test test_protocolSwarm -vvvv 2>&1 | grep -E "revert|Error"
```

### Ghost Variable Validation

| Check | Formula | Healthy |
|-------|---------|---------|
| Deposit conservation | `ghost_totalDeposited >= ghost_totalWithdrawn + TVL` | Within 5% tolerance |
| Forfeiture tracking | `ghost_totalForfeited <= matchPool + ghost_totalMatchClaimed` | Exact match |
| Action efficiency | `(totalActions - failedActions) / totalActions` | > 60% |

### Common Debugging Scenarios

**"Vault insolvent" invariant failure:**
`wbtc.balanceOf(vault) < matchPool` — indicates a withdrawal or early redeem returned more WBTC than expected. Check ghost_totalWithdrawn vs actual WBTC flow.

**"Delegation exceeds 10000 BPS" invariant failure:**
Multiple grantors delegated to the same wallet. Check `walletTotalDelegatedBPS()` for agents in the Delegation Grantor range (index 35-44).

**Simulation runs out of gas:**
The `_findOwnedToken` linear scan iterates up to 1000 token IDs. Ensure `gas_limit` is set in `foundry.toml`:
```toml
gas_limit = 1_000_000_000_000
```

**Zero recombinations (RETURN_BTC_TOKEN never fires):**
Check priority ordering in `decide()`. If `WITHDRAW` has higher priority than `RETURN_BTC_TOKEN`, withdrawal preempts recombination every tick. The vBTC Separator archetype should check recombine before withdrawal.

---

## 5. Metrics Interpretation

### Simulation Output Metrics

| Metric | Meaning | Expected Range (521 weeks, seed 42) |
|--------|---------|-------------------------------------|
| Total actions | Agent decisions that produced a non-NONE action | 10,000–16,000 |
| Failed actions | Actions that reverted at the protocol contract | 40–60% of total |
| Total deposited | Cumulative WBTC minted into vaults | ~750M sats |
| Total withdrawn | Cumulative WBTC withdrawn post-vesting | ~180M sats |
| Total forfeited | WBTC forfeited to match pool via early redemption | ~100M sats |
| Total match claimed | WBTC claimed from match pool by vested holders | ~14M sats |
| Delegation grants | Successful wallet/vault delegation grants | 25–35 |
| Delegated withdrawals | WBTC withdrawn by delegates | ~10M sats |
| vBTC separations | Successful `mintBtcToken` calls | 40–55 |
| vBTC recombinations | Successful `returnBtcToken` calls | 25–40 |
| Final TVL | WBTC remaining in vault contract | ~575M sats |
| Final match pool | Unclaimed match pool balance | ~95M sats |

### Failure Rate Benchmarks

| Rate | Assessment | Likely Cause |
|------|-----------|-------------|
| 0–20% | Excellent | Minimal race conditions only |
| 20–40% | Good | Normal cooldown retries + race conditions |
| 40–60% | Acceptable | Known decision logic gaps (current state) |
| 60–80% | Poor | Aggregate portfolio mismatches, missing precondition checks |
| >80% | Broken | Fundamental decision logic error or deployment issue |

---

## 6. Mitigations Applied

### Phase 2: Vault-Specific Portfolio Selection

**Problem:** 70% failure rate from aggregate portfolio checks + `vaultIds[0]` selection.

**Changes:**
- `Portfolio` struct: Added `withdrawableVaultId`, `matchClaimableVaultId`, `unvestedVaultId`, `vestedVaultId`, `anyValidVaultId`, `currentWalletDelegatedBps`
- `_buildPortfolio()`: Vault ownership verification via `ownerOf()`, match claim tracking via `_vaultMatchClaimed`, BPS capacity via `walletTotalDelegatedBPS()`
- `decide()`: All actions target specific eligible vaults
- vBTC lifecycle priority elevated above withdrawal for `VBTC_SEPARATOR` archetype
- Delegation BPS capacity check before granting

**Result:** 70% → 58% failure rate (-37% reduction). vBTC recombinations: 0 → 33. vBTC separations: 20 → 50.

### Remaining Unsolved

- **Race conditions** (~30% of remaining failures): Multiple agents targeting same dormant vault or depleting match pool within a tick. Inherent to sequential execution.
- **Delegation cooldown retries** (~15%): Delegate Withdrawers attempt every rebalance interval but 30-day cooldown limits success to ~monthly.
- **Stale vault ID storage** (~10%): Vault IDs from dormancy claims remain in `_agentVaultIds` storage arrays; skipped by `ownerOf()` check but not pruned.
- **Treasure NFT exhaustion** (~5%): Multi-Vault Accumulators consume all 10 treasures, subsequent mints fail.
