'use strict';
/* ============================================================
   ZENO TRAINING PROTOCOL — tutorial engine + scenarios.
   Classic script loaded after the game script: shares its
   top-level bindings (S, ui, P, ARCH, tick, mintVault, …).
   ============================================================ */

const TUT = {
  active:null, step:-1, ctx:null, failedMsg:null, pollIv:null, testMode:false,
  progress:(()=>{ try{ const p=JSON.parse(localStorage.getItem('zeno_tut')||'{}');
    p.done=p.done||{}; return p; }catch(e){ return {done:{}}; } })(),
};
TUT.saveP=()=>{ try{ localStorage.setItem('zeno_tut',JSON.stringify(TUT.progress)); }catch(e){} };

/* ---------- css + dom ---------- */
document.head.insertAdjacentHTML('beforeend',`<style>
.tutlock{pointer-events:none!important;opacity:.35!important;filter:grayscale(.6)}
#tutSpot{position:fixed;z-index:84;border:1px solid var(--gold);border-radius:8px;pointer-events:none;
  box-shadow:0 0 0 9999px #020409b0,0 0 22px #ffc24755;transition:all .25s ease}
#tutBox{position:fixed;z-index:86;width:min(560px,92vw);left:50%;transform:translateX(-50%);bottom:302px;
  background:var(--panel);border:1px solid var(--gold);border-radius:9px;padding:13px 17px;
  box-shadow:0 0 30px #ffc24726;font-size:12px;line-height:1.65;color:var(--ice)}
#tutBox.top{bottom:auto;top:62px}
#tutBox b{color:var(--gold)} #tutBox .c{color:var(--cyan)} #tutBox .m{color:var(--mag)}
.tut-ttl{font-size:10px;letter-spacing:.26em;color:var(--gold);text-transform:uppercase;margin-bottom:7px;
  display:flex;justify-content:space-between}
.tut-ttl .who{color:var(--mute2);letter-spacing:.1em}
.tut-obj{margin-top:9px;padding:7px 10px;border:1px dashed var(--cyan-dim);border-radius:6px;color:var(--cyan);
  font-size:11px;letter-spacing:.04em}
.tut-obj::before{content:"◇ OBJECTIVE — ";color:var(--mute)}
.tut-btns{display:flex;gap:8px;margin-top:11px;align-items:center}
.tut-btns .n{color:var(--mute2);font-size:10px}
#tutFail{color:var(--red);letter-spacing:.1em;margin-top:8px;font-size:11px}
#tutMenu .tut-sec{font-size:10px;letter-spacing:.24em;color:var(--mute);text-transform:uppercase;margin:16px 0 8px}
.tut-cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:9px}
.tut-card{border:1px solid var(--line2);border-radius:8px;padding:11px 13px;cursor:pointer;transition:all .13s;
  background:var(--bg2)}
.tut-card:hover:not(.locked){border-color:var(--gold);box-shadow:0 0 12px #ffc24722}
.tut-card.locked{opacity:.38;cursor:default}
.tut-card.done{border-color:var(--grn)}
.tut-card .tc-t{display:flex;justify-content:space-between;font-size:12px;letter-spacing:.08em;margin-bottom:4px}
.tut-card .tc-t b{color:var(--ice)}
.tut-card .st{font-size:9px;letter-spacing:.14em}
.tut-card.done .st{color:var(--grn)} .tut-card.ready .st{color:var(--gold)} .tut-card.locked .st{color:var(--mute2)}
.tut-card small{color:var(--mute);font-size:10px;line-height:1.5;display:block}
</style>`);

document.body.insertAdjacentHTML('beforeend',`
<div id="tutSpot" class="hidden"></div>
<div id="tutBox" class="hidden">
  <div class="tut-ttl"><span id="tutTtl"></span><span class="who">OPERATOR//</span></div>
  <div id="tutSay"></div>
  <div class="tut-obj hidden" id="tutObj"><span id="tutObjTxt"></span></div>
  <div id="tutFail" class="hidden"></div>
  <div class="tut-btns"><span class="n" id="tutStepN"></span><span style="flex:1"></span>
    <button id="tutExitB">EXIT</button>
    <button id="tutRetryB" class="danger hidden">RETRY</button>
    <button id="tutNextB" class="gold">CONTINUE ▸</button></div>
</div>
<div id="tutMenu" class="screen hidden" style="align-items:flex-start;overflow-y:auto;padding:34px 0">
  <div class="cfg" style="width:min(1000px,94vw)">
    <h1>TRAINING PROTOCOL</h1>
    <div class="sub">clearance is earned · every construct runs on the live protocol</div>
    <div id="tutCards"></div>
    <div class="cfg-foot">
      <div class="note" id="tutNote"></div>
      <button id="tutToArena" class="primary">ARENA ▸</button>
    </div>
  </div>
</div>`);

/* ---------- ui locking ---------- */
const LOCKS={ mint:'#mintBtn', vaults:'#vaultList', ops:'#opsBody',
  tabTrade:'#opsTabs [data-ops="trade"]', tabHunt:'#opsTabs [data-ops="hunt"]',
  tabDesk:'#opsTabs [data-ops="desk"]', speed:'#speedCtl', charts:'.charttabs' };
const LOCK_ALL=Object.keys(LOCKS);
const except=(...ns)=>LOCK_ALL.filter(n=>!ns.includes(n));
TUT.applyLocks=names=>{ for(const k of LOCK_ALL)
  document.querySelectorAll(LOCKS[k]).forEach(el=>el.classList.toggle('tutlock',names.includes(k))); };

/* ---------- coach box ---------- */
const $=id=>document.getElementById(id);
function objText(st,ctx){ return typeof st.obj==='function'? st.obj(ctx) : (st.obj||''); }
TUT.renderBox=function(){
  const sc=TUT.active, st=sc.steps[TUT.step]; if(!st) return;
  $('tutBox').classList.remove('hidden');
  $('tutTtl').textContent=sc.title;
  $('tutSay').innerHTML=st.say;
  $('tutStepN').textContent=`${TUT.step+1}/${sc.steps.length}`;
  $('tutObj').classList.toggle('hidden',!st.waitFor);
  if(st.waitFor) $('tutObjTxt').textContent=objText(st,TUT.ctx);
  $('tutNextB').classList.toggle('hidden',!!st.waitFor);
  $('tutFail').classList.add('hidden'); $('tutRetryB').classList.add('hidden');
  TUT.spot(st.highlight);
  // keep the box away from what it points at
  let top=false;
  if(st.highlight){ const el=document.querySelector(st.highlight);
    if(el){ const r=el.getBoundingClientRect(); top = r.top > innerHeight*0.5; } }
  $('tutBox').classList.toggle('top',top);
};
TUT.spot=function(sel){
  const sp=$('tutSpot');
  if(!sel){ sp.classList.add('hidden'); return; }
  const el=document.querySelector(sel);
  if(!el){ sp.classList.add('hidden'); return; }
  const r=el.getBoundingClientRect();
  sp.classList.remove('hidden');
  Object.assign(sp.style,{left:(r.left-5)+'px',top:(r.top-5)+'px',width:(r.width+10)+'px',height:(r.height+10)+'px'});
};
TUT.spotRefresh=function(){ const st=TUT.active&&TUT.active.steps[TUT.step];
  if(st&&st.highlight&&!$('tutSpot').classList.contains('hidden')) TUT.spot(st.highlight); };

/* ---------- runner ---------- */
TUT.start=function(sc){
  TUT.active=sc; TUT.step=-1; TUT.ctx={}; TUT.failedMsg=null;
  ['boot','config','end','tutMenu'].forEach(id=>$(id).classList.add('hidden'));
  $('game').classList.remove('hidden');
  sc.session(TUT.ctx);
  S.tut=sc.id;
  $('feed').innerHTML=''; S.feed=[];
  feed(`<b class="gold-t">TRAINING CONSTRUCT</b> · ${sc.title}`,'hot');
  const jo=$('jackOut');
  if(!TUT._jo) TUT._jo=jo.onclick;
  jo.onclick=()=>TUT.exit(); jo.textContent='ABORT SIM';
  TUT.applyLocks(sc.lock0||[]);
  render();
  if(!TUT.pollIv&&!TUT.testMode) TUT.pollIv=setInterval(()=>{TUT.check();TUT.spotRefresh();},250);
  TUT.next();
};
TUT.next=function(){
  const sc=TUT.active; if(!sc) return;
  TUT.step++;
  if(TUT.step>=sc.steps.length) return TUT.complete();
  const st=sc.steps[TUT.step];
  if(st.lock) TUT.applyLocks(st.lock);
  setSpeed(st.waitFor? (st.speed??1) : (st.speed??0));
  st.onEnter&&st.onEnter(TUT.ctx);
  if(!TUT.testMode) TUT.renderBox();
};
TUT.check=function(){
  const sc=TUT.active; if(!sc||TUT.failedMsg) return;
  const st=sc.steps[TUT.step]; if(!st) return;
  sc.onTickX&&sc.onTickX(TUT.ctx);
  if(st.fail){ const f=st.fail(TUT.ctx); if(f) return TUT.fail(f); }
  if(st.waitFor){
    if(!TUT.testMode&&st.progress!==false) $('tutObjTxt').textContent=objText(st,TUT.ctx);
    if(st.waitFor(TUT.ctx)) TUT.next();
  }
};
TUT.fail=function(msg){
  TUT.failedMsg=msg; setSpeed(0);
  if(TUT.testMode) return;
  $('tutBox').classList.remove('hidden');
  $('tutSay').innerHTML='Construct terminated.';
  $('tutFail').textContent='✕ MISSION FAILED — '+msg; $('tutFail').classList.remove('hidden');
  $('tutObj').classList.add('hidden'); $('tutNextB').classList.add('hidden');
  $('tutRetryB').classList.remove('hidden');
};
TUT.complete=function(){
  const sc=TUT.active;
  TUT.progress.done[sc.id]=true; TUT.saveP();
  setSpeed(0);
  if(TUT.testMode){ TUT.active=null; return; }
  const nxt=ALL_SCENARIOS.find(s=>!TUT.progress.done[s.id]&&TUT.unlocked(s));
  $('tutBox').classList.remove('hidden');
  $('tutTtl').textContent=sc.title;
  $('tutSay').innerHTML=`<b>CONSTRUCT CLEARED.</b> ${sc.outro||''}`;
  $('tutObj').classList.add('hidden'); $('tutFail').classList.add('hidden');
  $('tutRetryB').classList.add('hidden');
  const nb=$('tutNextB'); nb.classList.remove('hidden');
  nb.textContent=nxt?`NEXT: ${nxt.short} ▸`:'TRAINING COMPLETE ▸';
  nb.onclick=()=>{ nb.onclick=TUT._nextClick; nxt? TUT.start(nxt) : TUT.exit(); };
  TUT.active={...sc,steps:[]}; // hold ui, no more checks
  TUT.step=0;
};
TUT.exit=function(){
  TUT.active=null; TUT.failedMsg=null;
  clearInterval(TUT.pollIv); TUT.pollIv=null;
  clearInterval(loopTimer);
  TUT.applyLocks([]);
  const jo=$('jackOut'); if(TUT._jo){ jo.onclick=TUT._jo; jo.textContent='JACK OUT'; }
  $('tutBox').classList.add('hidden'); $('tutSpot').classList.add('hidden');
  $('game').classList.add('hidden'); $('end').classList.add('hidden');
  TUT.openMenu();
};

/* time dilation */
TUT.ff=function(cond,cap=600){
  setSpeed(0);
  if(TUT.testMode){ let n=0; while(!cond()&&n++<cap) tick(); render(); return; }
  const fl=document.createElement('div'); fl.textContent='◢ TIME DILATION ◣';
  Object.assign(fl.style,{position:'fixed',top:'58px',left:'50%',transform:'translateX(-50%)',zIndex:'87',
    color:'var(--gold)',letterSpacing:'.3em',fontSize:'11px',padding:'6px 16px',background:'#000c',
    border:'1px solid var(--gold)',borderRadius:'6px'});
  document.body.appendChild(fl);
  let n=0;
  (function chunk(){
    for(let i=0;i<12;i++){ if(cond()||n++>cap){ fl.remove(); render(); return; } tick(); }
    render(); requestAnimationFrame(chunk);
  })();
};

/* ---------- scenario helpers ---------- */
function tutSession(o){
  // stagger:false — constructs need rivals at the table from week 0
  S=newSession({capital:o.capital??2, target:o.target??99, market:o.market||'moderate', speed:1,
    rivals:o.rivals||[], seed:o.seed??7, stagger:false});
  ui.tab='market'; ui.ops=o.ops||'trade'; ui.tradeMode='buy'; ui.tradeAmt=25;
  return byId('you');
}
function aged(actor,amt,ageDays){
  const v=mintVault(actor,amt);
  v.mintDay=S.day-ageDays; v.lastWithdraw=S.day-P.PERIOD_DAYS; v._vestTold=true;
  return v;
}
function mkPrey(rivalId,amt){ // fully stripped, paper sold, long dark — dormancy-eligible now
  const a=byId(rivalId);
  const v=aged(a,amt,P.VEST_DAYS+1200);
  doStrip(v, v.collateral);
  a.vbtc-=v.reserve; a.btc+=v.reserve*0.7;
  v.lastActivity=S.day-(P.DORMANCY_DAYS+7);
  a.dark=true;
  return v;
}
function forcePanic(rid){
  const a=byId(rid); const v=actorVaults(a).find(v=>!vested(v)); if(!v) return;
  const {forfeit}=doEarlyRedeem(v);
  feed(`<b style="color:${a.color}">${a.name}</b> PANICS — early-redeems ${v.treasure}, forfeits <b style="color:var(--mag)">${fmt(forfeit)} ₿</b> to the pool`,'alert');
  sfx('forfeit');
}
function forceList(sellerId){
  const a=byId(sellerId);
  const lv=actorVaults(a).find(v=>vested(v)&&!v.delegations.length&&!S.offers.find(o=>o.vaultId===v.id));
  if(!lv) return;
  const pct=0.35, durDays=300; let npv=0,c=lv.collateral;
  for(let i=0;i<10;i++){ npv+=c*P.WITHDRAW_PCT*pct/Math.pow(1.02,i+1); c*=0.99; }
  S.offers.push({vaultId:lv.id,seller:a.id,pct,durDays,price:npv});
  feed(`<b style="color:${a.color}">${a.name}</b> lists delegation rights on ${lv.treasure} at the DESK`,'hot');
}
const me=()=>byId('you');
const myV=()=>actorVaults(me());
const sched=(dw,fn)=>{ S.script=S.script||[]; S.script.push({week:S.week+dw,fn}); };

/* ============================================================
   CHAPTERS
   ============================================================ */
const CH=[];

CH.push({ id:'ch0', short:'CH0 WIRE CHECK', title:'CH0 · WIRE CHECK', group:'chapters',
  brief:'Screen anatomy. Clock, price, worth, the wire, time control.',
  outro:'You can read the floor. Next: you learn what a vault is.',
  session:()=>tutSession({rivals:['diamond','momentum'],seed:11}),
  lock0:LOCK_ALL,
  steps:[
    {say:`Training construct online. This is the floor — a live Zeno protocol session, sandboxed. Nothing here is real except the rules. The rules are <b>exactly</b> real.`},
    {say:`Top left: the clock. One tick of this world is <b>one week — 7 protocol days</b>. Everything in Zeno is priced in time, so watch this like a pilot watches altitude.`, highlight:'header'},
    {say:`The heartbeat. BTC/USD moves like the real thing — drifting, then convulsing. The tag beside it reads the weather: <span class="c">CALM</span> or <span class="m">STORM</span>. Storms arrive fast and fade slow.`, highlight:'#hPrice'},
    {say:`Your worth, the leaderboard, the table. Worth is measured in <b>Bitcoin terms</b> — the sum of everything you hold, everywhere in the protocol. First to the target takes the session.`, highlight:'.rail'},
    {say:`Time only moves if you push it. <b>SPACE</b> pauses. <b>1 / 2 / 4</b> shift gears. Run it.`,
      highlight:'#speedCtl', lock:except('speed'), speed:2,
      obj:'let 6 weeks pass', waitFor:()=>S.week>=6, auto:()=>{}},
    {say:`Good. Now stop the world — you'll want this reflex when a predator moves on you.`,
      highlight:'#speedCtl', obj:'pause time (SPACE or ❚❚)', speed:2,
      waitFor:()=>ui.paused, auto:()=>setSpeed(0)},
  ]});

CH.push({ id:'ch1', short:'CH1 THE LOCK', title:'CH1 · THE LOCK', group:'chapters',
  brief:'Mint a vault. Feel 1129 days. Draw 1% — never the whole.',
  outro:'Zeno\'s paradox is now your income. Next: what leaving early costs.',
  session:()=>tutSession({rivals:[],seed:21}),
  lock0:LOCK_ALL,
  steps:[
    {say:`Everything in Zeno begins with a vault: a treasure sealed over Bitcoin collateral. Once sealed, the clock owns it — <b>1129 days</b> before the vault vests. No borrowing against it. No liquidating it. Just time.`},
    {say:`Mint your first vault. Lock at least <b>half</b> your liquid BTC — patience pays the committed.`,
      highlight:'#mintBtn', lock:except('mint','vaults'), speed:0,
      obj:'mint a vault with ≥50% of your BTC',
      waitFor:ctx=>{ const vs=myV(); ctx.v1=vs[0];
        return vs.reduce((s,v)=>s+v.initial,0)>=S.cfg.capital*0.5; },
      auto:()=>mintVault(me(),1.2)},
    {say:`There it is. The bar under it is the vesting clock — it fills over 1129 days. Until it fills you can't draw a single satoshi. Feel the weight of that.`, highlight:'#vaultList'},
    {say:`Run time and watch it crawl. This is the game's central tension: everyone at the table is waiting on the same physics.`,
      lock:except('mint','vaults','speed'), speed:4,
      obj:'watch 8 weeks pass', onEnter:ctx=>ctx.w0=S.week,
      waitFor:ctx=>S.week>=ctx.w0+8, auto:()=>{}},
    {say:`161 weeks of that would teach you patience but waste your evening. Engaging time dilation — <b>the protocol math is untouched</b>, we're just skipping the boring part.`,
      onEnter:ctx=>TUT.ff(()=>S.day>=ctx.v1.mintDay+P.VEST_DAYS-21,400)},
    {say:`Three weeks out. Watch it turn.`, speed:1,
      obj:'watch the vault vest', waitFor:ctx=>vested(ctx.v1), auto:()=>{}},
    {say:`<b>VESTED.</b> Now the core mechanic: every 30 days you may draw <b>1% of whatever remains</b>. Remaining, not original — 0.99ⁿ never reaches zero. You can always take a share. You can never take the whole. That's Zeno's paradox, weaponized as an income stream.`,
      highlight:'#vaultList', speed:4,
      obj:ctx=>`execute 2 draws (${(ctx.v1&&ctx.v1.draws)||0}/2) — 30-day lock between`,
      waitFor:ctx=>(ctx.v1.draws||0)>=2,
      auto:ctx=>{ if(withdrawReady(ctx.v1)) uiWithdraw(ctx.v1.id); }},
    {say:`Ten years of monthly draws harvests ~70% and still leaves ~30% breathing in the vault. The stream never dies — which is why everything else in this game is a fight over streams.`},
  ]});

CH.push({ id:'ch2', short:'CH2 THE FORFEIT', title:'CH2 · THE FORFEIT', group:'chapters',
  brief:'Early exit, the penalty, and the match accrual that feeds the patient.',
  outro:'Their fear literally pays your patience. Next: stripping paper off a vault.',
  session:ctx=>{ const m=tutSession({rivals:['panic'],seed:33});
    ctx.vSmall=aged(m,0.5,450);            // ~40% served
    ctx.vKeep=aged(m,0.9,1050);            // near vest — but accrual doesn't care
    aged(byId('panic'),1.0,700);           // JITTERS' doomed vault
  },
  lock0:LOCK_ALL,
  steps:[
    {say:`You hold two vaults this time — one 40% through its lock, one nearly vested. Zeno lets you leave early. It just prices the exit in <b>time served</b>: leave at 40% of the lock, keep 40% of your collateral. The rest is forfeit. (And you must owe the street nothing — a vault with stripped reserve outstanding can't exit until it recombines.)`},
    {say:`Abandon the young vault. Read the split before you confirm. The treasure burns — that part is forever.`,
      highlight:'#vaultList', lock:except('vaults'), speed:0,
      obj:'early-exit the 40% vault (EARLY EXIT)',
      waitFor:ctx=>ctx.vSmall.burned,
      auto:ctx=>doEarlyRedeem(ctx.vSmall)},
    {say:`Where did your forfeit go? <b>Nowhere and everywhere.</b> No treasury, no fee switch — an accumulator credited it to <b>every active vault instantly, pro-rata to collateral</b>. Even vaults still vesting. No claims, no deadlines, no one-shot flags.`, highlight:'#hPool'},
    {say:`You're not the only one who breaks. Watch the wire.`,
      speed:1, onEnter:ctx=>{ ctx.pool0=S.matchPool; sched(2,()=>forcePanic('panic')); },
      obj:'watch someone else feed the match accrual',
      waitFor:ctx=>S.matchPool>ctx.pool0+0.05, auto:()=>{}},
    {say:`JITTERS just paid everyone at the table — including your <b>unvested</b> vault. The share is riding on it right now as unsettled accrual. It folds into collateral automatically the moment the vault is touched; or fold it in yourself.`},
    {say:`Settle it. Watch the vault's collateral grow — that's other people's panic, compounding for you before you've vested a single day.`,
      highlight:'#vaultList', speed:0,
      onEnter:ctx=>ctx.c0=ctx.vKeep.collateral,
      obj:'press SETTLE on your remaining vault',
      waitFor:ctx=>ctx.vKeep.collateral>ctx.c0+1e-9,
      auto:ctx=>settleMatch(ctx.vKeep)},
    {say:`That's the flywheel: exits feed the accumulator, the accumulator feeds everyone still holding, and settled forfeits themselves start earning the next forfeit. Patience is a claim on other people's panic — collected continuously, no vesting gate, no expiry.`},
  ]});

CH.push({ id:'ch3', short:'CH3 THE STREET', title:'CH3 · THE STREET', group:'chapters',
  brief:'Vesting unlocks the strip: vBTC, the floating discount, par as NAV floor, buyback.',
  outro:'You can now strip vested principal into paper and trade the float. Next: the weather.',
  session:ctx=>{ const m=tutSession({rivals:['arb'],seed:44,ops:'trade'});
    ctx.v=aged(m,1.2,P.VEST_DAYS-14);   // two weeks from vesting — the gate IS the lesson
  },
  lock0:LOCK_ALL,
  steps:[
    {say:`Your vault is two weeks from vesting — and until it turns, <b>STRIP</b> stays sealed. Vesting is the protocol's time lock, and stripping is not a back door through it: no liquidity against unvested principal, ever. Look at the vault card — the strip control is dark.`,
      highlight:'#vaultList'},
    {say:`Let it turn.`, speed:2, lock:except('vaults','speed'),
      obj:'watch the vault vest — the strip unlocks with it',
      waitFor:ctx=>vested(ctx.v), auto:()=>{}},
    {say:`<b>VESTED.</b> Now the street opens. <b>STRIP</b> moves any slice of active collateral into an <b>immunized reserve</b> and mints <span class="c">vestedBTC</span> 1:1 against it. Fungible. Tradeable. Fractional and repeatable — but only on the far side of the 1129 days.`},
    {say:`Strip about half. Read the modal: the reserve is <b>untouchable by withdrawals</b>. Your 1% draws on the active remainder only. You cannot sell the principal and keep collecting its coupon.`,
      highlight:'#vaultList', lock:except('vaults'), speed:0,
      obj:'STRIP ~50% of your vault',
      waitFor:ctx=>ctx.v.reserve>0,
      auto:ctx=>doStrip(ctx.v,ctx.v.collateral*0.5)},
    {say:`Hold that invariant: <b>total reserve always equals vBTC supply</b>. Every unit of paper is backed by a locked unit of BTC — so <b>1.00, par, is the on-chain NAV floor</b>. Below it the paper is provably underpriced against its backing.`},
    {say:`Sell ~30% of your vBTC into the pool. Watch two numbers: the price you get (slippage + 0.3% fee) and the <b>ratio</b> after — your own sale moves the market against you.`,
      highlight:'#opsBody', lock:except('vaults','ops','tabTrade'), speed:0,
      onEnter:ctx=>ctx.vb0=me().vbtc,
      obj:'sell ≈30% of your vBTC (SELL vBTC · size ~30% · EXECUTE)',
      waitFor:ctx=>me().vbtc<=ctx.vb0*0.75,
      auto:()=>doSwap(me(),'sell',me().vbtc*0.3)},
    {say:`So why does vBTC trade <b>below</b> par? No peg holds it up — it floats. The discount is the market pricing <b>when</b> the reserve comes back: recombination timing, dormancy risk, seller desperation. And there's no discount above par: try to bid past 1.00 and strippers mint fresh paper into your order. Par caps the top; arbitrage disciplines the bottom.`},
    {say:`Which makes the discount an <b>owner's arbitrage</b>: your reserve redeems paper at 1:1, so every vBTC you buy back below par is guaranteed profit. Buy some back cheap.`,
      highlight:'#opsBody', speed:1,
      obj:ctx=>`buy vBTC below par (you hold ${fmt(me().vbtc)}, ratio ${ratio().toFixed(3)})`,
      waitFor:ctx=>me().vbtc>ctx.vb0*0.75,
      auto:()=>doSwap(me(),'buy',me().btc*0.2)},
    {say:`Recombine. <b>Fractional</b>, like everything here: burn any amount of vBTC, reactivate that much reserve into active collateral. No magic original number to reassemble — the protocol only counts units.`,
      highlight:'#vaultList', speed:0,
      onEnter:ctx=>ctx.res0=ctx.v.reserve,
      obj:'RECOMBINE into your vault',
      waitFor:ctx=>ctx.v.reserve<ctx.res0-1e-9,
      auto:ctx=>doRecombine(ctx.v)},
    {say:`That loop — strip, sell, buy the discount, recombine — is the whole vBTC economy. This is what DELTA_GHOST lives on: the buyback arbitrage that keeps the float honest without a single line of peg code. Stripping is liquidity without killing the stream. It's also exposure, as you'll learn in CH6.`},
  ]});

CH.push({ id:'ch4', short:'CH4 WEATHER', title:'CH4 · WEATHER', group:'chapters',
  brief:'Volatility regimes, rival psychology, buying fear and selling calm.',
  outro:'You can read minds now — they\'re printed on the rail. Next: renting streams.',
  session:ctx=>{ tutSession({rivals:['momentum','volplayer','panic'],seed:55,ops:'trade'});
    byId('panic').vbtc=1.0;                       // give JITTERS paper to dump
    for(let w=2;w<=9;w++) sched(w,()=>{ S.regime=1; });   // hold the storm
    sched(3,()=>{ doSwap(byId('panic'),'sell',0.6);
      feed(`<b style="color:${ARCH.panic.color}">JITTERS</b> dumps vBTC into the pit — ratio bleeds`,'alert'); });
  },
  lock0:except('speed','charts'),
  steps:[
    {say:`Two weathers on this floor. <span class="c">CALM</span>: σ ≈ 7.4% weekly. <span class="m">STORM</span>: σ ≈ 11.3%, and the whole screen knows it. Storms arrive fast and fade slow — panic moves faster than calm. One is coming.`},
    {say:`Ride it out. Watch the rail while it blows: every rival wears their mind on their sleeve — <span class="c">STEADY</span>, FEARFUL, <span class="m">PANICKING</span>. Psychology here runs on <b>dollar-terms pain</b>, and it drifts: losers get jumpier, winners get careless.`,
      highlight:'#rivals', speed:1,
      obj:'survive 6 storm weeks — watch the moods flip',
      onEnter:ctx=>ctx.w0=S.week,
      waitFor:ctx=>S.week>=ctx.w0+7, auto:()=>{}},
    {say:`See JITTERS bleeding paper into the pool? Fear is a seller. Which makes fear a <b>discount</b>. Buy it.`,
      highlight:'#opsBody', lock:except('ops','tabTrade','speed','charts'), speed:1,
      obj:()=>`buy ≥0.1 vBTC while the street is scared (ratio ${ratio().toFixed(3)})`,
      waitFor:()=>me().vbtc>=0.1,
      auto:()=>doSwap(me(),'buy',0.3)},
    {say:`Position on. Storms fade slow — but they fade. Hold through the noise and unload into recovery.`,
      speed:2, onEnter:ctx=>ctx.vbHigh=me().vbtc,
      obj:ctx=>`in CALM, sell at least half your position (${fmt(me().vbtc)} held)`,
      waitFor:ctx=>S.regime===0&&me().vbtc<=ctx.vbHigh/2,
      auto:ctx=>{ if(S.regime===0&&me().vbtc>ctx.vbHigh/2) doSwap(me(),'sell',me().vbtc*0.6); }},
    {say:`That round trip is STATIC_JOY's entire life, and the 7-week trend line is RAZORWAVE's. You don't have to trade weather — but you must <b>read</b> it, because it decides when rivals crack, and cracking rivals feed pools.`},
  ]});

CH.push({ id:'ch5', short:'CH5 THE DESK', title:'CH5 · THE DESK', group:'chapters',
  brief:'Delegation: buy a rival\'s withdrawal stream, sell a slice of yours.',
  outro:'Streams are property. Next: what happens to abandoned property.',
  session:ctx=>{ const m=tutSession({rivals:['farmer','diamond'],seed:66,ops:'desk'});
    ctx.v=aged(m,1.0,P.VEST_DAYS+3);
    aged(byId('farmer'),0.8,P.VEST_DAYS+40);
    sched(1,()=>forceList('farmer'));
  },
  lock0:LOCK_ALL,
  steps:[
    {say:`A withdrawal stream is property, and property can be rented. <b>Delegation</b> grants an address a percentage of every 1% draw — the protocol itself splits the payment. No custody handover, no trust. The DESK is where streams change hands.`},
    {say:`HARVESTER-9 just listed a slice of its stream. The price is roughly the discounted value of a decaying 1%-per-30-days flow — check what you pay against what you'll receive.`,
      highlight:'#opsBody', lock:except('ops','tabDesk'), speed:1,
      obj:'BUY STREAM at the desk',
      waitFor:()=>S.vaults.some(v=>v.delegations.some(d=>d.to==='you')),
      auto:()=>{ const o=S.offers[0]; if(!o) return; const v=S.vaults.find(x=>x.id===o.vaultId);
        if(v&&me().btc>=o.price){ me().btc-=o.price; byId(o.seller).btc+=o.price;
          v.delegations.push({to:'you',pct:o.pct,until:S.day+o.durDays}); S.offers=S.offers.filter(x=>x!==o); } }},
    {say:`Done. Now you get paid <b>when the owner draws</b> — their cadence, your cut. Watch the wire for a few weeks; the drips land straight in your liquid BTC.`,
      speed:4, onEnter:ctx=>ctx.w0=S.week,
      obj:'let ~10 weeks of drips arrive',
      waitFor:ctx=>S.week>=ctx.w0+10, auto:()=>{}},
    {say:`It works in reverse: sell a slice of <b>your</b> stream for cash up front. Time-preference arbitrage — you're trading future patience for present firepower.`,
      highlight:'#vaultList', lock:except('vaults','ops','tabDesk'), speed:0,
      obj:'SELL DELEGATION on your vested vault',
      waitFor:()=>myV().some(v=>v.delegations.some(d=>d.to!=='you')),
      auto:ctx=>{ const v=ctx.v; const buyer=S.actors.find(a=>a.arch);
        me().btc+=0.03; buyer.btc-=0.03; v.delegations.push({to:buyer.id,pct:0.4,until:S.day+300}); }},
    {say:`Both sides of the desk, one session. Rule of thumb: buy streams when you're rich in BTC and poor in time; sell them when the opposite. The archetypes that farm this — HARVESTER-9 — quietly compound while everyone else watches the chart.`},
  ]});

CH.push({ id:'ch6', short:'CH6 THE HUNT', title:'CH6 · THE HUNT', group:'chapters',
  brief:'Dormancy: poke, grace, claim. Then survive being prey yourself.',
  outro:'Hunter and hunted, same session. The gauntlet is open.',
  session:ctx=>{ const m=tutSession({rivals:['predator','panic'],seed:77,ops:'hunt'});
    m.vbtc=1.0;
    ctx.prey=mkPrey('panic',0.9);
    const c=byId('predator'); c.dark=true; c.btc=0.6; c.vbtc=0.2;  // caged, for now
  },
  lock0:LOCK_ALL,
  steps:[
    {say:`Zeno never liquidates anyone. But it does <b>punish absence</b>. A vault becomes prey when three things align: stripped reserve is outstanding, its owner holds less paper than that reserve, and <b>1129 days</b> pass with no touch. JITTERS left exactly such a corpse. The HUNT board sees it.`},
    {say:`Poke it. A poke starts a <b>30-day grace clock</b> — a public accusation of abandonment. If the owner touches the vault, the poke dies. If not…`,
      highlight:'#opsBody', lock:except('ops','tabHunt'), speed:0,
      obj:'POKE the dormant vault',
      waitFor:ctx=>ctx.prey.pokeDay!==null,
      auto:ctx=>doPoke(ctx.prey)},
    {say:`Grace is running. JITTERS' terminal has been dark for three years — nobody is coming.`,
      speed:4,
      obj:ctx=>`outlast the grace (${Math.max(0,P.GRACE_DAYS-(S.day-(ctx.prey.pokeDay||S.day)))}d left)`,
      waitFor:ctx=>claimable(ctx.prey), auto:()=>{}},
    {say:`CLAIMABLE. Any vBTC holder — not just you — may now burn paper <b>1:1 for the reserve</b>, any amount, repeatedly, until the reserve runs dry. And read the fine print: only the reserve moves. The vault, its treasure, its active collateral all <b>stay with JITTERS</b>. Dormancy forecloses the sold principal, nothing else.`,
      highlight:'#opsBody', speed:0,
      obj:'CLAIM the reserve (burns vBTC 1:1)',
      waitFor:ctx=>ctx.prey._claimedBy==='you',
      auto:ctx=>doClaimDormant(ctx.prey,me())},
    {say:`Clean feed. Now the mirror. You've been careless too — an old stripped vault of yours, paper long sold, untouched for years. And the thing across the table just <b>woke up</b>.`,
      onEnter:ctx=>{
        const v=aged(me(),0.6,P.VEST_DAYS+1200); doStrip(v,v.collateral);
        me().vbtc-=v.reserve; me().btc+=v.reserve*0.65; v.lastActivity=S.day-(P.DORMANCY_DAYS+3);
        ctx.mine=v; const c=byId('predator'); c.dark=false; c.nextAct=S.week+1;
        toast('⚠ Old stripped vault surfaced in your holdings — CARRION is awake','warn'); sfx('poke');
      }},
    {say:`CARRION hunts exactly like you just did. When the poke lands, you have 30 days. <b>PROVE ACTIVITY</b> — any touch resets the clock.`,
      highlight:'#vaultList', lock:except('vaults','ops','tabHunt','speed'), speed:1,
      obj:'survive: PROVE ACTIVITY after CARRION pokes you',
      waitFor:ctx=>{ if(ctx.mine.pokeDay!==null) ctx.poked=true;
        return ctx.poked&&ctx.mine.pokeDay===null&&ctx.mine._claimedBy===undefined; },
      fail:ctx=>ctx.mine._claimedBy?'CARRION burned paper for your whole reserve. You keep the husk — the principal is gone.':null,
      auto:ctx=>{ if(ctx.mine.pokeDay!==null) doProveActivity(ctx.mine); }},
    {say:`The predator slinks back. Remember both halves of this lesson: <b>hunt</b> reserves others abandon, and never let a stripped vault go quiet — a draw, a proof, holding your own paper, any of it keeps the wolves off. The gauntlet will test everything now.`},
  ]});

/* ============================================================
   CH7 — THE GAUNTLET (five doctrines)
   ============================================================ */
const MIS=[];

MIS.push({ id:'m_monk', short:'MONK', title:'GAUNTLET · MONK', group:'gauntlet',
  brief:'Diamond doctrine: mint, draw, settle. Trading is forbidden. +15%.',
  outro:'PATIENCE.EXE respects you now. It won\'t say so.',
  session:ctx=>{ const m=tutSession({rivals:['panic','momentum','spec'],seed:101});
    ctx.va=aged(m,0.8,P.VEST_DAYS); ctx.vb=aged(m,0.8,P.VEST_DAYS);
    const j=byId('panic'); aged(j,0.9,620); aged(j,1.0,320);
    sched(5,()=>forcePanic('panic')); sched(20,()=>forcePanic('panic'));
    ctx.goal=S.cfg.capital*1.15;
  },
  lock0:['ops','tabTrade','tabHunt','tabDesk'],
  steps:[
    {say:`<b>DOCTRINE: MONK.</b> The exchange is sealed. The desk is sealed. The hunt is sealed. You may mint, draw, and settle — nothing else. Reach <b>+15%</b> inside 100 weeks. The mechanics carry you: every forfeit accrues to your collateral the instant it lands, every draw folds it in, and freshly settled forfeits earn the <b>next</b> forfeit. Sit still, correctly.`},
    {say:`Run.`, speed:2,
      obj:ctx=>`net worth ${fmt(me().nw)} / ${fmt(ctx.goal)} ₿ · fed ${fmt(S.matchPool)} · week ${S.week}/100`,
      waitFor:ctx=>me().nw>=ctx.goal,
      fail:()=>S.week>100?'The clock beat the monk. The accrual compounds only for those who last.':null,
      auto:ctx=>{ for(const v of myV()){
        if(withdrawReady(v)) doWithdraw(v);
        if(pendingMatch(v)>0.02) settleMatch(v); } }},
    {say:`+15% without touching a single trade. Patience, mechanically superior.`},
  ]});

MIS.push({ id:'m_harvest', short:'HARVEST', title:'GAUNTLET · HARVEST', group:'gauntlet',
  brief:'Farmer doctrine: strip, sell paper, buy streams. Full loop.',
  outro:'HARVESTER-9 would call this a modest Tuesday.',
  session:ctx=>{ const m=tutSession({rivals:['diamond','farmer','panic'],seed:102});
    ctx.v=aged(m,1.2,P.VEST_DAYS+3);
    aged(byId('diamond'),1.0,P.VEST_DAYS+50);
    const j=byId('panic'); aged(j,0.9,600); aged(j,1.0,350);
    sched(2,()=>forceList('diamond'));
    sched(8,()=>forcePanic('panic')); sched(26,()=>forcePanic('panic'));
    ctx.goal=S.cfg.capital*1.10;   // forfeits+streams cap the real edge ≈+13% here; +15% was unreachable
  },
  lock0:['tabHunt'],
  steps:[
    {say:`<b>DOCTRINE: HARVEST.</b> Yield is a verb. Inside 80 weeks: <b>strip</b> your vault, <b>sell at least 30%</b> of the paper, <b>buy a delegation stream</b> at the desk, and stand at <b>+10%</b>. The full farmer loop — paper out at a discount, streams and forfeits in, buy the paper back cheaper than you sold it. Mind the trade-off: what you strip stops feeding your 1% draw until you recombine.`},
    {say:`Work.`, speed:2,
      obj:ctx=>{ const sold=ctx.soldFlag?'✓':'✗', sep=ctx.stripFlag?'✓':'✗',
        del=S.vaults.some(v=>v.delegations.some(d=>d.to==='you'))?'✓':'✗';
        return `strip ${sep} · sold30% ${sold} · stream ${del} · ${fmt(me().nw)}/${fmt(ctx.goal)} ₿ · wk ${S.week}/80`; },
      waitFor:ctx=>{ if(ctx.v.reserve>0) ctx.stripFlag=true;
        if(ctx.v.reserve>0&&me().vbtc<=ctx.v.reserve*0.7) ctx.soldFlag=true;
        return ctx.stripFlag&&ctx.soldFlag&&S.vaults.some(v=>v.delegations.some(d=>d.to==='you'))&&me().nw>=ctx.goal; },
      fail:()=>S.week>80?'80 weeks gone. A farmer who doesn\'t plant reaps nothing.':null,
      auto:ctx=>{ if(!ctx.stripFlag&&ctx.v.reserve<=0) doStrip(ctx.v,ctx.v.collateral*0.6);
        if(ctx.v.reserve>0&&!ctx.soldFlag) doSwap(me(),'sell',ctx.v.reserve*0.35);
        const o=S.offers[0];
        if(o&&!S.vaults.some(v=>v.delegations.some(d=>d.to==='you'))){
          const v=S.vaults.find(x=>x.id===o.vaultId);
          if(v&&me().btc>=o.price){ me().btc-=o.price; byId(o.seller).btc+=o.price;
            v.delegations.push({to:'you',pct:o.pct,until:S.day+o.durDays}); S.offers=S.offers.filter(x=>x!==o); } }
        for(const v of myV()){ if(withdrawReady(v)) doWithdraw(v); if(pendingMatch(v)>0.02) settleMatch(v); }
        // buy the discount back and recombine — the farmer's second harvest
        if(ctx.soldFlag&&ratio()<0.8&&me().btc>0.3) doSwap(me(),'buy',me().btc*0.25);
        if(ctx.soldFlag&&ctx.v.reserve>0&&me().vbtc>ctx.v.reserve*0.75) doRecombine(ctx.v,me().vbtc-ctx.v.reserve*0.72); }},
    {say:`Paper sold, stream bought, forfeits settled, worth up 10%. That's compounding without praying to the chart.`},
  ]});

MIS.push({ id:'m_edge', short:'EDGE', title:'GAUNTLET · EDGE', group:'gauntlet',
  brief:'Trader doctrine: no vaults, pure vBTC swings. +10% in 60 weeks.',
  outro:'RAZORWAVE just glanced over. That\'s as warm as it gets.',
  session:ctx=>{ tutSession({rivals:['momentum','volplayer','spec','panic'],seed:103,ops:'trade'});
    const j=byId('panic'); j.vbtc=1.5;
    for(let w=5;w<=12;w++) sched(w,()=>{S.regime=1;});
    sched(6,()=>doSwap(byId('panic'),'sell',0.9));
    for(let w=25;w<=31;w++) sched(w,()=>{S.regime=1;});
    sched(26,()=>doSwap(byId('panic'),'sell',0.5));
    sched(14,()=>doSwap(byId('spec'),'buy',0.5));
    sched(38,()=>doSwap(byId('spec'),'buy',0.6));
    ctx.goal=S.cfg.capital*1.10;
  },
  lock0:['mint','vaults','tabHunt','tabDesk'],
  steps:[
    {say:`<b>DOCTRINE: EDGE.</b> No vaults. No streams. Just you, the pit, and the weather. <b>+10% in 60 weeks</b> trading vBTC only. Storms are scheduled by the gods of this construct — buy the terror, sell the relief. Miss the swings and the fee grind eats you.`},
    {say:`Trade.`, speed:2,
      obj:ctx=>`net worth ${fmt(me().nw)} / ${fmt(ctx.goal)} ₿ · ratio ${ratio().toFixed(3)} · wk ${S.week}/60`,
      waitFor:ctx=>me().nw>=ctx.goal,
      fail:()=>S.week>60?'Flat after 60 weeks. The pit keeps the timid as tuition.':null,
      auto:()=>{ const r=ratio();
        if(r<0.70&&me().btc>0.3) doSwap(me(),'buy',me().btc*0.5);
        if(r>0.84&&me().vbtc>0.1) doSwap(me(),'sell',me().vbtc*0.7); }},
    {say:`+10% out of pure oscillation. GLITCHBET does this on vibes; you did it on regime physics.`},
  ]});

MIS.push({ id:'m_carrion', short:'CARRION RUN', title:'GAUNTLET · CARRION RUN', group:'gauntlet',
  brief:'Predator doctrine: out-hunt CARRION for the dormant corpses.',
  outro:'CARRION eats second tonight. It will remember.',
  session:ctx=>{ const m=tutSession({rivals:['predator','panic'],seed:104,ops:'hunt'});
    m.vbtc=2.2;
    ctx.preys=[mkPrey('panic',0.6),mkPrey('panic',0.65),mkPrey('panic',0.7)];
    const c=byId('predator'); c.btc=0.9; c.vbtc=0.66; c.nextAct=3;
  },
  lock0:['mint','tabTrade','tabDesk'],
  steps:[
    {say:`<b>DOCTRINE: PREDATOR.</b> Three corpses on the board — JITTERS stripped everything, sold the paper, went dark. CARRION wakes in three weeks and it is <b>faster than you think</b>. Drain <b>two of three</b> reserves before it does. Pokes are public; grace is 30 days; claims burn paper 1:1 for reserve — whoever burns last takes the scraps. Move.`},
    {say:`Hunt.`, speed:1,
      obj:ctx=>{ const y=ctx.preys.filter(p=>p._claimedBy==='you').length,
        c=ctx.preys.filter(p=>p._claimedBy==='predator').length;
        return `you ${y}/2 · CARRION ${c}/2 · vBTC ${fmt(me().vbtc)} · wk ${S.week}/45`; },
      waitFor:ctx=>ctx.preys.filter(p=>p._claimedBy==='you').length>=2,
      fail:ctx=>{ if(ctx.preys.filter(p=>p._claimedBy==='predator').length>=2)
          return 'CARRION fed twice. In the wild, the patient predator is the fed predator.';
        return S.week>45?'The corpses rotted unclaimed. Hesitation is not a doctrine.':null; },
      auto:ctx=>{ for(const p of ctx.preys){ if(p.reserve<=0) continue;
        if(p.pokeDay===null&&dormancyEligible(p)) doPoke(p);
        if(claimable(p)&&me().vbtc>0) doClaimDormant(p,me()); } }},
    {say:`Two feeds. Notice what you never did: attack a <i>living</i> player — the husks even keep their treasures. Zeno's only violence is against absence, and only against what absence already sold.`},
  ]});

MIS.push({ id:'m_ghost', short:'GHOST', title:'GAUNTLET · GHOST', group:'gauntlet',
  brief:'Arbitrageur doctrine: keep the float in the 0.70–0.95 lane for 40 weeks, profitably.',
  outro:'DELTA_GHOST nods once. The float held because you held it.',
  session:ctx=>{ const m=tutSession({capital:3,rivals:['spec','panic'],seed:105,ops:'trade'});
    S.pool={btc:12.3, vbtc:15};                       // ratio 0.82, deep enough to steer by hand
    m.btc=2.5; m.vbtc=2.5;                             // arb seed: inventory on BOTH sides
    // whales move in scripted bursts then go quiet — pool churns ONLY on their pushes and yours
    const P1=byId('panic'), P2=byId('spec');
    P1.vbtc=6.0; P2.btc=5.0; P1.dark=true; P2.dark=true;
    // paired same-direction pressure: leaving it alone WILL breach — active two-sided defense required
    sched(3, ()=>doSwap(P1,'sell',0.9));   // → ~0.75
    sched(7, ()=>doSwap(P1,'sell',0.9));   // stacks toward floor if not corrected
    sched(14,()=>doSwap(P2,'buy', 0.9));   // → ~0.90
    sched(18,()=>doSwap(P2,'buy', 0.9));   // stacks toward ceiling if not corrected
    sched(26,()=>doSwap(P1,'sell',1.0));
    sched(32,()=>doSwap(P2,'buy', 1.0));
    sched(37,()=>doSwap(P1,'sell',0.9));
    ctx.w0=S.week; ctx.startNW=netWorth(m).total; ctx.goal=ctx.startNW*1.02; ctx.oobN=0; ctx.oobW=-1;
  },
  lock0:['mint','vaults','tabHunt','tabDesk'],
  steps:[
    {say:`<b>DOCTRINE: GHOST.</b> vBTC has no peg — the protocol gives you exactly one number, <b>par</b>, and everything below it is opinion. Your desk's opinion: the float belongs between <b>0.70 and 0.95</b>. For 40 weeks, whales will disagree. You are the counterparty — seeded with <b>both BTC and vBTC</b> so you can lean either way: buy the panic, sell the euphoria. Let the ratio sit outside your lane <b>3 weeks running</b> and the construct fails. End in profit — each whale you fade leaves fee edge in your pocket.`},
    {say:`Defend.`, speed:1,
      obj:ctx=>`ratio ${ratio().toFixed(3)} [0.70–0.95] · breach ${ctx.oobN}/3 · ${fmt(me().nw)}/${fmt(ctx.goal)} ₿ · wk ${S.week-ctx.w0}/40`,
      waitFor:ctx=>S.week>=ctx.w0+40&&me().nw>=ctx.goal,
      fail:ctx=>{ const r=ratio();
        if(r<0.70||r>0.95){ if(ctx.oobW!==S.week){ ctx.oobN++; ctx.oobW=S.week; } }
        else ctx.oobN=0;
        if(ctx.oobN>=3) return 'The lane broke on your watch. Below par there is no floor but you.';
        if(S.week>=ctx.w0+40&&me().nw<ctx.goal) return 'Lane held, book bled. A ghost that pays to exist fades.';
        return null; },
      auto:()=>{ const r=ratio(), k=S.pool.btc*S.pool.vbtc;
        // trade sized to land the pool at ratio 0.80 (constant-product: btc' = sqrt(T·k))
        if(r<0.72){ const x=Math.sqrt(0.80*k)-S.pool.btc;
          if(x>0.01) doSwap(me(),'buy',Math.min(x/(1-P.AMM_FEE),me().btc)); }
        if(r>0.92){ const a=Math.sqrt(k/0.80)-S.pool.vbtc;
          if(a>0.01) doSwap(me(),'sell',Math.min(a/(1-P.AMM_FEE),me().vbtc)); } }},
    {say:`Forty weeks, lane intact, book green. No peg did that — you did. This is what DELTA_GHOST does silently in every session you play; now you'll see it everywhere.`},
  ]});

/* ============================================================
   CH8 — GRADUATION
   ============================================================ */
const CH8={ id:'ch8', short:'CH8 GRADUATION', title:'CH8 · GRADUATION', group:'final',
  brief:'A real session, full table, real target. Advisor on. Win or learn.',
  outro:'Training over. The arena is through the boot screen. They remember you.',
  session:ctx=>{ tutSession({rivals:['diamond','farmer','momentum','panic','predator'],
    target:1.5, seed: TUT.testMode? 999 : (Math.floor(Math.random()*99999)||1)});
    ctx.hints={};
  },
  lock0:[],
  onTickX:ctx=>{ if(!ctx.hints) return; const h=ctx.hints;
    if(!h.vest){ const v=myV().find(v=>vested(v)&&withdrawReady(v));
      if(v){ h.vest=1; toast('◇ ADVISOR: a vault is vested with a draw ready. Streams don\'t pay the idle.','gold'); } }
    if(!h.pool&&myV().some(v=>pendingMatch(v)>0.1)){
      h.pool=1; toast('◇ ADVISOR: a fat match accrual is riding on your vault. Any touch settles it into collateral.','gold'); }
    if(!h.dorm){ const v=myV().find(v=>v.reserve>0&&S.day-v.lastActivity>900);
      if(v){ h.dorm=1; toast('◇ ADVISOR: your stripped vault is going quiet. Touch it — or hold paper — before something claims the reserve.','warn'); } }
    if(!h.storm&&S.regime===1&&S.week>3){ h.storm=1;
      toast('◇ ADVISOR: storm regime. Fear sells the float cheap — every vBTC below par is backed at par.','gold'); }
  },
  steps:[
    {say:`<b>GRADUATION.</b> Full table. Real target: <b>+50%</b>, first one there takes it. Everything is unlocked, the seed is random, and the ADVISOR will whisper exactly four times. After this, you're just another mind at the table. Good hunting.`},
    {say:`The session is yours. This box stays out of your way — it returns when someone wins.`,
      speed:1, progress:false,
      obj:'finish the session (win, lose, or jack out via ABORT)',
      onEnter:()=>{ $('tutBox').classList.add('hidden'); $('tutSpot').classList.add('hidden'); },
      waitFor:()=>S.over,
      auto:()=>{ for(const v of myV()){
          if(withdrawReady(v)) doWithdraw(v);
          if(pendingMatch(v)>0.05) settleMatch(v);
          if(vested(v)&&v.reserve<=0&&S.week>200) doStrip(v,v.collateral*0.5);
          if(v.pokeDay!==null) doProveActivity(v); }
        if(myV().length===0&&me().btc>1) mintVault(me(),me().btc*0.6);
        if(ratio()<0.62&&me().btc>0.2) doSwap(me(),'buy',me().btc*0.3);
        if(ratio()>0.93&&me().vbtc>0.1) doSwap(me(),'sell',me().vbtc*0.5); }},
    {say:`However it ended — that was the real game, played with real doctrine. Every rival you just faced is a strategy you now know from the inside.`},
  ]};

const ALL_SCENARIOS=[...CH,...MIS,CH8];
const byIdSc=id=>ALL_SCENARIOS.find(s=>s.id===id);

/* ---------- unlock rules ---------- */
TUT.unlocked=function(sc){
  const d=TUT.progress.done;
  if(sc.group==='chapters'){ const i=CH.indexOf(sc); return i===0||!!d[CH[i-1].id]; }
  if(sc.group==='gauntlet') return !!d.ch6;
  if(sc.id==='ch8') return MIS.filter(m=>d[m.id]).length>=3;
  return true;
};

/* ---------- menu ---------- */
TUT.openMenu=function(){
  ['boot','config','end','game'].forEach(id=>$(id).classList.add('hidden'));
  $('tutBox').classList.add('hidden'); $('tutSpot').classList.add('hidden');
  $('tutMenu').classList.remove('hidden');
  const d=TUT.progress.done;
  const card=sc=>{ const done=!!d[sc.id], ok=TUT.unlocked(sc);
    return `<div class="tut-card ${done?'done':ok?'ready':'locked'}" data-sc="${sc.id}">
      <div class="tc-t"><b>${sc.short}</b><span class="st">${done?'CLEARED':ok?'READY':'LOCKED'}</span></div>
      <small>${sc.brief}</small></div>`; };
  $('tutCards').innerHTML=
    `<div class="tut-sec">Fundamentals</div><div class="tut-cards">${CH.map(card).join('')}</div>
     <div class="tut-sec">The Gauntlet — five doctrines ${d.ch6?'':'· clear CH6 to open'}</div>
     <div class="tut-cards">${MIS.map(card).join('')}</div>
     <div class="tut-sec">Final clearance ${TUT.unlocked(CH8)?'':'· clear 3 doctrines to open'}</div>
     <div class="tut-cards">${card(CH8)}</div>`;
  const total=ALL_SCENARIOS.filter(s=>d[s.id]).length;
  $('tutNote').textContent= total===ALL_SCENARIOS.length
    ? 'Full clearance. The table is waiting for you in the arena.'
    : `${total}/${ALL_SCENARIOS.length} constructs cleared. Progress persists on this terminal.`;
  $('tutCards').querySelectorAll('.tut-card').forEach(el=>{
    const sc=byIdSc(el.dataset.sc);
    if(TUT.unlocked(sc)) el.onclick=()=>TUT.start(sc);
  });
};

/* ---------- wiring ---------- */
TUT._nextClick=()=>TUT.next();
$('tutNextB').onclick=TUT._nextClick;
$('tutExitB').onclick=()=>TUT.exit();
$('tutRetryB').onclick=()=>{ const sc=byIdSc(TUT.active.id); TUT.failedMsg=null; TUT.start(sc); };
$('tutBtn').onclick=()=>TUT.openMenu();
$('tutToArena').onclick=()=>{ $('tutMenu').classList.add('hidden');
  $('config').classList.remove('hidden'); buildConfig(); };

/* ============================================================
   headless harness: ?test=tut
   ============================================================ */
if(location.search.includes('test=tut')){
  window.addEventListener('load',()=>{
    TUT.testMode=true; ui.muted=true;
    // stub the heavy DOM paths — logic untouched
    render=()=>{}; toast=()=>{}; shake=()=>{};
    feed=(m,c)=>{ S&&S.feed&&S.feed.unshift({w:S.week,msg:m,cls:c}); };
    const _ss=setSpeed; setSpeed=x=>{ ui.speed=x; ui.paused=(x===0); };
    const fails=[];
    for(const sc of ALL_SCENARIOS){
      try{
        TUT.progress.done={}; // isolation: unlock checks not exercised here
        TUT.start(sc);
        let guard=0;
        while(TUT.active&&TUT.active.id===sc.id&&guard++<4000){
          const st=sc.steps[TUT.step];
          if(!st) break;
          if(TUT.failedMsg){ fails.push(`${sc.id}: FAILED at step ${TUT.step+1} — ${TUT.failedMsg}`); break; }
          if(!st.waitFor){ TUT.next(); continue; }
          st.auto&&st.auto(TUT.ctx);
          tick(); TUT.check();
        }
        if(guard>=4000) fails.push(`${sc.id}: stuck at step ${TUT.step+1} after 4000 ticks`);
      }catch(e){ fails.push(`${sc.id}: threw ${e.message}`); }
      TUT.active=null; TUT.failedMsg=null;
    }
    setSpeed=_ss;
    document.title=fails.length?`TUT FAIL ${fails.length}`:'TUT SELFTEST PASS';
    document.body.insertAdjacentHTML('beforeend',
      `<pre id="testout" style="position:fixed;inset:auto 0 0 0;z-index:99;background:#000;color:${fails.length?'#ff4d5e':'#3dff9c'};padding:10px;max-height:45vh;overflow:auto">`+
      (fails.length? 'TUT SELFTEST FAIL\n'+fails.join('\n')
        : `TUT SELFTEST PASS · ${ALL_SCENARIOS.length} constructs cleared end-to-end`)+'</pre>');
  });
}
