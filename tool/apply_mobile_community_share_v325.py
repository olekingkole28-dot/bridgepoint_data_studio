from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v325-mobile-community-share-radar'
if marker in body:
    print('BridgePoint v325 mobile/community/share/radar already applied.')
    raise SystemExit(0)

if 'bridgepoint-v324-owner-truth-customer-safe-catalog' not in body:
    raise SystemExit('v325 requires the audited v324 generated source')

# ---------------------------------------------------------------------------
# Community 3D: never leave a tall blank map on phones. Give MapLibre time to
# initialize, show an explicit loading state, and collapse to the already-live
# 2D Community map below if the WebGL/3D surface does not become ready.
# ---------------------------------------------------------------------------
start=body.find('class _Community3DMapV255State')
end=body.find('class _Community3DControlV255',start)
if start<0 or end<0:
    raise SystemExit('v325 Community 3D block missing')
block=body[start:end]

fields='''  int requestSerial=0;
  int _activeMapPointersV287=0;
'''
fields_new='''  int requestSerial=0;
  Timer? _community3dStartupV325;
  bool _community3dFallbackV325=false;
  int _community3dReloadV325=0;
  int _activeMapPointersV287=0;
'''
if fields in block:
    block=block.replace(fields,fields_new,1)
elif '_community3dStartupV325' not in block:
    raise SystemExit('v325 Community 3D state-field anchor missing')

init='''  @override void initState(){super.initState();weatherMotion=AnimationController(vsync:this,duration:const Duration(milliseconds:1500));_displayPreferences.addListener(_syncWeatherMotion);}
  void _syncWeatherMotion(){'''
init_new='''  @override void initState(){super.initState();weatherMotion=AnimationController(vsync:this,duration:const Duration(milliseconds:1500));_displayPreferences.addListener(_syncWeatherMotion);_armCommunity3DV325();}
  void _armCommunity3DV325(){
    _community3dStartupV325?.cancel();
    _community3dStartupV325=Timer(const Duration(seconds:8),(){
      if(mounted&&!styleReady)setState(()=>_community3dFallbackV325=true);
    });
  }
  void _retryCommunity3DV325(){
    _community3dStartupV325?.cancel();
    setState((){_community3dFallbackV325=false;styleReady=false;error=null;controller=null;_community3dReloadV325++;});
    _armCommunity3DV325();
  }
  void _syncWeatherMotion(){'''
if init in block:
    block=block.replace(init,init_new,1)
elif '_armCommunity3DV325' not in block:
    raise SystemExit('v325 Community 3D init anchor missing')

old_dispose="@override void dispose(){debounce?.cancel();_nationalWeatherTimerV287?.cancel();_bridgePointMapTouchLockV287.value=false;_displayPreferences.removeListener(_syncWeatherMotion);weatherMotion.dispose();super.dispose();}"
new_dispose="@override void dispose(){debounce?.cancel();_community3dStartupV325?.cancel();_nationalWeatherTimerV287?.cancel();_bridgePointMapTouchLockV287.value=false;_displayPreferences.removeListener(_syncWeatherMotion);weatherMotion.dispose();super.dispose();}"
if old_dispose in block:
    block=block.replace(old_dispose,new_dispose,1)
elif '_community3dStartupV325?.cancel()' not in block:
    raise SystemExit('v325 Community 3D dispose anchor missing')

ready='''      if(mounted)setState(()=>styleReady=true);
      unawaited(_installNationalWeatherV287());
'''
ready_new='''      _community3dStartupV325?.cancel();
      if(mounted)setState((){styleReady=true;_community3dFallbackV325=false;});
      unawaited(_installNationalWeatherV287());
'''
if ready in block:
    block=block.replace(ready,ready_new,1)
elif '_community3dFallbackV325=false' not in block:
    raise SystemExit('v325 Community 3D ready anchor missing')

# A phone should not dedicate most of the page to an uninitialized WebGL canvas.
block=block.replace('SizedBox(height:compact?390:510','SizedBox(height:compact?300:510',1)

map_ctor='''child:ClipRRect(borderRadius:BorderRadius.circular(14),child:ml.MapLibreMap(
          styleString:_style,
'''
map_ctor_new='''child:ClipRRect(borderRadius:BorderRadius.circular(14),child:ml.MapLibreMap(
          key:ValueKey('bridgepoint-community-3d-$_community3dReloadV325'),
          styleString:_style,
'''
if map_ctor in block:
    block=block.replace(map_ctor,map_ctor_new,1)
elif "bridgepoint-community-3d-$_community3dReloadV325" not in block:
    raise SystemExit('v325 Community 3D MapLibre constructor anchor missing')

stack='''      Stack(children:[
'''
fallback='''      _community3dFallbackV325
        ? Container(
            height:compact?118:150,
            width:double.infinity,
            padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.72),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.amber.withOpacity(.25))),
            child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Row(children:[Icon(Icons.map_outlined,color:AppTheme.amber,size:18),SizedBox(width:8),Expanded(child:Text('3D map did not finish loading on this device',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)))]),
              const SizedBox(height:6),
              const Text('The live 2D Community Observation Map directly below is still available. Retry 3D anytime without losing the rest of Community.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)),
              const SizedBox(height:8),
              OutlinedButton.icon(onPressed:_retryCommunity3DV325,icon:const Icon(Icons.refresh_rounded,size:16),label:const Text('Retry 3D')),
            ]),
          )
        : Stack(children:[
'''
if stack in block:
    block=block.replace(stack,fallback,1)
elif '_community3dFallbackV325' not in block:
    raise SystemExit('v325 Community 3D stack anchor missing')

controls='''        Positioned(top:10,right:10,child:Column(children:[
'''
loading_overlay='''        if(!styleReady)Positioned.fill(child:Container(
          alignment:Alignment.center,
          color:const Color(0xB807111F),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            const SizedBox(width:28,height:28,child:CircularProgressIndicator(strokeWidth:2.5,color:AppTheme.cyan)),
            const SizedBox(height:10),
            const Text('Loading BridgePoint Community 3D…',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900)),
            const SizedBox(height:4),
            const Text('Buildings and live layers are initializing',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
            const SizedBox(height:9),
            TextButton.icon(onPressed:_retryCommunity3DV325,icon:const Icon(Icons.refresh_rounded,size:15),label:const Text('Retry now')),
          ]),
        )),
        Positioned(top:10,right:10,child:Column(children:[
'''
if controls in block:
    block=block.replace(controls,loading_overlay,1)
elif 'Loading BridgePoint Community 3D' not in block:
    raise SystemExit('v325 Community 3D control anchor missing')

body=body[:start]+block+body[end:]

# ---------------------------------------------------------------------------
# NOAA radar: latest/current view uses NOAA's symbolized current reflectivity
# MapServer. Historical verified frames continue to use the time-enabled image
# service. This gives the live map the familiar green/yellow/orange/red/magenta
# reflectivity colors instead of relying on BridgePoint cluster graphics.
# ---------------------------------------------------------------------------
start=body.find('class _IntelligenceMapPageState extends State<_IntelligenceMapPage>')
end=body.find('class _MapLegendDot extends StatelessWidget',start)
if start<0 or end<0:
    raise SystemExit('v325 Intelligence Map block missing')
intel=body[start:end]

# Patch only the primary Intelligence Map radar TileLayer. Historical/preloaded
# verified frames keep the time-enabled ImageServer; the newest/current frame uses
# NOAA's symbolized current base-reflectivity MapServer so real reflectivity colors
# are visible over the satellite basemap.
primary_key="key:ValueKey('noaa-radar-$_radarRevision-${_radarFrame.toIso8601String()}')"
key_idx=intel.find(primary_key)
if key_idx<0:
    raise SystemExit('v325 primary Intelligence Map radar key missing')
tile_start=intel.rfind('TileLayer(',0,key_idx)
if tile_start<0 or key_idx-tile_start>260:
    raise SystemExit('v325 primary Intelligence Map radar TileLayer start missing')
tile_end_marker="userAgentPackageName:'com.bridgepoint.data_studio'"
tile_end=intel.find(tile_end_marker,key_idx)
if tile_end<0:
    raise SystemExit('v325 primary Intelligence Map radar TileLayer end marker missing')
tile_segment=intel[tile_start:tile_end+len(tile_end_marker)]
historical_url="https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$_radarRevision&"
current_url="https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity/MapServer/WMSServer?_bp=$_radarRevision&"
if current_url not in tile_segment:
    old_base="baseUrl:'"+historical_url+"'"
    if old_base not in tile_segment:
        raise SystemExit('v325 primary radar WMS base URL missing')
    new_base="baseUrl:_radarIsLatestV271?'"+current_url+"':'"+historical_url+"'"
    tile_segment=tile_segment.replace(old_base,new_base,1)
    intel=intel[:tile_start]+tile_segment+intel[tile_end+len(tile_end_marker):]
if current_url not in intel or historical_url not in intel:
    raise SystemExit('v325 current/historical NOAA radar services not both present')
# Make it visually clear that the colors are NOAA reflectivity, not BridgePoint scoring.
intel=intel.replace('NOAA LIVE RAIN RADAR • WEATHER MOTION','NOAA RADAR • LIVE REFLECTIVITY')
intel=intel.replace('Blue/green • trace–light','Green/blue • light rain')
intel=intel.replace('Yellow/orange • moderate–heavy','Yellow/orange • moderate–heavy rain')
intel=intel.replace('Red • very heavy','Red • very heavy / severe core')
intel=intel.replace('Pink/magenta • extreme; hail possible','Magenta/pink • extreme / hail possible')
body=body[:start]+intel+body[end:]

# ---------------------------------------------------------------------------
# Share + Community: add a useful share kit, better media language and external
# sharing for individual Network posts. All outbound sharing remains user-initiated.
# ---------------------------------------------------------------------------
share_anchor='void _showShareBridgePointDialog(BuildContext context)=>showDialog<void>(context:context,builder:(context)=>const _ShareBridgePointDialog());'
share_helpers=r'''Future<void> _shareBridgePointTextV325(BuildContext context,String subject,String text)async{
  try{
    final box=context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      title:subject,subject:subject,text:'$text\n\n$_bridgePointLiveUrl',
      sharePositionOrigin:box==null?null:box.localToGlobal(Offset.zero)&box.size,
    ));
  }catch(e){if(context.mounted)_showInfoDialog(context,'Share unavailable','$e');}
}

class _BridgePointCommunityShareKitV325 extends StatelessWidget{
  const _BridgePointCommunityShareKitV325({required this.profile});
  final Map<String,dynamic> profile;
  Widget _share(BuildContext context,IconData icon,String label,String subject,String message)=>OutlinedButton.icon(
    onPressed:()=>_shareBridgePointTextV325(context,subject,message),
    icon:Icon(icon,size:16),label:Text(label),
  );
  @override Widget build(BuildContext context){
    final handle='${profile['handle']??''}'.trim();
    final invite=handle.isEmpty
      ? 'Join me on BridgePoint Community — a member network built around property intelligence, field updates, local weather and useful professional connections.'
      : 'Join me on BridgePoint Community. Find me @$handle and connect around property intelligence, field updates, local weather and useful professional connections.';
    return Container(
      width:double.infinity,padding:const EdgeInsets.all(11),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.09),AppTheme.blue.withOpacity(.04)]),
        borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.16)),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Icon(Icons.rocket_launch_outlined,color:AppTheme.cyan,size:18),SizedBox(width:8),Expanded(child:Text('SHARE + GROW THE COMMUNITY',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.6)))]),
        const SizedBox(height:5),
        const Text('Invite people with a message that fits them. Nothing posts automatically — your phone opens the share sheet and you approve where it goes.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)),
        const SizedBox(height:9),
        Wrap(spacing:7,runSpacing:7,children:[
          _share(context,Icons.people_alt_outlined,'Community invite','Join me on BridgePoint',invite),
          _share(context,Icons.handyman_outlined,'Contractor / field','BridgePoint for property pros','BridgePoint helps property professionals combine live property intelligence, weather context, evidence, opportunities and field workflow in one place.'),
          _share(context,Icons.home_outlined,'Homeowner','BridgePoint for your property','BridgePoint brings property history, weather context, evidence and useful property intelligence into one understandable place.'),
          _share(context,Icons.insights_outlined,'Investor / partner','BridgePoint Intelligence','BridgePoint turns fragmented property and public data into explainable property intelligence, ranked opportunities and repeatable geographic expansion.'),
          FilledButton.tonalIcon(onPressed:()=>_showShareBridgePointDialog(context),icon:const Icon(Icons.ios_share_rounded,size:16),label:const Text('More share options')),
        ]),
      ]),
    );
  }
}

'''+share_anchor
if share_anchor in body:
    body=body.replace(share_anchor,share_helpers,1)
elif '_BridgePointCommunityShareKitV325' not in body:
    raise SystemExit('v325 global share dialog anchor missing')

# Network media accepts common phone video formats as well as MP4.
body=body.replace("case 'webp':return 'image/webp';case 'mp4':return 'video/mp4';default:return 'application/octet-stream';","case 'webp':return 'image/webp';case 'mp4':case 'm4v':return 'video/mp4';case 'mov':return 'video/quicktime';default:return 'application/octet-stream';",1)
body=body.replace("allowedExtensions:const ['jpg','jpeg','png','webp','mp4']","allowedExtensions:const ['jpg','jpeg','png','webp','mp4','mov','m4v']",1)

# Add an external share action for a Community post.
friend_anchor='''  Future<void> _friend(String id)async{try{await _callRpc('bridgepoint_network_send_friend_request_v323',{'p_user_id':id});_refresh();}catch(e){if(mounted)_showInfoDialog(context,'Friend request','$e');}}
'''
friend_new='''  Future<void> _shareNetworkPostV325(Map<String,dynamic> post)async{
    final who='${post['display_name']??post['handle']??'A BridgePoint member'}';
    final text='${post['body']??''}'.trim();
    await _shareBridgePointTextV325(context,'BridgePoint Community','$who shared on BridgePoint Community:\\n\\n$text');
  }
'''+friend_anchor
if friend_anchor in body:
    body=body.replace(friend_anchor,friend_new,1)
elif '_shareNetworkPostV325' not in body:
    raise SystemExit('v325 Network friend-method anchor missing')

# Put the share kit directly in the signed-in Network experience.
network_copy="""      const SizedBox(height:8),const Text('Professional connection + property intelligence. User posts are community content, not verified BridgePoint evidence unless explicitly labeled.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)),const SizedBox(height:10),
      Wrap(spacing:6,runSpacing:6,children:[for(final v in const [('FEED','Feed',Icons.dynamic_feed_rounded),('PEOPLE','People & Friends',Icons.group_add_rounded),('MESSAGES','Messages',Icons.forum_rounded)])ChoiceChip(selected:tab==v.$1,onSelected:(_)=>setState(()=>tab=v.$1),avatar:Icon(v.$3,size:15),label:Text(v.$2,style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)))]),const SizedBox(height:12),
"""
network_copy_new="""      const SizedBox(height:8),const Text('Professional connection + property intelligence. User posts are community content, not verified BridgePoint evidence unless explicitly labeled.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)),const SizedBox(height:10),
      _BridgePointCommunityShareKitV325(profile:profile),const SizedBox(height:10),
      Wrap(spacing:6,runSpacing:6,children:[for(final v in const [('FEED','Feed',Icons.dynamic_feed_rounded),('PEOPLE','People & Friends',Icons.group_add_rounded),('MESSAGES','Messages',Icons.forum_rounded)])ChoiceChip(selected:tab==v.$1,onSelected:(_)=>setState(()=>tab=v.$1),avatar:Icon(v.$3,size:15),label:Text(v.$2,style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)))]),const SizedBox(height:12),
"""
if network_copy in body:
    body=body.replace(network_copy,network_copy_new,1)
elif '_BridgePointCommunityShareKitV325(profile:profile)' not in body:
    raise SystemExit('v325 Network header anchor missing')

body=body.replace("hintText:'Share a useful field insight, project update, property lesson or question…'","hintText:'Share a local update, field insight, weather note, question, before/after lesson, project win or useful property tip…'",1)
body=body.replace("pendingMedia==null?'Add photo/video':pendingMedia!.name","pendingMedia==null?'Photo / video':pendingMedia!.name",1)
body=body.replace("'Photos/videos stay private until moderation approves them. Nothing unreviewed is shown in the public Network feed.'","'Photos/videos stay private until moderation approves them. Great community posts include local weather, field conditions, before/after lessons, project updates, questions and useful property observations.'",1)

# Add a small external-share button beside each post timestamp.
post_time="""Text(_bpDateTime(p['created_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5))"""
post_time_new="""Row(mainAxisSize:MainAxisSize.min,children:[Text(_bpDateTime(p['created_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5)),IconButton(tooltip:'Share this Community post',visualDensity:VisualDensity.compact,onPressed:()=>_shareNetworkPostV325(p),icon:const Icon(Icons.ios_share_rounded,size:15,color:AppTheme.cyan))])"""
if post_time in body:
    body=body.replace(post_time,post_time_new,1)
elif 'Share this Community post' not in body:
    raise SystemExit('v325 Network post timestamp anchor missing')

body += "\nconst String _bridgePointMobileCommunityShareRadarV325='bridgepoint-v325-mobile-community-share-radar | phone-first 3D timeout | retry/collapse fallback | NOAA symbolized live reflectivity | Community Share Kit | external post sharing | phone video formats';\n"
path.write_text(body,encoding='utf-8')
print('Applied BridgePoint v325 mobile Community, real-radar visibility and share/social polish.')
