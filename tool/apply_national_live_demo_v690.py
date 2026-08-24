from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

marker = '// bridgepoint-v690-national-live-demo'

# 1) Make the global top-bar autocomplete truly national across the states
# available to the signed-in user. The v192 contract enforces geography.
old_search = """            final result=await _callRpc('bridgepoint_flutter_property_suggestions_v77',{
              'p_query':query,'p_state_code':'CT','p_limit':8,
            });"""
new_search = """            final result=await _callRpc('bridgepoint_property_suggestions_v192',{
              'p_query':query,'p_limit':8,
            });"""
if old_search in s:
    s = s.replace(old_search, new_search, 1)
elif "_callRpc('bridgepoint_property_suggestions_v192'" not in s:
    raise SystemExit('Could not locate top-bar property autocomplete anchor')

old_subtitle = """                          Text('${option['municipality']??'Connecticut'} • Parcel ${option['parcel_number']??'not listed'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),"""
new_subtitle = """                          Text('${option['municipality']??'Property'} • ${option['state_code']??''} • Parcel ${option['parcel_number']??'not listed'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),"""
if old_subtitle in s:
    s = s.replace(old_subtitle, new_subtitle, 1)

# 2) Turn a national signal marker into a doorway to the complete property
# record. The existing property detail RPC already infers/enforces state access.
old_signal_tail = """                const SizedBox(height: 18),
                Text(
                  'Signal ID: ${signal['signal_id'] ?? '—'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.30),
                    fontSize: 9,
                  ),
                ),"""
new_signal_tail = """                const SizedBox(height: 18),
                if(signal['property_id']!=null)...[
                  SizedBox(
                    width:double.infinity,
                    child:FilledButton.icon(
                      onPressed:(){
                        Navigator.of(context).pop();
                        _showPropertyInventoryDetail(context,signal);
                      },
                      icon:const Icon(Icons.home_work_outlined),
                      label:const Text('Open full property intelligence'),
                    ),
                  ),
                  const SizedBox(height:12),
                ],
                Text(
                  'Signal ID: ${signal['signal_id'] ?? '—'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.30),
                    fontSize: 9,
                  ),
                ),"""
if old_signal_tail in s:
    s = s.replace(old_signal_tail, new_signal_tail, 1)
elif "Open full property intelligence" not in s:
    raise SystemExit('Could not locate signal-detail action anchor')

# 3) Make the map visibly national and give the presenter one-click US framing.
s = s.replace(
    "'${widget.packageName} • live Connecticut intelligence with visible expansion markets'",
    "'${widget.packageName} • live U.S. property intelligence • property-linked signals and expansion coverage'",
    1,
)
old_us_button = """_MapControlButton(icon:Icons.public_rounded,tooltip:'Show Northeast expansion',onTap:()=>_mapController.move(const LatLng(42.15,-72.90),6.3)),"""
new_us_button = """_MapControlButton(icon:Icons.public_rounded,tooltip:'Show U.S. intelligence',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.0)),"""
if old_us_button in s:
    s = s.replace(old_us_button, new_us_button, 1)
elif "tooltip:'Show U.S. intelligence'" not in s:
    raise SystemExit('Could not locate national map control anchor')

# 4) Remove CT-only language from the generic property dialog so national
# records look intentional while CT-specific physical data remains optional.
s = s.replace(
    "'${property['full_address'] ?? '${property['municipality'] ?? 'Connecticut'} property'}'",
    "'${property['full_address'] ?? '${property['municipality'] ?? property['state_code'] ?? 'Property'} property'}'",
    1,
)
s = s.replace(
    "'PROPERTY INTELLIGENCE RECORD • ${property['municipality'] ?? 'CT'} • ${property['parcel_number'] ?? 'No parcel'}'",
    "'PROPERTY INTELLIGENCE RECORD • ${property['municipality'] ?? property['state_code'] ?? 'US'} • ${property['state_code']??''} • ${property['parcel_number'] ?? 'No parcel'}'",
    1,
)
s = s.replace("subtitle: 'Canonical Connecticut property record',", "subtitle: 'Canonical property record linked to BridgePoint intelligence',", 1)
s = s.replace(
    "'Connecticut 2023 2D and 3D building baselines linked to this property'",
    "'Matched 2D and 3D building baselines when available for this property'",
    1,
)

# 5) Keep a durable marker so the workflow can prove the source patch landed.
if marker not in s:
    anchor = "const _bridgePointLiveUrl = 'https://bridgepointintelligence.online';"
    if anchor not in s:
        raise SystemExit('Could not locate BridgePoint live URL anchor')
    s = s.replace(anchor, anchor + '\n' + marker, 1)

required = [
    marker,
    "_callRpc('bridgepoint_property_suggestions_v192'",
    "Open full property intelligence",
    "tooltip:'Show U.S. intelligence'",
    "live U.S. property intelligence",
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('Missing V690 markers: ' + repr(missing))

p.write_text(s, encoding='utf-8')
print('Applied BridgePoint national live-demo patch V690')
