from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
original=text

# Global autocomplete should search all entitled/configured BridgePoint states, not CT only.
old="""            final result=await _callRpc('bridgepoint_flutter_property_suggestions_v77',{
              'p_query':query,'p_state_code':'CT','p_limit':8,
            });
"""
new="""            final result=await _callRpc('bridgepoint_property_suggestions_v192',{
              'p_query':query,'p_limit':8,
            });
"""
if old not in text: raise SystemExit('global CT search anchor missing')
text=text.replace(old,new,1)
text=text.replace("Text('${option['municipality']??'Connecticut'} • Parcel ${option['parcel_number']??'not listed'}'","Text('${option['municipality']??'Property'}${option['state_code']==null?'':' • ${option['state_code']}'} • Parcel ${option['parcel_number']??'not listed'}'",1)

# Make device recenter callable after the initial automatic center.
text=text.replace('Future<void> _centerMapOnDevice()async{\n    if(_didAutoCenterOnDevice||!mounted)return;', 'Future<void> _centerMapOnDevice({bool force=false})async{\n    if((_didAutoCenterOnDevice&&!force)||!mounted)return;',1)

old_reset="""                            _MapControlButton(
                              icon: Icons.center_focus_strong_rounded,
                              tooltip: 'Reset Connecticut',
                              onTap: () => _mapController.move(
                                const LatLng(41.60, -72.70),
                                8.2,
                              ),
                            ),
"""
new_reset="""                            _MapControlButton(
                              icon: Icons.my_location_rounded,
                              tooltip: 'Center on my current location',
                              onTap: () => _centerMapOnDevice(force:true),
                            ),
"""
if old_reset not in text: raise SystemExit('Reset Connecticut control missing')
text=text.replace(old_reset,new_reset,1)

# The Northeast overview remains useful, but describe it accurately.
text=text.replace("tooltip:'Show Northeast expansion'","tooltip:'Show Northeast coverage overview'",1)

for marker in ['bridgepoint_property_suggestions_v192','Center on my current location','_centerMapOnDevice({bool force=false})']:
    if marker not in text: raise SystemExit(f'missing v192 marker {marker}')
if text==original: raise SystemExit('No global search/location changes applied')
p.write_text(text,encoding='utf-8')
print('Applied multistate global search and location recenter v192')
