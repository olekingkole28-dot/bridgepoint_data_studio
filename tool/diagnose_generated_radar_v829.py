from pathlib import Path

text=Path('lib/main.dart').read_text(encoding='utf-8')
start=text.find('class _IntelligenceMapPageState')
print('v829 radar diagnostic: file_len=',len(text),'map_start=',start)
needles=[
    'WMSTileLayerOptions(',
    'wmsOptions:',
    'conus_bref_qcd',
    'opengeo.ncep.noaa.gov',
    'noaa-radar-preview-',
    'NORTHEAST_loop.gif',
    'radar_base_reflectivity',
    'ImageOverlay(',
    'TileLayer(',
    '_showRadar',
]
for needle in needles:
    positions=[]
    at=0
    while True:
        pos=text.find(needle,at)
        if pos<0:break
        positions.append(pos)
        at=pos+len(needle)
        if len(positions)>=8:break
    print(f'v829 {needle}: count={text.count(needle)} first={positions[:8]}')

for needle in ['conus_bref_qcd','noaa-radar-preview-','radar_base_reflectivity','_showRadar']:
    pos=text.find(needle,start if start>=0 else 0)
    if pos>=0:
        lo=max(0,pos-450);hi=min(len(text),pos+950)
        ctx=text[lo:hi].replace('\n','\\n')
        print(f'v829 CONTEXT {needle} @ {pos}: {ctx}')
