from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
required = ['_loadNoaaRadarFramesV271', '_radarIsLatestV271', '_radarPlaying', '_startRadarLoop']
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f'v360 radar control contract missing: {missing}')

print('V360_RADAR_LINES_BEGIN')
for n, line in enumerate(text.splitlines(), 1):
    low = line.lower()
    if 'radar' in low and any(token in line for token in ['TileLayer','WMSTileLayerOptions','TIME','ValueKey','preload','_radarFrames','_radarTimeParametersV271','_showRadar','_toggleRadarPlayback']):
        print(f'{n}: {line}')
print('V360_RADAR_LINES_END')
raise SystemExit('v360 evolved radar renderer inspection required')
