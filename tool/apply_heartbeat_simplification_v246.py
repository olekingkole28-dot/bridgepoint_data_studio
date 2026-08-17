from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v246-heartbeat-simplification'
if marker in body:
    print('v246 already applied')
    raise SystemExit(0)

old="""class _PropertyIntelligenceDialogState
    extends State<_PropertyIntelligenceDialog> {
  late Future<Map<String, dynamic>> _request;
"""
new="""class _PropertyIntelligenceDialogState
    extends State<_PropertyIntelligenceDialog> {
  late Future<Map<String, dynamic>> _request;
  bool _showAdvanced=false;
"""
if body.count(old)!=1: raise SystemExit(f'v246 property state anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""    final results=await Future.wait<Object>([
      http.post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_property_detail_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({'p_property_id': widget.propertyId}),
        ).timeout(const Duration(seconds: 30)),
      _callRpc('bridgepoint_property_timeline_v78',{'p_property_id':widget.propertyId,'p_limit':120})
        .catchError((_)=><String,dynamic>{}),
    ]);
"""
new="""    final results=await Future.wait<Object>([
      http.post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_property_detail_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({'p_property_id': widget.propertyId}),
        ).timeout(const Duration(seconds: 30)),
      _callRpc('bridgepoint_property_timeline_v78',{'p_property_id':widget.propertyId,'p_limit':120})
        .catchError((_)=><String,dynamic>{}),
      _callRpc('bridgepoint_property_heartbeat_v245',{'p_property_id':widget.propertyId})
        .catchError((_)=><String,dynamic>{}),
      _callRpc('bridgepoint_property_memory_questions_v237',{'p_property_id':widget.propertyId,'p_audience':'ALL'})
        .catchError((_)=><String,dynamic>{}),
      _callRpc('bridgepoint_property_twins_v232',{'p_property_id':widget.propertyId,'p_limit':8})
        .catchError((_)=><String,dynamic>{}),
    ]);
"""
if body.count(old)!=1: raise SystemExit(f'v246 load anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""    if(timeline['timeline'] is List){
      detail['timeline']=timeline['timeline'];
      detail['timeline_explanation']=timeline['explanation'];
      final summary=detail['summary'] is Map?Map<String,dynamic>.from(detail['summary'] as Map):<String,dynamic>{};
      summary['timeline_item_count']=timeline['item_count'];detail['summary']=summary;
    }
    return detail;
"""
new="""    if(timeline['timeline'] is List){
      detail['timeline']=timeline['timeline'];
      detail['timeline_explanation']=timeline['explanation'];
      final summary=detail['summary'] is Map?Map<String,dynamic>.from(detail['summary'] as Map):<String,dynamic>{};
      summary['timeline_item_count']=timeline['item_count'];detail['summary']=summary;
    }
    detail['heartbeat']=results[2];
    detail['property_memory']=results[3];
    detail['twins']=results[4];
    return detail;
"""
if body.count(old)!=1: raise SystemExit(f'v246 result anchor {body.count(old)}')
body=body.replace(old,new,1)

old="""            final modernOpportunities =
                _detailList(data['modern_opportunities']);

            final address =
"""
new="""            final modernOpportunities =
                _detailList(data['modern_opportunities']);
            final heartbeat=data['heartbeat'] is Map
                ? Map<String,dynamic>.from(data['heartbeat'] as Map)
                : <String,dynamic>{};
            final memory=data['property_memory'] is Map
                ? Map<String,dynamic>.from(data['property_memory'] as Map)
                : <String,dynamic>{};
            final twins=data['twins'] is Map
                ? Map<String,dynamic>.from(data['twins'] as Map)
                : <String,dynamic>{};

            final address =
"""
if body.count(old)!=1: raise SystemExit(f'v246 parse anchor {body.count(old)}')
body=body.replace(old,new,1)

start=body.index("                        _PropertyMediaCard(propertyId:widget.propertyId),",body.index('class _PropertyIntelligenceDialogState'))
end_anchor="""                        _DetailSection(
                          title: 'Property',
"""
end=body.index(end_anchor,start)
replacement="""                        _HeartbeatHeroV246(heartbeat:heartbeat),
                        const SizedBox(height:14),
                        _PropertyMediaCard(propertyId:widget.propertyId),
                        const SizedBox(height:14),
                        LayoutBuilder(builder:(context,c){
                          final compact=c.maxWidth<760;
                          final memoryCard=_PropertyMemorySummaryV246(
                            propertyId:widget.propertyId,
                            heartbeat:heartbeat,
                            memory:memory,
                            onSaved:_reload,
                          );
                          final twinCard=_PropertyTwinsSummaryV246(twins:twins);
                          return compact
                            ? Column(children:[memoryCard,const SizedBox(height:10),twinCard])
                            : Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                Expanded(child:memoryCard),const SizedBox(width:10),Expanded(child:twinCard),
                              ]);
                        }),
                        const SizedBox(height:14),
                        Wrap(
                          spacing:8,runSpacing:8,
                          children:[
                            _MiniStat(label:'HEARTBEAT',value:'${heartbeat['state']??'LEARNING'}'),
                            _MiniStat(label:'OPPORTUNITY',value:heartbeat['opportunity_strength']==null?'—':_formatDecimal(heartbeat['opportunity_strength'])),
                            _MiniStat(label:'CONFIDENCE',value:'${heartbeat['confidence_label']??'BUILDING'}'),
                            _MiniStat(label:'MEMORY',value:'${_bpMap(heartbeat['property_memory'])['fact_count']??0} facts'),
                            _MiniStat(label:'TIMELINE',value:'${summary['timeline_item_count']??timeline.length}'),
                            _MiniStat(label:'ASSESSED',value:assessed==null?'—':'\\$${_formatInteger(assessed)}'),
                          ],
                        ),
                        const SizedBox(height:18),
"""
body=body[:start]+replacement+body[end:]

body=body.replace("title: 'Property',\n                          subtitle: 'Canonical current property record with recorded ownership and provenance',","title: 'Property Snapshot',\n                          subtitle: 'The recorded facts BridgePoint currently knows about this property',",1)

modern_anchor="""                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Modern BridgePoint Intelligence',
"""
idx=body.index(modern_anchor,body.index('class _PropertyIntelligenceDialogState'))
advanced_open="""                        const SizedBox(height:14),
                        Container(
                          width:double.infinity,
                          padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),
                          decoration:BoxDecoration(
                            color:AppTheme.panelSoft.withOpacity(.55),
                            borderRadius:BorderRadius.circular(12),
                            border:Border.all(color:Colors.white.withOpacity(.07)),
                          ),
                          child:Row(children:[
                            const Icon(Icons.manage_search_rounded,color:AppTheme.cyan,size:20),
                            const SizedBox(width:9),
                            const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                              Text('Advanced intelligence details',style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w900)),
                              SizedBox(height:2),
                              Text('Models, source records, patterns, physical baselines and raw evidence stay here when you need the technical view.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.7,height:1.35)),
                            ])),
                            const SizedBox(width:8),
                            TextButton.icon(
                              onPressed:()=>setState(()=>_showAdvanced=!_showAdvanced),
                              icon:Icon(_showAdvanced?Icons.expand_less_rounded:Icons.expand_more_rounded),
                              label:Text(_showAdvanced?'Hide details':'Open details'),
                            ),
                          ]),
                        ),
                        if(_showAdvanced)...[
                        const SizedBox(height:14),
                        _DetailSection(
                          title: 'BridgePoint Analysis',
"""
body=body[:idx]+advanced_open+body[idx+len(modern_anchor):]
body=body.replace("""                          subtitle:
                              'V37 scoring, V36 compound patterns and V38 opportunity decisions',""","""                          subtitle:
                              'Technical scoring, compound patterns and opportunity decisions',""",1)
body=body.replace("'record_type': 'V37 Property Score'","'record_type': 'Property score detail'",1)
body=body.replace("'record_type': 'V36 Pattern'","'record_type': 'Compound pattern detail'",1)
body=body.replace("'record_type': 'V38 Opportunity'","'record_type': 'Opportunity decision detail'",1)

signal_idx=body.index("title: 'Signals & Evidence'",idx)
timeline_anchor="""                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Property Timeline',
"""
timeline_idx=body.index(timeline_anchor,signal_idx)
close="""                        ],
                        const SizedBox(height:14),
                        _DetailSection(
                          title: 'Property Timeline',
"""
body=body[:timeline_idx]+close+body[timeline_idx+len(timeline_anchor):]

helper_anchor='class _PropertyIntelligenceDialog extends StatefulWidget {'
helper=r'''Color _heartbeatColorV246(String state)=>switch(state.toUpperCase()){
  'ACTIVE'=>const Color(0xFFFF6B6B),
  'ELEVATED'=>const Color(0xFFFFA24B),
  'WATCH'=>const Color(0xFFFFC857),
  'STABLE'=>const Color(0xFF38D49A),
  _=>AppTheme.cyan,
};

IconData _heartbeatVitalIconV246(String name){
  final n=name.toUpperCase();
  if(n.contains('ROOF'))return Icons.roofing_rounded;
  if(n.contains('WATER'))return Icons.water_drop_rounded;
  if(n.contains('FIRE'))return Icons.local_fire_department_rounded;
  if(n.contains('CHANGE'))return Icons.construction_rounded;
  if(n.contains('OWNERSHIP'))return Icons.key_rounded;
  if(n.contains('UTILIT'))return Icons.electric_bolt_rounded;
  if(n.contains('OCCUP'))return Icons.business_rounded;
  return Icons.public_rounded;
}

class _HeartbeatHeroV246 extends StatelessWidget{
  const _HeartbeatHeroV246({required this.heartbeat});
  final Map<String,dynamic> heartbeat;
  @override Widget build(BuildContext context){
    final state='${heartbeat['state']??'LEARNING'}';
    final color=_heartbeatColorV246(state);
    final vitals=_detailList(heartbeat['vitals']);
    final concern='${heartbeat['top_property_concern']??''}'.trim();
    final strength=(heartbeat['opportunity_strength'] as num?)?.toDouble();
    return Container(
      width:double.infinity,padding:const EdgeInsets.all(18),
      decoration:BoxDecoration(
        gradient:LinearGradient(colors:[color.withOpacity(.16),AppTheme.panel.withOpacity(.94),AppTheme.blue.withOpacity(.08)],begin:Alignment.topLeft,end:Alignment.bottomRight),
        borderRadius:BorderRadius.circular(20),border:Border.all(color:color.withOpacity(.42),width:1.2),
        boxShadow:[BoxShadow(color:color.withOpacity(.10),blurRadius:24,spreadRadius:1)],
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
          Container(width:58,height:58,decoration:BoxDecoration(shape:BoxShape.circle,color:color.withOpacity(.12),border:Border.all(color:color.withOpacity(.42),width:1.4)),child:Stack(alignment:Alignment.center,children:[
            TweenAnimationBuilder<double>(tween:Tween(begin:.72,end:1),duration:const Duration(milliseconds:950),curve:Curves.easeOutCubic,builder:(context,value,child)=>Transform.scale(scale:value,child:Container(width:43,height:43,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:color.withOpacity((1-value)*1.8+.08),width:2))))),
            Icon(Icons.monitor_heart_rounded,color:color,size:29),
          ])),
          const SizedBox(width:13),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Text('PROPERTY HEARTBEAT',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.1,color:AppTheme.textMuted)),
              const SizedBox(width:8),
              Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:color.withOpacity(.14),borderRadius:BorderRadius.circular(20),border:Border.all(color:color.withOpacity(.34))),child:Text(state,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.6))),
            ]),
            const SizedBox(height:5),
            Text('${heartbeat['headline']??'BridgePoint is learning this property.'}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,height:1.15)),
            if(concern.isNotEmpty)...[const SizedBox(height:4),Text('Main thing to watch: $concern${strength==null?'':' • ${strength.round()}/100 opportunity strength'}',style:TextStyle(color:color,fontSize:9.5,fontWeight:FontWeight.w800))],
          ])),
        ]),
        const SizedBox(height:13),
        Text('${heartbeat['why_it_matters']??'BridgePoint is comparing current activity with this property’s history.'}',style:const TextStyle(color:Colors.white70,fontSize:10.5,height:1.5)),
        const SizedBox(height:11),
        Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:Colors.black.withOpacity(.13),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.05))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.arrow_forward_rounded,color:color,size:17),const SizedBox(width:8),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('WHAT TO DO NEXT',style:TextStyle(color:AppTheme.textMuted,fontSize:7.5,fontWeight:FontWeight.w900,letterSpacing:.7)),
            const SizedBox(height:3),Text('${heartbeat['recommended_next_step']??'BridgePoint will keep monitoring for meaningful change.'}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w700,height:1.4)),
          ])),
        ])),
        if(vitals.isNotEmpty)...[
          const SizedBox(height:13),
          Wrap(spacing:7,runSpacing:7,children:vitals.map((v){
            final vitalState='${v['state']??'QUIET'}';final active=vitalState=='ACTIVE'||vitalState=='CHANGING';final c=active?color:AppTheme.textMuted;
            return Container(constraints:const BoxConstraints(minWidth:126),padding:const EdgeInsets.symmetric(horizontal:9,vertical:8),decoration:BoxDecoration(color:c.withOpacity(active ? .08 : .035),borderRadius:BorderRadius.circular(10),border:Border.all(color:c.withOpacity(active ? .20 : .08))),child:Row(mainAxisSize:MainAxisSize.min,children:[
              Icon(_heartbeatVitalIconV246('${v['name']}'),size:15,color:c),const SizedBox(width:6),
              Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${v['name']}',style:const TextStyle(fontSize:7.8,fontWeight:FontWeight.w900)),Text(vitalState,style:TextStyle(fontSize:7,color:c,fontWeight:FontWeight.w800))]),
            ]));
          }).toList()),
        ],
      ]),
    );
  }
}

class _PropertyMemorySummaryV246 extends StatelessWidget{
  const _PropertyMemorySummaryV246({required this.propertyId,required this.heartbeat,required this.memory,required this.onSaved});
  final String propertyId;final Map<String,dynamic> heartbeat,memory;final VoidCallback onSaved;
  @override Widget build(BuildContext context){
    final mem=_bpMap(heartbeat['property_memory']);final questions=_detailList(memory['questions']);
    final facts=(mem['fact_count'] as num?)?.toInt()??questions.where((q)=>q['answer']!=null).length;final verified=(mem['verified_or_corroborated'] as num?)?.toInt()??0;
    return Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.08),AppTheme.panelSoft.withOpacity(.72)]),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.history_edu_rounded,color:AppTheme.cyan,size:20)),const SizedBox(width:9),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Property Memory',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Help BridgePoint learn what public records can’t see.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5))])),const Icon(Icons.lock_rounded,color:AppTheme.green,size:15)]),
      const SizedBox(height:9),Text('$facts private fact${facts==1?'':'s'} • $verified corroborated or verified',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800)),const SizedBox(height:4),
      const Text('Your entries are private by default. Other BridgePoint customers cannot see your private Property Memory unless you explicitly share it.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.2,height:1.4)),const SizedBox(height:10),
      SizedBox(width:double.infinity,child:FilledButton.tonalIcon(onPressed:questions.isEmpty?null:()=>showDialog<void>(context:context,builder:(_)=>_PropertyMemoryDialogV246(propertyId:propertyId,questions:questions,onSaved:onSaved)),icon:const Icon(Icons.add_home_work_rounded,size:17),label:Text(facts==0?'Tell BridgePoint about this property':'Update Property Memory'))),
    ]));
  }
}

class _PropertyMemoryDialogV246 extends StatefulWidget{
  const _PropertyMemoryDialogV246({required this.propertyId,required this.questions,required this.onSaved});
  final String propertyId;final List<Map<String,dynamic>> questions;final VoidCallback onSaved;
  @override State<_PropertyMemoryDialogV246> createState()=>_PropertyMemoryDialogV246State();
}
class _PropertyMemoryDialogV246State extends State<_PropertyMemoryDialogV246>{
  late List<Map<String,dynamic>> questions;String? savingKey;String? error;
  @override void initState(){super.initState();questions=widget.questions.map((q)=>Map<String,dynamic>.from(q)).toList();}
  List<String> _options(Map<String,dynamic> q)=>(q['options'] is List?(q['options'] as List):const []).map((e)=>'$e').toList();
  Set<String> _selected(Map<String,dynamic> q){final a=q['answer'];if(a is List)return a.map((e)=>'$e').toSet();if(a==null)return <String>{};return {'$a'};}
  Future<void> save(Map<String,dynamic> q,String value)async{
    final key='${q['question_key']}';final multi='${q['input_type']}'=='MULTI_SELECT';final current=_selected(q);dynamic answer=value;
    if(multi){current.contains(value)?current.remove(value):current.add(value);answer=current.toList();}
    setState((){savingKey=key;error=null;});
    try{await _callRpc('bridgepoint_save_property_fact_v237',{'p_property_id':widget.propertyId,'p_question_key':key,'p_answer':answer,'p_visibility':'PRIVATE'});if(!mounted)return;setState((){q['answer']=answer;savingKey=null;});widget.onSaved();}
    catch(e){if(mounted)setState((){savingKey=null;error='$e';});}
  }
  @override Widget build(BuildContext context)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Row(children:[Icon(Icons.lock_rounded,color:AppTheme.green),SizedBox(width:9),Expanded(child:Text('Private Property Memory'))]),content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760,maxHeight:650),child:SizedBox(width:760,height:600,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.07),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.green.withOpacity(.18))),child:const Text('Your answers are private by default. BridgePoint keeps them separate from public records, checks for corroboration when possible, and does not show your private answers to other customers unless you choose to share them.',style:TextStyle(fontSize:9,height:1.45))),
    if(error!=null)...[const SizedBox(height:7),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:8.5))],const SizedBox(height:10),
    Expanded(child:ListView.separated(itemCount:questions.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final q=questions[i];final options=_options(q);final selected=_selected(q);final busy=savingKey=='${q['question_key']}';return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.68),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.06))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('${q['question_text']}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))),if(busy)const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2))]),
      if('${q['help_text']??''}'.isNotEmpty)...[const SizedBox(height:3),Text('${q['help_text']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.35))],const SizedBox(height:8),
      Wrap(spacing:6,runSpacing:6,children:options.map((o)=>ChoiceChip(selected:selected.contains(o),selectedColor:AppTheme.cyan.withOpacity(.18),side:BorderSide(color:selected.contains(o)?AppTheme.cyan.withOpacity(.42):Colors.white10),label:Text(o,style:const TextStyle(fontSize:8)),onSelected:busy?null:(_)=>save(q,o))).toList()),
    ]));})),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Done'))]);
}

class _PropertyTwinsSummaryV246 extends StatelessWidget{
  const _PropertyTwinsSummaryV246({required this.twins});final Map<String,dynamic> twins;
  @override Widget build(BuildContext context){final rows=_detailList(twins['twins']);return Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.blue.withOpacity(.08),AppTheme.panelSoft.withOpacity(.72)]),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.blue.withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.10),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.join_inner_rounded,color:AppTheme.blue,size:20)),const SizedBox(width:9),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Property Twins',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Compare this property with structurally similar properties.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5))]))]),const SizedBox(height:9),
    if(rows.isEmpty)const Text('BridgePoint is still finding reliable twins for this property.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)) else ...[
      Text('${rows.length} close structural twin${rows.length==1?'':'s'} found nearby',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800)),const SizedBox(height:6),
      ...rows.take(3).map((r)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Row(children:[const Icon(Icons.home_work_outlined,size:13,color:AppTheme.blue),const SizedBox(width:6),Expanded(child:Text('${r['municipality']??'Nearby'} • built ${r['year_built']??'—'}',style:const TextStyle(fontSize:8.2))),Text('${(r['similarity'] as num?)?.round()??'—'}% match',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w800))]))),
      const SizedBox(height:3),const Text('BridgePoint can grow these into exposure and outcome twins as verified outcomes accumulate.',style:TextStyle(color:AppTheme.textMuted,fontSize:7.8,height:1.35)),
    ],
  ]));}
}

'''
if body.count(helper_anchor)!=1: raise SystemExit(f'v246 helper anchor {body.count(helper_anchor)}')
body=body.replace(helper_anchor,helper+helper_anchor,1)
body += "\nconst String _bridgePointHeartbeatSimplificationV246='bridgepoint-v246-heartbeat-simplification | PROPERTY HEARTBEAT | Private Property Memory | Property Twins | Advanced intelligence details';\n"

for required in ['bridgepoint_property_heartbeat_v245','Private Property Memory','Advanced intelligence details','Property Twins','bridgepoint-v246-heartbeat-simplification']:
    if required not in body: raise SystemExit(f'v246 missing {required}')
path.write_text(body,encoding='utf-8')
print('Applied BridgePoint Heartbeat-first property experience v246.')
