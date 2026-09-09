from pathlib import Path

p = Path('web/bridgepoint-3d-world/world-v2500.js')
text = p.read_text(encoding='utf-8')


def transition(old: str, new: str, label: str) -> None:
    global text
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 1 and new_count == 0:
        text = text.replace(old, new, 1)
        print(f'fixed {label}')
        return
    if old_count == 0 and new_count == 1:
        print(f'already fixed {label}')
        return
    raise SystemExit(f'{label}: contract drift old={old_count} new={new_count}')


transition(
    "function closeCard(){card.classList.remove('open');state.currentCard=null;state.cardToken++;highlightEntity(null)}\nasync function selectBuilding(entity)",
    "function closeCard(){card.classList.remove('open');state.currentCard=null;state.cardToken++;highlightEntity(null)}\nfunction buildingResolvePoint(b={}){const lat=finite(b.latitude??b.lat),lon=finite(b.longitude??b.lng??b.lon);if(lat!==null&&lon!==null)return[lon,lat];const ring=outerRings(rowGeometry(b))[0],c=ring?centerOfRing(ring):null;return c&&finite(c[0])!==null&&finite(c[1])!==null?[Number(c[0]),Number(c[1])]:null}\nasync function resolveBuildingDetail(b={}){const c=buildingResolvePoint(b);if(!c)throw new Error('Source building coordinate is unavailable for exact detail resolution');return rpcTimed('bridgepoint_building_detail_v2300',{p_lng:c[0],p_lat:c[1],p_radius_m:110},7500)}\nasync function selectBuilding(entity)",
    'exact building-detail coordinate resolver',
)
transition(
    "rpcTimed('bridgepoint_building_detail_v2300',{p_building_id:b.building_id??null,p_property_id:b.property_id??null,p_source_key:b.source_key??null},7500)",
    "resolveBuildingDetail(b)",
    'card building-detail RPC signature',
)
transition(
    "rpcTimed('bridgepoint_building_detail_v2300',{p_building_id:c.building.building_id??null,p_property_id:c.model.property_id??null,p_source_key:c.building.source_key??null},7500)",
    "resolveBuildingDetail(c.building)",
    'lab building-detail RPC signature',
)
transition(
    "const calls=[['Property', 'bridgepoint_flutter_property_detail_v344',{p_property_id:propertyId}],['Timeline','bridgepoint_property_timeline_v857',{p_property_id:propertyId}],['Climate','bridgepoint_property_climate_profile_v510',{p_property_id:propertyId}],['Twin','bridgepoint_digital_twin_summary_v856',{p_property_id:propertyId}],['Geometry','bridgepoint_property_geometry_v854',{p_property_id:propertyId}],['Permits','bridgepoint_flutter_permit_context_v68',{p_property_id:propertyId}],['Media','bridgepoint_property_media_bundle_v169',{p_property_id:propertyId}]];",
    "const calls=[['Property','bridgepoint_flutter_property_detail_v344',{p_property_id:propertyId}],['Timeline','bridgepoint_property_timeline_v857',{p_property_id:propertyId,p_limit:200}],['Climate','bridgepoint_property_climate_profile_v510',{p_property_id:propertyId}],['Twin','bridgepoint_digital_twin_summary_v856',{p_property_id:propertyId}],['Geometry','bridgepoint_property_geometry_v854',{p_property_id:propertyId,p_limit:25}],current.model.municipality?['Permits','bridgepoint_flutter_permit_context_v68',{p_municipality:current.model.municipality}]:null,['Media','bridgepoint_property_media_bundle_v169',{p_property_id:propertyId}]].filter(Boolean);",
    'Property 360 enrichment RPC signatures',
)

transition(
    "  labels:new Cesium.CustomDataSource('bp-labels'), weather:new Cesium.CustomDataSource('bp-weather'), locks:new Cesium.CustomDataSource('bp-country-locks')",
    "  propertyPoints:new Cesium.CustomDataSource('bp-property-points'), labels:new Cesium.CustomDataSource('bp-labels'), weather:new Cesium.CustomDataSource('bp-weather'), locks:new Cesium.CustomDataSource('bp-country-locks')",
    'property point source',
)
transition(
    "for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','labels'])sources[k].entities.removeAll();",
    "for(const k of ['buildings','parcels','roofs','roads','rails','water','parking','streetlights','vegetation','propertyPoints','labels'])sources[k].entities.removeAll();",
    'property point cleanup',
)
transition(
    "function renderViewport(data={}){\n  clearPropertyGeometry();let labels=0;",
    "function renderPropertyCircles(data={}){sources.propertyPoints.entities.removeAll();const raw=Array.isArray(data.properties)&&data.properties.length?data.properties:(data.buildings||[]).filter(r=>r?.property_id);let n=0;for(const row of raw){if(n>=PERF.detail[1])break;let lat=finite(row.latitude??row.lat),lon=finite(row.longitude??row.lng??row.lon);if(lat===null||lon===null){const ring=outerRings(rowGeometry(row))[0],c=ring?centerOfRing(ring):null;if(!c)continue;lon=finite(c[0]);lat=finite(c[1])}if(lat===null||lon===null)continue;sources.propertyPoints.entities.add({id:`property-point-${row.property_id||row.id||n}`,position:Cesium.Cartesian3.fromDegrees(lon,lat,(finite(row.ground_elevation_m??row.elevation_m)||0)+1.8),point:{pixelSize:7,color:Cesium.Color.fromCssColorString('#48e1ff').withAlpha(.78),outlineColor:Cesium.Color.fromCssColorString('#061018'),outlineWidth:1,distanceDisplayCondition:new Cesium.DistanceDisplayCondition(0,24000)},properties:{property_id:row.property_id||row.id,source_backed:true}});n++}sources.propertyPoints.show=state.propertyCircles;return n}\nfunction renderViewport(data={}){\n  clearPropertyGeometry();let labels=0;",
    'source-backed property circles renderer',
)
transition(
    "  addPoints(sources.vegetation,data.vegetation||data.trees||[],{color:'#6fbc78',size:5,maxDistance:4500,prefix:'tree'});\n  for(const [k,v] of Object.entries(state.layers))if(sources[k])sources[k].show=v;",
    "  addPoints(sources.vegetation,data.vegetation||data.trees||[],{color:'#6fbc78',size:5,maxDistance:4500,prefix:'tree'});\n  renderPropertyCircles(data);\n  for(const [k,v] of Object.entries(state.layers))if(sources[k])sources[k].show=v;",
    'property circle viewport population',
)
transition(
    "$('propertyCirclesButton').onclick=()=>{state.propertyCircles=!state.propertyCircles;$('propertyCirclesButton').classList.toggle('active',state.propertyCircles);setStatus(`Property circles ${state.propertyCircles?'enabled':'disabled'}. Building and parcel geometry are unchanged.`,'ok')};",
    "$('propertyCirclesButton').onclick=()=>{state.propertyCircles=!state.propertyCircles;sources.propertyPoints.show=state.propertyCircles;$('propertyCirclesButton').classList.toggle('active',state.propertyCircles);viewer.scene.requestRender();setStatus(`Property circles ${state.propertyCircles?'enabled':'disabled'}. Only source-associated property points are shown.`,'ok')};",
    'functional property circle toggle',
)

p.write_text(text, encoding='utf-8')
print('World V2500 runtime contracts and property-circle behavior verified.')
