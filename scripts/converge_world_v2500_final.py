from pathlib import Path
import re

ROOT = Path('web/bridgepoint-3d-world')
WORLD = ROOT / 'world-v2500.js'
INSPECTOR = ROOT / 'world-v2500-inspector.js'
LIVING = ROOT / 'world-v2500-living.js'
REQ = Path('docs/BRIDGEPOINT_WORLD_REQUIREMENTS_V2500.md')


def swap(text, old, new, label, required=True):
    if new in text:
        return text
    if old not in text:
        if required:
            raise SystemExit(f'{label}: expected source marker not found')
        return text
    return text.replace(old, new, 1)


def replace_region(text, start, end, replacement, label):
    if replacement in text:
        return text
    a = text.find(start)
    b = text.find(end, a + len(start)) if a >= 0 else -1
    if a < 0 or b < 0:
        raise SystemExit(f'{label}: region markers not found')
    return text[:a] + replacement + text[b:]


world = WORLD.read_text(encoding='utf-8')

# Give the globe a lawful, global visual base while retaining USGS as the high-resolution U.S. layer.
world = swap(
    world,
    "const USGS_IMAGERY = 'https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/{z}/{y}/{x}';",
    "const NASA_GIBS_WMTS = 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/wmts.cgi';\nconst USGS_IMAGERY = 'https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/{z}/{y}/{x}';",
    'NASA GIBS global base marker',
)
world = swap(
    world,
    "// No vendor data provider: CesiumJS is the renderer. The base imagery is public USGS National Map.",
    "// CesiumJS is only the renderer. NASA GIBS supplies the free/public global visual base; USGS National Map overlays higher-resolution U.S. imagery.",
    'public imagery comment',
)
old_imagery = """const imagery = new Cesium.UrlTemplateImageryProvider({
  url: USGS_IMAGERY,
  maximumLevel: 23,
  credit: new Cesium.Credit('U.S. Geological Survey — The National Map')
});
viewer.imageryLayers.addImageryProvider(imagery);"""
new_imagery = """const globalImagery = new Cesium.WebMapTileServiceImageryProvider({
  url: NASA_GIBS_WMTS,
  layer: 'BlueMarble_ShadedRelief_Bathymetry',
  style: 'default',
  format: 'image/jpeg',
  tileMatrixSetID: 'GoogleMapsCompatible_Level8',
  maximumLevel: 8,
  credit: new Cesium.Credit('NASA EOSDIS GIBS — Blue Marble')
});
viewer.imageryLayers.addImageryProvider(globalImagery);
const imagery = new Cesium.UrlTemplateImageryProvider({
  url: USGS_IMAGERY,
  maximumLevel: 23,
  credit: new Cesium.Credit('U.S. Geological Survey — The National Map')
});
viewer.imageryLayers.addImageryProvider(imagery);"""
world = swap(world, old_imagery, new_imagery, 'global + U.S. imagery stack')

# Camera journeys are explicit, interruptible, and never resume after a manual gesture.
world = swap(
    world,
    "lab:null, session:null, terrain:null, living:null",
    "lab:null, session:null, terrain:null, living:null, cameraJourney:0",
    'camera journey state',
)

# Source height wins. An existing BridgePoint render-height field may be displayed as an estimate.
# If both are absent, preserve the exact source footprint flat instead of inventing 8.5 m / 3 m massing.
old_build = "const g=rowGeometry(b),ground=finite(b.ground_elevation_m??b.elevation_m)||0,height=Math.max(3,finite(b.render_height_m??b.height_m)||8.5),color=scoreColor(b);"
new_build = "const g=rowGeometry(b),ground=finite(b.ground_elevation_m??b.elevation_m)||0,sourceHeight=finite(b.height_m??b.source_height_m),renderHeight=finite(b.render_height_m),height=sourceHeight!==null&&sourceHeight>0?sourceHeight:(renderHeight!==null&&renderHeight>0?renderHeight:null),color=scoreColor(b);"
world = swap(world, old_build, new_build, 'truthful building height')
world = swap(world, "extrudedHeight:ground+height,material:Cesium.Color.fromCssColorString(color).withAlpha(.96)", "extrudedHeight:height===null?undefined:ground+height,material:Cesium.Color.fromCssColorString(color).withAlpha(1)", 'opaque truthful building massing')
world = world.replace("Cesium.Color.fromCssColorString(old).withAlpha(.96)", "Cesium.Color.fromCssColorString(old).withAlpha(1)")
world = world.replace("ground+height+2", "ground+(height||0)+2")

# Roof geometry may render only at a supplied/approved height. Never fabricate +4 m roof massing.
old_roof = "for(const [i,r] of (data.roofs||[]).entries()){const base=finite(r.roof_base_m??r.ground_elevation_m)||0,top=Math.max(base+.5,finite(r.roof_top_m??r.render_height_m)||base+4);addPolygonEntity(sources.roofs,r,i,{prefix:'roof',height:base,extrudedHeight:top,color:'#c9dbe2',alpha:.42,outline:'#eefcff',outlineAlpha:.7,distance:new Cesium.DistanceDisplayCondition(0,15000)})}"
new_roof = "for(const [i,r] of (data.roofs||[]).entries()){const base=finite(r.roof_base_m??r.ground_elevation_m)||0,top=finite(r.roof_top_m??r.height_m??r.render_height_m);addPolygonEntity(sources.roofs,r,i,{prefix:'roof',height:base,extrudedHeight:top!==null&&top>base?top:undefined,color:'#c9dbe2',alpha:.72,outline:'#eefcff',outlineAlpha:.82,distance:new Cesium.DistanceDisplayCondition(0,15000)})}"
world = swap(world, old_roof, new_roof, 'truthful roof height')

# Keep thermal/hotspot records in the wildfire family without ever synthesizing a fire point.
world = swap(
    world,
    "if(text.includes('wildfire')||text.includes('forest fire')||text.includes('brush fire'))return'wildfire';",
    "if(text.includes('wildfire')||text.includes('forest fire')||text.includes('brush fire')||text.includes('thermal')||text.includes('hotspot'))return'wildfire';",
    'thermal hazard classification',
)

# Structure Lab must return to the exact camera that existed before opening.
lab_start = "async function openLabForCurrent(){"
lab_end = "\n\nasync function startAtUser(){"
lab_replacement = """function snapshotWorldCamera(){return{destination:Cesium.Cartesian3.clone(viewer.camera.positionWC),orientation:{heading:viewer.camera.heading,pitch:viewer.camera.pitch,roll:viewer.camera.roll}}}
function restoreWorldCamera(s){if(!s)return;viewer.camera.setView({destination:s.destination,orientation:s.orientation});viewer.scene.requestRender()}
async function openLabForCurrent(){
  const c=state.currentCard;if(!c)return;let detail=c.buildingDetail;
  if(!detail){try{detail=await resolveBuildingDetail(c.building)}catch(e){renderCardModel(c.model,{error:`Structure lab detail unavailable: ${e?.message||e}`});return}}
  if(state.lab)state.lab.destroy();
  const savedCamera=snapshotWorldCamera();let restored=false;
  const restore=()=>{if(restored)return;restored=true;state.lab=null;restoreWorldCamera(savedCamera)};
  state.lab=await createStructureLab({root:$('studyLab'),canvasHost:$('studyCanvas'),infoHost:$('labInfo'),measurementHost:$('measurement'),detail,onClose:restore});
  $('labClose').onclick=()=>state.lab?.destroy();$('labReset').onclick=()=>state.lab?.reset();$('labMeasure').onclick=()=>state.lab?.measure();$('labXray').onclick=()=>{const on=state.lab?.xray();$('labXray').classList.toggle('active',Boolean(on))}
}"""
world = replace_region(world, lab_start, lab_end, lab_replacement + "\n\n", 'exact Structure Lab camera restoration')

# Replace snap-style search/location flights with an interruption-safe globe→regional→city→close sequence.
cam_start = "async function startAtUser(){"
cam_end = "\n\nviewer.camera.changed.addEventListener"
cam_replacement = """function cancelCameraJourney(){state.cameraJourney++;viewer.camera.cancelFlight?.();state.living?.stopFly?.()}
function cameraFlightStep(lon,lat,height,pitch,duration,token){return new Promise(resolve=>{if(token!==state.cameraJourney)return resolve(false);viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(lon,lat,height),orientation:{heading:viewer.camera.heading,pitch:Cesium.Math.toRadians(pitch),roll:0},duration,complete:()=>resolve(token===state.cameraJourney),cancel:()=>resolve(false)})})}
async function cinematicFlyTo(lon,lat,finalHeight=1800){
  const token=++state.cameraJourney;state.living?.stopFly?.();const current=cameraHeight();const stages=[];
  if(current>1200000)stages.push([560000,-76,.72]);
  if(finalHeight<120000&&current>140000)stages.push([90000,-66,.68]);
  if(finalHeight<18000&&current>16000)stages.push([12000,-54,.62]);
  stages.push([finalHeight,finalHeight<5000?-47:-52,.68]);
  for(const [height,pitch,duration] of stages)if(!(await cameraFlightStep(lon,lat,height,pitch,duration,token)))return false;
  return true
}
async function startAtUser(){
  cancelCameraJourney();viewer.camera.setView({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0}});if(!navigator.geolocation)return;
  await new Promise(resolve=>navigator.geolocation.getCurrentPosition(async p=>{const lon=p.coords.longitude,lat=p.coords.latitude,c=countryAt(lon,lat);if(!c||unlocked(c))await cinematicFlyTo(lon,lat,13000);resolve()},()=>resolve(),{enableHighAccuracy:true,timeout:6500,maximumAge:120000}))
}
async function searchPlace(q){q=q.trim();if(!q)return;setStatus('Searching BridgePoint…');try{const data=await rpcTimed('bridgepoint_universal_search_context_v244',{p_query:q,p_limit:8},8000);const rows=Array.isArray(data)?data:(data?.results||data?.items||[]);const first=rows.find(r=>finite(r.latitude)!==null&&finite(r.longitude??r.lng)!==null);if(first){const lat=finite(first.latitude),lon=finite(first.longitude??first.lng);await cinematicFlyTo(lon,lat,1800);setStatus(`BridgePoint search centered on ${first.full_address||first.title||q}.`,'ok')}else setStatus(`BridgePoint search returned context for “${q}” but no map coordinate.`, 'warn')}catch(e){setStatus(`Search unavailable: ${e?.message||e}`,'bad')}}
viewer.scene.canvas.addEventListener('pointerdown',cancelCameraJourney,{passive:true});
viewer.scene.canvas.addEventListener('wheel',cancelCameraJourney,{passive:true});"""
world = replace_region(world, cam_start, cam_end, cam_replacement + "\n\n", 'progressive camera journey')
world = swap(
    world,
    "$('usButton').onclick=()=>viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0},duration:1});",
    "$('usButton').onclick=()=>{cancelCameraJourney();viewer.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(-98.35,39.5,5600000),orientation:{heading:0,pitch:Cesium.Math.toRadians(-88),roll:0},duration:1})};",
    'explicit U.S. reset cancels journey',
)

WORLD.write_text(world, encoding='utf-8')

inspector = INSPECTOR.read_text(encoding='utf-8')
old_height_truth = """function heightTruth(detail = {}) {
  const b = detailBuilding(detail);
  const source = num(b.height_m ?? b.source_height_m ?? detail.height_m);
  const render = num(b.render_height_m ?? detail.render_height_m ?? source);
  return {
    height: Math.max(1, source ?? render ?? 8.5),
    sourceBacked: source !== null && source > 0,
    label: source !== null && source > 0 ? 'source height' : 'visual estimate',
  };
}"""
new_height_truth = """function heightTruth(detail = {}) {
  const b = detailBuilding(detail);
  const source = num(b.height_m ?? b.source_height_m ?? detail.height_m);
  const render = num(b.render_height_m ?? detail.render_height_m);
  const sourceHeight = source !== null && source > 0 ? source : null;
  const renderHeight = render !== null && render > 0 ? render : null;
  return {
    height: sourceHeight ?? renderHeight ?? 0,
    sourceBacked: sourceHeight !== null,
    label: sourceHeight !== null ? 'source height' : (renderHeight !== null ? 'BridgePoint visual estimate' : 'height unavailable · source footprint only'),
  };
}"""
inspector = swap(inspector, old_height_truth, new_height_truth, 'inspector truthful height')

old_roof_cue = """function addRoofCue(THREE, scene, shapes, h, detail) {
  const b = detailBuilding(detail);
  const roof = String(b.roof_shape ?? b.roof_type ?? detail.roof_shape ?? '').toLowerCase();
  if (!roof || !shapes.length) return;
  const color = 0xd7e3e9;
  for (const s of shapes) {
    const geo = new THREE.ShapeGeometry(s);
    const mesh = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color, transparent: true, opacity: .68, side: THREE.DoubleSide }));
    mesh.position.z = h + .02;
    scene.add(mesh);
  }
}"""
new_roof_cue = """function roofGeometry(detail = {}) {
  const b = detailBuilding(detail), p = detailProperty(detail);
  return b.roof_geometry || b.roof_geometry_geojson || p.roof_geometry || detail.roof_geometry || null;
}
function addRoofCue(THREE, scene, h, detail, projector) {
  const rings = outerRings(roofGeometry(detail));
  if (!rings.length || !projector) return;
  for (const ring of rings) {
    const shape = shapeFromRing(THREE, ring, projector.point); if (!shape) continue;
    const geo = new THREE.ShapeGeometry(shape);
    const mesh = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color: 0xd7e3e9, transparent: false, opacity: 1, side: THREE.DoubleSide, roughness: .72 }));
    mesh.position.z = Math.max(0, h) + .02;
    scene.add(mesh);
  }
}"""
inspector = swap(inspector, old_roof_cue, new_roof_cue, 'source-only roof cue')
inspector = swap(inspector, "['Height', `${ht.height.toFixed(1)} m · ${ht.label}`],", "['Height', ht.height > 0 ? `${ht.height.toFixed(1)} m · ${ht.label}` : ht.label],", 'inspector missing-height label')
old_mesh = """const geo = new THREE.ExtrudeGeometry(shape, { depth: ht.height, bevelEnabled: false, steps: 1 });
    const mat = new THREE.MeshStandardMaterial({ color: 0x36bed7, roughness: .68, metalness: .08, transparent: true, opacity: .9 });"""
new_mesh = """const geo = ht.height > 0 ? new THREE.ExtrudeGeometry(shape, { depth: ht.height, bevelEnabled: false, steps: 1 }) : new THREE.ShapeGeometry(shape);
    const mat = new THREE.MeshStandardMaterial({ color: 0x36bed7, roughness: .68, metalness: .08, transparent: false, opacity: 1, side: THREE.DoubleSide });"""
inspector = swap(inspector, old_mesh, new_mesh, 'opaque inspector mesh')
inspector = swap(inspector, "addRoofCue(THREE, scene, shapes, ht.height, detail);", "addRoofCue(THREE, scene, ht.height, detail, projector);", 'exact roof cue invocation')
inspector = swap(inspector, "m.material.transparent = true; m.material.opacity = xray ? .25 : .9;", "m.material.transparent = xray; m.material.opacity = xray ? .25 : 1;", 'opaque xray restore')
INSPECTOR.write_text(inspector, encoding='utf-8')

living = LIVING.read_text(encoding='utf-8')
old_public = "async function refreshPublic(force=false){if(!enabled)return;const v=getViewRectangle?.();if(!v)return;const h=getCameraHeight?.()||1000000,k=bboxKey(v,h);if(!force&&k===contextKey)return;contextKey=k;if(contextAbort)contextAbort.abort();contextAbort=new AbortController();const signal=contextAbort.signal;const primary=getPrimaryCounts?.()||{};ds.roads.entities.removeAll();ds.rails.entities.removeAll();ds.water.entities.removeAll();ds.labels.entities.removeAll();"
new_public = "async function refreshPublic(force=false){if(!enabled)return;const v=getViewRectangle?.();if(!v)return;const h=getCameraHeight?.()||1000000,k=bboxKey(v,h),primary=getPrimaryCounts?.()||{};if(primary.roads>0)ds.roads.entities.removeAll();if(primary.rails>0)ds.rails.entities.removeAll();if(primary.water>0)ds.water.entities.removeAll();if(!force&&k===contextKey){viewer.scene.requestRender();return}contextKey=k;if(contextAbort)contextAbort.abort();contextAbort=new AbortController();const signal=contextAbort.signal;ds.roads.entities.removeAll();ds.rails.entities.removeAll();ds.water.entities.removeAll();ds.labels.entities.removeAll();"
living = swap(living, old_public, new_public, 'BridgePoint geometry wins over public fallback')
LIVING.write_text(living, encoding='utf-8')

req = REQ.read_text(encoding='utf-8')
marker = '## Final convergence additions — V2500'
if marker not in req:
    req += """

## Final convergence additions — V2500

- The globe uses a free/public NASA EOSDIS GIBS global visual base beneath the free/public USGS National Map U.S. imagery layer. BridgePoint-owned/source-governed building and property geometry remains the product geometry; imagery is visual context only.
- Normal building massing is opaque. Exact source height wins; an already-governed BridgePoint render-height may appear only as a labeled visual estimate. When neither exists, keep the exact footprint flat rather than inventing a height.
- Roof surfaces never receive a synthetic +4 m/default extrusion. Structure Lab roof cues require actual roof geometry; a roof-shape text value alone cannot create roof geometry.
- Search/location movement is an interruptible staged globe→regional→city→close camera journey. Any manual pointer/wheel gesture cancels it; no delayed snap-back is permitted.
- Structure + Parcel Lab snapshots and restores the exact world camera on close.
- Living public context includes source-backed government road/rail/water labels, jurisdiction labels, USGS earthquake context, NOAA ocean/tide context, NOAA/NHC storm context and animated NOAA cloud frames. BridgePoint geometry wins immediately whenever both BridgePoint and public fallback geometry exist.
- Thermal/hotspot records may be classified into wildfire context, but close-up fire effects still require an observed/source-backed point; no synthetic fire/lightning/flood-depth point is allowed.
- Moving effects are budgeted and request-rendered without reviving the historical map runtime or adding another primary world canvas.
"""
REQ.write_text(req, encoding='utf-8')

# Truth guardrails: fail before commit if any known fabricated-height path survived.
checks = {
    'world synthetic 8.5m height': '||8.5',
    'world synthetic roof +4m': 'base+4',
    'inspector synthetic 8.5m height': '?? 8.5',
    'semi-transparent main buildings': 'withAlpha(.96)',
}
joined = WORLD.read_text(encoding='utf-8') + '\n' + INSPECTOR.read_text(encoding='utf-8')
for label, needle in checks.items():
    if needle in joined:
        raise SystemExit(f'{label} remains: {needle}')
for needle in ['NASA_GIBS_WMTS','cinematicFlyTo','snapshotWorldCamera','height unavailable · source footprint only','roofGeometry(detail','primary.roads>0']:
    if needle not in (WORLD.read_text(encoding='utf-8') + INSPECTOR.read_text(encoding='utf-8') + LIVING.read_text(encoding='utf-8')):
        raise SystemExit(f'final convergence marker missing: {needle}')
print('BridgePoint World V2500 final convergence repairs applied.')
