from __future__ import annotations

from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
marker = 'bridgepoint-v410-owner-everything-command-center'

if marker in text:
    print('Owner Everything Command Center V410 already applied')
    raise SystemExit(0)

if 'bridgepoint-v219-owner-outreach' not in text:
    raise SystemExit('V410 requires the established owner center / outreach release layer')

heading = "_PageHeading(title:'Owner Center',subtitle:'Revenue • customers • outreach • automation • intelligence',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),"
replacement = heading + "\n        const SizedBox(height:14),\n        const _OwnerEverythingCommandV410(),"
if text.count(heading) != 1:
    raise SystemExit(f'V410 owner heading anchor count {text.count(heading)}')
text = text.replace(heading, replacement, 1)

widget = r'''
// bridgepoint-v410-owner-everything-command-center
class _OwnerEverythingCommandV410 extends StatefulWidget{
  const _OwnerEverythingCommandV410();
  @override State<_OwnerEverythingCommandV410> createState()=>_OwnerEverythingCommandV410State();
}

class _OwnerEverythingCommandV410State extends State<_OwnerEverythingCommandV410>{
  Future<Map<String,dynamic>>? request;
  final searchController=TextEditingController();
  String range='24H';
  String status='ALL';
  String search='';

  @override void initState(){super.initState();request=_load();}
  @override void dispose(){searchController.dispose();super.dispose();}

  DateTime _since()=>switch(range){
    'TODAY'=>DateTime.now().subtract(const Duration(hours:12)),
    '7D'=>DateTime.now().subtract(const Duration(days:7)),
    '30D'=>DateTime.now().subtract(const Duration(days:30)),
    'ALL'=>DateTime(2000),
    _=>DateTime.now().subtract(const Duration(hours:24)),
  };
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_owner_everything_v410',{'p_since':_since().toUtc().toIso8601String()});
  void refresh()=>setState(()=>request=_load());
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  Color statusColor(String value)=>switch(value.toUpperCase()){'LIVE'||'VERIFIED'=>AppTheme.green,'BLOCKED'=>AppTheme.red,'BUILDING'=>AppTheme.amber,'DEPLOYED'=>AppTheme.cyan,_=>AppTheme.blue};
  IconData sectionIcon(String key)=>switch(key){
    'overview'=>Icons.monitor_heart_outlined,'coverage'=>Icons.public_rounded,'matching'=>Icons.hub_outlined,
    'scoring'=>Icons.auto_graph_rounded,'readiness'=>Icons.lock_open_rounded,'billing'=>Icons.payments_outlined,
    'funnel'=>Icons.filter_alt_outlined,'outreach'=>Icons.outgoing_mail,'referrals'=>Icons.link_rounded,
    'inbound'=>Icons.travel_explore_rounded,'newsroom'=>Icons.newspaper_rounded,'podcast'=>Icons.podcasts_rounded,
    'social'=>Icons.share_outlined,'earned'=>Icons.campaign_outlined,'lifecycle'=>Icons.mark_email_read_outlined,
    'experiments'=>Icons.science_outlined,'security'=>Icons.security_rounded,'registry'=>Icons.inventory_2_outlined,
    'activity'=>Icons.timeline_rounded,'glossary'=>Icons.menu_book_outlined,_=>Icons.dashboard_customize_outlined};

  int _socialCount(Map<String,dynamic> social,String status){
    for(final row in rows(social['attempt_summary'])){
      if('${row['status']??''}'.toUpperCase()==status.toUpperCase())return (row['cnt'] as num?)?.toInt()??0;
    }
    return 0;
  }
  String _headline(String key,Map<String,dynamic> live){
    final systems=map(live['systems']),national=map(live['national']),funnel=map(live['funnel']),outreach=map(live['outreach']),social=map(live['social']);
    if(key=='overview')return '${systems['overall_status']??'Status loading'} • ${rows(systems['systems']).length} monitored systems';
    if(key=='coverage')return '${national['average_verified_progress_pct']??'—'}% average verified progress • ${rows(national['states']).length} states';
    if(key=='funnel')return '${funnel['unique_visitors']??0} unique visitors • ${funnel['known_users']??0} known users in selected window';
    if(key=='outreach')return '${outreach['emails_sent']??0} sent • ${outreach['replies']??0} replies • ${outreach['paid_customers']??0} paid';
    if(key=='social')return '${rows(social['connections']).length} provider targets • ${_socialCount(social,'PUBLISHED')} published attempts recorded';
    if(key=='registry')return '${rows(live['features']).length} major workstreams registered';
    if(key=='glossary')return '${rows(live['glossary']).length} owner terms explained';
    return 'Open Details for current source-of-truth status';
  }

  Future<void> showDetails(Map<String,dynamic> section,Map<String,dynamic> live)async{
    final key='${section['key']??''}',payloadKey=section['payload_key']?.toString();
    final payload=payloadKey==null?null:live[payloadKey];
    final color=statusColor('${section['status']??'BUILDING'}');
    final pretty=payload==null?'Live metric contract is not wired for this section yet. BridgePoint is intentionally showing this as unavailable instead of reporting a fake zero.':const JsonEncoder.withIndent('  ').convert(payload);
    await showDialog<void>(context:context,builder:(context)=>Dialog(backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(14),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900,maxHeight:820),child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,18,12,12),child:Row(children:[Container(width:40,height:40,decoration:BoxDecoration(color:color.withOpacity(.11),borderRadius:BorderRadius.circular(11)),child:Icon(sectionIcon(key),color:color)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${section['title']??'Owner detail'}',style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${section['status']??'BUILDING'}',style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6))])),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))])),
      Divider(height:1,color:Colors.white.withOpacity(.06)),
      Expanded(child:ListView(padding:const EdgeInsets.all(20),children:[
        _OwnerEverythingExplainV410(label:'WHAT THIS IS',text:'${section['what_is']??''}',icon:Icons.help_outline_rounded,color:AppTheme.cyan),
        _OwnerEverythingExplainV410(label:'WHY IT MATTERS',text:'${section['why_matters']??''}',icon:Icons.lightbulb_outline_rounded,color:AppTheme.blue),
        _OwnerEverythingExplainV410(label:'WHAT HAPPENS AUTOMATICALLY NEXT',text:'${section['auto_next']??''}',icon:Icons.autorenew_rounded,color:AppTheme.green),
        const SizedBox(height:5),
        Row(children:[const Icon(Icons.schedule_rounded,color:AppTheme.textMuted,size:15),const SizedBox(width:6),Expanded(child:Text('Freshness • ${_bpDateTime(live['_generated_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)))]),
        const SizedBox(height:12),
        ExpansionTile(initiallyExpanded:true,tilePadding:EdgeInsets.zero,title:const Text('Live source-of-truth details',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),subtitle:Text(payload==null?'Instrumentation is still building':'Owner-only backend payload • secrets redacted',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),children:[Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF07111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white10)),child:SelectableText(pretty,style:const TextStyle(fontFamily:'monospace',color:Colors.white70,fontSize:8.2,height:1.45)))])
      ])),
    ]))));
  }

  Widget sectionCard(Map<String,dynamic> section,Map<String,dynamic> live,double width){
    final key='${section['key']??''}',state='${section['status']??'BUILDING'}',color=statusColor(state);
    return SizedBox(width:width,child:InkWell(onTap:()=>showDetails(section,live),borderRadius:BorderRadius.circular(14),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.58),borderRadius:BorderRadius.circular(14),border:Border.all(color:color.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:color.withOpacity(.10),borderRadius:BorderRadius.circular(10)),child:Icon(sectionIcon(key),color:color,size:19)),const SizedBox(width:9),Expanded(child:Text('${section['title']??''}',style:const TextStyle(color:Colors.white,fontSize:10.5,fontWeight:FontWeight.w900))),_OpportunityChip(label:state,color:color)]),
      const SizedBox(height:9),Text(_headline(key,live),maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w800,height:1.35)),
      const SizedBox(height:6),Text('${section['what_is']??''}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.7,height:1.4)),
      const SizedBox(height:9),Row(children:[const Icon(Icons.info_outline_rounded,color:Colors.white38,size:13),const SizedBox(width:5),const Text('What does this mean?',style:TextStyle(color:Colors.white54,fontSize:7.8,fontWeight:FontWeight.w800)),const Spacer(),TextButton(onPressed:()=>showDetails(section,live),child:const Text('Details'))]),
    ]))));
  }

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
    if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Building your live Command Center…',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:10),const LinearProgressIndicator(color:AppTheme.cyan,minHeight:3)])));
    if(snapshot.hasError)return _DashboardError(title:'Owner Command Center could not load',message:snapshot.error.toString(),onRetry:refresh);
    final data=snapshot.data??const <String,dynamic>{},live=map(data['live']);
    live['_generated_at']=data['generated_at'];
    final all=rows(data['sections']);
    final needle=search.trim().toLowerCase();
    final visible=all.where((section){final state='${section['status']??''}';if(status!='ALL'&&state!=status)return false;if(needle.isEmpty)return true;final hay='${section['title']} ${section['what_is']} ${section['why_matters']} ${section['auto_next']}'.toLowerCase();return hay.contains(needle);}).toList();
    final liveCount=all.where((s)=>s['status']=='LIVE').length,buildingCount=all.where((s)=>s['status']=='BUILDING').length,blockedCount=all.where((s)=>s['status']=='BLOCKED').length;
    return Card(child:Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[AppTheme.cyan.withOpacity(.075),AppTheme.blue.withOpacity(.035),Colors.transparent]),borderRadius:BorderRadius.circular(15)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:46,height:46,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.green]),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.space_dashboard_rounded,color:Color(0xFF06111F))),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('BRIDGEPOINT COMMAND CENTER',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900,letterSpacing:.6)),const SizedBox(height:3),const Text('Owner Everything • live truth across product, data, revenue, growth, content and automation',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const SizedBox(height:5),Text('${data['truth_rule']??''}',style:const TextStyle(color:Colors.white54,fontSize:7.8,height:1.35))])),IconButton(tooltip:'Refresh Command Center',onPressed:refresh,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))]),
      const SizedBox(height:13),
      Wrap(spacing:8,runSpacing:8,children:[_OpportunityChip(label:'$liveCount LIVE',color:AppTheme.green),_OpportunityChip(label:'$buildingCount BUILDING',color:AppTheme.amber),if(blockedCount>0)_OpportunityChip(label:'$blockedCount BLOCKED',color:AppTheme.red),_OpportunityChip(label:'OWNER ONLY',color:AppTheme.cyan)]),
      const SizedBox(height:13),
      LayoutBuilder(builder:(context,c){final compact=c.maxWidth<720;return Wrap(spacing:9,runSpacing:9,crossAxisAlignment:WrapCrossAlignment.center,children:[
        SizedBox(width:compact?c.maxWidth:300,child:TextField(controller:searchController,onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(isDense:true,prefixIcon:Icon(Icons.search_rounded,size:18),labelText:'Search systems, features or metrics',border:OutlineInputBorder()))),
        DropdownButton<String>(value:range,items:const ['TODAY','24H','7D','30D','ALL'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v==null)return;setState((){range=v;request=_load();});}),
        DropdownButton<String>(value:status,items:const ['ALL','LIVE','BUILDING','BLOCKED'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>status=v??'ALL')),
      ]);}),
      const SizedBox(height:7),const Text('Global owner view • State, vertical, package, channel and worker drill-downs live inside the relevant Details payloads. Additional cross-section filters will only become active when their underlying metric supports them.',style:TextStyle(color:Colors.white38,fontSize:7.6,height:1.35)),
      const SizedBox(height:14),
      LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1080?3:c.maxWidth>=680?2:1;const gap=10.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:visible.map((s)=>sectionCard(s,live,w)).toList());}),
      if(visible.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Center(child:Text('No Command Center sections match this search/filter.',style:TextStyle(color:AppTheme.textMuted)))),
      const SizedBox(height:10),Text('Live owner snapshot • ${_bpDateTime(data['generated_at'])} • V${data['version']??410}',style:const TextStyle(color:Colors.white38,fontSize:7.6)),
      const Text('bridgepoint-v410-owner-everything-command-center',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ])));
  });
}

class _OwnerEverythingExplainV410 extends StatelessWidget{
  const _OwnerEverythingExplainV410({required this.label,required this.text,required this.icon,required this.color});
  final String label,text;final IconData icon;final Color color;
  @override Widget build(BuildContext context)=>Container(width:double.infinity,margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withOpacity(.045),borderRadius:BorderRadius.circular(10),border:Border.all(color:color.withOpacity(.13))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:17),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.55)),const SizedBox(height:4),Text(text,style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.45))]))]));
}
'''

text += '\n' + widget
for needle in (
    marker,
    'bridgepoint_owner_everything_v410',
    'BRIDGEPOINT COMMAND CENTER',
    'What does this mean?',
    'Live source-of-truth details',
    'Owner Everything • live truth',
):
    if needle not in text:
        raise SystemExit(f'V410 required marker missing: {needle}')

path.write_text(text,encoding='utf-8')
print('Owner Everything Command Center V410 applied')
