# Simulation Diagnostics

## Failure Taxonomy

The swarm simulation distinguishes between **expected failures** (normal protocol behavior under adversarial or race conditions) and **unexpected failures** (genuine bugs or protocol violations).

### Expected Failures

These reverts are part of healthy protocol operation. Agents encounter them due to cooldowns, race conditions, or one-shot semantics.

| Error | Selector | Context | Rationale |
|-------|----------|---------|-----------|
| `WithdrawalTooSoon(uint256 tokenId, uint256 nextAllowed)` | `0x4118819e` | `withdraw()` | Cooldown retry. Agents may attempt withdrawal before the 5-tick cooldown expires. |
| `AlreadyClaimed(uint256 tokenId)` | `0xb3167bfa` | `claimMatch()` | Race condition. Another agent claimed the match pool share for this vault in the same tick. |
| `AlreadyPoked(uint256 tokenId)` | `0x28630f73` | `pokeDormant()` | Race condition. Another agent already poked this dormant vault in the same tick. |
| `NoPoolAvailable()` | `0xc3230ab1` | `claimMatch()` | Pool drained. The match pool has been fully distributed; no claimable amount remains. |
| `StillVesting(uint256 tokenId)` | `0xa4395c9e` | `withdraw()` | Pre-vesting attempt. Agent tries to withdraw before the 1129-day vesting period completes. |
| `RatioBoundsExceeded(uint256 ratioBefore, uint256 ratioAfter)` | `0x8df4b45e` | `exchange()` / `add_liquidity()` | Swap or liquidity add would push the vBTC/WBTC ratio outside [0.5, 1.0]. Expected when agents race toward the boundary. |

### Unexpected Failures

Any revert that does not match the expected error selectors above is classified as unexpected. Common categories include:

- **Access control violations**: `NotTokenOwner`, `NotVaultOwner`, `NotPositionOwner`
- **State invariants violated**: `ZeroCollateral`, `InsufficientBtcToken`, `BtcTokenRequired`
- **Invalid operations**: `TokenDoesNotExist`, `PositionNotFound`, `PositionAlreadyClosed`
- **Oracle / settlement errors**: `OracleStale`, `InvalidPriceRatio`, `SettlementNotDue`
- **Dormancy errors on non-dormancy actions**: `NotDormantEligible`, `NotClaimable`
- **Generic reverts**: Empty revert data, panic codes, arithmetic overflow

### Invariant

```
ghost_totalFailedActions == ghost_expectedFailures + ghost_unexpectedFailures
```

A healthy simulation run should show `unexpectedFailures == 0`. If `unexpectedFailures > 0`, inspect the action log to identify which agents and actions produced the reverts.

## Error Selector Reference

| Error Signature | Selector |
|-----------------|----------|
| `WithdrawalTooSoon(uint256,uint256)` | `0x4118819e` |
| `AlreadyClaimed(uint256)` | `0xb3167bfa` |
| `AlreadyPoked(uint256)` | `0x28630f73` |
| `NoPoolAvailable()` | `0xc3230ab1` |
| `StillVesting(uint256)` | `0xa4395c9e` |
| `NotTokenOwner(uint256)` | `0x30cd5e3b` |
| `ZeroCollateral()` | `0x94eb6b78` |
| `BtcTokenAlreadyMinted(uint256)` | `0x8e392727` |
| `BtcTokenRequired(uint256)` | `0x0e5f2b71` |
| `InsufficientBtcToken(uint256,uint256)` | `0x6c4a67f3` |
| `NotVested(uint256)` | `0x10f0805a` |
| `InvalidCollateralToken(address)` | `0xd739757b` |
| `TokenDoesNotExist(uint256)` | `0xceea21b6` |
| `NotDormantEligible(uint256)` | `0x0e7c1c12` |
| `NotClaimable(uint256)` | `0x27a55d88` |
| `ZeroAddress()` | `0xd92e233d` |
| `CannotDelegateSelf()` | `0x19b99154` |
| `InvalidPercentage(uint256)` | `0x88d17d6d` |
| `ExceedsDelegationLimit()` | `0x0c5d1aef` |
| `DelegateNotActive(address,address)` | `0x9c867a8a` |
| `NotActiveDelegate(uint256,address)` | `0x8d0e6a1d` |
| `WithdrawalPeriodNotMet(uint256,address)` | `0x7a0e0c8e` |
| `ExceedsVaultDelegationLimit(uint256)` | `0x6b5b8e0a` |
| `VaultDelegateNotActive(uint256,address)` | `0x4b3a8e7c` |

## Diagnostic Checklist

When investigating unexpected failures:

1. Check `reports/agent_actions.csv` for `success=false` rows
2. Correlate the tick, agentId, and actionName with the failure
3. Verify the agent's vault/position state at that tick
4. Confirm the revert selector matches an unexpected error
5. If `StillVesting` appears on a non-WITHDRAW action, flag as bug in agent decision logic
6. If `unexpectedFailures > 0` and the error is `WithdrawalTooSoon` or similar, the `_countFailure` classifier may need updating
