from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once("import 'dart:convert';\n", "import 'dart:convert';\nimport 'dart:math';\n", 'dart-math-import')
replace_once("import 'package:share_plus/share_plus.dart';\n", "import 'package:share_plus/share_plus.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\n", 'shared-preferences-import')

old_rpc="""Future<Map<String, dynamic>> _callRpc(String name, Map<String, dynamic> body) async {
  final response = await http.post(
    Uri.parse('$_supabaseUrl/rest/v1/rpc/$name'),
    headers: _apiHeaders(),
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) throw const FormatException('Unexpected BridgePoint response.');
  return Map<String, dynamic>.from(decoded);
}
"""
new_rpc=r'''@immutable
class _ConnectionHealth{
  const _ConnectionHealth({this.consecutiveFailures=0,this.slowRequests=0,this.lastLatencyMs=0,this.lastSuccessAt});
  final int consecutiveFailures,slowRequests,lastLatencyMs;
  final DateTime? lastSuccessAt;
  bool get spotty=>consecutiveFailures>=2||slowRequests>=2;
  _ConnectionHealth copyWith({int? consecutiveFailures,int? slowRequests,int? lastLatencyMs,DateTime? lastSuccessAt})=>_ConnectionHealth(
    consecutiveFailures:consecutiveFailures??this.consecutiveFailures,
    slowRequests:slowRequests??this.slowRequests,
    lastLatencyMs:lastLatencyMs??this.lastLatencyMs,
    lastSuccessAt:lastSuccessAt??this.lastSuccessAt,
  );
}
final ValueNotifier<_ConnectionHealth> _bridgePointConnectionHealth=ValueNotifier(const _ConnectionHealth());

void _bpConnectionSuccess(int milliseconds){
  final current=_bridgePointConnectionHealth.value;
  final slow=milliseconds>=4500?min(current.slowRequests+1,6):max(current.slowRequests-1,0);
  _bridgePointConnectionHealth.value=_ConnectionHealth(
    consecutiveFailures:0,slowRequests:slow,lastLatencyMs:milliseconds,lastSuccessAt:DateTime.now(),
  );
}
void _bpConnectionFailure(){
  final current=_bridgePointConnectionHealth.value;
  _bridgePointConnectionHealth.value=current.copyWith(consecutiveFailures:min(current.consecutiveFailures+1,10));
}

String _bpUuidV4(){
  final random=Random.secure();
  final bytes=List<int>.generate(16,(_)=>random.nextInt(256));
  bytes[6]=(bytes[6]&0x0f)|0x40;
  bytes[8]=(bytes[8]&0x3f)|0x80;
  final hex=bytes.map((b)=>b.toRadixString(16).padLeft(2,'0')).join();
  return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
}

Future<Map<String, dynamic>> _callRpc(String name, Map<String, dynamic> body) async {
  final watch=Stopwatch()..start();
  try{
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/$name'),
      headers: _apiHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    watch.stop();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _bpConnectionFailure();
      throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
    }
    _bpConnectionSuccess(watch.elapsedMilliseconds);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Unexpected BridgePoint response.');
    return Map<String, dynamic>.from(decoded);
  }catch(_){
    if(watch.isRunning)watch.stop();
    _bpConnectionFailure();
    rethrow;
  }
}

Future<void> _bridgePointSecureSignOut()async{
  try{
    final prefs=SharedPreferencesAsync();
    final keys=await prefs.getKeys();
    for(final key in keys.where((key)=>key.startsWith('bp_offline_'))){
      await prefs.remove(key);
    }
  }catch(_){/* Sign-out must continue even if local cleanup fails. */}
  await Supabase.instance.client.auth.signOut();
}
'''
replace_once(old_rpc,new_rpc,'connection-aware-rpc')

replace_once("onPressed:()=>Supabase.instance.client.auth.signOut(),", "onPressed:()=>_bridgePointSecureSignOut(),", 'secure-signout')

sync_strip="""                      _LiveSyncStrip(
                        secondsRemaining:_secondsToRefresh,
                        refreshSeconds:_refreshSeconds,
                      ),
"""
sync_replacement=sync_strip+r'''                      ValueListenableBuilder<_ConnectionHealth>(
                        valueListenable:_bridgePointConnectionHealth,
                        builder:(context,health,_)=>health.spotty
                          ? _SpottyConnectionBanner(
                              health:health,
                              onOffline:()=>_navigateTo(7),
                            )
                          : const SizedBox.shrink(),
                      ),
'''
replace_once(sync_strip,sync_replacement,'spotty-banner-in-workspace')

mywork_anchor="""      const SizedBox(height:10),const _ExplainerBanner(icon:Icons.policy_rounded,title:'From first signal through paid claim',message:'Save a promising opportunity, qualify it, open a private claim workflow, record each milestone, attach notes and schedule the next action. Public evidence updates automatically; carrier details appear only when you enter them or authorize an integration.'),
      const SizedBox(height:18),LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?4:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
mywork_replacement="""      const SizedBox(height:10),const _ExplainerBanner(icon:Icons.policy_rounded,title:'From first signal through paid claim',message:'Save a promising opportunity, qualify it, open a private claim workflow, record each milestone, attach notes and schedule the next action. Public evidence updates automatically; carrier details appear only when you enter them or authorize an integration.'),
      const SizedBox(height:12),_RouteOfflinePanel(saved:saved),
      const SizedBox(height:18),LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?4:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
replace_once(mywork_anchor,mywork_replacement,'route-panel-in-my-work')

workspace_marker='class _WorkspaceAtmosphere extends StatelessWidget{'
if text.count(workspace_marker)!=1:
    raise SystemExit('Workspace atmosphere marker missing')
spotty=r'''
class _SpottyConnectionBanner extends StatelessWidget{
  const _SpottyConnectionBanner({required this.health,required this.onOffline});
  final _ConnectionHealth health;
  final VoidCallback onOffline;
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.fromLTRB(16,4,16,4),padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
    decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.09),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.22))),
    child:Row(children:[
      const Icon(Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,color:AppTheme.amber,size:18),const SizedBox(width:9),
      Expanded(child:Text('Connection looks spotty — switch to Offline Mode?  ${health.consecutiveFailures} recent failure${health.consecutiveFailures==1?'':'s'} • last request ${health.lastLatencyMs} ms',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800))),
      const SizedBox(width:8),FilledButton.tonalIcon(onPressed:onOffline,icon:const Icon(Icons.offline_bolt_rounded,size:16),label:const Text('Open Offline Mode')),
    ]),
  );
}

'''
text=text.replace(workspace_marker,spotty+workspace_marker,1)

models_marker='class _ModelsPage extends StatefulWidget {'
if text.count(models_marker)!=1:
    raise SystemExit('Models marker missing for route UI insertion')
route_classes=r'''
class _RouteOfflinePanel extends StatefulWidget{
  const _RouteOfflinePanel({required this.saved});
  final List<Map<String,dynamic>> saved;
  @override State<_RouteOfflinePanel> createState()=>_RouteOfflinePanelState();
}
class _RouteOfflinePanelState extends State<_RouteOfflinePanel>{
  late Future<Map<String,dynamic>> routesRequest;
  final SharedPreferencesAsync prefs=SharedPreferencesAsync();
  Set<String> offlineReady=<String>{};
  int queuedOffline=0;
  bool busy=false;

  @override void initState(){
    super.initState();
    routesRequest=_loadRoutes();
    _loadLocalState();
    _bridgePointConnectionHealth.addListener(_connectionChanged);
  }
  @override void dispose(){_bridgePointConnectionHealth.removeListener(_connectionChanged);super.dispose();}
  void _connectionChanged(){if(!_bridgePointConnectionHealth.value.spotty)unawaited(_syncPending(silent:true));}
  Future<Map<String,dynamic>> _loadRoutes()=>_callRpc('bridgepoint_route_plans_v87',const {'p_status':null,'p_limit':50});
  void refresh()=>setState(()=>routesRequest=_loadRoutes());
  String _packKey(String routeId)=>'bp_offline_pack_$routeId';
  String _queueKey(String routeId)=>'bp_offline_queue_$routeId';

  Future<void> _loadLocalState()async{
    try{
      final keys=await prefs.getKeys();
      final ready=<String>{};int queueCount=0;
      for(final key in keys){
        if(key.startsWith('bp_offline_pack_'))ready.add(key.substring('bp_offline_pack_'.length));
        if(key.startsWith('bp_offline_queue_')){
          final raw=await prefs.getString(key);if(raw!=null){final decoded=jsonDecode(raw);if(decoded is List)queueCount+=decoded.length;}
        }
      }
      if(mounted)setState((){offlineReady=ready;queuedOffline=queueCount;});
    }catch(_){/* Local storage status is supplemental. */}
  }

  Future<void> _buildRoute()async{
    final ids=widget.saved.map((e)=>e['opportunity_id']).where((v)=>v!=null&&'$v'.isNotEmpty).map((v)=>'$v').take(20).toList();
    if(ids.isEmpty){if(mounted)_showInfoDialog(context,'No routable saved opportunities','Save opportunities that have a BridgePoint opportunity ID, then build a route from My Work.');return;}
    final controller=TextEditingController(text:'Field Route ${DateTime.now().month}/${DateTime.now().day}');
    final name=await showDialog<String>(context:context,builder:(d)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Text('Build My Route'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[TextField(controller:controller,decoration:const InputDecoration(labelText:'Route name',border:OutlineInputBorder())),const SizedBox(height:10),Text('BridgePoint will use up to ${ids.length} saved opportunities and order nearby stops with high-value context attached.',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4))]),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,controller.text.trim()),child:const Text('Build route'))]));
    controller.dispose();if(name==null)return;
    setState(()=>busy=true);
    try{
      final result=await _callRpc('bridgepoint_route_build_v154',{'p_route_name':name,'p_opportunity_ids':ids,'p_start_latitude':null,'p_start_longitude':null,'p_max_stops':20});
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Route built with ${result['stop_count']} stops.')));refresh();}
    }catch(e){if(mounted)_showInfoDialog(context,'Could not build route','$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _prepareOffline(Map<String,dynamic> route)async{
    setState(()=>busy=true);
    try{
      final id='${route['route_plan_id']}';
      final result=await _callRpc('bridgepoint_prepare_offline_route_v154',{'p_route_plan_id':id,'p_hours':24});
      final payload=result['payload'];
      await prefs.setString(_packKey(id),jsonEncode(payload));
      await prefs.setString('bp_offline_active_route',id);
      await _loadLocalState();
      if(mounted)_showInfoDialog(context,'Offline route ready','${route['route_name']} is stored as a lean device-local working set until ${_bpDateTime(result['expires_at'])}.\n\nFree-form customer notes are not cached. Queued field statuses will sync when service returns. Signing out clears BridgePoint offline cache.');
    }catch(e){if(mounted)_showInfoDialog(context,'Could not prepare Offline Mode','$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _queueEvent(String routeId,int stopIndex,String status,{String? note})async{
    final key=_queueKey(routeId);
    final raw=await prefs.getString(key);
    final list=raw==null?<dynamic>[]:(jsonDecode(raw) is List?List<dynamic>.from(jsonDecode(raw) as List):<dynamic>[]);
    list.add({'route_plan_id':routeId,'stop_index':stopIndex,'status':status,'note':note,'client_event_id':_bpUuidV4(),'occurred_at':DateTime.now().toUtc().toIso8601String()});
    await prefs.setString(key,jsonEncode(list));
    await _loadLocalState();
  }

  Future<void> _updateStop(String routeId,int stopIndex,String status,{String? note})async{
    if(_bridgePointConnectionHealth.value.spotty){
      await _queueEvent(routeId,stopIndex,status,note:note);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved offline. BridgePoint will sync this update when the connection recovers.')));
      return;
    }
    final eventId=_bpUuidV4();
    try{
      await _callRpc('bridgepoint_route_stop_update_v154',{'p_route_plan_id':routeId,'p_stop_index':stopIndex,'p_status':status,'p_note':note,'p_client_event_id':eventId,'p_occurred_at':DateTime.now().toUtc().toIso8601String(),'p_source_mode':'ONLINE'});
      refresh();
    }catch(e){
      await _queueEvent(routeId,stopIndex,status,note:note);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Network failed; update was queued offline instead.')));
    }
  }

  Future<void> _syncPending({bool silent=false})async{
    if(_bridgePointConnectionHealth.value.spotty)return;
    try{
      final keys=await prefs.getKeys();
      var syncedTotal=0,failedTotal=0;
      for(final key in keys.where((k)=>k.startsWith('bp_offline_queue_'))){
        final raw=await prefs.getString(key);if(raw==null)continue;
        final decoded=jsonDecode(raw);if(decoded is! List||decoded.isEmpty){await prefs.remove(key);continue;}
        final events=List<dynamic>.from(decoded);
        final result=await _callRpc('bridgepoint_offline_sync_v154',{'p_events':events});
        syncedTotal+=(result['synced'] as num?)?.toInt()??0;
        syncedTotal+=(result['duplicates'] as num?)?.toInt()??0;
        failedTotal+=(result['failed'] as num?)?.toInt()??0;
        if((result['failed'] as num?)?.toInt()==0){await prefs.remove(key);}else{
          final failedIds=_bpRows(result['failures']).map((f)=>'${f['client_event_id']}').toSet();
          final remaining=events.where((e)=>e is Map&&failedIds.contains('${e['client_event_id']}')).toList();
          await prefs.setString(key,jsonEncode(remaining));
        }
      }
      await _loadLocalState();refresh();
      if(!silent&&mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(failedTotal==0?'Offline sync complete • $syncedTotal update${syncedTotal==1?'':'s'} reconciled.':'Offline sync finished with $failedTotal item${failedTotal==1?'':'s'} still waiting.')));
    }catch(e){if(!silent&&mounted)_showInfoDialog(context,'Offline sync could not finish','$e');}
  }

  Future<void> _openRoute(Map<String,dynamic> route)async{
    await showDialog<void>(context:context,builder:(d)=>_RouteDetailDialog(route:route,onPrepareOffline:()=>_prepareOffline(route),onUpdate:(index,status)=>_updateStop('${route['route_plan_id']}',index,status),offlineReady:offlineReady.contains('${route['route_plan_id']}')));
    refresh();
  }

  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Icon(Icons.route_rounded,color:AppTheme.cyan),const SizedBox(width:8),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('ROUTES & OFFLINE MODE',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('Build a field route • download a lean working set • keep status updates through weak service',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5))])),if(queuedOffline>0)_OpportunityChip(label:'$queuedOffline TO SYNC',color:AppTheme.amber),const SizedBox(width:7),OutlinedButton.icon(onPressed:busy?_syncPending:()=>_syncPending(),icon:const Icon(Icons.sync_rounded,size:16),label:const Text('Sync')),const SizedBox(width:6),FilledButton.icon(onPressed:busy?null:_buildRoute,icon:const Icon(Icons.add_road_rounded,size:16),label:const Text('Build My Route'))]),
    const SizedBox(height:9),ValueListenableBuilder<_ConnectionHealth>(valueListenable:_bridgePointConnectionHealth,builder:(context,h,_)=>Container(width:double.infinity,padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:(h.spotty?AppTheme.amber:AppTheme.green).withOpacity(.055),borderRadius:BorderRadius.circular(9)),child:Row(children:[Icon(h.spotty?Icons.signal_wifi_statusbar_connected_no_internet_4_rounded:Icons.cloud_done_outlined,size:16,color:h.spotty?AppTheme.amber:AppTheme.green),const SizedBox(width:7),Expanded(child:Text(h.spotty?'Connection is spotty. Route actions can be queued offline.':'Connection looks healthy. Offline packs are still useful before rural or storm field work.',style:const TextStyle(fontSize:8.5,color:AppTheme.textMuted))),if(offlineReady.isNotEmpty)Text('${offlineReady.length} route${offlineReady.length==1?'':'s'} offline-ready',style:const TextStyle(fontSize:8,color:AppTheme.cyan,fontWeight:FontWeight.w900))]))),
    const SizedBox(height:10),FutureBuilder<Map<String,dynamic>>(future:routesRequest,builder:(context,snapshot){final routes=_bpRows(snapshot.data?['routes']);if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)return const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2);if(snapshot.hasError)return _InlineError(message:snapshot.error.toString());if(routes.isEmpty)return const Text('No saved routes yet. Save a few opportunities, then press Build My Route.',style:TextStyle(color:AppTheme.textMuted,fontSize:9));return Wrap(spacing:8,runSpacing:8,children:routes.take(12).map((r)=>InkWell(onTap:()=>_openRoute(r),borderRadius:BorderRadius.circular(10),child:Container(width:300,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:offlineReady.contains('${r['route_plan_id']}')?AppTheme.green.withOpacity(.22):Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${r['route_name']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:10))),if(offlineReady.contains('${r['route_plan_id']}'))const Icon(Icons.offline_bolt_rounded,color:AppTheme.green,size:16)]),const SizedBox(height:4),Text('${r['stop_count']} stops • ${r['route_status']} • ${r['optimization_strategy']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),const SizedBox(height:8),Row(children:[TextButton.icon(onPressed:()=>_openRoute(r),icon:const Icon(Icons.route_outlined,size:15),label:const Text('Open')),const Spacer(),TextButton.icon(onPressed:busy?null:()=>_prepareOffline(r),icon:const Icon(Icons.download_for_offline_outlined,size:15),label:Text(offlineReady.contains('${r['route_plan_id']}')?'Refresh offline':'Offline'))])])))).toList());})
  ])));
}

class _RouteDetailDialog extends StatefulWidget{
  const _RouteDetailDialog({required this.route,required this.onPrepareOffline,required this.onUpdate,required this.offlineReady});
  final Map<String,dynamic> route;final Future<void> Function() onPrepareOffline;final Future<void> Function(int,String) onUpdate;final bool offlineReady;
  @override State<_RouteDetailDialog> createState()=>_RouteDetailDialogState();
}
class _RouteDetailDialogState extends State<_RouteDetailDialog>{
  late List<Map<String,dynamic>> stops;
  @override void initState(){super.initState();stops=_bpRows(widget.route['stops']);}
  Future<void> _status(int index,String status)async{await widget.onUpdate(index,status);if(mounted)setState(()=>stops[index-1]={...stops[index-1],'status':status,'last_updated_at':DateTime.now().toIso8601String()});}
  Future<void> _directions(Map<String,dynamic> stop)async{
    final lat=stop['latitude'],lon=stop['longitude'];if(lat==null||lon==null)return;
    final uri=Uri.https('www.google.com','/maps/dir/',{'api':'1','destination':'$lat,$lon'});if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted)_showInfoDialog(context,'Navigation unavailable','Copy the address into your preferred navigation app.');
  }
  Color _statusColor(String s)=>switch(s){'CONTACTED'||'APPOINTMENT'||'INSPECTION'||'COMPLETED'=>AppTheme.green,'NOT_HOME'||'FOLLOW_UP'=>AppTheme.amber,'SKIP'=>AppTheme.red,_=>AppTheme.cyan};
  @override Widget build(BuildContext context)=>Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900,maxHeight:780),child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
    Row(children:[const Icon(Icons.route_rounded,color:AppTheme.cyan),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${widget.route['route_name']}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('${stops.length} stops • ${widget.route['optimization_strategy']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))])),if(widget.offlineReady)_OpportunityChip(label:'OFFLINE READY',color:AppTheme.green),const SizedBox(width:7),OutlinedButton.icon(onPressed:widget.onPrepareOffline,icon:const Icon(Icons.download_for_offline_outlined),label:const Text('Prepare offline')),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
    const SizedBox(height:8),const _ExplainerBanner(icon:Icons.directions_car_filled_outlined,title:'Field route',message:'Route order is an efficiency aid. Navigation, traffic, property access, safety rules and no-soliciting restrictions still control what you may do in the field. Do not interact with BridgePoint while driving.'),
    const SizedBox(height:10),Expanded(child:ListView.separated(itemCount:stops.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,i){final s=stops[i];final idx=(s['stop_index'] as num?)?.toInt()??i+1;final status='${s['status']??'PLANNED'}';return Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(radius:17,backgroundColor:_statusColor(status).withOpacity(.13),child:Text('$idx',style:TextStyle(color:_statusColor(status),fontSize:10,fontWeight:FontWeight.w900))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['address']??'Property'}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:3),Text('${s['opportunity_name']??''} • Score ${s['quality_score']??'—'} • Confidence ${s['confidence_score']??'—'} • Urgency ${s['urgency_score']??'—'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),const SizedBox(height:5),Text('${s['why_now']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,height:1.35)),const SizedBox(height:5),Text(s['property_photo_url']==null?'Property photo not available yet':'Property photo available',style:TextStyle(color:s['property_photo_url']==null?AppTheme.textMuted:AppTheme.green,fontSize:8,fontWeight:FontWeight.w800))])),const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[_OpportunityChip(label:status.replaceAll('_',' '),color:_statusColor(status)),const SizedBox(height:5),PopupMenuButton<String>(tooltip:'Update stop',onSelected:(v)=>_status(idx,v),itemBuilder:(context)=>const [PopupMenuItem(value:'NAVIGATING',child:Text('Navigating')),PopupMenuItem(value:'ARRIVED',child:Text('Arrived')),PopupMenuItem(value:'CONTACTED',child:Text('Contacted')),PopupMenuItem(value:'NOT_HOME',child:Text('Not home')),PopupMenuItem(value:'FOLLOW_UP',child:Text('Follow-up')),PopupMenuItem(value:'APPOINTMENT',child:Text('Appointment')),PopupMenuItem(value:'INSPECTION',child:Text('Inspection')),PopupMenuItem(value:'SKIP',child:Text('Skip')),PopupMenuItem(value:'COMPLETED',child:Text('Completed'))],child:const Padding(padding:EdgeInsets.all(7),child:Row(children:[Icon(Icons.edit_location_alt_outlined,size:16),SizedBox(width:4),Text('Status',style:TextStyle(fontSize:9))]))),TextButton.icon(onPressed:()=>_directions(s),icon:const Icon(Icons.navigation_outlined,size:15),label:const Text('Navigate'))])])));}))
  ]))));
}

'''
text=text.replace(models_marker,route_classes+models_marker,1)

if text==original:raise SystemExit('No route/offline Flutter changes applied')
path.write_text(text,encoding='utf-8')
print('Applied routes, offline persistence, and spotty connection UX v157')
