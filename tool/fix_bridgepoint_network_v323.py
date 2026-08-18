from pathlib import Path
import runpy

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v323-network-ui-repair'
if marker in body:
    print('BridgePoint Network v323 repair already applied.')
    runpy.run_path('tool/apply_bridgepoint_network_safety_controls_v323.py',run_name='__main__')
    runpy.run_path('tool/apply_bridgepoint_network_owner_moderation_v323.py',run_name='__main__')
    runpy.run_path('tool/audit_bridgepoint_network_v323.py',run_name='__main__')
    raise SystemExit(0)
if 'bridgepoint-v323-network-ui' not in body:
    raise SystemExit('v323 Network UI must run before repair')

body=body.replace("withOpacity(mine?.12:.82)","withOpacity(mine ? .12 : .82)")
body=body.replace("withOpacity(mine?.18:.06)","withOpacity(mine ? .18 : .06)")

old="""    }catch(e){if(mounted)_showInfoDialog(context,'Could not publish','$e');}finally{if(mounted)setState(()=>busy=false);} 
"""
new="""    }catch(e){
      if(preparedPostId!=null){try{await _callRpc('bridgepoint_network_delete_own_post_v323',{'p_post_id':preparedPostId});}catch(_){}}
      if(mounted)_showInfoDialog(context,'Could not publish','$e');
    }finally{if(mounted)setState(()=>busy=false);} 
"""
if old in body:
    body=body.replace(old,new,1)
else:
    compact="}catch(e){if(mounted)_showInfoDialog(context,'Could not publish','$e');}finally{if(mounted)setState(()=>busy=false);}"
    if compact in body:
        body=body.replace(compact,"}catch(e){if(preparedPostId!=null){try{await _callRpc('bridgepoint_network_delete_own_post_v323',{'p_post_id':preparedPostId});}catch(_){}}if(mounted)_showInfoDialog(context,'Could not publish','$e');}finally{if(mounted)setState(()=>busy=false);}",1)
    elif 'bridgepoint_network_delete_own_post_v323' not in body:
        raise SystemExit('v323 media cleanup anchor missing')

body+='\n// bridgepoint-v323-network-ui-repair\n'
path.write_text(body,encoding='utf-8')
print('Repaired v323 message bubbles and failed-media draft cleanup.')
runpy.run_path('tool/apply_bridgepoint_network_safety_controls_v323.py',run_name='__main__')
runpy.run_path('tool/apply_bridgepoint_network_owner_moderation_v323.py',run_name='__main__')
runpy.run_path('tool/audit_bridgepoint_network_v323.py',run_name='__main__')
