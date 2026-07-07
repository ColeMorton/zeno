# Zeno Greenfield — BTCNFT Protocol, Redesigned

Ground-up redesign of BTCNFT Protocol isolating the core product. Two contracts, ~330 LOC total, replacing ~2,900 protocol LOC + ~6,900 issuer LOC.

## The core product

**Time as the trust-free averaging mechanism.** Lock any ERC-721 treasure plus BTC collateral for 1129 days, then withdraw 1% of remaining active collateral every 30 days, forever. Percentage-based withdrawal never depletes principal (Zeno's paradox). Early exits return collateral pro-rata to time served; the forfeit rewards remaining holders. Immutable: no owner, no admin, no oracle, no fees, no governance.

## Contracts

| Contract | Purpose |
|---|---|
| `ZenoVault.sol` | ERC-721 vault: mint, withdraw, early-redeem, redeem, match distribution, vBTC stripping, dormancy rescue |
| `VestedBTC.sol` | ERC-20 (8 decimals) principal strip; mint/burn only by vault |

One deployment per collateral token (wBTC, cbBTC, tBTC) — isolated risk, isolated match distribution.

## User journeys

**Holder:** approve treasure + collateral → `mint` → wait 1129 days → `withdraw` monthly forever, or `redeem` for the full remaining collateral + treasure. Exit early via `earlyRedeem` (linear return, treasure burned). Once vested, `strip(id, amount)` to mint fungible vBTC 1:1 against collateral moved into an immunized reserve; `recombine(id, amount)` to burn vBTC and reactivate it, fractionally, at leisure. Stripping is honest bond stripping — vesting-gated (the time lock is the product; stripping must not provide early liquidity against it), and reserve collateral earns no withdrawals until recombined: you cannot sell the principal and keep collecting its coupon.

**Issuer:** deploy any ERC-721 collection as treasure. No protocol registration needed — the vault accepts any ERC-721. Branding, gating, and campaigns live entirely outside the protocol.

**DeFi integrator:** vBTC is a plain ERC-20 — pool it, lend it, wrap it. Backing invariant: `strippedReserve == vbtc.totalSupply()` at all times, so par is the on-chain NAV floor. The market discount below par prices recombination timing and control; the owner-buyback arbitrage (buy discounted vBTC, recombine 1:1) disciplines the float without a peg.

## Design decisions vs original

| Original | Greenfield | Why |
|---|---|---|
| Match pool with snapshot denominator (`_snapshotDenominator`, `matured`, `matchClaimed`) | Synthetix-style accumulator index (`matchIndex`) | Original did not conserve the pool across staggered claims. Accumulator is exactly conserved (fuzz-verified), auto-compounds into collateral. Now adopted by the main protocol too |
| Two bps scales (100000 and 10000) | Single 10000 scale | Readability hazard removed |
| Withdrawal delegation (wallet + vault level, ~300 LOC) | Cut | Automation belongs off-chain or in a wrapper contract holding the vault NFT |
| `HybridVaultNFT` (805 LOC, 90% duplicate) | Cut | Second product line with three inconsistent treatments of the secondary asset |
| `ExpeditionCredits` bootstrap token | Cut | Growth mechanic, not core — and the only admin keys in the original core lived in its whitelist |
| Issuer layer (achievements, auctions, perps, volatility pools, pixel art, dashboards — ~6,900 LOC) | Cut | Any ERC-721 works as treasure; distribution/gamification is composable on top, not in the protocol |
| Dormancy claim: burn full original amount, claimer takes everything, vault burned | Fractional: burn any vBTC amount for reserve 1:1; vault, treasure, and active collateral stay with the owner | All-or-nothing burns blunt the arbitrage and strand positions; fractional claims make dormancy the perpetual's continuous maturity event |
| `redeem()` missing | Post-vest full redemption path | Vested holders could only exit 1%/month |

**vBTC as an immunized principal strip (the real fix).** The original minted vBTC in fixed BTC units, 1:1 on a vault's full collateral, while the owner kept withdrawing that same collateral. That over-issues: total vBTC exceeds total backing, the discount is path-dependent on seller behavior (moral hazard), and the shortfall was convertible to cross-vault theft via fungibility.

Greenfield makes stripping honest STRIPS-style separation:

- `strip(id, amount)`: move `amount` from a vested vault's active collateral into an immunized per-vault reserve, mint vBTC 1:1. Fractional, repeatable.
- `withdraw`: 1% of ACTIVE collateral only. The reserve is untouchable — coupon cannot erode principal.
- `recombine(id, amount)` / `claimDormant(id, amount)`: burn vBTC, release reserve 1:1.
- `earlyRedeem` / `redeem`: require zero outstanding reserve — recombination before redemption.

Hard invariant: `strippedReserve == vbtc.totalSupply()` (fuzz-verified). Every vBTC is fully reserved, so cross-vault theft is structurally impossible and the token has a par NAV floor. No pool-rate math, no share pricing, no rounding directionality to reason about — 1:1 both ways.

## Mechanics

- **Withdraw:** 1% of current active collateral, first eligible exactly at day 1129, then every 30 days. Missed periods are not banked — matches the `0.99^n` decay table in the original guide.
- **Match index:** on forfeit, `matchIndex += forfeited * 1e18 / totalActiveCollateral`. Any vault's pending share = `activeCollateral * Δindex / 1e18`, folded into collateral on any interaction or via public `settleMatch`. Exactly conserved (dust ≤ a few sats favors the contract). Reserve does not accrue match — it is principal, not a participating stake.
- **Last-holder exit:** if no other active vaults exist, early redeemer receives full collateral — no one left to reward.
- **Dormancy:** reserve outstanding + owner holds less vBTC than the reserve + 1129 days no activity → anyone `pokeDormant` → 30-day grace (owner can `proveActivity` or transfer) → any vBTC holder burns any amount for reserve collateral 1:1. The vault survives; reserve at zero ends eligibility.

## Verification

```bash
cd greenfield && forge test
```

Full lifecycle, cooldowns, Zeno decay over 120 periods, staggered match-claim conservation, fractional strip/recombine round-trips, reserve immunization, dormancy state machine, access control, plus fuzz invariants: contract balance covers active + reserve, and `strippedReserve == vbtc.totalSupply()` always.
