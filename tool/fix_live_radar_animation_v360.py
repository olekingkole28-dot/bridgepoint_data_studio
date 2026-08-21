from pathlib import Path
import re

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v360-live-radar-persistence'

required = ['_loadNoaaRadarFramesV271', '_radarIsLatestV271', '_radarPlaying']
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f'v360 radar control contract missing: {missing}')

# The current V319/V321 release evolved both the renderer and timer. Until the
# exact generated implementation is captured, fail closed after emitting narrow
# non-secret source neighborhoods from the generated artifact.
if not re.search(r'void\s+_startRadarAnimation\s*\(\s*\)\s*\{', text):
    probes = ['_radarPlaying', '_loadNoaaRadarFramesV271', 'bp-us-radar-preloaded', 'weather-center-radar-preloaded', 'iso-wms-preloaded-radar']
    for needle in probes:
        idx = text.find(needle)
        if idx < 0:
            continue
        print(f'V360_NEIGHBORHOOD_BEGIN {needle}')
        print(text[max(0, idx-2200):min(len(text), idx+4200)])
        print(f'V360_NEIGHBORHOOD_END {needle}')
    raise SystemExit('v360 evolved radar timer/renderer inspection required')

raise SystemExit('v360 old timer unexpectedly remained; inspection path should be removed after retargeting')
