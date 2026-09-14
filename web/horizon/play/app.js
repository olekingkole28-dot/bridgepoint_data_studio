import {DeterministicRng,HorizonRuntimeContract,KillCamBuffer,DwellPickupController,generateCover} from './runtime-contract.js';

const SUPABASE_URL='https://xdfsjztwgsbmabshzsjw.supabase.co';
const PUBLISHABLE_KEY='sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';
const sb=window.supabase?.createClient(SUPABASE_URL,PUBLISHABLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const $=id=>document.getElementById(id);
const state={player:null,config:null,party:null,match:null,worldCell:null,selectedMode:'TDM',channel:null,peers:new Map(),killcam:new KillCamBuffer(),pickup:null};
const qs=new URLSearchParams(location.search);

function b64url(bytes){
  let s='';for(const b of bytes)s+=String.fromCharCode(b);
  return btoa(s).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
}
function identity(){
  let id=localStorage.getItem('horizon-player-id');
  let secret=localStorage.getItem('horizon-player-secret');
  if(!id){id=crypto.randomUUID();localStorage.setItem('horizon-player-id',id)}
  if(!secret){secret=b64url(crypto.getRandomValues(new Uint8Array(32)));localStorage.setItem('horizon-player-secret',secret)}
  return {id,secret};
}
const ident=identity();

async function rpc(name,params={}){
  const r=await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`,{
    method:'POST',
    headers:{apikey:PUBLISHABLE_KEY,'content-type':'application/json','accept':'application/json'},
    body:JSON.stringify(params)
  });
  const text=await r.text();
  if(!r.ok){let msg=text;try{msg=JSON.parse(text)?.message||text}catch{}throw new Error(msg)}
  return text?JSON.parse(text):null;
}

function setNet(label,color='#f4c45e'){
  $('netLabel').textContent=label;$('netDot').style.background=color;$('netDot').style.color=color;
}
function status(msg){$('statusMessage').textContent=msg}

function avatarTheme(key){
  const n=Number(String(key||'').match(/\d+/)?.[0]||1);
  const skins=['#c88f6f','#8b5f4a','#e0ae89','#704b3d','#b97755','#d59a75','#6d4635','#a46a50','#e1b19c','#815846'];
  const armors=['#2f6c5d','#4c3b70','#384e74','#6f4838','#24565d','#594e32','#455b39','#5d385d','#285078','#6d3038'];
  return {skin:skins[(n-1)%skins.length],armor:armors[(n-1)%armors.length],num:String(n).padStart(2,'0')};
}
function renderParty(){
  const members=state.party?.members||[];
  const row=$('partyRow');row.innerHTML='';
  for(let slot=1;slot<=4;slot++){
    const m=members.find(x=>Number(x.slot)===slot);
    const box=document.createElement('div');box.className='player-slot'+(m?'':' empty');
    if(m){
      const t=avatarTheme(m.avatar_key);
      box.innerHTML=`<div class="pedestal"></div><div class="figure" style="--skin:${t.skin};--armor:${t.armor}"></div><div class="nameplate">${escapeHtml(m.display_name)}<small>${m.host?'PARTY LEADER':'READY'}</small></div>`;
    }else{
      box.innerHTML=`<div class="pedestal"></div><div class="figure" style="--skin:#41524b;--armor:#15231e"></div><div class="nameplate">OPEN SLOT<small>INVITE FRIEND</small></div>`;
      box.addEventListener('click',inviteFriend);
    }
    row.appendChild(box);
  }
  $('partyCode').textContent=state.party?.invite_code||'------';
  const me=members.find(x=>x.player_id===state.player?.player_id);
  if(me){
    const t=avatarTheme(me.avatar_key);$('avatarBadge').textContent=t.num;
  }
}
function escapeHtml(s=''){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}

async function bootstrap(){
  setNet('BOOTING','#f4c45e');
  const savedName=localStorage.getItem('horizon-display-name')||`Survivor-${ident.id.slice(0,4).toUpperCase()}`;
  $('displayName').value=savedName;
  state.config=await rpc('bridgepoint_horizon_bootstrap_v4300',{p_player_id:ident.id,p_player_secret:ident.secret,p_display_name:savedName});
  state.player=state.config.player;
  $('loadoutName').textContent=state.config.loadouts.find(x=>x.slot===state.player.selected_loadout)?.name||'Ranger';

  const invite=(qs.get('party')||'').trim().toUpperCase();
  if(invite){
    try{
      const joined=await rpc('bridgepoint_horizon_join_party_v4300',{p_player_id:ident.id,p_player_secret:ident.secret,p_invite_code:invite});
      state.party=joined.party;status(`Joined ${invite}`);
    }catch(e){console.warn(e);status('Invite unavailable. Opening your own party…')}
  }
  if(!state.party){
    const opened=await rpc('bridgepoint_horizon_open_party_v4300',{p_player_id:ident.id,p_player_secret:ident.secret});
    state.party=opened.party;
  }
  state.selectedMode=state.party.selected_mode||'TDM';
  markMode();
  renderParty();
  setNet('ONLINE','#44f3bd');
  status('Lobby ready · invite friends or choose a mode');
  connectPartySignal();
  setInterval(refreshParty,1800);
}
async function refreshParty(){
  try{
    const snap=await rpc('bridgepoint_horizon_party_snapshot_v4300',{p_player_id:ident.id,p_player_secret:ident.secret});
    if(snap?.party){state.party=snap.party;renderParty();markMode()}
  }catch(e){setNet('RETRYING','#f4c45e')}
}
function partyUrl(){
  const code=state.party?.invite_code||'';
  return `${location.origin}/app/horizon/play/?party=${encodeURIComponent(code)}`;
}
async function inviteFriend(){
  const url=partyUrl(),text=`Join my BridgePoint Horizon party: ${state.party?.invite_code||''}`;
  if(navigator.share){try{await navigator.share({title:'BridgePoint Horizon',text,url});return}catch{}}
  await navigator.clipboard.writeText(`${text}\n${url}`);status('Party invite copied');
}
$('inviteBtn').onclick=inviteFriend;$('inviteTop').onclick=inviteFriend;
$('copyParty').onclick=async()=>{await navigator.clipboard.writeText(state.party?.invite_code||'');status('Party code copied')};

$('displayName').addEventListener('change',async e=>{
  const name=e.target.value.trim().slice(0,32)||'Survivor';
  localStorage.setItem('horizon-display-name',name);
  try{
    const out=await rpc('bridgepoint_horizon_bootstrap_v4300',{p_player_id:ident.id,p_player_secret:ident.secret,p_display_name:name});
    state.player=out.player;await refreshParty();
  }catch(err){status(err.message)}
});

function markMode(){
  document.querySelectorAll('.mode').forEach(b=>b.classList.toggle('active',b.dataset.mode===state.selectedMode));
  const d=state.config?.modes?.find(m=>m.key===state.selectedMode);
  $('playSub').textContent=d?(d.solo?'SOLO · 3 lives':`${d.label==='Team Deathmatch'?'6v6':d.match_target+' players'}`):'';
}
document.querySelectorAll('.mode').forEach(btn=>btn.addEventListener('click',async()=>{
  const mode=btn.dataset.mode;
  const count=state.party?.members?.length||1;
  if(mode==='YEAR_ONE'&&count>1){status('Year One is solo. Leave the party to enter it.');return}
  const meHost=state.party?.host_player_id===ident.id;
  if(!meHost){status('Party leader chooses the mode');return}
  try{
    const snap=await rpc('bridgepoint_horizon_select_mode_v4300',{p_player_id:ident.id,p_player_secret:ident.secret,p_mode:mode});
    state.party=snap.party;state.selectedMode=mode;markMode();renderParty();
  }catch(e){status(e.message)}
}));

$('playBtn').onclick=async()=>{
  if(state.party?.host_player_id!==ident.id){status('Party leader starts matchmaking');return}
  $('playBtn').disabled=true;$('playLabel').textContent='QUEUING';
  try{
    const q=await rpc('bridgepoint_horizon_queue_v4300',{p_player_id:ident.id,p_player_secret:ident.secret});
    status(q.queued?'Finding match… direct P2P host will be elected':'Solo world ready');
    pollMatch();
  }catch(e){status(e.message);$('playBtn').disabled=false;$('playLabel').textContent='READY'}
};

let matchPoll=null;
async function pollMatch(){
  clearInterval(matchPoll);
  const check=async()=>{
    try{
      const r=await rpc('bridgepoint_horizon_match_snapshot_v4300',{p_player_id:ident.id,p_player_secret:ident.secret});
      if(r?.match){
        clearInterval(matchPoll);state.match=r.match;showLoading(r.match);return;
      }
      $('playLabel').textContent='SEARCHING';
    }catch(e){status(e.message)}
  };
  await check();matchPoll=setInterval(check,1000);
}

function hashSeed(x){
  let h=2166136261>>>0;for(const c of String(x)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return BigInt(h||1);
}
function drawMap(match){
  const c=$('mapCanvas'),g=c.getContext('2d'),rng=new DeterministicRng(hashSeed(match.seed));
  const palettes={
    'toxic-dawn':['#0c2b24','#2a5d4d','#73ffc6','#e1bf66'],
    'storm-violet':['#15122e','#39325f','#8d76ff','#71e9d0'],
    'ember-night':['#21120f','#5a3021','#e46a45','#f5c76b'],
    'cold-moon':['#0f2026','#23424e','#65bcd2','#d8f4ed']
  };
  const p=palettes[match.map_palette]||palettes['cold-moon'];
  g.fillStyle=p[0];g.fillRect(0,0,c.width,c.height);
  g.strokeStyle='rgba(255,255,255,.07)';g.lineWidth=2;
  for(let i=0;i<9;i++){const y=40+i*58;g.beginPath();g.moveTo(0,y);g.lineTo(c.width,y+rng.int(-25,25));g.stroke()}
  for(let i=0;i<13;i++){const x=35+i*70;g.beginPath();g.moveTo(x,0);g.lineTo(x+rng.int(-35,35),c.height);g.stroke()}
  const labels=['HIGHRISE','RAIL YARD','MARKET','GARAGE','WATERFRONT','HOSPITAL','WAREHOUSE','SUBSTATION','OLD TOWN','ROOFTOPS'];
  for(let i=0;i<28;i++){
    const x=rng.int(22,c.width-145),y=rng.int(30,c.height-90),w=rng.int(45,125),h=rng.int(28,82);
    g.fillStyle=i%5===0?p[1]:'rgba(12,25,22,.88)';g.fillRect(x,y,w,h);
    g.strokeStyle=i%7===0?p[2]:'rgba(255,255,255,.09)';g.strokeRect(x,y,w,h);
  }
  g.font='700 16px system-ui';g.fillStyle='rgba(235,255,247,.86)';
  labels.slice(0,6).forEach((l,i)=>g.fillText(l,rng.int(40,c.width-180),60+i*72));
  g.font='900 12px system-ui';g.fillStyle=p[2];g.fillText('SPAWN A',40,c.height-35);g.fillStyle=p[3];g.fillText('SPAWN B',c.width-115,36);
}
function idbOpen(){
  return new Promise((resolve,reject)=>{
    const req=indexedDB.open('bridgepoint-horizon-cache',2);
    req.onupgradeneeded=()=>{const db=req.result;if(!db.objectStoreNames.contains('worldCells'))db.createObjectStore('worldCells')};
    req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);
  });
}
async function cacheGet(key){
  try{const db=await idbOpen();return await new Promise((resolve,reject)=>{const tx=db.transaction('worldCells','readonly'),r=tx.objectStore('worldCells').get(key);r.onsuccess=()=>resolve(r.result||null);r.onerror=()=>reject(r.error)})}catch{return null}
}
async function cachePut(key,value){
  try{const db=await idbOpen();await new Promise((resolve,reject)=>{const tx=db.transaction('worldCells','readwrite');tx.objectStore('worldCells').put(value,key);tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error)})}catch{}
}
function deviceClass(){
  const mem=Number(navigator.deviceMemory||0),cores=Number(navigator.hardwareConcurrency||0);
  if(/Android|iPhone|iPad/i.test(navigator.userAgent))return mem>=8||cores>=8?'mobile-high':'mobile';
  return 'desktop';
}
async function loadWorldCell(match){
  const m=match.metadata||{},stateCode=m.world_state,lat=Number(m.world_lat),lon=Number(m.world_lon),span=Number(m.world_span_km||3.2);
  if(!stateCode||!Number.isFinite(lat)||!Number.isFinite(lon))return null;
  const key=`v3022:${stateCode}:${lat.toFixed(4)}:${lon.toFixed(4)}:${span.toFixed(1)}`;
  const cached=await cacheGet(key);
  if(cached?.payload){$('loadingStatus').textContent='World cell loaded from this phone’s cache…';return cached.payload}
  $('loadingStatus').textContent='Streaming buildings, terrain, roads and water for this match…';
  const url=new URL(`${SUPABASE_URL}/functions/v1/bridgepoint-horizon-stream-v3020`);
  url.searchParams.set('state',stateCode);url.searchParams.set('lat',String(lat));url.searchParams.set('lon',String(lon));url.searchParams.set('span_km',String(span));
  const r=await fetch(url,{headers:{apikey:PUBLISHABLE_KEY}});
  if(!r.ok)throw new Error('WORLD_CELL_'+r.status);
  const payload=await r.json();
  if(payload?.complete===false)throw new Error(payload.error||'WORLD_CELL_FAILED');
  payload.procedural_cover=generateCover(hashSeed(match.seed),18);
  await cachePut(key,{saved_at:Date.now(),payload});
  return payload;
}
async function waitForSynchronizedStart(match){
  const started=performance.now();
  try{
    state.worldCell=await loadWorldCell(match);
    $('loadbarFill').style.width='72%';
    const ready=await rpc('bridgepoint_horizon_match_ready_v4302',{
      p_player_id:ident.id,p_player_secret:ident.secret,p_match_id:match.match_id,
      p_loaded_build:'web-v4302',p_ping_ms:Math.round(performance.now()-started),p_device_class:deviceClass()
    });
    $('loadingStatus').textContent=ready.all_humans_ready?'Everyone is loaded. Synchronizing launch…':`${ready.humans_ready}/${ready.humans_total} players loaded…`;
  }catch(e){
    console.warn(e);$('loadingStatus').textContent='World stream degraded; deterministic fallback is ready.';
    await rpc('bridgepoint_horizon_match_ready_v4302',{
      p_player_id:ident.id,p_player_secret:ident.secret,p_match_id:match.match_id,
      p_loaded_build:'web-v4302-fallback',p_ping_ms:null,p_device_class:deviceClass()
    }).catch(()=>{});
  }

  return new Promise(resolve=>{
    const poll=setInterval(async()=>{
      try{
        const r=await rpc('bridgepoint_horizon_match_snapshot_v4300',{p_player_id:ident.id,p_player_secret:ident.secret});
        if(!r?.match)return;
        state.match=r.match;
        const readyCount=r.match.members.filter(x=>x.loaded).length;
        $('loadingStatus').textContent=`${readyCount}/${r.match.human_players} players loaded · same seed locked on every device`;
        if(r.match.starts_at){clearInterval(poll);resolve(r.match)}
      }catch{}
    },500);
  });
}
async function showLoading(match){
  $('loading').classList.add('show');$('loading').setAttribute('aria-hidden','false');
  $('mapName').textContent=String(match.map_label||'HORIZON SECTOR').toUpperCase();
  $('modeMeta').textContent=match.mode;$('humanMeta').textContent=`${match.human_players} HUMANS`;$('botMeta').textContent=`${match.bot_players} BOTS`;
  drawMap(match);$('loadbarFill').style.width='10%';
  const synchronized=await waitForSynchronizedStart(match);
  connectMatchSignal(synchronized);startHostLease(synchronized);
  const start=Date.parse(synchronized.starts_at);
  const timer=setInterval(()=>{
    const left=Math.max(0,start-Date.now()),sec=Math.ceil(left/1000);
    $('launchCount').textContent=sec;$('loadbarFill').style.width=`${Math.max(78,100-left/70)}%`;
    if(left<=0){
      clearInterval(timer);$('loadingStatus').textContent='World seed locked. Phone-side runtime ready.';
      $('loadbarFill').style.width='100%';$('launchCount').textContent='GO';$('hudPreview').classList.add('show');
      setTimeout(()=>{$('loading').classList.remove('show')},1100);
    }
  },100);
}

function weaponSvg(name){
  const type=/shotgun|rifle|smg|lmg|sidearm|pistol|revolver/i.test(name)?'gun':/grenade|betty|claymore|charge|decoy/i.test(name)?'grenade':'melee';
  if(type==='gun')return `<svg viewBox="0 0 80 36"><path d="M6 13h41l8 5h18v7H54l-7 4H30l-5-7H6z"/><path d="M38 25h8l4 10H39z"/></svg>`;
  if(type==='grenade')return `<svg viewBox="0 0 80 36"><path d="M29 9h24l7 8-4 15H26l-5-15z"/><path d="M37 3h12v7H37z"/></svg>`;
  return `<svg viewBox="0 0 80 36"><path d="M8 25 61 6l5 6-52 20z"/><path d="m56 5 11-4 6 9-9 5z"/></svg>`;
}
function openModal(tab){
  const c=$('modalContent');
  if(tab==='LOADOUTS'){
    c.innerHTML=`<div class="eyebrow">PRE-MATCH LOADOUTS</div><h1>Choose one of five Horizon kits</h1><p style="color:#95aaa0">TDM and Extraction lock this choice when the match starts.</p><div class="catalog-grid">${state.config.loadouts.map(l=>`<article class="catalog-card ${l.slot===state.player.selected_loadout?'selected':''}" data-loadout="${l.slot}"><span class="eyebrow">LOADOUT ${l.slot}</span><h3>${l.name}</h3>${['primary','secondary','tactical','lethal','melee','field'].map(k=>`<div class="item-row"><div class="weapon-svg">${weaponSvg(l[k])}</div><div><small style="color:#95aaa0">${k.toUpperCase()}</small><br><b>${l[k]}</b></div></div>`).join('')}</article>`).join('')}</div>`;
  }else if(tab==='LOCKER'){
    c.innerHTML=`<div class="eyebrow">LOCKER</div><h1>Free survivor rotation</h1><p style="color:#95aaa0">Ten starter characters are available. Your device receives one automatically; cosmetics can change the look without changing stats.</p><div class="catalog-grid">${state.config.free_characters.map(k=>{const t=avatarTheme(k);return `<article class="catalog-card ${k===state.player.avatar_key?'selected':''}" data-avatar="${k}"><div class="avatar-badge" style="--skin:${t.skin};background:linear-gradient(145deg,${t.skin},${t.armor})">${t.num}</div><h3>Survivor ${t.num}</h3><small>FREE</small></article>`}).join('')}</div>`;
  }else if(tab==='BATTLE_PASS'){
    c.innerHTML=`<div class="eyebrow">BATTLE PASS</div><h1>150-level monthly track</h1><p style="color:#95aaa0">Cosmetics, wraps, emotes, character variants and blueprints. Commerce remains disabled until you explicitly approve it.</p><div class="catalog-grid">${[1,15,30,60,100].map((n,i)=>`<article class="catalog-card"><span class="eyebrow">LEVEL ${n}</span><h3>${['Founder Cache','Hazmat Wrap','Night Runner','Rooftop Raider','Blackout Legend'][i]}</h3><p style="color:#95aaa0;font-size:11px">Preview reward slot</p></article>`).join('')}</div>`;
  }else if(tab==='STORE'){
    c.innerHTML=`<div class="eyebrow">STORE</div><h1>Store preview</h1><p style="color:#95aaa0">The storefront surface exists, but purchasing is intentionally locked. Stripe/payment wiring stays off until final approval.</p>`;
  }else if(tab==='ARENA'){
    c.innerHTML=`<div class="eyebrow">ARENA</div><h1>Competitive queue</h1><p style="color:#95aaa0">Arena routes into Team Deathmatch using the same 12-player low-latency P2P-first transport, with ranked rules layered on top later.</p>`;
  }else{
    c.innerHTML=`<div class="eyebrow">HORIZON</div><h1>Lobby settings</h1><p style="color:#95aaa0">Aim: toggle · Pickup: 1.75s dwell · Killcam: 5s before / slow-motion kill / 5s after · Build button is the single large right-side control.</p>`;
  }
  $('modal').classList.add('show');$('modal').setAttribute('aria-hidden','false');
}
$('closeModal').onclick=()=>$('modal').classList.remove('show');
$('modal').addEventListener('click',e=>{if(e.target===$('modal'))$('modal').classList.remove('show')});
$('settingsBtn').onclick=()=>openModal('SETTINGS');$('editLocker').onclick=()=>openModal('LOCKER');
document.querySelectorAll('#tabs button').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('#tabs button').forEach(x=>x.classList.toggle('active',x===b));
  if(b.dataset.tab!=='PLAY')openModal(b.dataset.tab);
});
$('modalContent').addEventListener('click',async e=>{
  const loadout=e.target.closest('[data-loadout]');
  if(loadout){
    const slot=Number(loadout.dataset.loadout);
    try{
      const out=await rpc('bridgepoint_horizon_set_profile_v4302',{
        p_player_id:ident.id,p_player_secret:ident.secret,p_avatar_key:null,p_wrap_key:null,p_loadout:slot
      });
      state.player=out.player;localStorage.setItem('horizon-loadout',String(slot));
      $('loadoutName').textContent=state.config.loadouts.find(x=>x.slot===slot)?.name||'Ranger';
      document.querySelectorAll('[data-loadout]').forEach(x=>x.classList.toggle('selected',Number(x.dataset.loadout)===slot));
    }catch(err){status(err.message)}
    return;
  }
  const avatar=e.target.closest('[data-avatar]');
  if(avatar){
    try{
      const out=await rpc('bridgepoint_horizon_set_profile_v4302',{
        p_player_id:ident.id,p_player_secret:ident.secret,p_avatar_key:avatar.dataset.avatar,p_wrap_key:null,p_loadout:null
      });
      state.player=out.player;await refreshParty();
      document.querySelectorAll('[data-avatar]').forEach(x=>x.classList.toggle('selected',x.dataset.avatar===state.player.avatar_key));
    }catch(err){status(err.message)}
  }
});

function connectPartySignal(){
  if(!sb||!state.party?.invite_code)return;
  const ch=sb.channel(`horizon-party:${state.party.invite_code}`,{config:{broadcast:{self:false}}});
  ch.on('broadcast',{event:'party-ping'},()=>refreshParty()).subscribe(status=>{if(status==='SUBSCRIBED')ch.send({type:'broadcast',event:'party-ping',payload:{player_id:ident.id}})});
  state.channel=ch;
}

const peerConfig={iceServers:[{urls:['stun:stun.l.google.com:19302','stun:stun1.l.google.com:19302']}]};
let hostLeaseTimer=null;
async function hostLeaseTick(){
  const m=state.match;if(!m?.match_id)return;
  try{
    if(m.host_player_id===ident.id){
      const hb=await rpc('bridgepoint_horizon_host_heartbeat_v4303',{
        p_player_id:ident.id,p_player_secret:ident.secret,p_match_id:m.match_id
      });
      if(hb?.host_player_id)state.match.host_player_id=hb.host_player_id;
      return;
    }
    const hostMember=m.members?.find(x=>x.player_id===m.host_player_id);
    const rec=hostMember?state.peers.get(hostMember.player_id):null;
    if(rec?.pc?.connectionState==='connected')return;
    const claim=await rpc('bridgepoint_horizon_claim_host_v4303',{
      p_player_id:ident.id,p_player_secret:ident.secret,p_match_id:m.match_id
    });
    if(claim?.host_player_id&&claim.host_player_id!==state.match.host_player_id){
      state.match.host_player_id=claim.host_player_id;
      $('peerMeta').textContent=claim.host_player_id===ident.id?'HOST MIGRATED TO YOU':'HOST MIGRATED';
      if(state.channel){
        state.channel.send({type:'broadcast',event:'hello',payload:{player_id:ident.id,host_epoch:claim.host_epoch}});
      }
    }
  }catch(e){console.warn('host lease',e)}
}
function startHostLease(match){
  state.match=match;clearInterval(hostLeaseTimer);hostLeaseTimer=setInterval(hostLeaseTick,2500);
  hostLeaseTick();
}

function connectMatchSignal(match){
  if(!sb)return;
  if(state.channel)sb.removeChannel(state.channel).catch(()=>{});
  const ch=sb.channel(match.network_topic,{config:{broadcast:{self:false}}});
  ch.on('broadcast',{event:'hello'},({payload})=>{if(payload?.player_id&&payload.player_id!==ident.id&&match.host_player_id===ident.id)makeOffer(payload.player_id,ch)})
    .on('broadcast',{event:'signal'},({payload})=>handleSignal(payload,ch))
    .subscribe(s=>{
      if(s==='SUBSCRIBED'){
        setNet('P2P SIGNALING','#64d7ff');
        ch.send({type:'broadcast',event:'hello',payload:{player_id:ident.id}});
        $('peerMeta').textContent=match.host_player_id===ident.id?'YOU ARE HOST':'P2P JOINING';
      }
    });
  state.channel=ch;
}
function pcFor(peerId,ch,initiator=false){
  let rec=state.peers.get(peerId);if(rec)return rec.pc;
  const pc=new RTCPeerConnection(peerConfig);rec={pc,dc:null};state.peers.set(peerId,rec);
  pc.onicecandidate=e=>{if(e.candidate)ch.send({type:'broadcast',event:'signal',payload:{from:ident.id,to:peerId,candidate:e.candidate}})};
  pc.onconnectionstatechange=()=>{
    if(pc.connectionState==='connected'){setNet('P2P DIRECT','#44f3bd');$('peerMeta').textContent=`${[...state.peers.values()].filter(x=>x.pc.connectionState==='connected').length+1} DIRECT`}
  };
  if(initiator){const dc=pc.createDataChannel('horizon-game',{ordered:false,maxRetransmits:0});wireData(peerId,dc)}
  pc.ondatachannel=e=>wireData(peerId,e.channel);
  return pc;
}
function wireData(peerId,dc){
  const rec=state.peers.get(peerId);if(rec)rec.dc=dc;
  dc.onopen=()=>{dc.send(JSON.stringify({t:'hello',player_id:ident.id,seed:state.match?.seed}))};
  dc.onmessage=e=>{try{const m=JSON.parse(e.data);if(m.t==='snapshot')state.killcam.push(m.s)}catch{}};
}
async function makeOffer(peerId,ch){
  const pc=pcFor(peerId,ch,true),offer=await pc.createOffer();await pc.setLocalDescription(offer);
  ch.send({type:'broadcast',event:'signal',payload:{from:ident.id,to:peerId,sdp:pc.localDescription}});
}
async function handleSignal(p,ch){
  if(!p||p.to!==ident.id||!p.from)return;
  const pc=pcFor(p.from,ch,false);
  if(p.sdp){
    await pc.setRemoteDescription(p.sdp);
    if(p.sdp.type==='offer'){const ans=await pc.createAnswer();await pc.setLocalDescription(ans);ch.send({type:'broadcast',event:'signal',payload:{from:ident.id,to:p.from,sdp:pc.localDescription}})}
  }else if(p.candidate){try{await pc.addIceCandidate(p.candidate)}catch{}}
}

async function emitGhostEvent(type,eventKey,payload={},ttlSeconds=86400){
  if(!state.match?.match_id)return null;
  const cellKey=state.match.cell_seed||String(state.match.metadata?.world_state||'UNKNOWN');
  return rpc('bridgepoint_horizon_emit_world_event_v4303',{
    p_player_id:ident.id,p_player_secret:ident.secret,p_match_id:state.match.match_id,
    p_cell_key:cellKey,p_event_type:type,p_event_key:eventKey,p_payload:payload,p_ttl_seconds:ttlSeconds
  });
}
async function loadGhostEvents(){
  if(!state.match)return[];
  const cellKey=state.match.cell_seed||String(state.match.metadata?.world_state||'UNKNOWN');
  const out=await rpc('bridgepoint_horizon_world_events_v4303',{
    p_player_id:ident.id,p_player_secret:ident.secret,p_cell_key:cellKey,p_limit:100
  }).catch(()=>({events:[]}));
  return out?.events||[];
}

function animateSky(){
  const c=$('sky'),g=c.getContext('2d'),dpr=Math.min(2,devicePixelRatio||1);let pts=[];
  function resize(){c.width=innerWidth*dpr;c.height=innerHeight*dpr;c.style.width=innerWidth+'px';c.style.height=innerHeight+'px';g.setTransform(dpr,0,0,dpr,0,0);pts=Array.from({length:Math.min(120,Math.floor(innerWidth/9))},()=>({x:Math.random()*innerWidth,y:Math.random()*innerHeight,r:Math.random()*1.5+.3,s:Math.random()*.18+.03}))}
  addEventListener('resize',resize);resize();
  function frame(){g.clearRect(0,0,innerWidth,innerHeight);for(const p of pts){p.y-=p.s;if(p.y<0)p.y=innerHeight;g.fillStyle='rgba(174,255,226,.22)';g.beginPath();g.arc(p.x,p.y,p.r,0,Math.PI*2);g.fill()}requestAnimationFrame(frame)}frame();
}

state.pickup=new DwellPickupController({onProgress:(p)=>{document.documentElement.style.setProperty('--pickup',String(p))}});
animateSky();
bootstrap().catch(e=>{console.error(e);setNet('BACKEND ERROR','#ff5d71');status(e.message)});
if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{});
