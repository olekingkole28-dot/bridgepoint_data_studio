import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { createStructureLab } from './world-v2500-inspector.js';

const VERSION = 2500;
const SUPABASE_URL = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const SUPABASE_KEY = 'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
const USGS_IMAGERY = 'https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/{z}/{y}/{x}';
const NWS_RADAR_WMS = 'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?';
const NWS_RADAR_QUERY = 'https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer/query';
const NATURAL_EARTH_COUNTRIES = 'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson';
const US_CODES = new Set(['US','USA','PR','GU','VI','AS','MP','UM']);
const LOCK_HEIGHT_M = 350000;

const mobile = /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);
const memory = Number(navigator.deviceMemory || 4);
const cores = Number(navigator.hardwareConcurrency || 4);
const tier = memory <= 4 || cores <= 4 ? 'LOW' : (!mobile && memory >= 8 && cores >= 8 ? 'HIGH' : 'MEDIUM');
const PERF = Object.freeze(tier === 'LOW'
  ? { scale:.72, fps:30, detail:[550,850,1150], labels:70, weather:90 }
  : tier === 'HIGH'
    ? { scale:1, fps:60, detail:[1500,2300,3500], labels:260, weather:280 }
    : { scale:mobile?.86:.95, fps:45, detail:[950,1500,2200], labels:150, weather:170 });

const $ = (id) => document.getElementById(id);
const statusEl = $('status'), card = $('propertyCard'), layerPanel = $('layerPanel'), weatherFx = $('weatherFx'), lockCard = $('lockCard');
const esc = (v) => String(v ?? '').replace(/[&<>'"]/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const finite = (v) => Number.isFinite(Number(v)) ? Number(v) : null;
const clamp = (v,min,max) => Math.max(min,Math.min(max,v));
const fmt = (v, digits=1) => finite(v) === null ? null : Number(v).toLocaleString(undefined,{maximumFractionDigits:digits});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const setStatus = (text, kind='') => { statusEl.className = `panel ${kind}`; statusEl.textContent = text; };

// No vendor data provider: CesiumJS is the renderer. The base imagery is public USGS National Map.
const viewer = new Cesium.Viewer('cesiumContainer', {
  animation:false, timeline:false, baseLayerPicker:false, geocoder:false, homeButton:false,
  sceneModePicker:false, navigationHelpButton:false, fullscreenButton:false, infoBox:false,
  selectionIndicator:false, baseLayer:false, terrainProvider:new Cesium.EllipsoidTerrainProvider(),
  requestRenderMode:true, maximumRenderTimeChange:Infinity, shouldAnimate:true
});
viewer.resolutionScale = PERF.scale;
viewer.targetFrameRate = PERF.fps;
viewer.scene.backgroundColor = Cesium.Color.fromCssColorString('#020711');
viewer.scene.globe.baseColor = Cesium.Color.fromCssColorString('#07111a');
viewer.scene.globe.depthTestAgainstTerrain = true;
viewer.scene.globe.enableLighting = true;
viewer.scene.globe.showGroundAtmosphere = true;
viewer.scene.fog.enabled = true;
viewer.scene.fog.density = .00017;
viewer.scene.skyAtmosphere.show = true;
viewer.scene.screenSpaceCameraController.minimumZoomDistance = 1.6;
viewer.scene.screenSpaceCameraController.maximumZoomDistance = 26000000;
viewer.scene.screenSpaceCameraController.enableCollisionDetection = true;
viewer.camera.percentageChanged = .025;

const imagery = new Cesium.UrlTemplateImageryProvider({
  url: USGS_IMAGERY,
  maximumLevel: 16,
  credit: new Cesium.Credit('U.S. Geological Survey — The National Map')
});
viewer.imageryLayers.addImageryProvider(imagery);

for (const ev of ['touchstart','touchmove','touchend','wheel']) {
  viewer.scene.canvas.addEventListener(ev, (e) => { if (e.cancelable) e.preventDefault(); }, { passive:false });
}

const sources = {
  buildings:new Cesium.CustomDataSource('bp-buildings'), parcels:new Cesium.CustomDataSource('bp-parcels'), roofs:new Cesium.CustomDataSource('bp-roofs'),
  roads:new Cesium.CustomDataSource('bp-roads'), rails:new Cesium.CustomDataSource('bp-rails'), water:new Cesium.CustomDataSource('bp-water'),
  parking:new Cesium.CustomDataSource('bp-parking'), streetlights:new Cesium.CustomDataSource('bp-streetlights'), vegetation:new Cesium.CustomDataSource('bp-vegetation'),
  labels:new Cesium.CustomDataSource('bp-labels'), weather:new Cesium.CustomDataSource('bp-weather'), locks:new Cesium.CustomDataSource('bp-country-locks')
};
Object.values(sources).forEach((s) => viewer.dataSources.add(s));

const state = {
  countries:[], focus:null, locked:null, guarding:false,
  viewportKey:'', viewportBusy:false, viewportSeq:0, selectedEntity:null,
  radar:true, radarLayer:null, radarTime:null, weatherBusy:false, weatherSeq:0, weatherLast:0,
  fx:false, weatherFilters:new Set(['all']), weatherPrimitives:[],
  propertyCircles:false, layers:{buildings:true,parcels:true,roofs:true,roads:true,rails:true,water:true,parking:true,streetlights:true,vegetation:true,labels:true},
  detailCache:new Map(), buildingCache:new Map(), cardToken:0, currentCard:null,
  lab:null, session:null
};

function cameraHeight(){ return viewer.camera.positionCartographic?.height || 100000; }
function viewRectangle(){
  const r=viewer.camera.computeViewRectangle(viewer.scene.globe.ellipsoid); if(!r)return null;
  return {west:Cesium.Math.toDegrees(r.west),south:Cesium.Math.toDegrees(r.south),east:Cesium.Math.toDegrees(r.east),north:Cesium.Math.toDegrees(r.north)};
}
function keyFor(v,h){return [v.west,v.south,v.east,v.north].map(x=>x.toFixed(h<1200?4:h<10000?3:2)).join(':')+':'+Math.round(Math.log10(Math.max(h,1))*4)}
function focusPoint(){const c=viewer.scene.canvas,p=viewer.camera.pickEllipsoid(new Cesium.Cartesian2(c.clientWidth/2,c.clientHeight/2),Cesium.Ellipsoid.WGS84);if(!p)return null;const q=Cesium.Cartographic.fromCartesian(p);return{lon:Cesium.Math.toDegrees(q.longitude),lat:Cesium.Math.toDegrees(q.latitude)}}
function normalizeAround(x,a){let v=Number(x);while(v-a>180)v-=360;while(v-a<-180)v+=360;return v}
function pointInRing(lon,lat,ring){let inside=false;for(let i=0,j=ring.length-1;i<ring.length;j=i++){const xi=normalizeAround(ring[i][0],lon),yi=Number(ring[i][1]),xj=normalizeAround(ring[j][0],lon),yj=Number(ring[j][1]);if(((yi>lat)!==(yj>lat))&&(lon<(xj-xi)*(lat-yi)/((yj-yi)||1e-12)+xi))inside=!inside}return inside}
function pointInPolygon(lon,lat,p){if(!p?.length||!pointInRing(lon,lat,p[0]))return false;for(let i=1;i<p.length;i++)if(pointInRing(lon,lat,p[i]))return false;return true}
function pointInGeometry(lon,lat,g){if(g?.type==='Polygon')return pointInPolygon(lon,lat,g.coordinates||[]);if(g?.type==='MultiPolygon')return(g.coordinates||[]).some(point=>pointInPolygon(lon,lat,point));return false}
function outerRings(g){if(g?.type==='Polygon')return g.coordinates?.[0]?[g.coordinates[0]]:[];if(g?.type==='MultiPolygon')return(g.coordinates||[]).map(p=>p?.[0]).filter(Boolean);return[]}
function lineStrings(g){if(g?.type==='LineString')return[g.coordinates||[]];if(g?.type==='MultiLineString')return g.coordinates||[];if(g?.type==='Polygon')return g.coordinates?.length?[g.coordinates[0]]:[];if(g?.type==='MultiPolygon')return(g.coordinates||[]).map(p=>p?.[0]).filter(Boolean);return[]}
function degrees(ring){const out=[];for(const p of ring||[])if(Number.isFinite(+p[0])&&Number.isFinite(+p[1]))out.push(+p[0],+p[1]);return out.length>=4?out:null}
function centerOfRing(ring){let x=0,y=0,n=0;for(const p of ring||[])if(Number.isFinite(+p[0])&&Number.isFinite(+p[1])){x+=+p[0];y+=+p[1];n++}return n?[x/n,y/n]:null}
function rowGeometry(row){return row?.geometry||row?.geometry_geojson||row?.geom_geojson||row?.footprint||null}
function countryAt(lon,lat){for(const c of state.countries){if(lat<c.bbox[1]||lat>c.bbox[3])continue;if(pointInGeometry(lon,lat,c.geometry))return c}return null}
function unlocked(c){return !c||US_CODES.has(c.code)}

async function loadCountries(){
  try{
    const res=await fetch(NATURAL_EARTH_COUNTRIES,{cache:'force-cache'});if(!res.ok)throw new Error(`Natural Earth ${res.status}`);const j=await res.json();state.countries=[];sources.locks.entities.removeAll();
    for(const f of j.features||[]){const p=f.properties||{},code=String(p.ISO_A2||p.ISO_A2_EH||p.ADM0_A3||'').toUpperCase(),name=String(p.NAME_EN||p.ADMIN||p.NAME||'Country');if(!code)continue;const pts=outerRings(f.geometry).flat();if(!pts.length)continue;let minX=180,minY=90,maxX=-180,maxY=-90;for(const q of pts){minX=Math.min(minX,+q[0]);minY=Math.min(minY,+q[1]);maxX=Math.max(maxX,+q[0]);maxY=Math.max(maxY,+q[1]);}const c={code,name,geometry:f.geometry,bbox:[minX,minY,maxX,maxY]};state.countries.push(c);if(unlocked(c))continue;
      for(const ring of outerRings(f.geometry)){const coords=degrees(ring);if(!coords)continue;sources.locks.entities.add({polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),material:Cesium.Color.fromCssColorString('#151a1f').withAlpha(.31),outline:true,outlineColor:Cesium.Color.fromCssColorString('#ffc95e').withAlpha(.5),height:0,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(600000,26000000)}})}
    }
    viewer.scene.requestRender();
  }catch(e){console.warn(e);setStatus('Public country-lock geometry is unavailable; deep property streaming remains U.S.-gated by session/data.', 'warn')}
}
function showLock(c){if(!c||unlocked(c))return;state.locked=c;$('lockTitle').textContent=`${c.name} — Locked`;$('lockText').textContent='Under Construction. Deep property zoom stays disabled here until BridgePoint completes source, legal, geometry and quality gates.';lockCard.classList.add('open')}
function hideLock(){state.locked=null;lockCard.classList.remove('open')}
function guardCountry(){if(state.guarding||!state.countries.length)return;const f=focusPoint();if(!f)return;const c=countryAt(f.lon,f.lat);state.focus={...f,country:c};if(c&&!unlocked(c)&&cameraHeight()<LOCK_HEIGHT_M){state.guarding=true;showLock(c);clearPropertyGeometry();const p=viewer.camera.positionCartographic;viewer.camera.setView({destination:Cesium.Cartesian3.fromRadians(p.longitude,p.latitude,LOCK_HEIGHT_M),orientation:{heading:viewer.camera.heading,pitch:viewer.camera.pitch,roll:viewer.camera.roll}});setStatus(`${c.name} is locked — deep zoom stopped at BridgePoint's expansion boundary.`,'warn');setTimeout(()=>state.guarding=false,0)}else if(!c||unlocked(c)){if(state.locked)hideLock()}}

function setVisible(name,visible){state.layers[name]=visible;const ds=sources[name];if(ds)ds.show=visible;viewer.scene.requestRender()}
function clearPropertyGeometry(){for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','labels'])sources[k].entities.removeAll();state.viewportKey='';viewer.scene.requestRender()}
function scoreColor(row){const s=finite(row?.render_score??row?.opportunity_score??row?.score);if(s!==null&&s>=80)return'#ffb13b';if(s!==null&&s>=65)return'#f8d76b';return row?.height_m?'#36bed7':'#d9aa42'}
function addPolygonEntity(ds,row,index,opts={}){const g=rowGeometry(row);let added=0;for(const ring of outerRings(g)){const coords=degrees(ring);if(!coords||coords.length<6)continue;const e=ds.entities.add({id:`${opts.prefix||ds.name}-${row.property_id||row.id||index}-${ds.entities.values.length}`,polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),height:finite(opts.height??row.ground_elevation_m??0)||0,extrudedHeight:opts.extrudedHeight??undefined,material:Cesium.Color.fromCssColorString(opts.color||'#48e1ff').withAlpha(opts.alpha??.25),outline:true,outlineColor:Cesium.Color.fromCssColorString(opts.outline||opts.color||'#48e1ff').withAlpha(opts.outlineAlpha??.8),distanceDisplayCondition:opts.distance||undefined}});e.bridgepoint=row;added++}return added}
function addLines(ds,rows,{color='#cbd8df',width=1.2,maxDistance=80000,prefix='line'}={}){let n=0;for(const [i,row] of (rows||[]).entries()){for(const line of lineStrings(rowGeometry(row))){const coords=degrees(line);if(!coords)continue;const e=ds.entities.add({id:`${prefix}-${row.id||row.source_id||i}-${n}`,polyline:{positions:Cesium.Cartesian3.fromDegreesArray(coords),width,material:Cesium.Color.fromCssColorString(color),clampToGround:true,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,maxDistance)}});e.bridgepoint=row;n++}}return n}
function addPoints(ds,rows,{color='#f8e8a8',size=5,maxDistance=10000,prefix='point'}={}){let n=0;for(const [i,row] of (rows||[]).entries()){const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat===null||lon===null)continue;ds.entities.add({id:`${prefix}-${row.id||i}`,position:Cesium.Cartesian3.fromDegrees(lon,lat,finite(row.elevation_m)||1.5),point:{pixelSize:size,color:Cesium.Color.fromCssColorString(color),outlineColor:Cesium.Color.fromCssColorString('#071018'),outlineWidth:1,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,maxDistance)}});n++}return n}

function renderViewport(data={}){
  clearPropertyGeometry();let labels=0;
  for(const [i,b] of (data.buildings||[]).entries()){
    const g=rowGeometry(b),ground=finite(b.ground_elevation_m??b.elevation_m)||0,height=Math.max(3,finite(b.render_height_m??b.height_m)||8.5),color=scoreColor(b);
    for(const ring of outerRings(g)){const coords=degrees(ring);if(!coords||coords.length<6)continue;const e=sources.buildings.entities.add({id:`building-${b.source_key||'bp'}-${b.building_id||i}-${sources.buildings.entities.values.length}`,polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),height:ground,extrudedHeight:ground+height,material:Cesium.Color.fromCssColorString(color).withAlpha(.64),outline:true,outlineColor:Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.5),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,135000)}});e.bridgepoint={...b,__displayColor:color};
      const label=String(b.building_name||b.facility_name||b.name||b.classification_label||b.category||'').trim();if(label&&labels<PERF.labels){const c=centerOfRing(ring);if(c){sources.labels.entities.add({position:Cesium.Cartesian3.fromDegrees(c[0],c[1],ground+height+2),label:{text:label,font:'700 12px sans-serif',fillColor:Cesium.Color.WHITE,outlineColor:Cesium.Color.fromCssColorString('#061018'),outlineWidth:3,style:Cesium.LabelStyle.FILL_AND_OUTLINE,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,5000),scaleByDistance:new Cesium.NearFarScalar(80,1,5000,.55),disableDepthTestDistance:900}});labels++}}
    }
  }
  for(const [i,p] of (data.parcels||[]).entries())addLines(sources.parcels,[p],{color:finite(p.render_score??p.opportunity_score)>=75?'#ffb13b':'#79e8ff',width:tier==='LOW'?1:1.6,maxDistance:65000,prefix:`parcel-${i}`});
  for(const [i,r] of (data.roofs||[]).entries()){const base=finite(r.roof_base_m??r.ground_elevation_m)||0,top=Math.max(base+.5,finite(r.roof_top_m??r.render_height_m)||base+4);addPolygonEntity(sources.roofs,r,i,{prefix:'roof',height:base,extrudedHeight:top,color:'#c9dbe2',alpha:.42,outline:'#eefcff',outlineAlpha:.7,distance:new Cesium.DistanceDisplayCondition(0,15000)})}
  addLines(sources.roads,data.roads||[],{color:'#e4e2d8',width:2,maxDistance:85000,prefix:'road'});
  addLines(sources.rails,data.railroads||data.rails||[],{color:'#bfcad0',width:2,maxDistance:65000,prefix:'rail'});
  for(const [i,w] of (data.water||data.water_bodies||[]).entries())addPolygonEntity(sources.water,w,i,{prefix:'water',color:'#1f85b8',alpha:.33,outline:'#6cccf2',outlineAlpha:.48,distance:new Cesium.DistanceDisplayCondition(0,120000)});
  for(const [i,p] of (data.parking||data.pavement||[]).entries())addPolygonEntity(sources.parking,p,i,{prefix:'parking',color:'#5e6468',alpha:.45,outline:'#a6afb3',outlineAlpha:.28,distance:new Cesium.DistanceDisplayCondition(0,22000)});
  addPoints(sources.streetlights,data.streetlights||[],{color:'#ffe7a2',size:4,maxDistance:6000,prefix:'light'});
  addPoints(sources.vegetation,data.vegetation||data.trees||[],{color:'#6fbc78',size:5,maxDistance:4500,prefix:'tree'});
  for(const [k,v] of Object.entries(state.layers))if(sources[k])sources[k].show=v;
  viewer.scene.requestRender();
  return {buildings:sources.buildings.entities.values.length,parcels:sources.parcels.entities.values.length,roofs:sources.roofs.entities.values.length,roads:sources.roads.entities.values.length,rails:sources.rails.entities.values.length};
}
async function streamViewport(force=false){
  guardCountry();if(state.viewportBusy)return;const c=state.focus?.country;if(c&&!unlocked(c)){clearPropertyGeometry();return}const h=cameraHeight();if(h>150000){clearPropertyGeometry();setStatus(`BridgePoint World V${VERSION} · ${tier} profile · zoom closer for property geometry.`,'ok');return}const v=viewRectangle();if(!v)return;const k=keyFor(v,h);if(!force&&k===state.viewportKey)return;state.viewportKey=k;state.viewportBusy=true;const seq=++state.viewportSeq;
  try{const limit=h<1000?PERF.detail[2]:h<8000?PERF.detail[1]:PERF.detail[0];const {data,error}=await supabase.rpc('bridgepoint_3d_world_viewport_v1899',{p_west:v.west,p_south:v.south,p_east:v.east,p_north:v.north,p_camera_height_m:h,p_limit:limit});if(error)throw error;if(seq!==state.viewportSeq)return;if(data?.locked){clearPropertyGeometry();setStatus('Sign in with BridgePoint map access to stream protected property intelligence.','warn');return}const counts=renderViewport(data||{});setStatus(`V${VERSION} · ${counts.buildings} buildings · ${counts.parcels} parcel lines · ${counts.roofs} roofs · ${counts.roads} roads · ${counts.rails} rail lines · ${tier} profile.`,'ok')}
  catch(e){console.error(e);setStatus(`BridgePoint property stream unavailable: ${e?.message||e}`,'bad')}finally{state.viewportBusy=false}
}

function hazardKind(row={}){const text=[row.hazard_type,row.event_name,row.event,row.headline,row.title,row.kind,row.category].filter(Boolean).join(' ').toLowerCase();if(text.includes('tornado'))return'tornado';if(text.includes('hurricane')||text.includes('tropical'))return'hurricane';if(text.includes('wildfire')||text.includes('forest fire')||text.includes('brush fire'))return'wildfire';if(text.includes('fire')||text.includes('smoke'))return'fire';if(text.includes('hail'))return'hail';if(text.includes('snow')||text.includes('ice')||text.includes('winter'))return'snow';if(text.includes('flood')||text.includes('surge'))return'flood';if(text.includes('wind')||text.includes('gust'))return'wind';if(text.includes('lightning'))return'lightning';if(text.includes('outage'))return'outage';if(text.includes('rain')||text.includes('precip'))return'rain';return'other'}
function hazardColor(kind){return{tornado:'#a67cff',hurricane:'#789bff',wildfire:'#ff6538',fire:'#ff7048',hail:'#b9f3ff',snow:'#eef8ff',flood:'#42bfff',wind:'#c5d5e5',lightning:'#ffd15c',outage:'#ffe070',rain:'#6c83ff',other:'#48e1ff'}[kind]||'#48e1ff'}
function observed(row){const mode=String(row.effect_mode||row.observation_kind||row.truth_status||'').toUpperCase();return mode.includes('OBSERVED')||mode.includes('CURRENT')||mode.includes('DETECTION')||row.observed===true}
function filtered(kind){return state.weatherFilters.has('all')||state.weatherFilters.has(kind)}
function renderWeatherRows(rows=[]){sources.weather.entities.removeAll();let used=0;for(const [i,row] of rows.entries()){if(used>=PERF.weather)break;const kind=hazardKind(row);if(!filtered(kind))continue;const color=hazardColor(kind),g=rowGeometry(row);for(const ring of outerRings(g)){const coords=degrees(ring);if(!coords||coords.length<6)continue;sources.weather.entities.add({id:`wx-${kind}-${row.hazard_event_id||row.id||i}-${used}`,polygon:{hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),height:90,material:Cesium.Color.fromCssColorString(color).withAlpha(observed(row)?.17:.08),outline:true,outlineColor:Cesium.Color.fromCssColorString(color).withAlpha(observed(row)?.88:.58),distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,9000000)},properties:{kind,event:row.event_name||row.event||row.headline,observed:observed(row)}});used++}}
  viewer.scene.requestRender();return used}
function sceneRows(data){if(Array.isArray(data))return data;if(!data||typeof data!=='object')return[];for(const k of ['events','hazards','items','rows','results'])if(Array.isArray(data[k]))return data[k];return[]}
function sceneLayers(data){if(!data||typeof data!=='object')return[];for(const k of ['continuous_layers','layers','weather_layers'])if(Array.isArray(data[k]))return data[k];return[]}
function currentPrecip(rows,layers){const text=[...rows,...layers].slice(0,250).map(r=>JSON.stringify(r)).join(' ').toLowerCase();if(text.includes('hail'))return'hail';if(text.includes('snow')||text.includes('winter precipitation'))return'snow';if(text.includes('rain')||text.includes('precipitation'))return'rain';return''}
function applyAtmosphere(rows,layers){const all=[...rows,...layers];let visibility=null,cloud=null,storm=0;for(const r of all){visibility??=finite(r.visibility_miles??r.visibilityMiles);cloud??=finite(r.cloud_coverage??r.cloudCoverage);const kind=hazardKind(r);if(['tornado','hurricane','wind','hail'].includes(kind))storm=Math.max(storm,observed(r)?.8:.35)}const vis=visibility??10;viewer.scene.fog.density=(vis<1?.0028:vis<3?.0011:vis<6?.00045:.00017)*(1+storm*.5);viewer.scene.fog.minimumBrightness=clamp(.25-(cloud??0)/180-storm*.12,.03,.3);weatherFx.className='';if(state.fx){const precip=currentPrecip(rows,layers);if(precip)weatherFx.classList.add(`wx-${precip}`)}viewer.scene.requestRender()}
function clearWeatherPrimitives(){for(const p of state.weatherPrimitives.splice(0)){try{viewer.scene.primitives.remove(p);p.destroy?.()}catch(_){}}}
function makeParticleImage(inner,mid,outer){const c=document.createElement('canvas');c.width=64;c.height=64;const x=c.getContext('2d'),g=x.createRadialGradient(32,38,2,32,32,30);g.addColorStop(0,inner);g.addColorStop(.35,mid);g.addColorStop(1,outer);x.fillStyle=g;x.fillRect(0,0,64,64);return c}
function eventCenter(row){const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat!==null&&lon!==null)return[lon,lat];const ring=outerRings(rowGeometry(row))[0];return ring?centerOfRing(ring):null}
function addObservedFireFx(rows){clearWeatherPrimitives();if(!state.fx||cameraHeight()>40000)return;let count=0;for(const row of rows){const kind=hazardKind(row);if(!['wildfire','fire'].includes(kind)||!observed(row)||count>=12)continue;const c=eventCenter(row);if(!c)continue;const acres=Math.max(1,finite(row.acres??row.fire_acres??row.size_acres)||25),scale=clamp(Math.sqrt(acres)/8,.7,5),position=Cesium.Cartesian3.fromDegrees(c[0],c[1],finite(row.elevation_m)||5),matrix=Cesium.Transforms.eastNorthUpToFixedFrame(position);const fire=new Cesium.ParticleSystem({image:makeParticleImage('rgba(255,255,245,1)','rgba(255,110,25,.9)','rgba(130,0,0,0)'),startColor:Cesium.Color.WHITE.withAlpha(.95),endColor:Cesium.Color.RED.withAlpha(0),startScale:.45*scale,endScale:2.4*scale,minimumParticleLife:.45,maximumParticleLife:1.45,minimumSpeed:1.5*scale,maximumSpeed:6*scale,imageSize:new Cesium.Cartesian2(10*scale,18*scale),emissionRate:22*scale,emitter:new Cesium.ConeEmitter(Cesium.Math.toRadians(24)),modelMatrix:matrix,lifetime:Number.MAX_VALUE});viewer.scene.primitives.add(fire);state.weatherPrimitives.push(fire);const smoke=new Cesium.ParticleSystem({image:makeParticleImage('rgba(110,120,125,.65)','rgba(72,80,86,.35)','rgba(35,40,43,0)'),startColor:Cesium.Color.GRAY.withAlpha(.45),endColor:Cesium.Color.DARKGRAY.withAlpha(0),startScale:1.2*scale,endScale:4.8*scale,minimumParticleLife:2,maximumParticleLife:5,minimumSpeed:.7*scale,maximumSpeed:2.2*scale,imageSize:new Cesium.Cartesian2(18*scale,18*scale),emissionRate:5*scale,emitter:new Cesium.ConeEmitter(Cesium.Math.toRadians(14)),modelMatrix:matrix,lifetime:Number.MAX_VALUE});viewer.scene.primitives.add(smoke);state.weatherPrimitives.push(smoke);count++}}
async function loadWeather(force=false){const now=Date.now();if(state.weatherBusy||(!force&&now-state.weatherLast<1800))return;state.weatherBusy=true;state.weatherLast=now;const seq=++state.weatherSeq;const v=viewRectangle();try{let data=null;if(v){const {data:d,error}=await supabase.rpc('bridgepoint_live_map_weather_scene_v1997',{p_min_lat:v.south,p_max_lat:v.north,p_min_lng:v.west,p_max_lng:v.east,p_limit:cameraHeight()<100000?1100:500});if(!error)data=d}if(seq!==state.weatherSeq)return;let rows=sceneRows(data),layers=sceneLayers(data);if(!rows.length&&cameraHeight()>250000){try{const r=await fetch('https://api.weather.gov/alerts/active',{headers:{accept:'application/geo+json'}});if(r.ok){const j=await r.json();rows=(j.features||[]).map(f=>({...f.properties,geometry:f.geometry,effect_mode:'ALERT_FORECAST_CONTEXT'}))}}catch(_){}}
    const n=renderWeatherRows(rows);applyAtmosphere(rows,layers);addObservedFireFx(rows);setStatus(`BridgePoint World V${VERSION} · ${n} source-shaped weather/hazard geometries · radar ${state.radar?'on':'off'} · ${tier} profile.`,'ok')}
  catch(e){console.warn(e);setStatus(`Weather context refresh failed without resetting the map: ${e?.message||e}`,'warn')}finally{state.weatherBusy=false}}
async function latestRadarTime(){try{const u=new URL(NWS_RADAR_QUERY);u.searchParams.set('where','1=1');u.searchParams.set('outFields','idp_validtime');u.searchParams.set('returnGeometry','false');u.searchParams.set('orderByFields','idp_validtime DESC');u.searchParams.set('resultRecordCount','1');u.searchParams.set('f','json');const r=await fetch(u);if(!r.ok)throw new Error(`radar query ${r.status}`);const j=await r.json(),raw=j.features?.[0]?.attributes?.idp_validtime;if(!raw)return null;return new Date(Number(raw)).toISOString()}catch(e){console.warn(e);return null}}
async function refreshRadar(){if(state.radarLayer){viewer.imageryLayers.remove(state.radarLayer,true);state.radarLayer=null}if(!state.radar){viewer.scene.requestRender();return}const time=await latestRadarTime();state.radarTime=time;const provider=new Cesium.WebMapServiceImageryProvider({url:NWS_RADAR_WMS,layers:'0',parameters:{transparent:true,format:'image/png',version:'1.3.0',...(time?{time}:{})},credit:new Cesium.Credit('NOAA / National Weather Service radar')});state.radarLayer=viewer.imageryLayers.addImageryProvider(provider);state.radarLayer.alpha=.58;viewer.scene.requestRender()}

function timeoutPromise(ms,label){return new Promise((_,reject)=>setTimeout(()=>reject(new Error(`${label} timed out after ${ms/1000}s`)),ms))}
async function rpcTimed(name,params,ms=7500){return Promise.race([supabase.rpc(name,params).then(({data,error})=>{if(error)throw error;return data}),timeoutPromise(ms,name)])}
function firstValue(...v){return v.find(x=>x!==undefined&&x!==null&&String(x).trim()!=='')}
function money(v){const n=finite(v);return n===null?null:n.toLocaleString(undefined,{style:'currency',currency:'USD',maximumFractionDigits:0})}
function fact(label,value){if(value===null||value===undefined||String(value).trim()==='')return'';return`<b>${esc(label)}</b><span>${esc(value)}</span>`}
function immediateCardData(b={}){return{address:firstValue(b.full_address,b.address,b.site_address),property_id:b.property_id,parcel:firstValue(b.parcel_id,b.apn),municipality:firstValue(b.municipality,b.city),county:b.county,state:b.state_code,height:finite(b.height_m??b.render_height_m),heightTruth:b.height_m?'source':'visual estimate',floors:firstValue(b.floors,b.floor_count),footprint:firstValue(b.footprint_area_sqft,b.footprint_sqft),year:firstValue(b.year_built,b.built_year),assessed:firstValue(b.assessed_value,b.total_assessed_value),roofShape:firstValue(b.roof_shape,b.roof_type),roofMaterial:b.roof_material,roofPitch:b.roof_pitch,roofArea:firstValue(b.roof_area_sqft,b.roof_sqft),score:firstValue(b.render_score,b.opportunity_score,b.score),source:firstValue(b.source_name,b.source_key),truth:firstValue(b.truth_label,b.height_truth),building:b}}
function mergeDetail(base,detail){if(!detail||typeof detail!=='object')return base;const b=detail.building||detail.structure||{},p=detail.property||detail.property_detail||{};return{...base,address:firstValue(p.full_address,p.address,b.full_address,b.address,base.address),property_id:firstValue(p.property_id,b.property_id,base.property_id),parcel:firstValue(p.parcel_id,p.apn,b.parcel_id,b.apn,base.parcel),municipality:firstValue(p.municipality,p.city,b.municipality,base.municipality),county:firstValue(p.county,b.county,base.county),state:firstValue(p.state_code,b.state_code,base.state),height:firstValue(b.height_m,b.render_height_m,detail.height_m,base.height),heightTruth:firstValue(b.height_truth,detail.height_truth,b.height_m?'source':null,base.heightTruth),floors:firstValue(b.floors,b.floor_count,p.floors,base.floors),footprint:firstValue(b.footprint_area_sqft,b.footprint_sqft,detail.footprint_area_sqft,base.footprint),land:firstValue(p.land_area_sqft,p.lot_size_sqft,p.acres?Number(p.acres)*43560:null,base.land),perimeter:firstValue(p.perimeter_ft,b.perimeter_ft,detail.perimeter_ft,base.perimeter),year:firstValue(p.year_built,b.year_built,base.year),assessed:firstValue(p.assessed_value,p.total_assessed_value,b.assessed_value,base.assessed),roofShape:firstValue(b.roof_shape,b.roof_type,p.roof_shape,base.roofShape),roofMaterial:firstValue(b.roof_material,p.roof_material,base.roofMaterial),roofPitch:firstValue(b.roof_pitch,p.roof_pitch,base.roofPitch),roofArea:firstValue(b.roof_area_sqft,p.roof_area_sqft,base.roofArea),elevation:firstValue(b.ground_elevation_m,p.elevation_m,detail.elevation?.elevation_m,base.elevation),score:firstValue(p.score,p.property_score,b.score,base.score),source:firstValue(b.source_name,b.source_key,p.source_name,base.source),truth:firstValue(b.truth_label,b.height_truth,p.truth_label,base.truth),rawDetail:detail}}
function renderCardModel(model,{loading=false,error=null,enriched=null}={}){const height=finite(model.height),foot=fmt(model.footprint,0),land=fmt(model.land,0),perim=fmt(model.perimeter,1),roofArea=fmt(model.roofArea,0),score=fmt(model.score,1);card.innerHTML=`<div class="cardHead"><div><div class="cardTitle">${esc(model.address||'BridgePoint structure')}</div><div class="cardSub">${esc([model.municipality,model.county,model.state].filter(Boolean).join(' · ')||'Source-backed structure')} · ${esc(model.source||'BridgePoint geometry')}</div></div><button id="cardClose" class="closeButton">×</button></div><div><span class="badge">${esc(model.truth||'source geometry')}</span>${model.score!=null?`<span class="badge gold">score ${esc(score)}</span>`:''}</div><div class="section"><h3>Structure + parcel</h3><div class="facts">${fact('Property ID',model.property_id)}${fact('Parcel / APN',model.parcel)}${fact('Height',height!==null?`${fmt(height,1)} m · ${model.heightTruth||'truth unknown'}`:null)}${fact('Floors',model.floors)}${fact('Footprint',foot?`${foot} sq ft`:null)}${fact('Land / parcel',land?`${land} sq ft`:null)}${fact('Perimeter',perim?`${perim} ft`:null)}${fact('Year built',model.year)}${fact('Assessed',money(model.assessed))}${fact('Elevation',model.elevation!=null?`${fmt(model.elevation,1)} m`:null)}</div></div><div class="section"><h3>Roof</h3><div class="facts">${fact('Shape',model.roofShape)}${fact('Material',model.roofMaterial)}${fact('Pitch',model.roofPitch)}${fact('Area',roofArea?`${roofArea} sq ft`:null)}</div>${!model.roofShape&&!model.roofMaterial&&!model.roofPitch&&!model.roofArea?'<div class="truthNote">No exact roof attribute is being invented. BridgePoint will show roof facts only when a source supplies them.</div>':''}</div>${enriched||''}${loading?'<div class="loadingRow"><i class="spinner"></i>Loading additional BridgePoint property intelligence without blocking this card…</div>':''}${error?`<div class="errorNote">${esc(error)} The already-loaded structure truth remains visible.</div>`:''}<div class="cardActions"><button id="studyStructure" class="gold">Structure + Parcel Lab</button><button id="retryDetail">${error?'Retry enrichment':'Refresh details'}</button></div>`;card.classList.add('open');$('cardClose').onclick=closeCard;$('retryDetail').onclick=()=>enrichCurrentCard(true);$('studyStructure').onclick=()=>openLabForCurrent()}
function enrichmentHtml(results){const chunks=[];for(const [label,data] of results){if(!data)continue;if(label==='Timeline'){const rows=Array.isArray(data)?data:(data.events||data.timeline||[]);if(rows.length)chunks.push(`<div class="section"><h3>Timeline</h3>${rows.slice(0,5).map(r=>`<div class="cardSub">${esc(firstValue(r.event_date,r.occurred_at,r.date,''))} · ${esc(firstValue(r.title,r.event_type,r.description,'Property event'))}</div>`).join('')}</div>`)}else if(label==='Climate'){const t=typeof data==='string'?data:JSON.stringify(data);chunks.push(`<div class="section"><h3>Climate / weather context</h3><div class="cardSub">${esc(t.slice(0,650))}</div></div>`)}else if(label==='Permits'){const rows=Array.isArray(data)?data:(data.permits||data.items||[]);if(rows.length)chunks.push(`<div class="section"><h3>Permits</h3><div class="cardSub">${esc(`${rows.length} permit/context records returned for this property.`)}</div></div>`)}else if(label==='Media'){const rows=Array.isArray(data)?data:(data.media||data.items||[]);if(rows.length)chunks.push(`<div class="section"><h3>Property media</h3><div class="cardSub">${esc(`${rows.length} source media records available in the property profile.`)}</div></div>`)}}return chunks.join('')}
function highlightEntity(entity){if(state.selectedEntity?.polygon){const old=state.selectedEntity.bridgepoint?.__displayColor||'#36bed7';state.selectedEntity.polygon.material=Cesium.Color.fromCssColorString(old).withAlpha(.64);state.selectedEntity.polygon.outlineColor=Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.5)}state.selectedEntity=entity;if(entity?.polygon){const c=entity.bridgepoint?.__displayColor||'#36bed7';entity.polygon.material=Cesium.Color.fromCssColorString(c).withAlpha(.82);entity.polygon.outlineColor=Cesium.Color.WHITE.withAlpha(.95)}viewer.scene.requestRender()}
function closeCard(){card.classList.remove('open');state.currentCard=null;state.cardToken++;highlightEntity(null)}
function buildingResolvePoint(b={}){const lat=finite(b.latitude??b.lat),lon=finite(b.longitude??b.lng??b.lon);if(lat!==null&&lon!==null)return[lon,lat];const ring=outerRings(rowGeometry(b))[0],c=ring?centerOfRing(ring):null;return c&&finite(c[0])!==null&&finite(c[1])!==null?[Number(c[0]),Number(c[1])]:null}
async function resolveBuildingDetail(b={}){const c=buildingResolvePoint(b);if(!c)throw new Error('Source building coordinate is unavailable for exact detail resolution');return rpcTimed('bridgepoint_building_detail_v2300',{p_lng:c[0],p_lat:c[1],p_radius_m:110},7500)}
async function selectBuilding(entity){const b=entity.bridgepoint||{};highlightEntity(entity);const token=++state.cardToken;let model=immediateCardData(b);state.currentCard={entity,building:b,model,buildingDetail:null,enrichment:[]};renderCardModel(model,{loading:true});const key=String(b.building_id||b.source_key||b.property_id||entity.id);try{let detail=state.buildingCache.get(key);if(!detail){detail=await resolveBuildingDetail(b);if(detail)state.buildingCache.set(key,detail)}if(token!==state.cardToken)return;model=mergeDetail(model,detail);state.currentCard.model=model;state.currentCard.buildingDetail=detail;renderCardModel(model,{loading:Boolean(model.property_id)});await enrichCurrentCard(false,token)}catch(e){if(token!==state.cardToken)return;state.currentCard.model=model;renderCardModel(model,{error:e?.message||String(e)})}}
async function enrichCurrentCard(force=false,existingToken=null){const current=state.currentCard;if(!current)return;const token=existingToken??++state.cardToken;const propertyId=current.model.property_id;if(!propertyId){renderCardModel(current.model,{error:'This structure is not yet associated with a canonical property ID, so property-level enrichment cannot run.'});return}const cached=!force?state.detailCache.get(String(propertyId)):null;if(cached){current.enrichment=cached;renderCardModel(current.model,{enriched:enrichmentHtml(cached)});return}renderCardModel(current.model,{loading:true});const calls=[['Property','bridgepoint_flutter_property_detail_v344',{p_property_id:propertyId}],['Timeline','bridgepoint_property_timeline_v857',{p_property_id:propertyId,p_limit:200}],['Climate','bridgepoint_property_climate_profile_v510',{p_property_id:propertyId}],['Twin','bridgepoint_digital_twin_summary_v856',{p_property_id:propertyId}],['Geometry','bridgepoint_property_geometry_v854',{p_property_id:propertyId,p_limit:25}],current.model.municipality?['Permits','bridgepoint_flutter_permit_context_v68',{p_municipality:current.model.municipality}]:null,['Media','bridgepoint_property_media_bundle_v169',{p_property_id:propertyId}]].filter(Boolean);const settled=await Promise.allSettled(calls.map(async([label,rpc,params])=>[label,await rpcTimed(rpc,params,label==='Media'?10000:8000)]));if(token!==state.cardToken)return;const ok=[];const errors=[];for(const r of settled){if(r.status==='fulfilled')ok.push(r.value);else errors.push(r.reason?.message||String(r.reason))}const property=ok.find(([l])=>l==='Property')?.[1];if(property)current.model=mergeDetail(current.model,{property});current.enrichment=ok;state.detailCache.set(String(propertyId),ok);renderCardModel(current.model,{enriched:enrichmentHtml(ok),error:errors.length?`${errors.length} optional enrichment source${errors.length===1?'':'s'} did not answer in time.`:null})}
async function openLabForCurrent(){const c=state.currentCard;if(!c)return;let detail=c.buildingDetail;if(!detail){try{detail=await resolveBuildingDetail(c.building)}catch(e){renderCardModel(c.model,{error:`Structure lab detail unavailable: ${e?.message||e}`});return}}if(state.lab)state.lab.destroy();state.lab=await createStructureLab({root:$('studyLab'),canvasHost:$('studyCanvas'),infoHost:$('labInfo'),measurementHost:$('measurement'),detail,onClose:()=>state.lab=null});$('labClose').onclick=()=>state.lab?.destroy();$('labReset').onclick=()=>state.lab?.reset();$('labMeasure').onclick=()=>state.lab?.measure();$('labXray').onclick=()=>{const on=state.lab?.xray();$('labXray').classList.toggle('active',Boolean(on))}}

async function startAtUser(){viewer.camera.setView({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0}});if(!navigator.geolocation)return;await new Promise(resolve=>navigator.geolocation.getCurrentPosition(p=>{const lon=p.coords.longitude,lat=p.coords.latitude,c=countryAt(lon,lat);if(!c||unlocked(c))viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(lon,lat,13000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-52),roll:0},duration:.8});resolve()},()=>resolve(),{enableHighAccuracy:true,timeout:6500,maximumAge:120000}))}
async function searchPlace(q){q=q.trim();if(!q)return;setStatus('Searching BridgePoint…');try{const data=await rpcTimed('bridgepoint_universal_search_context_v244',{p_query:q,p_limit:8},8000);const rows=Array.isArray(data)?data:(data?.results||data?.items||[]);const first=rows.find(r=>finite(r.latitude)!==null&&finite(r.longitude??r.lng)!==null);if(first){const lat=finite(first.latitude),lon=finite(first.longitude??first.lng);viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(lon,lat,1800),orientation:{heading:0,pitch:Cesium.Math.toRadians(-47),roll:0},duration:.9});setStatus(`BridgePoint search centered on ${first.full_address||first.title||q}.`,'ok')}else setStatus(`BridgePoint search returned context for “${q}” but no map coordinate.`, 'warn')}catch(e){setStatus(`Search unavailable: ${e?.message||e}`,'bad')}}

viewer.camera.changed.addEventListener(()=>guardCountry());
viewer.camera.moveEnd.addEventListener(()=>{guardCountry();streamViewport(false);loadWeather(false)});
viewer.screenSpaceEventHandler.setInputAction((movement)=>{const picked=viewer.scene.pick(movement.position),entity=picked?.id;if(entity?.bridgepoint&&String(entity.id||'').startsWith('building-'))selectBuilding(entity)},Cesium.ScreenSpaceEventType.LEFT_CLICK);

$('layersButton').onclick=()=>layerPanel.classList.toggle('open');
$('locationButton').onclick=()=>startAtUser();
$('usButton').onclick=()=>viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0},duration:1});
$('radarButton').onclick=()=>{state.radar=!state.radar;$('radarButton').classList.toggle('active',state.radar);refreshRadar()};
$('fxButton').onclick=()=>{state.fx=!state.fx;$('fxButton').classList.toggle('active',state.fx);loadWeather(true)};
$('propertyCirclesButton').onclick=()=>{state.propertyCircles=!state.propertyCircles;$('propertyCirclesButton').classList.toggle('active',state.propertyCircles);setStatus(`Property circles ${state.propertyCircles?'enabled':'disabled'}. Building and parcel geometry are unchanged.`,'ok')};
$('lockClose').onclick=hideLock;
$('searchButton').onclick=()=>searchPlace($('searchInput').value);
$('searchInput').addEventListener('keydown',e=>{if(e.key==='Enter')searchPlace(e.target.value)});
for(const btn of document.querySelectorAll('[data-layer]'))btn.onclick=()=>{const name=btn.dataset.layer;setVisible(name,!state.layers[name]);btn.classList.toggle('active',state.layers[name])};
for(const btn of document.querySelectorAll('[data-weather]'))btn.onclick=()=>{const k=btn.dataset.weather;if(k==='all'){state.weatherFilters=new Set(['all']);for(const b of document.querySelectorAll('[data-weather]'))b.classList.toggle('active',b.dataset.weather==='all')}else{state.weatherFilters.delete('all');if(state.weatherFilters.has(k))state.weatherFilters.delete(k);else state.weatherFilters.add(k);btn.classList.toggle('active',state.weatherFilters.has(k));if(!state.weatherFilters.size){state.weatherFilters.add('all');document.querySelector('[data-weather="all"]')?.classList.add('active')}}loadWeather(true)};

setInterval(()=>refreshRadar(),120000);
setInterval(()=>loadWeather(false),60000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden){streamViewport(true);loadWeather(true);if(state.radar)refreshRadar()}});
window.addEventListener('pageshow',()=>{streamViewport(true);loadWeather(true)});

async function boot(){
  setStatus(`BridgePoint World V${VERSION} · recovering source state…`);
  const sessionPromise=supabase.auth.getSession();
  await loadCountries();
  await startAtUser();
  const {data:{session}}=await sessionPromise;state.session=session;
  $('radarButton').classList.add('active');
  for(const b of document.querySelectorAll('[data-layer]'))b.classList.toggle('active',state.layers[b.dataset.layer]);
  document.querySelector('[data-weather="all"]')?.classList.add('active');
  await Promise.allSettled([refreshRadar(),streamViewport(true),loadWeather(true)]);
  if(!session)setStatus(`World V${VERSION} ready with public context. Sign in on BridgePoint to stream protected property intelligence.`,'warn');
  else setStatus(`World V${VERSION} ready · public-only context · BridgePoint property truth · ${tier} device profile.`,'ok');
}

window.BridgePointWorldV2500={
  version:VERSION,viewer,streamViewport,loadWeather,refreshRadar,
  selectBuilding,openLabForCurrent,
  get state(){return{version:VERSION,tier,memory,cores,mobile,radar:state.radar,fx:state.fx,lockedCountry:state.locked?.code||null,cameraHeightMeters:cameraHeight(),focus:state.focus,buildings:sources.buildings.entities.values.length,parcels:sources.parcels.entities.values.length,weather:sources.weather.entities.values.length,selectedProperty:state.currentCard?.model?.property_id||null,publicOnly:true}}
};
boot().catch(e=>{console.error(e);setStatus(`BridgePoint World failed to start: ${e?.message||e}`,'bad')});
