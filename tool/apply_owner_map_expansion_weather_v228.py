from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v228-owner-map-weather-expansion'
if marker in body:
    print('v228 already applied')
    raise SystemExit(0)

old="""      _callRpc('bridgepoint_flutter_geographic_catalog_v77',const {}),
      showPropertyIntelligence
        ? _callRpc('bridgepoint_flutter_signal_map_v80',signalBody)
        : Future.value(<String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'map_mode':'WEATHER_OVERVIEW'}),
"""
new="""      _callRpc('bridgepoint_flutter_geographic_catalog_v77',const {}).catchError((_)=> <String,dynamic>{'complete':true,'markets':<dynamic>[],'bundles':<dynamic>[],'fallback':true}),
      showPropertyIntelligence
        ? _callRpc('bridgepoint_flutter_signal_map_v80',signalBody).catchError((_)=> <String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'signal_type_count':0,'fallback':true})
        : Future.value(<String,dynamic>{'complete':true,'signals':<dynamic>[],'returned_points':0,'map_mode':'WEATHER_OVERVIEW'}),
"""
if old not in body: raise SystemExit('map Future.wait anchor missing')
body=body.replace(old,new,1)

body=body.replace('bool _showClouds=true;','bool _showClouds=false;',1)
body=body.replace("if(!mounted||!_radarPlaying||(!_showRadar&&!_showClouds))return;","if(!mounted||!_radarPlaying||!_showRadar)return;",1)
body=body.replace("_mobileDefaultsAppliedV218=true;_visibleLayer='opportunities';_showRadar=false;_showClouds=false;_showExpansion=false;_radarPlaying=false;","_mobileDefaultsAppliedV218=true;_visibleLayer='opportunities';_showRadar=true;_showClouds=false;_showExpansion=false;_radarPlaying=true;",1)
body=body.replace('    unawaited(_loadCloudFrames());\n','',1)

main_cloud="""                          if(_showClouds&&_cloudFrame!=null)Opacity(opacity:.48,child:TileLayer(
                            wmsOptions:WMSTileLayerOptions(baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':_cloudFrame!.toUtc().toIso8601String()}),
                            maxNativeZoom:19,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:240),startOpacity:.88,reloadStartOpacity:.96),userAgentPackageName:'com.bridgepoint.data_studio',
                          )),
"""
if main_cloud not in body: raise SystemExit('main cloud tile anchor missing')
body=body.replace(main_cloud,'',1)
preview_cloud="""                                    if(_showClouds&&_cloudFrame!=null)Opacity(opacity:.52,child:TileLayer(wmsOptions:WMSTileLayerOptions(baseUrl:'https://nowcoast.noaa.gov/geoserver/observations/satellite/ows?',layers:const ['global_visible_imagery_mosaic'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':_cloudFrame!.toUtc().toIso8601String()}),maxNativeZoom:19,panBuffer:0,keepBuffer:3,tileDisplay:const TileDisplay.fadeIn(duration:Duration(milliseconds:240),startOpacity:.88,reloadStartOpacity:.96),userAgentPackageName:'com.bridgepoint.data_studio')),
"""
if preview_cloud not in body: raise SystemExit('preview cloud tile anchor missing')
body=body.replace(preview_cloud,'',1)
body=body.replace('if (_showRadar||_showClouds)','if (_showRadar)')
body=body.replace('if(_showRadar||_showClouds)','if(_showRadar)')
cloud_control="""                            const SizedBox(height:7),
                            _MapControlButton(icon:_showClouds?Icons.cloud_rounded:Icons.cloud_off_rounded,tooltip:_showClouds?'Hide moving satellite clouds':'Show moving satellite clouds',onTap:()=>setState((){_showClouds=!_showClouds;if(_showClouds)_radarPlaying=true;})),
"""
if cloud_control not in body: raise SystemExit('cloud control anchor missing')
body=body.replace(cloud_control,'',1)
body=body.replace('NOAA CLOUDS + RADAR • WEATHER MOTION','NOAA LIVE RAIN RADAR • WEATHER MOTION')

old_noaa_button="""                      if(_showRadar)Positioned(left:14,top:162,child:FilledButton.icon(
                        style:FilledButton.styleFrom(backgroundColor:const Color(0xFF071321).withOpacity(.96),foregroundColor:AppTheme.cyan,padding:const EdgeInsets.symmetric(horizontal:10,vertical:8)),
                        onPressed:_checkingNoaa?null:()=>_checkNoaaHealth(),icon:Icon(_bpMap(_noaaHealth?['radar'])['ok']==true?Icons.check_circle_rounded:Icons.network_check_rounded,size:16),label:Text(_checkingNoaa?'Checking NOAA…':'Test NOAA live',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900)),
                      )),
"""
new_noaa_button="""                      if(_showRadar)Positioned(left:14,top:162,child:Wrap(spacing:7,runSpacing:6,children:[
                        FilledButton.icon(
                          style:FilledButton.styleFrom(backgroundColor:const Color(0xFF071321).withOpacity(.96),foregroundColor:AppTheme.cyan,padding:const EdgeInsets.symmetric(horizontal:10,vertical:8)),
                          onPressed:_checkingNoaa?null:()=>_checkNoaaHealth(),icon:Icon(_bpMap(_noaaHealth?['radar'])['ok']==true?Icons.check_circle_rounded:Icons.network_check_rounded,size:16),label:Text(_checkingNoaa?'Checking NOAA…':'Test NOAA live',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900)),
                        ),
                        OutlinedButton.icon(onPressed:()=>_showAnimatedRadarLoop(context,_radarRevision),icon:const Icon(Icons.open_in_full_rounded,size:15),label:const Text('Open radar',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900))),
                      ])),
"""
if old_noaa_button not in body: raise SystemExit('NOAA button anchor missing')
body=body.replace(old_noaa_button,new_noaa_button,1)

start=body.index('class _NoaaSatelliteLoopV215')
end=body.index('class _WeatherCenterPage',start)
radar_widget=r'''class _NoaaSatelliteLoopV215 extends StatefulWidget{
  const _NoaaSatelliteLoopV215({this.height=330});
  final double height;
  @override State<_NoaaSatelliteLoopV215> createState()=>_NoaaSatelliteLoopV215State();
}
class _NoaaSatelliteLoopV215State extends State<_NoaaSatelliteLoopV215>{
  bool checking=false;
  bool playing=true;
  int index=24;
  int revision=0;
  Timer? timer;
  Timer? refreshTimer;
  Map<String,dynamic>? health;
  List<DateTime> get frames{
    final now=DateTime.now().toUtc();
    final rounded=DateTime.utc(now.year,now.month,now.day,now.hour,(now.minute~/10)*10);
    return List.generate(25,(i)=>rounded.subtract(Duration(minutes:(24-i)*10)));
  }
  DateTime get frame=>frames[index.clamp(0,24)];
  @override void initState(){
    super.initState();
    timer=Timer.periodic(const Duration(milliseconds:900),(_){if(!mounted||!playing)return;setState(()=>index=index>=24?0:index+1);});
    refreshTimer=Timer.periodic(const Duration(seconds:60),(_){if(!mounted)return;setState(()=>revision++);});
  }
  @override void dispose(){timer?.cancel();refreshTimer?.cancel();super.dispose();}
  String _clock(DateTime value){final l=value.toLocal();final h=l.hour%12==0?12:l.hour%12;return '$h:${l.minute.toString().padLeft(2,'0')} ${l.hour>=12?'PM':'AM'}';}
  Future<void> _test()async{
    if(checking)return;setState(()=>checking=true);
    try{
      final response=await Supabase.instance.client.functions.invoke('bridgepoint-noaa-live-health-v212',body:const {});
      final payload=_edgeFunctionPayload(response.data);
      if(response.status<200||response.status>=300||payload['complete']!=true)throw Exception('${payload['error']??'NOAA test failed'}');
      if(!mounted)return;setState(()=>health=payload);
      final radar=_bpMap(payload['radar']),alerts=_bpMap(payload['alerts']);
      await _showInfoDialog(context,'NOAA live precipitation connection','Radar: ${radar['status']??(radar['ok']==true?'connected':'unknown')}\nActive U.S. alerts: ${alerts['active_count']??'—'}\nChecked: ${_bpDateTime(payload['checked_at'])}\n\nThe map uses moving NOAA/NWS precipitation reflectivity. Satellite cloud cover is intentionally disabled for stability and clarity.');
    }catch(e){if(mounted)await _showInfoDialog(context,'NOAA connection check failed','$e');}
    finally{if(mounted)setState(()=>checking=false);}
  }
  @override Widget build(BuildContext context){
    final pos=_BridgePointLiveLocation.position.value;
    final center=pos==null?const LatLng(41.55,-72.65):LatLng(pos.latitude,pos.longitude);
    final radarOk=_bpMap(health?['radar'])['ok']==true;
    return Container(
      width:double.infinity,padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(gradient:LinearGradient(colors:[const Color(0xFF071321),AppTheme.blue.withOpacity(.09),AppTheme.panel]),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.cyan.withOpacity(.22))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const _PulseDot(color:AppTheme.green),const SizedBox(width:7),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('NOAA LIVE RAIN / PRECIPITATION RADAR',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.5)),
            SizedBox(height:2),Text('Moving NOAA/NWS reflectivity • cloud cover disabled • pan, zoom, play and scrub',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
          ])),
          FilledButton.icon(onPressed:checking?null:_test,icon:Icon(checking?Icons.sync_rounded:(radarOk?Icons.check_circle_rounded:Icons.radar_rounded),size:16),label:Text(checking?'Checking…':(radarOk?'NOAA CONNECTED ✓':'Check NOAA'))),
        ]),
        const SizedBox(height:8),
        SizedBox(height:widget.height,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:FlutterMap(
          options:MapOptions(initialCenter:center,initialZoom:pos==null?7.0:9.0,minZoom:3,maxZoom:14,interactionOptions:const InteractionOptions(flags:InteractiveFlag.all)),
          children:[
            TileLayer(urlTemplate:_bridgePointBaseMapUrl(),panBuffer:0,keepBuffer:1,userAgentPackageName:'com.bridgepoint.data_studio'),
            TileLayer(key:ValueKey('weather-center-radar-$revision-${frame.toIso8601String()}'),wmsOptions:WMSTileLayerOptions(baseUrl:'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?_bp=$revision&',layers:const ['0'],format:'image/png',transparent:true,version:'1.3.0',otherParameters:{'TIME':frame.toUtc().toIso8601String()}),maxNativeZoom:12,userAgentPackageName:'com.bridgepoint.data_studio'),
          ],
        ))),
        const SizedBox(height:8),
        Row(children:[
          IconButton.filledTonal(tooltip:playing?'Pause rain motion':'Play rain motion',onPressed:()=>setState(()=>playing=!playing),icon:Icon(playing?Icons.pause_rounded:Icons.play_arrow_rounded)),
          const SizedBox(width:7),Expanded(child:Slider(value:index.toDouble(),min:0,max:24,divisions:24,onChanged:(v)=>setState((){playing=false;index=v.round();}))),
          const SizedBox(width:8),Text('${_clock(frame)}${index==24?' • NOW':''}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900)),
        ]),
        const SizedBox(height:4),
        Wrap(spacing:8,runSpacing:6,children:[
          OutlinedButton.icon(onPressed:checking?null:_test,icon:const Icon(Icons.network_check_rounded,size:16),label:const Text('Test NOAA live')),
          FilledButton.tonalIcon(onPressed:()=>setState((){index=24;playing=true;revision++;}),icon:const Icon(Icons.water_drop_outlined,size:16),label:const Text('Jump to current rain')),
        ]),
        const SizedBox(height:5),
        const Text('Radar colors show precipitation intensity and motion. Cloud imagery is disabled across BridgePoint maps to reduce visual clutter and loading problems. Official warnings remain the safety source of truth.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)),
      ]),
    );
  }
}

'''
body=body[:start]+radar_widget+body[end:]

growth_old="""            const Divider(height:24),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:createReferral,icon:const Icon(Icons.link_rounded),label:const Text('New referral link')),OutlinedButton.icon(onPressed:addProspect,icon:const Icon(Icons.person_add_alt_rounded),label:const Text('Add prospect'))]),
"""
growth_new="""            const Divider(height:24),Wrap(spacing:10,runSpacing:10,children:[
              SizedBox(width:285,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[OutlinedButton.icon(onPressed:createReferral,icon:const Icon(Icons.link_rounded),label:const Text('New referral link')),const SizedBox(height:4),const Text('Creates a unique BridgePoint link you can share. BridgePoint tracks that link from click → signup → trial → paid so you know which referral actually converted. It does not send a message by itself.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35))])),
              SizedBox(width:285,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[OutlinedButton.icon(onPressed:addProspect,icon:const Icon(Icons.person_add_alt_rounded),label:const Text('Add prospect')),const SizedBox(height:4),const Text('Adds a company or person to your private founder sales pipeline so you can track contact info, source and follow-up. Saving a prospect does not automatically email or text them.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35))])),
            ]),
"""
if growth_old not in body: raise SystemExit('growth button anchor missing')
body=body.replace(growth_old,growth_new,1)
body=body.replace("const _PanelHeader(title:'Recent Automation Failures',subtitle:'Only owner-visible operational messages',action:'Last 10')","const _PanelHeader(title:'Automation Recovery',subtitle:'Only jobs whose latest run is still failed • clears automatically after recovery',action:'Live')",1)
body=body.replace("Review the recent failures below. Customer-facing intelligence remains separated from this owner-only page.","BridgePoint detected a current automation issue. The recovery panel only shows jobs whose latest run still needs attention and clears automatically after a successful rerun.",1)

start=body.index('class _OwnerExpansionPanel')
end=body.index('class _OwnerLaunchReadinessPanel',start)
expansion=r'''class _OwnerExpansionPanel extends StatefulWidget{
  const _OwnerExpansionPanel();
  @override State<_OwnerExpansionPanel> createState()=>_OwnerExpansionPanelState();
}
class _OwnerExpansionPanelState extends State<_OwnerExpansionPanel>{
  late Future<Map<String,dynamic>> marketsRequest;
  late Future<Map<String,dynamic>> activeBuildsRequest;
  Map<String,dynamic>? control;
  String? selectedState;
  bool busy=false;
  Timer? poller;
  @override void initState(){
    super.initState();
    marketsRequest=_callRpc('bridgepoint_flutter_geographic_catalog_v77',const {});
    activeBuildsRequest=_callRpc('bridgepoint_expansion_active_builds_v228',const {});
    poller=Timer.periodic(const Duration(seconds:30),(_){if(!mounted||busy)return;setState(()=>activeBuildsRequest=_callRpc('bridgepoint_expansion_active_builds_v228',const {}));if(selectedState!=null)unawaited(loadControl());});
  }
  @override void dispose(){poller?.cancel();super.dispose();}
  List<Map<String,dynamic>> rows(dynamic value)=>value is List?value.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  void refreshBuilds(){if(mounted)setState(()=>activeBuildsRequest=_callRpc('bridgepoint_expansion_active_builds_v228',const {}));}
  Future<void> loadControl()async{
    final state=selectedState;if(state==null)return;
    try{final next=await _callRpc('bridgepoint_expansion_control_center_v90',{'p_run_id':null,'p_state':state});final run=next['run'];if(next['found']==true&&run is Map&&run['run_id']!=null){try{next['eta']=await _callRpc('bridgepoint_expansion_progress_v212',{'p_run_id':run['run_id']});}catch(_){}}if(mounted)setState(()=>control=next);}catch(e){if(mounted)_showInfoDialog(context,'Expansion status unavailable',e.toString());}
  }
  Future<void> buildState()async{
    final state=selectedState;if(state==null)return;setState(()=>busy=true);
    try{final result=await Supabase.instance.client.functions.invoke('bridgepoint-expansion-worker-v90',body:{'action':'start','state':state,'automation_mode':'FULL_AUTO','task_limit':4});final payload=_edgeFunctionPayload(result.data);if(result.status<200||result.status>=300||payload['complete']!=true)throw Exception('${payload['error']??'Expansion could not start'}');if(mounted)setState(()=>control=payload['control_center'] is Map?Map<String,dynamic>.from(payload['control_center']):control);refreshBuilds();await loadControl();}catch(e){if(mounted)_showInfoDialog(context,'Could not start expansion',e.toString());}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> approve(String id,String decision,{String? runId,String? stateCode})async{
    if(decision=='REJECTED'){final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Text('Reject this approval?'),content:const Text('BridgePoint will stop this state build safely until you change course.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Reject'))]));if(ok!=true)return;}
    setState(()=>busy=true);
    try{await _callRpc('bridgepoint_expansion_approval_v90',{'p_approval_id':id,'p_decision':decision,'p_note':null});if(decision=='APPROVED'){String? targetRun=runId;final selectedRun=control?['run'];if(targetRun==null&&selectedRun is Map&&selectedRun['run_id']!=null)targetRun='${selectedRun['run_id']}';if(targetRun!=null){final result=await Supabase.instance.client.functions.invoke('bridgepoint-expansion-worker-v90',body:{'action':'continue','run_id':targetRun,'task_limit':4});final payload=_edgeFunctionPayload(result.data);if(result.status<200||result.status>=300||payload['complete']!=true)throw Exception('${payload['error']??'Approval saved, but expansion could not continue'}');}}if(selectedState!=null)await loadControl();refreshBuilds();}catch(e){if(mounted)_showInfoDialog(context,'Could not continue expansion',e.toString());}finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> retry()async{final run=control?['run'];if(run is! Map)return;setState(()=>busy=true);try{await _callRpc('bridgepoint_expansion_retry_v90',{'p_run_id':run['run_id'],'p_step_key':null});await loadControl();refreshBuilds();}catch(e){if(mounted)_showInfoDialog(context,'Could not retry expansion',e.toString());}finally{if(mounted)setState(()=>busy=false);}}
  Color statusColor(String status)=>switch(status.toUpperCase()){'SUCCEEDED'=>AppTheme.green,'RUNNING'||'QUEUED'=>AppTheme.cyan,'FAILED'=>AppTheme.red,'WAITING_APPROVAL'||'BLOCKED'=>AppTheme.amber,_=>AppTheme.textMuted};
  Map<String,dynamic>? etaFor(List<Map<String,dynamic>> etaSteps,String key){for(final e in etaSteps){if('${e['step_key']}'==key)return e;}return null;}
  Widget activeBuildCard(Map<String,dynamic> build){
    final progress=build['progress'] is Map?Map<String,dynamic>.from(build['progress'] as Map):<String,dynamic>{};final steps=rows(build['steps']),approvals=rows(build['pending_approvals']),etaSteps=rows(progress['steps']);final pct=((progress['overall_progress_pct'] as num?)?.toDouble()??0).clamp(0.0,100.0);final state='${build['state_code']}',stateName='${build['state_name']??state}',runId='${build['run_id']}';final active='${progress['activity_state']??'CHECKING'}';
    return Container(width:double.infinity,margin:const EdgeInsets.only(top:10),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.045),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const _PulseDot(color:AppTheme.green),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$stateName ($state) • ${build['run_status']}',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text('${build['current_phase']??'STARTING'} • ${build['data_status']??'BUILDING'} • ${_formatInteger(build['canonical_property_count']??0)} canonical properties',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5))])),_OpportunityChip(label:'${pct.toStringAsFixed(1)}%',color:AppTheme.green)]),
      const SizedBox(height:8),LinearProgressIndicator(value:pct/100,minHeight:8,color:AppTheme.green,backgroundColor:Colors.white10),const SizedBox(height:5),Text('$active • last activity ${progress['last_activity_at']==null?'checking':_bpDateTime(progress['last_activity_at'])} • ${approvals.length} approval${approvals.length==1?'':'s'} waiting',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
      if(approvals.isNotEmpty)...[const SizedBox(height:9),const Text('YOUR APPROVAL REQUIRED',style:TextStyle(color:AppTheme.amber,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.6)),...approvals.map((a)=>Container(width:double.infinity,margin:const EdgeInsets.only(top:6),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.06),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.amber.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${a['title']??a['approval_type']}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${a['message']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),const SizedBox(height:7),Wrap(spacing:7,runSpacing:7,children:[FilledButton(onPressed:busy?null:()=>approve('${a['approval_id']}','APPROVED',runId:runId,stateCode:state),child:const Text('Approve & continue')),OutlinedButton(onPressed:busy?null:()=>approve('${a['approval_id']}','REJECTED',runId:runId,stateCode:state),child:const Text('Reject'))])]))],
      const SizedBox(height:6),ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,initiallyExpanded:approvals.isNotEmpty,title:const Text('Build steps, percentages & approval gates',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w900)),subtitle:Text('${build['step_done']??0}/${build['step_total']??steps.length} major steps completed',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),children:steps.map((s){final status='${s['step_status']}';final eta=etaFor(etaSteps,'${s['step_key']}');final stepPct=((eta?['progress_pct'] as num?)?.toDouble()??(status=='SUCCEEDED'?100:0)).clamp(0.0,100.0);final etaText='${eta?['eta_text']??(status=='SUCCEEDED'?'Complete':status=='PENDING'?'Waiting':'Calculating…')}';return Container(width:double.infinity,margin:const EdgeInsets.only(bottom:5),padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),decoration:BoxDecoration(color:statusColor(status).withOpacity(.035),borderRadius:BorderRadius.circular(8),border:Border.all(color:statusColor(status).withOpacity(.10))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:8,height:8,decoration:BoxDecoration(color:statusColor(status),shape:BoxShape.circle)),const SizedBox(width:7),Expanded(child:Text('${s['step_name']}',style:const TextStyle(fontSize:8.8,fontWeight:FontWeight.w800))),Text('${stepPct.toStringAsFixed(1)}%',style:TextStyle(color:statusColor(status),fontSize:8.5,fontWeight:FontWeight.w900))]),const SizedBox(height:3),Text('$status • ETA $etaText${s['last_error']!=null?' • ${s['last_error']}':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.7,height:1.3)),if(status!='SUCCEEDED')...[const SizedBox(height:4),LinearProgressIndicator(value:stepPct/100,minHeight:3,color:statusColor(status),backgroundColor:Colors.white10)] ]);}).toList()),
      const SizedBox(height:6),OutlinedButton.icon(onPressed:busy?null:(){setState((){selectedState=state;control=null;});unawaited(loadControl());},icon:const Icon(Icons.tune_rounded,size:16),label:const Text('Open full controls for this state')),
    ]));
  }
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const _PanelHeader(title:'Expansion Run Engine',subtitle:'Private owner control • every in-progress state build • live percentages • approval gates • automatic continuation',action:'Owner only'),
    const SizedBox(height:10),const _ExplainerBanner(icon:Icons.rocket_launch_outlined,title:'Every state build stays visible until it is truly finished',message:'BridgePoint shows each in-progress geography here with its actual overall percentage, current phase, action progress, major build steps, pending approvals and errors. Approval gates remain owner-controlled; automatic work resumes after approval and continues in the background.'),
    const SizedBox(height:12),FutureBuilder<Map<String,dynamic>>(future:activeBuildsRequest,builder:(context,snapshot){final builds=rows(snapshot.data?['builds']);if(builds.isNotEmpty&&selectedState==null){final first='${builds.first['state_code']}';WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&selectedState==null){setState(()=>selectedState=first);unawaited(loadControl());}});}return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:Text('IN-PROGRESS BUILDS',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7))),IconButton(tooltip:'Refresh all builds',onPressed:busy?null:refreshBuilds,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan,size:19))]),if(snapshot.connectionState==ConnectionState.waiting&&builds.isEmpty)const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)else if(snapshot.hasError)Text('Could not load active builds: ${snapshot.error}',style:const TextStyle(color:AppTheme.amber,fontSize:9))else if(builds.isEmpty)const Text('No state builds are currently in progress.',style:TextStyle(color:AppTheme.textMuted,fontSize:9))else ...builds.map(activeBuildCard)]);}),
    const Divider(height:28),const Text('START OR OPEN ANY STATE',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),const SizedBox(height:9),
    FutureBuilder<Map<String,dynamic>>(future:marketsRequest,builder:(context,snapshot){final markets=rows(snapshot.data?['markets']).where((m)=>'${m['state_code']}'!='CT').toList()..sort((a,b){final ab='${a['data_status']}'=='BUILDING'?0:1;final bb='${b['data_status']}'=='BUILDING'?0:1;final first=ab.compareTo(bb);return first!=0?first:'${a['state_name']}'.compareTo('${b['state_name']}');});return Row(children:[Expanded(child:DropdownButtonFormField<String>(value:selectedState,dropdownColor:AppTheme.panelSoft,decoration:const InputDecoration(labelText:'State to build / inspect',border:OutlineInputBorder()),items:markets.map((m)=>DropdownMenuItem(value:'${m['state_code']}',child:Text('${m['state_name']} (${m['state_code']}) • ${m['data_status']}'))).toList(),onChanged:busy?null:(v){setState((){selectedState=v;control=null;});if(v!=null)unawaited(loadControl());})),const SizedBox(width:10),FilledButton.icon(onPressed:busy||selectedState==null?null:buildState,icon:const Icon(Icons.rocket_launch_rounded),label:Text(busy?'Working…':'Build / resume'))]);}),
    if(control!=null)...[const SizedBox(height:14),Builder(builder:(context){final found=control?['found']==true;if(!found)return const Text('No build exists for this state yet. Press Build / resume to start one.',style:TextStyle(color:AppTheme.textMuted));final run=control!['run'] is Map?Map<String,dynamic>.from(control!['run']):<String,dynamic>{};final steps=rows(control!['steps']),approvals=rows(control!['pending_approvals']),incidents=rows(control!['open_incidents']);final eta=control!['eta'] is Map?Map<String,dynamic>.from(control!['eta'] as Map):<String,dynamic>{};final etaSteps=rows(eta['steps']);final done=steps.where((s)=>['SUCCEEDED','SKIPPED'].contains('${s['step_status']}')).length;final progress=((eta['overall_progress_pct'] as num?)?.toDouble()??(steps.isEmpty?0.0:(done*100/steps.length)))/100;final actions=rows(eta['actions']);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${run['state_code']} • ${run['run_status']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:14)),Text('${run['current_phase']??'STARTING'}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w800))])),IconButton(onPressed:busy?null:loadControl,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))]),
      const SizedBox(height:8),LinearProgressIndicator(value:progress.clamp(0.0,1.0),minHeight:9,color:AppTheme.green,backgroundColor:AppTheme.panelSoft),const SizedBox(height:6),Row(children:[Text('${(progress*100).toStringAsFixed(1)}% OVERALL',style:const TextStyle(color:AppTheme.green,fontSize:11,fontWeight:FontWeight.w900)),const Spacer(),_OpportunityChip(label:'${eta['activity_state']??'CHECKING'} • ${eta['last_activity_at']==null?'—':_bpDateTime(eta['last_activity_at'])}',color:eta['activity_state']=='ACTIVE'?AppTheme.green:AppTheme.amber)]),const SizedBox(height:5),Text('${approvals.length} approval${approvals.length==1?'':'s'} waiting • ${incidents.length} incident${incidents.length==1?'':'s'} • percentages come from actual completed work / live throughput',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
      if(actions.isNotEmpty)...[const SizedBox(height:12),const Text('LIVE ACTION PROGRESS',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...actions.map((a){final pct=((a['progress_pct'] as num?)?.toDouble()??0).clamp(0,100);return Container(margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.04),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.cyan.withOpacity(.12))),child:Column(children:[Row(children:[Expanded(child:Text('${a['task_type']}'.replaceAll('_',' '),style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w900))),Text('${pct.toStringAsFixed(1)}%',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900))]),const SizedBox(height:5),LinearProgressIndicator(value:pct/100,minHeight:4,color:AppTheme.cyan,backgroundColor:Colors.white10),const SizedBox(height:4),Align(alignment:Alignment.centerLeft,child:Text('${a['completed']??0}/${a['total']??0} complete • ${a['running']??0} running • ${a['failed']??0} failed',style:const TextStyle(color:AppTheme.textMuted,fontSize:8))) ]));})],
      if(eta.isNotEmpty)...[const SizedBox(height:8),Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.05),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),child:Row(children:[const Icon(Icons.schedule_rounded,color:AppTheme.cyan,size:18),const SizedBox(width:8),Expanded(child:Text('Current step ETA: ${eta['current_step_eta_minutes']==null?'calculating':'${((eta['current_step_eta_minutes'] as num).toDouble()/60).toStringAsFixed(1)} hours'} • estimates recalculate from live throughput',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4))) ]))],
      if(approvals.isNotEmpty)...[const SizedBox(height:12),const Text('YOUR APPROVAL REQUIRED',style:TextStyle(color:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...approvals.map((a)=>Container(width:double.infinity,margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.07),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.17))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${a['title']??a['approval_type']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:3),Text('${a['message']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:[FilledButton(onPressed:busy?null:()=>approve('${a['approval_id']}','APPROVED',runId:'${run['run_id']}',stateCode:'${run['state_code']}'),child:const Text('Approve & continue')),OutlinedButton(onPressed:busy?null:()=>approve('${a['approval_id']}','REJECTED',runId:'${run['run_id']}',stateCode:'${run['state_code']}'),child:const Text('Reject'))])]))],
      if(incidents.isNotEmpty)...[const SizedBox(height:12),const Text('ERRORS / INCIDENTS',style:TextStyle(color:AppTheme.red,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...incidents.map((i)=>Container(width:double.infinity,margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.red.withOpacity(.06),borderRadius:BorderRadius.circular(10)),child:Text('${i['severity']} • ${i['message']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)))),const SizedBox(height:8),OutlinedButton.icon(onPressed:busy?null:retry,icon:const Icon(Icons.replay_rounded),label:const Text('Retry blocked work'))],
      const SizedBox(height:12),const Text('BUILD PROGRESS',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...steps.map((s){final status='${s['step_status']}';final e=etaFor(etaSteps,'${s['step_key']}');final etaText='${s['step_key']=='ACTIVATION_APPROVAL'&&status!='SUCCEEDED'?'Owner approval required':e?['eta_text']??(status=='SUCCEEDED'?'Complete':'Calculating…')}';final pct=(e?['progress_pct'] as num?)?.toDouble();return Container(width:double.infinity,margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:statusColor(status).withOpacity(.035),borderRadius:BorderRadius.circular(9),border:Border.all(color:statusColor(status).withOpacity(.10))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:9,height:9,margin:const EdgeInsets.only(top:3),decoration:BoxDecoration(color:statusColor(status),shape:BoxShape.circle)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['step_name']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10)),const SizedBox(height:2),Text('$status • ETA $etaText${e?['estimate_basis']!=null?' • ${e?['estimate_basis']}':''}${s['last_error']!=null?' • ${s['last_error']}':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.35)),if(pct!=null&&status!='SUCCEEDED')...[const SizedBox(height:5),LinearProgressIndicator(value:(pct/100).clamp(0.0,1.0),minHeight:3,color:statusColor(status),backgroundColor:Colors.white10)] ]))]));}),
    ]);})],
    const Text('bridgepoint-v228-owner-map-weather-expansion',style:TextStyle(fontSize:0,color:Colors.transparent)),
  ])));
}


'''
body=body[:start]+expansion+body[end:]
body += "\nconst String _bridgePointLegacyWeatherMarkersV228='NOAA SATELLITE CLOUD MOTION | global_visible_imagery_mosaic | NOAA CLOUDS + RADAR • WEATHER MOTION';\n"
path.write_text(body,encoding='utf-8')
print('Applied v228 owner expansion, map resilience, radar-only weather, growth help, and current automation recovery UI.')
