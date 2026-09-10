(() => {
  'use strict';

  const RELEASE = '2026-08-19.0';
  const PMTILES_URL = `https://overturemaps-extras-us-west-2.s3.us-west-2.amazonaws.com/tiles/${RELEASE}/buildings.pmtiles`;
  const MAX_NATIVE_ENTITIES = 6500;
  const MAX_TILES = 28;
  const MIN_NATIVE_HEIGHT = 2.8;
  const SOURCE_NAME = 'bp-overture-source-native-buildings';
  const STATE = {
    viewer:null, source:null, pm:null, VectorTile:null, Pbf:null, header:null,
    seq:0, timer:null, enabled:true, loadedKey:'', busy:false, failed:false,
    release:RELEASE, url:PMTILES_URL
  };

  window.BRIDGEPOINT_SOURCE_NATIVE_BUILDINGS = STATE;

  function finite(v){ const n=Number(v); return Number.isFinite(n) ? n : null; }
  function clamp(v,min,max){ return Math.max(min,Math.min(max,v)); }
  function cameraHeight(){ return STATE.viewer?.camera?.positionCartographic?.height || 1e9; }
  function viewRectangle(){
    const v=STATE.viewer; if(!v)return null;
    const r=v.camera.computeViewRectangle(v.scene.globe.ellipsoid); if(!r)return null;
    return {west:Cesium.Math.toDegrees(r.west),south:Cesium.Math.toDegrees(r.south),east:Cesium.Math.toDegrees(r.east),north:Cesium.Math.toDegrees(r.north)};
  }
  function nativeZoom(h){
    const max=Number(STATE.header?.maxZoom ?? 14);
    if(h>90000)return null;
    if(h>45000)return Math.min(max,12);
    if(h>14000)return Math.min(max,13);
    return Math.min(max,14);
  }
  function lonX(lon,z){const n=2**z;return clamp(Math.floor((lon+180)/360*n),0,n-1)}
  function latY(lat,z){
    const n=2**z, p=clamp(lat,-85.05112878,85.05112878)*Math.PI/180;
    return clamp(Math.floor((1-Math.asinh(Math.tan(p))/Math.PI)/2*n),0,n-1);
  }
  function tileRanges(v,z){
    const ys=[latY(v.north,z),latY(v.south,z)].sort((a,b)=>a-b), out=[];
    const spans=v.east>=v.west?[[v.west,v.east]]:[[v.west,180],[-180,v.east]];
    for(const [w,e] of spans){const xs=[lonX(w,z),lonX(e,z)].sort((a,b)=>a-b);out.push({x0:xs[0],x1:xs[1],y0:ys[0],y1:ys[1]})}
    return out;
  }
  function candidateTiles(v,z){
    const all=[]; for(const r of tileRanges(v,z))for(let y=r.y0;y<=r.y1;y++)for(let x=r.x0;x<=r.x1;x++)all.push({z,x,y});
    if(all.length<=MAX_TILES)return all;
    const c=STATE.viewer.camera.positionCartographic, lon=Cesium.Math.toDegrees(c.longitude), lat=Cesium.Math.toDegrees(c.latitude), cx=lonX(lon,z),cy=latY(lat,z);
    all.sort((a,b)=>(Math.abs(a.x-cx)+Math.abs(a.y-cy))-(Math.abs(b.x-cx)+Math.abs(b.y-cy)));
    return all.slice(0,MAX_TILES);
  }
  function outerRings(g){
    if(g?.type==='Polygon')return g.coordinates?.[0]?[g.coordinates[0]]:[];
    if(g?.type==='MultiPolygon')return(g.coordinates||[]).map(p=>p?.[0]).filter(Boolean);
    return [];
  }
  function flatDegrees(ring){
    const out=[]; for(const p of ring||[])if(Number.isFinite(+p[0])&&Number.isFinite(+p[1]))out.push(+p[0],+p[1]);
    return out.length>=6?out:null;
  }
  function prop(p,...names){for(const n of names)if(p?.[n]!==undefined&&p?.[n]!==null&&String(p[n])!=='')return p[n];return null}
  function renderHeight(p){
    const source=finite(prop(p,'height','@height'));
    if(source!==null&&source>0)return{value:source,truth:'SOURCE_HEIGHT'};
    const floors=finite(prop(p,'num_floors','levels','level'));
    if(floors!==null&&floors>0)return{value:Math.max(MIN_NATIVE_HEIGHT,floors*3.2),truth:'DERIVED_FROM_FLOORS'};
    return{value:MIN_NATIVE_HEIGHT,truth:'DISPLAY_DEFAULT_NO_SOURCE_HEIGHT'};
  }
  function color(kind,p){
    if(kind==='building_part')return Cesium.Color.fromCssColorString('#9fd5df').withAlpha(.96);
    return Cesium.Color.fromCssColorString(prop(p,'facade_color','@facade_color')||'#7caeb8').withAlpha(.94);
  }
  function privateBuildingCount(){
    try{return STATE.viewer.dataSources.getByName('bp-buildings')?.[0]?.entities?.values?.length||0}catch(_){return 0}
  }
  function clear(){if(STATE.source)STATE.source.entities.removeAll();STATE.viewer?.scene?.requestRender()}
  function key(v,z){return `${z}:${v.west.toFixed(3)}:${v.south.toFixed(3)}:${v.east.toFixed(3)}:${v.north.toFixed(3)}`}

  async function modules(){
    const [{PMTiles},{VectorTile},{default:Pbf}] = await Promise.all([
      import('https://cdn.jsdelivr.net/npm/pmtiles@4.5.0/+esm'),
      import('https://cdn.jsdelivr.net/npm/@mapbox/vector-tile@3.0.0/+esm'),
      import('https://cdn.jsdelivr.net/npm/pbf@5.1.2/+esm')
    ]);
    STATE.VectorTile=VectorTile;STATE.Pbf=Pbf;STATE.pm=new PMTiles(PMTILES_URL);STATE.header=await STATE.pm.getHeader();
  }

  async function loadTile(t,seq,budget){
    const rr=await STATE.pm.getZxy(t.z,t.x,t.y); if(!rr?.data||seq!==STATE.seq)return 0;
    const vt=new STATE.VectorTile(new STATE.Pbf(rr.data)); let added=0;
    for(const kind of ['building','building_part']){
      const layer=vt.layers?.[kind]; if(!layer)continue;
      const step=Math.max(1,Math.ceil(layer.length/Math.max(1,budget)));
      for(let i=0;i<layer.length&&added<budget&&STATE.source.entities.values.length<MAX_NATIVE_ENTITIES;i+=step){
        if(seq!==STATE.seq)return added;
        const f=layer.feature(i); if(f.type!==3)continue;
        const gj=f.toGeoJSON(t.x,t.y,t.z), p={...(f.properties||{}),id:f.properties?.id||f.id||null};
        const rh=renderHeight(p), ground=finite(prop(p,'min_height'))||0;
        for(const ring of outerRings(gj.geometry)){
          const coords=flatDegrees(ring);if(!coords)continue;
          const e=STATE.source.entities.add({
            id:`overture-${RELEASE}-${kind}-${t.z}-${t.x}-${t.y}-${p.id||i}-${STATE.source.entities.values.length}`,
            polygon:{
              hierarchy:Cesium.Cartesian3.fromDegreesArray(coords),height:ground,extrudedHeight:ground+rh.value,
              material:color(kind,p),outline:true,outlineColor:Cesium.Color.fromCssColorString('#d9f7fb').withAlpha(.26),
              distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,95000)
            }
          });
          e.bridgepoint={...p,geometry:gj.geometry,source_key:`OVERTURE_PM_TILES_${RELEASE.replaceAll('-','').replace('.','_')}`,source_name:'Overture Maps',asset_kind:kind,height_m:finite(prop(p,'height','@height')),render_height_m:rh.value,height_truth:rh.truth,source_release:RELEASE,source_native:true};
          added++; if(added>=budget||STATE.source.entities.values.length>=MAX_NATIVE_ENTITIES)break;
        }
      }
    }
    return added;
  }

  async function refresh(force=false){
    if(!STATE.enabled||STATE.failed||STATE.busy||!STATE.pm)return;
    const h=cameraHeight(), z=nativeZoom(h); if(z===null){clear();STATE.loadedKey='';return}
    const v=viewRectangle(); if(!v)return; const k=key(v,z);if(!force&&k===STATE.loadedKey)return;
    STATE.loadedKey=k;STATE.busy=true;const seq=++STATE.seq;
    try{
      // BridgePoint property-linked buildings remain authoritative when the current viewport is already populated.
      // Source-native Overture fills national gaps; it is not bulk-copied into BridgePoint storage.
      if(privateBuildingCount()>=120){clear();return}
      clear(); const tiles=candidateTiles(v,z), per=Math.max(120,Math.floor(MAX_NATIVE_ENTITIES/Math.max(1,tiles.length)));
      const queue=[...tiles]; const workers=Array.from({length:Math.min(4,queue.length)},async()=>{while(queue.length&&seq===STATE.seq&&STATE.source.entities.values.length<MAX_NATIVE_ENTITIES){const t=queue.shift();try{await loadTile(t,seq,per)}catch(e){console.warn('Overture building tile skipped',t,e)}}});
      await Promise.all(workers);if(seq===STATE.seq)STATE.viewer.scene.requestRender();
    } finally {if(seq===STATE.seq)STATE.busy=false}
  }
  function schedule(){clearTimeout(STATE.timer);STATE.timer=setTimeout(()=>refresh(false),420)}
  function bindToggle(){
    const b=document.querySelector('[data-layer="buildings"]');if(!b)return;
    b.addEventListener('click',()=>{STATE.enabled=!STATE.enabled;if(STATE.source)STATE.source.show=STATE.enabled;if(STATE.enabled)schedule();else clear()});
  }
  async function start(viewer){
    if(STATE.viewer)return;STATE.viewer=viewer;STATE.source=new Cesium.CustomDataSource(SOURCE_NAME);viewer.dataSources.add(STATE.source);bindToggle();
    try{await modules();viewer.creditDisplay?.addStaticCredit?.(new Cesium.Credit('Overture Maps Foundation'));viewer.camera.changed.addEventListener(schedule);viewer.camera.moveEnd.addEventListener(()=>refresh(true));await refresh(true);console.info(`BridgePoint source-native buildings ready: Overture ${RELEASE}`)}
    catch(e){STATE.failed=true;console.error('BridgePoint source-native building fallback unavailable',e)}
  }

  // Capture the V2500 Cesium Viewer without changing the existing world module's internal API.
  try{
    const OriginalViewer=Cesium.Viewer;
    Cesium.Viewer=new Proxy(OriginalViewer,{construct(target,args){const viewer=Reflect.construct(target,args,target);queueMicrotask(()=>start(viewer));return viewer}});
  }catch(e){console.error('BridgePoint viewer capture failed',e)}
})();
