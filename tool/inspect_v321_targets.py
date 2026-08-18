from pathlib import Path
import hashlib

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
actual=hashlib.sha256(path.read_bytes()).hexdigest()
expected='1040a4c877400a3d641ab54c4771ff50ef02be0a2afa626f6f607de79a3b1225'
print(f'V321_INSPECT_HASH={actual}')
if actual!=expected:
    raise SystemExit(f'v321 inspect baseline mismatch: expected {expected}, got {actual}')

needles=[
    'class _IntelligenceMapPageState',
    'bp-us-radar-preloaded',
    'weather-center-radar-preloaded',
    'NOAA LIVE RAIN RADAR',
    'nearbyCentroids',
    'class _CoveragePageState',
    'Expansion bundles',
    'BUILDING NOW',
    'bridgepoint_expansion_progress_v212',
]
for needle in needles:
    index=body.find(needle)
    print(f'\n===== V321 TARGET {needle!r} index={index} =====')
    if index<0:
        continue
    start=max(0,index-1800)
    end=min(len(body),index+5200)
    print(body[start:end])
