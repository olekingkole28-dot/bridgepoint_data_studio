from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v313-expansion-dual-source-resilience'
if marker in body:
    print('v313 expansion dual-source resilience already applied.')
    raise SystemExit(0)

old="""Future<Map<String,dynamic>> _loadActiveBuilds()async{
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
"""
new="""Future<Map<String,dynamic>> _loadActiveBuilds()async{
    Map<String,dynamic> data=<String,dynamic>{};Object? primaryError;
    try{data=await _callRpc('bridgepoint_expansion_active_builds_v228',const {});}catch(e){primaryError=e;}
    var builds=rows(data['builds']);
    if(builds.isEmpty){
      try{
        final owner=await _callRpc('bridgepoint_owner_command_snapshot_v254',const {});
        final buildingMarkets=rows(owner['expansion_markets']).where((m)=>'${m['data_status']}'.toUpperCase()=='BUILDING').toList();
        final fallback=<Map<String,dynamic>>[];
        for(final market in buildingMarkets){
          final code='${market['state_code']}';if(code.isEmpty)continue;
          Map<String,dynamic> control=<String,dynamic>{};Map<String,dynamic> progress=<String,dynamic>{};
          try{control=await _callRpc('bridgepoint_expansion_control_center_v90',{'p_run_id':null,'p_state':code});}catch(_){}
          final run=control['run'] is Map?Map<String,dynamic>.from(control['run'] as Map):<String,dynamic>{};
          final runId=run['run_id'];
          if(runId!=null){try{progress=await _callRpc('bridgepoint_expansion_progress_v212',{'p_run_id':runId});}catch(_){}}
          final steps=rows(control['steps']);
          final done=steps.where((s)=>['SUCCEEDED','SKIPPED'].contains('${s['step_status']}')).length;
          final safeProgress=progress.isNotEmpty?progress:<String,dynamic>{
            'found':run.isNotEmpty,'activity_state':run.isNotEmpty?'ACTIVE':'BUILDING',
            'overall_progress_pct':steps.isEmpty?0.0:(done*100/steps.length),
            'current_phase':run['current_phase']??'BUILDING',
          };
          fallback.add(<String,dynamic>{
            ...market,
            ...run,
            'state_code':code,'state_name':market['state_name']??code,'data_status':'BUILDING',
            'run_status':run['run_status']??'BUILDING','current_phase':run['current_phase']??safeProgress['current_phase']??'BUILDING',
            'canonical_property_count':market['canonical_property_count']??0,
            'progress':safeProgress,'steps':steps,'pending_approvals':rows(control['pending_approvals']),
            'step_done':done,'step_total':steps.length,'source':'OWNER_MARKET_FALLBACK',
          });
        }
        if(fallback.isNotEmpty){
          data=<String,dynamic>{'complete':true,'generated_at':owner['generated_at'],'build_count':fallback.length,'builds':fallback,'source':'DUAL_SOURCE_OWNER_FALLBACK',if(primaryError!=null)'primary_error':'$primaryError'};
          builds=fallback;
        }else if(primaryError!=null){throw Exception('Both active expansion sources were unavailable. Primary: $primaryError');}
      }catch(e){if(primaryError!=null)throw Exception('Active expansion status could not be verified. Primary: $primaryError • Fallback: $e');rethrow;}
    }
    if(builds.isNotEmpty){
      final codes=builds.map((b)=>'${b['state_code']}').where((x)=>x.isNotEmpty).toSet();
      if(selectedState==null||!codes.contains(selectedState)){
        selectedState='${builds.first['state_code']}';
        WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&selectedState!=null)unawaited(loadControl());});
      }
    }
    return data;
  }
"""
if body.count(old)!=1:
    raise SystemExit(f'v313 active build loader anchor count {body.count(old)}')
body=body.replace(old,new,1)

old_empty="""No state builds are currently in progress.',style:TextStyle(color:AppTheme.textMuted,fontSize:9))else ...builds.map"""
new_empty="""No active state builds are reported by either expansion source right now.',style:TextStyle(color:AppTheme.textMuted,fontSize:9))else ...builds.map"""
if body.count(old_empty)!=1:
    raise SystemExit(f'v313 expansion empty copy anchor count {body.count(old_empty)}')
body=body.replace(old_empty,new_empty,1)

body += "\nconst String _bridgePointExpansionDualSourceResilienceV313='bridgepoint-v313-expansion-dual-source-resilience | active-build RPC first | owner market BUILDING fallback | automatic state cards';\n"
path.write_text(body,encoding='utf-8')
print('Applied v313 dual-source expansion resilience.')
