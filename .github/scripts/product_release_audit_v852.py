from pathlib import Path
import re
import sys

ROOT = Path('.')
LIB = ROOT / 'lib'
errors = []


def fail(msg):
    errors.append(msg)


def check(cond, msg):
    if not cond:
        fail(msg)


def text(path):
    return (ROOT / path).read_text(encoding='utf-8')


# ---- World V2500 permanent map/weather regression contract ----
world_index = text('web/bridgepoint-3d-world/index.html')
world = text('web/bridgepoint-3d-world/world-v2500.js')
world_css = text('web/bridgepoint-3d-world/world-v2500.css')
check('world-v2500.js' in world_index, 'Map shell must load World V2500')
check('const VERSION = 2500' in world, 'World renderer must identify as V2500')
check('BridgePointWorldV2500' in world, 'World V2500 runtime marker is missing')
check('radar:true' in world.replace(' ', ''), 'World V2500 radar must start enabled')
check('latestRadarTime()' in world and 'idp_validtime' in world,
      'World V2500 radar must use NOAA published observation time')
check('setInterval(()=>refreshRadar(),120000)' in world.replace(' ', ''),
      'World V2500 radar must refresh on the two-minute source cadence')
check('mapservices.weather.noaa.gov' in world,
      'World V2500 must retain NOAA radar/weather source wiring')
check('basemap.nationalmap.gov' in world and 'U.S. Geological Survey' in world,
      'World V2500 must retain public USGS imagery source wiring')
check('hazardKind' in world and 'hazardColor' in world and 'renderWeatherRows' in world,
      'World V2500 must retain category-specific hazard rendering')
for kind in ['tornado','hurricane','wildfire','fire','hail','snow','flood','wind','lightning','outage','rain']:
    check(kind in world, f'World V2500 hazard rendering missing category: {kind}')
check('propertyCircles:false' in world.replace(' ', ''),
      'World V2500 property circles must remain opt-in rather than fake default precision')
check('bridgepoint_3d_world_viewport_v1899' in world,
      'World V2500 must stream viewport property/building intelligence')
check('bridgepoint_building_detail_v2300' in world,
      'World V2500 must retain building/property detail enrichment')
check(not (ROOT / 'lib/v2/bridgepoint_map_weather_v2.dart').exists(),
      'Retired Flutter Intelligence Map source must not ship beside V2500')
check(not (ROOT / 'web/bridgepoint-3d-world/world-v2400.js').exists(),
      'Retired World V2400 JavaScript must not ship beside V2500')
check(not (ROOT / 'web/bridgepoint-3d-world/world-v2400.css').exists(),
      'Retired World V2400 CSS must not ship beside V2500')

# ---- 3D / digital twin permanent regression contract ----
geom = text('lib/v2/bridgepoint_building_geometry_v2.dart')
bldg = text('lib/v2/bridgepoint_buildings_v2.dart')
surface = text('lib/v2/bridgepoint_source_surface_model_v2.dart')
check('L2_SOURCE_SURFACE_MODEL' in bldg, 'Buildings/Twin must surface L2 source-surface fidelity')
check('BridgePointSourceSurfaceModelV2' in geom, 'Building geometry must mount the real source-surface renderer')
check("widget.payload['geometry_3d']" in surface, 'Source-surface renderer must consume backend geometry_3d')
check('coordinate.length >= 3' in surface and 'coordinate[2]' in surface,
      'Source-surface renderer must require and parse a real Z coordinate')
check('L2 • SOURCE XYZ SURFACES' in surface, 'Source model must identify real L2 XYZ surfaces')
check('_Vec3' in surface and '_rotate' in surface and '_project' in surface,
      'Source-surface renderer must perform 3D rotation/projection rather than 2D footprint extrusion')
check('exact replica' in bldg.lower(), 'Digital twin UI must preserve exact-replica truth disclosure')
check('photoreal' in bldg.lower(), 'Digital twin UI must preserve photorealistic truth disclosure')

# Hardened customer RPC contract: old internal versions must never be called from Flutter.
all_dart = '\n'.join(p.read_text(encoding='utf-8') for p in LIB.rglob('*.dart'))
old_customer_rpcs = [
    'bridgepoint_property_geometry_v837',
    'bridgepoint_property_source_3d_v843',
    'bridgepoint_digital_twin_summary_v509',
    'bridgepoint_property_timeline_v78',
]
for rpc in old_customer_rpcs:
    check(rpc not in all_dart, f'Flutter still calls internal/unhardened RPC {rpc}')
for rpc in [
    'bridgepoint_property_geometry_v854',
    'bridgepoint_property_source_3d_v855',
    'bridgepoint_digital_twin_summary_v856',
    'bridgepoint_property_timeline_v857',
]:
    check(rpc in all_dart, f'Hardened customer RPC is not wired into Flutter: {rpc}')

# ---- Clean V2 information architecture contract ----
app = text('lib/v2/bridgepoint_app_v2.dart')
check("static const primary = <_Area>[_Area.home, _Area.map, _Area.properties, _Area.work];" in app,
      'Primary navigation must be Home / Map / Properties / Work')
for label in ["label:'Home'", "label:'Map'", "label:'Properties'", "label:'Work'", "label:'Plans'"]:
    check(label in app or label.replace("label:'", "label: '") in app, f'Navigation missing {label}')
check("if (owner) _Group(title:'Owner only'" in app or "if (owner) _Group(title: 'Owner only'" in app,
      'Models/Worth/Studio must be behind owner-only navigation')
check("_item(_Area.worth,'Owner Valuation'" in app, 'Owner valuation must remain available to the owner')
check("_item(_Area.models,'Model Operations'" in app, 'Model operations must remain available to the owner')
check("_item(_Area.studio,'Intelligence Studio'" in app, 'Intelligence Studio must remain available to the owner')
check('BridgePointWorldEmbedV2' in app, 'Map route must use BridgePoint World V2500 embed')
check('BridgePointMapWeatherV2' not in app, 'Retired Intelligence Map must not be reachable from the app')
customer_slice = app.split("if (owner) _Group", 1)[0]
check("_item(_Area.worth" not in customer_slice, 'Worth leaked into customer Explore')
check("_item(_Area.models" not in customer_slice, 'Models leaked into customer Explore')
check("_item(_Area.studio" not in customer_slice, 'Studio leaked into customer Explore')

# ---- Customer Plans / checkout contract ----
plans = text('lib/v2/bridgepoint_products_settings_v2.dart')
check('bridgepoint_customer_plans_v944' in plans,
      'Normal plan chooser must use customer-safe V944 package catalog')
check("'bridgepoint-checkout-v67'" in plans,
      'Plans must use BridgePoint secure checkout')
check("body: {'package_key': key, 'interval': interval}" in plans,
      'Checkout invocation must pass selected package and billing interval')
check("_checkout(plan, 'month')" in plans and "_checkout(plan, 'year')" in plans,
      'Customer plans must expose monthly and annual checkout when annual pricing exists')
check('7-DAY FREE TRIAL' in plans,
      'Plans conversion surface must preserve the free-trial message')

# ---- Owner truth contracts ----
owner = text('lib/screens/bridgepoint_owner_overview_v2.dart')
check('bridgepoint_owner_parcel_progress_v942' in owner,
      'Owner Overview must use real parcel progress contract V942')
check('bridgepoint_owner_source_truth_v943' in owner,
      'Owner Overview must distinguish unique source breadth from routing rows')
check('LAST PARCEL ACTIVITY' in owner and 'DISTINCT SOURCE ENDPOINTS' in owner,
      'Owner Overview must visibly expose parcel heartbeat and source-count truth')

# ---- Shared visual contract ----
chrome = text('lib/v2/bridgepoint_chrome_v2.dart')
check('_BridgePointOrbitalDnaPainter' in chrome,
      'Clean V2 must use the darker orbital/DNA motion background')
check('bridgepoint-mark-v80.svg' in chrome,
      'Clean V2 must use the real BridgePoint mark')

# ---- No hard-coded formula shell regression ----
home = text('lib/v2/bridgepoint_home_v2.dart')
landing = text('lib/v2/bridgepoint_public_landing_v2.dart')
check('equation' not in home.lower(), 'Signed-in Home regressed to equation/formula presentation')
check('equation' not in landing.lower(), 'Public landing regressed to equation/formula presentation')

# ---- Deep customer-surface hygiene ----
production_v2 = [p for p in (LIB / 'v2').rglob('*.dart')]
for p in production_v2:
    s = p.read_text(encoding='utf-8')
    rel = p.as_posix()
    for i, line in enumerate(s.splitlines(), 1):
        stripped = line.strip()
        if ('Text(' in stripped or '_message =' in stripped) and (
            '${snapshot.error}' in line or '$snapshot.error' in line or "'$e'" in line or '"$e"' in line
        ):
            fail(f'Raw exception appears customer-visible: {rel}:{i}: {stripped[:160]}')
        if 'TODO' in line or 'FIXME' in line:
            fail(f'Production TODO/FIXME remains: {rel}:{i}: {stripped[:160]}')

allowed_payload_files = {'lib/v2/bridgepoint_property_presentation_v2.dart'}
for p in production_v2:
    rel = p.as_posix()
    if rel in allowed_payload_files:
        continue
    s = p.read_text(encoding='utf-8')
    if re.search(r'class\s+_Payload\b', s) or re.search(r'class\s+_PayloadPanel\b', s):
        fail(f'Generic recursive payload presenter remains in customer surface: {rel}')

for p in LIB.rglob('*.dart'):
    lines = p.read_text(encoding='utf-8').splitlines()
    imports = [x.strip() for x in lines if x.strip().startswith('import ')]
    dupes = sorted({x for x in imports if imports.count(x) > 1})
    if dupes:
        fail(f'Duplicate imports in {p.as_posix()}: {dupes}')

required = [
    'lib/v2/bridgepoint_properties_v2.dart',
    'lib/v2/bridgepoint_opportunities_v2.dart',
    'lib/v2/bridgepoint_investor_v2.dart',
    'lib/v2/bridgepoint_buildings_v2.dart',
    'lib/v2/bridgepoint_source_surface_model_v2.dart',
    'lib/screens/bridgepoint_owner_overview_v2.dart',
    'lib/v2/bridgepoint_portfolio_risk_v2.dart',
    'lib/v2/bridgepoint_ai_v2.dart',
    'lib/v2/bridgepoint_global_search_v2.dart',
]
for path in required:
    check((ROOT / path).exists(), f'Restored product surface missing: {path}')

check(not (LIB / 'v3').exists(), 'Parallel V3 architecture reappeared; Clean V2 must remain the single app')

print('BridgePoint Clean V2 + World V2500 product release audit')
print(f'Checked {len(list(LIB.rglob("*.dart")))} Dart files')
if errors:
    print('\nFAILURES:')
    for err in errors:
        print(f' - {err}')
    sys.exit(1)
print('PASS: V2500 world, NOAA/USGS map truth, true XYZ 3D, hardened RPCs, four-area navigation, owner-only internals, customer plans, owner truth, visual system, and customer-surface hygiene')
