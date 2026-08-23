from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v602-owner-ai-workers-forgotten-work'

if marker in body:
    print('BridgePoint v602 owner AI visibility already applied.')
    raise SystemExit(0)

owner_anchor='class _OwnerCenterPage extends StatefulWidget{'
if owner_anchor not in body:
    raise SystemExit('v602 owner center anchor missing')

widget=r'''// bridgepoint-v602-owner-ai-workers-forgotten-work
class _OwnerAiVisibilityV602 extends StatefulWidget{
  const _OwnerAiVisibilityV602();
  @override State<_OwnerAiVisibilityV602> createState()=>_OwnerAiVisibilityV602State();
}

class _OwnerAiVisibilityV602State extends State<_OwnerAiVisibilityV602>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_load();}
  Future<Map<String,dynamic>> _load() async=>{
    'ai':await _callRpc('bridgepoint_owner_ai_control_local_v598',const {}),
    'ledger':await _callRpc('bridgepoint_owner_master_completion_v586',const {}),
  };
  void refresh()=>setState(()=>request=_load());
  Map<String,dynamic> _map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  List<Map<String,dynamic>> _rows(dynamic v)=>v is List?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
  Color _statusColor(BuildContext context,String value){
    final s=value.toUpperCase();
    if(s.contains('SUCC')||s.contains('PROVEN')||s.contains('ONLINE')||s.contains('HEALTHY'))return Colors.greenAccent;
    if(s.contains('FAIL')||s.contains('BLOCK')||s.contains('CRITICAL')||s.contains('ERROR'))return Colors.redAccent;
    return Colors.amberAccent;
  }
  Widget _pill(BuildContext context,String value)=>Container(
    margin:const EdgeInsets.only(right:6,bottom:6),padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(999),border:Border.all(color:_statusColor(context,value).withOpacity(.55))),
    child:Text(value,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:_statusColor(context,value))),
  );
  @override Widget build(BuildContext context){
    return FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting)return const Padding(padding:EdgeInsets.symmetric(vertical:12),child:LinearProgressIndicator());
      if(snapshot.hasError)return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('AI workforce / forgotten-work feed unavailable',style:TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:5),Text('${snapshot.error}',style:const TextStyle(fontSize:12)),
        const SizedBox(height:8),OutlinedButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh_rounded),label:const Text('Retry')),
      ])));
      final d=snapshot.data??const <String,dynamic>{};
      final ai=_map(d['ai']),ledger=_map(d['ledger']),health=_map(ai['local_ai_health']),counts=_map(ai['task_counts']);
      final workers=_rows(ai['workers']);
      final items=_rows(ledger['items']).where((x)=>x['status']!='PROVEN_DONE').toList();
      final online=((health['online_nodes'] as num?)?.toInt()??0);
      final queued=((counts['ai_queued'] as num?)?.toInt()??0);
      return Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('BridgePoint AI Workforce + Forgotten Work',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
          SizedBox(height:3),Text('This is the owner truth: every AI worker, whether local reasoning is actually online, and the recovered cross-chat backlog.',style:TextStyle(fontSize:12)),
        ])),IconButton(onPressed:refresh,tooltip:'Refresh AI truth',icon:const Icon(Icons.refresh_rounded))]),
        const SizedBox(height:10),Wrap(children:[
          _pill(context,'${workers.length} WORKERS'),_pill(context,'$online LOCAL NODE ONLINE'),_pill(context,'$queued AI QUEUED'),
          _pill(context,'${items.length} OPEN / FORGOTTEN'),_pill(context,(health['status']??'UNKNOWN').toString()),
        ]),
        const Divider(height:22),
        const Text('AI workers',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:7),
        Wrap(spacing:7,runSpacing:7,children:workers.map((w){final status=(w['status']??'UNKNOWN').toString();return Container(
          constraints:const BoxConstraints(minWidth:175,maxWidth:290),padding:const EdgeInsets.all(9),
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(11),border:Border.all(color:Theme.of(context).dividerColor)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((w['display_name']??w['worker_key']??'Worker').toString(),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(height:4),_pill(context,status),Text('${w['successful_runs']??0}/${w['total_runs']??0} successful runs',style:const TextStyle(fontSize:10))]),
        );}).toList()),
        const Divider(height:24),
        Row(children:[const Expanded(child:Text('Recovered cross-chat work still open',style:TextStyle(fontWeight:FontWeight.w900))),Text('${items.length}',style:const TextStyle(fontWeight:FontWeight.w900))]),
        const SizedBox(height:7),
        ...items.take(12).map((x)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Padding(padding:const EdgeInsets.only(top:2,right:8),child:Icon(Icons.radio_button_unchecked_rounded,size:14,color:_statusColor(context,(x['status']??'').toString()))),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((x['requirement']??x['req_key']??'').toString(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),Text('${x['category']??''} • ${x['status']??''}',style:const TextStyle(fontSize:10))])),
        ]))),
        if(items.length>12)Text('+ ${items.length-12} more in the full Master Completion ledger',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700)),
        const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/owner/ai/control/?v=602'),mode:LaunchMode.platformDefault),icon:const Icon(Icons.smart_toy_outlined),label:const Text('Open full AI Control')),
          OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/owner/completion/?v=602'),mode:LaunchMode.platformDefault),icon:const Icon(Icons.fact_check_outlined),label:const Text('Open every forgotten item')),
          OutlinedButton.icon(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/owner/local-ai/?v=602'),mode:LaunchMode.platformDefault),icon:const Icon(Icons.computer_rounded),label:const Text('Local AI setup')),
        ]),
      ])));
    });
  }
}

'''
body=body.replace(owner_anchor,widget+owner_anchor,1)

heading="_PageHeading(title:'Owner Center',subtitle:'Your private daily view of revenue • customers • automation • intelligence',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),"
if heading not in body:
    raise SystemExit('v602 owner center heading anchor missing')
body=body.replace(heading,heading+"\n        const SizedBox(height:10),const _OwnerAiVisibilityV602(),",1)

path.write_text(body,encoding='utf-8')
print('Applied BridgePoint v602 owner AI workforce + forgotten-work visibility.')
