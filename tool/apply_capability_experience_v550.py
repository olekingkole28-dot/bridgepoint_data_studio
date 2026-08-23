from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
marker = 'class _TechnologyCenterPageV550'

if marker not in s:
    nav_old = """    _NavigationItem('Models', Icons.psychology_alt_rounded),
    _NavigationItem('Settings', Icons.settings_rounded),
"""
    nav_new = """    _NavigationItem('Models', Icons.psychology_alt_rounded),
    _NavigationItem('Technology', Icons.auto_awesome_mosaic_rounded),
    _NavigationItem('Settings', Icons.settings_rounded),
"""
    if nav_old not in s:
        raise SystemExit('V550 navigation anchor missing')
    s = s.replace(nav_old, nav_new, 1)

    switch_old = """      case 12:
        return _SettingsPage(
          ownerMode:widget.ownerMode,
          settingsRequest: settingsRequest,
          healthRequest: healthRequest,
          refreshSeconds: _refreshSeconds,
          onRefreshSecondsChanged: _setRefreshSeconds,
          onRefresh: () {
            setState(() {
              settingsRequest = _loadRuntimeSettings();
              healthRequest = _loadSystemHealth();
            });
          },
        );
      case 13:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );
"""
    switch_new = """      case 12:
        return _TechnologyCenterPageV550(
          ownerMode: widget.ownerMode,
          onNavigate: _navigateTo,
        );
      case 13:
        return _SettingsPage(
          ownerMode:widget.ownerMode,
          settingsRequest: settingsRequest,
          healthRequest: healthRequest,
          refreshSeconds: _refreshSeconds,
          onRefreshSecondsChanged: _setRefreshSeconds,
          onRefresh: () {
            setState(() {
              settingsRequest = _loadRuntimeSettings();
              healthRequest = _loadSystemHealth();
            });
          },
        );
      case 14:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );
"""
    if switch_old not in s:
        raise SystemExit('V550 selected-page switch anchor missing')
    s = s.replace(switch_old, switch_new, 1)

    atmosphere_old = "final daily=pageIndex==0||pageIndex==9||pageIndex==10||pageIndex==12||pageIndex==13;"
    atmosphere_new = "final daily=pageIndex==0||pageIndex==9||pageIndex==10||pageIndex==12||pageIndex==13||pageIndex==14;"
    if atmosphere_old in s:
        s = s.replace(atmosphere_old, atmosphere_new, 1)

    s += r'''

// BridgePoint V550: native customer + owner capability experience.
class _TechnologyCenterPageV550 extends StatefulWidget {
  const _TechnologyCenterPageV550({required this.ownerMode, required this.onNavigate});
  final bool ownerMode;
  final ValueChanged<int> onNavigate;
  @override
  State<_TechnologyCenterPageV550> createState()=>_TechnologyCenterPageV550State();
}

class _TechnologyCenterPageV550State extends State<_TechnologyCenterPageV550>{
  late Future<Map<String,dynamic>> _request;
  String _query='';
  String _filter='ALL';

  @override void initState(){super.initState();_request=_load();}
  Future<Map<String,dynamic>> _load()=>_callRpc('bridgepoint_capability_experience_v550',{'p_include_all':widget.ownerMode});
  void _reload()=>setState(()=>_request=_load());

  Color _statusColor(String value){
    if(value=='AVAILABLE NOW')return AppTheme.green;
    if(value.contains('LIVE ENGINE'))return AppTheme.cyan;
    if(value.contains('PARTIAL'))return const Color(0xFFB99AFF);
    if(value.contains('OWNER')||value.contains('WAITING')||value.contains('NOT CUSTOMER'))return AppTheme.amber;
    return AppTheme.blue;
  }

  bool _matches(Map<String,dynamic> c){
    final q=_query.trim().toLowerCase();
    final hay='${c['capability_name']} ${c['domain']} ${c['plain_english']} ${c['example_text']} ${c['why_it_matters']} ${c['what_it_needs']}'.toLowerCase();
    if(q.isNotEmpty&&!hay.contains(q))return false;
    if(_filter=='ALL')return true;
    if(_filter=='LIVE')return c['implementation_status']=='LIVE';
    if(_filter=='CUSTOMER')return c['customer_status']=='ENTITLEMENT_READY';
    if(_filter=='NEEDS INPUTS')return '${c['experience_status']}'.contains('CONNECT');
    if(_filter=='HIDDEN')return c['customer_status']!='ENTITLEMENT_READY';
    return c['domain']==_filter;
  }

  Widget _metric(String label,dynamic value,String detail)=>Expanded(child:Container(
    constraints:const BoxConstraints(minWidth:150),padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:AppTheme.panel.withOpacity(.92),borderRadius:BorderRadius.circular(16),border:Border.all(color:Colors.white10)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$value',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:Colors.white)),const SizedBox(height:3),Text(label,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.7,color:AppTheme.cyan)),const SizedBox(height:3),Text(detail,style:const TextStyle(fontSize:10,color:AppTheme.textMuted))])));

  Widget _capabilityCard(Map<String,dynamic> c,double width){
    final status='${c['experience_status']??''}';
    final accent=_statusColor(status);
    return SizedBox(width:width,child:Card(child:Container(
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[accent.withOpacity(.09),Colors.transparent])),
      child:ExpansionTile(
        tilePadding:const EdgeInsets.fromLTRB(16,12,14,12),childrenPadding:const EdgeInsets.fromLTRB(16,0,16,16),
        leading:Container(width:42,height:42,decoration:BoxDecoration(color:accent.withOpacity(.13),borderRadius:BorderRadius.circular(12)),child:Icon(Icons.hub_rounded,color:accent,size:21)),
        title:Text('${c['capability_name']}',style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)),
        subtitle:Padding(padding:const EdgeInsets.only(top:5),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${c['plain_english']}',style:const TextStyle(fontSize:11,height:1.45,color:AppTheme.textMuted)),const SizedBox(height:7),Wrap(spacing:6,runSpacing:5,children:[_StatusChip(label:status,color:accent),_StatusChip(label:'${c['domain']}'.replaceAll('_',' '),color:AppTheme.blue)])])),
        children:[
          _TechExplainRowV550(label:'EXAMPLE',text:'${c['example_text']}'.replaceFirst(RegExp(r'^Example:\s*',caseSensitive:false),''),icon:Icons.lightbulb_outline_rounded),
          _TechExplainRowV550(label:'WHY IT MATTERS',text:'${c['why_it_matters']}',icon:Icons.trending_up_rounded),
          _TechExplainRowV550(label:'WHAT IT STILL NEEDS',text:'${c['what_it_needs']}',icon:Icons.build_circle_outlined),
          _TechExplainRowV550(label:'TECHNICAL TRUTH',text:'${c['truthful_claim']}',icon:Icons.verified_outlined),
          if(widget.ownerMode&&c['prohibited_claim']!=null)_TechExplainRowV550(label:'DO NOT CLAIM',text:'${c['prohibited_claim']}',icon:Icons.gpp_maybe_outlined),
          const SizedBox(height:8),
          Row(children:[Expanded(child:OutlinedButton.icon(onPressed:(){final i=(c['workspace_index'] as num?)?.toInt();if(i!=null)widget.onNavigate(i);},icon:const Icon(Icons.open_in_new_rounded,size:16),label:Text('Open ${c['workspace_label']??'workspace'}'))),const SizedBox(width:8),OutlinedButton(onPressed:()=>launchUrl(Uri.parse('$_bridgePointLiveUrl/app/technology/'),mode:LaunchMode.platformDefault),child:const Text('Visual guide'))]),
        ],
      ),
    )));
  }

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:_request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final raw=data['capabilities'];
      final all=raw is List?raw.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList():<Map<String,dynamic>>[];
      final rows=all.where(_matches).toList();
      final domains=<String>{...all.map((x)=>'${x['domain']}')}.toList()..sort();
      final summary=data['summary'] is Map?Map<String,dynamic>.from(data['summary']):<String,dynamic>{};
      final filters=<String>['ALL','LIVE','CUSTOMER','NEEDS INPUTS',if(widget.ownerMode)'HIDDEN',...domains];
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _PageHeading(title:'Everything BridgePoint',subtitle:widget.ownerMode?'Owner view · every live, hidden, internal, blocked and experimental capability explained plainly':'Every customer-eligible capability · what it does, why it matters, and what it still needs',onRefresh:_reload,loading:snapshot.connectionState==ConnectionState.waiting),
        const SizedBox(height:12),
        Container(width:double.infinity,padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:LinearGradient(colors:[AppTheme.blue.withOpacity(.20),AppTheme.cyan.withOpacity(.05),AppTheme.panel.withOpacity(.92)]),border:Border.all(color:AppTheme.cyan.withOpacity(.20))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('THE PROPERTY BRAIN',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.2,color:AppTheme.cyan)),const SizedBox(height:8),Text(widget.ownerMode?'Nothing is hidden from owner mode.':'You do not have to memorize the technology.',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:7),Text(widget.ownerMode?'This page shows what BridgePoint can do, what is actually live, what is waiting on data or partners, and what must stay private until validation catches up.':'Pick the job you are trying to do. BridgePoint shows which engine handles it, what evidence it needs, and where to work with it.',style:const TextStyle(color:AppTheme.textMuted,height:1.5))])),
        const SizedBox(height:12),
        if(snapshot.hasError)_DashboardError(message:snapshot.error.toString(),onRetry:_reload) else ...[
          LayoutBuilder(builder:(context,c){return Wrap(spacing:9,runSpacing:9,children:[SizedBox(width:c.maxWidth<720?c.maxWidth:(c.maxWidth-36)/5,child:_metric('SHOWN',summary['shown']??all.length,'capabilities')),SizedBox(width:c.maxWidth<720?c.maxWidth:(c.maxWidth-36)/5,child:_metric('LIVE',summary['live']??0,'engines')),SizedBox(width:c.maxWidth<720?c.maxWidth:(c.maxWidth-36)/5,child:_metric('CUSTOMER',summary['customer_ready']??0,'eligible')),if(widget.ownerMode)SizedBox(width:c.maxWidth<720?c.maxWidth:(c.maxWidth-36)/5,child:_metric('HIDDEN',summary['hidden']??0,'validating')),SizedBox(width:c.maxWidth<720?c.maxWidth:(c.maxWidth-36)/5,child:_metric('MODE',widget.ownerMode?'OWNER':'CUSTOMER','truth view'))]);}),
          const SizedBox(height:14),
          TextField(onChanged:(v)=>setState(()=>_query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),labelText:'Search everything',hintText:'supplement, drone, IoT, climate, digital twin…',border:OutlineInputBorder())),
          const SizedBox(height:10),
          Wrap(spacing:7,runSpacing:7,children:filters.map((f)=>ChoiceChip(label:Text(f.replaceAll('_',' '),style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)),selected:_filter==f,onSelected:(_)=>setState(()=>_filter=f))).toList()),
          const SizedBox(height:15),
          LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1100?3:c.maxWidth>=680?2:1;const gap=12.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:rows.map((x)=>_capabilityCard(x,w)).toList());}),
          if(rows.isEmpty)const Padding(padding:EdgeInsets.all(25),child:Center(child:Text('Nothing matches that filter.',style:TextStyle(color:AppTheme.textMuted)))),
          if(widget.ownerMode)...[const SizedBox(height:18),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('OWNER MISSION CONTROL',style:TextStyle(fontWeight:FontWeight.w900,color:AppTheme.cyan)),const SizedBox(height:8),const Text('Open the machine behind the customer app.',style:TextStyle(color:AppTheme.textMuted)),const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton(onPressed:null,child:Text('Autonomy Center → web')),OutlinedButton(onPressed:null,child:Text('Property Trust Engine → web')),OutlinedButton(onPressed:null,child:Text('Distribution → web')),OutlinedButton(onPressed:null,child:Text('Innovation → web'))])])))]
        ]
      ]);
    });
}

class _StatusChip extends StatelessWidget{
  const _StatusChip({required this.label,required this.color});final String label;final Color color;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(borderRadius:BorderRadius.circular(999),border:Border.all(color:color.withOpacity(.55)),color:color.withOpacity(.08)),child:Text(label,style:TextStyle(fontSize:8,fontWeight:FontWeight.w900,color:color)));
}

class _TechExplainRowV550 extends StatelessWidget{
  const _TechExplainRowV550({required this.label,required this.text,required this.icon});final String label,text;final IconData icon;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(top:10),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:17,color:AppTheme.cyan),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.7,color:AppTheme.cyan)),const SizedBox(height:3),Text(text,style:const TextStyle(fontSize:11,height:1.45,color:AppTheme.textMuted))]))]));
}
'''

p.write_text(s, encoding='utf-8')
print('V550 capability experience applied to lib/main.dart')
