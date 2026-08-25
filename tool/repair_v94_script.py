from pathlib import Path

p=Path('tool/apply_launch_v94.py')
s=p.read_text(encoding='utf-8')

# Historical v94 banner syntax repair.
old='''"""                  const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  Text(\n                    technology\n'''
new='''"""                  child: const Text(\n                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',\n                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),\n                  ),\n""",\n"""                  child: Text(\n                    technology\n'''
if old in s:
    s=s.replace(old,new,1)
elif new not in s:
    raise SystemExit('v94 banner matcher repair target not found in either historical or repaired form')

# v782: v94 predates the canonical national NOAA map stack, the server-driven
# package purchase/delivery truth, and the current Owner Global Control plane.
# Historical replacements remain strict unless newer checked-in source proves
# the capability that superseded them.
old_replace='''def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)
'''
old_v775='''_SUPERSEDED_V94_MAP_LABELS = {
    'map-radar-state',
    'map-radar-timer',
    'map-opportunity-limit',
    'map-signal-limit',
    'map-min-zoom',
    'map-live-radar-cache-bust',
    'map-remove-scan-overlay',
}
_MODERN_MAP_MARKERS = (
    'bridgepoint-v287-national-weather-spatial-background',
    '_BridgePointNationwideWeatherV287',
    'bp-us-radar-v287',
    'bridgepoint-v218-mobile-layout-readable-evidence',
)

def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count == 1:
        text = text.replace(old, new, 1)
        return
    if count == 0 and label in _SUPERSEDED_V94_MAP_LABELS and any(marker in text for marker in _MODERN_MAP_MARKERS):
        print(f'{label}: superseded by newer canonical radar/map source; continuing')
        return
    raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
'''
old_v776='''_SUPERSEDED_V94_MAP_LABELS = {
    'map-radar-state',
    'map-radar-timer',
    'map-opportunity-limit',
    'map-signal-limit',
    'map-min-zoom',
    'map-live-radar-cache-bust',
    'map-remove-scan-overlay',
}

def _canonical_map_truth_present() -> bool:
    radar_state = ('bool _showRadar = true;' in text or 'bool _showRadar=true;' in text)
    noaa_wms = (
        'opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?' in text
        and "layers: const ['conus_bref_qcd']" in text
    )
    us_control = (
        "tooltip: 'Show U.S. intelligence'" in text
        or "tooltip:'Show United States live weather'" in text
        or "LatLng(39.50, -98.35)" in text
        or "LatLng(39.50,-98.35)" in text
    )
    return radar_state and noaa_wms and us_control

def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count == 1:
        text = text.replace(old, new, 1)
        return
    if count == 0 and label in _SUPERSEDED_V94_MAP_LABELS and _canonical_map_truth_present():
        print(f'{label}: superseded by canonical NOAA WMS + U.S. map controls; continuing')
        return
    raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
'''
old_v780='''_SUPERSEDED_V94_MAP_LABELS = {
    'map-radar-state',
    'map-radar-timer',
    'map-opportunity-limit',
    'map-signal-limit',
    'map-min-zoom',
    'map-live-radar-cache-bust',
    'map-remove-scan-overlay',
}
_SUPERSEDED_V94_PACKAGE_LABELS = {
    'technology-card-flag',
    'technology-card-chip',
    'technology-empty-model-copy',
    'technology-price-label',
    'technology-detail-flag',
    'technology-detail-banner',
    'technology-contact-sales',
}

def _canonical_map_truth_present() -> bool:
    radar_state = ('bool _showRadar = true;' in text or 'bool _showRadar=true;' in text)
    noaa_wms = (
        'opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?' in text
        and "layers: const ['conus_bref_qcd']" in text
    )
    us_control = (
        "tooltip: 'Show U.S. intelligence'" in text
        or "tooltip:'Show United States live weather'" in text
        or "LatLng(39.50, -98.35)" in text
        or "LatLng(39.50,-98.35)" in text
    )
    return radar_state and noaa_wms and us_control

def _canonical_package_truth_present() -> bool:
    return (
        'bridgepoint-package-purchase-truth-v778' in text
        and "'bridgepoint_request_owner_approved_package_v323'" in text
        and "'bridgepoint_request_technology_package_v93'" in text
        and "return 'BUY';" in text
        and "return 'REQUEST';" in text
        and "return 'BUILDING';" in text
    )

def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count == 1:
        text = text.replace(old, new, 1)
        return
    if count == 0 and label in _SUPERSEDED_V94_MAP_LABELS and _canonical_map_truth_present():
        print(f'{label}: superseded by canonical NOAA WMS + U.S. map controls; continuing')
        return
    if count == 0 and label in _SUPERSEDED_V94_PACKAGE_LABELS and _canonical_package_truth_present():
        print(f'{label}: superseded by server-driven package purchase/delivery truth v778; continuing')
        return
    raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
'''
new_v782='''_SUPERSEDED_V94_MAP_LABELS = {
    'map-radar-state',
    'map-radar-timer',
    'map-opportunity-limit',
    'map-signal-limit',
    'map-min-zoom',
    'map-live-radar-cache-bust',
    'map-remove-scan-overlay',
}
_SUPERSEDED_V94_PACKAGE_LABELS = {
    'technology-card-flag',
    'technology-card-chip',
    'technology-empty-model-copy',
    'technology-price-label',
    'technology-detail-flag',
    'technology-detail-banner',
    'technology-contact-sales',
}
_SUPERSEDED_V94_OWNER_LABELS = {
    'owner-expansion-insert',
}

def _canonical_map_truth_present() -> bool:
    radar_state = ('bool _showRadar = true;' in text or 'bool _showRadar=true;' in text)
    noaa_wms = (
        'opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?' in text
        and "layers: const ['conus_bref_qcd']" in text
    )
    us_control = (
        "tooltip: 'Show U.S. intelligence'" in text
        or "tooltip:'Show United States live weather'" in text
        or "LatLng(39.50, -98.35)" in text
        or "LatLng(39.50,-98.35)" in text
    )
    return radar_state and noaa_wms and us_control

def _canonical_package_truth_present() -> bool:
    return (
        'bridgepoint-package-purchase-truth-v778' in text
        and "'bridgepoint_request_owner_approved_package_v323'" in text
        and "'bridgepoint_request_technology_package_v93'" in text
        and "return 'BUY';" in text
        and "return 'REQUEST';" in text
        and "return 'BUILDING';" in text
    )

def _canonical_owner_global_truth_present() -> bool:
    owner_path = Path('lib/screens/bridgepoint_owner_global_control.dart')
    if not owner_path.exists():
        return False
    owner = owner_path.read_text(encoding='utf-8')
    main_wired = (
        "import 'screens/bridgepoint_owner_command_center.dart';" in text
        and 'BridgePointOwnerCommandCenter' in text
    )
    control_truth = all(marker in owner for marker in (
        'bridgepoint_owner_global_command_v675',
        "'START_US_ALL'",
        "'START_WORLD_DISCOVERY'",
        "'START_JURISDICTION'",
        'bridgepoint_owner_state_export_manifest_v675',
        'These actions queue discovery/build work. They never bypass validation or customer-readiness gates.',
    ))
    return main_wired and control_truth

def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count == 1:
        text = text.replace(old, new, 1)
        return
    if count == 0 and label in _SUPERSEDED_V94_MAP_LABELS and _canonical_map_truth_present():
        print(f'{label}: superseded by canonical NOAA WMS + U.S. map controls; continuing')
        return
    if count == 0 and label in _SUPERSEDED_V94_PACKAGE_LABELS and _canonical_package_truth_present():
        print(f'{label}: superseded by server-driven package purchase/delivery truth v778; continuing')
        return
    if count == 0 and label in _SUPERSEDED_V94_OWNER_LABELS and _canonical_owner_global_truth_present():
        print(f'{label}: superseded by Owner Global Control v675; continuing')
        return
    raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
'''
if new_v782 not in s:
    if old_v780 in s:
        s=s.replace(old_v780,new_v782,1)
    elif old_v776 in s:
        s=s.replace(old_v776,new_v782,1)
    elif old_v775 in s:
        s=s.replace(old_v775,new_v782,1)
    elif old_replace in s:
        s=s.replace(old_replace,new_v782,1)
    else:
        raise SystemExit('v94 replace_once compatibility target not found')

# The U.S.-weather control was historically patched outside replace_once.
old_us='''if text.count(_old_us_weather) == 1:
    text = text.replace(_old_us_weather, _new_us_weather, 1)
elif text.count(_new_us_weather) >= 1:
    print('map-us-weather-button: already applied by a newer canonical source; continuing')
else:
    raise SystemExit('map-us-weather-button: neither historical nor current control found')
'''
new_us='''if text.count(_old_us_weather) == 1:
    text = text.replace(_old_us_weather, _new_us_weather, 1)
elif text.count(_new_us_weather) >= 1:
    print('map-us-weather-button: already applied by a newer canonical source; continuing')
elif _canonical_map_truth_present():
    print('map-us-weather-button: superseded by canonical U.S. intelligence control; continuing')
else:
    raise SystemExit('map-us-weather-button: neither historical nor canonical U.S. map control found')
'''
if new_us not in s:
    if old_us not in s:
        raise SystemExit('v94 special U.S. map-control compatibility target not found')
    s=s.replace(old_us,new_us,1)

# The old owner expansion class was injected outside replace_once as well.
old_owner_guard="""if text.count(marker) != 1:
    raise SystemExit('owner-expansion-class-marker not found exactly once')
"""
new_owner_guard="""_owner_global_superseded = _canonical_owner_global_truth_present()
if not _owner_global_superseded and text.count(marker) != 1:
    raise SystemExit('owner-expansion-class-marker not found exactly once')
"""
if new_owner_guard not in s:
    if old_owner_guard not in s:
        raise SystemExit('v94 owner-expansion class guard target not found')
    s=s.replace(old_owner_guard,new_owner_guard,1)

old_owner_insert="text = text.replace(marker, owner_class + marker, 1)"
new_owner_insert="""if _owner_global_superseded:
    print('owner-expansion-class: superseded by wired Owner Global Control v675; continuing')
elif 'class _OwnerExpansionPanel extends StatefulWidget' in text:
    print('owner-expansion-class: already present; continuing')
else:
    text = text.replace(marker, owner_class + marker, 1)"""
if new_owner_insert not in s:
    if old_owner_insert not in s:
        raise SystemExit('v94 owner-expansion class insertion target not found')
    s=s.replace(old_owner_insert,new_owner_insert,1)

p.write_text(s,encoding='utf-8')
print('Repaired v94 supersession for canonical map + package + owner global truth v782')
