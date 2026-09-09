import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const VERSION = 2501;
const SUPABASE_URL = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const SUPABASE_KEY = 'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const finite = (v) => Number.isFinite(Number(v)) ? Number(v) : null;
const fmt = (v, digits = 0) => finite(v) === null ? '—' : Number(v).toLocaleString(undefined,{maximumFractionDigits:digits});
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

function timeout(ms, label){ return new Promise((_, reject) => setTimeout(() => reject(new Error(`${label} timeout`)), ms)); }
async function rpc(name, params = {}, ms = 9000){
  return Promise.race([
    supabase.rpc(name, params).then(({data,error}) => { if(error) throw error; return data; }),
    timeout(ms, name)
  ]);
}

async function waitForWorld(){
  for(let i=0;i<160;i++){
    if(window.BridgePointWorldV2500?.viewer) return window.BridgePointWorldV2500;
    await sleep(100);
  }
  throw new Error('BridgePoint World V2500 runtime not available');
}

function injectStyles(){
  if(document.getElementById('bpV2501Styles')) return;
  const style=document.createElement('style');
  style.id='bpV2501Styles';
  style.textContent=`
    #bpSystemPulse{margin-top:10px;padding:10px;border:1px solid rgba(255,201,94,.24);border-radius:12px;background:rgba(2,7,17,.48)}
    #bpSystemPulse .bpPulseTitle{font-size:11px;font-weight:900;letter-spacing:.08em;text-transform:uppercase;color:#ffd67a;margin-bottom:7px}
    #bpSystemPulse .bpPulseGrid,.bpIntelGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px}
    #bpSystemPulse .bpMetric,.bpIntelMetric{padding:7px 8px;border-radius:9px;background:rgba(255,255,255,.045);border:1px solid rgba(255,255,255,.07)}
    #bpSystemPulse .bpMetric b,.bpIntelMetric b{display:block;font-size:13px;color:#fff}.bpMetric small,.bpIntelMetric small{font-size:9px;color:#aebfc9;text-transform:uppercase;letter-spacing:.04em}
    .bpIntelSection{margin-top:10px;padding-top:10px;border-top:1px solid rgba(255,255,255,.10)}
    .bpIntelSection h3{margin:0 0 7px;font-size:12px;color:#ffd67a}.bpIntelText{font-size:11px;line-height:1.45;color:#d8e4ea}.bpIntelMuted{font-size:10px;line-height:1.4;color:#9fb0ba;margin-top:6px}
    .bpIntelBadge{display:inline-block;margin:2px 4px 2px 0;padding:3px 6px;border-radius:999px;background:rgba(72,225,255,.09);border:1px solid rgba(72,225,255,.22);font-size:9px;color:#c9f7ff}
    .bpIntelBadge.gold{background:rgba(255,177,59,.1);border-color:rgba(255,177,59,.25);color:#ffd98d}
    #bpV2501Intel .bpRetry{margin-top:8px}
    @media(max-width:700px){#bpSystemPulse .bpPulseGrid,.bpIntelGrid{grid-template-columns:1fr 1fr}}
  `;
  document.head.appendChild(style);
}

function viewRect(viewer){
  const r=viewer.camera.computeViewRectangle(viewer.scene.globe.ellipsoid); if(!r) return null;
  return {west:Cesium.Math.toDegrees(r.west),south:Cesium.Math.toDegrees(r.south),east:Cesium.Math.toDegrees(r.east),north:Cesium.Math.toDegrees(r.north)};
}
function cameraHeight(viewer){ return viewer.camera.positionCartographic?.height || 1e7; }
function rings(g){
  if(g?.type==='Polygon') return g.coordinates?.[0]?[g.coordinates[0]]:[];
  if(g?.type==='MultiPolygon') return (g.coordinates||[]).map(p=>p?.[0]).filter(Boolean);
  return [];
}
function coords(ring){
  const out=[]; for(const p of ring||[]) if(Number.isFinite(+p[0])&&Number.isFinite(+p[1])) out.push(+p[0],+p[1]);
  return out.length>=6?out:null;
}
function centerFromGeometry(g){
  const ring=rings(g)[0]; if(!ring?.length) return null;
  let x=0,y=0,n=0; for(const p of ring){ if(Number.isFinite(+p[0])&&Number.isFinite(+p[1])){x+=+p[0];y+=+p[1];n++;} }
  return n?[x/n,y/n]:null;
}
function scoreColor(score){ const s=finite(score); return s!==null&&s>=82?'#ff9e35':s!==null&&s>=70?'#ffd15d':'#48e1ff'; }

function human(k){return String(k||'').replace(/_/g,' ').replace(/\b\w/g,c=>c.toUpperCase());}
function deepFind(obj, keys){
  if(!obj||typeof obj!=='object') return null;
  for(const k of keys) if(obj[k]!==undefined&&obj[k]!==null&&obj[k]!=='' ) return obj[k];
  for(const v of Object.values(obj)) if(v&&typeof v==='object'&&!Array.isArray(v)){const found=deepFind(v,keys);if(found!==null)return found;}
  return null;
}
function collectCounts(obj, rx, out={}, depth=0){
  if(!obj||typeof obj!=='object'||depth>4) return out;
  for(const [k,v] of Object.entries(obj)){
    if(Array.isArray(v)&&rx.test(k)) out[k]=v.length;
    else if(typeof v==='number'&&rx.test(k)&&/(count|total|number|records|events|signals|patterns|opportunities|evidence)/i.test(k)) out[k]=v;
    else if(v&&typeof v==='object') collectCounts(v,rx,out,depth+1);
  }
  return out;
}
function entityPropertyId(entity){
  const direct=entity?.bridgepoint?.property_id||entity?.bridgepoint?.id;
  if(direct) return String(direct);
  try{
    const bag=entity?.properties;
    const v=bag?.property_id?.getValue?.(Cesium.JulianDate.now()) ?? bag?.property_id?._value;
    return v?String(v):null;
  }catch(_){return null;}
}
function entityPoint(entity){
  const b=entity?.bridgepoint||{};
  const lon=finite(b.longitude??b.lng??b.lon),lat=finite(b.latitude??b.lat);
  if(lon!==null&&lat!==null) return [lon,lat];
  return centerFromGeometry(b.geometry||b.geometry_geojson||b.geom_geojson||b.footprint);
}

async function init(){
  injectStyles();
  const world=await waitForWorld();
  const viewer=world.viewer;
  const layerPanel=document.getElementById('layerPanel');
  const layerGrid=layerPanel?.querySelector('.layerGrid');
  const card=document.getElementById('propertyCard');
  const status=document.getElementById('status');

  const opportunities=new Cesium.CustomDataSource('bp-v2501-opportunities');
  viewer.dataSources.add(opportunities);
  let opportunitiesOn=true, oppBusy=false, oppPending=false, lastOppKey='';
  let activePropertyId=null;
  const intelCache=new Map();
  const intelInflight=new Map();
  let pulseTimer=null;

  const oppButton=document.createElement('button');
  oppButton.id='bpOpportunityLayerButton';
  oppButton.className='active';
  oppButton.textContent='Verified opportunities';
  oppButton.title='Source/evidence-gated BridgePoint opportunities';
  layerGrid?.appendChild(oppButton);
  oppButton.onclick=()=>{opportunitiesOn=!opportunitiesOn;opportunities.show=opportunitiesOn;oppButton.classList.toggle('active',opportunitiesOn);viewer.scene.requestRender();if(opportunitiesOn)refreshOpportunities(true);};

  const pulse=document.createElement('div');
  pulse.id='bpSystemPulse';
  pulse.innerHTML='<div class="bpPulseTitle">Live BridgePoint system pulse</div><div class="bpIntelMuted">Loading governed national progress…</div>';
  layerPanel?.appendChild(pulse);

  async function refreshPulse(){
    const jobs=[
      ['parcels','bridgepoint_public_parcel_progress_v956',{}],
      ['national','bridgepoint_public_national_progress_v1053',{}],
      ['physical','bridgepoint_owner_physical_world_counters_v2020',{}]
    ];
    const settled=await Promise.allSettled(jobs.map(async ([key,name,params])=>[key,await rpc(name,params,7000)]));
    const data={}; for(const r of settled) if(r.status==='fulfilled') data[r.value[0]]=r.value[1];
    const p=data.parcels||{}, n=data.national||{}, ph=data.physical||{};
    const totals=n.totals||{};
    const physicalCounts=ph.totals||ph.counts||ph;
    const metrics=[
      ['Canonical',p.total_parcels??totals.canonical_properties],
      ['States + jurisdictions',p.jurisdictions_present??p.states_present??totals.states_tracked],
      ['Accepted sources',totals.accepted_sources],
      ['Matched signal properties',totals.matched_signal_properties],
      ['Buildings / geometry',deepFind(physicalCounts,['universal_buildings','building_geometry','buildings','building_count','geometry_count'])],
      ['Parcel boundaries',deepFind(physicalCounts,['parcel_boundaries','boundary_count','parcel_boundary_count'])],
      ['Claims lifecycle',deepFind(physicalCounts,['claims_lifecycle','claims_context','lifecycle_count','claims_count'])],
      ['Roof geometry',deepFind(physicalCounts,['roof_planes','roof_geometry','roof_count'])]
    ].filter(([,v])=>v!==undefined&&v!==null);
    pulse.innerHTML=`<div class="bpPulseTitle">Live BridgePoint system pulse · V${VERSION}</div><div class="bpPulseGrid">${metrics.map(([k,v])=>`<div class="bpMetric"><b>${esc(fmt(v))}</b><small>${esc(k)}</small></div>`).join('')}</div><div class="bpIntelMuted">${esc(p.parcel_acquisition_notice||n.parcel_acquisition_notice||'Governed ingestion and matching remain live.')} ${p.remaining_to_163m!=null?`${fmt(p.remaining_to_163m)} to the 163M target.`:''}</div>`;
  }

  function renderOpportunities(fc){
    opportunities.entities.removeAll();
    const features=fc?.features||[];
    for(const [i,f] of features.entries()){
      const props=f.properties||{}, color=scoreColor(props.score);
      for(const ring of rings(f.geometry)){
        const d=coords(ring); if(!d) continue;
        const e=opportunities.entities.add({
          id:`bp-v2501-opportunity-${props.opportunity_id||i}-${opportunities.entities.values.length}`,
          polygon:{
            hierarchy:Cesium.Cartesian3.fromDegreesArray(d),
            height:2,
            material:Cesium.Color.fromCssColorString(color).withAlpha(.13),
            outline:true,
            outlineColor:Cesium.Color.fromCssColorString(color).withAlpha(.95),
            distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,95000)
          }
        });
        e.bridgepoint={...props,geometry:f.geometry,source_name:'BridgePoint verified opportunity',truth_label:'evidence-gated opportunity',render_score:props.score};
      }
    }
    opportunities.show=opportunitiesOn;
    viewer.scene.requestRender();
  }

  async function refreshOpportunities(force=false){
    if(!opportunitiesOn) return;
    if(oppBusy){oppPending=true;return;}
    const h=cameraHeight(viewer); if(h>180000){opportunities.entities.removeAll();viewer.scene.requestRender();return;}
    const v=viewRect(viewer); if(!v||v.east<=v.west) return;
    const key=[v.west,v.south,v.east,v.north].map(x=>x.toFixed(h<5000?3:2)).join(':');
    if(!force&&key===lastOppKey) return;
    lastOppKey=key; oppBusy=true;
    try{
      const data=await rpc('bridgepoint_opportunity_buildings_viewport_v2180',{p_west:v.west,p_south:v.south,p_east:v.east,p_north:v.north,p_limit:120},8500);
      if(!data?.locked) renderOpportunities(data?.geojson||{type:'FeatureCollection',features:[]});
      else opportunities.entities.removeAll();
    }catch(e){console.warn('V2501 opportunity overlay',e);}
    finally{oppBusy=false;if(oppPending){oppPending=false;queueMicrotask(()=>refreshOpportunities(true));}}
  }

  function intelSection(title, body){return `<div class="bpIntelSection"><h3>${esc(title)}</h3>${body}</div>`;}
  function metricsGrid(items){
    const clean=items.filter(([,v])=>v!==undefined&&v!==null&&v!==''); if(!clean.length) return '';
    return `<div class="bpIntelGrid">${clean.map(([k,v])=>`<div class="bpIntelMetric"><b>${esc(String(v))}</b><small>${esc(k)}</small></div>`).join('')}</div>`;
  }
  function countBadges(obj){
    const counts=collectCounts(obj,/(claim|lifecycle|evidence|signal|pattern|opportun|permit|weather|hazard)/i);
    return Object.entries(counts).slice(0,10).map(([k,v])=>`<span class="bpIntelBadge">${esc(human(k))}: ${esc(fmt(v))}</span>`).join('');
  }
  function imagerySummary(data){
    const history=Array.isArray(data?.history)?data.history:[];
    if(!history.length) return '<div class="bpIntelMuted">No source-backed historical imagery references are available for this property yet.</div>';
    const dates=history.slice(0,6).map(x=>x?.captured_at||x?.capture_date||x?.imagery_date||x?.year||x?.date).filter(Boolean);
    return `${metricsGrid([['Frames / references',data.count??history.length]])}${dates.length?`<div class="bpIntelMuted">Recent source dates: ${esc(dates.join(' · '))}</div>`:''}<div class="bpIntelMuted">Historical imagery is evidence/context; visual differences are not automatically treated as confirmed property change.</div>`;
  }
  function renderIntel(pid, payload, loading=false, error=null){
    if(!card?.classList.contains('open')) return;
    let root=document.getElementById('bpV2501Intel');
    if(!root){root=document.createElement('div');root.id='bpV2501Intel';card.appendChild(root);}
    const h=payload?.heartbeat||{}, m=payload?.match||{}, terrain=payload?.terrain||{}, imagery=payload?.imagery||{}, score=payload?.score||{}, snap=payload?.snapshot||{}, scene=payload?.scene||{}, evidence=payload?.evidence||{}, site3d=payload?.site3d||{};
    const scoreValue=deepFind(score,['customer_score','score','property_score','current_score']) ?? h.opportunity_strength;
    const confidence=deepFind(score,['confidence_label','confidence','direct_confidence']) ?? h.confidence_label;
    const siteCount=Object.values(collectCounts(site3d,/(building|structure|geometry|roof|parcel|part)/i)).reduce((a,b)=>a+(Number(b)||0),0);
    const evidenceBadges=countBadges({snapshot:snap,scene,evidence});
    let html=`<div class="bpIntelSection"><h3>BridgePoint full intelligence · V${VERSION}</h3>${loading?'<div class="loadingRow"><i class="spinner"></i>Loading claims, evidence, score, imagery, roof/3D and terrain context…</div>':''}${error?`<div class="errorNote">${esc(error)}</div>`:''}</div>`;
    if(m?.resolved) html+=intelSection('Canonical property match',`${metricsGrid([['Address',m.display_address],['Parcel',m.parcel_number],['Match',m.match_method],['Distance',m.distance_m!=null?`${m.distance_m} m`:null]])}<div class="bpIntelMuted">${esc(m.match_notice||'Canonical BridgePoint property match.')}</div>`);
    if(h?.complete) html+=intelSection('Property heartbeat',`${metricsGrid([['State',h.state],['Confidence',confidence],['Opportunity strength',scoreValue!=null?fmt(scoreValue,1):null],['Evidence families',h.independent_evidence_families]])}<div class="bpIntelText"><b>${esc(h.headline||'')}</b>${h.why_it_matters?`<br>${esc(h.why_it_matters)}`:''}${h.recommended_next_step?`<br><span class="bpIntelMuted">Next: ${esc(h.recommended_next_step)}</span>`:''}</div>${Array.isArray(h.vitals)?`<div style="margin-top:6px">${h.vitals.map(v=>`<span class="bpIntelBadge ${v.state==='ACTIVE'?'gold':''}">${esc(v.name)} · ${esc(v.state)}</span>`).join('')}</div>`:''}`);
    if(evidenceBadges) html+=intelSection('Claims lifecycle · evidence · signals · patterns',`${evidenceBadges}<div class="bpIntelMuted">These are BridgePoint-linked intelligence/evidence counts and context. Public hazard or claims-area context does not by itself prove property damage or an insurance claim.</div>`);
    if(scoreValue!==null&&scoreValue!==undefined) html+=intelSection('Score / opportunity explanation',`${metricsGrid([['Score',fmt(scoreValue,1)],['Confidence',confidence],['Top concern',h.top_property_concern]])}<div class="bpIntelText">${esc(deepFind(score,['why_it_matters','why_now','explanation','reason','summary'])||'BridgePoint score explanation loaded from the governed customer contract.')}</div>`);
    html+=intelSection('Historical imagery',imagerySummary(imagery));
    html+=intelSection('3D / roof / terrain truth',`${metricsGrid([['3D/site records',siteCount||null],['Elevation',terrain.elevation_m!=null?`${fmt(terrain.elevation_m,1)} m`:null],['3DEP resolution',terrain.resolution_m!=null?`${fmt(terrain.resolution_m,1)} m`:null],['Terrain status',terrain.available===true?'SOURCE-BACKED':terrain.queued?'QUEUED':terrain.sample_status]])}<div class="bpIntelMuted">${esc(terrain.truth_note||'Exact source geometry wins. Missing roof/building/terrain detail is not fabricated.')}</div>`);
    html+=`<button class="bpRetry" id="bpV2501Retry" type="button">Refresh full intelligence</button>`;
    root.innerHTML=html;
    document.getElementById('bpV2501Retry')?.addEventListener('click',()=>loadIntelligence(pid,true));
  }

  async function loadIntelligence(pid, force=false, entity=null){
    if(!pid) return;
    activePropertyId=String(pid);
    if(!force&&intelCache.has(activePropertyId)){renderIntel(activePropertyId,intelCache.get(activePropertyId));return;}
    if(intelInflight.has(activePropertyId)) return intelInflight.get(activePropertyId);
    const point=entityPoint(entity);
    renderIntel(activePropertyId,intelCache.get(activePropertyId)||{},true);
    const task=(async()=>{
      const calls=[
        ['match','bridgepoint_map_click_property_v2002',{p_property_id:activePropertyId,p_lng:point?.[0]??null,p_lat:point?.[1]??null},4500],
        ['heartbeat','bridgepoint_property_heartbeat_v245',{p_property_id:activePropertyId},7500],
        ['snapshot','bridgepoint_property_intelligence_snapshot_v907',{p_property_id:activePropertyId},8000],
        ['score','bridgepoint_property_score_explainability_v1959',{p_property_id:activePropertyId},7500],
        ['imagery','bridgepoint_property_imagery_history_v169',{p_property_id:activePropertyId},7500],
        ['terrain','bridgepoint_property_terrain_v931',{p_property_id:activePropertyId},7500],
        ['site3d','bridgepoint_property_site_3d_v918',{p_property_id:activePropertyId,p_radius_m:180,p_limit:120},8500],
        ['evidence','bridgepoint_field_evidence_governance_v1966',{p_property_id:activePropertyId,p_limit:60},7000],
        ['scene','bridgepoint_property_4d_scene_v1957',{p_property_id:activePropertyId,p_at:new Date().toISOString(),p_timeline_limit:120},9000]
      ];
      const settled=await Promise.allSettled(calls.map(async([key,name,params,ms])=>[key,await rpc(name,params,ms)]));
      const payload={}; const errors=[];
      for(const r of settled){if(r.status==='fulfilled')payload[r.value[0]]=r.value[1];else errors.push(r.reason?.message||String(r.reason));}
      intelCache.set(activePropertyId,payload);
      if(activePropertyId===String(pid)) renderIntel(activePropertyId,payload,false,errors.length?`${errors.length} optional intelligence module${errors.length===1?'':'s'} did not answer; available truth is still shown.`:null);
      return payload;
    })().finally(()=>intelInflight.delete(String(pid)));
    intelInflight.set(String(pid),task); return task;
  }

  function openStandaloneProperty(entity,pid){
    const b=entity?.bridgepoint||{};
    card.innerHTML=`<div class="cardHead"><div><div class="cardTitle">${esc(b.full_address||b.address||b.title||'BridgePoint property')}</div><div class="cardSub">${esc(b.opportunity_name||b.opportunity_family||b.truth_label||'Canonical property intelligence')}</div></div><button id="bpStandaloneClose" class="closeButton" type="button">×</button></div><div class="truthNote">Loading the canonical property, claims/evidence, score, imagery, 3D/roof and terrain contracts.</div>`;
    card.classList.add('open');
    document.getElementById('bpStandaloneClose').onclick=()=>{card.classList.remove('open');activePropertyId=null;};
    loadIntelligence(pid,false,entity);
  }

  const handler=viewer.screenSpaceEventHandler;
  const prior=handler.getInputAction(Cesium.ScreenSpaceEventType.LEFT_CLICK);
  handler.setInputAction((movement)=>{
    const picked=viewer.scene.pick(movement.position), entity=picked?.id;
    try{ if(prior) prior(movement); }catch(e){console.warn('BridgePoint core click handler',e);}
    if(!entity) return;
    const id=String(entity.id||'');
    const pid=entityPropertyId(entity);
    if(id.startsWith('bp-v2501-opportunity-')&&entity.bridgepoint){
      world.selectBuilding?.(entity);
      if(pid) loadIntelligence(pid,false,entity);
      return;
    }
    if(pid){
      if(id.startsWith('building-')) loadIntelligence(pid,false,entity);
      else openStandaloneProperty(entity,pid);
      return;
    }
    if(id.startsWith('wx-')){
      const props=entity.properties;
      const now=Cesium.JulianDate.now();
      const kind=props?.kind?.getValue?.(now)||props?.kind?._value||'hazard';
      const event=props?.event?.getValue?.(now)||props?.event?._value||'Weather / hazard context';
      const observed=props?.observed?.getValue?.(now)??props?.observed?._value;
      card.innerHTML=`<div class="cardHead"><div><div class="cardTitle">${esc(event)}</div><div class="cardSub">${esc(kind)} · BridgePoint / public hazard context</div></div><button id="bpWeatherClose" class="closeButton" type="button">×</button></div><div class="truthNote">${observed?'Source marks this context as observed/current.':'Alert/forecast/context only.'} This does not by itself prove property damage, causation, coverage, or a claim.</div>`;
      card.classList.add('open');document.getElementById('bpWeatherClose').onclick=()=>card.classList.remove('open');
    }
  },Cesium.ScreenSpaceEventType.LEFT_CLICK);

  const observer=new MutationObserver(()=>{
    if(!activePropertyId||!card?.classList.contains('open')) return;
    const payload=intelCache.get(activePropertyId);
    if(payload&&!document.getElementById('bpV2501Intel')) queueMicrotask(()=>renderIntel(activePropertyId,payload));
    else if(intelInflight.has(activePropertyId)&&!document.getElementById('bpV2501Intel')) queueMicrotask(()=>renderIntel(activePropertyId,payload||{},true));
  });
  if(card) observer.observe(card,{childList:true,subtree:true});

  viewer.camera.moveEnd.addEventListener(()=>refreshOpportunities(false));
  document.addEventListener('visibilitychange',()=>{if(!document.hidden){refreshPulse();refreshOpportunities(true);}});
  await Promise.allSettled([refreshPulse(),refreshOpportunities(true)]);
  pulseTimer=setInterval(refreshPulse,15000);
  window.BridgePointWorldV2501={version:VERSION,refreshPulse,refreshOpportunities,loadIntelligence,get opportunitiesOn(){return opportunitiesOn;},destroy(){if(pulseTimer)clearInterval(pulseTimer);observer.disconnect();viewer.dataSources.remove(opportunities,true);}};
  if(status) status.textContent=`BridgePoint World V2500 + Intelligence V${VERSION} · live parcel/opportunity/property intelligence connected.`;
}

init().catch(e=>{console.error('BridgePoint V2501 intelligence enhancement failed',e);});
