from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v248-navigation-ai'
if marker in body:
    print('v248 already applied')
    raise SystemExit(0)

anchor="""  List<_NavigationItem> get visibleNavigationItems=>[
    if(_effectiveOwnerMode)...const [
      _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
      _NavigationItem('Founder Command',Icons.tune_rounded),
      _NavigationItem('Owner Demo',Icons.slideshow_rounded),
    ],
    ...navigationItems,
  ];
"""
insert=anchor+"""

  List<int> get _primaryNavigationIndicesV248 {
    final model=packageModelKeys[selectedPackage]??'all';
    final labels=<String>{
      if(_effectiveOwnerMode)'Owner Center',
      'Daily Brief','Opportunities','Intelligence Map','Properties','My Work','Community','Settings',
      if(model=='bridgepoint_home')'My Home',
      if(model!='bridgepoint_home'&&model!='all')'Field Mode',
    };
    final ordered=<String>[
      if(_effectiveOwnerMode)'Owner Center','Daily Brief',
      if(model=='bridgepoint_home')'My Home',
      'Opportunities','Intelligence Map','Properties',
      if(model!='bridgepoint_home'&&model!='all')'Field Mode',
      'My Work','Community','Settings',
    ];
    final indices=<int>[];
    for(final label in ordered){
      if(!labels.contains(label))continue;
      final i=visibleNavigationItems.indexWhere((item)=>item.label==label);
      if(i>=0&&!indices.contains(i))indices.add(i);
    }
    return indices;
  }

  void _openMoreToolsV248()=>_showMoreToolsV248(
    context,items:visibleNavigationItems,primaryIndices:_primaryNavigationIndicesV248,
    selectedIndex:selectedNavigation,onSelected:_navigateTo,
  );

  void _openBridgePointAiV248(String query){
    final q=query.trim();
    if(q.length<2){_showBridgePointAiPromptV248(context,_openBridgePointAiV248);return;}
    showDialog<void>(context:context,builder:(dialogContext)=>_BridgePointAiSearchDialogV248(
      initialQuery:q,onNavigateLabel:_navigateTrainingLabel,
      onPropertySelected:(property){Navigator.of(dialogContext).pop();_showPropertyInventoryDetail(context,property);},
    ));
  }
"""
if body.count(anchor)!=1: raise SystemExit(f'v248 nav getter anchor {body.count(anchor)}')
body=body.replace(anchor,insert,1)

old="""                  _SideNavigation(
                    items: visibleNavigationItems,
                    selectedIndex: selectedNavigation,
                    onSelected: _navigateTo,
                  ),"""
new="""                  _SideNavigation(
                    items: visibleNavigationItems,
                    primaryIndices:_primaryNavigationIndicesV248,
                    selectedIndex: selectedNavigation,
                    onSelected: _navigateTo,
                    onMoreTools:_openMoreToolsV248,
                  ),"""
if body.count(old)!=1: raise SystemExit(f'v248 side call {body.count(old)}')
body=body.replace(old,new,1)

old="""                        onSearch: (_) => _navigateTo(4),"""
if body.count(old)!=1: raise SystemExit(f'v248 search callback {body.count(old)}')
body=body.replace(old,"""                        onSearch: _openBridgePointAiV248,""",1)

old="""                        _CompactNavigation(
                          items: visibleNavigationItems,
                          selectedIndex: selectedNavigation,
                          onSelected: _navigateTo,
                        ),"""
new="""                        _CompactNavigation(
                          items: visibleNavigationItems,
                          primaryIndices:_primaryNavigationIndicesV248,
                          selectedIndex: selectedNavigation,
                          onSelected: _navigateTo,
                          onMoreTools:_openMoreToolsV248,
                        ),"""
if body.count(old)!=1: raise SystemExit(f'v248 compact call {body.count(old)}')
body=body.replace(old,new,1)

old="""class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container("""
new="""class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.items,required this.primaryIndices,required this.selectedIndex,required this.onSelected,required this.onMoreTools});
  final List<_NavigationItem> items;final List<int> primaryIndices;final int selectedIndex;final ValueChanged<int> onSelected;final VoidCallback onMoreTools;
  @override Widget build(BuildContext context) {
    final entries=primaryIndices.where((i)=>i>=0&&i<items.length).map((i)=>MapEntry(i,items[i])).toList();
    final hiddenSelected=!primaryIndices.contains(selectedIndex);
    return Container("""
if body.count(old)!=1: raise SystemExit(f'v248 side class {body.count(old)}')
body=body.replace(old,new,1)

old="""              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == selectedIndex;
                final accent=_bridgePointPageAccent(index);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(index),"""
new="""              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, position) {
                final entry=entries[position];final index=entry.key;final item=entry.value;
                final selected=index==selectedIndex;final accent=_bridgePointPageAccent(index);
                return InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>onSelected(index),"""
if body.count(old)!=1: raise SystemExit(f'v248 side list {body.count(old)}')
body=body.replace(old,new,1)

side_anchor="""          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.08),"""
side_more="""          ),
          Padding(padding:const EdgeInsets.fromLTRB(12,5,12,0),child:OutlinedButton.icon(
            onPressed:onMoreTools,
            style:OutlinedButton.styleFrom(minimumSize:const Size(double.infinity,44),alignment:Alignment.centerLeft,
              foregroundColor:hiddenSelected?Colors.white:AppTheme.textMuted,backgroundColor:hiddenSelected?AppTheme.blue.withOpacity(.10):Colors.transparent,
              side:BorderSide(color:hiddenSelected?AppTheme.blue.withOpacity(.30):Colors.white10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
            icon:Icon(Icons.grid_view_rounded,size:18,color:hiddenSelected?AppTheme.blue:AppTheme.textMuted),
            label:Text(hiddenSelected?'More tools • open':'More tools',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),
          )),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.08),"""
side_pos=body.index('class _SideNavigation')
next_pos=body.find(side_anchor,side_pos)
if next_pos<0: raise SystemExit('v248 side more anchor missing')
body=body[:next_pos]+body[next_pos:].replace(side_anchor,side_more,1)

mobile_old="""            PopupMenuButton<String>(tooltip:'Quick actions',onSelected:(v){if(v=='share')_showShareBridgePointDialog(context);if(v=='walk')onTraining();if(v=='help')_showFaqDialog(context);if(v=='alerts')onNotifications();},itemBuilder:(context)=>const [
              PopupMenuItem(value:'share',child:ListTile(leading:Icon(Icons.ios_share_rounded),title:Text('Share BridgePoint'))),"""
mobile_new="""            PopupMenuButton<String>(tooltip:'Quick actions',onSelected:(v){if(v=='ai')_showBridgePointAiPromptV248(context,onSearch);if(v=='share')_showShareBridgePointDialog(context);if(v=='walk')onTraining();if(v=='help')_showFaqDialog(context);if(v=='alerts')onNotifications();},itemBuilder:(context)=>const [
              PopupMenuItem(value:'ai',child:ListTile(leading:Icon(Icons.auto_awesome_rounded,color:AppTheme.cyan),title:Text('Ask BridgePoint AI'))),
              PopupMenuItem(value:'share',child:ListTile(leading:Icon(Icons.ios_share_rounded),title:Text('Share BridgePoint'))),"""
if body.count(mobile_old)!=1: raise SystemExit(f'v248 mobile action {body.count(mobile_old)}')
body=body.replace(mobile_old,mobile_new,1)

search_old="""            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted),
            hintText: 'Start typing an address or parcel',"""
search_new="""            prefixIcon: Icon(Icons.auto_awesome_rounded, color: AppTheme.cyan),
            hintText: 'Ask BridgePoint AI about any property, place, event or opportunity',"""
if body.count(search_old)!=1: raise SystemExit(f'v248 search hint {body.count(search_old)}')
body=body.replace(search_old,search_new,1)

compact_old="""class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox("""
compact_new="""class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({required this.items,required this.primaryIndices,required this.selectedIndex,required this.onSelected,required this.onMoreTools});
  final List<_NavigationItem> items;final List<int> primaryIndices;final int selectedIndex;final ValueChanged<int> onSelected;final VoidCallback onMoreTools;
  @override Widget build(BuildContext context) {
    final entries=primaryIndices.where((i)=>i>=0&&i<items.length).map((i)=>MapEntry(i,items[i])).toList();
    final hiddenSelected=!primaryIndices.contains(selectedIndex);
    return SizedBox("""
if body.count(compact_old)!=1: raise SystemExit(f'v248 compact class {body.count(compact_old)}')
body=body.replace(compact_old,compact_new,1)

compact_list_old="""        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = index == selectedIndex;
          final accent=_bridgePointPageAccent(index);
          return ChoiceChip("""
compact_list_new="""        itemCount: entries.length+1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, position) {
          if(position==entries.length)return ActionChip(
            avatar:Icon(Icons.grid_view_rounded,size:17,color:hiddenSelected?AppTheme.blue:AppTheme.textMuted),
            label:Text(hiddenSelected?'More • open':'More',style:TextStyle(color:hiddenSelected?Colors.white:AppTheme.textMuted,fontWeight:FontWeight.w800)),
            backgroundColor:hiddenSelected?AppTheme.blue.withOpacity(.12):AppTheme.panel,
            side:BorderSide(color:hiddenSelected?AppTheme.blue.withOpacity(.35):Colors.white10),onPressed:onMoreTools);
          final entry=entries[position];final index=entry.key;final item=entry.value;
          final selected=index==selectedIndex;final accent=_bridgePointPageAccent(index);
          return ChoiceChip("""
if body.count(compact_list_old)!=1: raise SystemExit(f'v248 compact list {body.count(compact_list_old)}')
body=body.replace(compact_list_old,compact_list_new,1)

helper_anchor='class _SideNavigation extends StatelessWidget {'
helpers=r'''
void _showMoreToolsV248(BuildContext context,{required List<_NavigationItem> items,required List<int> primaryIndices,required int selectedIndex,required ValueChanged<int> onSelected}){
  final hidden=<MapEntry<int,_NavigationItem>>[];
  for(var i=0;i<items.length;i++){if(!primaryIndices.contains(i))hidden.add(MapEntry(i,items[i]));}
  showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:AppTheme.panel,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(sheetContext)=>SafeArea(child:SizedBox(height:620,child:Padding(padding:const EdgeInsets.fromLTRB(20,18,20,24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(10)))),const SizedBox(height:15),
      const Row(children:[Icon(Icons.grid_view_rounded,color:AppTheme.cyan),SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('More BridgePoint tools',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Nothing was removed. Deeper tools stay one tap away when you need them.',style:TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.4))]))]),const SizedBox(height:14),
      Expanded(child:GridView.builder(gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:260,mainAxisExtent:76,crossAxisSpacing:9,mainAxisSpacing:9),itemCount:hidden.length,itemBuilder:(context,pos){final entry=hidden[pos];final selected=entry.key==selectedIndex;return InkWell(onTap:(){Navigator.pop(sheetContext);onSelected(entry.key);},borderRadius:BorderRadius.circular(13),child:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:selected?AppTheme.cyan.withOpacity(.11):AppTheme.panelSoft,borderRadius:BorderRadius.circular(13),border:Border.all(color:selected?AppTheme.cyan.withOpacity(.34):Colors.white.withOpacity(.06))),child:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:(selected?AppTheme.cyan:AppTheme.blue).withOpacity(.09),borderRadius:BorderRadius.circular(10)),child:Icon(entry.value.icon,color:selected?AppTheme.cyan:AppTheme.textMuted,size:19)),const SizedBox(width:9),Expanded(child:Text(entry.value.label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:selected?Colors.white:Colors.white70)))])));})),
    ])))));
}

void _showBridgePointAiPromptV248(BuildContext context,ValueChanged<String> onSearch){
  final controller=TextEditingController();
  showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(backgroundColor:AppTheme.panel,
    title:const Row(children:[Icon(Icons.auto_awesome_rounded,color:AppTheme.cyan),SizedBox(width:9),Expanded(child:Text('Ask BridgePoint AI'))]),
    content:SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Search BridgePoint intelligence across properties, places, events, opportunities, maps and the information your account can access.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),const SizedBox(height:12),
      TextField(controller:controller,autofocus:true,textInputAction:TextInputAction.search,onSubmitted:(q){Navigator.pop(dialogContext);onSearch(q);},decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Try “best roofing opportunities near Hartford”',border:OutlineInputBorder())),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton.icon(onPressed:(){final q=controller.text.trim();Navigator.pop(dialogContext);onSearch(q);},icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Ask BridgePoint'))]));
}

class _BridgePointAiSearchDialogV248 extends StatefulWidget{
  const _BridgePointAiSearchDialogV248({required this.initialQuery,required this.onNavigateLabel,required this.onPropertySelected});
  final String initialQuery;final ValueChanged<String> onNavigateLabel;final ValueChanged<Map<String,dynamic>> onPropertySelected;
  @override State<_BridgePointAiSearchDialogV248> createState()=>_BridgePointAiSearchDialogV248State();
}
class _BridgePointAiSearchDialogV248State extends State<_BridgePointAiSearchDialogV248>{
  late final TextEditingController controller;late Future<Map<String,dynamic>> request;String query='';
  @override void initState(){super.initState();controller=TextEditingController(text:widget.initialQuery);query=widget.initialQuery;request=_callRpc('bridgepoint_universal_search_context_v244',{'p_query':query,'p_limit':12});}
  @override void dispose(){controller.dispose();super.dispose();}
  void _search(String value){final q=value.trim();if(q.length<2)return;setState((){query=q;request=_callRpc('bridgepoint_universal_search_context_v244',{'p_query':q,'p_limit':12});});}
  void _action(String target){final label=switch(target){'PROPERTIES'=>'Properties','OPPORTUNITIES'=>'Opportunities','INTELLIGENCE_MAP'=>'Intelligence Map','COMMUNITY'=>'Community','PROPERTY_MEMORY'=>'My Home','ADVANCED_EVIDENCE'=>'Properties',_=>'Daily Brief'};Navigator.pop(context);widget.onNavigateLabel(label);}
  @override Widget build(BuildContext context)=>AlertDialog(backgroundColor:AppTheme.panel,insetPadding:const EdgeInsets.all(16),
    title:Row(children:[Container(width:40,height:40,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue]),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.auto_awesome_rounded,color:Colors.white)),const SizedBox(width:10),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('BridgePoint AI',style:TextStyle(fontWeight:FontWeight.w900)),SizedBox(height:2),Text('Grounded property intelligence search',style:TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w600))]))]),
    content:SizedBox(width:880,height:650,child:Column(children:[
      TextField(controller:controller,textInputAction:TextInputAction.search,onSubmitted:_search,decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded,color:AppTheme.cyan),suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward_rounded),onPressed:()=>_search(controller.text)),hintText:'Ask about a property, place, event, opportunity or BridgePoint tool',border:const OutlineInputBorder())),const SizedBox(height:10),
      Expanded(child:FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(),SizedBox(height:12),Text('BridgePoint is checking the evidence…',style:TextStyle(color:AppTheme.textMuted))]));
        if(snapshot.hasError)return Center(child:_DashboardError(message:snapshot.error.toString(),onRetry:()=>_search(query)));
        final data=snapshot.data??const <String,dynamic>{};final rawProps=_bpMap(data['property_suggestions']);final props=_detailList(rawProps['suggestions']);final results=_detailList(data['search_results']);final actions=_detailList(data['quick_actions']);final model=data['model_connected']==true;
        return ListView(children:[
          Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.09),AppTheme.blue.withOpacity(.06)]),borderRadius:BorderRadius.circular(13),border:Border.all(color:AppTheme.cyan.withOpacity(.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.verified_rounded,color:AppTheme.green,size:16),const SizedBox(width:6),Text(model?'AI answer synthesis connected':'Grounded BridgePoint search active',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900)),const Spacer(),Text('${data['detected_intent']??'GENERAL'}'.replaceAll('_',' '),style:const TextStyle(color:AppTheme.cyan,fontSize:8,fontWeight:FontWeight.w900))]),const SizedBox(height:6),Text(model?'BridgePoint AI is answering from evidence your account is authorized to access.':'BridgePoint searched the intelligence your account can access. Natural-language synthesis is kept separate so no model receives raw database access.',style:const TextStyle(color:Colors.white70,fontSize:9.5,height:1.45))])),
          if(props.isNotEmpty)...[const SizedBox(height:14),const Text('Properties that match',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(height:7),...props.take(5).map((p)=>Card(color:AppTheme.panelSoft,child:ListTile(leading:const Icon(Icons.home_work_outlined,color:AppTheme.cyan),title:Text('${p['full_address']??'Property'}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)),subtitle:Text('${p['municipality']??''}${p['state_code']==null?'':' • ${p['state_code']}'}',style:const TextStyle(fontSize:8,color:AppTheme.textMuted)),trailing:p['top_score']==null?null:_OpportunityChip(label:'${p['top_score']}',color:AppTheme.green),onTap:()=>widget.onPropertySelected(p)))],
          if(results.isNotEmpty)...[const SizedBox(height:14),const Text('Other BridgePoint intelligence',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(height:7),...results.take(8).map((r)=>Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.72),borderRadius:BorderRadius.circular(11),border:Border.all(color:Colors.white.withOpacity(.05))),child:Row(children:[const Icon(Icons.bubble_chart_outlined,color:AppTheme.blue,size:17),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r['title']??r['entity_type']??'BridgePoint result'}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w800)),if('${r['subtitle']??''}'.isNotEmpty)Text('${r['subtitle']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),if('${r['description']??''}'.isNotEmpty)Text('${r['description']}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white60,fontSize:8,height:1.35))]))])))],
          if(actions.isNotEmpty)...[const SizedBox(height:14),const Text('Do something with it',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(height:7),Wrap(spacing:7,runSpacing:7,children:actions.map((a)=>ActionChip(avatar:Icon(a['recommended']==true?Icons.auto_awesome_rounded:Icons.arrow_forward_rounded,size:14,color:a['recommended']==true?AppTheme.cyan:AppTheme.textMuted),label:Text('${a['label']}',style:const TextStyle(fontSize:8.5)),onPressed:()=>_action('${a['target']}'))).toList())],
          const SizedBox(height:14),Row(children:[const Icon(Icons.lock_outline_rounded,color:AppTheme.green,size:14),const SizedBox(width:6),Expanded(child:Text('${data['privacy_notice']??'BridgePoint only searches information your account is allowed to access.'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8,height:1.4)))])
        ]);
      })),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]);
}

'''
if body.count(helper_anchor)!=1: raise SystemExit(f'v248 helper anchor {body.count(helper_anchor)}')
body=body.replace(helper_anchor,helpers+helper_anchor,1)
body += "\nconst String _bridgePointNavigationAiV248='bridgepoint-v248-navigation-ai | Ask BridgePoint AI | More BridgePoint tools | Nothing was removed';\n"
for required in ['bridgepoint-v248-navigation-ai','Ask BridgePoint AI','More BridgePoint tools','bridgepoint_universal_search_context_v244','_primaryNavigationIndicesV248']:
    if required not in body: raise SystemExit(f'v248 missing {required}')
path.write_text(body,encoding='utf-8')
print('Applied simplified package-first navigation and BridgePoint AI search v248.')
