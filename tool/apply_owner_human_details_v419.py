from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')
marker='bridgepoint-v419-owner-human-details'
if marker in text:
    print('Owner Human Details V419 already applied')
    raise SystemExit(0)
if 'bridgepoint-v418-owner-truth-gaps' not in text:
    raise SystemExit('V419 requires V418 owner truth gaps')

start_needle='  Future<void> showDetails(Map<String,dynamic> section,Map<String,dynamic> live)async{'
end_needle='\n  Widget sectionCard(Map<String,dynamic> section,Map<String,dynamic> live,double width){'
if text.count(start_needle)!=1 or text.count(end_needle)!=1:
    raise SystemExit(f'V419 showDetails boundaries unexpected: start={text.count(start_needle)} end={text.count(end_needle)}')
start=text.index(start_needle)
end=text.index(end_needle,start)

replacement=r'''  Future<void> showDetails(Map<String,dynamic> section,Map<String,dynamic> live)async{
    final key='${section['key']??''}',payloadKey=section['payload_key']?.toString();
    final payload=payloadKey==null?null:live[payloadKey];
    final payloadMap=map(payload),metrics=map(live['metrics']);
    final color=statusColor('${section['status']??'BUILDING'}');
    String label(String raw)=>raw.replaceAll('_',' ').split(' ').where((v)=>v.isNotEmpty).map((v)=>v.length<=3?v.toUpperCase():'${v[0].toUpperCase()}${v.substring(1)}').join(' ');
    String short(dynamic value){
      if(value==null)return 'Unavailable';
      if(value is bool)return value?'Yes':'No';
      if(value is num)return value.toString();
      if(value is String)return value.isEmpty?'Unavailable':value;
      if(value is List)return '${value.length} records';
      if(value is Map){
        final m=map(value);
        if(m.containsKey('value')){
          final v=m['value'];
          if(v is Map){
            final vm=map(v);
            final useful=vm.entries.where((e)=>e.value is num||e.value is bool||e.value is String).take(4).map((e)=>'${label(e.key)}: ${short(e.value)}').join(' • ');
            if(useful.isNotEmpty)return useful;
          }
          return short(v);
        }
        final useful=m.entries.where((e)=>e.value is num||e.value is bool||e.value is String).take(4).map((e)=>'${label(e.key)}: ${short(e.value)}').join(' • ');
        return useful.isEmpty?'${m.length} fields':useful;
      }
      return '$value';
    }
    final human=<MapEntry<String,String>>[];
    if(payloadMap.isNotEmpty){
      for(final entry in payloadMap.entries){
        if(entry.key.startsWith('_'))continue;
        final value=entry.value;
        if(value==null||value is num||value is bool||value is String||(value is List&&value.length<=500)||(value is Map)){
          human.add(MapEntry(label(entry.key),short(value)));
        }
        if(human.length>=14)break;
      }
    }
    final trust=<String>[];
    for(final entry in metrics.entries){
      final mk='${entry.key}'.toLowerCase();
      if(!(mk.startsWith('$key.')||mk.contains('.$key')||(payloadKey!=null&&mk.contains(payloadKey.toLowerCase()))))continue;
      final m=map(entry.value),observed='${m['observed_state']??''}'.toUpperCase(),health='${m['health_status']??''}'.toUpperCase();
      final limitation='${m['limitation']??''}'.trim();
      if(observed.isNotEmpty||health.isNotEmpty||limitation.isNotEmpty){
        trust.add('${label('${entry.key}')} • ${observed.isEmpty?'OBSERVED':observed}${health.isEmpty?'':' • $health'}${limitation.isEmpty?'':' • $limitation'}');
      }
    }
    if(trust.isEmpty&&payload==null)trust.add('No reconciled backend payload is wired for this section yet. BridgePoint is showing this as unavailable instead of inventing a zero.');
    final pretty=payload==null?'No source-of-truth payload is currently materialized for this section.':const JsonEncoder.withIndent('  ').convert(payload);
    Widget metricRow(MapEntry<String,String> item)=>Container(
      width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),
      decoration:BoxDecoration(border:Border(bottom:BorderSide(color:Colors.white.withOpacity(.045)))),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SizedBox(width:150,child:Text(item.key,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.4,fontWeight:FontWeight.w800))),
        const SizedBox(width:8),Expanded(child:Text(item.value,style:const TextStyle(color:Colors.white,fontSize:9,height:1.35,fontWeight:FontWeight.w700))),
      ]));
    await showDialog<void>(context:context,builder:(context)=>Dialog(backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(12),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:940,maxHeight:860),child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(18,16,10,11),child:Row(children:[Container(width:40,height:40,decoration:BoxDecoration(color:color.withOpacity(.11),borderRadius:BorderRadius.circular(11)),child:Icon(sectionIcon(key),color:color)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${section['title']??'Owner detail'}',style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:3),Wrap(spacing:7,runSpacing:4,children:[_OpportunityChip(label:'${section['status']??'BUILDING'}',color:color),_OpportunityChip(label:'OWNER ONLY',color:AppTheme.cyan)])])),IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))])),
      Divider(height:1,color:Colors.white.withOpacity(.06)),
      Expanded(child:ListView(padding:const EdgeInsets.all(18),children:[
        Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withOpacity(.065),borderRadius:BorderRadius.circular(11),border:Border.all(color:color.withOpacity(.15))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('CURRENT STATUS',style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.8)),const SizedBox(height:5),
          Text(_headline(key,live),style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900,height:1.35)),const SizedBox(height:5),
          Text('Freshness • ${_bpDateTime(live['_generated_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.2)),
        ])),
        const SizedBox(height:10),
        _OwnerEverythingExplainV410(label:'WHAT THIS IS',text:'${section['what_is']??''}',icon:Icons.help_outline_rounded,color:AppTheme.cyan),
        _OwnerEverythingExplainV410(label:'WHY IT MATTERS',text:'${section['why_matters']??''}',icon:Icons.lightbulb_outline_rounded,color:AppTheme.blue),
        _OwnerEverythingExplainV410(label:'WHAT HAPPENS AUTOMATICALLY NEXT',text:'${section['auto_next']??''}',icon:Icons.autorenew_rounded,color:AppTheme.green),
        const SizedBox(height:10),
        Text('LIVE METRICS',style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),const SizedBox(height:5),
        Container(decoration:BoxDecoration(color:const Color(0xFF07111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white10)),child:human.isEmpty
          ?const Padding(padding:EdgeInsets.all(12),child:Text('No safe summarized metric rows are available yet. Open the audit payload below for current backend truth.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4)))
          :Column(children:human.map(metricRow).toList())),
        const SizedBox(height:10),
        if(trust.isNotEmpty)...[
          const Text('TRUTH / LIMITATIONS',style:TextStyle(color:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),const SizedBox(height:5),
          Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.055),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:trust.take(8).map((v)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('•  ',style:TextStyle(color:AppTheme.amber,fontSize:9)),Expanded(child:Text(v,style:const TextStyle(color:Colors.white70,fontSize:8.3,height:1.4)))]))).toList())),
          const SizedBox(height:10),
        ],
        ExpansionTile(initiallyExpanded:false,tilePadding:EdgeInsets.zero,title:const Text('Owner audit payload',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900)),subtitle:Text(payload==null?'Instrumentation is still building':'Exact owner-only backend payload • secrets remain redacted',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.2)),children:[Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF07111F),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white10)),child:SelectableText(pretty,style:const TextStyle(fontFamily:'monospace',color:Colors.white70,fontSize:8.0,height:1.45)))])
      ])),
      const Text('bridgepoint-v419-owner-human-details',style:TextStyle(fontSize:0,color:Colors.transparent)),
    ]))));
  }
'''

text=text[:start]+replacement+text[end:]
path.write_text(text,encoding='utf-8')
print('Applied Owner Human Details V419')
