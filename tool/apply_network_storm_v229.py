from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v229-network-storm-accuracy'
if marker in body:
    print('v229 already applied')
    raise SystemExit(0)

old="""@immutable
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
"""
new="""@immutable
class _ConnectionHealth{
  const _ConnectionHealth({this.consecutiveFailures=0,this.slowRequests=0,this.lastLatencyMs=0,this.lastSuccessAt});
  final int consecutiveFailures,slowRequests,lastLatencyMs;
  final DateTime? lastSuccessAt;
  // Only show Offline Mode after several true transport failures in a row.
  // Normal API validation errors and a couple slow requests do not count as a bad connection.
  bool get spotty=>consecutiveFailures>=4;
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
  final slow=milliseconds>=9000?min(current.slowRequests+1,6):max(current.slowRequests-2,0);
  _bridgePointConnectionHealth.value=_ConnectionHealth(
    consecutiveFailures:0,slowRequests:slow,lastLatencyMs:milliseconds,lastSuccessAt:DateTime.now(),
  );
}
void _bpConnectionFailure(){
  final current=_bridgePointConnectionHealth.value;
  _bridgePointConnectionHealth.value=current.copyWith(consecutiveFailures:min(current.consecutiveFailures+1,10));
}
"""
if body.count(old)!=1: raise SystemExit(f'connection health anchor {body.count(old)}')
body=body.replace(old,new,1)

old_rpc="""Future<Map<String, dynamic>> _callRpc(String name, Map<String, dynamic> body) async {
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
"""
new_rpc="""Future<Map<String, dynamic>> _callRpc(String name, Map<String, dynamic> body) async {
  final watch=Stopwatch()..start();
  var reachedServer=false;
  try{
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/$name'),
      headers: _apiHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    reachedServer=true;
    watch.stop();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // The server answered, so this is an application/API error rather than bad internet.
      throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
    }
    _bpConnectionSuccess(watch.elapsedMilliseconds);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Unexpected BridgePoint response.');
    return Map<String, dynamic>.from(decoded);
  }catch(_){
    if(watch.isRunning)watch.stop();
    if(!reachedServer)_bpConnectionFailure();
    rethrow;
  }
}
"""
if body.count(old_rpc)!=1: raise SystemExit(f'rpc anchor {body.count(old_rpc)}')
body=body.replace(old_rpc,new_rpc,1)

body=body.replace("Expanded(child:Text('Connection looks spotty — switch to Offline Mode?  ${health.consecutiveFailures} recent failure${health.consecutiveFailures==1?'':'s'} • last request ${health.lastLatencyMs} ms',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800))),","Expanded(child:Text('BridgePoint could not reach the server several times in a row. Offline Mode is available until the connection recovers. • ${health.consecutiveFailures} consecutive connection failures',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800))),",1)

weather_anchor='class _WeatherCenterPage extends StatefulWidget{'
idx=body.index(weather_anchor)
storm=r'''class _UsStormCloudActivityV229 extends StatefulWidget{
  const _UsStormCloudActivityV229();
  @override State<_UsStormCloudActivityV229> createState()=>_UsStormCloudActivityV229State();
}
class _UsStormCloudActivityV229State extends State<_UsStormCloudActivityV229>{
  Map<String,dynamic> data=<String,dynamic>{};
  bool loading=true;
  String? error;
  Timer? refreshTimer;
  int revision=0;
  @override void initState(){
    super.initState();
    unawaited(_refresh());
    refreshTimer=Timer.periodic(const Duration(minutes:5),(_)=>unawaited(_refresh(silent:true)));
  }
  @override void dispose(){refreshTimer?.cancel();super.dispose();}
  Future<void> _refresh({bool silent=false})async{
    if(!silent&&mounted)setState(()=>loading=true);
    try{
      final response=await Supabase.instance.client.functions.invoke('bridgepoint-us-storm-clouds-v229',body:const {});
      final payload=_edgeFunctionPayload(response.data);
      if(response.status<200||response.status>=300||payload['complete']!=true)throw Exception('${payload['error']??'National storm feed unavailable'}');
      if(mounted)setState((){data=payload;error=null;loading=false;revision++;});
    }catch(e){
      if(mounted)setState((){error='$e';loading=false;});
    }
  }
  Color _severity(String value)=>switch(value.toUpperCase()){'EXTREME'=>Colors.redAccent,'SEVERE'=>Colors.deepOrangeAccent,'MODERATE'=>AppTheme.amber,_=>AppTheme.cyan};
  @override Widget build(BuildContext context){
    final sat=_bpMap(data['satellite']);
    final alerts=_bpMap(data['alerts']);
    final top=_bpRows(alerts['top_alerts']);
    final image='${sat['image_url']??''}';
    final imageTime=_bpDateTime(sat['image_time']);
    final generated=_bpDateTime(data['generated_at']);
    return Container(
      width:double.infinity,padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:AppTheme.panel,borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.blue.withOpacity(.25))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.thunderstorm_rounded,color:AppTheme.cyan),const SizedBox(width:8),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('U.S. ACTIVE STORM / CLOUD ACTIVITY',style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w900,letterSpacing:.45)),
            SizedBox(height:2),Text('NOAA GOES-19 satellite + nationwide NWS storm alerts • automatically refreshes every 5 minutes',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
          ])),
          if(loading)const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
          else IconButton.filledTonal(tooltip:'Refresh NOAA storm data now',onPressed:()=>_refresh(),icon:const Icon(Icons.refresh_rounded,size:18)),
        ]),
        const SizedBox(height:9),
        LayoutBuilder(builder:(context,c){
          final compact=c.maxWidth<760;
          final satelliteCard=Container(
            padding:const EdgeInsets.all(9),
            decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.6),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white10)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[const Icon(Icons.satellite_alt_rounded,color:AppTheme.cyan,size:17),const SizedBox(width:6),const Expanded(child:Text('LIVE CONUS CLOUD VIEW',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900))),Text(sat['ok']==true?'LIVE':'SOURCE DELAY',style:TextStyle(fontSize:8,fontWeight:FontWeight.w900,color:sat['ok']==true?AppTheme.green:AppTheme.amber))]),
              const SizedBox(height:7),
              ClipRRect(borderRadius:BorderRadius.circular(10),child:image.isNotEmpty
                ? Image.network('$image?bp=$revision',width:double.infinity,height:compact?230:300,fit:BoxFit.cover,gaplessPlayback:true,errorBuilder:(_,__,___)=>Container(height:compact?230:300,color:Colors.white.withOpacity(.03),child:const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.cloud_off_rounded,color:AppTheme.amber,size:34),SizedBox(height:7),Text('NOAA satellite image is temporarily unavailable.',style:TextStyle(color:AppTheme.textMuted,fontSize:9))])))
                : Container(height:compact?230:300,color:Colors.white.withOpacity(.03),child:const Center(child:Text('Waiting for the current NOAA satellite frame…',style:TextStyle(color:AppTheme.textMuted,fontSize:9))))),
              const SizedBox(height:7),
              Text('Satellite frame: ${imageTime=='—'?'latest NOAA frame':imageTime}',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),
              const SizedBox(height:2),
              const Text('Source: NOAA NESDIS / STAR • GOES-19 GeoColor • continental U.S. • source imagery updates every 5 minutes.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.35)),
            ]),
          );
          final alertCard=Container(
            padding:const EdgeInsets.all(11),
            decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.6),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white10)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('NATIONWIDE ACTIVE STORM ALERTS',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.35)),const SizedBox(height:7),
              Wrap(spacing:7,runSpacing:7,children:[
                Chip(label:Text('All NWS alerts ${alerts['active_count']??'—'}',style:const TextStyle(fontSize:8,fontWeight:FontWeight.w800)),backgroundColor:AppTheme.cyan.withOpacity(.08),side:BorderSide(color:AppTheme.cyan.withOpacity(.18))),
                Chip(label:Text('Storm alerts ${alerts['storm_alert_count']??'—'}',style:const TextStyle(fontSize:8,fontWeight:FontWeight.w800)),backgroundColor:AppTheme.amber.withOpacity(.08),side:BorderSide(color:AppTheme.amber.withOpacity(.18))),
                Chip(label:Text('Severe / extreme ${alerts['severe_count']??'—'}',style:const TextStyle(fontSize:8,fontWeight:FontWeight.w800)),backgroundColor:Colors.redAccent.withOpacity(.08),side:BorderSide(color:Colors.redAccent.withOpacity(.18))),
              ]),
              const SizedBox(height:8),
              if(top.isEmpty)const Text('No active storm-specific alerts were returned on the latest nationwide check.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.7,height:1.4))
              else ...top.take(8).map((a)=>Container(width:double.infinity,margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:_severity('${a['severity']??''}').withOpacity(.06),borderRadius:BorderRadius.circular(9),border:Border.all(color:_severity('${a['severity']??''}').withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[Expanded(child:Text('${a['event']??'Weather alert'}',style:const TextStyle(fontSize:8.8,fontWeight:FontWeight.w900))),Text('${a['severity']??''}',style:TextStyle(fontSize:7.8,fontWeight:FontWeight.w900,color:_severity('${a['severity']??''}')))]),
                const SizedBox(height:3),Text('${a['area']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.3)),
              ])),
              const SizedBox(height:3),Text('Nationwide alert feed checked: ${generated=='—'?'just now':generated}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.2)),
              const SizedBox(height:2),const Text('NWS alert coverage includes the U.S., Alaska, Hawaii, Puerto Rico, territories and marine zones when alerts are issued.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.35)),
            ]),
          );
          return compact?Column(children:[satelliteCard,const SizedBox(height:9),alertCard]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:3,child:satelliteCard),const SizedBox(width:9),Expanded(flex:2,child:alertCard)]);
        }),
        if(error!=null)...[const SizedBox(height:7),Text('Latest refresh issue: $error • BridgePoint keeps the last good storm data visible and retries automatically.',style:const TextStyle(color:AppTheme.amber,fontSize:8.2,height:1.35))],
        const SizedBox(height:6),
        const Text('This panel is for situational awareness. Follow official NWS warnings and local emergency instructions for safety decisions.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.35)),
      ]),
    );
  }
}

'''
body=body[:idx]+storm+body[idx:]

old_insert="""      const _NoaaSatelliteLoopV215(height:300),
      const SizedBox(height:12),
      LayoutBuilder(builder:(context,c){"""
new_insert="""      const _NoaaSatelliteLoopV215(height:300),
      const SizedBox(height:12),
      const _UsStormCloudActivityV229(),
      const SizedBox(height:12),
      LayoutBuilder(builder:(context,c){"""
if body.count(old_insert)!=1: raise SystemExit(f'weather insert anchor {body.count(old_insert)}')
body=body.replace(old_insert,new_insert,1)

body += "\nconst String _bridgePointV229NetworkStormAccuracy='bridgepoint-v229-network-storm-accuracy | U.S. ACTIVE STORM / CLOUD ACTIVITY | bridgepoint-us-storm-clouds-v229';\n"
path.write_text(body,encoding='utf-8')
print('Applied v229 connection warning tuning and NOAA national storm/cloud auto-refresh panel.')
