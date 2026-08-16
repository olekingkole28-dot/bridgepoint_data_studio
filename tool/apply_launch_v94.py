from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text


def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text = text.replace(old, new, 1)

# 1) Keep automatic refresh from destroying the active page subtree.
replace_once(
"""      dashboardRequest = nextDashboard;
      sourcesRequest = nextSources;
      healthRequest = _loadSystemHealth();
      _liveRefreshTick++;
""",
"""      dashboardRequest = nextDashboard;
      sourcesRequest = nextSources;
      healthRequest = _loadSystemHealth();
""",
'preserve-page-on-live-refresh')

# 2) Live map: lighter initial payload, fresh NOAA tiles, U.S. view, less GPU decoration.
replace_once(
"""  String _visibleLayer=_displayPreferences.value.simplifiedViews?'opportunities':'both';
  bool _showRadar=true;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
""",
"""  String _visibleLayer=_displayPreferences.value.simplifiedViews?'opportunities':'both';
  bool _showRadar=true;
  bool _showExpansion=!_displayPreferences.value.simplifiedViews;
  Timer? _radarRefreshTimer;
  int _radarRevision=0;
""",
'map-radar-state')

replace_once(
"""  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void didUpdateWidget(covariant _IntelligenceMapPage oldWidget) {
""",
"""  void initState() {
    super.initState();
    _request = _load();
    _radarRefreshTimer=Timer.periodic(const Duration(seconds:60),(_){
      if(mounted&&_showRadar)setState(()=>_radarRevision++);
    });
  }

  @override
  void dispose(){
    _radarRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _IntelligenceMapPage oldWidget) {
""",
'map-radar-timer')

replace_once("'p_min_score': _minimumScore,'p_limit': 500,", "'p_min_score': _minimumScore,'p_limit': 250,", 'map-opportunity-limit')
replace_once("'p_min_lat':null,'p_max_lat':null,'p_min_lng':null,'p_max_lng':null,'p_limit':240,", "'p_min_lat':null,'p_max_lat':null,'p_min_lng':null,'p_max_lng':null,'p_limit':120,", 'map-signal-limit')
replace_once("""                          minZoom: 4,
                          maxZoom: 18,
""", """                          minZoom: 3,
                          maxZoom: 18,
""", 'map-min-zoom')
replace_once(
"""                          if(_showRadar)TileLayer(
                            wmsOptions:WMSTileLayerOptions(
                              baseUrl:'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?',
                              layers:const ['conus_bref_qcd'],format:'image/png',transparent:true,version:'1.3.0',
                            ),
                            maxNativeZoom:12,
                            userAgentPackageName:'com.bridgepoint.data_studio',
                          ),
""",
"""                          if(_showRadar)TileLayer(
                            key:ValueKey('noaa-radar-$_radarRevision'),
                            wmsOptions:WMSTileLayerOptions(
                              baseUrl:'https://opengeo.ncep.noaa.gov/geoserver/conus/conus_bref_qcd/ows?_bp=$_radarRevision&',
                              layers:const ['conus_bref_qcd'],format:'image/png',transparent:true,version:'1.3.0',
                            ),
                            maxNativeZoom:12,
                            userAgentPackageName:'com.bridgepoint.data_studio',
                          ),
""",
'map-live-radar-cache-bust')
replace_once(
"""                      if(!loading&&!_displayPreferences.value.reducedMotion)const Positioned.fill(child:IgnorePointer(child:_MapScanOverlay())),
""",
"""                      // Keep the live map lightweight; NOAA radar provides the motion/context instead of a GPU scan overlay.
""",
'map-remove-scan-overlay')
replace_once(
"""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show Northeast expansion',onTap:()=>_mapController.move(const LatLng(42.15,-72.90),6.3)),
""",
"""                            _MapControlButton(icon:Icons.public_rounded,tooltip:'Show United States live weather',onTap:()=>_mapController.move(const LatLng(39.50,-98.35),4.2)),
""",
'map-us-weather-button')

# 3) Technology products: show starting prices but route them to enterprise interest, never normal Stripe checkout.
replace_once(
"""    final type = '${package['package_type'] ?? 'standard'}';

    return Card(
""",
"""    final type = '${package['package_type'] ?? 'standard'}';
    final technology='${package['package_key']??''}'.startsWith('technology_');

    return Card(
""",
'technology-card-flag')
replace_once(
"""                  if (trialDays != null)
                    _OpportunityChip(
                      label: '$trialDays DAY TRIAL',
                      color: AppTheme.cyan,
                    ),
""",
"""                  if (!technology && trialDays != null && trialDays>0)
                    _OpportunityChip(
                      label: '$trialDays DAY TRIAL',
                      color: AppTheme.cyan,
                    ),
                  if (technology)
                    const _OpportunityChip(label:'ENTERPRISE TECHNOLOGY',color:AppTheme.amber),
""",
'technology-card-chip')
replace_once(
"""                  child: const Text(
                    'Custom intelligence model builder',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
""",
"""                  child: Text(
                    technology?'BridgePoint technology infrastructure • scoped deployment':'Custom intelligence model builder',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
""",
'technology-empty-model-copy')
replace_once(
"""                              ? '\$${monthly.toStringAsFixed(0)} / month'
""",
"""                              ? '${technology?'Starting at ':''}\$${monthly.toStringAsFixed(0)} / month'
""",
'technology-price-label')

replace_once(
"""  final models = rawModels is List
      ? rawModels.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  showDialog<void>(
""",
"""  final models = rawModels is List
      ? rawModels.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  final technology='${package['package_key']??''}'.startsWith('technology_');

  showDialog<void>(
""",
'technology-detail-flag')
replace_once(
"""                  const Text(
                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',
                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),
                  ),
""",
"""                  Text(
                    technology
                      ? 'Technology pricing is shown as a starting point. BridgePoint scopes data volume, deployment mode, geography, API usage and support before billing. Core scoring weights and proprietary learning logic stay protected.'
                      : 'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',
                    style: const TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),
                  ),
""",
'technology-detail-banner')
replace_once(
"""                Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:const Icon(Icons.bolt_rounded),
                    label:Text(package['monthly_price']==null?'Monthly unavailable':'Start monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
""",
"""                if(technology)SizedBox(width:double.infinity,child:FilledButton.icon(
                  onPressed:()async{
                    try{
                      final result=await _callRpc('bridgepoint_request_technology_package_v93',{'p_package_key':package['package_key'],'p_note':null});
                      if(context.mounted){Navigator.of(context).pop();_showInfoDialog(context,'Technology request saved','${result['message']??'BridgePoint saved your request.'}');}
                    }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save request',e.toString());}
                  },
                  icon:const Icon(Icons.business_center_outlined),
                  label:Text('Request technology scope • starting at \$${(package['monthly_price'] as num?)?.toStringAsFixed(0)??'—'}/mo'),
                )) else Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:const Icon(Icons.bolt_rounded),
                    label:Text(package['monthly_price']==null?'Monthly unavailable':'Start monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
""",
'technology-contact-sales')

# 4) Native owner-only state expansion panel.
replace_once(
"""        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:LayoutBuilder(builder:(context,c)=>Wrap(
""",
"""        const SizedBox(height:18),const _OwnerExpansionPanel(),
        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(18),child:LayoutBuilder(builder:(context,c)=>Wrap(
""",
'owner-expansion-insert')

marker = "class _EmergencyAdminPanel extends StatefulWidget{"
if text.count(marker) != 1:
    raise SystemExit('owner-expansion-class-marker not found exactly once')
owner_class = r'''
class _OwnerExpansionPanel extends StatefulWidget{
  const _OwnerExpansionPanel();
  @override State<_OwnerExpansionPanel> createState()=>_OwnerExpansionPanelState();
}
class _OwnerExpansionPanelState extends State<_OwnerExpansionPanel>{
  late Future<Map<String,dynamic>> marketsRequest;
  Map<String,dynamic>? control;
  String? selectedState;
  bool busy=false;
  Timer? poller;
  @override void initState(){
    super.initState();
    marketsRequest=_callRpc('bridgepoint_flutter_geographic_catalog_v77',const {});
    poller=Timer.periodic(const Duration(seconds:15),(_){if(mounted&&selectedState!=null&&!busy)unawaited(loadControl());});
  }
  @override void dispose(){poller?.cancel();super.dispose();}
  List<Map<String,dynamic>> rows(dynamic value)=>value is List?value.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  Future<void> loadControl()async{
    final state=selectedState;if(state==null)return;
    try{final next=await _callRpc('bridgepoint_expansion_control_center_v90',{'p_run_id':null,'p_state':state});if(mounted)setState(()=>control=next);}catch(e){if(mounted)_showInfoDialog(context,'Expansion status unavailable',e.toString());}
  }
  Future<void> buildState()async{
    final state=selectedState;if(state==null)return;
    setState(()=>busy=true);
    try{
      final result=await Supabase.instance.client.functions.invoke('bridgepoint-expansion-worker-v90',body:{'action':'start','state':state,'automation_mode':'FULL_AUTO','task_limit':4});
      final payload=_edgeFunctionPayload(result.data);
      if(result.status<200||result.status>=300||payload['complete']!=true)throw Exception('${payload['error']??'Expansion could not start'}');
      if(mounted)setState(()=>control=payload['control_center'] is Map?Map<String,dynamic>.from(payload['control_center']):control);
    }catch(e){if(mounted)_showInfoDialog(context,'Could not start expansion',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> approve(String id,String decision)async{
    if(decision=='REJECTED'){
      final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Text('Reject this approval?'),content:const Text('BridgePoint will stop this state build safely until you change course.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Reject'))]));
      if(ok!=true)return;
    }
    setState(()=>busy=true);
    try{await _callRpc('bridgepoint_expansion_approval_v90',{'p_approval_id':id,'p_decision':decision,'p_note':null});await loadControl();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not save decision',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> retry()async{
    final run=control?['run'];if(run is! Map)return;
    setState(()=>busy=true);
    try{await _callRpc('bridgepoint_expansion_retry_v90',{'p_run_id':run['run_id'],'p_step_key':null});await loadControl();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not retry expansion',e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Color statusColor(String status)=>switch(status.toUpperCase()){'SUCCEEDED'=>AppTheme.green,'RUNNING'||'QUEUED'=>AppTheme.cyan,'FAILED'=>AppTheme.red,'WAITING_APPROVAL'||'BLOCKED'=>AppTheme.amber,_=>AppTheme.textMuted};
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const _PanelHeader(title:'One-click State Expansion',subtitle:'Private owner control • choose a state • BridgePoint discovers the best available data for that state and builds through governed quality gates',action:'Owner only'),
    const SizedBox(height:10),const _ExplainerBanner(icon:Icons.rocket_launch_outlined,title:'Connecticut is a reference architecture—not a data ceiling',message:'A new state can use better, different, or unique datasets. BridgePoint automatically prefers authoritative high-quality substitutes, keeps state-only advantages, pauses only for real approval decisions or blocking errors, and continues in the background after you close the app.'),
    const SizedBox(height:14),FutureBuilder<Map<String,dynamic>>(future:marketsRequest,builder:(context,snapshot){
      final markets=rows(snapshot.data?['markets']).where((m)=>'${m['state_code']}'!='CT').toList()..sort((a,b)=>'${a['state_name']}'.compareTo('${b['state_name']}'));
      return Row(children:[Expanded(child:DropdownButtonFormField<String>(value:selectedState,dropdownColor:AppTheme.panelSoft,decoration:const InputDecoration(labelText:'State to build',border:OutlineInputBorder()),items:markets.map((m)=>DropdownMenuItem(value:'${m['state_code']}',child:Text('${m['state_name']} (${m['state_code']}) • ${m['data_status']}'))).toList(),onChanged:busy?null:(v){setState((){selectedState=v;control=null;});if(v!=null)unawaited(loadControl());})),const SizedBox(width:10),FilledButton.icon(onPressed:busy||selectedState==null?null:buildState,icon:const Icon(Icons.rocket_launch_rounded),label:Text(busy?'Working…':'Build State'))]);
    }),
    if(control!=null)...[
      const SizedBox(height:14),Builder(builder:(context){
        final found=control?['found']==true; if(!found)return const Text('No build exists for this state yet. Press Build State to start one.',style:TextStyle(color:AppTheme.textMuted));
        final run=control!['run'] is Map?Map<String,dynamic>.from(control!['run']):<String,dynamic>{};
        final steps=rows(control!['steps']),approvals=rows(control!['pending_approvals']),incidents=rows(control!['open_incidents']);
        final done=steps.where((s)=>['SUCCEEDED','SKIPPED'].contains('${s['step_status']}')).length;
        final progress=steps.isEmpty?0.0:(done/steps.length).clamp(0.0,1.0);
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${run['state_code']} • ${run['run_status']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:14)),Text('${run['current_phase']??'STARTING'}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w800))])),IconButton(onPressed:busy?null:loadControl,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))]),
          const SizedBox(height:8),LinearProgressIndicator(value:progress,minHeight:7,color:AppTheme.cyan,backgroundColor:AppTheme.panelSoft),const SizedBox(height:5),Text('${(progress*100).round()}% governed steps complete • ${approvals.length} approval${approvals.length==1?'':'s'} waiting • ${incidents.length} incident${incidents.length==1?'':'s'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)),
          if(approvals.isNotEmpty)...[const SizedBox(height:12),const Text('YOUR APPROVAL REQUIRED',style:TextStyle(color:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...approvals.map((a)=>Container(width:double.infinity,margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.07),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.17))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${a['title']??a['approval_type']}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:3),Text('${a['message']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:[FilledButton(onPressed:busy?null:()=>approve('${a['approval_id']}','APPROVED'),child:const Text('Approve & continue')),OutlinedButton(onPressed:busy?null:()=>approve('${a['approval_id']}','REJECTED'),child:const Text('Reject'))])]))],
          if(incidents.isNotEmpty)...[const SizedBox(height:12),const Text('ERRORS / INCIDENTS',style:TextStyle(color:AppTheme.red,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...incidents.map((i)=>Container(width:double.infinity,margin:const EdgeInsets.only(top:7),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.red.withOpacity(.06),borderRadius:BorderRadius.circular(10)),child:Text('${i['severity']} • ${i['message']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)))),const SizedBox(height:8),OutlinedButton.icon(onPressed:busy?null:retry,icon:const Icon(Icons.replay_rounded),label:const Text('Retry blocked work'))],
          const SizedBox(height:12),const Text('BUILD PROGRESS',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),...steps.map((s){final status='${s['step_status']}';return Padding(padding:const EdgeInsets.only(top:7),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:9,height:9,margin:const EdgeInsets.only(top:3),decoration:BoxDecoration(color:statusColor(status),shape:BoxShape.circle)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['step_name']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10)),Text('$status${s['last_error']!=null?' • ${s['last_error']}':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.35))]))]));}),
        ]);
      })
    ],
  ])));
}

'''
text = text.replace(marker, owner_class + marker, 1)

if text == original:
    raise SystemExit('No changes applied')
path.write_text(text, encoding='utf-8')
print('Applied BridgePoint launch patch v94')
