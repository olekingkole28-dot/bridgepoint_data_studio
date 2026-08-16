from pathlib import Path

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
"""  int _liveRefreshTick = 0;
  int _refreshSeconds = 120;
""",
"""  int _liveRefreshTick = 0;
  bool _ownerCustomerPreview=false;
  int _refreshSeconds = 120;
""",
'customer-preview-state')

replace_once(
"""  List<_NavigationItem> get visibleNavigationItems=>[
    ...navigationItems,
    if(widget.ownerMode)
      const _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
  ];
""",
"""  bool get _effectiveOwnerMode=>widget.ownerMode&&!_ownerCustomerPreview;

  List<_NavigationItem> get visibleNavigationItems=>[
    ...navigationItems,
    if(_effectiveOwnerMode)...const [
      _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
      _NavigationItem('Owner Demo',Icons.slideshow_rounded),
      _NavigationItem('Founder Command',Icons.command_rounded),
    ],
  ];
""",
'owner-navigation')

replace_once(
"""    unawaited(_recordAppActivity('SESSION_START', 'Daily Brief'));
    if(!widget.ownerMode){
      WidgetsBinding.instance.addPostFrameCallback((_)=>_maybeOfferWalkthrough());
    }
""",
"""    unawaited(_recordAppActivity('SESSION_START', 'Daily Brief'));
    WidgetsBinding.instance.addPostFrameCallback((_)=>_maybeOfferWalkthrough());
""",
'auto-walkthrough-all-users')

start=text.find('  Future<void> _maybeOfferWalkthrough() async {')
end=text.find('  @override\n  void dispose()',start)
if start<0 or end<0:
    raise SystemExit('Old walkthrough method block not found')
walk_methods=r'''  int? _navigationIndexForLabel(String label){
    final normalized=switch(label){
      'Dashboard'=>'Daily Brief','Map'=>'Intelligence Map','Plans'=>'Packages','Analytics'=>'Models','Calendar'=>'My Work',_=>label,
    };
    for(var i=0;i<visibleNavigationItems.length;i++){
      if(visibleNavigationItems[i].label==normalized)return i;
    }
    return null;
  }

  void _navigateTrainingLabel(String label){
    if(label=='Notifications'){
      showDialog<void>(context:context,builder:(context)=>const _NotificationCenterDialog());
      return;
    }
    final index=_navigationIndexForLabel(label);
    if(index!=null)_navigateTo(index);
  }

  Future<void> _openWalkthrough({bool replay=false,bool automatic=false})async{
    try{
      var data=await _callRpc('bridgepoint_walkthrough_v155',{'p_replay':replay});
      final state=_bpMap(data['state']);
      final status='${state['status']??'NOT_STARTED'}';
      if(automatic&&!['NOT_STARTED','IN_PROGRESS'].contains(status))return;
      if(!automatic&&!replay&&status=='COMPLETED')data=await _callRpc('bridgepoint_walkthrough_v155',{'p_replay':true});
      if(!automatic&&!replay&&status=='SKIPPED'){
        await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'RESUME','p_step':state['current_step']});
        data=await _callRpc('bridgepoint_walkthrough_v155',{'p_replay':false});
      }
      if(!mounted)return;
      await showDialog<void>(
        context:context,barrierDismissible:false,
        builder:(dialogContext)=>_VisualWalkthroughDialog(initialData:data,onNavigateLabel:_navigateTrainingLabel),
      );
    }catch(e){if(mounted&& !automatic)_showInfoDialog(context,'Walkthrough unavailable','$e');}
  }

  Future<void> _maybeOfferWalkthrough()async{
    try{await _openWalkthrough(automatic:true);}catch(_){/* Training can never block the workspace. */}
  }

  void _startCustomerPreview(){
    if(!widget.ownerMode)return;
    setState((){
      _ownerCustomerPreview=true;
      selectedNavigation=0;
      if(selectedPackage=='All Intelligence')selectedPackage='BridgePoint Home';
      dashboardRequest=_loadDashboard();
    });
  }
  void _exitCustomerPreview(){
    if(!widget.ownerMode)return;
    setState((){
      _ownerCustomerPreview=false;
      selectedNavigation=0;
      selectedPackage='All Intelligence';
      dashboardRequest=_loadDashboard();
    });
  }

'''
text=text[:start]+walk_methods+text[end:]

replace_once(
"""      case 17:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );
""",
"""      case 17:
        if(_effectiveOwnerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(title:'Owner Center',icon:Icons.admin_panel_settings_rounded);
      case 18:
        if(_effectiveOwnerMode)return _OwnerDemoPage(onNavigateLabel:_navigateTrainingLabel);
        return const _ComingSoonPage(title:'Owner Demo',icon:Icons.slideshow_rounded);
      case 19:
        if(_effectiveOwnerMode)return _FounderCommandPage(
          onReplayWalkthrough:()=>_openWalkthrough(replay:true),
          onOpenDemo:()=>_navigateTo(18),
          onStartCustomerPreview:_startCustomerPreview,
          onNavigateLabel:_navigateTrainingLabel,
        );
        return const _ComingSoonPage(title:'Founder Command',icon:Icons.command_rounded);
""",
'owner-demo-founder-switch')

replace_once('ownerMode:widget.ownerMode,','ownerMode:_effectiveOwnerMode,','settings-effective-owner')

replace_once(
"""    required this.onPropertySelected,
    required this.onNotifications,
  });
""",
"""    required this.onPropertySelected,
    required this.onNotifications,
    required this.onTraining,
  });
""",
'topbar-training-constructor')
replace_once(
"""  final ValueChanged<Map<String, dynamic>> onPropertySelected;
  final VoidCallback onNotifications;
""",
"""  final ValueChanged<Map<String, dynamic>> onPropertySelected;
  final VoidCallback onNotifications;
  final VoidCallback onTraining;
""",
'topbar-training-field')
replace_once(
"""          _IconButton(
            icon: Icons.help_outline_rounded,
            onTap: () => _showFaqDialog(context),
          ),
          const SizedBox(width: 10),
          _IconButton(
            icon: Icons.notifications_none_rounded,
""",
"""          _IconButton(
            icon: Icons.school_outlined,
            onTap: onTraining,
          ),
          const SizedBox(width: 10),
          _IconButton(
            icon: Icons.help_outline_rounded,
            onTap: () => _showFaqDialog(context),
          ),
          const SizedBox(width: 10),
          _IconButton(
            icon: Icons.notifications_none_rounded,
""",
'topbar-training-button')
replace_once(
"""                        onNotifications: () => showDialog<void>(
                          context:context,
                          builder:(context)=>const _NotificationCenterDialog(),
                        ),
""",
"""                        onNotifications: () => showDialog<void>(
                          context:context,
                          builder:(context)=>const _NotificationCenterDialog(),
                        ),
                        onTraining:()=>_openWalkthrough(),
""",
'topbar-training-callback')

preview_anchor="""                      _LiveSyncStrip(
                        secondsRemaining:_secondsToRefresh,
                        refreshSeconds:_refreshSeconds,
                      ),
                      ValueListenableBuilder<_ConnectionHealth>(
"""
preview_replacement="""                      _LiveSyncStrip(
                        secondsRemaining:_secondsToRefresh,
                        refreshSeconds:_refreshSeconds,
                      ),
                      if(_ownerCustomerPreview)_CustomerPreviewBanner(
                        packageName:selectedPackage,
                        onExit:_exitCustomerPreview,
                      ),
                      ValueListenableBuilder<_ConnectionHealth>(
"""
replace_once(preview_anchor,preview_replacement,'customer-preview-banner')

owner_marker='class _OwnerCenterPage extends StatefulWidget{'
if text.count(owner_marker)!=1:
    raise SystemExit('Owner Center marker missing for training/founder classes')
classes=r'''
IconData _trainingIcon(String key)=>switch(key){
  'hub'=>Icons.hub_outlined,'dashboard'=>Icons.dashboard_outlined,'brief'=>Icons.wb_sunny_outlined,'weather'=>Icons.cloud_outlined,
  'map'=>Icons.map_outlined,'search'=>Icons.search_rounded,'dna'=>Icons.biotech_outlined,'explain'=>Icons.psychology_alt_outlined,
  'trend'=>Icons.trending_up_rounded,'community'=>Icons.groups_2_outlined,'work'=>Icons.work_history_outlined,'route'=>Icons.route_rounded,
  'offline'=>Icons.offline_bolt_rounded,'export'=>Icons.ios_share_outlined,'calendar'=>Icons.calendar_month_outlined,'notifications'=>Icons.notifications_active_outlined,
  'models'=>Icons.psychology_outlined,'cluster'=>Icons.bubble_chart_outlined,'home'=>Icons.home_rounded,'checklist'=>Icons.checklist_rounded,
  'outcome'=>Icons.insights_outlined,'replay'=>Icons.history_rounded,'mission'=>Icons.flag_outlined,'settings'=>Icons.settings_outlined,
  'security'=>Icons.security_outlined,'owner'=>Icons.admin_panel_settings_outlined,'people'=>Icons.group_add_outlined,'command'=>Icons.command_rounded,
  'expansion'=>Icons.public_rounded,'api'=>Icons.api_rounded,'growth'=>Icons.campaign_outlined,'email'=>Icons.mark_email_unread_outlined,
  'analytics'=>Icons.analytics_outlined,'moderation'=>Icons.gavel_outlined,'billing'=>Icons.credit_card_outlined,'health'=>Icons.health_and_safety_outlined,
  'demo'=>Icons.slideshow_rounded,'finish'=>Icons.rocket_launch_rounded,'forum'=>Icons.forum_outlined,'visibility'=>Icons.visibility_outlined,
  'fact_check'=>Icons.fact_check_outlined,'rocket_launch'=>Icons.rocket_launch_outlined,'verified_user'=>Icons.verified_user_outlined,'handshake'=>Icons.handshake_outlined,
  _=>Icons.auto_awesome_rounded,
};

class _CustomerPreviewBanner extends StatelessWidget{
  const _CustomerPreviewBanner({required this.packageName,required this.onExit});
  final String packageName;final VoidCallback onExit;
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.fromLTRB(16,4,16,4),padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
    decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.1),borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.amber.withOpacity(.25))),
    child:Row(children:[const Icon(Icons.visibility_outlined,color:AppTheme.amber,size:18),const SizedBox(width:9),Expanded(child:Text('CUSTOMER PREVIEW • $packageName  — owner-only navigation is hidden; your real backend owner permissions are unchanged.',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900))),OutlinedButton.icon(onPressed:onExit,icon:const Icon(Icons.close_rounded,size:15),label:const Text('Exit preview'))]),
  );
}

class _VisualWalkthroughDialog extends StatefulWidget{
  const _VisualWalkthroughDialog({required this.initialData,required this.onNavigateLabel});
  final Map<String,dynamic> initialData;final ValueChanged<String> onNavigateLabel;
  @override State<_VisualWalkthroughDialog> createState()=>_VisualWalkthroughDialogState();
}
class _VisualWalkthroughDialogState extends State<_VisualWalkthroughDialog>{
  late List<Map<String,dynamic>> steps;int index=0;bool busy=false;
  @override void initState(){super.initState();steps=_bpRows(widget.initialData['steps']);final state=_bpMap(widget.initialData['state']);final current=(state['current_step'] as num?)?.toInt();if(current!=null){final found=steps.indexWhere((s)=>(s['step_number'] as num?)?.toInt()==current);if(found>=0)index=found;}if('${state['status']}'=='NOT_STARTED')unawaited(_callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'START','p_step':steps.isEmpty?1:steps[index]['step_number']}));}
  Future<void> _move(int next)async{if(steps.isEmpty)return;setState(()=>busy=true);try{final bounded=next.clamp(0,steps.length-1);await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'STEP','p_step':steps[bounded]['step_number']});if(mounted)setState(()=>index=bounded);}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _skip()async{await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'SKIP','p_step':steps.isEmpty?1:steps[index]['step_number']});if(mounted)Navigator.pop(context);}
  Future<void> _next()async{if(index>=steps.length-1){await _callRpc('bridgepoint_walkthrough_progress_v155',{'p_action':'COMPLETE','p_step':steps[index]['step_number']});if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('BridgePoint walkthrough complete. You can replay it anytime with the training button.')));Navigator.pop(context);}return;}await _move(index+1);}
  @override Widget build(BuildContext context){if(steps.isEmpty)return AlertDialog(title:const Text('Walkthrough'),content:const Text('Training steps are not available yet.'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]);final s=steps[index];final asset='${s['visual_asset']??'assets/images/bridgepoint-intelligence-background-v1.webp'}';final progress=(index+1)/steps.length;return Dialog(backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.all(18),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:980,maxHeight:820),child:Container(decoration:BoxDecoration(color:AppTheme.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:AppTheme.cyan.withOpacity(.2))),child:Column(children:[
    ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(20)),child:SizedBox(height:210,width:double.infinity,child:Stack(fit:StackFit.expand,children:[Image.asset(asset,fit:BoxFit.cover,color:Colors.white.withOpacity(.32),colorBlendMode:BlendMode.modulate),DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withOpacity(.15),AppTheme.panel.withOpacity(.94)]))),Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:52,height:52,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.16),borderRadius:BorderRadius.circular(14)),child:Icon(_trainingIcon('${s['icon_key']}'),color:AppTheme.cyan,size:28)),const Spacer(),Text('STEP ${index+1} OF ${steps.length}',style:const TextStyle(color:Colors.white70,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),const SizedBox(width:8),TextButton(onPressed:busy?null:_skip,child:const Text('Skip for now'))]),const Spacer(),Text('${s['title']}',style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900,color:AppTheme.cyan)),const SizedBox(height:5),Text('${s['headline']}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,height:1.08))]))]))),
    LinearProgressIndicator(value:progress,minHeight:4,backgroundColor:Colors.white10,valueColor:const AlwaysStoppedAnimation(AppTheme.cyan)),
    Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:AnimatedSwitcher(duration:const Duration(milliseconds:220),child:Column(key:ValueKey(index),crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['body']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.65)),if('${s['why_it_matters']??''}'.isNotEmpty)...[const SizedBox(height:15),Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.065),borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('WHY IT MATTERS',style:TextStyle(color:AppTheme.blue,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.8)),const SizedBox(height:5),Text('${s['why_it_matters']}',style:const TextStyle(fontSize:10,height:1.5))]))],const SizedBox(height:12),LayoutBuilder(builder:(context,c){final wide=c.maxWidth>650;final tip=Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.065),borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.lightbulb_outline_rounded,color:AppTheme.amber,size:16),SizedBox(width:6),Text('TIP / TRICK',style:TextStyle(color:AppTheme.amber,fontSize:8,fontWeight:FontWeight.w900))]),const SizedBox(height:5),Text('${s['tip']??''}',style:const TextStyle(fontSize:9.5,height:1.45))]));final tryIt=Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.06),borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.touch_app_outlined,color:AppTheme.green,size:16),SizedBox(width:6),Text('TRY THIS NOW',style:TextStyle(color:AppTheme.green,fontSize:8,fontWeight:FontWeight.w900))]),const SizedBox(height:5),Text('${s['try_this']??''}',style:const TextStyle(fontSize:9.5,height:1.45))]));return wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:tip),const SizedBox(width:9),Expanded(child:tryIt)]):Column(children:[tip,const SizedBox(height:9),tryIt]);}),if('${s['nav_label']??''}'.isNotEmpty)...[const SizedBox(height:13),OutlinedButton.icon(onPressed:()=>widget.onNavigateLabel('${s['nav_label']}'),icon:const Icon(Icons.open_in_new_rounded),label:Text('Show me ${s['nav_label']}'))]]))))),
    Padding(padding:const EdgeInsets.fromLTRB(18,10,18,18),child:Row(children:[TextButton.icon(onPressed:index==0||busy?null:()=>_move(index-1),icon:const Icon(Icons.arrow_back_rounded),label:const Text('Back')),const Spacer(),Text('You can replay this anytime',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),const SizedBox(width:10),FilledButton.icon(onPressed:busy?null:_next,icon:Icon(index==steps.length-1?Icons.check_rounded:Icons.arrow_forward_rounded),label:Text(index==steps.length-1?'Finish walkthrough':'Next'))]))
  ])))));}
}

class _OwnerDemoPage extends StatefulWidget{
  const _OwnerDemoPage({required this.onNavigateLabel});final ValueChanged<String> onNavigateLabel;
  @override State<_OwnerDemoPage> createState()=>_OwnerDemoPageState();
}
class _OwnerDemoPageState extends State<_OwnerDemoPage>{
  late Future<Map<String,dynamic>> packagesRequest;String? selected;Map<String,dynamic>? playbook;bool loading=false;String? error;
  @override void initState(){super.initState();packagesRequest=_callRpc('bridgepoint_owner_demo_packages_v155',const {});}
  Future<void> _loadDemo(String key)async{setState((){selected=key;loading=true;error=null;});try{final r=await _callRpc('bridgepoint_owner_demo_mode_v155',{'p_package_key':key});if(mounted)setState(()=>playbook=r);}catch(e){if(mounted)setState(()=>error='$e');}finally{if(mounted)setState(()=>loading=false);}}
  Future<void> _start()async{if(playbook==null)return;await showDialog<void>(context:context,barrierDismissible:false,builder:(d)=>_GuidedDemoDialog(data:playbook!,onNavigateLabel:widget.onNavigateLabel));}
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _PanelHeader(title:'Owner Demo Mode',subtitle:'Choose what you are selling • BridgePoint coaches what to say, show and prove',action:'Owner-only presenter'),const SizedBox(height:10),const _ExplainerBanner(icon:Icons.slideshow_rounded,title:'You do not have to memorize BridgePoint',message:'Pick a package. Demo Mode gives you the opener, discovery question, exact screen sequence, “say this,” “show this,” proof point, tip, objection response, transition and close. Use the buyer’s problem as the center of the demo—not the feature count.'),const SizedBox(height:13),FutureBuilder<Map<String,dynamic>>(future:packagesRequest,builder:(context,snap){final packages=_bpRows(snap.data?['packages']);if(snap.connectionState==ConnectionState.waiting)return const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2);if(snap.hasError)return _InlineError(message:snap.error.toString());return DropdownButtonFormField<String>(value:selected,dropdownColor:AppTheme.panel,decoration:const InputDecoration(labelText:'Choose the package / technology you are demoing',border:OutlineInputBorder()),items:packages.map((p)=>DropdownMenuItem(value:'${p['package_key']}',child:Text('${p['package_name']} • ${p['audience']}',overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)_loadDemo(v);});}),if(loading)...[const SizedBox(height:9),const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2)],if(error!=null)...[const SizedBox(height:9),_InlineError(message:error!)],if(playbook!=null)...[const SizedBox(height:14),_DemoPreview(data:playbook!,onStart:_start)] ]));
}

class _DemoPreview extends StatelessWidget{
  const _DemoPreview({required this.data,required this.onStart});final Map<String,dynamic> data;final VoidCallback onStart;
  @override Widget build(BuildContext context){final p=_bpMap(data['package']),d=_bpMap(data['playbook']),steps=_bpRows(data['steps']);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.sell_outlined,color:AppTheme.cyan),const SizedBox(width:8),Expanded(child:Text('${p['package_name']}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))),Text(p['monthly_price']==null?'Enterprise':'\$${p['monthly_price']}/mo',style:const TextStyle(color:AppTheme.green,fontWeight:FontWeight.w900))]),const SizedBox(height:6),Text('${p['description']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:9.5,height:1.45)),const SizedBox(height:12),Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.05),borderRadius:BorderRadius.circular(10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('OPEN WITH THIS',style:TextStyle(color:AppTheme.cyan,fontSize:8,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${d['opener']}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800,height:1.45)),const SizedBox(height:9),const Text('THEN ASK',style:TextStyle(color:AppTheme.green,fontSize:8,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text('${d['discovery_question']}',style:const TextStyle(fontSize:10,height:1.45))])),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:onStart,icon:const Icon(Icons.play_arrow_rounded),label:Text('Start guided ${p['package_name']} demo')))]))),const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:steps.map((s)=>Container(width:250,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(10)),child:Row(children:[CircleAvatar(radius:15,backgroundColor:AppTheme.cyan.withOpacity(.13),child:Text('${s['step']}',style:const TextStyle(color:AppTheme.cyan,fontSize:9,fontWeight:FontWeight.w900))),const SizedBox(width:7),Expanded(child:Text('${s['title']}',style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800)))]))).toList())]);}
}

class _GuidedDemoDialog extends StatefulWidget{
  const _GuidedDemoDialog({required this.data,required this.onNavigateLabel});final Map<String,dynamic> data;final ValueChanged<String> onNavigateLabel;
  @override State<_GuidedDemoDialog> createState()=>_GuidedDemoDialogState();
}
class _GuidedDemoDialogState extends State<_GuidedDemoDialog>{int index=0;@override Widget build(BuildContext context){final p=_bpMap(widget.data['package']),steps=_bpRows(widget.data['steps']);final s=steps[index];final asset='${s['visual_asset']}';return Dialog(backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.all(16),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:980,maxHeight:840),child:Container(decoration:BoxDecoration(color:AppTheme.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:AppTheme.green.withOpacity(.2))),child:Column(children:[ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(20)),child:SizedBox(height:190,width:double.infinity,child:Stack(fit:StackFit.expand,children:[Image.asset(asset,fit:BoxFit.cover,color:Colors.white.withOpacity(.28),colorBlendMode:BlendMode.modulate),DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black12,AppTheme.panel.withOpacity(.95)]))),Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:AppTheme.green.withOpacity(.14),borderRadius:BorderRadius.circular(13)),child:Icon(_trainingIcon('${s['icon_key']}'),color:AppTheme.green,size:26)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${p['package_name']}',style:const TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900)),Text('DEMO STEP ${index+1} OF ${steps.length}',style:const TextStyle(color:Colors.white70,fontSize:8))])),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('End demo'))]),const Spacer(),Text('${s['title']}',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900))]))]))),LinearProgressIndicator(value:(index+1)/steps.length,minHeight:4,backgroundColor:Colors.white10,valueColor:const AlwaysStoppedAnimation(AppTheme.green)),Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.065),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('SAY THIS',style:TextStyle(color:AppTheme.green,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.8)),const SizedBox(height:6),SelectableText('${s['say_this']}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,height:1.5))])),const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.055),borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('SHOW THIS NOW',style:TextStyle(color:AppTheme.cyan,fontSize:8,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${s['show_this']}',style:const TextStyle(fontSize:10,height:1.45)),const SizedBox(height:8),OutlinedButton.icon(onPressed:()=>widget.onNavigateLabel('${s['nav_label']}'),icon:const Icon(Icons.open_in_new_rounded),label:Text('Open ${s['nav_label']}'))])),const SizedBox(height:10),LayoutBuilder(builder:(context,c){final wide=c.maxWidth>650;final tip=_demoBox('TIP',Icons.lightbulb_outline_rounded,AppTheme.amber,'${s['tip']}');final proof=_demoBox('PROOF POINT',Icons.fact_check_outlined,AppTheme.blue,'${s['proof_point']}');return wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:tip),const SizedBox(width:8),Expanded(child:proof)]):Column(children:[tip,const SizedBox(height:8),proof]);}),const SizedBox(height:10),_demoBox('TRANSITION / OBJECTION',Icons.forward_rounded,AppTheme.cyan,'${s['transition']}')]))),Padding(padding:const EdgeInsets.fromLTRB(18,8,18,18),child:Row(children:[TextButton.icon(onPressed:index==0?null:()=>setState(()=>index--),icon:const Icon(Icons.arrow_back_rounded),label:const Text('Back')),const Spacer(),FilledButton.icon(onPressed:(){if(index==steps.length-1){Navigator.pop(context);}else{setState(()=>index++);}},icon:Icon(index==steps.length-1?Icons.check_rounded:Icons.arrow_forward_rounded),label:Text(index==steps.length-1?'Finish demo':'Next talking point'))]))]))));}
  Widget _demoBox(String label,IconData icon,Color color,String body)=>Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:color,size:16),const SizedBox(width:6),Text(label,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900))]),const SizedBox(height:5),Text(body,style:const TextStyle(fontSize:9.5,height:1.45))]));
}

class _FounderCommandPage extends StatefulWidget{
  const _FounderCommandPage({required this.onReplayWalkthrough,required this.onOpenDemo,required this.onStartCustomerPreview,required this.onNavigateLabel});
  final VoidCallback onReplayWalkthrough,onOpenDemo,onStartCustomerPreview;final ValueChanged<String> onNavigateLabel;
  @override State<_FounderCommandPage> createState()=>_FounderCommandPageState();
}
class _FounderCommandPageState extends State<_FounderCommandPage>{
  late Future<Map<String,dynamic>> commandRequest,activityRequest;bool busy=false;
  @override void initState(){super.initState();refresh();}
  void refresh(){commandRequest=_callRpc('bridgepoint_owner_command_center_v153',const {});activityRequest=_callRpc('bridgepoint_owner_activity_v158',const {'p_limit':80});if(mounted)setState((){});}
  Future<void> _inviteOwner()async{final email=TextEditingController(),name=TextEditingController();final values=await showDialog<Map<String,String>>(context:context,builder:(d)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Text('Add a full-access owner'),content:SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('This person will be able to see and operate every package, model, geography and owner tool. Only invite someone you trust with BridgePoint operations.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.45)),const SizedBox(height:10),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),const SizedBox(height:8),TextField(controller:name,decoration:const InputDecoration(labelText:'Display name (optional)',border:OutlineInputBorder()))])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,{'email':email.text.trim(),'name':name.text.trim()}),child:const Text('Send full-owner invite'))]));email.dispose();name.dispose();if(values==null||values['email']!.isEmpty)return;setState(()=>busy=true);try{final response=await Supabase.instance.client.functions.invoke('bridgepoint-owner-invite-v153',body:{'email':values['email'],'display_name':values['name'],'redirect_url':_bridgePointLiveUrl});final r=_edgeFunctionPayload(response.data);if(r['complete']!=true)throw Exception('${r['error']??'Invite failed'}');if(mounted){await _showInfoDialog(context,r['existing_account']==true?'Owner access granted':'Owner invitation sent','${r['message']}');refresh();}}catch(e){if(mounted)_showInfoDialog(context,'Could not add owner','$e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _revoke(Map<String,dynamic> owner)async{final phrase=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(backgroundColor:AppTheme.panel,title:Text('Revoke ${owner['display_name']??owner['email']??'full owner'}?'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('This removes the all-access override. The primary founder cannot be removed here.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)),const SizedBox(height:10),TextField(controller:phrase,decoration:const InputDecoration(labelText:'Type REVOKE FULL OWNER',border:OutlineInputBorder()))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,phrase.text.trim().toUpperCase()=='REVOKE FULL OWNER'),child:const Text('Revoke'))]));phrase.dispose();if(ok!=true)return;try{await _callRpc('bridgepoint_owner_revoke_full_access_v153',{'p_user_id':owner['user_id'],'p_confirmation':'REVOKE FULL OWNER'});refresh();}catch(e){if(mounted)_showInfoDialog(context,'Could not revoke owner','$e');}}
  Future<void> _addTask()async{final title=TextEditingController(),detail=TextEditingController();String priority='NORMAL';final data=await showDialog<Map<String,String>>(context:context,builder:(d)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Text('New owner task'),content:SizedBox(width:560,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Task',border:OutlineInputBorder())),const SizedBox(height:8),TextField(controller:detail,maxLines:3,decoration:const InputDecoration(labelText:'Details',border:OutlineInputBorder())),const SizedBox(height:8),DropdownButtonFormField<String>(value:priority,dropdownColor:AppTheme.panel,items:const ['LOW','NORMAL','HIGH','URGENT'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setLocal(()=>priority=v??priority),decoration:const InputDecoration(labelText:'Priority',border:OutlineInputBorder()))])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,{'title':title.text.trim(),'detail':detail.text.trim(),'priority':priority}),child:const Text('Create task'))])));title.dispose();detail.dispose();if(data==null||data['title']!.isEmpty)return;try{await _callRpc('bridgepoint_owner_add_task_v153',{'p_title':data['title'],'p_description':data['detail'],'p_priority':data['priority'],'p_assigned_to':null,'p_due_at':null,'p_related_area':'FOUNDER_COMMAND'});refresh();}catch(e){if(mounted)_showInfoDialog(context,'Could not create task','$e');}}
  Future<void> _addNote()async{final title=TextEditingController(),note=TextEditingController();final data=await showDialog<Map<String,String>>(context:context,builder:(d)=>AlertDialog(backgroundColor:AppTheme.panel,title:const Text('Private founder decision note'),content:SizedBox(width:580,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Title',border:OutlineInputBorder())),const SizedBox(height:8),TextField(controller:note,maxLines:5,decoration:const InputDecoration(labelText:'Decision / note',border:OutlineInputBorder()))])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,{'title':title.text.trim(),'note':note.text.trim()}),child:const Text('Pin note'))]));title.dispose();note.dispose();if(data==null||data['title']!.isEmpty||data['note']!.isEmpty)return;try{await _callRpc('bridgepoint_owner_save_note_v153',{'p_title':data['title'],'p_note':data['note'],'p_category':'DECISION','p_pinned':true});refresh();}catch(e){if(mounted)_showInfoDialog(context,'Could not save note','$e');}}
  Future<void> _decide(Map<String,dynamic> a,String decision)async{try{await _callRpc('bridgepoint_owner_decide_approval_v158',{'p_approval_id':a['approval_id'],'p_decision':decision,'p_note':null});refresh();}catch(e){if(mounted)_showInfoDialog(context,'Could not decide approval','$e');}}
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(18),child:FutureBuilder<Map<String,dynamic>>(future:commandRequest,builder:(context,snap){if(snap.connectionState==ConnectionState.waiting&&!snap.hasData)return const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2);if(snap.hasError)return _InlineError(message:snap.error.toString());final data=snap.data??const <String,dynamic>{};final access=_bpMap(data['owner_access']),owners=_bpRows(access['executives']),invites=_bpRows(access['pending_invites']),tasks=_bpRows(data['tasks']),notes=_bpRows(data['pinned_notes']),approvals=_bpRows(data['approvals']);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const _PanelHeader(title:'Founder Command Center',subtitle:'Full owners • handoffs • decisions • approvals • moderation • security • demo/test controls',action:'Private owner layer'),const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(onPressed:busy?null:_inviteOwner,icon:const Icon(Icons.person_add_alt_1_rounded),label:const Text('Add full-access owner')),OutlinedButton.icon(onPressed:widget.onReplayWalkthrough,icon:const Icon(Icons.school_outlined),label:const Text('Replay full walkthrough')),OutlinedButton.icon(onPressed:widget.onOpenDemo,icon:const Icon(Icons.slideshow_outlined),label:const Text('Open Demo Mode')),OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer')),OutlinedButton.icon(onPressed:_addTask,icon:const Icon(Icons.add_task_rounded),label:const Text('Owner task')),OutlinedButton.icon(onPressed:_addNote,icon:const Icon(Icons.push_pin_outlined),label:const Text('Pin decision note'))]),const SizedBox(height:13),LayoutBuilder(builder:(context,c){final w=c.maxWidth>=900?(c.maxWidth-18)/4:c.maxWidth>=520?(c.maxWidth-8)/2:c.maxWidth;return Wrap(spacing:8,runSpacing:8,children:[_MetricCard(width:w,label:'FULL OWNERS',value:'${access['full_owner_count']??owners.length}',detail:'Active trusted platform operators',icon:Icons.shield_person_outlined,accent:AppTheme.cyan),_MetricCard(width:w,label:'PENDING COMMUNITY',value:'${data['pending_community']??0}',detail:'Observations waiting review',icon:Icons.gavel_outlined,accent:AppTheme.amber),_MetricCard(width:w,label:'OWNER EMAILS READY',value:'${data['ready_owner_emails']??0}',detail:'Outbox items awaiting delivery',icon:Icons.mark_email_unread_outlined,accent:AppTheme.blue),_MetricCard(width:w,label:'SECURITY ISSUES',value:'${data['open_security_incidents']??0}',detail:'Open incident reports',icon:Icons.security_outlined,accent:AppTheme.red)]);}),const SizedBox(height:14),_OwnerAccessPanel(owners:owners,invites:invites,onInvite:_inviteOwner,onRevoke:_revoke),const SizedBox(height:10),LayoutBuilder(builder:(context,c){final w=c.maxWidth>=900?(c.maxWidth-10)/2:c.maxWidth;return Wrap(spacing:10,runSpacing:10,children:[SizedBox(width:w,child:_FounderListCard(title:'OWNER TASKS',icon:Icons.task_alt_rounded,empty:'No open founder tasks.',children:tasks.take(12).map((t)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Icon(t['priority']=='URGENT'?Icons.priority_high_rounded:Icons.check_circle_outline_rounded,color:t['priority']=='URGENT'?AppTheme.red:t['priority']=='HIGH'?AppTheme.amber:AppTheme.cyan),title:Text('${t['title']}'),subtitle:Text('${t['description']??''}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),trailing:_OpportunityChip(label:'${t['priority']}',color:t['priority']=='URGENT'?AppTheme.red:t['priority']=='HIGH'?AppTheme.amber:AppTheme.cyan))).toList())),SizedBox(width:w,child:_FounderListCard(title:'PINNED DECISIONS',icon:Icons.push_pin_outlined,empty:'No pinned founder decisions yet.',children:notes.take(10).map((n)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.notes_rounded,color:AppTheme.green),title:Text('${n['title']}'),subtitle:Text('${n['note']}',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:8)))).toList()))]);}),if(approvals.isNotEmpty)...[const SizedBox(height:10),_FounderListCard(title:'OWNER APPROVALS',icon:Icons.approval_outlined,empty:'No approvals waiting.',children:approvals.map((a)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.pending_actions_rounded,color:AppTheme.amber),title:Text('${a['title']}'),subtitle:Text('${a['detail']??a['approval_type']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)),trailing:Wrap(spacing:5,children:[TextButton(onPressed:()=>_decide(a,'REJECTED'),child:const Text('Reject')),FilledButton(onPressed:()=>_decide(a,'APPROVED'),child:const Text('Approve'))]))).toList())],const SizedBox(height:10),FutureBuilder<Map<String,dynamic>>(future:activityRequest,builder:(context,aSnap){final items=_bpRows(aSnap.data?['items']);return _FounderListCard(title:'OWNER ACTIVITY',icon:Icons.history_rounded,empty:'Owner activity will appear here as actions are recorded.',children:items.take(20).map((a)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.history_toggle_off_rounded,color:AppTheme.textMuted),title:Text('${a['summary']}'),subtitle:Text('${a['actor']} • ${_bpDateTime(a['created_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8)))).toList());})]);}));
}

class _OwnerAccessPanel extends StatelessWidget{
  const _OwnerAccessPanel({required this.owners,required this.invites,required this.onInvite,required this.onRevoke});final List<Map<String,dynamic>> owners,invites;final VoidCallback onInvite;final Future<void> Function(Map<String,dynamic>) onRevoke;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.shield_person_outlined,color:AppTheme.cyan),const SizedBox(width:7),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('FULL-ACCESS OWNERS',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('More than one trusted person can operate all of BridgePoint. The primary founder is protected from ordinary revocation.',style:TextStyle(color:AppTheme.textMuted,fontSize:8.5))])),TextButton.icon(onPressed:onInvite,icon:const Icon(Icons.person_add_alt_1_rounded,size:16),label:const Text('Add another'))]),const SizedBox(height:9),Wrap(spacing:8,runSpacing:8,children:owners.map((o){final founder=o['executive_role']=='PRIMARY_FOUNDER';return Container(width:330,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(10),border:Border.all(color:(founder?AppTheme.green:AppTheme.cyan).withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[CircleAvatar(radius:17,backgroundColor:(founder?AppTheme.green:AppTheme.cyan).withOpacity(.13),child:Icon(founder?Icons.workspace_premium_outlined:Icons.admin_panel_settings_outlined,size:17,color:founder?AppTheme.green:AppTheme.cyan)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${o['display_name']??o['email']??'Full owner'}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900)),Text(founder?'PRIMARY FOUNDER':'FULL OWNER',style:TextStyle(color:founder?AppTheme.green:AppTheme.cyan,fontSize:7.5,fontWeight:FontWeight.w900))])),if(!founder)PopupMenuButton<String>(onSelected:(v){if(v=='revoke')onRevoke(o);},itemBuilder:(_)=>const [PopupMenuItem(value:'revoke',child:Text('Revoke full access'))])]),const SizedBox(height:7),Wrap(spacing:5,runSpacing:5,children:[_OpportunityChip(label:'ALL MODELS',color:AppTheme.cyan),_OpportunityChip(label:'ALL FEATURES',color:AppTheme.green),_OpportunityChip(label:'ALL STATES',color:AppTheme.blue),_OpportunityChip(label:'OWNER TOOLS',color:AppTheme.amber)]),const SizedBox(height:5),Text('Last seen ${_bpDateTime(o['last_seen_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:7.5))]));}).toList()),if(invites.isNotEmpty)...[const SizedBox(height:10),const Text('PENDING / FAILED INVITES',style:TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w900)),const SizedBox(height:5),...invites.map((i)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Icon(i['status']=='FAILED'?Icons.error_outline_rounded:Icons.mark_email_unread_outlined,color:i['status']=='FAILED'?AppTheme.red:AppTheme.amber),title:Text('${i['email']}'),subtitle:Text('${i['status']} • ${_bpDateTime(i['invited_at'])}${i['last_error']==null?'':' • ${i['last_error']}'}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8))))]])));
}

class _FounderListCard extends StatelessWidget{
  const _FounderListCard({required this.title,required this.icon,required this.empty,required this.children});final String title,empty;final IconData icon;final List<Widget> children;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:AppTheme.cyan,size:18),const SizedBox(width:7),Text(title,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))]),const SizedBox(height:8),if(children.isEmpty)Text(empty,style:const TextStyle(color:AppTheme.textMuted,fontSize:9)) else ...children])));
}

'''
text=text.replace(owner_marker,classes+owner_marker,1)

if text==original:raise SystemExit('No training/demo/founder changes applied')
path.write_text(text,encoding='utf-8')
print('Applied full visual walkthrough, owner demo, multi-owner command center, and customer preview v159')
