from pathlib import Path

main=Path('lib/main.dart')
web=Path('web/index.html')
text=main.read_text(encoding='utf-8')
marker='bridgepoint-v380-owner-national-cockpit'
if marker in text:
    print('v380 already applied')
    raise SystemExit(0)

required=[
    'bridgepoint-v360-live-radar-persistence',
    'class _OwnerExpansionPanel extends StatefulWidget{',
    'class _OwnerLaunchReadinessPanel extends StatefulWidget{',
    "heroTag:'bridgepoint-expansion-fab-v212'",
    "if(nationalZoom){\n            markerChild=Container(",
]
missing=[x for x in required if x not in text]
if missing:
    raise SystemExit(f'v380 generated-source contract drift; missing: {missing}')

fab="""                    if(_effectiveOwnerMode)Positioned(\n                      right:desktop?22:14,bottom:desktop?78:70,\n                      child:SafeArea(child:Tooltip(message:'Automatic State Expansion • Owner only',child:FloatingActionButton.small(\n                        heroTag:'bridgepoint-expansion-fab-v212',onPressed:()=>_navigateTrainingLabel('Owner Center'),backgroundColor:AppTheme.green,foregroundColor:const Color(0xFF06111F),elevation:7,\n                        child:const Icon(Icons.public_rounded,size:21),\n                      ))),\n                    ),\n"""
if text.count(fab)!=1:
    raise SystemExit(f'v380 expansion FAB anchor count {text.count(fab)}')
text=text.replace(fab,'',1)

panel_start=text.index('class _OwnerExpansionPanel extends StatefulWidget{')
panel_end=text.index('class _OwnerLaunchReadinessPanel extends StatefulWidget{',panel_start)
new_panel=r'''class _OwnerExpansionPanel extends StatefulWidget{
  const _OwnerExpansionPanel();
  @override State<_OwnerExpansionPanel> createState()=>_OwnerExpansionPanelState();
}
class _OwnerExpansionPanelState extends State<_OwnerExpansionPanel>{
  Map<String,dynamic>? data;
  Object? lastError;
  bool loading=true;
  String phaseFilter='ALL';
  String search='';
  Timer? poller;
  final searchController=TextEditingController();

  @override void initState(){
    super.initState();
    unawaited(refresh());
    poller=Timer.periodic(const Duration(seconds:20),(_){if(mounted&&!loading)unawaited(refresh(quiet:true));});
  }
  @override void dispose(){poller?.cancel();searchController.dispose();super.dispose();}

  List<Map<String,dynamic>> rows(dynamic value)=>value is List?value.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
  double pct(dynamic v)=>((v as num?)?.toDouble()??0).clamp(0.0,100.0).toDouble();
  int numInt(dynamic v)=>(v as num?)?.toInt()??0;
  String phaseLabel(dynamic value)=>'${value??'WAITING'}'.replaceAll('_',' ');
  Color phaseColor(String phase)=>switch(phase){
    'ACTIVATE'||'CUSTOMER_QA'||'SECURITY_ENTITLEMENTS'=>AppTheme.green,
    'SCORE_OPPORTUNITIES'||'SIGNALS_EVIDENCE'=>AppTheme.cyan,
    'NORMALIZE_MATCH'||'CONTEXT_LAYERS'=>AppTheme.blue,
    'PROPERTY_FOUNDATION'=>AppTheme.amber,
    _=>const Color(0xFF9B7BFF),
  };
  String eta(Map<String,dynamic> s){
    final minutes=(s['eta_minutes'] as num?)?.toInt();
    if(minutes==null||minutes<0)return 'ETA learning from live work';
    if(minutes<60)return '≈ ${minutes}m left';
    if(minutes<1440)return '≈ ${(minutes/60).toStringAsFixed(minutes<360?1:0)}h left';
    return '≈ ${(minutes/1440).toStringAsFixed(minutes<4320?1:0)}d left';
  }
  String countPair(dynamic a,dynamic b){final aa=numInt(a),bb=numInt(b);return bb>0?'${_formatInteger(aa)} / ${_formatInteger(bb)}':_formatInteger(aa);}

  Future<void> refresh({bool quiet=false})async{
    if(!quiet&&mounted)setState(()=>loading=true);
    try{
      final next=await _callRpc('bridgepoint_owner_national_progress_v377',const {});
      if(!mounted)return;
      setState((){data=next;lastError=null;loading=false;});
    }catch(e){
      if(!mounted)return;
      setState((){lastError=e;loading=false;});
    }
  }

  Widget summaryMetric(String label,String value,String detail,Color color,IconData icon)=>Container(
    width:154,padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:color.withOpacity(.065),borderRadius:BorderRadius.circular(13),border:Border.all(color:color.withOpacity(.18))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,color:color,size:16),const Spacer(),Container(width:7,height:7,decoration:BoxDecoration(color:color,shape:BoxShape.circle))]),
      const SizedBox(height:8),Text(value,style:TextStyle(color:color,fontSize:17,fontWeight:FontWeight.w900)),
      Text(label,style:const TextStyle(color:Colors.white,fontSize:8.3,fontWeight:FontWeight.w900,letterSpacing:.5)),
      const SizedBox(height:3),Text(detail,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5,height:1.3)),
    ]),
  );

  Widget miniMetric(String label,String value,Color color)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),
    decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(9),border:Border.all(color:color.withOpacity(.12))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:color,fontSize:9.5,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:6.7,fontWeight:FontWeight.w800,letterSpacing:.35))]),
  );

  Widget stateCard(Map<String,dynamic> s,double width){
    final overall=pct(s['overall_progress_pct']);
    final phasePctRaw=s['phase_progress_pct'];
    final phasePct=phasePctRaw==null?null:pct(phasePctRaw);
    final phase='${s['current_phase']??'WAITING'}';
    final color=phaseColor(phase);
    final steps=rows(s['steps']);
    final expected=numInt(s['expected_foundation_rows']);
    final canonical=numInt(s['canonical_property_count']);
    final sourceDone=numInt(s['source_tasks_completed']);
    final sourceTotal=numInt(s['source_tasks_total']);
    final signals=numInt(s['signals_count']);
    final evidence=numInt(s['evidence_items_count']);
    final queue=numInt(s['property_queue_pending']);
    final scores=numInt(s['scores_present']);
    final opps=numInt(s['opportunities_present']);
    final etaConfidence='${s['eta_confidence']??'LEARNING'}';
    final activity=s['last_activity_at'];
    return SizedBox(width:width,child:Container(
      margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[color.withOpacity(.10),AppTheme.panelSoft.withOpacity(.74),const Color(0xFF07111F).withOpacity(.72)]),
        borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withOpacity(.22)),
        boxShadow:[BoxShadow(color:color.withOpacity(.055),blurRadius:22,offset:const Offset(0,8))],
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
          _OwnerStateDonutV380(overall:overall,phase:phasePct,color:color,size:72),const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text('${s['state_name']??s['state_code']} (${s['state_code']})',style:const TextStyle(color:Colors.white,fontSize:12.5,fontWeight:FontWeight.w900))),_OpportunityChip(label:'${s['queue_status']??'ACTIVE'}',color:AppTheme.green)]),
            const SizedBox(height:4),Text(phaseLabel(phase),style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.45)),
            const SizedBox(height:5),Text('${numInt(s['step_done'])}/${numInt(s['step_total'])} verified gates • ${s['data_status']??'BUILDING'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.2)),
            const SizedBox(height:7),Row(children:[Icon(Icons.schedule_rounded,color:color,size:13),const SizedBox(width:5),Expanded(child:Text('${eta(s)} • $etaConfidence confidence',style:TextStyle(color:color,fontSize:8.3,fontWeight:FontWeight.w800)))]),
          ])),
        ]),
        const SizedBox(height:12),
        if(phasePct!=null)...[
          Row(children:[Expanded(child:Text('CURRENT PHASE • ${phaseLabel(phase)}',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.4,fontWeight:FontWeight.w900,letterSpacing:.4))),Text('${phasePct.toStringAsFixed(1)}%',style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900))]),
          const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(99),child:LinearProgressIndicator(value:phasePct/100,minHeight:5,color:color,backgroundColor:Colors.white10)),const SizedBox(height:10),
        ],
        GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:7,crossAxisSpacing:7,childAspectRatio:2.9,children:[
          miniMetric('PROPERTIES',countPair(canonical,expected),AppTheme.cyan),
          miniMetric('SOURCES','$sourceDone / $sourceTotal',AppTheme.blue),
          miniMetric('SIGNALS / EVIDENCE','${_formatInteger(signals)} / ${_formatInteger(evidence)}',AppTheme.green),
          miniMetric('QUEUE PENDING',_formatInteger(queue),queue>0?AppTheme.amber:AppTheme.green),
          if(scores>0||opps>0)miniMetric('SCORES / OPPS','${_formatInteger(scores)} / ${_formatInteger(opps)}',const Color(0xFF9B7BFF)),
          if(s['rows_per_minute']!=null)miniMetric('PROPERTY RATE','${s['rows_per_minute']} / min',AppTheme.cyan),
        ]),
        if(steps.isNotEmpty)...[
          const SizedBox(height:11),_OwnerStateStepStripV380(steps:steps,color:color),
          Theme(data:Theme.of(context).copyWith(dividerColor:Colors.transparent),child:ExpansionTile(
            tilePadding:EdgeInsets.zero,childrenPadding:EdgeInsets.zero,dense:true,
            title:const Text('Open verified build details',style:TextStyle(color:Colors.white,fontSize:8.8,fontWeight:FontWeight.w900)),
            subtitle:Text(activity==null?'Waiting for activity':'Updated ${_bpDateTime(activity)}',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.3)),
            children:steps.map((step){
              final status='${step['status']??step['step_status']??'PENDING'}';
              final sc=switch(status){'SUCCEEDED'||'SKIPPED'=>AppTheme.green,'RUNNING'=>AppTheme.cyan,'FAILED'=>AppTheme.red,'WAITING_APPROVAL'||'BLOCKED'=>AppTheme.amber,_=>AppTheme.textMuted};
              return Container(width:double.infinity,margin:const EdgeInsets.only(bottom:5),padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),decoration:BoxDecoration(color:sc.withOpacity(.035),borderRadius:BorderRadius.circular(8),border:Border.all(color:sc.withOpacity(.10))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:8,height:8,margin:const EdgeInsets.only(top:2),decoration:BoxDecoration(color:sc,shape:BoxShape.circle)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${step['step_name']??step['step_key']??'Build step'}',style:const TextStyle(color:Colors.white,fontSize:8.5,fontWeight:FontWeight.w800)),const SizedBox(height:2),Text(status.replaceAll('_',' '),style:TextStyle(color:sc,fontSize:7.2,fontWeight:FontWeight.w800))]))]));
            }).toList(),
          )),
        ],
      ]),
    ));
  }

  @override Widget build(BuildContext context){
    final all=rows(data?['states']);
    final phases=<String>{...all.map((s)=>'${s['current_phase']??'WAITING'}')}.toList()..sort();
    final needle=search.trim().toLowerCase();
    final visible=all.where((s){
      final phase='${s['current_phase']??'WAITING'}';
      if(phaseFilter!='ALL'&&phase!=phaseFilter)return false;
      if(needle.isEmpty)return true;
      return '${s['state_name']} ${s['state_code']} $phase'.toLowerCase().contains(needle);
    }).toList()..sort((a,b){final p=pct(b['overall_progress_pct']).compareTo(pct(a['overall_progress_pct']));return p!=0?p:'${a['state_name']}'.compareTo('${b['state_name']}');});
    final totalCanonical=all.fold<int>(0,(sum,s)=>sum+numInt(s['canonical_property_count']));
    final signalsStates=all.where((s)=>numInt(s['signals_count'])>0).length;
    final foundationStates=all.where((s)=>'${s['current_phase']}'=='PROPERTY_FOUNDATION').length;
    final avg=pct(data?['average_verified_progress_pct']);
    final sourceQueued=all.fold<int>(0,(sum,s)=>sum+numInt(s['source_tasks_queued']));

    return Card(child:Container(width:double.infinity,padding:const EdgeInsets.all(17),decoration:BoxDecoration(
      gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[AppTheme.green.withOpacity(.075),AppTheme.cyan.withOpacity(.035),Colors.transparent]),borderRadius:BorderRadius.circular(15)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:43,height:43,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.green,AppTheme.cyan]),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.public_rounded,color:Color(0xFF06111F))),
          const SizedBox(width:11),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('NATIONAL EXPANSION COMMAND',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900,letterSpacing:.55)),SizedBox(height:3),Text('Owner live view • every state • real percentages • counts • phase • measured ETA',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4))])),
          IconButton(tooltip:'Refresh all state progress',onPressed:loading?null:()=>refresh(),icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:AppTheme.cyan)):const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
        ]),
        if(lastError!=null)...[const SizedBox(height:9),Container(width:double.infinity,padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.06),borderRadius:BorderRadius.circular(9),border:Border.all(color:AppTheme.amber.withOpacity(.14))),child:Text('Live refresh hiccup • keeping the last verified state snapshot on screen. $lastError',style:const TextStyle(color:AppTheme.amber,fontSize:8,height:1.35)))],
        const SizedBox(height:13),
        LayoutBuilder(builder:(context,c){
          final ring=Container(width:c.maxWidth<620?c.maxWidth:185,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.62),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.green.withOpacity(.18))),child:Row(children:[_OwnerStateDonutV380(overall:avg,phase:null,color:AppTheme.green,size:68),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${all.length} STATES',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)),const SizedBox(height:2),const Text('verified national build',style:TextStyle(color:AppTheme.textMuted,fontSize:7.5)),const SizedBox(height:5),Text('${avg.toStringAsFixed(1)}% avg',style:const TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900))]))]));
          final metrics=<Widget>[summaryMetric('CANONICAL',_formatInteger(totalCanonical),'properties currently materialized',AppTheme.cyan,Icons.home_work_outlined),summaryMetric('SIGNAL STATES','$signalsStates','states with signal/evidence work',AppTheme.green,Icons.bolt_rounded),summaryMetric('FOUNDATION','$foundationStates','states currently building property base',AppTheme.amber,Icons.foundation_rounded),summaryMetric('SOURCE QUEUE',_formatInteger(sourceQueued),'remaining source tasks',AppTheme.blue,Icons.hub_outlined)];
          return Wrap(spacing:9,runSpacing:9,children:[ring,...metrics]);
        }),
        const SizedBox(height:14),
        LayoutBuilder(builder:(context,c){final compact=c.maxWidth<680;final searchBox=TextField(controller:searchController,onChanged:(v)=>setState(()=>search=v),decoration:InputDecoration(isDense:true,prefixIcon:const Icon(Icons.search_rounded,size:18),suffixIcon:search.isEmpty?null:IconButton(onPressed:(){searchController.clear();setState(()=>search='');},icon:const Icon(Icons.close_rounded,size:16)),hintText:'Find a state or phase',border:const OutlineInputBorder()));return compact?Column(children:[searchBox,const SizedBox(height:9),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[FilterChip(selected:phaseFilter=='ALL',label:const Text('ALL'),onSelected:(_)=>setState(()=>phaseFilter='ALL')),...phases.map((p)=>Padding(padding:const EdgeInsets.only(left:6),child:FilterChip(selected:phaseFilter==p,label:Text(phaseLabel(p),style:const TextStyle(fontSize:7.5)),onSelected:(_)=>setState(()=>phaseFilter=p))))]))]):Row(children:[Expanded(flex:2,child:searchBox),const SizedBox(width:9),Expanded(flex:3,child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[FilterChip(selected:phaseFilter=='ALL',label:const Text('ALL'),onSelected:(_)=>setState(()=>phaseFilter='ALL')),...phases.map((p)=>Padding(padding:const EdgeInsets.only(left:6),child:FilterChip(selected:phaseFilter==p,label:Text(phaseLabel(p),style:const TextStyle(fontSize:7.5)),onSelected:(_)=>setState(()=>phaseFilter=p))))])))]);}),
        const SizedBox(height:12),
        Row(children:[Expanded(child:Text('${visible.length} STATE${visible.length==1?'':'S'} SHOWN',style:const TextStyle(color:AppTheme.green,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.55))),Text('auto refresh • 20s',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5))]),
        const SizedBox(height:8),
        if(loading&&data==null)const SizedBox(height:220,child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(color:AppTheme.cyan),SizedBox(height:10),Text('Loading all state build telemetry…',style:TextStyle(color:AppTheme.textMuted,fontSize:9))])))
        else if(data==null)_DashboardError(title:'National expansion view could not load',message:'$lastError',onRetry:()=>refresh())
        else if(visible.isEmpty)const SizedBox(height:120,child:Center(child:Text('No states match this filter.',style:TextStyle(color:AppTheme.textMuted))) )
        else LayoutBuilder(builder:(context,c){final columns=c.maxWidth>=1080?3:c.maxWidth>=690?2:1;final gap=12.0;final cardWidth=(c.maxWidth-gap*(columns-1))/columns;return Wrap(spacing:gap,runSpacing:0,children:visible.map((s)=>stateCard(s,cardWidth)).toList());}),
        const SizedBox(height:2),const Text('Verified completion never advances from a count alone. Each state remains BUILDING until the required BridgePoint gates actually pass.',style:TextStyle(color:AppTheme.textMuted,fontSize:7.5,height:1.4)),
        const Text('bridgepoint-v380-owner-national-cockpit',style:TextStyle(fontSize:0,color:Colors.transparent)),
      ]),
    ));
  }
}

class _OwnerStateDonutV380 extends StatelessWidget{
  const _OwnerStateDonutV380({required this.overall,required this.phase,required this.color,required this.size});
  final double overall;final double? phase;final Color color;final double size;
  @override Widget build(BuildContext context)=>SizedBox(width:size,height:size,child:CustomPaint(painter:_OwnerStateDonutPainterV380(overall:overall,phase:phase,color:color),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${overall.toStringAsFixed(overall>=10?0:1)}%',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)),if(phase!=null)Text('${phase!.toStringAsFixed(0)}% phase',style:TextStyle(color:color,fontSize:5.8,fontWeight:FontWeight.w900))]))));
}
class _OwnerStateDonutPainterV380 extends CustomPainter{
  const _OwnerStateDonutPainterV380({required this.overall,required this.phase,required this.color});final double overall;final double? phase;final Color color;
  @override void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height/2);final radius=(size.shortestSide/2)-5;
    final bg=Paint()..style=PaintingStyle.stroke..strokeWidth=6..strokeCap=StrokeCap.round..color=Colors.white.withOpacity(.08);
    final fg=Paint()..style=PaintingStyle.stroke..strokeWidth=6..strokeCap=StrokeCap.round..shader=LinearGradient(colors:[color,AppTheme.cyan]).createShader(Rect.fromCircle(center:center,radius:radius));
    canvas.drawCircle(center,radius,bg);canvas.drawArc(Rect.fromCircle(center:center,radius:radius),-1.57079632679,6.28318530718*(overall.clamp(0,100).toDouble()/100),false,fg);
    if(phase!=null){final inner=radius-8;final pb=Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=color.withOpacity(.16);final pf=Paint()..style=PaintingStyle.stroke..strokeWidth=2..strokeCap=StrokeCap.round..color=color.withOpacity(.85);canvas.drawCircle(center,inner,pb);canvas.drawArc(Rect.fromCircle(center:center,radius:inner),-1.57079632679,6.28318530718*(phase!.clamp(0,100).toDouble()/100),false,pf);}
  }
  @override bool shouldRepaint(covariant _OwnerStateDonutPainterV380 old)=>old.overall!=overall||old.phase!=phase||old.color!=color;
}
class _OwnerStateStepStripV380 extends StatelessWidget{
  const _OwnerStateStepStripV380({required this.steps,required this.color});final List<Map<String,dynamic>> steps;final Color color;
  Color c(dynamic status)=>switch('${status??'PENDING'}'){'SUCCEEDED'||'SKIPPED'=>AppTheme.green,'RUNNING'=>AppTheme.cyan,'FAILED'=>AppTheme.red,'WAITING_APPROVAL'||'BLOCKED'=>AppTheme.amber,_=>Colors.white12};
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('13-GATE BUILD',style:TextStyle(color:AppTheme.textMuted,fontSize:6.8,fontWeight:FontWeight.w900,letterSpacing:.4)),const SizedBox(height:5),Row(children:steps.map((s)=>Expanded(child:Tooltip(message:'${s['step_name']??s['step_key']} • ${s['status']??s['step_status']}',child:Container(height:5,margin:const EdgeInsets.only(right:2),decoration:BoxDecoration(color:c(s['status']??s['step_status']),borderRadius:BorderRadius.circular(99)))))).toList())]);
}
'''
text=text[:panel_start]+new_panel+'\n'+text[panel_end:]

old_national="""          if(nationalZoom){\n            markerChild=Container(\n              decoration:BoxDecoration(\n                shape:BoxShape.circle,\n                color:marketColor.withOpacity(.42),\n                border:Border.all(color:marketColor.withOpacity(.85),width:1.5),\n              ),\n            );\n"""
new_national="""          if(nationalZoom){\n            markerChild=widget.ownerMode\n              ?_OwnerMapProgressDotV380(progress:((market['owner_progress_pct'] as num?)?.toDouble()??0),color:marketColor)\n              :Container(\n                decoration:BoxDecoration(\n                  shape:BoxShape.circle,\n                  color:marketColor.withOpacity(.42),\n                  border:Border.all(color:marketColor.withOpacity(.85),width:1.5),\n                ),\n              );\n"""
if text.count(old_national)!=1:raise SystemExit(f'v380 map national anchor count {text.count(old_national)}')
text=text.replace(old_national,new_national,1)
old_size="""          final markerSize=nationalZoom?12.0:regionalZoom?25.0:82.0;\n          final markerHeight=nationalZoom?12.0:regionalZoom?25.0:52.0;\n"""
new_size="""          final markerSize=nationalZoom?(widget.ownerMode?27.0:12.0):regionalZoom?25.0:82.0;\n          final markerHeight=nationalZoom?(widget.ownerMode?27.0:12.0):regionalZoom?25.0:52.0;\n"""
if text.count(old_size)!=1:raise SystemExit('v380 marker-size anchor drift')
text=text.replace(old_size,new_size,1)
old_tip="message:'${market['state_name']} • ${market['data_status']} • ${_formatExpansionEtaV321(market['build_eta'])}',"
new_tip="message:widget.ownerMode?'${market['state_name']} • ${market['owner_progress_pct']??0}% verified • ${market['owner_current_phase']??market['data_status']} • ${_formatExpansionEtaV321(market['build_eta'])}':'${market['state_name']} • ${market['data_status']} • ${_formatExpansionEtaV321(market['build_eta'])}',"
if text.count(old_tip)!=1:raise SystemExit('v380 map tooltip anchor drift')
text=text.replace(old_tip,new_tip,1)
old_banner="            if(buildingMarkets.isNotEmpty)...[const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),"
owner_banner="""            if(widget.ownerMode)...[const SizedBox(height:10),Builder(builder:(context){\n              final ownerStates=coverageMarkets.where((m)=>m['owner_progress_pct']!=null).toList();\n              final avg=ownerStates.isEmpty?0.0:ownerStates.fold<double>(0,(a,m)=>a+((m['owner_progress_pct'] as num?)?.toDouble()??0))/ownerStates.length;\n              final phases=<String,int>{};for(final m in ownerStates){final p='${m['owner_current_phase']??'WAITING'}';phases[p]=(phases[p]??0)+1;}\n              final top=phases.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));\n              return Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.055),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),child:Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:8,runSpacing:6,children:[const Icon(Icons.donut_large_rounded,color:AppTheme.cyan,size:16),Text('${ownerStates.length} STATE BUILDS • ${avg.toStringAsFixed(1)}% AVG VERIFIED',style:const TextStyle(color:Colors.white,fontSize:8.5,fontWeight:FontWeight.w900)),...top.take(3).map((e)=>_OpportunityChip(label:'${e.key.replaceAll('_',' ')} ${e.value}',color:phaseColorForOwnerMapV380(e.key))) ]));\n            })],\n            if(buildingMarkets.isNotEmpty)...[const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),"""
if text.count(old_banner)!=1:raise SystemExit('v380 map banner anchor drift')
text=text.replace(old_banner,owner_banner,1)

insert_before='class _OwnerExpansionPanel extends StatefulWidget{'
helpers=r'''Color phaseColorForOwnerMapV380(String phase)=>switch(phase){'SIGNALS_EVIDENCE'||'SCORE_OPPORTUNITIES'=>AppTheme.cyan,'NORMALIZE_MATCH'||'CONTEXT_LAYERS'=>AppTheme.blue,'PROPERTY_FOUNDATION'=>AppTheme.amber,'SECURITY_ENTITLEMENTS'||'CUSTOMER_QA'||'ACTIVATE'=>AppTheme.green,_=>const Color(0xFF9B7BFF)};
class _OwnerMapProgressDotV380 extends StatelessWidget{
  const _OwnerMapProgressDotV380({required this.progress,required this.color});final double progress;final Color color;
  @override Widget build(BuildContext context)=>Stack(alignment:Alignment.center,children:[SizedBox(width:25,height:25,child:CircularProgressIndicator(value:(progress.clamp(0,100)/100).toDouble(),strokeWidth:3,color:color,backgroundColor:Colors.black.withOpacity(.42))),Text('${progress.round()}',style:const TextStyle(color:Colors.white,fontSize:6,fontWeight:FontWeight.w900))]);
}

'''
idx=text.index(insert_before)
text=text[:idx]+helpers+text[idx:]
text += "\nconst String _bridgePointOwnerNationalCockpitV380='bridgepoint-v380-owner-national-cockpit | 49-state cached progress | owner donuts | map progress rings | no duplicate expansion floating controls';\n"
main.write_text(text,encoding='utf-8')

html=web.read_text(encoding='utf-8')
if 'bp-expansion-launcher' in html:
    css_pos=html.index('#bp-expansion-launcher')
    css_start=html.rfind('<style>',0,css_pos)
    css_end=html.index('</style>',css_pos)+len('</style>')
    if css_start<0:raise SystemExit('v380 web expansion CSS start not found')
    html=html[:css_start]+html[css_end:]
    launch=html.index('<button id="bp-expansion-launcher"')
    script=html.index('<script>',launch)
    html=html[:launch]+html[script:]
    script_start=html.index('<script>',launch)
    iife=html.index('(()=>{',script_start)
    script_end=html.index('</script>',iife)+len('</script>')
    html=html[:script_start]+html[script_end:]
if 'bp-expansion-launcher' in html or '>Expansion Engine<' in html:
    raise SystemExit('v380 duplicate web expansion launcher still present')
web.write_text(html,encoding='utf-8')

final=main.read_text(encoding='utf-8')
for needle in ['NATIONAL EXPANSION COMMAND','bridgepoint_owner_national_progress_v377','_OwnerStateDonutV380','_OwnerMapProgressDotV380','bridgepoint-v380-owner-national-cockpit']:
    if needle not in final:raise SystemExit(f'v380 missing generated marker: {needle}')
if "heroTag:'bridgepoint-expansion-fab-v212'" in final:raise SystemExit('v380 duplicate Flutter expansion FAB still present')
print('Applied v380 owner national cockpit, map progress rings, and duplicate-expansion-control cleanup.')
