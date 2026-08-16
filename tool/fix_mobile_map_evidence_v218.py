from pathlib import Path

p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
original=s
edits=0

def once(old,new,label):
    global s,edits
    n=s.count(old)
    if n!=1:
        raise SystemExit(f'{label}: expected 1 match, found {n}')
    s=s.replace(old,new,1);edits+=1

def class_range(name):
    a=s.find('class '+name)
    if a<0: raise SystemExit('missing class '+name)
    j=s.find('{',a);d=0
    for i in range(j,len(s)):
        if s[i]=='{':d+=1
        elif s[i]=='}':
            d-=1
            if d==0:return a,i+1
    raise SystemExit('unclosed class '+name)

def replace_class(name,new):
    global s,edits
    a,b=class_range(name)
    s=s[:a]+new+s[b:];edits+=1

anchor='class _JsonIntelligenceList extends StatelessWidget {'
if anchor not in s: raise SystemExit('Missing JSON intelligence renderer anchor')
if '_bridgePointReadableEvidenceV218' not in s:
    helper=r'''bool _bridgePointInternalLookingTextV218(String value){
  final v=value.toLowerCase().trim();
  const blocked=[
    'case when','coalesce(','greatest(','least(','jsonb_','::numeric','::text',
    'score_breakdown','component_score','raw_positive','raw_negative','formula',
    'rule_expression','model_definition','detector_definition','weight=',
    'coefficient','dedupe_key','storage_mode','matching_precision','source_record_count=',
  ];
  return blocked.any(v.contains)||(v.startsWith('{')&&v.endsWith('}'))||(v.startsWith('[')&&v.endsWith(']'));
}
String _bridgePointFriendlyLabelV218(dynamic value){
  final raw='${value??''}'.trim();if(raw.isEmpty)return '';
  return raw.replaceAll('_',' ').toLowerCase().split(' ').where((x)=>x.isNotEmpty).map((x)=>x.length<3?x:'${x[0].toUpperCase()}${x.substring(1)}').join(' ');
}
String _bridgePointReadableEvidenceV218(Map<String,dynamic> signal){
  final title='${signal['signal_name']??signal['title']??'Property signal'}'.trim();
  final description='${signal['description']??''}'.trim();
  if(description.isNotEmpty&&!_bridgePointInternalLookingTextV218(description))return description;
  final raw=signal['evidence_summary'];
  if(raw is String){final text=raw.trim();if(text.isNotEmpty&&!_bridgePointInternalLookingTextV218(text))return text;}
  final e=raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{};
  final provider=_bridgePointFriendlyLabelV218(e['provider']??e['source']??signal['source_name']??signal['signal_family']);
  final precision='${e['matching_precision']??''}'.toUpperCase();
  final storage='${e['storage_mode']??''}'.toLowerCase();
  final contextual=precision.startsWith('AREA_')||storage.contains('area_context');
  final geos=e['geography_types'];
  final geo=geos is List&&geos.isNotEmpty?_bridgePointFriendlyLabelV218(geos.first):'';
  final records=(e['area_source_records']??e['source_record_count']??e['supporting_rows']??e['event_count']??e['exposure_count']) as num?;
  final amount=(e['area_monetary_total']??e['total_reported_loss']??e['total_incentive_amount']??e['total_system_cost']) as num?;
  final distance=e['nearest_distance_meters'] as num?;
  final first='${e['first_event_at']??e['first_recorded_at']??e['first_exposure_at']??e['first_release_at']??''}'.trim();
  final latest='${e['latest_event_at']??e['latest_recorded_at']??e['latest_exposure_at']??e['latest_release_at']??''}'.trim();
  final parts=<String>[];
  if(contextual){
    parts.add('$title appears in ${geo.isEmpty?'surrounding-area':geo} records${provider.isEmpty?'':' from $provider'}. This is area-level context, not confirmation that the event or claim happened at this individual property.');
  }else{
    parts.add('BridgePoint linked $title to this property${provider.isEmpty?'':' using $provider records'}.');
  }
  if(records!=null&&records>0)parts.add('${records.toInt()} supporting source record${records.toInt()==1?'':'s'} were found.');
  if(distance!=null&&distance>=0)parts.add('Nearest supporting activity was about ${distance<1000?'${distance.round()} m':'${(distance/1609.344).toStringAsFixed(1)} mi'} away.');
  if(amount!=null&&amount>0&&contextual)parts.add('The surrounding records report about \$${amount.toStringAsFixed(0)} in associated activity; this is not a property-level loss amount.');
  if(first.isNotEmpty&&latest.isNotEmpty&&first!=latest)parts.add('Supporting activity spans ${first.split('T').first} through ${latest.split('T').first}.');
  else if(latest.isNotEmpty)parts.add('Latest supporting activity: ${latest.split('T').first}.');
  if(parts.length==1)parts.add('Open the property timeline to review timing, source, match quality, and limitations.');
  return parts.join(' ');
}
bool _bridgePointCustomerSafeValueV218(dynamic value){
  if(value==null)return false;final text='$value'.trim();return text.isNotEmpty&&!_bridgePointInternalLookingTextV218(text);
}

'''
    s=s.replace(anchor,helper+anchor,1);edits+=1
old="""  final evidence = signal['evidence_summary'];
  final evidenceText = evidence is Map
      ? const JsonEncoder.withIndent('  ').convert(evidence)
      : (evidence?.toString() ?? 'No evidence summary.');
"""
if old in s: once(old,"  final evidenceText = _bridgePointReadableEvidenceV218(signal);\n",'raw evidence dialog')
old_filter="""          return _bridgePointCustomerSafeKey(entry.key) &&
              value != null &&
              '$value'.trim().isNotEmpty &&
              value is! Map &&
              value is! List;
"""
if old_filter in s: once(old_filter,"""          return _bridgePointCustomerSafeKey(entry.key) &&
              _bridgePointCustomerSafeValueV218(value) &&
              value is! Map &&
              value is! List;
""",'customer scalar safety')

replace_class('_PanelHeader',r'''class _PanelHeader extends StatelessWidget{
  const _PanelHeader({required this.title,required this.subtitle,required this.action});
  final String title;final String subtitle;final String action;
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,c){
    final compact=c.maxWidth<520;
    final copy=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:TextStyle(color:Colors.white,fontSize:compact?15:16,fontWeight:FontWeight.w800,height:1.18)),
      const SizedBox(height:4),Text(subtitle,style:TextStyle(color:AppTheme.textMuted,fontSize:compact?10:11,height:1.38)),
    ]);
    final actionButton=TextButton(
      style:compact?TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:0,vertical:5),minimumSize:Size.zero,tapTargetSize:MaterialTapTargetSize.shrinkWrap):null,
      onPressed:()=>_showInfoDialog(context,title,'$subtitle\n\nOpen the rows or cards below for property-level detail, supporting evidence, timing, confidence, sources, and suggested next steps.'),
      child:Text(action,maxLines:1,overflow:TextOverflow.ellipsis),
    );
    return compact?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy,const SizedBox(height:3),actionButton]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:copy),actionButton]);
  });
}''')
replace_class('_PageHeading',r'''class _PageHeading extends StatelessWidget{
  const _PageHeading({required this.title,required this.subtitle,required this.onRefresh,required this.loading});
  final String title;final String subtitle;final VoidCallback onRefresh;final bool loading;
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,c){
    final compact=c.maxWidth<520;
    final copy=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:TextStyle(color:Colors.white,fontSize:compact?23:27,fontWeight:FontWeight.w800,height:1.08)),
      const SizedBox(height:5),Text(subtitle,style:TextStyle(color:AppTheme.textMuted,fontSize:compact?11:13,height:1.35)),
    ]);
    final controls=Row(mainAxisSize:MainAxisSize.min,children:[
      Tooltip(message:'Explain this page',child:IconButton(onPressed:()=>_showInfoDialog(context,title,'$subtitle\n\nTap any summary card, list row, map marker, legend item, status, or timeline event for a plain-language explanation and the next available action.'),icon:const Icon(Icons.help_outline_rounded,color:AppTheme.cyan))),
      _IconButton(icon:Icons.refresh_rounded,onTap:loading?null:onRefresh),
    ]);
    return compact?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[copy,const SizedBox(height:4),Align(alignment:Alignment.centerRight,child:controls)]):Row(children:[Expanded(child:copy),controls]);
  });
}''')

replace_class('_OpportunityListCard',r'''class _OpportunityListCard extends StatelessWidget{
  const _OpportunityListCard({required this.opportunity});final Map<String,dynamic> opportunity;
  @override Widget build(BuildContext context){
    final score=opportunity['score'] as num?;
    final confidence=opportunity['confidence_score'] as num??opportunity['opportunity_confidence_percent'] as num?;
    final priority=(opportunity['priority']??'medium').toString().toLowerCase();
    final priorityColor=_opportunityPriorityColor(priority);final rank=opportunity['rank_value'];
    final address=(opportunity['full_address']??'Address unavailable').toString();
    final signal=(opportunity['top_signal_type']??'No top signal').toString();
    final events=(opportunity['event_count'] as num?)?.toInt()??0;
    final distinctSignals=(opportunity['distinct_signal_count'] as num?)?.toInt()??0;
    final stage=(opportunity['stage']??'monitor').toString();
    final action=(opportunity['recommended_action']??'Continue monitoring').toString();
    Widget scoreBlock()=>Container(width:62,padding:const EdgeInsets.symmetric(vertical:8),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.07),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.cyan.withOpacity(.14))),child:Column(children:[Text(rank==null?'—':'#$rank',style:const TextStyle(color:AppTheme.cyan,fontSize:15,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(score==null?'—':score.toStringAsFixed(1),style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800))]));
    final chips=Wrap(spacing:6,runSpacing:6,children:[_OpportunityChip(label:priority.toUpperCase(),color:priorityColor),_OpportunityChip(label:stage.replaceAll('_',' ').toUpperCase(),color:AppTheme.blue),_OpportunityChip(label:'$events EVENTS',color:AppTheme.cyan),_OpportunityChip(label:'$distinctSignals SIGNALS',color:AppTheme.green)]);
    return InkWell(onTap:()=>_showOpportunityDetail(context,opportunity),borderRadius:BorderRadius.circular(14),child:Container(
      margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.50),borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white.withOpacity(.06))),
      child:LayoutBuilder(builder:(context,c){final compact=c.maxWidth<650;
        if(compact)return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(crossAxisAlignment:CrossAxisAlignment.start,children:[scoreBlock(),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(address,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:12.5,fontWeight:FontWeight.w900,height:1.25)),const SizedBox(height:5),Text('${opportunity['model_name']??opportunity['model_key']??'BridgePoint'} • $signal',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.3))])),const SizedBox(width:4),const Icon(Icons.chevron_right_rounded,color:AppTheme.textMuted,size:20)]),
          const SizedBox(height:10),chips,const SizedBox(height:10),
          Container(width:double.infinity,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white.withOpacity(.025),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(confidence==null?'Confidence —':'Confidence ${confidence.toStringAsFixed(0)}%',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(action,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700,height:1.35))]))
        ]);
        return Row(children:[scoreBlock(),const SizedBox(width:14),Expanded(flex:4,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(address,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w800)),const SizedBox(height:5),Text('${opportunity['model_name']??opportunity['model_key']??'BridgePoint'} • $signal',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:10))])),Expanded(flex:3,child:chips),const SizedBox(width:12),SizedBox(width:145,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(confidence==null?'Confidence —':'Confidence ${confidence.toStringAsFixed(0)}%',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700)),const SizedBox(height:5),Text(action,textAlign:TextAlign.right,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700))])),const SizedBox(width:8),const Icon(Icons.chevron_right_rounded,color:AppTheme.textMuted,size:20)]);
      }),
    ));
  }
}''')

replace_class('_HomeSection',r'''class _HomeSection extends StatelessWidget{
  const _HomeSection({required this.title,required this.icon,required this.child,required this.actionLabel,required this.onAction});
  final String title;final IconData icon;final Widget child;final String? actionLabel;final VoidCallback? onAction;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:LayoutBuilder(builder:(context,c){
    final compact=c.maxWidth<430;
    final heading=Row(children:[Icon(icon,color:AppTheme.cyan,size:19),const SizedBox(width:7),Expanded(child:Text(title,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.4,height:1.25)))]);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(compact)...[heading,if(actionLabel!=null)...[const SizedBox(height:5),TextButton.icon(style:TextButton.styleFrom(padding:EdgeInsets.zero,minimumSize:Size.zero,tapTargetSize:MaterialTapTargetSize.shrinkWrap),onPressed:onAction,icon:const Icon(Icons.add_rounded,size:16),label:Text(actionLabel!))]]
      else Row(children:[Expanded(child:heading),if(actionLabel!=null)TextButton.icon(onPressed:onAction,icon:const Icon(Icons.add_rounded,size:16),label:Text(actionLabel!))]),
      const SizedBox(height:8),child,
    ]);
  })));
}''')
old_home_header="""        Row(children:[
          const Expanded(child:_PanelHeader(
            title:'My Home',
            subtitle:'Home Passport • home health • maintenance • documents • weather • neighborhood intelligence',
            action:'Homeowner advantage',
          )),
          OutlinedButton.icon(onPressed:_findHome,icon:const Icon(Icons.add_home_work_outlined),label:Text(homes.isEmpty?'Add my home':'Change / add home')),
        ]),
"""
new_home_header="""        LayoutBuilder(builder:(context,c){final compact=c.maxWidth<560;return compact?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'My Home',subtitle:'Home Passport • home health • maintenance • documents • weather • neighborhood intelligence',action:'Homeowner advantage'),
          const SizedBox(height:7),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:_findHome,icon:const Icon(Icons.add_home_work_outlined),label:Text(homes.isEmpty?'Add my home':'Change / add home'))),
        ]):Row(children:[const Expanded(child:_PanelHeader(title:'My Home',subtitle:'Home Passport • home health • maintenance • documents • weather • neighborhood intelligence',action:'Homeowner advantage')),OutlinedButton.icon(onPressed:_findHome,icon:const Icon(Icons.add_home_work_outlined),label:Text(homes.isEmpty?'Add my home':'Change / add home'))]);}),
"""
if old_home_header in s: once(old_home_header,new_home_header,'My Home mobile header')

old_search="""      Row(children:[Expanded(child:TextField(controller:search,onSubmitted:(v)=>_load(query:v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),labelText:'Change location',hintText:'Address, city/state, or ZIP',border:OutlineInputBorder()))),const SizedBox(width:8),FilledButton.icon(onPressed:loading?null:()=>_load(query:search.text),icon:const Icon(Icons.search_rounded),label:const Text('Forecast')),const SizedBox(width:6),OutlinedButton.icon(
        onPressed:loading?null:_useLocation,
        icon:Icon(_liveLocationOn?Icons.location_on_rounded:Icons.my_location_rounded),
        label:Text(_liveLocationOn?'Stop live location':'Start live location'),
      )]),
"""
new_search="""      LayoutBuilder(builder:(context,c){final compact=c.maxWidth<620;final field=TextField(controller:search,onSubmitted:(v)=>_load(query:v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),labelText:'Change location',hintText:'Address, city/state, or ZIP',border:OutlineInputBorder()));final buttons=Wrap(spacing:6,runSpacing:6,children:[FilledButton.icon(onPressed:loading?null:()=>_load(query:search.text),icon:const Icon(Icons.search_rounded),label:const Text('Forecast')),OutlinedButton.icon(onPressed:loading?null:_useLocation,icon:Icon(_liveLocationOn?Icons.location_on_rounded:Icons.my_location_rounded),label:Text(_liveLocationOn?'Stop live location':'Start live location'))]);return compact?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[field,const SizedBox(height:8),buttons]):Row(children:[Expanded(child:field),const SizedBox(width:8),buttons]);}),
"""
if old_search in s: once(old_search,new_search,'Weather search mobile')
old_current="""        Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if('${current['icon']??''}'.isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network('${current['icon']}',width:92,height:92,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(width:92,height:92,child:Icon(Icons.cloud_outlined,size:48,color:AppTheme.cyan)))) else const SizedBox(width:92,height:92,child:Icon(Icons.cloud_outlined,size:48,color:AppTheme.cyan)),
          const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${loc['name']??'Selected location'}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${current['textDescription']??'Current conditions'}',style:const TextStyle(color:AppTheme.textMuted)),const SizedBox(height:10),Wrap(spacing:12,runSpacing:8,children:[_MiniStat(label:'NOW',value:current['temperatureF']==null?'—':'${current['temperatureF']}°F'),_MiniStat(label:'HUMIDITY',value:current['relativeHumidity']==null?'—':'${(current['relativeHumidity'] as num).round()}%'),_MiniStat(label:'RISK WINDOW',value:'${risk['level']??'LOW'}'),_MiniStat(label:'NEARBY OPPS',value:'${nearby['count']??opps.length}')]),const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:[OutlinedButton.icon(onPressed:_saveCurrent,icon:const Icon(Icons.bookmark_add_outlined),label:const Text('Save location')),OutlinedButton.icon(onPressed:widget.onOpenMap,icon:const Icon(Icons.radar_rounded),label:const Text('Open live map'))])]))
        ]))),
"""
new_current="""        Card(child:Padding(padding:const EdgeInsets.all(16),child:LayoutBuilder(builder:(context,c){final compact=c.maxWidth<520;final image=ClipRRect(borderRadius:BorderRadius.circular(12),child:'${current['icon']??''}'.isNotEmpty?Image.network('${current['icon']}',width:compact?double.infinity:108,height:compact?150:108,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(width:compact?double.infinity:108,height:compact?150:108,color:AppTheme.panelSoft,child:const Icon(Icons.cloud_outlined,size:48,color:AppTheme.cyan))):Container(width:compact?double.infinity:108,height:compact?150:108,color:AppTheme.panelSoft,child:const Icon(Icons.cloud_outlined,size:48,color:AppTheme.cyan)));final info=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${loc['name']??'Selected location'}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${current['textDescription']??'Current conditions'}',style:const TextStyle(color:AppTheme.textMuted)),const SizedBox(height:10),Wrap(spacing:12,runSpacing:8,children:[_MiniStat(label:'NOW',value:current['temperatureF']==null?'—':'${current['temperatureF']}°F'),_MiniStat(label:'HUMIDITY',value:current['relativeHumidity']==null?'—':'${(current['relativeHumidity'] as num).round()}%'),_MiniStat(label:'RISK WINDOW',value:'${risk['level']??'LOW'}'),_MiniStat(label:'NEARBY OPPS',value:'${nearby['count']??opps.length}')]),const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:[OutlinedButton.icon(onPressed:_saveCurrent,icon:const Icon(Icons.bookmark_add_outlined),label:const Text('Save location')),OutlinedButton.icon(onPressed:widget.onOpenMap,icon:const Icon(Icons.radar_rounded),label:const Text('Open live map'))])]);return compact?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[image,const SizedBox(height:12),info]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[image,const SizedBox(width:14),Expanded(child:info)]);}))),
"""
if old_current in s: once(old_current,new_current,'Weather current card image')
old_hourly="""        SizedBox(height:174,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:hourly.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i){final h=hourly[i];return Container(width:128,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_bpDateTime(h['startTime']).split(' • ').last,style:const TextStyle(fontSize:9,color:AppTheme.textMuted)),const Spacer(),Text('${h['temperature']??'—'}°${h['temperatureUnit']??'F'}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${h['shortForecast']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,height:1.3)),const SizedBox(height:5),Text('Rain ${h['probabilityOfPrecipitation']??0}% • ${h['windSpeed']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8))]));})),
"""
new_hourly="""        SizedBox(height:214,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:hourly.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i){final h=hourly[i];final icon='${h['icon']??''}';return Container(width:142,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_bpDateTime(h['startTime']).split(' • ').last,style:const TextStyle(fontSize:9,color:AppTheme.textMuted)),const SizedBox(height:7),ClipRRect(borderRadius:BorderRadius.circular(9),child:icon.isNotEmpty?Image.network(icon,width:double.infinity,height:66,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(height:66,color:Colors.white.withOpacity(.04),child:const Center(child:Icon(Icons.cloud_outlined,color:AppTheme.cyan,size:30)))):Container(height:66,color:Colors.white.withOpacity(.04),child:const Center(child:Icon(Icons.cloud_outlined,color:AppTheme.cyan,size:30)))),const SizedBox(height:7),Text('${h['temperature']??'—'}°${h['temperatureUnit']??'F'}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text('${h['shortForecast']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,height:1.25)),const Spacer(),Text('Rain ${h['probabilityOfPrecipitation']??0}% • ${h['windSpeed']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8))]));})),
"""
if old_hourly in s: once(old_hourly,new_hourly,'Hourly image cards')
old_daily="""        Wrap(spacing:8,runSpacing:8,children:daily.map((d)=>Container(width:190,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${d['isDaytime']==true?'Day':'Night'} • ${_bpDateTime(d['startTime']).split(' • ').first}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),const SizedBox(height:4),Text('${d['temperature']??'—'}°${d['temperatureUnit']??'F'}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${d['shortForecast']??''}',style:const TextStyle(fontSize:9,height:1.35)),const SizedBox(height:4),Text('${d['windDirection']??''} ${d['windSpeed']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8))]))).toList()),
"""
new_daily="""        LayoutBuilder(builder:(context,c){final compact=c.maxWidth<650;if(compact)return SizedBox(height:238,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:daily.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i){final d=daily[i];final icon='${d['icon']??''}';return Container(width:164,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${d['isDaytime']==true?'DAY':'NIGHT'} • ${_bpDateTime(d['startTime']).split(' • ').first}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w800)),const SizedBox(height:7),ClipRRect(borderRadius:BorderRadius.circular(9),child:icon.isNotEmpty?Image.network(icon,width:double.infinity,height:78,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(height:78,color:Colors.white.withOpacity(.04),child:const Center(child:Icon(Icons.cloud_outlined,color:AppTheme.cyan,size:32)))):Container(height:78,color:Colors.white.withOpacity(.04),child:const Center(child:Icon(Icons.cloud_outlined,color:AppTheme.cyan,size:32)))),const SizedBox(height:7),Text('${d['temperature']??'—'}°${d['temperatureUnit']??'F'}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${d['shortForecast']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,height:1.3)),const Spacer(),Text('${d['windDirection']??''} ${d['windSpeed']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8))]));}));return Wrap(spacing:8,runSpacing:8,children:daily.map((d){final icon='${d['icon']??''}';return Container(width:210,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${d['isDaytime']==true?'Day':'Night'} • ${_bpDateTime(d['startTime']).split(' • ').first}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),const SizedBox(height:6),ClipRRect(borderRadius:BorderRadius.circular(8),child:icon.isNotEmpty?Image.network(icon,width:double.infinity,height:74,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(height:74,child:Center(child:Icon(Icons.cloud_outlined,color:AppTheme.cyan)))):const SizedBox(height:74,child:Center(child:Icon(Icons.cloud_outlined,color:AppTheme.cyan)))),const SizedBox(height:6),Text('${d['temperature']??'—'}°${d['temperatureUnit']??'F'}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${d['shortForecast']??''}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9,height:1.35)),const SizedBox(height:4),Text('${d['windDirection']??''} ${d['windSpeed']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8))]));}).toList());}),
"""
if old_daily in s: once(old_daily,new_daily,'Daily mobile forecast cards')

replace_class('_CommunityMapAndChatV212State',r'''class _CommunityMapAndChatV212State extends State<_CommunityMapAndChatV212>{
  late Future<Map<String,dynamic>> mapRequest;late Future<Map<String,dynamic>> channelRequest;String? channel;List<Map<String,dynamic>> messages=[];bool busy=false;final message=TextEditingController();
  @override void initState(){super.initState();mapRequest=_callRpc('bridgepoint_community_observation_map_v212',{'p_limit':250});channelRequest=_callRpc('bridgepoint_community_channels_v212',const {});}
  @override void dispose(){message.dispose();super.dispose();}
  Future<void> loadMessages(String key)async{setState((){channel=key;busy=true;});try{final r=await _callRpc('bridgepoint_community_messages_v212',{'p_channel_key':key,'p_limit':60,'p_before':null});if(mounted)setState(()=>messages=_bpRows(r['messages']));}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> post()async{final text=message.text.trim();if(text.isEmpty||channel==null)return;setState(()=>busy=true);try{final r=await _callRpc('bridgepoint_post_community_message_v212',{'p_channel_key':channel,'p_body':text});if(r['blocked']==true){if(mounted)_showInfoDialog(context,'Message not posted','${r['message']}');}else{message.clear();await loadMessages(channel!);}}catch(e){if(mounted)_showInfoDialog(context,'Could not post message','$e');}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context)=>Column(children:[
    FutureBuilder<Map<String,dynamic>>(future:mapRequest,builder:(context,s){final rows=_bpRows(s.data?['observations']);final markers=<Marker>[];for(final o in rows.take(MediaQuery.sizeOf(context).width<700?80:250)){final lat=(o['latitude'] as num?)?.toDouble(),lng=(o['longitude'] as num?)?.toDouble();if(lat==null||lng==null)continue;markers.add(Marker(point:LatLng(lat,lng),width:34,height:34,child:Tooltip(message:'${o['full_address']??'Community observation'} • ${o['observation_key']??''}',child:Container(decoration:BoxDecoration(color:AppTheme.green,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:2)),child:const Icon(Icons.visibility_rounded,color:Colors.white,size:17)))));}return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _PanelHeader(title:'Community Observation Map',subtitle:'Approved property posts automatically appear at the matched property',action:'Live map'),const SizedBox(height:8),SizedBox(height:MediaQuery.sizeOf(context).width<700?220:260,child:ClipRRect(borderRadius:BorderRadius.circular(11),child:FlutterMap(options:MapOptions(initialCenter:const LatLng(41.60,-72.70),initialZoom:7,minZoom:3,maxZoom:18,interactionOptions:InteractionOptions(flags:MediaQuery.sizeOf(context).width<700?(InteractiveFlag.drag|InteractiveFlag.pinchZoom|InteractiveFlag.doubleTapZoom):InteractiveFlag.all)),children:[TileLayer(urlTemplate:_bridgePointBaseMapUrl(),panBuffer:0,keepBuffer:1,userAgentPackageName:'com.bridgepoint.data_studio'),if(_displayPreferences.value.mapBaseStyle=='satellite')TileLayer(urlTemplate:_bridgePointLabelMapUrl(),panBuffer:0,keepBuffer:1,userAgentPackageName:'com.bridgepoint.data_studio'),MarkerLayer(markers:markers)]))),const SizedBox(height:5),Text(rows.isEmpty?'No approved community observations yet. The map is ready; the first approved post will place its property icon automatically.':'${rows.length} approved observations mapped.',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))])));}),
    const SizedBox(height:10),
    FutureBuilder<Map<String,dynamic>>(future:channelRequest,builder:(context,s){final channels=_bpRows(s.data?['channels']);final rules='${s.data?['rules']??'Respect people and properties.'}';return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _PanelHeader(title:'BridgePoint Community Chat',subtitle:'Package-based channels • moderated • customer connection without sacrificing trust',action:'Connected intelligence'),const SizedBox(height:7),Text(rules,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),const SizedBox(height:8),if(channels.isEmpty)const Text('Your current package does not include a community channel.',style:TextStyle(color:AppTheme.textMuted)) else Wrap(spacing:6,runSpacing:6,children:channels.map((c)=>ChoiceChip(selected:channel=='${c['channel_key']}',label:Text('${c['channel_name']}',style:const TextStyle(fontSize:9)),onSelected:(_)=>loadMessages('${c['channel_key']}'))).toList()),if(channel!=null)...[const Divider(height:18),ConstrainedBox(constraints:const BoxConstraints(maxHeight:260),child:messages.isEmpty?const Padding(padding:EdgeInsets.all(12),child:Text('No messages yet. Start a useful conversation.',style:TextStyle(color:AppTheme.textMuted))):ListView.builder(shrinkWrap:true,itemCount:messages.length,itemBuilder:(context,i){final m=messages[i];return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const CircleAvatar(radius:14,child:Icon(Icons.person_outline_rounded,size:15)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('${m['display_name']??'BridgePoint member'}',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900))),Text(_bpDateTime(m['created_at']),style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5))]),const SizedBox(height:3),Text('${m['body']}',style:const TextStyle(fontSize:9.5,height:1.35))]))]));})),const SizedBox(height:7),LayoutBuilder(builder:(context,c){final compact=c.maxWidth<520;final field=TextField(controller:message,maxLength:1200,maxLines:2,decoration:const InputDecoration(hintText:'Share a useful property or work insight…',border:OutlineInputBorder(),counterText:''));final send=FilledButton.icon(onPressed:busy?null:post,icon:const Icon(Icons.send_rounded,size:16),label:const Text('Post'));return compact?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[field,const SizedBox(height:7),send]):Row(children:[Expanded(child:field),const SizedBox(width:7),send]);})]])));})
  ]);
}''')
old_comm_header="""    Row(children:[const Expanded(child:_PanelHeader(title:'Community Property Observations',subtitle:'Verified contributors • dated property observations • BridgePoint interpretation • corroboration',action:'Data flywheel')),OutlinedButton.icon(onPressed:_identity,icon:const Icon(Icons.badge_outlined),label:const Text('Public identity')),const SizedBox(width:6),FilledButton.icon(onPressed:_addObservation,icon:const Icon(Icons.add_location_alt_outlined),label:const Text('Add observation'))]),
"""
new_comm_header="""    LayoutBuilder(builder:(context,c){final compact=c.maxWidth<620;final buttons=Wrap(spacing:6,runSpacing:6,children:[OutlinedButton.icon(onPressed:_identity,icon:const Icon(Icons.badge_outlined),label:const Text('Public identity')),FilledButton.icon(onPressed:_addObservation,icon:const Icon(Icons.add_location_alt_outlined),label:const Text('Add observation'))]);return compact?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _PanelHeader(title:'Community Property Observations',subtitle:'Verified contributors • dated property observations • BridgePoint interpretation • corroboration',action:'Data flywheel'),const SizedBox(height:7),buttons]):Row(children:[const Expanded(child:_PanelHeader(title:'Community Property Observations',subtitle:'Verified contributors • dated property observations • BridgePoint interpretation • corroboration',action:'Data flywheel')),buttons]);}),
"""
if old_comm_header in s: once(old_comm_header,new_comm_header,'Community header mobile')
old_property_row="""    const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[const Icon(Icons.home_work_outlined,color:AppTheme.cyan),const SizedBox(width:8),Expanded(child:Text(property==null?'Choose a property to view its community history.':'${property!['full_address']??'Property'}',style:const TextStyle(fontWeight:FontWeight.w900))),OutlinedButton.icon(onPressed:_chooseProperty,icon:const Icon(Icons.search_rounded),label:Text(property==null?'Choose property':'Change property'))]))),
"""
new_property_row="""    const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(12),child:LayoutBuilder(builder:(context,c){final compact=c.maxWidth<520;final label=Row(children:[const Icon(Icons.home_work_outlined,color:AppTheme.cyan),const SizedBox(width:8),Expanded(child:Text(property==null?'Choose a property to view its community history.':'${property!['full_address']??'Property'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,height:1.3)))]);final button=OutlinedButton.icon(onPressed:_chooseProperty,icon:const Icon(Icons.search_rounded),label:Text(property==null?'Choose property':'Change property'));return compact?Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[label,const SizedBox(height:8),button]):Row(children:[Expanded(child:label),const SizedBox(width:8),button]);}))),
"""
if old_property_row in s: once(old_property_row,new_property_row,'Community property selector')
old_obs_head="""Row(children:[_OpportunityChip(label:'${o['category']}',color:AppTheme.cyan),const SizedBox(width:7),Expanded(child:Text('${o['observation_label']}',style:const TextStyle(fontWeight:FontWeight.w900))),Text('${o['confidence_percent']??0}% confidence',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))])"""
new_obs_head="""LayoutBuilder(builder:(context,c){final compact=c.maxWidth<480;final title=Text('${o['observation_label']}',style:const TextStyle(fontWeight:FontWeight.w900,height:1.3));return compact?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Wrap(spacing:7,runSpacing:5,children:[_OpportunityChip(label:'${o['category']}',color:AppTheme.cyan),Text('${o['confidence_percent']??0}% confidence',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))]),const SizedBox(height:5),title]):Row(children:[_OpportunityChip(label:'${o['category']}',color:AppTheme.cyan),const SizedBox(width:7),Expanded(child:title),Text('${o['confidence_percent']??0}% confidence',style:const TextStyle(color:AppTheme.textMuted,fontSize:9))]);})"""
if old_obs_head in s: once(old_obs_head,new_obs_head,'Community observation title')
old_obs_actions="""Row(children:[Text('${o['corroboration_count']} confirm • ${o['dispute_count']} dispute',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),const Spacer(),TextButton.icon(onPressed:()=>_respond(o,'CONFIRM'),icon:const Icon(Icons.thumb_up_alt_outlined,size:15),label:const Text('Confirm')),TextButton.icon(onPressed:()=>_respond(o,'DISPUTE'),icon:const Icon(Icons.help_outline_rounded,size:15),label:const Text('Dispute')),IconButton(tooltip:'Report',onPressed:()=>_report(o),icon:const Icon(Icons.flag_outlined,size:18))])"""
new_obs_actions="""LayoutBuilder(builder:(context,c){final controls=Wrap(spacing:2,runSpacing:2,crossAxisAlignment:WrapCrossAlignment.center,children:[TextButton.icon(onPressed:()=>_respond(o,'CONFIRM'),icon:const Icon(Icons.thumb_up_alt_outlined,size:15),label:const Text('Confirm')),TextButton.icon(onPressed:()=>_respond(o,'DISPUTE'),icon:const Icon(Icons.help_outline_rounded,size:15),label:const Text('Dispute')),IconButton(tooltip:'Report',onPressed:()=>_report(o),icon:const Icon(Icons.flag_outlined,size:18))]);return c.maxWidth<520?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${o['corroboration_count']} confirm • ${o['dispute_count']} dispute',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),controls]):Row(children:[Text('${o['corroboration_count']} confirm • ${o['dispute_count']} dispute',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),const Spacer(),controls]);})"""
if old_obs_actions in s: once(old_obs_actions,new_obs_actions,'Community observation actions')

old_fields="""  bool _showRadar=true;
  bool _showClouds=true;
"""
new_fields="""  bool _showRadar=true;
  bool _showClouds=true;
  bool _compactMapV218=false;
  bool _mobileDefaultsAppliedV218=false;
"""
if old_fields in s: once(old_fields,new_fields,'Map mobile fields')
insert_before="""  @override
  void initState() {
    super.initState();
"""
pos=s.find('class _IntelligenceMapPageState')
ip=s.find(insert_before,pos)
if ip<0: raise SystemExit('map init anchor missing')
lifecycle="""  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    final compact=MediaQuery.sizeOf(context).width<700;
    _compactMapV218=compact;
    if(compact&&!_mobileDefaultsAppliedV218){
      _mobileDefaultsAppliedV218=true;_visibleLayer='opportunities';_showRadar=false;_showClouds=false;_showExpansion=false;_radarPlaying=false;
    }
  }

"""
s=s[:ip]+lifecycle+s[ip:];edits+=1
once("""        final markerPointLimit=_viewportZoom>=12?70:_viewportZoom>=9?36:_viewportZoom>=7?18:8;
        final markerSignalLimit=_viewportZoom>=12?38:_viewportZoom>=9?22:_viewportZoom>=7?12:6;
""","""        final markerPointLimit=_compactMapV218?(_viewportZoom>=12?42:_viewportZoom>=9?26:_viewportZoom>=7?14:7):(_viewportZoom>=12?70:_viewportZoom>=9?36:_viewportZoom>=7?18:8);
        final markerSignalLimit=_compactMapV218?(_viewportZoom>=12?20:_viewportZoom>=9?14:_viewportZoom>=7?8:4):(_viewportZoom>=12?38:_viewportZoom>=9?22:_viewportZoom>=7?12:6);
""",'Map phone marker limits')
once("interactionOptions:const InteractionOptions(flags:InteractiveFlag.all),","interactionOptions:InteractionOptions(flags:_compactMapV218?(InteractiveFlag.drag|InteractiveFlag.pinchZoom|InteractiveFlag.doubleTapZoom):InteractiveFlag.all),",'Map phone gestures')
once("onMapReady:()=>unawaited(_centerMapOnDevice(force:true)),","onMapReady:()=>unawaited(_centerMapOnDevice()),",'Map single auto center')
once("_viewportRefreshTimer=Timer(const Duration(milliseconds:450),(){","_viewportRefreshTimer=Timer(Duration(milliseconds:_compactMapV218?850:450),(){",'Map phone debounce')
once("final zoomChanged=(nextZoom-_viewportZoom).abs()>=0.12;","final zoomChanged=(nextZoom-_viewportZoom).abs()>=(_compactMapV218?0.25:0.12);",'Map phone zoom threshold')
once("(nextBounds.southWest.latitude-prior.southWest.latitude).abs()>=0.015||","(nextBounds.southWest.latitude-prior.southWest.latitude).abs()>=(_compactMapV218?0.03:0.015)||",'Map bounds 1')
once("(nextBounds.southWest.longitude-prior.southWest.longitude).abs()>=0.015||","(nextBounds.southWest.longitude-prior.southWest.longitude).abs()>=(_compactMapV218?0.03:0.015)||",'Map bounds 2')
once("(nextBounds.northEast.latitude-prior.northEast.latitude).abs()>=0.015||","(nextBounds.northEast.latitude-prior.northEast.latitude).abs()>=(_compactMapV218?0.03:0.015)||",'Map bounds 3')
once("(nextBounds.northEast.longitude-prior.northEast.longitude).abs()>=0.015;","(nextBounds.northEast.longitude-prior.northEast.longitude).abs()>=(_compactMapV218?0.03:0.015);",'Map bounds 4')
once("""                          TileLayer(
                            urlTemplate:
                                _bridgePointBaseMapUrl(),
                            userAgentPackageName: 'com.bridgepoint.data_studio',
                          ),
""","""                          TileLayer(
                            urlTemplate:_bridgePointBaseMapUrl(),
                            panBuffer:_compactMapV218?0:1,
                            keepBuffer:_compactMapV218?1:2,
                            userAgentPackageName:'com.bridgepoint.data_studio',
                          ),
""",'Map tile buffer')

marker="const String _bridgePointV217ClarityMarker='bridgepoint-v217-cloud-clarity';"
if marker in s: s=s.replace(marker,"const String _bridgePointV218MobileEvidenceMarker='bridgepoint-v218-mobile-layout-readable-evidence';\n"+marker,1);edits+=1
else: raise SystemExit('Missing v217 marker')

for required in ['_bridgePointReadableEvidenceV218','_compactMapV218','bridgepoint-v218-mobile-layout-readable-evidence','Community Property Observations','7–10 DAY OUTLOOK']:
    if required not in s: raise SystemExit('missing v218 guard '+required)
if s==original:raise SystemExit('No changes')
p.write_text(s,encoding='utf-8')
print(f'Applied BridgePoint v218 mobile layout + readable evidence repair ({edits} guarded edits).')
