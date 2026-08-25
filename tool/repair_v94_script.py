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

# v776: v94 predates the current national WMS/radar stack. Keep historical
# replacements strict when their exact target exists. If formatting/architecture
# has already moved on, allow only the map-specific historical replacements to
# no-op when the canonical source still proves all three functional structures:
# radar state, NOAA WMS, and a U.S. map-control destination.
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
new_replace='''_SUPERSEDED_V94_MAP_LABELS = {
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
if new_replace not in s:
    if old_v775 in s:
        s=s.replace(old_v775,new_replace,1)
    elif old_replace in s:
        s=s.replace(old_replace,new_replace,1)
    else:
        raise SystemExit('v94 replace_once compatibility target not found')

p.write_text(s,encoding='utf-8')
print('Repaired v94 banner matcher and guarded canonical NOAA map supersession v776')
