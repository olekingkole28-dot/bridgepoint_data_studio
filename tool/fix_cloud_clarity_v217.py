from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

changed = 0

def replace(old: str, new: str, label: str, count: int | None = None):
    global s, changed
    found = s.count(old)
    if found == 0:
        raise SystemExit(f'MISSING {label}')
    if count is not None and found != count:
        raise SystemExit(f'UNEXPECTED {label}: expected {count}, found {found}')
    s = s.replace(old, new)
    changed += found

# The original cloud loop advanced faster than WMS tiles could finish loading,
# causing checkerboard/flicker between frames. Keep radar responsive, but let
# satellite imagery settle before the next frame.
replace(
    "timer=Timer.periodic(const Duration(milliseconds:900),(_){",
    "timer=Timer.periodic(const Duration(milliseconds:1700),(_){",
    'weather-center cloud animation cadence',
    1,
)

old_map_tick = "setState(()=>_radarFrameIndex=_radarFrameIndex>=24?0:_radarFrameIndex+1);"
# Older generated releases may still use the radar-only expression; leave it alone.
if old_map_tick in s:
    pass

old_combined_tick = "setState((){_radarFrameIndex=_radarFrameIndex>=24?0:_radarFrameIndex+1;if(_cloudFrames.isNotEmpty)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;});"
new_combined_tick = "setState((){_radarFrameIndex=_radarFrameIndex>=24?0:_radarFrameIndex+1;if(_cloudFrames.isNotEmpty&&_radarFrameIndex.isEven)_cloudFrameIndex=_cloudFrameIndex>=_cloudFrames.length-1?0:_cloudFrameIndex+1;});"
replace(old_combined_tick, new_combined_tick, 'main-map cloud animation cadence', 1)

# maxNativeZoom=8 forced flutter_map to enlarge the same low-zoom raster tiles
# at street/property zoom levels. NOAA WMS can render a fresh GetMap tile for
# each requested bbox, so allow normal native requests through zoom 19.
cloud_zoom_old = "maxNativeZoom:8"
cloud_zoom_new = "maxNativeZoom:19,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:240),startOpacity:.88,reloadStartOpacity:.96)"
count_zoom = s.count(cloud_zoom_old)
if count_zoom < 3:
    raise SystemExit(f'EXPECTED at least 3 NOAA cloud maxNativeZoom entries, found {count_zoom}')
s = s.replace(cloud_zoom_old, cloud_zoom_new)
changed += count_zoom

# Do not destroy/recreate the whole tile layer every frame. Keeping the same
# TileLayer state allows the prior raster to remain while the next TIME frame
# is fetched, and the short reload fade removes the flashing/pixel-grid effect.
patterns = [
    r"key:ValueKey\('bp-cloud-\$\{frame\.toIso8601String\(\)\}'\),\s*",
    r"key:ValueKey\('noaa-cloud-\$\{_cloudFrame!\.toIso8601String\(\)\}'\),\s*",
    r"key:ValueKey\('noaa-cloud-preview-\$\{_cloudFrame!\.toIso8601String\(\)\}'\),\s*",
]
for pattern in patterns:
    s2, n = re.subn(pattern, '', s)
    if n != 1:
        raise SystemExit(f'EXPECTED one cloud ValueKey match for {pattern}, found {n}')
    s = s2
    changed += n

# Keep the imagery readable without washing out streets, parcel labels, or
# opportunity markers underneath it.
s = s.replace("Opacity(opacity:.52,child:TileLayer(", "Opacity(opacity:.48,child:TileLayer(", 1)
s = s.replace("Opacity(opacity:.58,child:TileLayer(", "Opacity(opacity:.52,child:TileLayer(", 1)

marker = "const String _bridgePointV215ReleaseMarker='bridgepoint-v215-secure-stability-polish';"
if marker not in s:
    raise SystemExit('MISSING v215 release marker')
s = s.replace(marker, "const String _bridgePointV217ClarityMarker='bridgepoint-v217-cloud-clarity';\n" + marker, 1)
changed += 1

p.write_text(s, encoding='utf-8')
print(f'Applied BridgePoint v217 cloud clarity repair ({changed} guarded edits).')
