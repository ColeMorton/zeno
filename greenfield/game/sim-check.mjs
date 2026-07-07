// Standalone sanity check: the JS port of ZenoVault math must match the Solidity invariants.
// Run: node sim-check.mjs

const VEST = 1129, WPERIOD = 30, RATE = 0.01;

function assert(c, m) { if (!c) { console.error("FAIL:", m); process.exitCode = 1; } else console.log("ok  ", m); }
const approx = (a, b, e = 1e-9) => Math.abs(a - b) <= e;

// --- Zeno's paradox: 1% withdrawals never deplete, match 0.99^n ---
let c = 1.0;
for (let i = 0; i < 120; i++) c -= c * RATE;
assert(approx(c, Math.pow(0.99, 120), 1e-12), "withdrawal decay equals 0.99^n");
assert(c > 0.29 && c < 0.31, "after 120 periods ~0.30 BTC remains, never zero");

// --- Match pool: forfeit distributes pro-rata via accumulator index, conserved ---
let matchIndex = 0, totalActive = 0;
const v = {}; // id -> {collateral, snap}
function mint(id, amt) { v[id] = { collateral: amt, snap: matchIndex }; totalActive += amt; }
function settle(id) { const x = v[id]; const acc = x.collateral * (matchIndex - x.snap); x.snap = matchIndex; x.collateral += acc; totalActive += acc; return acc; }
function earlyRedeem(id, elapsed) {
  settle(id); const x = v[id]; const col = x.collateral; totalActive -= col;
  const returned = col * elapsed / VEST; const forfeit = col - returned;
  if (forfeit > 0 && totalActive > 0) matchIndex += forfeit / totalActive;
  delete v[id]; return { returned, forfeit };
}
mint("a", 3); mint("b", 1); mint("c", 1);
const { returned, forfeit } = earlyRedeem("a", 500); // a quits at day 500
const gb = settle("b"), gc = settle("c");
assert(approx(gb, gc), "equal-collateral survivors get equal match shares");
assert(approx(gb + gc, forfeit, 1e-9), "sum of match shares equals forfeited amount (conserved)");
assert(approx(v.b.collateral + v.c.collateral, (3 - returned) + 1 + 1 - forfeit + forfeit, 1e-9) ||
       approx(v.b.collateral + v.c.collateral, 2 + forfeit, 1e-9), "survivor collateral == original + forfeit");

// --- vBTC strip: immunized per-vault reserve, minted/burned 1:1, par NAV floor ---
let reserve = 0, supply = 0; // globals: strippedReserve must equal vBTC supply, always
function strip(v, amt) { if (!v.vested) return 0; amt = Math.min(amt, v.c); v.c -= amt; v.r += amt; reserve += amt; supply += amt; return amt; }
function recombine(v, amt) { amt = Math.min(amt, v.r); v.r -= amt; v.c += amt; reserve -= amt; supply -= amt; return amt; }
function withdrawActive(v) { const amt = v.c * RATE; v.c -= amt; return amt; } // 1% of ACTIVE only
const A = { c: 1, r: 0, vested: false };
assert(strip(A, 0.4) === 0 && A.r === 0 && supply === 0, "strip blocked during vesting (StillVesting)");
A.vested = true;
strip(A, 0.4); // fractional, vested vaults only
for (let i = 0; i < 60; i++) withdrawActive(A); // withdrawals draw active collateral only
assert(approx(A.r, 0.4), "reserve immunized: 60 withdrawals never touch stripped collateral");
assert(approx(reserve, supply), "strippedReserve == vBTC supply (par is the NAV floor)");
strip(A, A.c); // strip the rest: fully stripped vault
assert(approx(withdrawActive(A), 0), "fully stripped vault withdraws nothing (no coupon on sold principal)");
// fractional dormancy claims: burn vBTC 1:1 for reserve collateral; the vault survives
let claimedTotal = 0;
function claimDormant(v, amt) { amt = Math.min(amt, v.r); v.r -= amt; reserve -= amt; supply -= amt; claimedTotal += amt; return amt; }
const rBefore = A.r;
claimDormant(A, rBefore * 0.3); claimDormant(A, rBefore * 0.2); // two claimants, partial
assert(approx(claimedTotal, rBefore * 0.5), "fractional dormancy claims pay exactly 1:1");
assert(A.r > 0 && approx(reserve, supply), "vault survives claims; par preserved");
recombine(A, A.r); // owner buys back the float and recombines the remainder
assert(approx(A.r, 0) && approx(reserve, 0) && approx(supply, 0), "full recombination unwinds: reserve and vBTC supply return to zero");


console.log(process.exitCode ? "\nSOME CHECKS FAILED" : "\nALL CHECKS PASSED");
