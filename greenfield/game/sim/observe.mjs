// Zeno Observe Harness — headless AI-only simulation + product telemetry.
//
// Runs the real game logic (loaded from ../index.html) with every keeper on a
// policy, no human, no render. Instruments every economic action, sweeps N seeds,
// and prints a product report: feature adoption, balance, flywheel health, the
// vBTC economy, decision density, and pacing. This is a product-owner instrument,
// not a test — it answers "which mechanics are alive, is it balanced, where are the
// dead zones" so we know what to build, cut, or surface.
//
// Usage: node sim/observe.mjs [seeds]           (default 40 seeds)
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
const __dir = path.dirname(fileURLToPath(import.meta.url));

// ---- minimal DOM stubs so the game's presentation calls no-op ----
const ctxStub=new Proxy({},{get:(t,k)=>{if(k==='createLinearGradient'||k==='createRadialGradient')return ()=>({addColorStop(){}});return ()=>{}}});
function fakeEl(){return new Proxy(function(){},{get(t,k){
  if(k==='style')return new Proxy({},{get:()=>'',set:()=>true});
  if(k==='classList')return {add(){},remove(){},toggle(){},contains(){return false}};
  if(k==='children')return [];if(k==='getContext')return ()=>ctxStub;
  if(k==='getBoundingClientRect')return ()=>({width:900,height:600,top:0,left:0});
  if(k==='appendChild'||k==='addEventListener'||k==='remove')return ()=>{};
  if(k==='querySelector')return ()=>fakeEl();if(k==='querySelectorAll')return ()=>[];
  if(k==='textContent'||k==='innerHTML'||k==='value')return '';
  if(k==='width'||k==='height')return 900;if(k==='disabled')return false;
  return fakeEl();},set(){return true},apply(){return fakeEl()}});}
global.document={getElementById:()=>fakeEl(),createElement:()=>fakeEl(),querySelector:()=>fakeEl(),querySelectorAll:()=>[],addEventListener:()=>{},readyState:'complete'};
global.window={addEventListener:()=>{},AudioContext:undefined,webkitAudioContext:undefined,devicePixelRatio:1};
global.performance={now:()=>0};global.requestAnimationFrame=()=>0;global.devicePixelRatio=1;global.setTimeout=()=>0;global.clearTimeout=()=>{};

// ---- load the real game logic once ----
const html=fs.readFileSync(path.join(__dir,'..','index.html'),'utf8');
let src=html.match(/<script>([\s\S]*)<\/script>/)[1];
src+="\n;globalThis.__game=game;globalThis.__TIERS=TIERS;";
try{ new Function(src)(); }catch(e){ console.error("engine load failed:",e.message); process.exit(1); }
const game=globalThis.__game;

// ---- deterministic RNG for the observed "explorer" agent (the human slot) ----
function lcg(seed){let s=seed>>>0||1;return()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296;};}

const ACTIONS=['mint','withdraw','earlyRedeem','strip','recombine','redeem','claimDormant','buyVbtc','sellVbtc','stakeYv','betVol','expedition'];

// Explorer policy: a "curious player" that exercises the WHOLE feature surface so
// the harness can measure each mechanic's reachability and effect. The 5 bots keep
// their existing archetype heuristics — the gap between the two IS a product signal.
function explorer(g,rng){
  const you=g.you,W=g.W;
  // draw from any ready vault
  for(const v of [...you.vaults]) if(W.canWithdraw(v)&&rng()<0.5){ g.actWithdraw(v); return; }
  // send a vault on an expedition when seas are calm-ish
  if(g._calm()>0.5) for(const v of you.vaults) if(W.canExpedition(v)&&rng()<0.03){ g.actExpedition(v); return; }
  // strip a vested vault for liquidity (fractional, 1:1 — blocked during vesting)
  for(const v of you.vaults) if(W.vested(v)&&v.collateral>0.2&&v.reserve<=0&&rng()<0.03){ g.actStrip(v); return; }
  // recombine a stripped vault (burn vBTC 1:1, closes the liquidity loop)
  for(const v of you.vaults) if(v.reserve>0&&you.vbtc>0&&rng()<0.02){ g.actRecombine(v); return; }
  // use the Deeps
  if(you.vbtc>0.4&&rng()<0.03){ g.actStakeYv(you.vbtc*0.4); return; }
  if(you.vbtc>0.3&&rng()<0.025){ g.actBet(rng()<0.5?'long':'short', you.vbtc*0.4); return; }
  if(you.vbtc>0.5&&rng()<0.02){ g.actSellVbtc(you.vbtc*0.3); return; }
  if(you.btc>1&&rng()<0.02){ g.actBuyVbtc(0.6); return; }
  // raid a rival's abandoned vault if we can afford it
  for(const b of g.bots) for(const v of b.vaults) if(W.canClaim(v)&&you.vbtc>0&&rng()<0.5){ g.actRaid(v); return; }
  // buy a treasure occasionally, then mint
  if(you.btc>2&&you.treasures.length<2&&g.bazaar.length&&rng()<0.03){ g.actBuyTreasure(0); return; }
  if(you.treasures.length&&you.btc>0.6&&you.vaults.length<4&&rng()<0.03){ g.actMint(Math.min(you.btc*0.5,2), you.treasures[0], 1); return; }
}

function runSeed(seedStr,agentRngSeed){
  game.setup(seedStr,0.55,0.75);
  const W=game.W;
  // instrument: wrap every economic World method to log an event {act,who,day}
  const ev=[]; const byPlayer={};
  const wrap=(name)=>{const orig=W[name].bind(W);W[name]=(...a)=>{const before=W.vbtcSupply;const r=orig(...a);
    // who = the acting player: first arg that is a player, else infer from vault owner
    let who=null;for(const x of a){if(x&&x.name&&x.vaults)who=x;} if(!who&&a[0]&&a[0].owner)who=a[0].owner;
    // only log when the action actually did something
    const did=(name==='mint'&&r)||(name==='expedition'&&r)||(name!=='mint'&&name!=='expedition'&&(typeof r==='number'?r>1e-9:(r&&r.forf!==undefined)));
    if(did){ev.push({act:name,who:who?who.name:'?',day:game.day});byPlayer[who?who.name:'?']=(byPlayer[who?who.name:'?']||0)+1;}
    return r;};};
  ACTIONS.forEach(wrap);
  let forfeited=0; const oER=W.earlyRedeem.bind(W); W.earlyRedeem=(v)=>{const r=oER(v);if(r)forfeited+=r.forf;return r;};
  let mktLo=1,mktHi=1;

  const arng=lcg(agentRngSeed);
  let guard=0;
  while(!game.ended && game.day<1600 && guard++<1600){
    game.tickDay();
    explorer(game,arng);
    const p=W.mktPrice(); if(p<mktLo)mktLo=p; if(p>mktHi)mktHi=p;
  }
  const players=[...W.players].sort((a,b)=>W.netWorthBtc(b)-W.netWorthBtc(a));
  return {ev,byPlayer,forfeited,mktLo,mktHi,
    ranks:players.map((p,i)=>({name:p.name,arch:p.archetype||'explorer',rank:i+1,nw:W.netWorthBtc(p),matchTaken:p.matchTaken})),
    finalIndex:W.matchIndex, finalSupply:W.vbtcSupply, finalRate:W.poolRate(),
    prestige:game.prestige(), achievements:game.you.achievements.size,
    totalActive:W.totalActive, days:game.day};
}

// ---- run the sweep ----
const N=parseInt(process.argv[2]||'40');
const runs=[];
for(let i=0;i<N;i++) runs.push(runSeed('seed-'+i, 0x9e37+i*2654435761));

// ---- aggregate ----
const mean=a=>a.reduce((x,y)=>x+y,0)/a.length;
const sum=a=>a.reduce((x,y)=>x+y,0);
const pct=(n,d)=>(100*n/d).toFixed(0)+'%';
const fmt=n=>n.toFixed(2);

// action totals
const actTotals={}; ACTIONS.forEach(a=>actTotals[a]=0);
const actAdopt={}; ACTIONS.forEach(a=>actAdopt[a]=0);
// pacing: 4 quarters of vesting + post
const pace=[0,0,0,0,0];
for(const r of runs){const seen=new Set();
  for(const e of r.ev){actTotals[e.act]++;seen.add(e.act);
    const q=e.day>=1129?4:Math.min(3,Math.floor(e.day/(1129/4)));pace[q]++;}
  for(const a of seen)actAdopt[a]++;}
const totalActions=sum(Object.values(actTotals));

// balance: mean rank + win rate per archetype
const archStats={};
for(const r of runs) for(const p of r.ranks){const s=archStats[p.arch]||(archStats[p.arch]={ranks:[],wins:0,nw:[]});s.ranks.push(p.rank);if(p.rank===1)s.wins++;s.nw.push(p.nw);}

// flywheel
const matchRecvFrac=mean(runs.map(r=>r.ranks.filter(p=>p.matchTaken>0.001).length/r.ranks.length));
const forfeitVsActive=mean(runs.map(r=>r.forfeited/(r.totalActive+r.forfeited+1e-9)));

// vBTC economy
const mktRange=`${fmt(mean(runs.map(r=>r.mktLo)))}–${fmt(mean(runs.map(r=>r.mktHi)))}`;
const vbtcVel = mean(runs.map(r=>(r.byPlayer && 0))); // placeholder
const deepsUses=mean(runs.map(r=>r.ev.filter(e=>['buyVbtc','sellVbtc','stakeYv','betVol'].includes(e.act)).length));

// decision density: actions per agent per voyage-year
const yrs=1129/365, agents=6;
const density=mean(runs.map(r=>r.ev.length))/agents/yrs;

// outcome spread — is rank driven by archetype (skill) or noise?
const explorerRanks=runs.map(r=>r.ranks.find(p=>p.arch==='explorer').rank);

// ---- report ----
const L=[];
L.push('════════════════════════════════════════════════════════════');
L.push(`  ZENO · OBSERVE HARNESS — product report   (${N} AI-only voyages)`);
L.push('════════════════════════════════════════════════════════════');
L.push('');
L.push('FEATURE ADOPTION  (avg uses/voyage · % of voyages any agent used it)');
for(const a of ACTIONS){const u=(actTotals[a]/N).toFixed(1).padStart(6);const ad=pct(actAdopt[a],N).padStart(5);
  const flag=actTotals[a]===0?'  ✗ unreached':(actTotals[a]/N<0.5?'  ⚠ rare':'');
  L.push(`  ${a.padEnd(13)} ${u}   ${ad}${flag}`);}
L.push(`  ${'TOTAL'.padEnd(13)} ${(totalActions/N).toFixed(1).padStart(6)}`);
L.push('');
L.push('BALANCE  (mean finish rank of 6 · win-rate · mean net-worth ₿)');
const order=Object.entries(archStats).sort((a,b)=>mean(a[1].ranks)-mean(b[1].ranks));
for(const [arch,s] of order){L.push(`  ${arch.padEnd(11)} rank ${fmt(mean(s.ranks))}   win ${pct(s.wins,N).padStart(4)}   nw ${fmt(mean(s.nw)).padStart(6)}`);}
L.push('');
L.push('FLYWHEEL (match pool)');
L.push(`  agents ever rewarded ....... ${pct(matchRecvFrac*runs.length, runs.length).padStart(5)}  (share of keepers who got match rain)`);
L.push(`  forfeit recirculation ...... ${(forfeitVsActive*100).toFixed(1)}%  (forfeited ₿ vs active collateral)`);
L.push(`  final match index .......... ${fmt(mean(runs.map(r=>r.finalIndex)))}`);
L.push('');
L.push('vBTC ECONOMY (the Deeps)');
L.push(`  market price range ......... ${mktRange} ₿/vBTC`);
L.push(`  deeps interactions/voyage .. ${deepsUses.toFixed(1)}  (market+yield+storm)`);
L.push(`  final vBTC supply .......... ${fmt(mean(runs.map(r=>r.finalSupply)))}  at par (backed 1:1 by immunized reserve)`);
L.push('');
L.push('ENGAGEMENT & PACING');
L.push(`  decision density ........... ${density.toFixed(1)} actions / agent / voyage-year`);
L.push(`  actions by voyage phase ....`);
const paceLabels=['Q1 (0–282d)','Q2 (282–564)','Q3 (564–846)','Q4 (846–1129)','post-vest'];
const paceMax=Math.max(...pace);
pace.forEach((v,i)=>{const bar='█'.repeat(Math.round(24*v/paceMax));L.push(`    ${paceLabels[i].padEnd(14)} ${bar} ${(v/N).toFixed(1)}`);});
L.push(`  explorer mean finish ....... ${fmt(mean(explorerRanks))} of 6  (full-feature agent vs heuristic bots)`);
L.push(`  collection prestige (you) .. ${fmt(mean(runs.map(r=>r.prestige)))}  · ${fmt(mean(runs.map(r=>r.achievements)))}/8 deeds`);
L.push('');
L.push('── PRODUCT SIGNALS ──────────────────────────────────────────');
const insights=[];
for(const a of ['buyVbtc','sellVbtc','stakeYv','betVol','claimDormant','recombine']){
  if(actTotals[a]===0) insights.push(`✗ "${a}" stayed at zero even with the full-feature explorer — its precondition never arises in normal play (e.g. dormancy needs an abandoned+inactive owner). Confirm the path is reachable, then decide: surface it in the UI, or accept it as a rare edge mechanic.`);}
const worst=order[order.length-1], best=order[0];
if(mean(best[1].ranks)<2.2) insights.push(`⚠ "${best[0]}" dominates (mean rank ${fmt(mean(best[1].ranks))}, win ${pct(best[1].wins,N)}). Strategy space may be too solvable — patient/whale play likely trivially best. Consider a mechanic that punishes pure passivity.`);
if(density<4) insights.push(`⚠ Decision density ${density.toFixed(1)}/agent/yr is low — long stretches of nothing. Add mid-vesting decisions (the Q2–Q3 pacing trough below) or shorten dead time.`);
if(pace[1]+pace[2] < pace[0]*0.6) insights.push(`⚠ Mid-voyage (Q2–Q3) is a dead zone vs Q1. The vesting middle needs a reason to act — events, deeps nudges, or rival dynamics.`);
if(matchRecvFrac<0.5) insights.push(`⚠ Only ${pct(matchRecvFrac*100,100)} of keepers ever receive match rain — the flywheel's payoff is concentrated, not broadly felt.`);
if(!insights.length) insights.push('No red flags at this sample — widen the sweep and add adversarial agents.');
insights.forEach((s,i)=>L.push(`  ${i+1}. ${s}`));
L.push('════════════════════════════════════════════════════════════');
const report=L.join('\n');
console.log(report);
fs.writeFileSync(path.join(__dir,'last-report.txt'),report);
