from pathlib import Path
import re

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
"""class _DailyBriefPageState extends State<_DailyBriefPage>{
  late Future<Map<String,dynamic>> request;
  late Future<Map<String,dynamic>> fieldNoteRequest;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});}
""",
"""class _DailyBriefPageState extends State<_DailyBriefPage>{
  late Future<Map<String,dynamic>> request;
  late Future<Map<String,dynamic>> fieldNoteRequest;
  late Future<Map<String,dynamic>> widgetRequest;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {});}
""",
'daily-widget-future')

replace_once(
"""            IconButton(tooltip:'Refresh Daily Brief',onPressed:()=>setState((){request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});}),icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
""",
"""            IconButton(tooltip:'Refresh Daily Brief',onPressed:()=>setState((){request=_callRpc('bridgepoint_daily_brief_v74',const {});fieldNoteRequest=_callRpc('bridgepoint_field_note_of_day_v81',const {});widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {});}),icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
""",
'daily-widget-refresh')

replace_once(
"""        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:fieldNoteRequest,builder:(context,noteSnapshot){
""",
"""        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:widgetRequest,builder:(context,widgetSnapshot)=>_DashboardWidgetsPanel(
            snapshot:widgetSnapshot,
            onRefresh:()=>setState(()=>widgetRequest=_callRpc('bridgepoint_dashboard_widgets_v163',const {})),
          ),
        ),
        const SizedBox(height:18),FutureBuilder<Map<String,dynamic>>(
          future:fieldNoteRequest,builder:(context,noteSnapshot){
""",
'daily-widget-panel')

marker='class _FieldNoteCard extends StatelessWidget{'
if text.count(marker)!=1:
    raise SystemExit('FieldNote marker missing')
classes=r'''
class _DashboardWidgetsPanel extends StatelessWidget{
  const _DashboardWidgetsPanel({required this.snapshot,required this.onRefresh});
  final AsyncSnapshot<Map<String,dynamic>> snapshot;
  final VoidCallback onRefresh;

  @override Widget build(BuildContext context){
    if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData){
      return const Card(child:Padding(padding:EdgeInsets.all(16),child:LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)));
    }
    if(snapshot.hasError)return _InlineError(message:snapshot.error.toString());
    final payload=snapshot.data??const <String,dynamic>{};
    final widgets=_bpRows(payload['widgets']);
    final enabled=widgets.where((w)=>w['enabled']==true).toList();
    final data=_bpMap(payload['data']);
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('MY DASHBOARD WIDGETS',style:TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7)),
          SizedBox(height:3),Text('Your layout • drag to reorder • turn widgets on or off',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5)),
        ])),
        OutlinedButton.icon(onPressed:()=>_showDashboardCustomizeDialog(context,widgets,onRefresh),icon:const Icon(Icons.dashboard_customize_outlined,size:16),label:const Text('Customize')),
      ]),
      const SizedBox(height:10),
      if(enabled.isEmpty)Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(11)),child:const Text('No dashboard widgets are enabled. Choose Customize to add the ones you want.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)))
      else LayoutBuilder(builder:(context,c)=>Wrap(spacing:9,runSpacing:9,children:enabled.map((w)=>SizedBox(width:_dashboardWidgetWidth(c.maxWidth,'${w['width']??'HALF'}'),child:_DashboardWidgetTile(config:w,data:data))).toList())),
    ])));
  }
}

double _dashboardWidgetWidth(double maxWidth,String width){
  if(maxWidth<650)return maxWidth;
  if(width=='FULL')return maxWidth;
  if(width=='THIRD'&&maxWidth>=1000)return (maxWidth-18)/3;
  return (maxWidth-9)/2;
}

IconData _dashboardWidgetIcon(String key)=>switch(key){
  'CLOCK'=>Icons.schedule_rounded,
  'NEW_OPPORTUNITIES'=>Icons.auto_awesome_rounded,
  'UNREAD_ALERTS'=>Icons.notifications_active_outlined,
  'ROUTE_PROGRESS'=>Icons.route_rounded,
  'WATCHLISTS'=>Icons.bookmark_added_outlined,
  'RECENT_CHANGES'=>Icons.change_circle_outlined,
  'TERRITORY_POTENTIAL'=>Icons.travel_explore_rounded,
  'WEATHER'=>Icons.cloud_outlined,
  'SUPPORT'=>Icons.support_agent_rounded,
  _=>Icons.widgets_outlined,
};

String _dashboardWidgetTitle(String key)=>switch(key){
  'CLOCK'=>'Clock',
  'NEW_OPPORTUNITIES'=>'New Opportunities',
  'UNREAD_ALERTS'=>'Unread Alerts',
  'ROUTE_PROGRESS'=>'Route Progress',
  'WATCHLISTS'=>'Watchlists',
  'RECENT_CHANGES'=>'Recent Score Changes',
  'TERRITORY_POTENTIAL'=>'Territory Potential',
  'WEATHER'=>'Weather Location',
  'SUPPORT'=>'Questions or Concerns',
  _=>key.replaceAll('_',' '),
};

Color _dashboardWidgetColor(String key)=>switch(key){
  'CLOCK'=>AppTheme.cyan,
  'NEW_OPPORTUNITIES'=>AppTheme.green,
  'UNREAD_ALERTS'=>AppTheme.amber,
  'ROUTE_PROGRESS'=>AppTheme.blue,
  'WATCHLISTS'=>const Color(0xFF9D8CFF),
  'RECENT_CHANGES'=>const Color(0xFFE67ED1),
  'TERRITORY_POTENTIAL'=>const Color(0xFF56D6A4),
  'WEATHER'=>const Color(0xFF67B8FF),
  'SUPPORT'=>const Color(0xFFFF9F5A),
  _=>AppTheme.cyan,
};

class _DashboardWidgetTile extends StatelessWidget{
  const _DashboardWidgetTile({required this.config,required this.data});
  final Map<String,dynamic> config,data;
  @override Widget build(BuildContext context){
    final key='${config['widget_key']??''}';
    final color=_dashboardWidgetColor(key);
    if(key=='CLOCK')return _DashboardClockWidget(color:color);
    final routes=_bpRows(data['routes']);
    final watchlists=_bpRows(data['watchlists']);
    final changes=_bpRows(data['recent_changes']);
    final weather=_bpRows(data['weather_locations']);
    final territory=_bpRows(_bpMap(data['territory'])['territories']);
    String big='—',detail='';
    switch(key){
      case 'NEW_OPPORTUNITIES':
        big='${data['new_opportunities_24h']??0}';detail='Verified opportunities detected in the last 24 hours';break;
      case 'UNREAD_ALERTS':
        big='${data['unread_alerts']??0}';detail='Unread BridgePoint alerts';break;
      case 'ROUTE_PROGRESS':
        if(routes.isEmpty){big='0';detail='No active route yet';}
        else{final r=routes.first;final done=(r['completed_stops'] as num?)?.toInt()??0;final total=(r['stop_count'] as num?)?.toInt()??0;big='$done / $total';detail='${r['route_name']??'Current route'} • ${r['route_status']??''}';}
        break;
      case 'WATCHLISTS':
        final total=watchlists.fold<int>(0,(s,w)=>s+((w['item_count'] as num?)?.toInt()??0));big='$total';detail='${watchlists.length} watchlist${watchlists.length==1?'':'s'} • monitored items';break;
      case 'RECENT_CHANGES':
        big='${changes.length}';detail=changes.isEmpty?'No recent score changes stored':('${changes.first['explanation']??'Latest score movement recorded'}');break;
      case 'TERRITORY_POTENTIAL':
        if(territory.isEmpty){big='—';detail='Territory intelligence is still building';}
        else{final t=territory.first;big='${t['qualified_properties']??0}';detail='${t['municipality']??'Top territory'} • potential ${t['potential_score']??'—'}';}
        break;
      case 'WEATHER':
        if(weather.isEmpty){big='Set';detail='Save a location in Weather Center';}
        else{final w=weather.firstWhere((x)=>x['is_default']==true,orElse:()=>weather.first);big='${w['label']??'Saved'}';detail='${w['location_name']??w['postal_code']??'Weather Center'}';}
        break;
      case 'SUPPORT':
        final s=_bpMap(data['support']);big='203-605-2389';detail='${s['email']??'BridgePoint support'}';break;
    }
    return InkWell(
      borderRadius:BorderRadius.circular(12),
      onTap:()=>_showInfoDialog(context,_dashboardWidgetTitle(key),detail),
      child:Container(minHeight:112,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(_dashboardWidgetIcon(key),color:color,size:18),const SizedBox(width:7),Expanded(child:Text(_dashboardWidgetTitle(key),style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900))),const Icon(Icons.drag_indicator_rounded,color:Colors.white24,size:16)]),
        const Spacer(),Text(big,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(detail,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35)),
      ])),
    );
  }
}

class _DashboardClockWidget extends StatefulWidget{
  const _DashboardClockWidget({required this.color});final Color color;
  @override State<_DashboardClockWidget> createState()=>_DashboardClockWidgetState();
}
class _DashboardClockWidgetState extends State<_DashboardClockWidget>{
  late DateTime now;Timer? timer;
  @override void initState(){super.initState();now=DateTime.now();timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>now=DateTime.now());});}
  @override void dispose(){timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){final h=now.hour%12==0?12:now.hour%12;final m=now.minute.toString().padLeft(2,'0');final ap=now.hour>=12?'PM':'AM';return Container(minHeight:112,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:widget.color.withOpacity(.055),borderRadius:BorderRadius.circular(12),border:Border.all(color:widget.color.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(Icons.schedule_rounded,color:widget.color,size:18),const SizedBox(width:7),Text('Clock',style:TextStyle(color:widget.color,fontSize:9,fontWeight:FontWeight.w900)),const Spacer(),const Icon(Icons.drag_indicator_rounded,color:Colors.white24,size:16)]),const Spacer(),Text('$h:$m $ap',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text('${now.month}/${now.day}/${now.year}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5))]));}
}

Future<void> _showDashboardCustomizeDialog(BuildContext context,List<Map<String,dynamic>> source,VoidCallback refresh)async{
  final items=source.map((e)=>Map<String,dynamic>.from(e)).toList();
  var saving=false;
  await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal){
    Future<void> save()async{
      setLocal(()=>saving=true);
      try{
        await _callRpc('bridgepoint_save_dashboard_widgets_v163',{'p_widgets':items.map((e)=>{'widget_key':e['widget_key'],'enabled':e['enabled']==true,'width':e['width']??'HALF','settings':e['settings']??{}}).toList()});
        if(dialogContext.mounted)Navigator.pop(dialogContext);refresh();
      }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save dashboard','$e');}
      finally{if(context.mounted)setLocal(()=>saving=false);}
    }
    Future<void> reset()async{
      setLocal(()=>saving=true);
      try{await _callRpc('bridgepoint_reset_dashboard_widgets_v163',const {});if(dialogContext.mounted)Navigator.pop(dialogContext);refresh();}
      catch(e){if(context.mounted)_showInfoDialog(context,'Could not reset dashboard','$e');}
      finally{if(context.mounted)setLocal(()=>saving=false);}
    }
    return Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:720,maxHeight:760),child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
      Row(children:[const Icon(Icons.dashboard_customize_outlined,color:AppTheme.cyan),const SizedBox(width:8),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Customize Dashboard',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('Drag widgets into the order you want. Turn off anything you do not need.',style:TextStyle(color:AppTheme.textMuted,fontSize:9))])),IconButton(onPressed:()=>Navigator.pop(dialogContext),icon:const Icon(Icons.close_rounded))]),
      const SizedBox(height:12),
      Expanded(child:ReorderableListView.builder(
        itemCount:items.length,
        onReorder:(oldIndex,newIndex){setLocal((){if(newIndex>oldIndex)newIndex--;final item=items.removeAt(oldIndex);items.insert(newIndex,item);});},
        itemBuilder:(context,index){final item=items[index];final key='${item['widget_key']}';final color=_dashboardWidgetColor(key);return Container(key:ValueKey(key),margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:color.withOpacity(.045),borderRadius:BorderRadius.circular(10),border:Border.all(color:color.withOpacity(.12))),child:Row(children:[ReorderableDragStartListener(index:index,child:const Padding(padding:EdgeInsets.all(8),child:Icon(Icons.drag_indicator_rounded,color:AppTheme.textMuted))),Icon(_dashboardWidgetIcon(key),color:color,size:18),const SizedBox(width:9),Expanded(child:Text(_dashboardWidgetTitle(key),style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800))),SizedBox(width:94,child:DropdownButtonHideUnderline(child:DropdownButton<String>(value:'${item['width']??'HALF'}',dropdownColor:AppTheme.panelSoft,isDense:true,items:const ['THIRD','HALF','FULL'].map((v)=>DropdownMenuItem(value:v,child:Text(v,style:TextStyle(fontSize:8)))).toList(),onChanged:(v){if(v!=null)setLocal(()=>item['width']=v);}))),Switch(value:item['enabled']==true,onChanged:(v)=>setLocal(()=>item['enabled']=v))]));},
      )),
      const SizedBox(height:10),Row(children:[TextButton.icon(onPressed:saving?null:reset,icon:const Icon(Icons.restart_alt_rounded),label:const Text('Reset defaults')),const Spacer(),OutlinedButton(onPressed:saving?null:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),const SizedBox(width:7),FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save_outlined),label:Text(saving?'Saving…':'Save layout'))]),
    ]))));
  }));
}

class _PropertyMediaCard extends StatefulWidget{
  const _PropertyMediaCard({required this.propertyId});final String propertyId;
  @override State<_PropertyMediaCard> createState()=>_PropertyMediaCardState();
}
class _PropertyMediaCardState extends State<_PropertyMediaCard>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_property_media_v137',{'p_property_id':widget.propertyId});}
  @override void didUpdateWidget(covariant _PropertyMediaCard oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.propertyId!=widget.propertyId)request=_callRpc('bridgepoint_property_media_v137',{'p_property_id':widget.propertyId});}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snap){
    if(snap.connectionState==ConnectionState.waiting&&!snap.hasData)return Container(height:190,alignment:Alignment.center,decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12)),child:const CircularProgressIndicator(color:AppTheme.cyan,strokeWidth:2));
    if(snap.hasError)return _PropertyMediaMissing(message:'Property photo not available yet');
    final data=snap.data??{};final primary=_bpMap(data['primary']);final url='${primary['media_url']??''}';if(url.isEmpty)return _PropertyMediaMissing(message:'${data['display_message']??'Property photo not available yet'}');
    final label='${primary['display_label']??(primary['media_type']=='AERIAL'?'Aerial View':'Property Photo')}';
    final source='${primary['source_name']??primary['provider']??'BridgePoint property media'}';
    final captured=primary['captured_at']==null?'Date not available':_bpDateTime(primary['captured_at']);
    final fallback='${data['fallback_kind']??''}'=='AERIAL';
    return Container(width:double.infinity,decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.13))),clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Stack(children:[Image.network(url,width:double.infinity,height:260,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(height:220,child:_PropertyMediaMissing(message:'Property photo not available yet'))),Positioned(left:10,top:10,child:_OpportunityChip(label:label.toUpperCase(),color:fallback?AppTheme.blue:AppTheme.green))]),
      Padding(padding:const EdgeInsets.all(11),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(source,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800)),const SizedBox(height:3),Text('$captured${fallback?' • automatic aerial fallback':''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),if(fallback)...[const SizedBox(height:5),const Text('BridgePoint did not find a higher-priority displayable exterior/field photo, so it is showing the authoritative aerial reference instead.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.35))]]) ),
    ]);
  });
}
class _PropertyMediaMissing extends StatelessWidget{
  const _PropertyMediaMissing({required this.message});final String message;
  @override Widget build(BuildContext context)=>Container(width:double.infinity,height:190,alignment:Alignment.center,decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12)),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.photo_outlined,color:AppTheme.textMuted,size:34),const SizedBox(height:7),Text(message,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w800))]));
}

'''
text=text.replace(marker,classes+marker,1)

# Put the same media card into every detailed opportunity/reasoning view that has a property id.
pattern=re.compile(r"(?P<indent>\s*)_ReasoningPanel\(opportunity:(?P<var>[A-Za-z_][A-Za-z0-9_]*)\),")
matches=list(pattern.finditer(text))
if not matches:
    raise SystemExit('No opportunity reasoning panels found for property media')
def add_media(m):
    indent=m.group('indent');var=m.group('var')
    return f"{indent}_PropertyMediaCard(propertyId:'${{{var}['property_id']}}'),\n{indent}const SizedBox(height:14),\n{indent}_ReasoningPanel(opportunity:{var}),"
text=pattern.sub(add_media,text)

if text==original:
    raise SystemExit('No dashboard widget/property media changes applied')
path.write_text(text,encoding='utf-8')
print(f'Applied customizable dashboard widgets and visible property media v164 to {len(matches)} opportunity detail view(s)')
