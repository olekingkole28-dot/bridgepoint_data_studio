from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v286-owner-system-explorer'
if marker in body:
    print('Owner system explorer v286 already applied.')
    raise SystemExit(0)

flags_old="""  bool showDetailedMetrics=false;
  bool showInvestor=false;
  bool showOperations=false;
  bool showAdvanced=false;
"""
flags_new="""  bool showDetailedMetrics=false;
  bool showInvestor=false;
  bool showSystems=false;
  bool showOperations=false;
  bool showAdvanced=false;
"""
if body.count(flags_old)!=1:
    raise SystemExit(f'v286 owner flags anchor {body.count(flags_old)}')
body=body.replace(flags_old,flags_new,1)

button_old="""          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showInvestor=!showInvestor),
            icon:Icon(showInvestor?Icons.expand_less_rounded:Icons.show_chart_rounded,size:17),
            label:Text(showInvestor?'Hide investor view':'Investor view'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showOperations=!showOperations),
"""
button_new="""          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showInvestor=!showInvestor),
            icon:Icon(showInvestor?Icons.expand_less_rounded:Icons.show_chart_rounded,size:17),
            label:Text(showInvestor?'Hide investor view':'Investor view'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showSystems=!showSystems),
            icon:Icon(showSystems?Icons.expand_less_rounded:Icons.account_tree_outlined,size:17),
            label:Text(showSystems?'Hide system explorer':'System explorer'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showOperations=!showOperations),
"""
if body.count(button_old)!=1:
    raise SystemExit(f'v286 owner button anchor {body.count(button_old)}')
body=body.replace(button_old,button_new,1)

panel_old="""        if(showInvestor)...[const _OwnerInvestorCockpitV277(),const SizedBox(height:18)],
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
panel_new="""        if(showInvestor)...[const _OwnerInvestorCockpitV277(),const SizedBox(height:18)],
        if(showSystems)...[const _OwnerSystemExplorerV286(),const SizedBox(height:18)],
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
if body.count(panel_old)!=1:
    raise SystemExit(f'v286 owner panel insertion anchor {body.count(panel_old)}')
body=body.replace(panel_old,panel_new,1)

class_anchor="""class _OwnerInvestorCockpitV277 extends StatefulWidget{
"""
if body.count(class_anchor)!=1:
    raise SystemExit(f'v286 class anchor {body.count(class_anchor)}')

widget=r'''class _OwnerSystemExplorerV286 extends StatefulWidget{
  const _OwnerSystemExplorerV286();
  @override State<_OwnerSystemExplorerV286> createState()=>_OwnerSystemExplorerV286State();
}
class _OwnerSystemExplorerV286State extends State<_OwnerSystemExplorerV286>{
  late Future<Map<String,dynamic>> request;
  Timer? timer;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_owner_system_explorer_v285',const {});timer=Timer.periodic(const Duration(seconds:20),(_){if(mounted)setState(()=>request=_callRpc('bridgepoint_owner_system_explorer_v285',const {}));});}
  @override void dispose(){timer?.cancel();super.dispose();}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_owner_system_explorer_v285',const {}));
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic v)=>v is List?v.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
  Color statusColor(String status){final s=status.toUpperCase();if(s.contains('HEALTHY')||s.contains('VERIFIED')||s.contains('ENABLED')||s.contains('TARGET_REACHED'))return AppTheme.green;if(s.contains('ATTENTION')||s.contains('FAIL')||s.contains('REVIEW_NEEDED'))return AppTheme.red;if(s.contains('WATCH')||s.contains('EXTERNAL')||s.contains('WAITING'))return AppTheme.amber;if(s.contains('BUILD')||s.contains('PROGRESS')||s.contains('DISCOVER')||s.contains('LEARNING'))return AppTheme.cyan;return AppTheme.blue;}
  IconData systemIcon(String key)=>switch(key){'AUTOMATION_ENGINE'=>Icons.autorenew_rounded,'STATE_EXPANSION'=>Icons.public_rounded,'SOURCE_HEALTH'=>Icons.hub_outlined,'MUNICIPAL_DISCOVERY'=>Icons.location_city_rounded,'REQUIREMENTS_AUDIT'=>Icons.fact_check_outlined,'OUTCOME_LEARNING'=>Icons.psychology_alt_rounded,'SOURCE_VALUE_LEARNING'=>Icons.auto_graph_rounded,'OUTREACH'=>Icons.campaign_outlined,'COMMUNITY_MODERATION'=>Icons.shield_outlined,'TRANSACTIONAL_MAIL'=>Icons.mark_email_unread_outlined,_=>Icons.settings_suggest_outlined};
  Future<void> showDetails(Map<String,dynamic> s)async{
    final color=statusColor('${s['status']??''}');final details=map(s['details']);final pretty=const JsonEncoder.withIndent('  ').convert(details);
    await showDialog<void>(context:context,builder:(context)=>AlertDialog(backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(14),title:Row(children:[Icon(systemIcon('${s['system_key']??''}'),color:color),const SizedBox(width:8),Expanded(child:Text('${s['title']??'BridgePoint system'}')), _OpportunityChip(label:'${s['status']??'UNKNOWN'}',color:color)]),content:SizedBox(width:820,height:650,child:ListView(children:[
      Text('${s['headline']??''}',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900,height:1.35)),const SizedBox(height:12),
      _systemDetailBlock('WHAT IT DOES','${s['what_it_does']??''}',Icons.settings_suggest_outlined,AppTheme.cyan),
      _systemDetailBlock('WHAT TO WATCH','${s['what_to_watch']??''}',Icons.visibility_outlined,AppTheme.blue),
      _systemDetailBlock('WHAT “DONE” MEANS','${s['done_means']??''}',Icons.flag_outlined,AppTheme.green),
      _systemDetailBlock('DO I NEED TO DO ANYTHING?','${s['owner_action']??''}',Icons.person_outline_rounded,color),
      const SizedBox(height:4),Row(children:[const Icon(Icons.schedule_rounded,color:AppTheme.textMuted,size:15),const SizedBox(width:6),Expanded(child:Text(s['last_activity_at']==null?'No activity timestamp yet':'Last activity • ${_bpDateTime(s['last_activity_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9)))]),
      const SizedBox(height:10),ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Raw live backend details',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900)),subtitle:const Text('For owner troubleshooting and deep inspection',style:TextStyle(color:AppTheme.textMuted,fontSize:8)),children:[Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF07111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white10)),child:SelectableText(pretty,style:const TextStyle(fontFamily:'monospace',color:Colors.white70,fontSize:8.5,height:1.45)))])
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]));
  }
  Widget _systemDetailBlock(String label,String text,IconData icon,Color color)=>Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:color.withOpacity(.045),borderRadius:BorderRadius.circular(10),border:Border.all(color:color.withOpacity(.13))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:17),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.55)),const SizedBox(height:4),Text(text,style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.45))]))]));
  Widget card(Map<String,dynamic> s,double width){final status='${s['status']??'UNKNOWN'}',color=statusColor(status),pct=(s['progress_pct'] as num?)?.toDouble();return SizedBox(width:width,child:InkWell(borderRadius:BorderRadius.circular(14),onTap:()=>showDetails(s),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[color.withOpacity(.085),AppTheme.panelSoft.withOpacity(.83)]),borderRadius:BorderRadius.circular(14),border:Border.all(color:color.withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:color.withOpacity(.12),borderRadius:BorderRadius.circular(10)),child:Icon(systemIcon('${s['system_key']??''}'),color:color,size:20)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['title']??''}',style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(status.replaceAll('_',' '),style:TextStyle(color:color,fontSize:7.8,fontWeight:FontWeight.w900,letterSpacing:.45))])),const Icon(Icons.open_in_new_rounded,color:Colors.white38,size:15)]),const SizedBox(height:9),Text('${s['headline']??''}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,fontSize:9,height:1.4)),const SizedBox(height:10),if(pct!=null)...[Row(children:[Expanded(child:Text('${s['progress_mode']??'PROGRESS'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5,fontWeight:FontWeight.w800))),Text('${pct.toStringAsFixed(1)}%',style:TextStyle(color:color,fontSize:8.5,fontWeight:FontWeight.w900))]),const SizedBox(height:4),LinearProgressIndicator(value:(pct/100).clamp(0.0,1.0),minHeight:6,color:color,backgroundColor:Colors.white10,borderRadius:BorderRadius.circular(99))]else...[const Text('Continuous learning/activity system',style:TextStyle(color:AppTheme.textMuted,fontSize:7.5)),const SizedBox(height:4),LinearProgressIndicator(minHeight:3,color:color.withOpacity(.7),backgroundColor:Colors.white10)],const SizedBox(height:7),Text(s['last_activity_at']==null?'Waiting for first relevant activity':'Updated ${_bpDateTime(s['last_activity_at'])}',style:const TextStyle(color:Colors.white38,fontSize:7.5))]))));}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
    if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Loading live BridgePoint systems…',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:10),const LinearProgressIndicator(color:AppTheme.cyan,minHeight:3)])));
    if(snapshot.hasError)return _DashboardError(title:'System Explorer could not load',message:snapshot.error.toString(),onRetry:refresh);
    final data=snapshot.data??const <String,dynamic>{},systems=rows(data['systems']),attention=rows(data['needs_attention']);final overall='${data['overall_status']??'UNKNOWN'}',overallColor=statusColor(overall);
    return Card(child:Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[overallColor.withOpacity(.08),AppTheme.panel.withOpacity(.35),Colors.transparent]),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:42,height:42,decoration:BoxDecoration(color:overallColor.withOpacity(.12),borderRadius:BorderRadius.circular(13)),child:Icon(Icons.account_tree_rounded,color:overallColor)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('BRIDGEPOINT SYSTEM EXPLORER',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,letterSpacing:.65)),const SizedBox(height:3),Text('${data['plain_english']??'Open any system for live details.'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.4))])),_OpportunityChip(label:overall.replaceAll('_',' '),color:overallColor),IconButton(tooltip:'Refresh systems',onPressed:refresh,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))]),
      if(attention.isNotEmpty)...[const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.055),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.14))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('NEEDS ATTENTION / EXTERNAL DEPENDENCIES',style:TextStyle(color:AppTheme.amber,fontSize:8,fontWeight:FontWeight.w900)),const SizedBox(height:5),...attention.take(5).map((a)=>Padding(padding:const EdgeInsets.only(bottom:3),child:Text('• ${a['title']??a['kind']}: ${a['detail']??''}',style:const TextStyle(color:Colors.white70,fontSize:8.5,height:1.35))))]))],
      const SizedBox(height:13),LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1080?3:c.maxWidth>=700?2:1;const gap=10.0;final width=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:systems.map((x)=>card(x,width)).toList());}),
      const SizedBox(height:7),Text('System snapshot • ${_bpDateTime(data['generated_at'])} • auto-refreshes every 20 seconds',style:const TextStyle(color:Colors.white38,fontSize:7.5)),const Text('bridgepoint-v286-owner-system-explorer',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ])));
  });
}

'''
body=body.replace(class_anchor,widget+class_anchor,1)
body += "\nconst String _bridgePointOwnerSystemExplorerV286='bridgepoint-v286-owner-system-explorer | clickable live systems | progress bars | raw owner drilldown | 20 second refresh';\n"
path.write_text(body,encoding='utf-8')
print('Applied live owner system explorer v286.')
