from pathlib import Path
import runpy

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v276-owner-expansion-active-builds'
if marker in body:
    print('Owner expansion active-build v276 already applied.')
    raise SystemExit(0)

old_init="""    marketsRequest=_callRpc('bridgepoint_flutter_geographic_catalog_v77',const {});
    activeBuildsRequest=_callRpc('bridgepoint_expansion_active_builds_v228',const {});
    poller=Timer.periodic(const Duration(seconds:30),(_){if(!mounted||busy)return;setState(()=>activeBuildsRequest=_callRpc('bridgepoint_expansion_active_builds_v228',const {}));if(selectedState!=null)unawaited(loadControl());});
  }
  @override void dispose(){poller?.cancel();super.dispose();}
  List<Map<String,dynamic>> rows(dynamic value)=>value is List?value.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  void refreshBuilds(){if(mounted)setState(()=>activeBuildsRequest=_callRpc('bridgepoint_expansion_active_builds_v228',const {}));}
"""
new_init="""    marketsRequest=_callRpc('bridgepoint_flutter_geographic_catalog_v77',const {});
    activeBuildsRequest=_loadActiveBuilds();
    poller=Timer.periodic(const Duration(seconds:30),(_){if(!mounted||busy)return;setState(()=>activeBuildsRequest=_loadActiveBuilds());if(selectedState!=null)unawaited(loadControl());});
  }
  @override void dispose(){poller?.cancel();super.dispose();}
  List<Map<String,dynamic>> rows(dynamic value)=>value is List?value.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  Future<Map<String,dynamic>> _loadActiveBuilds()async{
    final data=await _callRpc('bridgepoint_expansion_active_builds_v228',const {});
    final builds=rows(data['builds']);
    if(builds.isNotEmpty){
      final codes=builds.map((b)=>'${b['state_code']}').where((x)=>x.isNotEmpty).toSet();
      if(selectedState==null||!codes.contains(selectedState)){
        selectedState='${builds.first['state_code']}';
        WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&selectedState!=null)unawaited(loadControl());});
      }
    }
    return data;
  }
  void refreshBuilds(){if(mounted)setState(()=>activeBuildsRequest=_loadActiveBuilds());}
"""
if body.count(old_init)!=1:
    raise SystemExit(f'v276 init anchor {body.count(old_init)}')
body=body.replace(old_init,new_init,1)

legacy_select="""if(builds.isNotEmpty&&selectedState==null){final first='${builds.first['state_code']}';WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&selectedState==null){setState(()=>selectedState=first);unawaited(loadControl());}});}"""
if body.count(legacy_select)==1:
    body=body.replace(legacy_select,'',1)
elif body.count(legacy_select)>1:
    raise SystemExit('v276 active selector became ambiguous')

old_cards="""else ...builds.map(activeBuildCard)]);}),"""
new_cards="""else ...builds.map((b)=>InkWell(borderRadius:BorderRadius.circular(12),onTap:busy?null:(){final code='${b['state_code']}';setState((){selectedState=code;control=null;});unawaited(loadControl());},child:activeBuildCard(b)))]);}),"""
if body.count(old_cards)!=1:
    raise SystemExit(f'v276 active cards anchor {body.count(old_cards)}')
body=body.replace(old_cards,new_cards,1)

old_market="""    FutureBuilder<Map<String,dynamic>>(future:marketsRequest,builder:(context,snapshot){final markets=rows(snapshot.data?['markets']).where((m)=>'${m['state_code']}'!='CT').toList()..sort((a,b){final ab='${a['data_status']}'=='BUILDING'?0:1;final bb='${b['data_status']}'=='BUILDING'?0:1;final first=ab.compareTo(bb);return first!=0?first:'${a['state_name']}'.compareTo('${b['state_name']}');});return Row(children:[Expanded(child:DropdownButtonFormField<String>(value:selectedState,dropdownColor:AppTheme.panelSoft,decoration:const InputDecoration(labelText:'State to build / inspect',border:OutlineInputBorder()),items:markets.map((m)=>DropdownMenuItem(value:'${m['state_code']}',child:Text('${m['state_name']} (${m['state_code']}) • ${m['data_status']}'))).toList(),onChanged:busy?null:(v){setState((){selectedState=v;control=null;});if(v!=null)unawaited(loadControl());})),const SizedBox(width:10),FilledButton.icon(onPressed:busy||selectedState==null?null:buildState,icon:const Icon(Icons.rocket_launch_rounded),label:Text(busy?'Working…':'Build / resume'))]);}),
"""
new_market="""    FutureBuilder<Map<String,dynamic>>(future:marketsRequest,builder:(context,snapshot){
      final markets=rows(snapshot.data?['markets']).where((m)=>'${m['state_code']}'!='CT').toList()..sort((a,b){final ab='${a['data_status']}'=='BUILDING'?0:1;final bb='${b['data_status']}'=='BUILDING'?0:1;final first=ab.compareTo(bb);return first!=0?first:'${a['state_name']}'.compareTo('${b['state_name']}');});
      final codes=markets.map((m)=>'${m['state_code']}').toSet();
      final dropdownValue=codes.contains(selectedState)?selectedState:null;
      if(snapshot.connectionState==ConnectionState.waiting&&markets.isEmpty)return const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2);
      if(snapshot.hasError)return Text('State catalog could not load: ${snapshot.error}',style:const TextStyle(color:AppTheme.amber,fontSize:9));
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        DropdownButtonFormField<String>(value:dropdownValue,dropdownColor:AppTheme.panelSoft,isExpanded:true,decoration:const InputDecoration(labelText:'State to build / inspect',border:OutlineInputBorder()),items:markets.map((m)=>DropdownMenuItem(value:'${m['state_code']}',child:Text('${m['state_name']} (${m['state_code']}) • ${m['data_status']}',overflow:TextOverflow.ellipsis))).toList(),onChanged:busy?null:(v){setState((){selectedState=v;control=null;});if(v!=null)unawaited(loadControl());}),
        const SizedBox(height:8),Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:busy||selectedState==null?null:buildState,icon:const Icon(Icons.rocket_launch_rounded),label:Text(busy?'Working…':'Build / resume ${selectedState??''}'))),
        const SizedBox(height:5),Text(selectedState==null?'Choose a state. Active builds above appear automatically from the expansion engine.':'Selected ${selectedState!}. If it is already building, BridgePoint resumes the existing run instead of creating a duplicate.',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
      ]);
    }),
"""
if body.count(old_market)!=1:
    raise SystemExit(f'v276 state selector anchor {body.count(old_market)}')
body=body.replace(old_market,new_market,1)

body += "\nconst String _bridgePointOwnerExpansionActiveBuildsV276='bridgepoint-v276-owner-expansion-active-builds | active build source of truth | responsive expansion controls | automatic state UI';\n"
path.write_text(body,encoding='utf-8')
print('Applied owner expansion active-build synchronization v276.')
runpy.run_path('tool/apply_owner_investor_cockpit_v277.py', run_name='__main__')
runpy.run_path('tool/apply_immersive_motion_background_v278.py', run_name='__main__')
runpy.run_path('tool/apply_weather_aware_community_3d_v279.py', run_name='__main__')
