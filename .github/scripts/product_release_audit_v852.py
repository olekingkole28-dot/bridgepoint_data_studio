from pathlib import Path
import re
import sys

ROOT = Path('.')
LIB = ROOT / 'lib'
errors = []
notes = []

def fail(msg):
    errors.append(msg)

def check(cond, msg):
    if not cond:
        fail(msg)

def text(path):
    return (ROOT / path).read_text(encoding='utf-8')

# ---- Weather permanent regression contract ----
weather_path = 'lib/v2/bridgepoint_map_weather_v2.dart'
w = text(weather_path)
check(w.count("import 'dart:convert';") == 1, 'Weather must import dart:convert exactly once')
check(w.count("import 'package:http/http.dart' as http;") == 1, 'Weather must import package:http exactly once')
check('_loadRadarFrames()' in w, 'Weather must load NOAA published frame catalog')
check('idp_validtime' in w, 'Weather must use NOAA idp_validtime')
check("_radarFrames.isEmpty\n                              ? const <String, String>{}" in w or "_radarFrames.isEmpty" in w and "otherParameters:" in w, 'Weather must omit TIME when no published frame exists')
check('max: 48' not in w and 'frame >= 48' not in w, 'Weather must not hardcode a 49-frame radar history')
check('_radarFrames.length - 1' in w, 'Weather slider/timer must use actual NOAA frame count')
check('_radarMaxHonestZoom' in w, 'Weather must retain property-level radar truth zoom gate')

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

# ---- Navigation contract ----
app = text('lib/v2/bridgepoint_app_v2.dart')
for marker in ['_AreaV2.home', '_AreaV2.map', '_AreaV2.properties', '_AreaV2.investor']:
    check(marker in app, f'Mobile primary navigation missing {marker}')
check("'Property Investor'" in app, 'Property Investor label missing from app shell')
check("'Investment / Worth'" in app, 'Owner Investment / Worth destination missing')

# ---- Checkout contract ----
packages = text('lib/v2/settings/bridgepoint_packages_v2.dart')
check("Future<void> _buy(Map<String, dynamic> package, String interval)" in packages,
      'Packages must pass an explicit billing interval into checkout')
check("body: {'package_key': key, 'interval': interval}" in packages,
      'Checkout invocation must use the selected interval')
check("_buy(p, 'month')" in packages and "_buy(p, 'year')" in packages,
      'Customer packages must expose both monthly and annual checkout when annual pricing exists')
check("'interval': 'month'" not in packages,
      'Packages must not silently hardcode every checkout to monthly')

# ---- No old hard-coded formula shell regression ----
home = text('lib/v2/bridgepoint_home_live_v2.dart') if (ROOT/'lib/v2/bridgepoint_home_live_v2.dart').exists() else ''
landing = text('lib/v2/bridgepoint_public_landing_v2.dart')
check('equation' not in home.lower(), 'Signed-in Home regressed to equation/formula presentation')
check('equation' not in landing.lower(), 'Public landing regressed to equation/formula presentation')

# ---- Deep customer-surface hygiene ----
production_v2 = [p for p in (LIB/'v2').rglob('*.dart')]
# Catch only user-visible interpolation patterns around Text/message strings, not catch variable declarations.
for p in production_v2:
    s = p.read_text(encoding='utf-8')
    rel = p.as_posix()
    for i, line in enumerate(s.splitlines(), 1):
        stripped = line.strip()
        if ('Text(' in stripped or '_message =' in stripped or "return {'" in stripped) and ('${snapshot.error}' in line or '$snapshot.error' in line or "'$e'" in line or '"$e"' in line or "'$error'" in line or '"$error"' in line):
            fail(f'Raw exception appears customer-visible: {rel}:{i}: {stripped[:160]}')
        if 'TODO' in line or 'FIXME' in line:
            fail(f'Production TODO/FIXME remains: {rel}:{i}: {stripped[:160]}')

# Recursive generic payload presenters are disallowed on customer-facing V2 pages.
# Property presentation may keep structured audit detail only when explicitly customer-safe.
allowed_payload_files = {'lib/v2/bridgepoint_property_presentation_v2.dart'}
for p in production_v2:
    rel = p.as_posix()
    if rel in allowed_payload_files:
        continue
    s = p.read_text(encoding='utf-8')
    if re.search(r'class\s+_Payload\b', s) or re.search(r'class\s+_PayloadPanel\b', s):
        fail(f'Generic recursive payload presenter remains in customer surface: {rel}')

# Duplicate exact import lines in any Dart file.
for p in LIB.rglob('*.dart'):
    lines = p.read_text(encoding='utf-8').splitlines()
    imports = [x.strip() for x in lines if x.strip().startswith('import ')]
    dupes = sorted({x for x in imports if imports.count(x) > 1})
    if dupes:
        fail(f'Duplicate imports in {p.as_posix()}: {dupes}')

# Required restored surfaces.
required = [
    'lib/v2/bridgepoint_properties_v2.dart',
    'lib/v2/bridgepoint_investor_v2.dart',
    'lib/v2/bridgepoint_buildings_v2.dart',
    'lib/v2/bridgepoint_source_surface_model_v2.dart',
    'lib/screens/bridgepoint_owner_overview_v2.dart',
    'lib/v2/bridgepoint_portfolio_risk_v2.dart',
    'lib/v2/bridgepoint_ai_v2.dart',
    'lib/v2/bridgepoint_global_search_v2.dart',
]
for path in required:
    check((ROOT/path).exists(), f'Restored product surface missing: {path}')

print('BridgePoint product release audit V858')
print(f'Checked {len(list(LIB.rglob("*.dart")))} Dart files')
if errors:
    print('\nFAILURES:')
    for err in errors:
        print(f' - {err}')
    sys.exit(1)
print('PASS: weather, true XYZ 3D/twin, hardened property RPCs, navigation, checkout, customer-surface hygiene, and restored-surface contracts')
