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

# v775: v94 predates the current national WMS/radar stack. Keep its patches strict
# when the old source is actually present, but allow an old map matcher to no-op
# when a newer canonical radar implementation is already checked in. This prevents
# historical generators from regressing or blocking modern source while still
# failing if neither historical nor modern map truth exists.
old_replace='''def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)
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
if new_replace not in s:
    if old_replace not in s:
        raise SystemExit('v94 replace_once compatibility target not found')
    s=s.replace(old_replace,new_replace,1)

p.write_text(s,encoding='utf-8')
print('Repaired v94 banner matcher and guarded superseded map matchers v775')
