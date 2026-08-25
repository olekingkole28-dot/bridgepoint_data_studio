from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

start=text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
if start<0:
    start=text.find('class _IntelligenceMapPageState')
if start<0:
    raise SystemExit('v826 Intelligence Map state missing')

# Prefer the known map-helper boundary; fall back to the next top-level class.
end=text.find('class _MapLegendDot',start)
if end<0:
    m=re.search(r'(?m)^class\s+_[A-Za-z0-9_]+',text[start+1:])
    end=len(text) if m is None else start+1+m.start()
block=text[start:end]

# Find the actual radar TileLayer controlled by _showRadar. Do not touch the
# separate preview/dialog WMS maps installed by v177.
radar=re.search(r'if\s*\(\s*_showRadar(?:\s*&&[^)]*)?\s*\)\s*\n\s*TileLayer\(',block,re.S)
if radar is None:
    raise SystemExit('v826 main _showRadar TileLayer missing')
wms_at=block.find('WMSTileLayerOptions(',radar.end())
if wms_at<0 or wms_at-radar.end()>1200:
    raise SystemExit('v826 main radar WMS options missing')

depth=0
wms_end=None
for i in range(wms_at,len(block)):
    if block[i]=='(':
        depth+=1
    elif block[i]==')':
        depth-=1
        if depth==0:
            wms_end=i
            break
if wms_end is None:
    raise SystemExit('v826 main radar WMS options unterminated')
wms=block[wms_at:wms_end+1]

historical="https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?"
base_pattern=re.compile(r"baseUrl\s*:\s*'[^']*'",re.S)
if base_pattern.search(wms) is None:
    raise SystemExit('v826 main radar baseUrl missing')
wms=base_pattern.sub(f"baseUrl: '{historical}'",wms,count=1)

# v190 accepts the historical layer id then converts it to the time-service id.
layers_pattern=re.compile(r"layers\s*:\s*const\s*\[[^\]]+\]",re.S)
if layers_pattern.search(wms) is None:
    raise SystemExit('v826 main radar layer list missing')
wms=layers_pattern.sub("layers: const ['conus_bref_qcd']",wms,count=1)

block=block[:wms_at]+wms+block[wms_end+1:]
text=text[:start]+block+text[end:]
if historical not in block:
    raise SystemExit('v826 NOAA compatibility marker missing')
if text==original:
    print('Main NOAA WMS already normalized for v190/v826')
else:
    path.write_text(text,encoding='utf-8')
    print('Normalized main _showRadar WMS boundary for NOAA timeline v190/v826')
