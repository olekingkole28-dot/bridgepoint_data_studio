from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v263-package-aware-ai'
if marker in body:
    print('Package-aware BridgePoint AI v263 already applied.')
    raise SystemExit(0)

start=body.find('class _BridgePointAiSearchDialogV248 extends StatefulWidget{')
end=body.find('final stt.SpeechToText _bridgePointSpeechV258', start)
if start<0 or end<0:
    raise SystemExit(f'v263 AI class anchors {start} {end}')

replacement=r'''String _bridgePointAiMoneyV263(dynamic value){
  final number=double.tryParse('${value??''}');
  if(number==null)return '—';
  final raw=number.round().abs().toString();
  final parts=<String>[];
  for(var i=raw.length;i>0;i-=3){parts.insert(0,raw.substring(i-3<0?0:i-3,i));}
  return '${number<0?'-':''}\$${parts.join(',')}';
}

String _bridgePointAiDateV263(dynamic value){
  final d=DateTime.tryParse('${value??''}')?.toLocal();
  if(d==null)return '';
  const months=<String>['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month-1]} ${d.day}, ${d.year}';
}

class _BridgePointAiSearchDialogV248 extends StatefulWidget{
  const _BridgePointAiSearchDialogV248({required this.initialQuery,required this.onNavigateLabel,required this.onPropertySelected});
  final String initialQuery;final ValueChanged<String> onNavigateLabel;final ValueChanged<Map<String,dynamic>> onPropertySelected;
  @override State<_BridgePointAiSearchDialogV248> createState()=>_BridgePointAiSearchDialogV248State();
}
class _BridgePointAiSearchDialogV248State extends State<_BridgePointAiSearchDialogV248>{
  late final TextEditingController controller;late Future<Map<String,dynamic>> request;String query='';
  @override void initState(){super.initState();controller=TextEditingController(text:widget.initialQuery);query=widget.initialQuery;request=_callRpc('bridgepoint_ai_answer_v262',{'p_query':query});}
  @override void dispose(){controller.dispose();super.dispose();}
  void _search(String value){final q=value.trim();if(q.length<2)return;setState((){query=q;request=_callRpc('bridgepoint_ai_answer_v262',{'p_query':q});});}
  void _action(String target,Map<String,dynamic> data){
    if(target=='PROPERTY'){
      final property=_bpMap(data['property']);
      if(property.isNotEmpty){widget.onPropertySelected(property);return;}
    }
    final label=switch(target){
      'PROPERTIES'=>'Properties','OPPORTUNITIES'=>'Opportunities','INTELLIGENCE_MAP'=>'Intelligence Map','COMMUNITY'=>'Community',
      'PROPERTY_MEMORY'=>'My Home','ADVANCED_EVIDENCE'=>'Properties','PACKAGES'=>'Packages',_=>'Daily Brief'};
    Navigator.pop(context);widget.onNavigateLabel(label);
  }

  Widget _metric(String label,String value,IconData icon,Color color)=>Container(
    constraints:const BoxConstraints(minWidth:122),padding:const EdgeInsets.all(10),
    decoration:BoxDecoration(color:color.withOpacity(.075),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.18))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:16),const SizedBox(height:6),Text(value,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w700))]));

  @override Widget build(BuildContext context)=>AlertDialog(
    backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(12),contentPadding:const EdgeInsets.fromLTRB(18,6,18,10),
    title:Row(children:[
      Container(width:44,height:44,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue]),borderRadius:BorderRadius.circular(14),boxShadow:[BoxShadow(color:AppTheme.cyan.withOpacity(.18),blurRadius:18)]),child:const Icon(Icons.auto_awesome_rounded,color:Colors.white)),
      const SizedBox(width:11),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('BridgePoint AI',style:TextStyle(fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Ask naturally • package-aware • grounded in BridgePoint evidence',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w600))])),
      IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded)),
    ]),
    content:SizedBox(width:960,height:710,child:Column(children:[
      TextField(
        controller:controller,textInputAction:TextInputAction.search,
        onTap:(){if(controller.text.isNotEmpty)controller.selection=TextSelection(baseOffset:0,extentOffset:controller.text.length);},
        onSubmitted:_search,
        decoration:InputDecoration(
          prefixIcon:const Icon(Icons.auto_awesome_rounded,color:AppTheme.cyan),
          suffixIcon:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(tooltip:'Talk to BridgePoint AI',icon:const Icon(Icons.mic_rounded,color:AppTheme.cyan),onPressed:()=>_bridgePointVoiceIntoControllerV258(context,controller)),
            IconButton(tooltip:'Clear search',icon:const Icon(Icons.close_rounded),onPressed:(){controller.clear();setState(()=>query='');}),
            IconButton(tooltip:'Ask BridgePoint',icon:const Icon(Icons.arrow_forward_rounded),onPressed:()=>_search(controller.text)),
          ]),
          hintText:'Ask anything — “What is happening at 394 High St Middletown, CT?”',
          helperText:'Tap existing text to select it all • × clears it • microphone lets you speak your question',
          filled:true,fillColor:AppTheme.panelSoft.withOpacity(.72),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:Colors.white.withOpacity(.08))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:const BorderSide(color:AppTheme.cyan,width:1.4)),
        ),
      ),const SizedBox(height:10),
      Expanded(child:FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return Center(child:Container(width:430,padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.08),AppTheme.blue.withOpacity(.05)]),borderRadius:BorderRadius.circular(18),border:Border.all(color:AppTheme.cyan.withOpacity(.15))),child:const Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.auto_awesome_rounded,color:AppTheme.cyan,size:30),SizedBox(height:14),LinearProgressIndicator(color:AppTheme.cyan,backgroundColor:Colors.white12),SizedBox(height:12),Text('BridgePoint AI is resolving the property and checking the intelligence your package can see…',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70,fontSize:10,height:1.45))])));
        if(snapshot.hasError)return Center(child:_DashboardError(title:'BridgePoint AI search could not load',message:'BridgePoint could not finish that answer. Please retry — your question has been kept.',onRetry:()=>_search(query)));
        final data=snapshot.data??const <String,dynamic>{};
        final property=_bpMap(data['property']);final heartbeat=_bpMap(data['heartbeat']);final packageContext=_bpMap(data['package_context']);
        final signals=_detailList(data['signals']);final opportunities=_detailList(data['opportunities']);final patterns=_detailList(data['patterns']);final upgrades=_detailList(data['upgrade_suggestions']);final actions=_detailList(data['quick_actions']);final activePackages=_detailList(packageContext['active_packages']);
        final topicAccess=packageContext['topic_access']!=false;final address='${property['full_address']??''}';final headline='${data['headline']??'BridgePoint AI answer'}';final summary='${data['summary']??''}';
        final vitals=_detailList(heartbeat['vitals']);final physical=_bpMap(data['physical_intelligence']);final buildings=_detailList(physical['building_2d']);
        return ListView(padding:const EdgeInsets.only(bottom:8),children:[
          Container(width:double.infinity,padding:const EdgeInsets.all(17),decoration:BoxDecoration(
            gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.13),AppTheme.blue.withOpacity(.08),AppTheme.panelSoft.withOpacity(.82)]),borderRadius:BorderRadius.circular(18),border:Border.all(color:(topicAccess?AppTheme.cyan:AppTheme.amber).withOpacity(.22))),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[Icon(topicAccess?Icons.auto_awesome_rounded:Icons.lock_outline_rounded,color:topicAccess?AppTheme.cyan:AppTheme.amber,size:18),const SizedBox(width:7),Expanded(child:Text('${data['topic_label']??'Property intelligence'}'.toUpperCase(),style:TextStyle(color:topicAccess?AppTheme.cyan:AppTheme.amber,fontSize:8.5,fontWeight:FontWeight.w900,letterSpacing:.7))),
                if(activePackages.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.09),borderRadius:BorderRadius.circular(99),border:Border.all(color:AppTheme.green.withOpacity(.2))),child:Text('${activePackages.first['package_name']??'Your package'}',style:const TextStyle(color:AppTheme.green,fontSize:7.5,fontWeight:FontWeight.w900))) ]),
              const SizedBox(height:9),Text(headline,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,height:1.18)),
              if(summary.isNotEmpty)...[const SizedBox(height:8),Text(summary,style:const TextStyle(color:Colors.white70,fontSize:10.5,height:1.55))],
              if(address.isNotEmpty)...[const SizedBox(height:11),Row(children:[const Icon(Icons.location_on_rounded,color:AppTheme.cyan,size:15),const SizedBox(width:5),Expanded(child:Text(address,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800)))])],
            ])),

          if(property.isNotEmpty)...[
            const SizedBox(height:13),
            Row(children:[const Icon(Icons.home_work_rounded,color:AppTheme.blue,size:18),const SizedBox(width:7),const Text('Property snapshot',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900)),const Spacer(),Text('${property['property_type']??''}'.replaceAll('_',' '),style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w800))]),const SizedBox(height:8),
            Wrap(spacing:8,runSpacing:8,children:[
              _metric('Heartbeat','${heartbeat['state']??'MONITOR'}',Icons.favorite_rounded,AppTheme.cyan),
              _metric('Current score','${heartbeat['current_score']??'—'}',Icons.speed_rounded,AppTheme.green),
              _metric('Last 14 days','${heartbeat['recent_observations_14d']??0} changes',Icons.bolt_rounded,AppTheme.amber),
              _metric('Year built','${property['year_built']??'—'}',Icons.calendar_month_rounded,AppTheme.blue),
              _metric('Market value',_bridgePointAiMoneyV263(property['market_total_value']),Icons.attach_money_rounded,AppTheme.green),
              _metric('Parcel','${property['parcel_number']??'—'}',Icons.grid_4x4_rounded,AppTheme.textMuted),
            ]),
            if(vitals.isNotEmpty)...[const SizedBox(height:9),Wrap(spacing:6,runSpacing:6,children:vitals.take(6).map((v){final active='${v['state']??''}'.toUpperCase().contains('ACTIVE');return Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:(active?AppTheme.amber:AppTheme.panelSoft).withOpacity(active ? .12 : .78),borderRadius:BorderRadius.circular(99),border:Border.all(color:(active?AppTheme.amber:Colors.white).withOpacity(active ? .22 : .07))),child:Text('${v['name']??''} • ${v['state']??''}',style:TextStyle(color:active?AppTheme.amber:Colors.white60,fontSize:7.5,fontWeight:FontWeight.w800)));}).toList())],
          ],

          if(signals.isNotEmpty)...[
            const SizedBox(height:16),const Row(children:[Icon(Icons.radar_rounded,color:AppTheme.cyan,size:18),SizedBox(width:7),Text('What BridgePoint sees',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900))]),const SizedBox(height:5),const Text('BridgePoint separates property-matched evidence from broader area context so customers can see what each item really means.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)),const SizedBox(height:8),
            ...signals.take(8).map((s){final area='${s['scope']??''}'=='AREA_CONTEXT';return Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.72),borderRadius:BorderRadius.circular(12),border:Border.all(color:(area?AppTheme.blue:AppTheme.green).withOpacity(.13))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:32,height:32,decoration:BoxDecoration(color:(area?AppTheme.blue:AppTheme.green).withOpacity(.09),borderRadius:BorderRadius.circular(9)),child:Icon(area?Icons.public_rounded:Icons.verified_rounded,color:area?AppTheme.blue:AppTheme.green,size:16)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${s['title']??s['signal_name']??'Intelligence signal'}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w900))),Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:(area?AppTheme.blue:AppTheme.green).withOpacity(.08),borderRadius:BorderRadius.circular(99)),child:Text(area?'AREA CONTEXT':'MATCHED EVIDENCE',style:TextStyle(color:area?AppTheme.blue:AppTheme.green,fontSize:6.8,fontWeight:FontWeight.w900)))]),const SizedBox(height:4),Text('${s['signal_family']??''}'.replaceAll('_',' '),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.8)),if(_bridgePointAiDateV263(s['detected_at']).isNotEmpty)Text(_bridgePointAiDateV263(s['detected_at']),style:const TextStyle(color:Colors.white38,fontSize:7.3))]))]));}).toList(),
          ],

          if(opportunities.isNotEmpty)...[
            const SizedBox(height:15),const Row(children:[Icon(Icons.bolt_rounded,color:AppTheme.green,size:18),SizedBox(width:7),Text('Opportunities your package unlocks',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900))]),const SizedBox(height:8),
            ...opportunities.take(5).map((o)=>Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(11),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.green.withOpacity(.08),AppTheme.panelSoft.withOpacity(.8)]),borderRadius:BorderRadius.circular(12),border:Border.all(color:AppTheme.green.withOpacity(.15))),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${o['title']??o['model_name']??'Opportunity'}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${o['explanation']??o['description']??''}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white60,fontSize:8,height:1.35))])),const SizedBox(width:8),_OpportunityChip(label:'${o['score']??'—'}',color:AppTheme.green)])),
          ],

          if(patterns.isNotEmpty)...[
            const SizedBox(height:15),const Row(children:[Icon(Icons.hub_rounded,color:AppTheme.blue,size:18),SizedBox(width:7),Text('Patterns',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900))]),const SizedBox(height:8),
            Wrap(spacing:7,runSpacing:7,children:patterns.take(6).map((p)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.07),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.blue.withOpacity(.13))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${p['pattern_name']??'Pattern'}',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text('${p['intelligence_stage']??''}'.replaceAll('_',' '),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.2))])).toList()),
          ],

          if(buildings.isNotEmpty)...[
            const SizedBox(height:15),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.68),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.06))),child:Row(children:[const Icon(Icons.view_in_ar_rounded,color:AppTheme.cyan,size:19),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Physical property intelligence',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('BridgePoint has ${buildings.first['footprint_count']??1} mapped building footprint${('${buildings.first['footprint_count']??1}'=='1')?'':'s'} tied to this property.',style:const TextStyle(color:Colors.white60,fontSize:8.2,height:1.35))]))])),
          ],

          if(!topicAccess || upgrades.isNotEmpty)...[
            const SizedBox(height:16),Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.amber.withOpacity(.11),AppTheme.blue.withOpacity(.05)]),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppTheme.amber.withOpacity(.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Row(children:[Icon(Icons.lock_open_rounded,color:AppTheme.amber,size:18),SizedBox(width:7),Text('Unlock more intelligence',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900))]),const SizedBox(height:5),Text(topicAccess?'BridgePoint found intelligence beyond the current package. Nothing locked is exposed until the matching package is active.':'That topic is outside the current package. BridgePoint kept the locked intelligence private and matched the closest packages below.',style:const TextStyle(color:Colors.white60,fontSize:8.5,height:1.4)),
              if(upgrades.isNotEmpty)...[const SizedBox(height:10),...upgrades.map((u)=>Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.navy.withOpacity(.45),borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white.withOpacity(.06))),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${u['package_name']??'BridgePoint package'}',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text('${u['description']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5,height:1.3))])),const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${_bridgePointAiMoneyV263(u['monthly_price'])}/mo',style:const TextStyle(color:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:4),TextButton(onPressed:()=>_action('PACKAGES',data),child:const Text('View plan',style:TextStyle(fontSize:8)))])]))],
            ])),
          ],

          if(actions.isNotEmpty)...[const SizedBox(height:15),const Text('Keep going',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(height:7),Wrap(spacing:7,runSpacing:7,children:actions.where((a)=>a['enabled']!=false).map((a)=>ActionChip(avatar:Icon('${a['target']}'=='PROPERTY'?Icons.home_work_rounded:'${a['target']}'=='PACKAGES'?Icons.workspace_premium_rounded:Icons.arrow_forward_rounded,size:14,color:'${a['target']}'=='PACKAGES'?AppTheme.amber:AppTheme.cyan),label:Text('${a['label']}',style:const TextStyle(fontSize:8.5,fontWeight:FontWeight.w800)),onPressed:()=>_action('${a['target']}',data))).toList())],
          const SizedBox(height:14),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.verified_user_outlined,color:AppTheme.green,size:14),const SizedBox(width:6),Expanded(child:Text('${data['privacy_notice']??'BridgePoint AI only uses intelligence your account is allowed to access.'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.8,height:1.4)))])
        ]);
      })),
    ])),actions:const []);
}

'''
body=body[:start]+replacement+body[end:]

old_owner="""                    if(_effectiveOwnerMode)Positioned(
                      right:desktop?22:14,bottom:desktop?22:14,
                      child:SafeArea(child:Tooltip(message:'Automatic State Expansion • Owner only',child:FloatingActionButton.small(
                        heroTag:'bridgepoint-expansion-fab-v212',onPressed:()=>_navigateTrainingLabel('Owner Center'),backgroundColor:AppTheme.green,foregroundColor:const Color(0xFF06111F),elevation:7,
                        child:const Icon(Icons.public_rounded,size:21),
                      ))),
                    ),
"""
new_owner="""                    Positioned(
                      right:desktop?22:14,bottom:desktop?22:14,
                      child:SafeArea(child:Material(color:Colors.transparent,child:InkWell(
                        borderRadius:BorderRadius.circular(99),onTap:()=>_showBridgePointAiPromptV248(context,_openBridgePointAiV248),
                        child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),decoration:BoxDecoration(
                          gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue]),borderRadius:BorderRadius.circular(99),
                          boxShadow:[BoxShadow(color:AppTheme.cyan.withOpacity(.22),blurRadius:20,offset:const Offset(0,6))]),
                          child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.auto_awesome_rounded,color:Colors.white,size:18),if(desktop)...const [SizedBox(width:7),Text('Ask BridgePoint AI',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900))]]),
                        ),
                      ))),
                    ),
                    if(_effectiveOwnerMode)Positioned(
                      right:desktop?22:14,bottom:desktop?78:70,
                      child:SafeArea(child:Tooltip(message:'Automatic State Expansion • Owner only',child:FloatingActionButton.small(
                        heroTag:'bridgepoint-expansion-fab-v212',onPressed:()=>_navigateTrainingLabel('Owner Center'),backgroundColor:AppTheme.green,foregroundColor:const Color(0xFF06111F),elevation:7,
                        child:const Icon(Icons.public_rounded,size:21),
                      ))),
                    ),
"""
if body.count(old_owner)!=1:
    raise SystemExit(f'v263 owner FAB anchor {body.count(old_owner)}')
body=body.replace(old_owner,new_owner,1)

body += "\nconst String _bridgePointPackageAwareAiV263='bridgepoint-v263-package-aware-ai | bridgepoint_ai_answer_v262 | Ask BridgePoint AI';\n"
path.write_text(body,encoding='utf-8')
print('Applied package-aware BridgePoint AI answer experience v263.')
