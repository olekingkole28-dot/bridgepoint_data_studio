from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
original=text

def replace_once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    text=text.replace(old,new,1)

replace_once(
"""        const SizedBox(height:18),const _OwnerGrowthPanel(),
""",
"""        const SizedBox(height:18),const _OwnerLaunchReadinessPanel(),
        const SizedBox(height:18),const _OwnerGrowthPanel(),
""",
'launch-readiness-insert')

marker='class _OwnerGrowthPanel extends StatefulWidget{'
if text.count(marker)!=1:
    raise SystemExit('Owner Growth marker not found exactly once')

panel=r'''
class _OwnerLaunchReadinessPanel extends StatefulWidget{
  const _OwnerLaunchReadinessPanel();
  @override State<_OwnerLaunchReadinessPanel> createState()=>_OwnerLaunchReadinessPanelState();
}
class _OwnerLaunchReadinessPanelState extends State<_OwnerLaunchReadinessPanel>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_load();}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_launch_readiness_v121',const {});
  void refresh()=>setState(()=>request=_load());
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  Color color(String status)=>switch(status){
    'READY'=>AppTheme.green,
    'NEEDS_CONNECTION'=>AppTheme.amber,
    'REVIEW'=>AppTheme.blue,
    'BLOCKED'=>const Color(0xFFFF6677),
    _=>AppTheme.textMuted,
  };
  IconData icon(String status)=>switch(status){
    'READY'=>Icons.check_circle_outline_rounded,
    'NEEDS_CONNECTION'=>Icons.link_off_rounded,
    'REVIEW'=>Icons.fact_check_outlined,
    'BLOCKED'=>Icons.error_outline_rounded,
    _=>Icons.help_outline_rounded,
  };
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final checks=rows(data['checks']);
      final summary=data['summary'] is Map?Map<String,dynamic>.from(data['summary']):<String,dynamic>{};
      return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _PanelHeader(title:'Launch Readiness',subtitle:'Private owner audit • verifies the systems behind the buttons',action:'Owner only'),
        const SizedBox(height:10),
        const _ExplainerBanner(icon:Icons.verified_user_outlined,title:'Green means the backend exists — not wishful thinking',message:'This audit checks the actual BridgePoint backend for the systems we locked in. REVIEW and NEEDS CONNECTION stay visible until the external provider or real-world test is complete.'),
        const SizedBox(height:12),
        if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)
        else if(snapshot.hasError)_InlineError(message:snapshot.error.toString())
        else ...[
          Wrap(spacing:8,runSpacing:8,children:[
            _OpportunityChip(label:'${summary['ready']??0} READY',color:AppTheme.green),
            _OpportunityChip(label:'${summary['needs_connection']??0} NEED CONNECTION',color:AppTheme.amber),
            _OpportunityChip(label:'${summary['review']??0} REVIEW',color:AppTheme.blue),
            _OpportunityChip(label:'${summary['blocked']??0} BLOCKED',color:const Color(0xFFFF6677)),
            OutlinedButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh_rounded,size:16),label:const Text('Run audit again')),
          ]),
          const SizedBox(height:10),
          ...checks.map((c){final status='${c['status']??'UNKNOWN'}';final accent=color(status);return Container(
            width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),
            decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(11),border:Border.all(color:accent.withOpacity(.18))),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Icon(icon(status),color:accent,size:19),const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Row(children:[Expanded(child:Text('${c['label']??c['key']??'Check'}',style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900))),const SizedBox(width:8),_OpportunityChip(label:status.replaceAll('_',' '),color:accent)]),
                const SizedBox(height:4),Text('${c['detail']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),
              ])),
            ]),
          );}),
        ],
      ])));
    },
  );
}

'''
text=text.replace(marker,panel+marker,1)
if text==original:
    raise SystemExit('No launch readiness changes applied')
path.write_text(text,encoding='utf-8')
print('Applied owner launch readiness UI v121')
