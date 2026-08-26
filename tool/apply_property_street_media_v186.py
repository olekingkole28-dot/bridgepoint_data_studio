from pathlib import Path
import runpy

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

start=text.find('class _PropertyMediaCardState extends State<_PropertyMediaCard>')
end=text.find('class _PropertyMediaMissing',start)
if start<0 or end<0: raise SystemExit('Property media card state block missing')
block=text[start:end]

old_load="""  Future<Map<String, dynamic>> _load() => _callRpc(
        'bridgepoint_property_media_bundle_v169',
        {'p_property_id': widget.propertyId},
      );
"""
new_load=r'''  Future<Map<String,dynamic>> _load()async{
    var bundle=await _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});
    if(bundle['front_available']!=true){
      try{
        final result=await Supabase.instance.client.functions.invoke(
          'bridgepoint-property-street-media-v186',body:{'property_id':widget.propertyId},
        );
        final payload=_edgeFunctionPayload(result.data);
        if(result.status>=200&&result.status<300&&payload['discovered']==true){
          bundle=await _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});
        }
      }catch(_){ }
    }
    return bundle;
  }
'''
if old_load not in block: raise SystemExit('v169 property media load function missing')
block=block.replace(old_load,new_load,1)

old_data="""        final data = snapshot.data ?? const <String, dynamic>{};
        final primary = _bpMap(data['primary']);
        final url = '${primary['media_url'] ?? ''}'.trim();
"""
new_data="""        final data = snapshot.data ?? const <String, dynamic>{};
        final primary = _bpMap(data['primary']);
        final aerialCurrent=_bpMap(data['aerial_current']);
        final aerialUrl='${aerialCurrent['media_url']??''}'.trim();
        final mediaType='${primary['media_type']??''}'.toUpperCase();
        final url = '${primary['media_url'] ?? ''}'.trim();
"""
if old_data not in block: raise SystemExit('property media data block missing')
block=block.replace(old_data,new_data,1)
old_label="""        final fallback = '${data['fallback_kind'] ?? ''}' == 'AERIAL';
        final label = '${primary['display_label'] ?? (fallback ? 'Aerial View' : 'Property Photo')}';
        final source = '${primary['source_name'] ?? primary['provider'] ?? 'BridgePoint property media'}';
"""
new_label="""        final fallback = '${data['fallback_kind'] ?? ''}' == 'AERIAL';
        final label='${primary['display_label']??(mediaType=='AERIAL'?'Aerial View':mediaType=='STREET_VIEW'?'Street-Level Property View':'Property Photo')}';
        final source = '${primary['source_name'] ?? primary['provider'] ?? 'BridgePoint property media'}';
        final isStreet=mediaType=='STREET_VIEW';
"""
if old_label not in block: raise SystemExit('property media label block missing')
block=block.replace(old_label,new_label,1)

fallback_anchor="""                    if (fallback) ...[
                      const SizedBox(height: 5),
"""
street_note="""                    if(isStreet)...[
                      const SizedBox(height:5),
                      Text('Street-level reference • $source. BridgePoint selected a nearby public camera frame facing toward the parcel; verify the structure before relying on it as field evidence.',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
                    ],
                    if (fallback) ...[
                      const SizedBox(height: 5),
"""
if fallback_anchor not in block: raise SystemExit('property fallback note anchor missing')
block=block.replace(fallback_anchor,street_note,1)

history="""                    if (aerialHistory.length > 1) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showPropertyImageHistory(context, aerialHistory),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: Text('Image history • ${aerialHistory.length} dates'),
                      ),
                    ],
"""
controls="""                    if(aerialUrl.isNotEmpty&&aerialUrl!=url)...[
                      const SizedBox(height:8),
                      OutlinedButton.icon(
                        onPressed:()=>_showZoomablePropertyImage(context,aerialUrl,title:'Current Aerial View',subtitle:'${aerialCurrent['source_name']??aerialCurrent['provider']??'Authoritative aerial source'}'),
                        icon:const Icon(Icons.satellite_alt_outlined,size:16),
                        label:const Text('Open aerial • pinch / scroll to zoom'),
                      ),
                    ],
"""+history
if history not in block: raise SystemExit('property aerial history control missing')
block=block.replace(history,controls,1)
text=text[:start]+block+text[end:]

for needle in ['bridgepoint-property-street-media-v186','Open aerial • pinch / scroll to zoom','Street-level reference • $source','PINCH / SCROLL TO ZOOM']:
    if needle not in text: raise SystemExit(f'missing v186 marker {needle}')
if text==original: raise SystemExit('No front-facing property media changes applied')
path.write_text(text,encoding='utf-8')
print('Applied front-first property media + separate aerial zoom controls v186')

# v820: normalize the current responsive property card/detail boundaries before
# the multistate/current-owner installer enriches them in the next step.
runpy.run_path('tool/repair_multistate_owner_compat_v820.py',run_name='__main__')

# v829: temporary release-shape diagnostic while modernizing NOAA timeline.
runpy.run_path('tool/diagnose_generated_radar_v829.py',run_name='__main__')
