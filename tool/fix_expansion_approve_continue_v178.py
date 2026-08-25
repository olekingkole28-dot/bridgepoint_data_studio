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

if old in text:
    text=text.replace(old,new,1)
    if "'action':'continue'" not in text or 'Could not continue expansion' not in text:
        raise SystemExit('expansion continuation markers missing')
    p.write_text(text,encoding='utf-8')
    print('Made legacy owner expansion approval continue immediately v178/v817')
else:
    # The canonical owner surface no longer uses the v90 approval UI. v675 is a
    # direct command/control plane: START_US_ALL / START_WORLD_DISCOVERY /
    # START_JURISDICTION queue expansion work immediately, while server-side
    # readiness gates still prevent unfinished jurisdictions from going live.
    global_control=Path('lib/screens/bridgepoint_owner_global_control.dart')
    if not global_control.exists():
        raise SystemExit('owner expansion approve handler missing and canonical v675 control file absent')
    control=global_control.read_text(encoding='utf-8')
    required=[
        "'bridgepoint_owner_global_command_v675'",
        "'START_US_ALL'",
        "'START_WORLD_DISCOVERY'",
        "'START_JURISDICTION'",
        'These actions queue discovery/build work. They never bypass validation or customer-readiness gates.',
    ]
    missing=[marker for marker in required if marker not in control]
    if missing:
        raise SystemExit(f'legacy v178 handler absent, but v675 supersession is incomplete: {missing}')
    if "import 'screens/bridgepoint_owner_command_center.dart';" not in text or 'BridgePointOwnerCommandCenter' not in text:
        raise SystemExit('v675 global control exists but owner command center is not wired into the app')
    print('Legacy v178 approval continuation superseded by wired Owner Global Control v675/v817; expansion commands already queue work immediately with readiness gates enforced.')
