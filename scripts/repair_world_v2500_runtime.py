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

p.write_text(text, encoding='utf-8')
print('World V2500 runtime RPC contracts repaired.')
