from pathlib import Path
import re

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

# Use the permanent BridgePoint custom domain in the generated release.
text=text.replace('https://olekingkole28-dot.github.io/bridgepoint-live/','https://bridgepointintelligence.online/')

marker='Map<String, String> _apiHeaders() {'
if marker not in text:
    raise SystemExit('api headers marker missing')
if '_bridgePointLabelMapUrl' not in text:
    helper="""String _bridgePointLabelMapUrl()=>\n  'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';\n\n"""
    text=text.replace(marker,helper+marker,1)

# Add town/city/state/reference labels above each satellite base-map layer.
pattern=re.compile(r"(TileLayer\(\s*urlTemplate:\s*_bridgePointBaseMapUrl\(\),\s*userAgentPackageName:\s*'([^']+)',?\s*\),)",re.MULTILINE)
matches=list(pattern.finditer(text))
if not matches:
    raise SystemExit('no BridgePoint base TileLayer blocks found')

def add_labels(m):
    block=m.group(1)
    package=m.group(2)
    label=("\n                          if(_displayPreferences.value.mapBaseStyle=='satellite')\n"
           "                            TileLayer(\n"
           "                              urlTemplate:_bridgePointLabelMapUrl(),\n"
           f"                              userAgentPackageName:'{package}',\n"
           "                            ),")
    return block+label

text=pattern.sub(add_labels,text)

# Start the main intelligence map at the signed-in customer's current device location.
start=text.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
end=text.find('class _MapLegendDot extends StatelessWidget',start)
if start<0 or end<0:
    raise SystemExit('intelligence map state block missing')
block=text[start:end]

controller='  final MapController _mapController = MapController();\n'
if controller not in block:
    raise SystemExit('intelligence map controller marker missing')
if '_didAutoCenterOnDevice' not in block:
    block=block.replace(controller,controller+'  bool _didAutoCenterOnDevice=false;\n',1)

method=r'''  Future<void> _centerMapOnDevice()async{
    if(_didAutoCenterOnDevice||!mounted)return;
    try{
      final cached=_BridgePointLiveLocation.position.value;
      final pos=cached??await _BridgePointLiveLocation.start();
      if(!mounted)return;
      _didAutoCenterOnDevice=true;
      _mapController.move(LatLng(pos.latitude,pos.longitude),12.2);
    }catch(_){
      // Location is optional. Keep BridgePoint's normal geographic fallback when unavailable.
    }
  }

'''
if 'Future<void> _centerMapOnDevice()async' not in block:
    load_match=re.search(r"  Future<Map<String,\s*dynamic>> _load\(\) async \{",block)
    if not load_match:
        raise SystemExit('intelligence map load marker missing')
    block=block[:load_match.start()]+method+block[load_match.start():]

if 'addPostFrameCallback((_)=>_centerMapOnDevice())' not in block:
    init_match=re.search(r"super\.initState\(\);",block)
    if not init_match:
        raise SystemExit('intelligence map initState marker missing')
    block=block[:init_match.start()]+"super.initState();\n    WidgetsBinding.instance.addPostFrameCallback((_)=>_centerMapOnDevice());"+block[init_match.end():]

text=text[:start]+block+text[end:]

for needle in [
    '_bridgePointLabelMapUrl',
    'World_Boundaries_and_Places',
    'Future<void> _centerMapOnDevice()async',
    'addPostFrameCallback((_)=>_centerMapOnDevice())',
    'https://bridgepointintelligence.online/',
]:
    if needle not in text:
        raise SystemExit(f'missing v180 marker: {needle}')

if text==original:
    raise SystemExit('no v180 map/domain changes applied')
path.write_text(text,encoding='utf-8')
print(f'Applied v180 map labels/location/domain patch across {len(matches)} satellite map layer(s)')
