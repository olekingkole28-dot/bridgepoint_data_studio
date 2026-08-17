from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v277-owner-investor-cockpit'
if marker in body:
    print('Owner investor cockpit v277 already applied.')
    raise SystemExit(0)

old_flags="""  bool showDetailedMetrics=false;
  bool showOperations=false;
  bool showAdvanced=false;
"""
new_flags="""  bool showDetailedMetrics=false;
  bool showInvestor=false;
  bool showOperations=false;
  bool showAdvanced=false;
"""
if body.count(old_flags)!=1:
    raise SystemExit(f'v277 owner flags anchor {body.count(old_flags)}')
body=body.replace(old_flags,new_flags,1)

old_buttons="""          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showDetailedMetrics=!showDetailedMetrics),
            icon:Icon(showDetailedMetrics?Icons.expand_less_rounded:Icons.insights_rounded,size:17),
            label:Text(showDetailedMetrics?'Hide detailed metrics':'Detailed metrics'),
          ),
          FilledButton.tonalIcon(
"""
new_buttons="""          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showDetailedMetrics=!showDetailedMetrics),
            icon:Icon(showDetailedMetrics?Icons.expand_less_rounded:Icons.insights_rounded,size:17),
            label:Text(showDetailedMetrics?'Hide detailed metrics':'Detailed metrics'),
          ),
          FilledButton.tonalIcon(
            onPressed:()=>setState(()=>showInvestor=!showInvestor),
            icon:Icon(showInvestor?Icons.expand_less_rounded:Icons.show_chart_rounded,size:17),
            label:Text(showInvestor?'Hide investor view':'Investor view'),
          ),
          FilledButton.tonalIcon(
"""
if body.count(old_buttons)!=1:
    raise SystemExit(f'v277 owner buttons anchor {body.count(old_buttons)}')
body=body.replace(old_buttons,new_buttons,1)

insert_anchor="""        const SizedBox(height:14),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
insert_replace="""        const SizedBox(height:14),
        if(showInvestor)...[const _OwnerInvestorCockpitV277(),const SizedBox(height:18)],
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?3:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
"""
if body.count(insert_anchor)!=1:
    raise SystemExit(f'v277 investor insertion anchor {body.count(insert_anchor)}')
body=body.replace(insert_anchor,insert_replace,1)

class_anchor="""class _OwnerExpansionPanel extends StatefulWidget{
"""
widget_code=r'''class _OwnerInvestorCockpitV277 extends StatefulWidget{
  const _OwnerInvestorCockpitV277();
  @override State<_OwnerInvestorCockpitV277> createState()=>_OwnerInvestorCockpitV277State();
}
class _OwnerInvestorCockpitV277State extends State<_OwnerInvestorCockpitV277>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_owner_investor_metrics_v275',const {});}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_owner_investor_metrics_v275',const {}));
  Map<String,dynamic> map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
  List<dynamic> list(dynamic v)=>v is List?v:<dynamic>[];
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse('$v')??0;
  Widget metric(String label,dynamic value,String detail,IconData icon,Color color){
    return InkWell(borderRadius:BorderRadius.circular(13),onTap:()=>_showInfoDialog(context,label,detail),child:Container(
      width:240,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(13),border:Border.all(color:color.withOpacity(.18))),
      child:Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:color.withOpacity(.11),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:20)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.45)),const SizedBox(height:3),Text('$value',style:TextStyle(color:color,fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:2),const Text('Tap for meaning + investor context',style:TextStyle(color:Colors.white38,fontSize:7.5))]))]),
    ));
  }
  Widget bar(String label,double value,double max,Color color,String suffix){
    final pct=max<=0?0.0:(value/max).clamp(0.0,1.0);
    return Padding(padding:const EdgeInsets.only(bottom:9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(label,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800))),Text('${_formatInteger(value.round())}$suffix',style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900))]),const SizedBox(height:5),LinearProgressIndicator(value:pct,minHeight:7,color:color,backgroundColor:Colors.white10,borderRadius:BorderRadius.circular(10))]));
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,s){
    if(s.connectionState==ConnectionState.waiting&&!s.hasData)return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Building live investor view…',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:10),const LinearProgressIndicator(color:AppTheme.cyan,minHeight:3)])));
    if(s.hasError)return _DashboardError(title:'Investor view could not load',message:s.error.toString(),onRetry:refresh);
    final d=s.data??const <String,dynamic>{},h=map(d['headline']),g=map(d['geographic_scale']),c=map(d['commercialization']),o=map(d['operating_system']),p=map(d['presentation']);
    final ct=n(g['ct_properties']),ny=n(g['ny_properties']),maxState=[ct,ny].reduce((a,b)=>a>b?a:b);
    final prospects=n(c['customer_prospects']),target=n(c['customer_target']);
    final ok=n(h['successful_runs_15m']),fail=n(h['failed_latest_runs_15m']);
    final health=(ok+fail)<=0?0.0:(ok/(ok+fail)).clamp(0.0,1.0);
    return Card(child:Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[AppTheme.cyan.withOpacity(.09),AppTheme.blue.withOpacity(.035),Colors.transparent]),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:42,height:42,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.12),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.show_chart_rounded,color:AppTheme.cyan)),const SizedBox(width:11),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('INVESTOR OPERATING VIEW',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,letterSpacing:.7)),SizedBox(height:3),Text('Live scale • intelligence production • automation health • commercialization • presentation guidance',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.4))])),IconButton(tooltip:'Refresh investor metrics',onPressed:refresh,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))]),
      const SizedBox(height:12),Wrap(spacing:9,runSpacing:9,children:[
        metric('CANONICAL PROPERTIES',_formatInteger(h['canonical_properties']??0),'This is the number of canonical property records BridgePoint currently maintains across markets that have real records loaded. Present it as operating data scale—not customers, users, or unique households.',Icons.home_work_outlined,AppTheme.cyan),
        metric('PROPERTY SCORES',_formatInteger(h['property_scores']??0),'Property scores are model outputs created on top of the canonical property layer. They show that BridgePoint is transforming source data into modeled property intelligence, not merely storing records.',Icons.speed_rounded,AppTheme.blue),
        metric('DETECTED PATTERNS',_formatInteger(h['detected_patterns']??0),'Detected patterns are reusable relationships BridgePoint has found across evidence and signals. Explain that patterns help connect fragmented events into property-level context.',Icons.hub_outlined,AppTheme.green),
        metric('VERIFIED OPPORTUNITIES',_formatInteger(h['verified_opportunities']??0),'Verified opportunities are deduplicated property opportunities that meet BridgePoint direct-evidence rules. This is a much narrower and more defensible number than raw signals or patterns.',Icons.bolt_rounded,AppTheme.amber),
        metric('AUTOMATION JOBS',_formatInteger(h['active_automation_jobs']??0),'Active scheduled jobs are recurring production jobs currently registered in BridgePoint automation. Use this to demonstrate that ingestion, health, expansion, learning and refresh work runs without manual button-pushing.',Icons.autorenew_rounded,const Color(0xFF9B7BFF)),
        metric('LATEST FAILURES',_formatInteger(h['failed_latest_runs_15m']??0),'This counts scheduled jobs whose latest run in the last 15 minutes is still failed. Recovered jobs clear from this metric after a successful rerun.',Icons.health_and_safety_outlined,(n(h['failed_latest_runs_15m'])==0)?AppTheme.green:AppTheme.red),
      ]),
      const SizedBox(height:16),LayoutBuilder(builder:(context,box){final narrow=box.maxWidth<760;final geo=Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.48),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('GEOGRAPHIC SCALE',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6,color:AppTheme.cyan)),const SizedBox(height:10),bar('Connecticut • LIVE',ct,maxState,AppTheme.green,''),bar('New York • BUILDING',ny,maxState,AppTheme.amber,''),Text('${g['live_states']??0} live • ${g['building_states']??0} building • ${g['planned_states']??0} planned',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5))]));final commercial=Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.48),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('COMMERCIALIZATION',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6,color:AppTheme.green)),const SizedBox(height:10),bar('Customer prospects',prospects,target,AppTheme.cyan,' / ${target.round()}'),Text('${c['customer_scheduled']??0} scheduled • ${c['customer_sent']??0} sent • ${c['customer_delivered']??0} delivered',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),const SizedBox(height:8),Row(children:[Expanded(child:Text('Active trials\n${c['active_trials']??0}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))),Expanded(child:Text('Booked MRR\n\$${c['active_mrr']??0}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))),Expanded(child:Text('Trial pipeline\n\$${c['trial_pipeline_mrr']??0}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900)))]) ]));return narrow?Column(children:[geo,const SizedBox(height:10),commercial]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:geo),const SizedBox(width:10),Expanded(child:commercial)]);}),
      const SizedBox(height:12),Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.045),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.14))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.settings_suggest_outlined,color:AppTheme.green,size:18),const SizedBox(width:8),const Expanded(child:Text('AUTOMATION HEALTH • LAST 15 MINUTES',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900))),Text('${(health*100).toStringAsFixed(1)}%',style:const TextStyle(color:AppTheme.green,fontWeight:FontWeight.w900))]),const SizedBox(height:7),LinearProgressIndicator(value:health,minHeight:7,color:AppTheme.green,backgroundColor:Colors.white10,borderRadius:BorderRadius.circular(10)),const SizedBox(height:5),Text('${h['successful_runs_15m']??0} successful latest runs • ${h['failed_latest_runs_15m']??0} still failed',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5))])),
      const SizedBox(height:12),ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,title:const Text('How I should present BridgePoint to an investor',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11)),subtitle:const Text('Tap to open the live talking points',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),children:[
        for(final item in [MapEntry('1 • OPENING',p['opening']),MapEntry('2 • SCALE',p['scale_script']),MapEntry('3 • INTELLIGENCE',p['intelligence_script']),MapEntry('4 • AUTOMATION',p['automation_script']),MapEntry('5 • COMMERCIALIZATION',p['commercialization_script']),MapEntry('6 • CLOSE',p['close'])])
          if(item.value!=null)Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.035),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.cyan.withOpacity(.10))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.key,style:const TextStyle(color:AppTheme.cyan,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.5)),const SizedBox(height:5),SelectableText('${item.value}',style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.5))])),
        if(list(p['do_not_say']).isNotEmpty)Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.055),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.15))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('DO NOT OVERSTATE',style:TextStyle(color:AppTheme.amber,fontSize:8.5,fontWeight:FontWeight.w900)),const SizedBox(height:5),...list(p['do_not_say']).map((x)=>Padding(padding:const EdgeInsets.only(bottom:4),child:Text('• $x',style:const TextStyle(color:Colors.white70,fontSize:9,height:1.35))))]))
      ]),
      ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,title:Text('Readiness & open items • ${o['requirements_open']??0} required open',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:10)),subtitle:Text('${o['requirements_verified']??0}/${o['requirements_total']??0} requirements verified • ${o['municipal_sources_discovered']??0} municipal sources discovered',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),children:[...list(o['needs_attention']).map((x){final m=map(x);return ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.info_outline_rounded,color:AppTheme.amber,size:18),title:Text('${m['title']??m['kind']}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:9.5)),subtitle:Text('${m['detail']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35));})]),
      const SizedBox(height:4),Text('Live snapshot • ${d['generated_at']==null?'now':_bpDateTime(d['generated_at'])}',style:const TextStyle(color:Colors.white30,fontSize:7.5)),const Text('bridgepoint-v277-owner-investor-cockpit',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ])));
  });
}

'''
if body.count(class_anchor)!=1:
    raise SystemExit(f'v277 class anchor {body.count(class_anchor)}')
body=body.replace(class_anchor,widget_code+class_anchor,1)
body += "\nconst String _bridgePointOwnerInvestorCockpitV277='bridgepoint-v277-owner-investor-cockpit | live investor metrics | presentation guidance | clickable explanations';\n"
path.write_text(body,encoding='utf-8')
print('Applied owner investor cockpit v277.')
