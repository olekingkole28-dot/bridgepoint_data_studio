from pathlib import Path

p=Path('lib/main.dart')
text=p.read_text(encoding='utf-8')
old="""    try{await _callRpc('bridgepoint_expansion_approval_v90',{'p_approval_id':id,'p_decision':decision,'p_note':null});await loadControl();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not save decision',e.toString());}
"""
new="""    try{
      await _callRpc('bridgepoint_expansion_approval_v90',{'p_approval_id':id,'p_decision':decision,'p_note':null});
      if(decision=='APPROVED'){
        final run=control?['run'];
        if(run is Map && run['run_id']!=null){
          final result=await Supabase.instance.client.functions.invoke('bridgepoint-expansion-worker-v90',body:{'action':'continue','run_id':run['run_id'],'task_limit':4});
          final payload=_edgeFunctionPayload(result.data);
          if(result.status<200||result.status>=300||payload['complete']!=true){
            throw Exception('${payload['error']??'Approval saved, but expansion could not continue'}');
          }
          if(mounted && payload['control_center'] is Map){
            setState(()=>control=Map<String,dynamic>.from(payload['control_center']));
          }
        }
      }
      await loadControl();
    }
    catch(e){if(mounted)_showInfoDialog(context,'Could not continue expansion',e.toString());}
"""
if old not in text:
    raise SystemExit('owner expansion approve handler missing')
text=text.replace(old,new,1)
if "'action':'continue'" not in text or 'Could not continue expansion' not in text:
    raise SystemExit('expansion continuation markers missing')
p.write_text(text,encoding='utf-8')
print('Made owner expansion approval continue immediately v178')
