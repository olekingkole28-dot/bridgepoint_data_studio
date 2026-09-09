from pathlib import Path

js_path = Path('web/bridgepoint-3d-world/world-v2500.js')
css_path = Path('web/bridgepoint-3d-world/world-v2500.css')
js = js_path.read_text(encoding='utf-8')
css = css_path.read_text(encoding='utf-8')


def transition(text: str, old: str, new: str, label: str) -> str:
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 1 and new_count == 0:
        print(f'fixed {label}')
        return text.replace(old, new, 1)
    if old_count == 0 and new_count == 1:
        print(f'already fixed {label}')
        return text
    raise SystemExit(f'{label}: contract drift old={old_count} new={new_count}')


# ----- Existing RPC correctness repairs -----
js = transition(
    js,
    "function closeCard(){card.classList.remove('open');state.currentCard=null;state.cardToken++;highlightEntity(null)}\nasync function selectBuilding(entity)",
    "function closeCard(){card.classList.remove('open');state.currentCard=null;state.cardToken++;highlightEntity(null)}\nfunction buildingResolvePoint(b={}){const lat=finite(b.latitude??b.lat),lon=finite(b.longitude??b.lng??b.lon);if(lat!==null&&lon!==null)return[lon,lat];const ring=outerRings(rowGeometry(b))[0],c=ring?centerOfRing(ring):null;return c&&finite(c[0])!==null&&finite(c[1])!==null?[Number(c[0]),Number(c[1])]:null}\nasync function resolveBuildingDetail(b={}){const c=buildingResolvePoint(b);if(!c)throw new Error('Source building coordinate is unavailable for exact detail resolution');return rpcTimed('bridgepoint_building_detail_v2300',{p_lng:c[0],p_lat:c[1],p_radius_m:110},7500)}\nasync function selectBuilding(entity)",
    'exact building-detail coordinate resolver',
)
js = transition(
    js,
    "rpcTimed('bridgepoint_building_detail_v2300',{p_building_id:b.building_id??null,p_property_id:b.property_id??null,p_source_key:b.source_key??null},7500)",
    "resolveBuildingDetail(b)",
    'card building-detail RPC signature',
)
js = transition(
    js,
    "rpcTimed('bridgepoint_building_detail_v2300',{p_building_id:c.building.building_id??null,p_property_id:c.model.property_id??null,p_source_key:c.building.source_key??null},7500)",
    "resolveBuildingDetail(c.building)",
    'lab building-detail RPC signature',
)
js = transition(
    js,
    "const calls=[['Property', 'bridgepoint_flutter_property_detail_v344',{p_property_id:propertyId}],['Timeline','bridgepoint_property_timeline_v857',{p_property_id:propertyId}],['Climate','bridgepoint_property_climate_profile_v510',{p_property_id:propertyId}],['Twin','bridgepoint_digital_twin_summary_v856',{p_property_id:propertyId}],['Geometry','bridgepoint_property_geometry_v854',{p_property_id:propertyId}],['Permits','bridgepoint_flutter_permit_context_v68',{p_property_id:propertyId}],['Media','bridgepoint_property_media_bundle_v169',{p_property_id:propertyId}]];",
    "const calls=[['Property','bridgepoint_flutter_property_detail_v344',{p_property_id:propertyId}],['Timeline','bridgepoint_property_timeline_v857',{p_property_id:propertyId,p_limit:200}],['Climate','bridgepoint_property_climate_profile_v510',{p_property_id:propertyId}],['Twin','bridgepoint_digital_twin_summary_v856',{p_property_id:propertyId}],['Geometry','bridgepoint_property_geometry_v854',{p_property_id:propertyId,p_limit:25}],current.model.municipality?['Permits','bridgepoint_flutter_permit_context_v68',{p_municipality:current.model.municipality}]:null,['Media','bridgepoint_property_media_bundle_v169',{p_property_id:propertyId}]].filter(Boolean);",
    'Property 360 enrichment RPC signatures',
)

# ----- Source-backed property circles -----
js = transition(
    js,
    "  labels:new Cesium.CustomDataSource('bp-labels'), weather:new Cesium.CustomDataSource('bp-weather'), locks:new Cesium.CustomDataSource('bp-country-locks')",
    "  propertyPoints:new Cesium.CustomDataSource('bp-property-points'), labels:new Cesium.CustomDataSource('bp-labels'), weather:new Cesium.CustomDataSource('bp-weather'), locks:new Cesium.CustomDataSource('bp-country-locks')",
    'property point source',
)
js = transition(
    js,
    "for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','labels'])sources[k].entities.removeAll();",
    "for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','propertyPoints','labels'])sources[k].entities.removeAll();",
    'property point cleanup',
)
js = transition(
    js,
    "function renderViewport(data={}){\n  clearPropertyGeometry();let labels=0;",
    "function renderPropertyCircles(data={}){sources.propertyPoints.entities.removeAll();const raw=Array.isArray(data.properties)&&data.properties.length?data.properties:(data.buildings||[]).filter(r=>r?.property_id);let n=0;for(const row of raw){if(n>=PERF.detail[1])break;let lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat===null||lon===null){const ring=outerRings(rowGeometry(row))[0],c=ring?centerOfRing(ring):null;if(!c)continue;lon=finite(c[0]);lat=finite(c[1])}if(lat===null||lon===null)continue;sources.propertyPoints.entities.add({id:`property-point-${row.property_id||row.id||n}`,position:Cesium.Cartesian3.fromDegrees(lon,lat,(finite(row.ground_elevation_m??row.elevation_m)||0)+1.8),point:{pixelSize:7,color:Cesium.Color.fromCssColorString('#48e1ff').withAlpha(.78),outlineColor:Cesium.Color.fromCssColorString('#061018'),outlineWidth:1,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,24000)},properties:{property_id:row.property_id||row.id,source_backed:true}});n++}sources.propertyPoints.show=state.propertyCircles;return n}\nfunction renderViewport(data={}){\n  clearPropertyGeometry();let labels=0;",
    'source-backed property circles renderer',
)
js = transition(
    js,
    "  addPoints(sources.vegetation,data.vegetation||data.trees||[],{color:'#6fbc78',size:5,maxDistance:4500,prefix:'tree'});\n  for(const [k,v] of Object.entries(state.layers))if(sources[k])sources[k].show=v;",
    "  addPoints(sources.vegetation,data.vegetation||data.trees||[],{color:'#6fbc78',size:5,maxDistance:4500,prefix:'tree'});\n  renderPropertyCircles(data);\n  for(const [k,v] of Object.entries(state.layers))if(sources[k])sources[k].show=v;",
    'property circle viewport population',
)
js = transition(
    js,
    "$('propertyCirclesButton').onclick=()=>{state.propertyCircles=!state.propertyCircles;$('propertyCirclesButton').classList.toggle('active',state.propertyCircles);setStatus(`Property circles ${state.propertyCircles?'enabled':'disabled'}. Building and parcel geometry are unchanged.`,'ok')};",
    "$('propertyCirclesButton').onclick=()=>{state.propertyCircles=!state.propertyCircles;sources.propertyPoints.show=state.propertyCircles;$('propertyCirclesButton').classList.toggle('active',state.propertyCircles);viewer.scene.requestRender();setStatus(`Property circles ${state.propertyCircles?'enabled':'disabled'}. Only source-associated property points are shown.`,'ok')};",
    'functional property circle toggle',
)

# ----- Imagery fidelity: USGS advertises LODs 0-23. -----
js = transition(js, '  maximumLevel: 16,', '  maximumLevel: 23,', 'USGS imagery full published LOD range')

# ----- Viewport race/refresh repairs -----
js = transition(
    js,
    "  viewportKey:'', viewportBusy:false, viewportSeq:0, selectedEntity:null,",
    "  viewportKey:'', viewportBusy:false, viewportPending:false, viewportSeq:0, selectedEntity:null,",
    'viewport pending state',
)
js = transition(
    js,
    "  radar:true, radarLayer:null, radarTime:null, weatherBusy:false, weatherSeq:0, weatherLast:0,",
    "  radar:true, radarLayer:null, radarTime:null, weatherBusy:false, weatherPending:false, weatherSeq:0, weatherLast:0,",
    'weather pending state',
)
js = transition(
    js,
    "function clearPropertyGeometry(){for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','propertyPoints','labels'])sources[k].entities.removeAll();state.viewportKey='';viewer.scene.requestRender()}",
    "function clearPropertyGeometry({resetKey=true}={}){for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','propertyPoints','labels'])sources[k].entities.removeAll();if(resetKey)state.viewportKey='';viewer.scene.requestRender()}",
    'viewport cache preservation primitive',
)
js = transition(
    js,
    "function renderViewport(data={}){\n  clearPropertyGeometry();let labels=0;",
    "function renderViewport(data={}){\n  clearPropertyGeometry({resetKey:false});let labels=0;",
    'render without erasing viewport cache key',
)
js = transition(
    js,
    "  guardCountry();if(state.viewportBusy)return;const c=state.focus?.country;",
    "  guardCountry();if(state.viewportBusy){state.viewportPending=true;state.viewportSeq++;return}const c=state.focus?.country;",
    'queue latest viewport while a request is in flight',
)
js = transition(
    js,
    "  catch(e){console.error(e);setStatus(`BridgePoint property stream unavailable: ${e?.message||e}`,'bad')}finally{state.viewportBusy=false}\n}",
    "  catch(e){console.error(e);setStatus(`BridgePoint property stream unavailable: ${e?.message||e}`,'bad')}finally{state.viewportBusy=false;if(state.viewportPending){state.viewportPending=false;queueMicrotask(()=>streamViewport(true))}}\n}",
    'replay latest viewport after in-flight request',
)
js = transition(
    js,
    "async function loadWeather(force=false){const now=Date.now();if(state.weatherBusy||(!force&&now-state.weatherLast<1800))return;state.weatherBusy=true;state.weatherLast=now;const seq=++state.weatherSeq;const v=viewRectangle();",
    "async function loadWeather(force=false){const now=Date.now();if(state.weatherBusy){state.weatherPending=true;state.weatherSeq++;return}if(!force&&now-state.weatherLast<1800)return;state.weatherBusy=true;state.weatherLast=now;const seq=++state.weatherSeq;const v=viewRectangle();",
    'queue latest weather camera state',
)
js = transition(
    js,
    "  catch(e){console.warn(e);setStatus(`Weather context refresh failed without resetting the map: ${e?.message||e}`,'warn')}finally{state.weatherBusy=false}}",
    "  catch(e){console.warn(e);setStatus(`Weather context refresh failed without resetting the map: ${e?.message||e}`,'warn')}finally{state.weatherBusy=false;if(state.weatherPending){state.weatherPending=false;queueMicrotask(()=>loadWeather(true))}}}",
    'replay latest weather refresh',
)

# ----- Local-only physical weather: never rain across the whole screen because a distant polygon exists. -----
js = transition(
    js,
    "function currentPrecip(rows,layers){const text=[...rows,...layers].slice(0,250).map(r=>JSON.stringify(r)).join(' ').toLowerCase();if(text.includes('hail'))return'hail';if(text.includes('snow')||text.includes('winter precipitation'))return'snow';if(text.includes('rain')||text.includes('precipitation'))return'rain';return''}\nfunction applyAtmosphere(rows,layers){const all=[...rows,...layers];let visibility=null,cloud=null,storm=0;for(const r of all){visibility??=finite(r.visibility_miles??r.visibilityMiles);cloud??=finite(r.cloud_coverage??r.cloudCoverage);const kind=hazardKind(r);if(['tornado','hurricane','wind','hail'].includes(kind))storm=Math.max(storm,observed(r)?.8:.35)}const vis=visibility??10;viewer.scene.fog.density=(vis<1?.0028:vis<3?.0011:vis<6?.00045:.00017)*(1+storm*.5);viewer.scene.fog.minimumBrightness=clamp(.25-(cloud??0)/180-storm*.12,.03,.3);weatherFx.className='';if(state.fx){const precip=currentPrecip(rows,layers);if(precip)weatherFx.classList.add(`wx-${precip}`)}viewer.scene.requestRender()}",
    "function currentPrecip(rows,layers){const text=[...rows,...layers].slice(0,250).map(r=>JSON.stringify(r)).join(' ').toLowerCase();if(text.includes('hail'))return'hail';if(text.includes('snow')||text.includes('winter precipitation'))return'snow';if(text.includes('rain')||text.includes('precipitation'))return'rain';return''}\nfunction rowAffectsFocus(row={}){const f=state.focus||focusPoint();if(!f)return false;const g=rowGeometry(row);if(g&&pointInGeometry(f.lon,f.lat,g))return true;const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat===null||lon===null)return false;const dy=(lat-f.lat)*111.32,dx=(lon-f.lon)*111.32*Math.cos(f.lat*Math.PI/180);return Math.hypot(dx,dy)<=25}\nfunction applyAtmosphere(rows,layers){const localRows=rows.filter(rowAffectsFocus),localLayers=layers.filter(rowAffectsFocus),all=[...localRows,...localLayers];let visibility=null,cloud=null,storm=0;for(const r of all){visibility??=finite(r.visibility_miles??r.visibilityMiles);cloud??=finite(r.cloud_coverage??r.cloudCoverage);const kind=hazardKind(r);if(['tornado','hurricane','wind','hail'].includes(kind))storm=Math.max(storm,observed(r)?.8:.35)}const vis=visibility??10;viewer.scene.fog.density=(vis<1?.0028:vis<3?.0011:vis<6?.00045:.00017)*(1+storm*.5);viewer.scene.fog.minimumBrightness=clamp(.25-(cloud??0)/180-storm*.12,.03,.3);weatherFx.className='';if(state.fx){const precip=currentPrecip(localRows,localLayers);if(precip)weatherFx.classList.add(`wx-${precip}`)}viewer.scene.requestRender()}",
    'camera-local atmosphere and precipitation',
)

# Perimeter geometry is not an exact flame/hotspot location. Only explicit points may emit flames.
js = transition(
    js,
    "function eventCenter(row){const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat!==null&&lon!==null)return[lon,lat];const ring=outerRings(rowGeometry(row))[0];return ring?centerOfRing(ring):null}",
    "function eventCenter(row,{allowGeometry=true}={}){const lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat!==null&&lon!==null)return[lon,lat];if(!allowGeometry)return null;const ring=outerRings(rowGeometry(row))[0];return ring?centerOfRing(ring):null}",
    'explicit-vs-perimeter event center truth',
)
js = transition(js, "const c=eventCenter(row);if(!c)continue;", "const c=eventCenter(row,{allowGeometry:false});if(!c)continue;", 'fire particles require explicit source point')

# ----- Solid close-up buildings while preserving BridgePoint opportunity/intelligence hue. -----
js = transition(
    js,
    "material:Cesium.Color.fromCssColorString(color).withAlpha(.64),outline:true,outlineColor:Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.5)",
    "material:Cesium.Color.fromCssColorString(color).withAlpha(.96),outline:true,outlineColor:Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.62)",
    'opaque source building massing',
)
js = transition(
    js,
    "state.selectedEntity.polygon.material=Cesium.Color.fromCssColorString(old).withAlpha(.64);state.selectedEntity.polygon.outlineColor=Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.5)",
    "state.selectedEntity.polygon.material=Cesium.Color.fromCssColorString(old).withAlpha(.96);state.selectedEntity.polygon.outlineColor=Cesium.Color.fromCssColorString('#b4f7ff').withAlpha(.62)",
    'restore solid building after selection',
)
js = transition(
    js,
    "entity.polygon.material=Cesium.Color.fromCssColorString(c).withAlpha(.82);entity.polygon.outlineColor=Cesium.Color.WHITE.withAlpha(.95)",
    "entity.polygon.material=Cesium.Color.fromCssColorString(c).withAlpha(1);entity.polygon.outlineColor=Cesium.Color.WHITE.withAlpha(.98)",
    'solid selected building highlight',
)

# ----- Mobile gesture ownership: scroll cards, never the world page while touching the globe. -----
css = transition(css, 'body{touch-action:none}', 'body{touch-action:manipulation}', 'body touch behavior')
css = transition(
    css,
    '#propertyCard{position:fixed;',
    '#propertyCard{touch-action:pan-y;overscroll-behavior:contain;position:fixed;',
    'property card vertical touch scroll',
)
css = transition(
    css,
    '#layerPanel{position:fixed;',
    '#layerPanel{touch-action:pan-y;overscroll-behavior:contain;position:fixed;',
    'layer panel vertical touch scroll',
)

js_path.write_text(js, encoding='utf-8')
css_path.write_text(css, encoding='utf-8')
print('World V2500 runtime interaction, fidelity, race, and weather truth repairs verified.')
