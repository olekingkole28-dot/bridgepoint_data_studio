from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v323-network-safety-controls'
if marker in body:
    print('BridgePoint Network v323 safety controls already applied.')
    raise SystemExit(0)
if 'bridgepoint-v323-network-ui-repair' not in body:
    raise SystemExit('v323 Network repair must run before safety controls')

# Use the shared report dialog for posts instead of a fixed one-click reason.
old_post="onPressed:()=>_callRpc('bridgepoint_network_report_v323',{'p_entity_type':'POST','p_entity_id':'${p['post_id']}','p_reason':'Member report','p_detail':null}).then((_)=>mounted?_showInfoDialog(context,'Reported','Thanks. This post was sent to BridgePoint moderation.'):null)"
new_post="onPressed:()=>_networkReportEntityV323(context,'POST','${p['post_id']}')"
if old_post in body:
    body=body.replace(old_post,new_post,1)
elif "_networkReportEntityV323(context,'POST'" not in body:
    raise SystemExit('v323 post report anchor missing')

# Add visible profile safety actions next to each member result.
old_people="trailing:p['is_friend']==true?OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(_)=>_BridgePointNetworkChatV323(user:p)),icon:const Icon(Icons.message_outlined,size:14),label:const Text('Message')):p['request_sent']==true?const Text('REQUESTED',style:TextStyle(color:AppTheme.textMuted,fontSize:7,fontWeight:FontWeight.w900)):FilledButton.icon(onPressed:()=>_friend('${p['user_id']}'),icon:const Icon(Icons.person_add_alt_1_rounded,size:14),label:const Text('Add'))"
new_people="trailing:Wrap(spacing:3,crossAxisAlignment:WrapCrossAlignment.center,children:[if(p['is_friend']==true)OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(_)=>_BridgePointNetworkChatV323(user:p)),icon:const Icon(Icons.message_outlined,size:14),label:const Text('Message')),if(p['is_friend']!=true&&p['request_sent']==true)const Text('REQUESTED',style:TextStyle(color:AppTheme.textMuted,fontSize:7,fontWeight:FontWeight.w900)),if(p['is_friend']!=true&&p['request_sent']!=true)FilledButton.icon(onPressed:()=>_friend('${p['user_id']}'),icon:const Icon(Icons.person_add_alt_1_rounded,size:14),label:const Text('Add')),PopupMenuButton<String>(tooltip:'Member safety',onSelected:(a){if(a=='REPORT')_networkReportEntityV323(context,'PROFILE','${p['user_id']}');if(a=='BLOCK')_networkBlockMemberV323(context,'${p['user_id']}').then((_)=>_refresh());},itemBuilder:(_)=>const [PopupMenuItem(value:'REPORT',child:Text('Report profile')),PopupMenuItem(value:'BLOCK',child:Text('Block member'))],icon:const Icon(Icons.shield_outlined,size:17))])"
if old_people in body:
    body=body.replace(old_people,new_people,1)
elif "tooltip:'Member safety'" not in body:
    raise SystemExit('v323 people safety anchor missing')

# Add report control to each visible comment.
old_comment="trailing:Text(_bpDateTime(c['created_at']),style:const TextStyle(fontSize:7,color:AppTheme.textMuted))"
new_comment="trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(_bpDateTime(c['created_at']),style:const TextStyle(fontSize:7,color:AppTheme.textMuted)),IconButton(tooltip:'Report comment',onPressed:()=>_networkReportEntityV323(context,'COMMENT','${c['comment_id']}'),icon:const Icon(Icons.flag_outlined,size:14))])"
if old_comment in body:
    body=body.replace(old_comment,new_comment,1)
elif "tooltip:'Report comment'" not in body:
    raise SystemExit('v323 comment report anchor missing')

# Add profile report/block actions to the private chat header.
old_chat_title="Expanded(child:Text('${widget.user['display_name']??'BridgePoint friend'}',style:const TextStyle(fontWeight:FontWeight.w900))),IconButton(onPressed:()=>setState(_load),icon:const Icon(Icons.refresh_rounded))"
new_chat_title="Expanded(child:Text('${widget.user['display_name']??'BridgePoint friend'}',style:const TextStyle(fontWeight:FontWeight.w900))),PopupMenuButton<String>(tooltip:'Conversation safety',onSelected:(a){if(a=='REPORT')_networkReportEntityV323(context,'PROFILE',uid);if(a=='BLOCK')_networkBlockMemberV323(context,uid).then((blocked){if(blocked&&mounted)Navigator.pop(context);});},itemBuilder:(_)=>const [PopupMenuItem(value:'REPORT',child:Text('Report profile')),PopupMenuItem(value:'BLOCK',child:Text('Block member'))],icon:const Icon(Icons.shield_outlined,size:18)),IconButton(onPressed:()=>setState(_load),icon:const Icon(Icons.refresh_rounded))"
if old_chat_title in body:
    body=body.replace(old_chat_title,new_chat_title,1)
elif "tooltip:'Conversation safety'" not in body:
    raise SystemExit('v323 chat safety anchor missing')

# Add report control to each incoming approved message. Blocked messages never enter this RPC result.
old_message_time="const SizedBox(height:3),Text(_bpDateTime(m['created_at']),style:const TextStyle(fontSize:6.8,color:AppTheme.textMuted))"
new_message_time="const SizedBox(height:3),Row(mainAxisSize:MainAxisSize.min,children:[Text(_bpDateTime(m['created_at']),style:const TextStyle(fontSize:6.8,color:AppTheme.textMuted)),if(!mine)IconButton(tooltip:'Report message',visualDensity:VisualDensity.compact,padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:28,minHeight:24),onPressed:()=>_networkReportEntityV323(context,'MESSAGE','${m['message_id']}'),icon:const Icon(Icons.flag_outlined,size:12))])"
if old_message_time in body:
    body=body.replace(old_message_time,new_message_time,1)
elif "tooltip:'Report message'" not in body:
    raise SystemExit('v323 message report anchor missing')

body += r'''

Future<void> _networkReportEntityV323(BuildContext context,String entityType,String entityId)async{
  if(entityId.trim().isEmpty)return;
  final detail=TextEditingController();
  String reason='Safety concern';
  final submit=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
    backgroundColor:AppTheme.panel,
    title:const Row(children:[Icon(Icons.flag_outlined,color:AppTheme.amber),SizedBox(width:8),Text('Report to BridgePoint')]),
    content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Reports go to the private BridgePoint owner moderation queue.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.8,height:1.4)),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(value:reason,decoration:const InputDecoration(labelText:'Reason',border:OutlineInputBorder()),items:const ['Safety concern','Spam or solicitation','Harassment','False or misleading','Other'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setLocal(()=>reason=v??reason)),
      const SizedBox(height:10),
      TextField(controller:detail,maxLength:500,maxLines:3,decoration:const InputDecoration(labelText:'Details (optional)',border:OutlineInputBorder())),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton.icon(onPressed:()=>Navigator.pop(d,true),icon:const Icon(Icons.flag_rounded),label:const Text('Submit report'))],
  )));
  final detailText=detail.text.trim();
  detail.dispose();
  if(submit!=true)return;
  try{
    final result=await _callRpc('bridgepoint_network_report_v323',{'p_entity_type':entityType,'p_entity_id':entityId,'p_reason':reason,'p_detail':detailText.isEmpty?null:detailText});
    _showInfoDialog(context,'Reported','${result['message']??'Thanks. This is now in BridgePoint moderation.'}');
  }catch(e){_showInfoDialog(context,'Report could not be submitted','$e');}
}

Future<bool> _networkBlockMemberV323(BuildContext context,String userId)async{
  if(userId.trim().isEmpty)return false;
  final confirm=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
    backgroundColor:AppTheme.panel,
    title:const Row(children:[Icon(Icons.block_rounded,color:Colors.redAccent),SizedBox(width:8),Text('Block this member?')]),
    content:const Text('Blocking removes the connection path between you and this member and prevents Network messaging between your accounts. You can only unblock through a future account-management control.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.2,height:1.5)),
    actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton.icon(onPressed:()=>Navigator.pop(d,true),icon:const Icon(Icons.block_rounded),label:const Text('Block member'))],
  ));
  if(confirm!=true)return false;
  try{
    await _callRpc('bridgepoint_network_block_user_v323',{'p_user_id':userId,'p_block':true});
    _showInfoDialog(context,'Member blocked','This member can no longer connect with or message you in BridgePoint Network.');
    return true;
  }catch(e){_showInfoDialog(context,'Block failed','$e');return false;}
}

// bridgepoint-v323-network-safety-controls
'''

path.write_text(body,encoding='utf-8')
print('Applied BridgePoint Network v323 report, message-report, profile-report and block controls.')
