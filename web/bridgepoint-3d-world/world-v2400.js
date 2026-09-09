import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const VERSION = 2400;
const NATURAL_EARTH_COUNTRIES = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson';
const US_CODES = new Set(['US','PR','GU','VI','AS','MP','UM','USA']);
const SUPABASE_URL = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const SUPABASE_KEY = 'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
const rawConfig = window.BRIDGEPOINT_WORLD_CONFIG || {};
const CONFIG = Object.freeze({
  googleMapsTileKey: String(rawConfig.googleMapsTileKey || '').trim(),
  cesiumIonToken: String(rawConfig.cesiumIonToken || '').trim(),
  photorealDefault: rawConfig.photorealDefault !== false,
  lockedCountryMinimumHeightMeters: Number(rawConfig.lockedCountryMinimumHeightMeters || 350000),
  photorealMaximumHeightMeters: Number(rawConfig.photorealMaximumHeightMeters || 450000)
});

const mobile = /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);
const deviceMemory = Number(navigator.deviceMemory || 4);
const cores = Number(navigator.hardwareConcurrency || 4);
const tier = deviceMemory <= 4 || cores <= 4 ? 'LOW' : (!mobile && deviceMemory >= 8 && cores >= 8 ? 'HIGH' : 'MEDIUM');
const PERF = Object.freeze(tier === 'LOW'
  ? { resolutionScale:.72, targetFps:30, sse:28, cacheBytes:96*1024*1024, buildingLimit:[650,900,1200], labelLimit:80 }
  : tier === 'HIGH'
    ? { resolutionScale:1, targetFps:60, sse:10, cacheBytes:384*1024*1024, buildingLimit:[1400,2200,3400], labelLimit:260 }
    : { resolutionScale:mobile?.86:.95, targetFps:45, sse:17, cacheBytes:192*1024*1024, buildingLimit:[1000,1500,2200], labelLimit:150 });

const $ = id => document.getElementById(id);
const statusEl = $('status'), drawer = $('drawer'), lockCard = $('lockCard'), weatherFx = $('weatherFx');
const setStatus = (text, kind='') => { statusEl.className = `panel ${kind}`; statusEl.textContent = text; };
const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const clamp = (v,min,max)=>Math.max(min,Math.min(max,v));

if (CONFIG.cesiumIonToken) Cesium.Ion.defaultAccessToken = CONFIG.cesiumIonToken;
const viewer = new Cesium.Viewer('cesiumContainer', {
  animation:false, timeline:false, baseLayerPicker:false, geocoder:false, homeButton:false,
  sceneModePicker:false, navigationHelpButton:false, fullscreenButton:false, infoBox:false,
  selectionIndicator:false, terrainProvider:new Cesium.EllipsoidTerrainProvider(),
  imageryProvider:new Cesium.OpenStreetMapImageryProvider({url:'https://tile.openstreetmap.org/', credit:'© OpenStreetMap contributors'}),
  requestRenderMode:true, maximumRenderTimeChange:Infinity, shouldAnimate:true
});
viewer.resolutionScale = PERF.resolutionScale;
viewer.targetFrameRate = PERF.targetFps;
viewer.scene.globe.depthTestAgainstTerrain = true;
viewer.scene.globe.enableLighting = true;
viewer.scene.globe.showGroundAtmosphere = true;
viewer.scene.fog.enabled = true;
viewer.scene.fog.density = 0.00018;
viewer.scene.fog.screenSpaceErrorFactor = 2;
viewer.scene.skyAtmosphere.show = true;
viewer.scene.backgroundColor = Cesium.Color.fromCssColorString('#020711');
viewer.scene.screenSpaceCameraController.enableCollisionDetection = true;
viewer.scene.screenSpaceCameraController.minimumZoomDistance = 1.8;
viewer.scene.screenSpaceCameraController.maximumZoomDistance = 24000000;
viewer.camera.percentageChanged = .025;
viewer.clock.shouldAnimate = true;
viewer.camera.setView({
  destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),
  orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0}
});

const buildingSource = new Cesium.CustomDataSource('bridgepoint-buildings');
const parcelSource = new Cesium.CustomDataSource('bridgepoint-parcels');
const roofSource = new Cesium.CustomDataSource('bridgepoint-roofs');
const labelSource = new Cesium.CustomDataSource('bridgepoint-labels');
const hazardSource = new Cesium.CustomDataSource('bridgepoint-hazards');
const lockedSource = new Cesium.CustomDataSource('bridgepoint-locked-countries');
for (const source of [buildingSource, parcelSource, roofSource, labelSource, hazardSource, lockedSource]) viewer.dataSources.add(source);

let photorealTileset = null;
let photorealWanted = CONFIG.photorealDefault;
let photorealReady = false;
let countries = [];
let selectedCountry = null;
let lastKey = '';
let loading = false;
let hazardsOn = false;
let guarding = false;
let currentFocus = null;
let detailAbort = 0;

function cameraHeight(){ return viewer.camera.positionCartographic?.height || 100000; }
function viewport(){
  const r = viewer.camera.computeViewRectangle(viewer.scene.globe.ellipsoid);
  if (!r) return null;
  return {west:Cesium.Math.toDegrees(r.west),south:Cesium.Math.toDegrees(r.south),east:Cesium.Math.toDegrees(r.east),north:Cesium.Math.toDegrees(r.north)};
}
function viewportKey(v,h){ return [v.west,v.south,v.east,v.north].map(x=>x.toFixed(h<1000?4:h<10000?3:2)).join(':')+':'+Math.round(Math.log10(Math.max(h,1))*4); }
function clearDetail(){ for (const s of [buildingSource,parcelSource,roofSource,labelSource]) s.entities.removeAll(); viewer.scene.requestRender(); }
function geometryOuterRings(geometry){
  if (!geometry) return [];
  if (geometry.type === 'Polygon') return geometry.coordinates?.length ? [geometry.coordinates[0]] : [];
  if (geometry.type === 'MultiPolygon') return (geometry.coordinates || []).map(p=>p?.[0]).filter(Boolean);
  return [];
}
function ringDegrees(ring){
  const out=[];
  for (const p of ring || []) if (Number.isFinite(+p[0]) && Number.isFinite(+p[1])) out.push(+p[0],+p[1]);
  return out.length>=6 ? out : null;
}
function ringCentroid(ring){
  if (!ring?.length) return null;
  let lon=0,lat=0,n=0;
  for (const p of ring) if (Number.isFinite(+p[0])&&Number.isFinite(+p[1])) {lon+=+p[0];lat+=+p[1];n++;}
  return n ? [lon/n,lat/n] : null;
}
function codeAndName(properties={}){
  const code=String(properties.ISO_A2||properties.ISO_A2_EH||properties.ADM0_A3||properties.SOV_A3||'').trim().toUpperCase();
  const name=String(properties.NAME_EN||properties.ADMIN||properties.NAME_LONG||properties.NAME||properties.SOVEREIGNT||'Country').trim();
  return {code,name};
}
function normalizeAround(x, anchor){ let v=Number(x); while(v-anchor>180)v-=360; while(v-anchor<-180)v+=360; return v; }
function pointInRing(lon,lat,ring){
  let inside=false;
  for(let i=0,j=ring.length-1;i<ring.length;j=i++){
    const xi=normalizeAround(ring[i][0],lon), yi=Number(ring[i][1]);
    const xj=normalizeAround(ring[j][0],lon), yj=Number(ring[j][1]);
    const hit=((yi>lat)!==(yj>lat))&&(lon<(xj-xi)*(lat-yi)/((yj-yi)||1e-12)+xi);
    if(hit)inside=!inside;
  }
  return inside;
}
function pointInPolygon(lon,lat,polygon){
  if(!polygon?.length||!pointInRing(lon,lat,polygon[0]))return false;
  for(let i=1;i<polygon.length;i++)if(pointInRing(lon,lat,polygon[i]))return false;
  return true;
}
function pointInGeometry(lon,lat,g){
  if(!g)return false;
  if(g.type==='Polygon')return pointInPolygon(lon,lat,g.coordinates||[]);
  if(g.type==='MultiPolygon')return (g.coordinates||[]).some(p=>pointInPolygon(lon,lat,p));
  return false;
}
function focusPoint(){
  const canvas=viewer.scene.canvas;
  const center=new Cesium.Cartesian2(canvas.clientWidth/2,canvas.clientHeight/2);
  const c=viewer.camera.pickEllipsoid(center,Cesium.Ellipsoid.WGS84);
  if(!c)return null;
  const cart=Cesium.Cartographic.fromCartesian(c);
  return {lon:Cesium.Math.toDegrees(cart.longitude),lat:Cesium.Math.toDegrees(cart.latitude)};
}
function countryAt(lon,lat){
  for(const c of countries){
    if(lat<c.bbox[1]||lat>c.bbox[3])continue;
    const w=normalizeAround(c.bbox[0],lon),e=normalizeAround(c.bbox[2],lon);
    const x=lon;
    if(w<=e&&(x<w||x>e))continue;
    if(pointInGeometry(lon,lat,c.geometry))return c;
  }
  return null;
}
function isUnlockedCountry(c){ return !c || US_CODES.has(c.code); }

function showLock(country){
  if(!country||isUnlockedCountry(country))return;
  selectedCountry=country;
  $('lockTitle').textContent=`${country.name} — Locked`;
  $('lockDetail').textContent='Under Construction. BridgePoint keeps deep property-level zoom inside the United States and its unlocked jurisdictions until this country passes source, legal, geometry, and quality gates.';
  $('lockStatus').textContent='';
  lockCard.hidden=false;
}
function hideLock(){ lockCard.hidden=true; selectedCountry=null; }
$('lockClose').onclick=hideLock;
$('requestBuild').onclick=async()=>{
  if(!selectedCountry)return;
  const btn=$('requestBuild'); btn.disabled=true; btn.textContent='Requesting…'; $('lockStatus').textContent='Submitting expansion request…';
  try{
    const {data,error}=await supabase.rpc('bridgepoint_request_country_expansion_v2170',{p_country_code:selectedCountry.code,p_country_name:selectedCountry.name});
    if(error)throw error;
    $('lockStatus').textContent=`${selectedCountry.name} request queued.`; btn.textContent='Requested';
    window.dispatchEvent(new CustomEvent('bp2400:country-build-requested',{detail:{country:selectedCountry,result:data}}));
  }catch(e){ $('lockStatus').textContent='Request could not be queued yet. Retry when the backend is reachable.'; btn.textContent='Retry Request'; btn.disabled=false; }
};

function lockGuard(force=false){
  if(guarding||!countries.length)return;
  const focus=focusPoint(); if(!focus)return;
  const c=countryAt(focus.lon,focus.lat); currentFocus={...focus,country:c};
  const h=cameraHeight(); const locked=c&&!isUnlockedCountry(c);
  if(locked&&h<CONFIG.lockedCountryMinimumHeightMeters){
    guarding=true; showLock(c); clearDetail();
    const pos=viewer.camera.positionCartographic;
    viewer.camera.setView({destination:Cesium.Cartesian3.fromRadians(pos.longitude,pos.latitude,CONFIG.lockedCountryMinimumHeightMeters),orientation:{heading:viewer.camera.heading,pitch:viewer.camera.pitch,roll:viewer.camera.roll}});
    setStatus(`${c.name} is locked • deep zoom stopped at the BridgePoint expansion boundary.`, 'warn');
    setTimeout(()=>{guarding=false;syncPhotorealVisibility();},0);
    return;
  }
  if(locked&&force)showLock(c);
  if(!locked&&selectedCountry)hideLock();
  syncPhotorealVisibility();
}

async function loadCountries(){
  try{
    const r=await fetch(NATURAL_EARTH_COUNTRIES,{cache:'force-cache'}); if(!r.ok)throw new Error(`countries ${r.status}`);
    const j=await r.json(); countries=[]; lockedSource.entities.removeAll();
    for(const f of j.features||[]){
      const id=codeAndName(f.properties||{}); if(!id.code)continue;
      const all=[]; for(const ring of geometryOuterRings(f.geometry))for(const p of ring)all.push(p);
      if(!all.length)continue;
      let minX=180,minY=90,maxX=-180,maxY=-90; for(const p of all){minX=Math.min(minX,+p[0]);minY=Math.min(minY,+p[1]);maxX=Math.max(maxX,+p[0]);maxY=Math.max(maxY,+p[1]);}
      const c={...id,geometry:f.geometry,bbox:[minX,minY,maxX,maxY]}; countries.push(c);
      if(isUnlockedCountry(c))continue;
      let polygons=0;
      for(const ring of geometryOuterRings(f.geometry)){
        const coords=ringDegrees(ring); if(!coords)continue;
        lockedSource.entities.add({polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),material:Cesium.Color.fromCssColorString('#151a1f').withAlpha(.34),outline:true,outlineColor:Cesium.Color.fromCssColorString('#ffd15c').withAlpha(.54),height:0}}); polygons++;
      }
      if(polygons&&tier!=='LOW'&&all.length<900){
        const center=ringCentroid(geometryOuterRings(f.geometry)[0]);
        if(center)lockedSource.entities.add({position:Cesium.Cartesian3.fromDegrees(center[0],center[1],2000),label:{text:`${c.name.toUpperCase()} · LOCKED`,font:'700 11px sans-serif',fillColor:Cesium.Color.fromCssColorString('#f6d36a').withAlpha(.72),outlineColor:Cesium.Color.fromCssColorString('#071017'),outlineWidth:2,style:Cesium.LabelStyle.FILL_AND_OUTLINE,scale:.8,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(800000,9000000),disableDepthTestDistance:Number.POSITIVE_INFINITY}});
      }
    }
    viewer.scene.requestRender(); lockGuard(true);
  }catch(e){ console.warn('BridgePoint country lock surface unavailable',e); setStatus('World loaded, but locked-country geometry could not be verified in this session.','warn'); }
}

async function installTerrain(){
  if(!CONFIG.cesiumIonToken)return false;
  try{
    viewer.terrainProvider=await Cesium.createWorldTerrainAsync({requestVertexNormals:true,requestWaterMask:true});
    viewer.scene.globe.depthTestAgainstTerrain=true; viewer.scene.requestRender(); return true;
  }catch(e){console.warn('Cesium World Terrain unavailable',e);return false;}
}

async function installPhotoreal(){
  if(!CONFIG.googleMapsTileKey){ $('photoreal').title='Add a browser-restricted Google Map Tiles API key in runtime-config.local.js'; return false; }
  try{
    photorealTileset=await Cesium.Cesium3DTileset.fromUrl(`https://tile.googleapis.com/v1/3dtiles/root.json?key=${encodeURIComponent(CONFIG.googleMapsTileKey)}`,{
      showCreditsOnScreen:true,
      maximumScreenSpaceError:PERF.sse,
      dynamicScreenSpaceError:true,
      dynamicScreenSpaceErrorDensity:tier==='LOW'?.0035:.0022,
      dynamicScreenSpaceErrorFactor:tier==='LOW'?8:5,
      cacheBytes:PERF.cacheBytes,
      maximumCacheOverflowBytes:Math.round(PERF.cacheBytes*.45),
      cullRequestsWhileMoving:true,
      cullWithChildrenBounds:true,
      skipLevelOfDetail:tier==='LOW',
      preferLeaves:tier==='LOW'
    });
    photorealTileset.showCreditsOnScreen=true;
    viewer.scene.primitives.add(photorealTileset); photorealReady=true; syncPhotorealVisibility(); return true;
  }catch(e){console.warn('Google Photorealistic 3D Tiles unavailable',e);setStatus('Source-backed world is active; Google photoreal tiles could not initialize.','warn');return false;}
}
function syncPhotorealVisibility(){
  const focus=currentFocus||(()=>{const p=focusPoint();return p?{...p,country:countryAt(p.lon,p.lat)}:null})();
  const unlocked=!focus?.country||isUnlockedCountry(focus.country);
  const show=Boolean(photorealReady&&photorealWanted&&unlocked&&cameraHeight()<=CONFIG.photorealMaximumHeightMeters);
  if(photorealTileset)photorealTileset.show=show;
  viewer.scene.globe.show=!show;
  $('photoreal').classList.toggle('active',show);
  viewer.scene.requestRender();
}
$('photoreal').onclick=()=>{
  photorealWanted=!photorealWanted;
  if(photorealWanted&&!photorealReady&&!CONFIG.googleMapsTileKey)setStatus('Photoreal mode needs a browser-restricted Google Map Tiles API key in runtime-config.local.js.','warn');
  syncPhotorealVisibility();
};

function buildingColor(b){
  const score=Number(b.render_score??b.opportunity_score??b.score);
  if(Number.isFinite(score)){ if(score>=80)return '#ffb13b'; if(score>=65)return '#ffdd70'; }
  const estimated=!b.height_m||Number(b.height_m)<=0;
  return estimated?'#d9aa42':'#36bed7';
}
function addParcel(p,index){
  for(const ring of geometryOuterRings(p.geometry)){
    const coords=ringDegrees(ring);if(!coords)continue;
    const score=Number(p.render_score??p.opportunity_score??p.score);
    const color=Number.isFinite(score)&&score>=75?'#ffb13b':'#8defff';
    parcelSource.entities.add({id:`parcel-${p.property_id||index}-${parcelSource.entities.values.length}`,polyline:{positions:Cesium.Cartesian3.fromDegreesArray(coords),width:tier==='LOW'?1:1.6,material:Cesium.Color.fromCssColorString(color).withAlpha(.9),clampToGround:true,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,60000)}});
  }
}
function addRoof(r,index){
  for(const ring of geometryOuterRings(r.geometry)){
    const coords=ringDegrees(ring);if(!coords)continue;
    const base=Number(r.roof_base_m??r.ground_elevation_m??0),top=Math.max(base+.6,Number(r.roof_top_m??r.render_height_m??base+4));
    roofSource.entities.add({id:`roof-${r.property_id||index}-${roofSource.entities.values.length}`,polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),height:base,extrudedHeight:top,material:Cesium.Color.fromCssColorString('#c8d8df').withAlpha(.55),outline:true,outlineColor:Cesium.Color.fromCssColorString('#e8fbff').withAlpha(.75),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,12000)}});
  }
}
async function streamBuildings(force=false){
  lockGuard();
  if(loading)return;
  const h=cameraHeight(); const c=currentFocus?.country;
  if(c&&!isUnlockedCountry(c)){clearDetail();return;}
  if(h>120000){clearDetail();setStatus(`World LOD • ${tier} device tier • zoom below ~120 km for BridgePoint property geometry.`,'ok');return;}
  const v=viewport();if(!v)return;const key=viewportKey(v,h);if(!force&&key===lastKey)return;lastKey=key;loading=true;const seq=++detailAbort;
  setStatus('Streaming BridgePoint property geometry for this viewport…');
  try{
    const limit=h<1000?PERF.buildingLimit[2]:h<8000?PERF.buildingLimit[1]:PERF.buildingLimit[0];
    const {data,error}=await supabase.rpc('bridgepoint_3d_world_viewport_v1899',{p_west:v.west,p_south:v.south,p_east:v.east,p_north:v.north,p_camera_height_m:h,p_limit:limit});
    if(error)throw error;if(seq!==detailAbort)return;
    if(data?.locked){clearDetail();setStatus('Sign in with BridgePoint map access to stream protected property intelligence.','warn');return;}
    clearDetail();
    let labelCount=0;
    for(const [i,b] of (data?.buildings||[]).entries()){
      const rings=geometryOuterRings(b.geometry);if(!rings.length)continue;const ground=Number(b.ground_elevation_m||0);const height=Math.max(3,Number(b.render_height_m||8.5));
      for(const ring of rings){
        const coords=ringDegrees(ring);if(!coords)continue;
        const e=buildingSource.entities.add({id:`bp-${b.source_key||'src'}-${b.building_id||i}-${buildingSource.entities.values.length}`,polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),height:ground,extrudedHeight:ground+height,material:Cesium.Color.fromCssColorString(buildingColor(b)).withAlpha(.58),outline:true,outlineColor:Cesium.Color.fromCssColorString('#83ecff').withAlpha(.46),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,125000)}});e.bridgepoint=b;
        const label=String(b.building_name||b.facility_name||b.name||b.classification_label||b.category||'').trim();
        if(label&&labelCount<PERF.labelLimit){const center=ringCentroid(ring);if(center){labelSource.entities.add({position:Cesium.Cartesian3.fromDegrees(center[0],center[1],ground+height+2),label:{text:label,font:'700 12px sans-serif',fillColor:Cesium.Color.WHITE,outlineColor:Cesium.Color.fromCssColorString('#061018'),outlineWidth:3,style:Cesium.LabelStyle.FILL_AND_OUTLINE,pixelOffset:new Cesium.Cartesian2(0,-8),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,4500),scaleByDistance:new Cesium.NearFarScalar(80,1,4500,.55),disableDepthTestDistance:900}});labelCount++;}}
      }
    }
    for(const [i,p] of (data?.parcels||[]).entries())addParcel(p,i);
    for(const [i,r] of (data?.roofs||[]).entries())addRoof(r,i);
    viewer.scene.requestRender();
    setStatus(`LOD ${data?.lod_level??'?'} • ${data?.returned??data?.buildings?.length??0} buildings • ${data?.parcels?.length??0} parcels • ${data?.roofs?.length??0} roofs • ${tier} mobile profile.`, 'ok');
  }catch(e){console.error(e);setStatus('BridgePoint 3D stream unavailable in this session: '+(e?.message||e),'bad');}finally{loading=false;}
}

viewer.camera.changed.addEventListener(()=>{lockGuard();syncPhotorealVisibility();});
viewer.camera.moveEnd.addEventListener(()=>{lockGuard(true);streamBuildings(false);});
$('reload').onclick=()=>streamBuildings(true);
$('us').onclick=()=>viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0},duration:1.25});
$('walk').onclick=()=>{
  const focus=focusPoint();if(!focus)return;
  const c=countryAt(focus.lon,focus.lat);if(c&&!isUnlockedCountry(c)){showLock(c);setStatus(`${c.name} is locked. Walk view is available only inside unlocked BridgePoint geography.`,'warn');return;}
  viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(focus.lon,focus.lat,38),orientation:{heading:viewer.camera.heading,pitch:Cesium.Math.toRadians(-9),roll:0},duration:1.05});
};
$('locate').onclick=()=>navigator.geolocation?.getCurrentPosition(p=>{
  const c=countryAt(p.coords.longitude,p.coords.latitude);if(c&&!isUnlockedCountry(c)){showLock(c);return;}
  viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(p.coords.longitude,p.coords.latitude,420),orientation:{heading:0,pitch:Cesium.Math.toRadians(-42),roll:0},duration:1.2});
},e=>setStatus('Location permission was not granted: '+e.message,'warn'),{enableHighAccuracy:true,timeout:12000});
$('back').onclick=()=>location.href='/';

viewer.screenSpaceEventHandler.setInputAction(async movement=>{
  const picked=viewer.scene.pick(movement.position);const entity=picked?.id;if(!entity?.bridgepoint)return;const b=entity.bridgepoint;
  drawer.style.display='block';
  drawer.innerHTML=`<div class="drawer-title">${b.property_id?'BridgePoint property':'Building geometry'}</div><div class="muted">${escapeHtml(b.truth_label||'Source-backed geometry')}</div><div class="kv"><b>Source</b><span>${escapeHtml(b.source_name||b.source_key||'—')}</span><b>Height</b><span>${Number(b.render_height_m||0).toFixed(1)} m ${b.height_m?'source':'visual estimate'}</span><b>Floors</b><span>${escapeHtml(b.floors??'—')}</span><b>Property ID</b><span>${escapeHtml(b.property_id||'Association pending')}</span></div>`;
  if(!b.property_id)return;
  try{
    const {data,error}=await supabase.rpc('bridgepoint_flutter_property_detail',{p_property_id:b.property_id});if(error)throw error;
    const d=data||{},address=d.full_address||d.address||d.property?.full_address||'Property profile',score=d.score??d.property_score??d.property?.score;
    drawer.innerHTML=`<div class="drawer-title">${escapeHtml(address)}</div><div class="muted">Live BridgePoint profile bound to the selected 3D structure.</div><div class="kv"><b>Property ID</b><span>${escapeHtml(b.property_id)}</span><b>Risk / score</b><span>${escapeHtml(score??'See profile')}</span><b>Source</b><span>${escapeHtml(b.source_name||b.source_key||'—')}</span><b>3D height</b><span>${Number(b.render_height_m||0).toFixed(1)} m</span></div><div><span class="tag">Permits</span><span class="tag">Storm history</span><span class="tag">Timeline</span><span class="tag">Custom scores</span></div>`;
  }catch(e){console.error(e);}
},Cesium.ScreenSpaceEventType.LEFT_CLICK);

async function loadHazards(){
  if(!hazardsOn){hazardSource.entities.removeAll();viewer.scene.requestRender();return;}
  try{
    const r=await fetch('https://api.weather.gov/alerts/active');const j=await r.json();hazardSource.entities.removeAll();
    for(const f of (j.features||[]).slice(0,tier==='LOW'?120:250)){
      const rings=geometryOuterRings(f.geometry);for(const ring of rings){const coords=ringDegrees(ring);if(!coords)continue;const sev=(f.properties?.severity||'').toLowerCase();const color=sev==='extreme'?Cesium.Color.RED:sev==='severe'?Cesium.Color.ORANGE:Cesium.Color.YELLOW;hazardSource.entities.add({polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),material:color.withAlpha(.16),outline:true,outlineColor:color.withAlpha(.8),height:120},properties:{event:f.properties?.event,headline:f.properties?.headline}});}
    }
    viewer.scene.requestRender();setStatus(`Live NWS alert polygons loaded (${hazardSource.entities.values.length}). Alerts are context—not verified property damage.`,'ok');
  }catch(e){setStatus('Could not load NWS alerts: '+(e?.message||e),'warn');}
}
$('hazards').onclick=()=>{hazardsOn=!hazardsOn;$('hazards').classList.toggle('danger',hazardsOn);loadHazards();};
setInterval(()=>{if(hazardsOn)loadHazards();},60000);

function applyWeather(wx={}){
  const visibilityMiles=Number(wx.visibilityMiles??wx.visibility_miles??10),cloud=clamp(Number(wx.cloudCoverage??wx.cloud_coverage??0),0,100),storm=clamp(Number(wx.stormIntensity??wx.storm_intensity??0),0,1);
  const density=visibilityMiles<1?.0028:visibilityMiles<3?.0011:visibilityMiles<6?.00045:.00018;
  viewer.scene.fog.density=density*(1+storm*.65);viewer.scene.fog.minimumBrightness=clamp(.2-cloud/180-storm*.16,.02,.35);
  viewer.scene.globe.enableLighting=true;
  const precip=String(wx.precipitationType??wx.precipitation_type??'').toLowerCase();weatherFx.className='';if(['rain','snow','hail'].includes(precip))weatherFx.classList.add(precip);
  weatherFx.style.opacity=String(clamp(Number(wx.intensity??wx.precipitationIntensity??.65),.15,1));viewer.scene.requestRender();
  return {visibilityMiles,cloudCoverage:cloud,stormIntensity:storm,precipitationType:precip};
}
window.addEventListener('bridgepoint:weather',e=>applyWeather(e.detail||{}));
window.addEventListener('bp:weather',e=>applyWeather(e.detail||{}));

async function askText(q){
  q=q.trim();if(!q)return;setStatus('Searching BridgePoint…');
  try{const {data,error}=await supabase.rpc('bridgepoint_universal_search_context_v244',{p_query:q,p_limit:8});if(error)throw error;const text=typeof data==='string'?data:JSON.stringify(data);drawer.style.display='block';drawer.innerHTML=`<div class="drawer-title">Spatial search</div><div class="muted">${escapeHtml(q)}</div><pre style="white-space:pre-wrap;font-size:11px;color:#d8e7f1">${escapeHtml(text.slice(0,5500))}</pre>`;setStatus('BridgePoint search complete.','ok');}catch(e){setStatus('Search unavailable: '+(e?.message||e),'bad');}
}
$('ask').onclick=()=>askText($('voiceText').value);$('voiceText').addEventListener('keydown',e=>{if(e.key==='Enter')askText(e.target.value)});
const SR=window.SpeechRecognition||window.webkitSpeechRecognition;$('mic').onclick=()=>{if(!SR){setStatus('This browser does not expose Web Speech recognition. Type the spatial question instead.','warn');return;}const r=new SR();r.lang='en-US';r.interimResults=false;r.onresult=e=>{const q=e.results[0][0].transcript;$('voiceText').value=q;askText(q)};r.onerror=e=>setStatus('Voice recognition: '+e.error,'warn');r.start();};

async function boot(){
  setStatus(`BridgePoint World V${VERSION} • calibrating ${tier} device profile…`);
  const terrainPromise=installTerrain();const countryPromise=loadCountries();const photorealPromise=installPhotoreal();
  const [{data:{session}}]=await Promise.all([supabase.auth.getSession(),terrainPromise,countryPromise,photorealPromise]);
  if(!session)setStatus(`World V${VERSION} ready • ${tier} profile • sign in on the main app to stream protected property intelligence.`,'warn');
  else setStatus(`World V${VERSION} ready • ${tier} profile • continuous U.S. zoom enabled.`,'ok');
  lockGuard(true);streamBuildings(true);
}

window.BridgePointWorldV2400={
  version:VERSION,viewer,streamBuildings,applyWeather,loadHazards,
  setPhotoreal(enabled){photorealWanted=Boolean(enabled);syncPhotorealVisibility();},
  get state(){return{version:VERSION,tier,deviceMemory,cores,mobile,photorealReady,photorealWanted,cameraHeightMeters:cameraHeight(),focus:currentFocus,countryLockReady:countries.length>0,lockedCountry:selectedCountry?.code||null,buildings:buildingSource.entities.values.length,parcels:parcelSource.entities.values.length,roofs:roofSource.entities.values.length,hazards:hazardSource.entities.values.length};}
};
boot().catch(e=>{console.error(e);setStatus('BridgePoint World failed to start: '+(e?.message||e),'bad');});
