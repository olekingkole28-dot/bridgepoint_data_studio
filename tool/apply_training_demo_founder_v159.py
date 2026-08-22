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
    Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:AnimatedSwitcher(duration:const Duration(milliseconds:220),child:Column(key:ValueKey(index),crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['body']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:11,height:1.65)),if('${s['why_it_matters']??''}'.isNotEmpty)...[const SizedBox(height:15),Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.blue.withOpacity(.065),borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('WHY IT MATTERS',style:TextStyle(color:AppTheme.blue,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.8)),const SizedBox(height:5),Text('${s['why_it_matters']}',style:const TextStyle(fontSize:10,height:1.5))]))],const SizedBox(height:12),LayoutBuilder(builder:(context,c){final wide=c.maxWidth>650;final tip=Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.065),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.amber.withOpacity(.13))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.pets_outlined,color:AppTheme.amber,size:17),SizedBox(width:7),Text("MOLLY'S TIP",style:TextStyle(color:AppTheme.amber,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.5))]),const SizedBox(height:5),Text('${s['tip']??''}',style:const TextStyle(fontSize:9.5,height:1.45)),const SizedBox(height:5),Text(index%4==0?'Molly says: sniff out the evidence before you chase the lead.':index%4==1?'Molly says: save the good one before it runs away.':index%4==2?'Molly says: the map knows where the trail starts.':'Molly says: facts first. Tail wags second.',style:const TextStyle(color:AppTheme.amber,fontSize:8,fontStyle:FontStyle.italic))]));final tryIt=Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.green.withOpacity(.06),borderRadius:BorderRadius.circular(11)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.touch_app_outlined,color:AppTheme.green,size:16),SizedBox(width:6),Text('TRY THIS NOW',style:TextStyle(color:AppTheme.green,fontSize:8,fontWeight:FontWeight.w900))]),const SizedBox(height:5),Text('${s['try_this']??''}',style:const TextStyle(fontSize:9.5,height:1.45))]));return wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:tip),const SizedBox(width:9),Expanded(child:tryIt)]):Column(children:[tip,const SizedBox(height:9),tryIt]);}),if('${s['nav_label']??''}'.isNotEmpty)...[const SizedBox(height:13),OutlinedButton.icon(onPressed:()=>widget.onNavigateLabel('${s['nav_label']}'),icon:const Icon(Icons.open_in_new_rounded),label:Text('Show me ${s['nav_label']}'))]]))))),
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
class _GuidedDemoDialogState extends State<_GuidedDemoDialog>{int index=0;@override Widget build(BuildContext context){final p=_bpMap(widget.data['package']),steps=_bpRows(widget.data['steps']);final s=steps[index];final asset='${s['visual_asset']}';return Dialog(backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.all(16),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:980,maxHeight:840),child:Container(decoration:BoxDecoration(color:AppTheme.panel,borderRadius:BorderRadius.circular(18)),child:Column(children:[ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(18)),child:SizedBox(height:190,width:double.infinity,child:Stack(fit:StackFit.expand,children:[Image.asset(asset,fit:BoxFit.cover,color:Colors.white.withOpacity(.28),colorBlendMode:BlendMode.modulate),DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withOpacity(.1),AppTheme.panel.withOpacity(.95)]))),Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Text('${p['package_name']}',style:const TextStyle(color:AppTheme.cyan,fontSize:10,fontWeight:FontWeight.w900)),const Spacer(),Text('DEMO ${index+1}/${steps.length}',style:const TextStyle(color:Colors.white70,fontSize:8,fontWeight:FontWeight.w900)),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),const Spacer(),Text('${s['title']}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900))]))]))),LinearProgressIndicator(value:(index+1)/steps.length,minHeight:4,backgroundColor:Colors.white10,valueColor:const AlwaysStoppedAnimation(AppTheme.cyan)),Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_DemoSection(label:'SAY THIS',value:'${s['say_this']}',color:AppTheme.cyan,icon:Icons.record_voice_over_outlined),const SizedBox(height:9),_DemoSection(label:'SHOW THIS',value:'${s['show_this']}',color:AppTheme.blue,icon:Icons.visibility_outlined),const SizedBox(height:9),_DemoSection(label:'PROVE THIS',value:'${s['prove_this']}',color:AppTheme.green,icon:Icons.fact_check_outlined),const SizedBox(height:9),_DemoSection(label:'PRESENTER TIP',value:'${s['presenter_tip']}',color:AppTheme.amber,icon:Icons.lightbulb_outline_rounded),const SizedBox(height:9),_DemoSection(label:'IF THEY PUSH BACK',value:'${s['objection_response']}',color:Colors.pinkAccent,icon:Icons.forum_outlined),if('${s['screen']}!='null'&&'${s['screen']}'.isNotEmpty)...[const SizedBox(height:11),OutlinedButton.icon(onPressed:()=>widget.onNavigateLabel('${s['screen']}'),icon:const Icon(Icons.open_in_new_rounded),label:Text('Open ${s['screen']} behind demo'))]]))),Padding(padding:const EdgeInsets.all(16),child:Row(children:[TextButton(onPressed:index==0?null:()=>setState(()=>index--),child:const Text('Back')),const Spacer(),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('End demo')),const SizedBox(width:7),FilledButton.icon(onPressed:(){if(index>=steps.length-1){Navigator.pop(context);}else{setState(()=>index++);}},icon:Icon(index>=steps.length-1?Icons.handshake_outlined:Icons.arrow_forward_rounded),label:Text(index>=steps.length-1?'Finish & close':'Next demo step'))]))]))));}
}

class _DemoSection extends StatelessWidget{
  const _DemoSection({required this.label,required this.value,required this.color,required this.icon});final String label,value;final Color color;final IconData icon;
  @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withOpacity(.05),borderRadius:BorderRadius.circular(10),border:Border.all(color:color.withOpacity(.12))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:18),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:.5)),const SizedBox(height:4),Text(value,style:const TextStyle(fontSize:9.5,height:1.45))]))]));
}

class _FounderCommandPage extends StatefulWidget{
  const _FounderCommandPage({required this.onReplayWalkthrough,required this.onOpenDemo,required this.onStartCustomerPreview,required this.onNavigateLabel});
  final VoidCallback onReplayWalkthrough,onOpenDemo,onStartCustomerPreview;final ValueChanged<String> onNavigateLabel;
  @override State<_FounderCommandPage> createState()=>_FounderCommandPageState();
}
class _FounderCommandPageState extends State<_FounderCommandPage>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_founder_command_center_v155',const {});}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_founder_command_center_v155',const {}));
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(18),child:FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snap){if(snap.connectionState==ConnectionState.waiting&&!snap.hasData)return const LinearProgressIndicator(color:AppTheme.cyan,minHeight:2);if(snap.hasError)return _InlineError(message:snap.error.toString());final data=snap.data??{};final legal=_bpMap(data['legal']);final community=_bpMap(data['community_inbox']);final email=_bpMap(data['email_outbox']);final people=_bpRows(data['recent_people']);final learning=_bpMap(data['outcome_learning']);final sources=_bpMap(data['source_health']);final expansion=_bpMap(data['expansion']);final route=_bpMap(data['route_offline']);final allAccess=_bpMap(data['all_access']);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:_PanelHeader(title:'Founder Command Center',subtitle:'Everything important to owning, demoing and operating BridgePoint in one place',action:'Owner-only')),IconButton(onPressed:refresh,icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan))]),const SizedBox(height:10),const _ExplainerBanner(icon:Icons.admin_panel_settings_outlined,title:'This page is your platform cockpit',message:'You have permanent founder access. Use Demo Mode to sell a package, Preview as Customer to see what buyers see, replay training whenever you want, moderate incoming community intelligence, review email delivery, watch sources, routes/offline health, outcomes and expansion without customer plan gates.'),const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(onPressed:widget.onOpenDemo,icon:const Icon(Icons.slideshow_rounded),label:const Text('Open Demo Mode')),OutlinedButton.icon(onPressed:widget.onReplayWalkthrough,icon:const Icon(Icons.school_outlined),label:const Text('Replay Full Walkthrough')),OutlinedButton.icon(onPressed:widget.onStartCustomerPreview,icon:const Icon(Icons.visibility_outlined),label:const Text('Preview as customer'))]),const SizedBox(height:13),Wrap(spacing:9,runSpacing:9,children:[_FounderStat(label:'ALL ACCESS',value:allAccess['founder_override']==true?'ON':'CHECK',color:AppTheme.green),_FounderStat(label:'USERS',value:'${data['registered_users']??0}',color:AppTheme.cyan),_FounderStat(label:'COMMUNITY REVIEW',value:'${community['pending_count']??0}',color:AppTheme.amber),_FounderStat(label:'EMAIL READY',value:'${email['ready_count']??0}',color:AppTheme.blue),_FounderStat(label:'ROUTES',value:'${route['route_count']??0}',color:AppTheme.green),_FounderStat(label:'OFFLINE QUEUED',value:'${route['offline_events_waiting']??0}',color:AppTheme.amber),_FounderStat(label:'OUTCOMES',value:'${learning['outcomes']??0}',color:AppTheme.cyan),_FounderStat(label:'SOURCES',value:'${sources['active_sources']??0}',color:AppTheme.blue),_FounderStat(label:'EXPANSION RUNS',value:'${expansion['runs']??0}',color:AppTheme.green)]),const SizedBox(height:12),LayoutBuilder(builder:(context,c){final w=c.maxWidth>=1100?(c.maxWidth-18)/3:c.maxWidth>=730?(c.maxWidth-9)/2:c.maxWidth;return Wrap(spacing:9,runSpacing:9,children:[SizedBox(width:w,child:_FounderBlock(title:'Incoming Community',icon:Icons.gavel_outlined,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${community['pending_count']??0} waiting for your review',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:7),..._bpRows(community['items']).take(4).map((i)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Text('• ${i['full_address']??'Property'} — ${i['label']??i['observation_key']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)))),TextButton.icon(onPressed:()=>widget.onNavigateLabel('Community'),icon:const Icon(Icons.open_in_new_rounded,size:15),label:const Text('Open Community'))]))),SizedBox(width:w,child:_FounderBlock(title:'Email Delivery',icon:Icons.mark_email_unread_outlined,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${email['destination']??'olekingkole28@gmail.com'}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:9.5)),const SizedBox(height:6),Text('${email['ready_count']??0} ready • ${email['failed_count']??0} failed • ${email['sent_24h']??0} sent in 24h',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),const SizedBox(height:6),Text('BridgePoint records provider delivery status so “sent” means a provider accepted it.',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4))]))),SizedBox(width:w,child:_FounderBlock(title:'Legal & Security',icon:Icons.security_outlined,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${legal['required_documents']??0} required documents • ${legal['unaccepted_required']??0} waiting',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:9)),const SizedBox(height:6),Text('${data['mfa_active']==true?'MFA-backed session':'MFA recommended'}',style:TextStyle(color:data['mfa_active']==true?AppTheme.green:AppTheme.amber,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:7),TextButton.icon(onPressed:()=>widget.onNavigateLabel('Settings'),icon:const Icon(Icons.open_in_new_rounded,size:15),label:const Text('Open Settings / Security'))]))),SizedBox(width:w,child:_FounderBlock(title:'Recent People',icon:Icons.group_outlined,child:people.isEmpty?const Text('No recent activity yet.',style:TextStyle(color:AppTheme.textMuted,fontSize:9)):Column(crossAxisAlignment:CrossAxisAlignment.start,children:people.take(5).map((p)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Text('• ${p['email']??p['display_name']??'User'} — ${p['active_now']==true?'using now':_bpDateTime(p['last_seen_at'])}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)))).toList()))),SizedBox(width:w,child:_FounderBlock(title:'Outcome Learning',icon:Icons.insights_outlined,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${learning['outcomes']??0} recorded outcomes',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${learning['won']??0} won • ${learning['lost']??0} lost • ${learning['contracts']??0} contracts',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),const SizedBox(height:7),Text('This is the feedback loop that turns field truth into stronger future ranking.',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5,height:1.4))]))),SizedBox(width:w,child:_FounderBlock(title:'Expansion Engine',icon:Icons.public_outlined,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${expansion['runs']??0} expansion runs',style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${expansion['waiting_approval']??0} awaiting approval • ${expansion['errors']??0} errors',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)),const SizedBox(height:7),TextButton.icon(onPressed:()=>widget.onNavigateLabel('Owner Center'),icon:const Icon(Icons.open_in_new_rounded,size:15),label:const Text('Open one-click expansion'))])))]);}),const SizedBox(height:12),_FounderBlock(title:'Recent source / pipeline issues',icon:Icons.health_and_safety_outlined,child:_bpRows(sources['issues']).isEmpty?const Text('No recent source-health issues surfaced.',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w800)):Column(children:_bpRows(sources['issues']).take(12).map((i)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:Icon(Icons.warning_amber_rounded,color:'${i['severity']}'=='HIGH'?Colors.redAccent:AppTheme.amber,size:18),title:Text('${i['source_name']??i['source_key']??'Source issue'}'),subtitle:Text('${i['message']??i['last_error']??''}',style:const TextStyle(color:AppTheme.textMuted,fontSize:8.5)))).toList()))]));});
}
class _FounderStat extends StatelessWidget{const _FounderStat({required this.label,required this.value,required this.color});final String label,value;final Color color;@override Widget build(BuildContext context)=>Container(width:145,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:color.withOpacity(.055),borderRadius:BorderRadius.circular(10),border:Border.all(color:color.withOpacity(.13))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:TextStyle(color:color,fontSize:7.5,fontWeight:FontWeight.w900,letterSpacing:.5)),const SizedBox(height:4),Text(value,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))]));}
class _FounderBlock extends StatelessWidget{const _FounderBlock({required this.title,required this.icon,required this.child});final String title;final IconData icon;final Widget child;@override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:AppTheme.cyan,size:18),const SizedBox(width:7),Text(title,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))]),const SizedBox(height:9),child])));}

'''
text=text.replace(owner_marker,classes+owner_marker,1)

if text==original:
    raise SystemExit('No training/demo/founder UI changes applied')
path.write_text(text,encoding='utf-8')
print('Applied full visual walkthrough, Molly tips, owner demo, multi-owner command center, and customer preview v159')
