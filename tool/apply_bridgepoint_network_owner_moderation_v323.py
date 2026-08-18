from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v323-owner-moderation-ui'
if marker in body:
    print('BridgePoint Network v323 owner moderation UI already applied.')
    raise SystemExit(0)
if 'bridgepoint-v323-network-ui-repair' not in body:
    raise SystemExit('v323 Network repair must run before owner moderation UI')

owner_anchor="const Text('bridgepoint-v219-owner-outreach',style:TextStyle(fontSize:0,color:Colors.transparent)),"
owner_insert=owner_anchor+"\n            const Divider(height:26),\n            const _BridgePointNetworkModerationV323(),"
if owner_anchor in body:
    body=body.replace(owner_anchor,owner_insert,1)
elif 'const _BridgePointNetworkModerationV323()' not in body:
    raise SystemExit('v323 owner moderation insertion anchor missing')

body += r'''

class _BridgePointNetworkModerationV323 extends StatefulWidget{
  const _BridgePointNetworkModerationV323();
  @override State<_BridgePointNetworkModerationV323> createState()=>_BridgePointNetworkModerationV323State();
}

class _BridgePointNetworkModerationV323State extends State<_BridgePointNetworkModerationV323>{
  late Future<Map<String,dynamic>> request;
  bool busy=false;
  @override void initState(){super.initState();_load();}
  void _load()=>request=_callRpc('bridgepoint_owner_network_moderation_v323',{'p_limit':100});
  void _refresh(){if(mounted)setState(_load);}

  IconData _actionIcon(String action){
    switch(action){
      case 'APPROVE':return Icons.verified_rounded;
      case 'BLOCK':return Icons.block_rounded;
      default:return Icons.done_rounded;
    }
  }

  Color _actionColor(String action){
    switch(action){
      case 'APPROVE':return AppTheme.green;
      case 'BLOCK':return Colors.redAccent;
      default:return AppTheme.textMuted;
    }
  }

  Future<void> _openMedia(String storagePath)async{
    try{
      final url=await Supabase.instance.client.storage.from('bridgepoint-community-media').createSignedUrl(storagePath,600);
      await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication);
    }catch(e){if(mounted)_showInfoDialog(context,'Media could not open','$e');}
  }

  Future<void> _act(Map<String,dynamic> item,String action)async{
    if(busy)return;
    final entityType='${item['moderation_entity_type']??''}'.trim();
    final entityId='${item['moderation_entity_id']??''}'.trim();
    if(entityType.isEmpty||entityId.isEmpty){
      if(mounted)_showInfoDialog(context,'Moderation target missing','Refresh the queue before taking action.');
      return;
    }
    final labels=_bpMap(item['action_labels']);
    final actionLabel='${labels[action]??action}'.trim();
    final note=TextEditingController();
    final confirmed=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      backgroundColor:AppTheme.panel,
      title:Row(children:[Icon(_actionIcon(action),color:_actionColor(action)),const SizedBox(width:8),Expanded(child:Text(actionLabel.isEmpty?action:actionLabel))]),
      content:SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('$entityType • ${item['current_state']??item['status']??'UNKNOWN'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w800)),
        const SizedBox(height:10),
        if(action=='DISMISS')const Text('Dismiss resolves the report or safety event only. It does not change the content state.',style:TextStyle(color:AppTheme.cyan,fontSize:9,height:1.45)),
        if(action=='BLOCK')const Text('Block changes the target to a blocked state where the backend contract allows it.',style:TextStyle(color:Colors.redAccent,fontSize:9,height:1.45)),
        if(action=='APPROVE')const Text('Approve is available only when the backend queue says this target may be approved or kept visible.',style:TextStyle(color:AppTheme.green,fontSize:9,height:1.45)),
        const SizedBox(height:12),
        TextField(controller:note,maxLength:500,maxLines:3,decoration:const InputDecoration(labelText:'Owner note (optional)',border:OutlineInputBorder())),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton.icon(onPressed:()=>Navigator.pop(d,true),icon:Icon(_actionIcon(action)),label:const Text('Confirm'))],
    ));
    final noteText=note.text.trim();
    note.dispose();
    if(confirmed!=true)return;
    if(mounted)setState(()=>busy=true);
    try{
      final result=await _callRpc('bridgepoint_owner_network_moderate_v323',{'p_entity_type':entityType,'p_entity_id':entityId,'p_action':action,'p_note':noteText.isEmpty?null:noteText});
      if(mounted){
        _showInfoDialog(context,'Network moderation','${result['message']??'Moderation action applied.'}');
        setState(_load);
      }
    }catch(e){if(mounted)_showInfoDialog(context,'Moderation action failed','$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Widget _stat(String label,dynamic value,Color accent)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
    decoration:BoxDecoration(color:accent.withOpacity(.07),borderRadius:BorderRadius.circular(10),border:Border.all(color:accent.withOpacity(.16))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$value',style:TextStyle(color:accent,fontSize:15,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5,fontWeight:FontWeight.w800))]),
  );

  Widget _item(Map<String,dynamic> item){
    final raw=item['allowed_actions'];
    final actions=raw is List?raw.map((e)=>'$e').toList():<String>[];
    final labels=_bpMap(item['action_labels']);
    final preview='${item['content_preview']??''}'.trim();
    final excerpt='${item['excerpt']??''}'.trim();
    final mediaPath='${item['media_path']??''}'.trim();
    final type='${item['moderation_entity_type']??item['entity_type']??'ITEM'}';
    final state='${item['current_state']??item['status']??''}';
    return Container(
      margin:const EdgeInsets.only(top:9),padding:const EdgeInsets.all(11),
      decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.58),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.055))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(item['item_kind']=='REPORT'?Icons.flag_outlined:item['item_kind']=='MEDIA'?Icons.photo_library_outlined:Icons.shield_outlined,size:16,color:item['item_kind']=='REPORT'?AppTheme.amber:AppTheme.cyan),const SizedBox(width:7),Expanded(child:Text('${item['label']??item['item_kind']??'Network moderation'}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w900))),Text('$type • $state',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.3,fontWeight:FontWeight.w800))]),
        if(preview.isNotEmpty)...[const SizedBox(height:7),Text(preview,style:const TextStyle(fontSize:9,height:1.4))],
        if(excerpt.isNotEmpty&&excerpt!=preview)...[const SizedBox(height:5),Text(excerpt,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.35))],
        const SizedBox(height:5),Text(_bpDateTime(item['created_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.2)),
        const SizedBox(height:8),
        Wrap(spacing:6,runSpacing:6,children:[
          if(mediaPath.isNotEmpty)OutlinedButton.icon(onPressed:busy?null:()=>_openMedia(mediaPath),icon:const Icon(Icons.open_in_new_rounded,size:14),label:const Text('Open media')),
          for(final action in actions)TextButton.icon(
            onPressed:busy?null:()=>_act(item,action),
            icon:Icon(_actionIcon(action),size:14,color:_actionColor(action)),
            label:Text('${labels[action]??action}',style:TextStyle(fontSize:8.2,fontWeight:FontWeight.w900,color:_actionColor(action))),
          ),
        ]),
      ]),
    );
  }

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,
    builder:(context,s){
      if(s.connectionState==ConnectionState.waiting&&!s.hasData)return const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Network Moderation',style:TextStyle(fontWeight:FontWeight.w900)),SizedBox(height:8),LinearProgressIndicator(color:AppTheme.cyan)]);
      if(s.hasError)return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Network Moderation',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('Owner moderation queue could not load: ${s.error}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),const SizedBox(height:7),OutlinedButton.icon(onPressed:_refresh,icon:const Icon(Icons.refresh_rounded,size:15),label:const Text('Retry'))]);
      final data=_bpMap(s.data);
      final items=_bpRows(data['items']);
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Network Moderation',style:TextStyle(fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Owner-only review queue • reports, quarantined media and blocked safety events',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2))])),IconButton(tooltip:'Refresh Network moderation',onPressed:busy?null:_refresh,icon:const Icon(Icons.refresh_rounded,size:18))]),
        const SizedBox(height:9),
        Wrap(spacing:7,runSpacing:7,children:[
          _stat('OPEN REPORTS',data['open_reports']??0,AppTheme.amber),
          _stat('PENDING MEDIA',data['pending_media']??0,AppTheme.cyan),
          _stat('SAFETY EVENTS',data['open_safety_events']??0,Colors.redAccent),
          _stat('BLOCKED 24H',data['blocked_text_24h']??0,AppTheme.textMuted),
        ]),
        const SizedBox(height:8),
        Text('Queue contract v${data['queue_contract_version']??'?'} • Dismiss never changes content state. Blocked direct messages cannot be restored.',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.8,height:1.4)),
        if(items.isEmpty)const Padding(padding:EdgeInsets.only(top:12),child:Text('No Network moderation items are waiting.',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w800))) else ...items.map(_item),
      ]);
    },
  );
}

// bridgepoint-v323-owner-moderation-ui
'''

path.write_text(body,encoding='utf-8')
print('Applied owner-only BridgePoint Network moderation console v323.')
