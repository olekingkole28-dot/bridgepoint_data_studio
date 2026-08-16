from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

start=text.find('class _PropertyMediaCardState extends State<_PropertyMediaCard>{')
end=text.find('class _PropertyMediaMissing',start)
if start<0 or end<0:
    raise SystemExit('Property media card state block missing')
block=text[start:end]

old="""  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});}
  @override void didUpdateWidget(covariant _PropertyMediaCard oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.propertyId!=widget.propertyId)request=_callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});}
"""
new=r'''  late Future<Map<String,dynamic>> request;
  Future<Map<String,dynamic>> _loadFrontFirst()async{
    var bundle=await _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});
    final frontAvailable=bundle['front_available']==true;
    if(!frontAvailable){
      try{
        final result=await Supabase.instance.client.functions.invoke(
          'bridgepoint-property-street-media-v186',
          body:{'property_id':widget.propertyId},
        );
        final payload=_edgeFunctionPayload(result.data);
        if(result.status>=200&&result.status<300&&payload['discovered']==true){
          bundle=await _callRpc('bridgepoint_property_media_bundle_v169',{'p_property_id':widget.propertyId});
        }
      }catch(_){
        // Street coverage is an enhancement. Keep lawful aerial fallback when unavailable.
      }
    }
    return bundle;
  }
  @override void initState(){super.initState();request=_loadFrontFirst();}
  @override void didUpdateWidget(covariant _PropertyMediaCard oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.propertyId!=widget.propertyId)request=_loadFrontFirst();}
'''
if old not in block:
    raise SystemExit('Property media request marker missing after v169/v174')
block=block.replace(old,new,1)

old_data="""    final data=snap.data??{};final primary=_bpMap(data['primary']);final url='${primary['media_url']??''}';if(url.isEmpty)return _PropertyMediaMissing(message:'${data['display_message']??'Property photo not available yet'}');
    final label='${primary['display_label']??(primary['media_type']=='AERIAL'?'Aerial View':'Property Photo')}';
"""
new_data="""    final data=snap.data??{};final primary=_bpMap(data['primary']);final url='${primary['media_url']??''}';if(url.isEmpty)return _PropertyMediaMissing(message:'${data['display_message']??'Property photo not available yet'}');
    final aerialCurrent=_bpMap(data['aerial_current']);
    final aerialUrl='${aerialCurrent['media_url']??''}'.trim();
    final mediaType='${primary['media_type']??''}'.toUpperCase();
    final label='${primary['display_label']??(mediaType=='AERIAL'?'Aerial View':mediaType=='STREET_VIEW'?'Street-Level Property View':'Property Photo')}';
"""
if old_data not in block:
    raise SystemExit('Property media data marker missing')
block=block.replace(old_data,new_data,1)

# Put a dedicated aerial button next to the history control so front-facing imagery never hides aerial evidence.
history_marker="""                    if (aerialHistory.length > 1) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showPropertyImageHistory(context, aerialHistory),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: Text('Image history • ${aerialHistory.length} dates'),
                      ),
                    ],
"""
aerial_controls="""                    if(aerialUrl.isNotEmpty&&aerialUrl!=url)...[
                      const SizedBox(height:8),
                      OutlinedButton.icon(
                        onPressed:()=>_showZoomablePropertyImage(
                          context,aerialUrl,
                          title:'Current Aerial View',
                          subtitle:'${aerialCurrent['source_name']??aerialCurrent['provider']??'Authoritative aerial source'}',
                        ),
                        icon:const Icon(Icons.satellite_alt_outlined,size:16),
                        label:const Text('Open aerial • pinch / scroll to zoom'),
                      ),
                    ],
                    if (aerialHistory.length > 1) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showPropertyImageHistory(context, aerialHistory),
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: Text('Image history • ${aerialHistory.length} dates'),
                      ),
                    ],
"""
if history_marker not in block:
    raise SystemExit('Aerial history controls marker missing')
block=block.replace(history_marker,aerial_controls,1)

# Give KartaView/street photos an explicit source label instead of presenting them as aerial imagery.
source_line="""    final source='${primary['source_name']??primary['provider']??'BridgePoint property media'}';
"""
source_new="""    final source='${primary['source_name']??primary['provider']??'BridgePoint property media'}';
    final isStreet=mediaType=='STREET_VIEW';
"""
if source_line not in block: raise SystemExit('source line missing')
block=block.replace(source_line,source_new,1)

fallback_note="""                    if (fallback) ...[
"""
if fallback_note not in block: raise SystemExit('fallback note marker missing')
street_note="""                    if(isStreet)...[
                      const SizedBox(height:5),
                      Text(
                        'Street-level reference • $source. BridgePoint selected a nearby public camera frame facing toward the parcel; verify the structure before relying on it as field evidence.',
                        style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35),
                      ),
                    ],
                    if (fallback) ...[
"""
block=block.replace(fallback_note,street_note,1)

text=text[:start]+block+text[end:]

for needle in [
  '_loadFrontFirst()','bridgepoint-property-street-media-v186','Open aerial • pinch / scroll to zoom',
  'Street-level reference • $source','PINCH / SCROLL TO ZOOM'
]:
    if needle not in text:raise SystemExit(f'missing v186 marker: {needle}')
if text==original:raise SystemExit('No front-facing property media changes applied')
path.write_text(text,encoding='utf-8')
print('Applied front-first property media + separate aerial zoom controls v186')
