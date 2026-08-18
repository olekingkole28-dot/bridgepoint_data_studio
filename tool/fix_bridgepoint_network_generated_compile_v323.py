from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v323-network-generated-compile-repair'
if marker in body:
    print('BridgePoint Network v323 generated compile repair already applied.')
    raise SystemExit(0)
if 'bridgepoint-v323-network-safety-controls' not in body:
    raise SystemExit('v323 safety controls must run before generated compile repair')

# file_picker 11 uses static methods on FilePicker; FilePicker.platform was removed.
body=body.replace('FilePicker.platform.pickFiles(', 'FilePicker.pickFiles(')

people_start=body.find('  Widget _people()=>')
people_end=body.find('  Widget _messages()=>',people_start)
if people_start<0 or people_end<0:
    raise SystemExit('v323 people method anchors missing')
people=r'''  Widget _people()=>Column(children:[
    Row(children:[
      Expanded(child:TextField(
        controller:peopleController,
        onSubmitted:(_)=>_searchPeople(),
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Find BridgePoint members or companies',border:OutlineInputBorder()),
      )),
      const SizedBox(width:7),
      IconButton(onPressed:_searchPeople,icon:const Icon(Icons.search_rounded)),
    ]),
    const SizedBox(height:9),
    FutureBuilder<Map<String,dynamic>>(
      future:friendsRequest,
      builder:(context,s){
        final incoming=_bpRows(s.data?['incoming_requests']);
        final friends=_bpRows(s.data?['friends']);
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(incoming.isNotEmpty)...[
            const Align(alignment:Alignment.centerLeft,child:Text('FRIEND REQUESTS',style:TextStyle(color:AppTheme.amber,fontSize:8,fontWeight:FontWeight.w900))),
            const SizedBox(height:5),
            ...incoming.map((r)=>ListTile(
              dense:true,
              leading:const CircleAvatar(child:Icon(Icons.person_outline)),
              title:Text('${r['display_name']}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800)),
              subtitle:Text('@${r['handle']}',style:const TextStyle(fontSize:8,color:AppTheme.textMuted)),
              trailing:Wrap(spacing:4,children:[
                IconButton(tooltip:'Accept',onPressed:()=>_respond('${r['request_id']}','ACCEPT'),icon:const Icon(Icons.check_circle_outline,color:AppTheme.green)),
                IconButton(tooltip:'Decline',onPressed:()=>_respond('${r['request_id']}','DECLINE'),icon:const Icon(Icons.close_rounded)),
              ]),
            )),
            const Divider(),
          ],
          if(friends.isNotEmpty)Align(
            alignment:Alignment.centerLeft,
            child:Text('${friends.length} FRIEND${friends.length==1?'':'S'}',style:const TextStyle(color:AppTheme.green,fontSize:8,fontWeight:FontWeight.w900)),
          ),
        ]);
      },
    ),
    FutureBuilder<Map<String,dynamic>>(
      future:peopleRequest,
      builder:(context,s){
        final people=_bpRows(s.data?['people']);
        if(s.connectionState==ConnectionState.waiting&&!s.hasData){
          return const LinearProgressIndicator(color:AppTheme.cyan);
        }
        return Column(children:people.map((p)=>ListTile(
          dense:true,
          leading:const CircleAvatar(child:Icon(Icons.person_outline_rounded,size:16)),
          title:Text('${p['display_name']}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w900)),
          subtitle:Text('@${p['handle']}${p['company_name']!=null?' • ${p['company_name']}':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),
          trailing:Wrap(spacing:3,crossAxisAlignment:WrapCrossAlignment.center,children:[
            if(p['is_friend']==true)OutlinedButton.icon(
              onPressed:()=>showDialog<void>(context:context,builder:(_)=>_BridgePointNetworkChatV323(user:p)),
              icon:const Icon(Icons.message_outlined,size:14),
              label:const Text('Message'),
            ),
            if(p['is_friend']!=true&&p['request_sent']==true)const Text('REQUESTED',style:TextStyle(color:AppTheme.textMuted,fontSize:7,fontWeight:FontWeight.w900)),
            if(p['is_friend']!=true&&p['request_sent']!=true)FilledButton.icon(
              onPressed:()=>_friend('${p['user_id']}'),
              icon:const Icon(Icons.person_add_alt_1_rounded,size:14),
              label:const Text('Add'),
            ),
            PopupMenuButton<String>(
              tooltip:'Member safety',
              onSelected:(a){
                if(a=='REPORT')_networkReportEntityV323(context,'PROFILE','${p['user_id']}');
                if(a=='BLOCK')_networkBlockMemberV323(context,'${p['user_id']}').then((_)=>_refresh());
              },
              itemBuilder:(_)=>const [
                PopupMenuItem(value:'REPORT',child:Text('Report profile')),
                PopupMenuItem(value:'BLOCK',child:Text('Block member')),
              ],
              icon:const Icon(Icons.shield_outlined,size:17),
            ),
          ]),
        )).toList());
      },
    ),
  ]);
'''
body=body[:people_start]+people+body[people_end:]

chat_start=body.find('class _BridgePointNetworkChatV323State extends State<_BridgePointNetworkChatV323>{')
chat_end=body.find('class _CommunityLegacyMapAndChatV212 extends StatefulWidget',chat_start)
if chat_start<0 or chat_end<0:
    raise SystemExit('v323 chat class anchors missing')
chat=r'''class _BridgePointNetworkChatV323State extends State<_BridgePointNetworkChatV323>{
  late Future<Map<String,dynamic>> request;
  final input=TextEditingController();
  Timer? timer;
  bool busy=false;
  String get uid=>'${widget.user['user_id']??widget.user['other_id']??''}';

  @override void initState(){
    super.initState();
    _load();
    timer=Timer.periodic(const Duration(seconds:8),(_){if(mounted)setState(_load);});
  }
  void _load()=>request=_callRpc('bridgepoint_network_messages_v323',{'p_user_id':uid,'p_limit':100,'p_before':null});
  @override void dispose(){timer?.cancel();input.dispose();super.dispose();}

  Future<void> send()async{
    final text=input.text.trim();
    if(text.isEmpty||busy)return;
    setState(()=>busy=true);
    try{
      final r=await _callRpc('bridgepoint_network_send_message_v323',{'p_user_id':uid,'p_body':text});
      if(r['blocked']==true){
        if(mounted)_showInfoDialog(context,'Message not delivered','${r['message']}');
      }else{
        input.clear();
        if(mounted)setState(_load);
      }
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  @override Widget build(BuildContext context)=>AlertDialog(
    backgroundColor:AppTheme.panel,
    title:Row(children:[
      const Icon(Icons.forum_rounded,color:AppTheme.cyan),
      const SizedBox(width:8),
      Expanded(child:Text('${widget.user['display_name']??'BridgePoint friend'}',style:const TextStyle(fontWeight:FontWeight.w900))),
      PopupMenuButton<String>(
        tooltip:'Conversation safety',
        onSelected:(a){
          if(a=='REPORT')_networkReportEntityV323(context,'PROFILE',uid);
          if(a=='BLOCK'){
            _networkBlockMemberV323(context,uid).then((blocked){
              if(blocked&&mounted)Navigator.pop(context);
            });
          }
        },
        itemBuilder:(_)=>const [
          PopupMenuItem(value:'REPORT',child:Text('Report profile')),
          PopupMenuItem(value:'BLOCK',child:Text('Block member')),
        ],
        icon:const Icon(Icons.shield_outlined,size:18),
      ),
      IconButton(onPressed:()=>setState(_load),icon:const Icon(Icons.refresh_rounded)),
    ]),
    content:SizedBox(
      width:700,
      height:560,
      child:Column(children:[
        const Text('Private between accepted BridgePoint friends. Safety filtering still applies before delivery.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2)),
        const SizedBox(height:8),
        Expanded(child:FutureBuilder<Map<String,dynamic>>(
          future:request,
          builder:(context,s){
            final rows=_bpRows(s.data?['messages']);
            if(s.connectionState==ConnectionState.waiting&&!s.hasData){
              return const Center(child:CircularProgressIndicator(color:AppTheme.cyan));
            }
            final me=Supabase.instance.client.auth.currentUser?.id;
            return ListView(children:rows.map((m){
              final mine='${m['sender_id']}'==me;
              return Align(
                alignment:mine?Alignment.centerRight:Alignment.centerLeft,
                child:Container(
                  constraints:const BoxConstraints(maxWidth:500),
                  margin:const EdgeInsets.only(bottom:6),
                  padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),
                  decoration:BoxDecoration(
                    color:(mine?AppTheme.cyan:AppTheme.panelSoft).withOpacity(mine?.12:.82),
                    borderRadius:BorderRadius.circular(12),
                    border:Border.all(color:(mine?AppTheme.cyan:Colors.white).withOpacity(mine?.18:.06)),
                  ),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text('${m['body']}',style:const TextStyle(fontSize:9.5,height:1.35)),
                    const SizedBox(height:3),
                    Row(mainAxisSize:MainAxisSize.min,children:[
                      Text(_bpDateTime(m['created_at']),style:const TextStyle(fontSize:6.8,color:AppTheme.textMuted)),
                      if(!mine)IconButton(
                        tooltip:'Report message',
                        visualDensity:VisualDensity.compact,
                        padding:EdgeInsets.zero,
                        constraints:const BoxConstraints(minWidth:28,minHeight:24),
                        onPressed:()=>_networkReportEntityV323(context,'MESSAGE','${m['message_id']}'),
                        icon:const Icon(Icons.flag_outlined,size:12),
                      ),
                    ]),
                  ]),
                ),
              );
            }).toList());
          },
        )),
        Row(children:[
          Expanded(child:TextField(
            controller:input,
            maxLength:1200,
            onSubmitted:(_)=>send(),
            decoration:const InputDecoration(hintText:'Message your BridgePoint friend…',border:OutlineInputBorder(),counterText:''),
          )),
          const SizedBox(width:7),
          IconButton(onPressed:busy?null:send,icon:const Icon(Icons.send_rounded,color:AppTheme.cyan)),
        ]),
      ]),
    ),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))],
  );
}

'''
body=body[:chat_start]+chat+body[chat_end:]

# Repair the intentionally compact color expressions after replacing the full chat class.
body=body.replace('withOpacity(mine?.12:.82)','withOpacity(mine ? .12 : .82)')
body=body.replace('withOpacity(mine?.18:.06)','withOpacity(mine ? .18 : .06)')

body+='\n// bridgepoint-v323-network-generated-compile-repair\n'
path.write_text(body,encoding='utf-8')
print('Repaired v323 static FilePicker API and rebuilt People/Chat widgets with balanced Flutter syntax.')
