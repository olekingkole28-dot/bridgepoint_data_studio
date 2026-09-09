import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const VERSION = 2652;
const SUPABASE_URL = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const SUPABASE_KEY = 'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
const $ = (id) => document.getElementById(id);
const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
const finite = (v) => Number.isFinite(Number(v)) ? Number(v) : null;
const esc = (v) => String(v ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const RESTRICTED = new Set(['BUILDING_INTERIOR_ARCHITECTURE','UNDERGROUND_UTILITIES_PUBLIC','UTILITY_LEAKS_BREAKS']);
const DEFAULT_LAYERS = new Set([
  'BASE_INFRASTRUCTURE','TRANSPORT_NETWORK_DETAIL','STREETLIGHTS_SIGNALS','SIDEWALKS_PARKING',
  'SURFACE_MATERIAL_FINE','TREE_OBJECTS_3D','ROCKS_BOULDERS_CLIFFS','BARRIERS_WALLS_FENCES',
  'POOLS_PROPERTY_WATER','ROOFTOP_SOLAR_DETAIL','PROPERTY_IMPROVEMENTS_FINE','LANDMARK_OBJECTS_FINE',
  'TUNNELS_UNDERPASSES','TRANSIT_LIVE','LIGHTNING','EARTHQUAKES','FIRE_ACTIVE','SMOKE_PLUMES',
  'OCEAN_BUOY_OBS','COASTAL_WATER_LEVEL'
]);

function waitForBaseWorld(timeoutMs=20000){
  const start=performance.now();
  return new Promise((resolve,reject)=>{
    const tick=()=>{
      if(window.BridgePointWorldV2500?.viewer) return resolve(window.BridgePointWorldV2500);
      if(performance.now()-start>timeoutMs) return reject(new Error('Base world did not initialize'));
      setTimeout(tick,100);
    };tick();
  });
}

function geometryLines(g){
  if(g?.type==='LineString')return[g.coordinates||[]];
  if(g?.type==='MultiLineString')return g.coordinates||[];
  if(g?.type==='Polygon')return g.coordinates?.[0]?[g.coordinates[0]]:[];
  if(g?.type==='MultiPolygon')return(g.coordinates||[]).map(p=>p?.[0]).filter(Boolean);
  return[];
}
function geometryPolygons(g){
  if(g?.type==='Polygon')return g.coordinates?.[0]?[g.coordinates[0]]:[];
  if(g?.type==='MultiPolygon')return(g.coordinates||[]).map(p=>p?.[0]).filter(Boolean);
  return[];
}
function geometryPoints(g){
  if(g?.type==='Point')return[g.coordinates];
  if(g?.type==='MultiPoint')return g.coordinates||[];
  return[];
}
function flatDegrees(line){const out=[];for(const p of line||[])if(Number.isFinite(+p[0])&&Number.isFinite(+p[1]))out.push(+p[0],+p[1]);return out.length>=4?out:null}
function centroid(g){
  const pts=geometryPoints(g);if(pts.length)return pts[0];
  const ring=geometryPolygons(g)[0]||geometryLines(g)[0];if(!ring?.length)return null;
  let x=0,y=0,n=0;for(const p of ring)if(Number.isFinite(+p[0])&&Number.isFinite(+p[1])){x+=+p[0];y+=+p[1];n++}return n?[x/n,y/n]:null;
}
function viewRectangle(viewer){const r=viewer.camera.computeViewRectangle(viewer.scene.globe.ellipsoid);return r?{west:Cesium.Math.toDegrees(r.west),south:Cesium.Math.toDegrees(r.south),east:Cesium.Math.toDegrees(r.east),north:Cesium.Math.toDegrees(r.north)}:null}
function cameraHeight(viewer){return viewer.camera.positionCartographic?.height||1e6}
function layerColor(key,family=''){
  const k=String(key).toUpperCase(),f=String(family).toUpperCase();
  if(k.includes('FIRE')||k.includes('BURN'))return'#ff623e';
  if(k.includes('FLOOD')||k.includes('WATER')||k.includes('OCEAN')||k.includes('POOL'))return'#45c9ff';
  if(k.includes('SNOW')||k.includes('ICE'))return'#edf8ff';
  if(k.includes('LIGHTNING'))return'#ffd45e';
  if(k.includes('TREE')||k.includes('VEGET')||f==='LAND')return'#69c77b';
  if(k.includes('SOLAR'))return'#8fa6ff';
  if(k.includes('TRANSIT')||k.includes('TRAIN')||k.includes('ROAD')||f==='TRANSPORT')return'#f0e6cf';
  if(k.includes('ROCK')||k.includes('MINE')||k.includes('GEOLOGY'))return'#a5927b';
  if(k.includes('UNDERGROUND')||k.includes('SUBSURFACE')||k.includes('UTILITY'))return'#9caec0';
  if(k.includes('WALL')||k.includes('FENCE')||k.includes('BARRIER'))return'#c4b49b';
  if(k.includes('BUILD')||k.includes('STRUCTURE'))return'#63ddf5';
  return'#7bdfff';
}
function truthAlpha(truth=''){const t=String(truth).toUpperCase();return t.includes('OBSERVED')||t.includes('SOURCE_BACKED')?0.92:t.includes('DERIVED')?0.72:0.55}
function destinationPoint(lon,lat,bearingDeg,meters){const b=bearingDeg*Math.PI/180,d=meters/6371000,la=lat*Math.PI/180,lo=lon*Math.PI/180;const la2=Math.asin(Math.sin(la)*Math.cos(d)+Math.cos(la)*Math.sin(d)*Math.cos(b));const lo2=lo+Math.atan2(Math.sin(b)*Math.sin(d)*Math.cos(la),Math.cos(d)-Math.sin(la)*Math.sin(la2));return[lo2*180/Math.PI,la2*180/Math.PI]}
function symbolSvg(symbol,color){const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="42" height="42"><circle cx="21" cy="21" r="18" fill="#07121d" fill-opacity=".86" stroke="${color}" stroke-width="2"/><text x="21" y="27" text-anchor="middle" font-size="20" fill="white">${symbol}</text></svg>`;return`data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`}

async function init(){
  const base=await waitForBaseWorld();const viewer=base.viewer;
  const assetDs=new Cesium.CustomDataSource('bp-v2652-assets');
  const liveDs=new Cesium.CustomDataSource('bp-v2652-live');
  const xrayDs=new Cesium.CustomDataSource('bp-v2652-xray');
  viewer.dataSources.add(assetDs);viewer.dataSources.add(liveDs);viewer.dataSources.add(xrayDs);
  const state={catalog:null,selected:new Set(DEFAULT_LAYERS),busy:false,pending:false,lastKey:'',xray:false,owner:false,assets:0,observations:0,current:0,historical:0,refreshSeq:0};

  function setPanelStatus(text,kind='') { const el=$('catalogStatus');if(el){el.textContent=text;el.className=`catalogStatus ${kind}`;} }
  function updateClock(){const el=$('truthClock');if(el){const d=new Date();el.textContent=`TRUTH CLOCK · ${d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',second:'2-digit'})} · ${d.toISOString().slice(11,19)} UTC`;}}
  setInterval(updateClock,1000);updateClock();

  async function loadCatalog(){
    const {data,error}=await supabase.rpc('bridgepoint_living_world_catalog_v2652');
    if(error)throw error;state.catalog=data;state.owner=Boolean(data?.owner);renderCatalog();return data;
  }
  function layerMaterialized(l){const s=l?.primary_source||{};return /ACTIVE|MATERIALIZED|RESOLVER|COMPUTED/.test(String(l.backend_status||''))||/ACTIVE|MATERIALIZED/.test(String(s.adapter_status||''));}
  function renderCatalog(){
    const data=state.catalog||{},counts=data.counts||{},metrics=$('worldMetrics');
    if(metrics)metrics.innerHTML=`<b>${Number(counts.layers||0).toLocaleString()}</b> layers · <b>${Number(counts.sources||0).toLocaleString()}</b> active sources · <b>${Number(counts.observations||0).toLocaleString()}</b> observations · <b>${Number(counts.roof_assets||0).toLocaleString()}</b> roof assets · <b>${Number(counts.detail_jobs||0).toLocaleString()}</b> local-detail jobs`;
    const host=$('dynamicLayerGrid');if(!host)return;host.innerHTML='';
    const search=String($('layerSearch')?.value||'').trim().toLowerCase();
    const grouped=new Map();
    for(const l of data.layers||[]){const hay=`${l.display_name} ${l.layer_key} ${l.family} ${l.filter_group}`.toLowerCase();if(search&&!hay.includes(search))continue;const group=l.filter_group||l.family||'World';if(!grouped.has(group))grouped.set(group,[]);grouped.get(group).push(l)}
    for(const [group,layers] of grouped){
      const wrap=document.createElement('div');wrap.className='dynamicGroup';const title=document.createElement('div');title.className='dynamicGroupTitle';title.textContent=`${group} · ${layers.length}`;wrap.appendChild(title);
      const grid=document.createElement('div');grid.className='layerGrid dynamicGrid';
      for(const l of layers){const b=document.createElement('button');b.type='button';b.dataset.dynamicLayer=l.layer_key;b.classList.toggle('active',state.selected.has(l.layer_key));b.classList.toggle('restricted',Boolean(l.restricted));b.classList.toggle('ready',layerMaterialized(l));const lock=l.restricted&&!l.owner_access?' 🔒':'';const realtime=l.realtime?' ●':'';b.innerHTML=`<span>${esc(l.display_name)}${lock}${realtime}</span><small>${esc(l.coverage_status||l.backend_status||'')}</small>`;b.title=`${l.layer_key} · ${l.truth_policy||''}`;b.onclick=()=>{if(l.restricted&&!l.owner_access){setPanelStatus(`${l.display_name} is restricted to owner/authorized access.`,'warn');return}if(state.selected.has(l.layer_key))state.selected.delete(l.layer_key);else state.selected.add(l.layer_key);b.classList.toggle('active',state.selected.has(l.layer_key));state.lastKey='';refreshScene(true)};grid.appendChild(b)}
      wrap.appendChild(grid);host.appendChild(wrap);
    }
    setPanelStatus(`V${VERSION} catalog synchronized · ${data.layers?.length||0} backend layers discovered.`,'ok');
  }
  $('layerSearch')?.addEventListener('input',renderCatalog);

  function addTree(row,g,color){const p=centroid(g);if(!p)return 0;const props=row.properties||{},h=clamp(finite(row.height_m??props.height_m??props.height)||6,2,55),dbh=finite(props.diameter_m??props.dbh_m??props.trunk_diameter_m),radius=clamp(dbh?dbh/2:Math.max(.09,h*.018),.08,1.6),ground=0;const pos=Cesium.Cartesian3.fromDegrees(p[0],p[1],ground+h*.5);assetDs.entities.add({position:pos,cylinder:{length:h,bottomRadius:radius,topRadius:radius*.72,material:Cesium.Color.fromCssColorString('#72543c'),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,6000)},properties:{truth:row.truth_class,layer:row.layer_key}});assetDs.entities.add({position:Cesium.Cartesian3.fromDegrees(p[0],p[1],ground+h*.88),ellipsoid:{radii:new Cesium.Cartesian3(h*.18,h*.18,h*.24),material:Cesium.Color.fromCssColorString(color).withAlpha(truthAlpha(row.truth_class)),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,6500)}});return 2}
  function addRock(row,g,color){const p=centroid(g);if(!p)return 0;const h=clamp(finite(row.height_m)||2,.4,28),r=Math.max(.5,h*.7);assetDs.entities.add({position:Cesium.Cartesian3.fromDegrees(p[0],p[1],h*.35),ellipsoid:{radii:new Cesium.Cartesian3(r,r*.72,h*.55),material:Cesium.Color.fromCssColorString(color).withAlpha(.92),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,8000)},properties:{truth:row.truth_class,layer:row.layer_key}});return 1}
  function addAsset(row){const g=row.geometry_geojson;if(!g)return 0;const key=row.layer_key||'',color=layerColor(key),alpha=truthAlpha(row.truth_class);if(key==='TREE_OBJECTS_3D')return addTree(row,g,color);if(key==='ROCKS_BOULDERS_CLIFFS'&&geometryPoints(g).length)return addRock(row,g,color);let n=0;
    for(const p of geometryPoints(g)){if(!Number.isFinite(+p?.[0])||!Number.isFinite(+p?.[1]))continue;const icon=key.includes('SOLAR')?'☀':key.includes('POOL')?'≈':key.includes('LANDMARK')?'◆':key.includes('MINE')?'◇':'•';assetDs.entities.add({position:Cesium.Cartesian3.fromDegrees(+p[0],+p[1],Math.max(1,(finite(row.height_m)||0)*.5)),billboard:{image:symbolSvg(icon,color),width:24,height:24,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,22000),disableDepthTestDistance:800},properties:{layer:key,truth:row.truth_class,source:row.source_key}});n++}
    for(const line of geometryLines(g)){const d=flatDegrees(line);if(!d)continue;const h=finite(row.height_m);if((key.includes('WALL')||key.includes('FENCE')||key.includes('BARRIER'))&&h!==null){const positions=Cesium.Cartesian3.fromDegreesArray(d);assetDs.entities.add({wall:{positions,minimumHeights:new Array(positions.length).fill(0),maximumHeights:new Array(positions.length).fill(h),material:Cesium.Color.fromCssColorString(color).withAlpha(alpha),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,12000)},properties:{layer:key,truth:row.truth_class}})}else assetDs.entities.add({polyline:{positions:Cesium.Cartesian3.fromDegreesArray(d),width:key.includes('TRANSPORT')?2.4:1.8,material:Cesium.Color.fromCssColorString(color).withAlpha(alpha),clampToGround:true,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,90000)},properties:{layer:key,truth:row.truth_class}});n++}
    for(const ring of geometryPolygons(g)){const d=flatDegrees(ring);if(!d)continue;const h=finite(row.height_m);const isPool=key.includes('POOL'),isSolar=key.includes('SOLAR');assetDs.entities.add({polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(d),height:isSolar?1.2:0,extrudedHeight:h!==null&&h>0&&!isPool?h:undefined,material:Cesium.Color.fromCssColorString(color).withAlpha(isPool?.48:alpha*.72),outline:true,outlineColor:Cesium.Color.fromCssColorString(color).withAlpha(.92),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,45000)},properties:{layer:key,truth:row.truth_class,source:row.source_key}});n++}
    return n;
  }
  function movingPosition(row,p){const observed=Date.parse(row.observed_at||'')||Date.now(),speed=finite(row.speed_mps)||0,heading=finite(row.heading_deg);return new Cesium.CallbackProperty(()=>{const age=clamp((Date.now()-observed)/1000,0,30);let lon=+p[0],lat=+p[1];if(speed>0&&heading!==null&&row.temporal_status==='CURRENT'){const e=destinationPoint(lon,lat,heading,speed*age);lon=e[0];lat=e[1]}return Cesium.Cartesian3.fromDegrees(lon,lat,finite(row.altitude_m)||5)},false)}
  function addObservation(row){const g=row.geometry_geojson,p=centroid(g);if(!p)return 0;const key=row.layer_key||'',current=row.temporal_status==='CURRENT',color=layerColor(key),isTransit=key.includes('TRANSIT')||key.includes('TRAIN'),isAnimal=key.includes('ANIMAL')||key.includes('FISH')||key.includes('WILDLIFE');const symbol=isTransit?'▰':isAnimal?'●':key.includes('LIGHTNING')?'ϟ':key.includes('FIRE')?'▲':'•';liveDs.entities.add({position:movingPosition(row,p),billboard:{image:symbolSvg(symbol,color),width:isTransit?28:22,height:isTransit?28:22,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,isTransit?180000:900000),disableDepthTestDistance:1500},label:isTransit?{text:String(row.values?.vehicle_label||row.values?.route_id||''),font:'700 10px sans-serif',fillColor:Cesium.Color.WHITE,outlineColor:Cesium.Color.BLACK,outlineWidth:3,style:Cesium.LabelStyle.FILL_AND_OUTLINE,pixelOffset:new Cesium.Cartesian2(0,-20),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,35000),disableDepthTestDistance:1200}:undefined,properties:{layer:key,truth:row.truth_class,temporal_status:row.temporal_status,observed_at:row.observed_at,current}});return 1}

  async function refreshScene(force=false){
    if(state.busy){state.pending=true;return}const h=cameraHeight(viewer);if(h>260000){assetDs.entities.removeAll();liveDs.entities.removeAll();return}const v=viewRectangle(viewer);if(!v||v.east<=v.west)return;const keys=[...state.selected];const k=`${v.west.toFixed(3)}:${v.south.toFixed(3)}:${v.east.toFixed(3)}:${v.north.toFixed(3)}:${Math.round(h/300)}:${keys.sort().join(',')}`;if(!force&&k===state.lastKey)return;state.lastKey=k;state.busy=true;const seq=++state.refreshSeq;
    try{const {data,error}=await supabase.rpc('bridgepoint_living_world_scene_v2652',{p_west:v.west,p_south:v.south,p_east:v.east,p_north:v.north,p_layer_keys:keys,p_at:new Date().toISOString(),p_limit:h<5000?3000:h<40000?1800:900});if(error)throw error;if(seq!==state.refreshSeq)return;if(data?.locked){setPanelStatus('Sign in to stream the governed living-world scene.','warn');return}assetDs.entities.removeAll();liveDs.entities.removeAll();let a=0,o=0,c=0,hist=0;for(const row of data?.assets||[])a+=addAsset(row);for(const row of data?.observations||[]){if(row.temporal_status==='CURRENT'){o+=addObservation(row);c++}else hist++}state.assets=a;state.observations=o;state.current=c;state.historical=hist;viewer.scene.requestRender();const s=$('sceneStatus');if(s)s.textContent=`SCENE · ${a} physical objects · ${c} current moving/event states · ${hist} older states withheld from “now”`;setPanelStatus(`Scene synchronized at ${new Date(data.requested_at||Date.now()).toLocaleTimeString()} · source/derived truth preserved.`,'ok')}catch(e){console.warn('V2652 scene unavailable',e);setPanelStatus(`Living scene waiting: ${e?.message||e}`,'warn')}finally{state.busy=false;if(state.pending){state.pending=false;queueMicrotask(()=>refreshScene(true))}}
  }

  function setXray(on){state.xray=Boolean(on);$('xrayWorldButton')?.classList.toggle('active',state.xray);const t=viewer.scene.globe.translucency;if(t){t.enabled=state.xray;t.frontFaceAlphaByDistance=new Cesium.NearFarScalar(0,state.xray?.18:1,800000,state.xray?.55:1);t.backFaceAlpha=state.xray?.08:1}if(state.xray){for(const k of ['SUBSURFACE_GEOLOGY','UNDERGROUND_STORAGE_RELEASES','MINES_QUARRIES','UNDERGROUND_PUBLIC_SPACES'])state.selected.add(k);if(state.owner)for(const k of ['UNDERGROUND_UTILITIES_PUBLIC','UTILITY_LEAKS_BREAKS'])state.selected.add(k)}state.lastKey='';renderCatalog();refreshScene(true);viewer.scene.requestRender()}
  $('xrayWorldButton')?.addEventListener('click',()=>setXray(!state.xray));
  $('allLivingButton')?.addEventListener('click',()=>{for(const l of state.catalog?.layers||[])if(!l.restricted||l.owner_access)state.selected.add(l.layer_key);renderCatalog();state.lastKey='';refreshScene(true)});
  $('clearLivingButton')?.addEventListener('click',()=>{state.selected.clear();renderCatalog();assetDs.entities.removeAll();liveDs.entities.removeAll();viewer.scene.requestRender()});

  viewer.camera.moveEnd.addEventListener(()=>refreshScene(false));
  setInterval(()=>{if(!document.hidden)refreshScene(true)},15000);
  setInterval(()=>{if(!document.hidden)loadCatalog().catch(()=>{})},120000);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden){loadCatalog().catch(()=>{});refreshScene(true)}});

  try{await loadCatalog()}catch(e){setPanelStatus(`Catalog unavailable: ${e?.message||e}`,'bad')}
  await refreshScene(true);
  window.BridgePointWorldV2652={version:VERSION,viewer,refreshScene,loadCatalog,setXray,get state(){return{...state,selected:[...state.selected],catalog:state.catalog?{counts:state.catalog.counts,layers:state.catalog.layers?.length}:null}}};
  document.documentElement.dataset.bridgepointWorldVersion=String(VERSION);
}

init().catch(e=>{console.error(e);const el=$('catalogStatus');if(el){el.textContent=`BridgePoint World V${VERSION} extension failed: ${e?.message||e}`;el.className='catalogStatus bad'}});
