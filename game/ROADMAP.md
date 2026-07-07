# ZENO://THE GAME — Production DAPP Roadmap

## Current State (baseline)

Two files, no build step, no runtime dependencies (viem lazy-loaded from CDN only when CHAIN MODE activates):

| Asset | What it is |
|---|---|
| `index.html` (2373 lines) | Engine + UI + chain bridge + LLM brains + 3 browser self-test suites |
| `tutorial.js` (747 lines) | Training-protocol engine, shares game globals |

**Strengths worth preserving**
- Deterministic seeded engine whose math mirrors the real contracts (`VaultMath.sol` constants, matchIndex accumulator, strip/recombine 1:1, dormancy lifecycle). The sim IS a faithful protocol model — verified by conservation and reserve==supply invariants in `?test=1`.
- Three fully-mocked self-test suites (core, LLM plumbing, chain bridge with `cast`-verified calldata vectors). Zero network in tests.
- Clean protocol-op layer (`mintVault`/`doStrip`/`doClaimDormant`…) already separated from rendering.
- Chain bridge proves the mirror concept end-to-end against real `VaultNFT.sol` on Anvil.

**Production blockers**
1. **Time.** Game runs 1 s = 1 week via `evm_increaseTime`. Impossible on any public chain. This is the defining design constraint, not an implementation detail.
2. **Architecture.** One `<script>` block, globals shared with tutorial.js, tests only runnable by loading URLs in a browser. No CI, no types, no modules.
3. **Secrets.** OpenRouter key in localStorage, spent client-side. Anvil well-known dev keys wired into flow. Fine for sandbox; disqualifying for production.
4. **Trust.** Single-player, all state client-side. Any leaderboard/reward is trivially forgeable.
5. **Chain plumbing.** Hand-precomputed 4-byte selectors and a hand-rolled ABI word codec — correct today, silently wrong after any contract change.

---

## Phase 0 — Product Definition (the fork everything hangs on)

Decide what "production DAPP" means. Three coherent shapes; they lead to different Phase 3+:

- **A. Protocol on-ramp** (recommended default): the game stays a client-side deterministic sim — the funnel and teaching layer for the real protocol. On-chain surface = session results: achievements minted via `AchievementMinter`, trophy `TreasureNFT`s, verifiable leaderboard. Cheapest, no new audited contracts, reuses issuer layer as-is.
- **B. On-chain arena**: separate arena deployment of the protocol with scaled time constants (1129 days → 1129 minutes) on an L2/testnet. Real txs are the gameplay. Requires new contract variants + audit + gas UX.
- **C. Protocol dashboard**: game engine becomes the visualization layer over real mainnet vaults; the "game" is the actual protocol position. Different product entirely.

Deliverable: written decision + success metrics. Everything below assumes **A**, with B as an optional later phase.

## Phase 1 — Codebase Industrialization

Goal: same game, real engineering substrate. No feature work.

- Extract from `index.html` into modules under `game/src/`: `engine/` (pure, deterministic, DOM-free: protocol ops, tick, price model, bots, hive), `ui/` (rendering, modals, chart, sfx), `chain/` (bridge), `llm/` (brains). Strict SOC — engine must run in Node with no browser.
- Vite + TypeScript. Type the state (`Session`, `Vault`, `Actor`) — the invariants already documented in comments become compiler-checked.
- Port the three `?test=` suites to Vitest; run in CI on every push. The conservation/reserve/horizon invariants are the regression net for the whole refactor — port them FIRST, then refactor until green.
- Keep the zero-backend, static-hosting deployability. Output is still a static bundle.
- Tutorial.js consumes the engine via imports, not shared globals.

Exit criteria: `npm test` green in CI; game byte-identical in behavior (same seed → same session).

## Phase 2 — Chain Layer Hardening

Goal: the bridge stops being a demo.

- Generate typed ABIs from Foundry artifacts (`wagmi` CLI / viem `getContract`) — delete `FN` selector table, `word()` codec, and `ERRS` map; decode custom errors from the real ABI.
- Proper wallet layer: EIP-6963 discovery, connect/disconnect UX, chain-switch prompts. Anvil dev-key path survives only behind an explicit dev flag.
- Deploy protocol contracts to a public testnet; CHAIN MODE targets Anvil *or* testnet (chainId allowlist replaces the 31337 hard-guard, mainnet still refused).
- Tx lifecycle UX: pending/confirmed/reverted states surfaced per action (queue already exists — give it UI).
- Contract-change safety: CI job that regenerates ABIs and fails on drift between `contracts/` artifacts and the game bundle.

## Phase 3 — On-Chain Settlement (shape A's core)

Goal: sessions produce verifiable on-chain outcomes without putting gameplay on-chain.

- **Deterministic replay as proof**: a session = (seed, config, player action log). Engine is pure (Phase 1), so a verifier replays the log and confirms the final score. This is the anti-cheat primitive — no trusted client.
- Settlement service (first backend component): accepts session proofs, replays server-side, then mints achievements through `AchievementMinter` / trophy NFTs to the player's address.
- Verifiable leaderboard keyed to addresses, backed by replayed-and-verified sessions only.
- LLM proxy moves server-side in the same service: OpenRouter key off the client, per-user rate limits, cost caps.

## Phase 4 — Multiplayer & Live Economy

Goal: the table stops being bots-only.

- Shared sessions: same seed + synchronized tick via a session server; human rivals occupy bot slots. Deterministic engine makes state sync cheap (broadcast actions, not state).
- Tournaments/seasons with on-chain trophies (issuer layer already has the primitives: achievements, tiers, badges).
- Spectator mode from the action log (free — it's a replay).
- Optional Phase-0-B unlock: scaled-time arena contracts on an L2 for players who want real-money gameplay. New audit scope; only if metrics justify.

## Phase 5 — Production Hardening & Launch

- Security: external audit of any new contract surface (settlement minter roles, arena variants); dependency and supply-chain review (pin viem, no CDN imports in prod bundle).
- Ops: static hosting + CDN for the client; monitoring/alerting on the settlement service; error tracking in-client.
- Regulatory review if any real-value path exists (real BTC collateral + game mechanics = scrutiny; shape A with testnet-only chain mode minimizes this).
- Progressive rollout: sandbox (today) → testnet settlement → mainnet achievement minting.

---

## Sequencing Logic

Phase 1 is prerequisite to everything (purity enables replay-proofs, types enable ABI safety, CI enables refactors). Phase 2 and Phase 3's settlement service are independent and can run in parallel after Phase 1. Phase 4 needs 3 (verified sessions before multiplayer rewards). Phase 0 costs nothing and de-risks all of it — do it first.
