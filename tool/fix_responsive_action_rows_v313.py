from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v313-responsive-action-rows'
if marker in body:
    print('v313 responsive action rows already applied.')
    raise SystemExit(0)

replacements=[
("""Row(children:[TextButton.icon(onPressed:saving?null:reset,icon:const Icon(Icons.restart_alt_rounded),label:const Text('Reset defaults')),const Spacer(),OutlinedButton(onPressed:saving?null:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),const SizedBox(width:7),FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save_outlined),label:Text(saving?'Saving…':'Save layout'))]),""",
 """Wrap(alignment:WrapAlignment.end,spacing:7,runSpacing:7,crossAxisAlignment:WrapCrossAlignment.center,children:[TextButton.icon(onPressed:saving?null:reset,icon:const Icon(Icons.restart_alt_rounded),label:const Text('Reset defaults')),OutlinedButton(onPressed:saving?null:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save_outlined),label:Text(saving?'Saving…':'Save layout'))]),"""),
("""Row(children:[FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save preferences')),const SizedBox(width:8),TextButton(onPressed:()async{await _callRpc('bridgepoint_mark_notifications_read_v74',{'p_notification_id':null});if(mounted)setState(()=>request=_load());},child:const Text('Mark all read'))]),""",
 """Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save preferences')),TextButton(onPressed:()async{await _callRpc('bridgepoint_mark_notifications_read_v74',{'p_notification_id':null});if(mounted)setState(()=>request=_load());},child:const Text('Mark all read'))]),"""),
("""Row(children:[FilledButton.icon(onPressed:loading?null:_apply,icon:const Icon(Icons.filter_alt_rounded,size:17),label:const Text('Apply filters')),const SizedBox(width:8),OutlinedButton.icon(onPressed:loading?null:_clear,icon:const Icon(Icons.clear_rounded,size:17),label:const Text('Clear')),const Spacer(),const Text('State access is enforced server-side by BridgePoint entitlements.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5))]),""",
 """Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[FilledButton.icon(onPressed:loading?null:_apply,icon:const Icon(Icons.filter_alt_rounded,size:17),label:const Text('Apply filters')),OutlinedButton.icon(onPressed:loading?null:_clear,icon:const Icon(Icons.clear_rounded,size:17),label:const Text('Clear')),const Text('State access is enforced server-side by BridgePoint entitlements.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5))]),"""),
("""return Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[Expanded(child:_OwnerStatusRow(label,live?'CONNECTED':'NEEDS CONNECTION',live?AppTheme.green:AppTheme.amber)),const SizedBox(width:6),TextButton.icon(onPressed:busy?null:()=>configureProvider(p),icon:const Icon(Icons.settings_outlined,size:15),label:const Text('Configure')),const SizedBox(width:4),FilledButton.tonalIcon(onPressed:busy?null:()=>connectProvider(p),icon:Icon(live?Icons.sync_rounded:Icons.link_rounded,size:15),label:Text(live?'Reconnect':'Connect'))]));""",
 """return Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(vertical:6),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_OwnerStatusRow(label,live?'CONNECTED':'NEEDS CONNECTION',live?AppTheme.green:AppTheme.amber),const SizedBox(height:6),Wrap(spacing:6,runSpacing:6,alignment:WrapAlignment.end,children:[TextButton.icon(onPressed:busy?null:()=>configureProvider(p),icon:const Icon(Icons.settings_outlined,size:15),label:const Text('Configure')),FilledButton.tonalIcon(onPressed:busy?null:()=>connectProvider(p),icon:Icon(live?Icons.sync_rounded:Icons.link_rounded,size:15),label:Text(live?'Reconnect':'Connect'))])]));""")
]

for old,new in replacements:
    count=body.count(old)
    if count!=1:
        raise SystemExit(f'v313 responsive action row anchor count {count}: {old[:100]}')
    body=body.replace(old,new,1)

body += "\nconst String _bridgePointResponsiveActionRowsV313='bridgepoint-v313-responsive-action-rows | dashboard actions wrap | preferences actions wrap | property filters wrap | social provider controls stack and wrap';\n"
path.write_text(body,encoding='utf-8')
print('Applied v313 responsive action-row audit fixes.')
