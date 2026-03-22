# Bootstrap Phase

> **Version:** 2.0
> **Status:** Final
> **Last Updated:** 2026-03-22

---

## Definition

The **Bootstrap** phase is the first 1129 days of the BTCNFT Protocol's existence (days 0–1128), from deployment until the first vaults complete vesting. During Bootstrap, no vestedBTC exists anywhere in the system.

---

## Characteristics

| Property | State |
|----------|-------|
| vestedBTC in circulation | None — no vault has completed vesting, `mintBtcToken()` cannot be called |
| Expedition Credits (xBTC) | Active — minted 1:1 with collateral at vault creation |
| Curve pool liquidity | xBTC/WBTC pool active (vestedBTC pool seeded post-Bootstrap) |
| DeFi composability | Enabled via xBTC — LP, lending, leverage, volatility products |
| Match pool claims | Unavailable — no vault has completed vesting to claim |
| Match pool accumulation | Active — early redeemer forfeitures accumulate |
| Governance model | Founder-led via Transitional Voting Power (100% → 0%) |
| The Ascent | Chapters 1–12 run during this period |

---

## Holder Actions

### Available

| Action | Notes |
|--------|-------|
| Transfer Vault NFT | Full ERC-998 transferability |
| Early redeem | Linear forfeit: `returned = (collateral × elapsed) / 1129 days` |
| Receive xBTC | Minted 1:1 with collateral at vault creation (single-collateral only) |
| DeFi via xBTC | LP, swap, lend, leverage, volatility — within protocol infrastructure |

### Unavailable

| Action | Reason |
|--------|--------|
| Withdraw BTC | Reverts with `StillVesting(tokenId)` |
| Separate to vestedBTC | Requires completed vesting |
| Claim match pool | Requires completed vesting |
| Delegate withdrawals | Requires completed vesting |

---

## Governance During Bootstrap

The founder holds Transitional Voting Power that decays linearly over 1129 days:

```
transitionalPower = totalProtocolBTC × (1 - daysSinceLaunch / 1129)
```

| Day | Founder Transitional Power |
|-----|---------------------------|
| 0 | 100% of total protocol BTC |
| 564 | 50% |
| 1129 | 0% (pure organic governance) |

This ensures founder stewardship during the period when no vestedBTC holders exist to participate in governance. See [Governance Specification](../../../../docs/dao/Governance_Specification.md).

---

## Expedition Credits (xBTC)

During Bootstrap, holders receive **Expedition Credits (xBTC)** — a utility token enabling DeFi participation before vestedBTC exists.

### Mechanics

| Property | Value |
|----------|-------|
| Token name | Expedition Credits |
| Symbol | xBTC |
| Decimals | 8 |
| Minting | 1:1 with collateral at single-collateral vault creation |
| Supply model | Fixed per-mint (no inflation, no decay) |
| Transfer model | ERC-20 with contract whitelist (ecosystem-scoped) |
| Backing | None (utility token, not a collateral claim) |
| Hybrid vaults | Not eligible |
| Early redemption | xBTC kept (no clawback) |

### DeFi Infrastructure

Protocol-deployed infrastructure accepts xBTC during Bootstrap:

| Product | xBTC Role |
|---------|-----------|
| Curve CryptoSwap V2 | xBTC/WBTC pair |
| Yield vault (yxBTC) | xBTC → Curve LP → yield |
| Capped leverage vaults | Bull/Bear on xBTC/WBTC ratio |
| Volatility pool | xBTC price observations |

### Transfer Restrictions

xBTC is ecosystem-scoped — freely transferable between wallets and whitelisted protocol contracts, but not listable on external DEXs.

### Post-Bootstrap

- xBTC minting stops after day 1129
- Existing tokens remain valid but DeFi infrastructure migrates to vBTC
- Bootstrap DeFi participation history unlocks exclusive **DeFi Pioneer** achievements (soulbound, permanently scarce)

---

## Transition

Bootstrap ends when the first vaults reach day 1129. This unlocks:

1. **vestedBTC minting** — `mintBtcToken()` becomes callable
2. **Withdrawals** — 1%/month perpetual withdrawals begin
3. **Match pool claims** — vested holders claim pro-rata share of accumulated forfeitures
4. **Delegation** — withdrawal rights can be delegated
5. **Curve pool seeding** — issuers can separate vault collateral to seed vestedBTC/BTC liquidity
6. **DeFi composability** — lending, LP, derivatives become possible

---

## Economic Dynamics

During Bootstrap, the match pool grows from early redeemer forfeitures with no outflows (no one can claim yet). This creates a first-mover advantage for the initial cohort: holders who vault on day 0 and complete the full 1129 days receive the largest possible share of accumulated match pool forfeitures.

The forfeit schedule is linear — exiting at day 365 returns 32.3% and forfeits 67.7%. This creates a strong incentive gradient favoring patience, particularly in the early protocol when the match pool accumulation rate is highest relative to remaining holders.
