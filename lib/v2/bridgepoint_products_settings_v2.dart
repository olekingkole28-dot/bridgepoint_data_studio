import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BridgePointProductsSettingsV2 extends StatefulWidget {
  const BridgePointProductsSettingsV2({super.key});

  @override
  State<BridgePointProductsSettingsV2> createState() => _BridgePointProductsSettingsV2State();
}

class _BridgePointProductsSettingsV2State extends State<BridgePointProductsSettingsV2> {
  int _tab = 0;
  late Future<List<dynamic>> _request;
  bool _busy = false;
  String? _message;

  bool _largeText = false;
  bool _highContrast = false;
  bool _reducedMotion = false;
  bool _simplified = false;
  String _mapStyle = 'satellite';

  bool _inApp = true;
  bool _push = true;
  bool _critical = true;
  bool _followUps = true;
  bool _sourceHealth = true;
  bool _dailyBrief = true;

  String _audience = 'roofing / exterior contractor';
  String _propertyFocus = 'residential homes';
  String _goal = 'find & prioritize opportunities';
  String _teamScale = 'one person';
  String _territory = 'statewide';
  String _integration = 'bridgepoint app';
  final Set<String> _capabilities = {'opportunity scoring', 'weather impact'};
  Map<String, dynamic> _fit = const {};

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);

  static const _audiences = [
    'roofing / exterior contractor','restoration / mitigation','home services contractor','public adjuster / claims professional','property investor / acquisitions','commercial real estate / property management','developer / builder','homeowner','solar / energy','insurer / risk / analytics','institutional investor / analytics','government / infrastructure','software / data / platform','other'
  ];
  static const _propertyFocuses = ['residential homes','commercial properties','mixed residential + commercial','development sites','large portfolios','one home','public infrastructure'];
  static const _goals = ['find & prioritize opportunities','understand risk','manage a team workflow','organize evidence','plan field work','monitor changes','acquire / invest','find development / redevelopment','analyze patterns at scale','integrate / build technology','build custom intelligence','ask natural-language property questions','clean / resolve property data','prove data quality','prove roi / learn from outcomes','track infrastructure / public projects','understand my property','expand geographic data coverage'];
  static const _teamScales = ['one person','2-5 people','6-25 people','26+ people','enterprise / institutional'];
  static const _territories = ['one property','local','statewide','multi-state','national'];
  static const _integrations = ['bridgepoint app','api / embed','managed implementation','white-label portal'];
  static const _capabilityOptions = ['opportunity scoring','weather impact','imagery / physical change','evidence reports','field routes','monitoring','natural-language ai','next-best action','pattern intelligence','portfolio relationships','property resolution','property timeline','signal / evidence normalization','source health / provenance','source roi','team roles / entitlements','api access','custom models','coverage readiness','data onboarding','historical replay','marketplace / entitlements','outcome learning','white-label portal'];

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['packages','items','results','catalog']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try { return await Supabase.instance.client.rpc(name, params: params); }
    catch (e) { return {'available': false, 'rpc': name, 'error': '$e'}; }
  }

  Future<List<dynamic>> _load() async {
    final values = await Future.wait([
      _safe('bridgepoint_flutter_packages_core_v429'),
      _safe('bridgepoint_display_preferences_v80'),
      _safe('bridgepoint_onboarding_state_v70'),
      _safe('bridgepoint_notification_preferences_v834'),
      _safe('bridgepoint_flutter_settings_v59'),
    ]);
    final prefs = _map(values[1]);
    _largeText = prefs['large_text'] == true;
    _highContrast = prefs['high_contrast'] == true;
    _reducedMotion = prefs['reduced_motion'] == true;
    _simplified = prefs['simplified_views'] == true;
    _mapStyle = '${prefs['map_base_style'] ?? 'satellite'}';

    final notify = _map(values[3]);
    _inApp = notify['in_app_enabled'] != false;
    _push = notify['device_push_enabled'] != false;
    _critical = notify['critical_opportunities'] != false;
    _followUps = notify['saved_follow_ups'] != false;
    _sourceHealth = notify['source_health'] != false;
    _dailyBrief = notify['daily_brief'] != false;

    final onboarding = _map(values[2]);
    final profile = _map(onboarding['profile']);
    final answers = _map(profile['fit_answers']);
    if (answers.isNotEmpty) {
      final a='${answers['audience'] ?? ''}'; if (_audiences.contains(a)) _audience=a;
      final p='${answers['property_focus'] ?? ''}'; if (_propertyFocuses.contains(p)) _propertyFocus=p;
      final g='${answers['goal'] ?? ''}'; if (_goals.contains(g)) _goal=g;
      final s='${answers['team_scale'] ?? ''}'; if (_teamScales.contains(s)) _teamScale=s;
      final t='${answers['territory'] ?? ''}'; if (_territories.contains(t)) _territory=t;
      final i='${answers['integration'] ?? ''}'; if (_integrations.contains(i)) _integration=i;
      final caps=answers['capabilities'];
      if (caps is List) {
        _capabilities..clear()..addAll(caps.map((e) => '$e').where(_capabilityOptions.contains));
      }
    }
    final recommendations = _map(profile['fit_recommendations']);
    if (recommendations.isNotEmpty) _fit = recommendations;
    return values;
  }

  Map<String, dynamic> get _answers => {
    'audience': _audience,
    'property_focus': _propertyFocus,
    'goal': _goal,
    'team_scale': _teamScale,
    'territory': _territory,
    'integration': _integration,
    'capabilities': _capabilities.toList()..sort(),
  };

  String _packageKey(Map<String, dynamic> p) => '${p['package_key'] ?? p['key'] ?? ''}';

  String _action(Map<String, dynamic> p) {
    final delivery='${p['delivery_status'] ?? ''}'.toUpperCase();
    final mode='${p['purchase_mode'] ?? ''}'.toUpperCase();
    final self=p['available_for_self_checkout']==true || p['checkout_ready']==true;
    final approval=p['owner_approval_required']==true || mode.contains('APPROVAL') || mode.contains('MANAGED');
    if (delivery=='BUILDING' || delivery=='ROADMAP') return delivery;
    if (self && (delivery.isEmpty || delivery=='READY' || delivery=='IMMEDIATE')) return 'BUY';
    if (approval) return 'REQUEST';
    return 'UNAVAILABLE';
  }

  Future<void> _buy(Map<String, dynamic> package) async {
    final key=_packageKey(package); if (key.isEmpty) return;
    setState(() { _busy=true; _message=null; });
    try {
      final response=await Supabase.instance.client.functions.invoke('bridgepoint-checkout-v67', body:{'package_key':key,'interval':'month'});
      final data=_map(response.data);
      final url='${data['url'] ?? ''}';
      if (data['complete']!=true || url.isEmpty) throw StateError('${data['error'] ?? 'Checkout is not ready.'}');
      if (!await launchUrl(Uri.parse(url), mode:LaunchMode.externalApplication)) throw StateError('Could not open Stripe checkout.');
      if (mounted) setState(() => _message='Stripe checkout opened for ${package['package_name'] ?? key}.');
    } catch (e) { if (mounted) setState(() => _message='Checkout unavailable: $e'); }
    finally { if (mounted) setState(() => _busy=false); }
  }

  Future<void> _requestActivation(Map<String, dynamic> package) async {
    final key=_packageKey(package); if (key.isEmpty) return;
    setState(() { _busy=true; _message=null; });
    try {
      final raw=await Supabase.instance.client.rpc('bridgepoint_request_owner_approved_package_v323', params:{'p_package_key':key,'p_note':'Requested from Clean V2 package workspace.'});
      if (mounted) setState(() => _message='${_map(raw)['message'] ?? 'Activation request submitted.'}');
    } catch (e) { if (mounted) setState(() => _message='Could not request activation: $e'); }
    finally { if (mounted) setState(() => _busy=false); }
  }

  Future<void> _previewFit() async {
    if (_capabilities.isEmpty) { setState(() => _message='Choose at least one capability.'); return; }
    setState(() { _busy=true; _message=null; });
    try {
      final raw=await Supabase.instance.client.rpc('bridgepoint_package_fit_preview_v315', params:{'p_answers':_answers});
      if (mounted) setState(() { _fit=_map(raw); _message='Package fit recalculated.'; });
    } catch (e) { if (mounted) setState(() => _message='Fit preview unavailable: $e'); }
    finally { if (mounted) setState(() => _busy=false); }
  }

  Future<void> _saveFit() async {
    if (_capabilities.isEmpty) { setState(() => _message='Choose at least one capability.'); return; }
    setState(() { _busy=true; _message=null; });
    try {
      final raw=await Supabase.instance.client.rpc('bridgepoint_complete_onboarding_v315', params:{'p_answers':_answers});
      if (mounted) setState(() { _fit=_map(raw); _message='Onboarding answers and recommended package saved.'; });
    } catch (e) { if (mounted) setState(() => _message='Could not save package fit: $e'); }
    finally { if (mounted) setState(() => _busy=false); }
  }

  Future<void> _saveNotifications() async {
    setState(() { _busy=true; _message=null; });
    try {
      await Supabase.instance.client.rpc('bridgepoint_update_notification_preferences_v74', params:{
        'p_in_app_enabled':_inApp,'p_device_push_enabled':_push,'p_critical_opportunities':_critical,'p_saved_follow_ups':_followUps,'p_source_health':_sourceHealth,'p_daily_brief':_dailyBrief,
      });
      if (mounted) setState(() => _message='Notification preferences saved.');
    } catch (e) { if (mounted) setState(() => _message='Could not save notifications: $e'); }
    finally { if (mounted) setState(() => _busy=false); }
  }

  Future<void> _saveDisplay() async {
    setState(() { _busy=true; _message=null; });
    try {
      await Supabase.instance.client.rpc('bridgepoint_update_display_preferences_v98', params:{'p_large_text':_largeText,'p_high_contrast':_highContrast,'p_reduced_motion':_reducedMotion,'p_simplified_views':_simplified,'p_map_base_style':_mapStyle});
      if (mounted) setState(() => _message='Display preferences saved.');
    } catch (e) { if (mounted) setState(() => _message='Could not save preferences: $e'); }
    finally { if (mounted) setState(() => _busy=false); }
  }

  Widget _packageCard(Map<String,dynamic> p) {
    final action=_action(p);
    final name='${p['package_name'] ?? p['name'] ?? _packageKey(p)}';
    final disclosure='${p['customer_delivery_disclosure'] ?? p['delivery_disclosure'] ?? p['description'] ?? ''}';
    final monthly=p['monthly_price'] ?? p['price_monthly'];
    final color=action=='BUY'?_green:action=='REQUEST'?_cyan:_amber;
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[Expanded(child:Text(name,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900))),Chip(label:Text('${p['delivery_status'] ?? p['purchase_mode'] ?? action}'),side:BorderSide(color:color.withValues(alpha:.35)))]),
      if(monthly!=null)...[const SizedBox(height:6),Text('\$$monthly / month',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))],
      if(disclosure.trim().isNotEmpty)...[const SizedBox(height:8),Text(disclosure,style:const TextStyle(color:_muted,fontSize:10,height:1.45))],
      const SizedBox(height:12),
      if(action=='BUY') FilledButton.icon(onPressed:_busy?null:()=>_buy(p),icon:const Icon(Icons.credit_card_rounded),label:const Text('Buy now'))
      else if(action=='REQUEST') FilledButton.tonalIcon(onPressed:_busy?null:()=>_requestActivation(p),icon:const Icon(Icons.outgoing_mail),label:Text('${p['request_cta'] ?? 'Request activation'}'))
      else OutlinedButton.icon(onPressed:null,icon:const Icon(Icons.construction_rounded),label:Text(action=='BUILDING'?'Building — not purchasable yet':action=='ROADMAP'?'Roadmap / interest only':'Not available for self-service')),
    ])));
  }

  Widget _dropdown(String label,String value,List<String> options,ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(initialValue:value,items:options.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:onChanged,decoration:InputDecoration(labelText:label));

  Widget _fitCard() {
    final best=_map(_fit['best_actionable']);
    final overall=_map(_fit['best_overall']);
    if (_fit.isEmpty) return const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Answer the fit questions and preview your best package match.',style:TextStyle(color:_muted))));
    return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Recommended package',style:TextStyle(fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      Text('${best['package_name'] ?? overall['package_name'] ?? _fit['recommended_package_key'] ?? 'BridgePoint package'}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:_cyan)),
      const SizedBox(height:6),
      Text('${best['reason'] ?? overall['reason'] ?? _fit['explanation'] ?? ''}',style:const TextStyle(color:_muted,height:1.45)),
      if(best['action_label']!=null)...[const SizedBox(height:8),Chip(label:Text('${best['action_label']}'))],
    ])));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future:_request,
      builder:(context,snapshot){
        final data=snapshot.data ?? const [];
        dynamic at(int i)=>i<data.length?data[i]:const <String,dynamic>{};
        final packages=_rows(at(0));
        return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('Products & Settings',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          const Text('Package fit, trials, purchase/activation truth, onboarding, notifications, accessibility and display settings.',style:TextStyle(color:_muted,height:1.45)),
          if(_busy || snapshot.connectionState==ConnectionState.waiting)...[const SizedBox(height:8),const LinearProgressIndicator()],
          if(_message!=null)...[const SizedBox(height:8),Text(_message!,style:const TextStyle(color:_cyan))],
          const SizedBox(height:12),
          SingleChildScrollView(scrollDirection:Axis.horizontal,child:SegmentedButton<int>(segments:const[
            ButtonSegment(value:0,icon:Icon(Icons.workspace_premium_outlined),label:Text('Packages')),
            ButtonSegment(value:1,icon:Icon(Icons.tune_rounded),label:Text('Find my fit')),
            ButtonSegment(value:2,icon:Icon(Icons.notifications_active_outlined),label:Text('Notifications')),
            ButtonSegment(value:3,icon:Icon(Icons.accessibility_new_rounded),label:Text('Display')),
          ],selected:{_tab},onSelectionChanged:(v)=>setState(()=>_tab=v.first))),
          const SizedBox(height:14),
          if(_tab==0)
            LayoutBuilder(builder:(context,c){final columns=c.maxWidth>=1200?3:c.maxWidth>=760?2:1;final width=(c.maxWidth-(columns-1)*12)/columns;return Wrap(spacing:12,runSpacing:12,children:packages.map((p)=>SizedBox(width:width,child:_packageCard(p))).toList());}),
          if(_tab==1)...[
            LayoutBuilder(builder:(context,c){final two=c.maxWidth>900;final width=two?(c.maxWidth-12)/2:c.maxWidth;return Wrap(spacing:12,runSpacing:12,children:[
              SizedBox(width:width,child:_dropdown('Who are you?',_audience,_audiences,(v)=>setState(()=>_audience=v??_audience))),
              SizedBox(width:width,child:_dropdown('Property focus',_propertyFocus,_propertyFocuses,(v)=>setState(()=>_propertyFocus=v??_propertyFocus))),
              SizedBox(width:width,child:_dropdown('Primary goal',_goal,_goals,(v)=>setState(()=>_goal=v??_goal))),
              SizedBox(width:width,child:_dropdown('Team size',_teamScale,_teamScales,(v)=>setState(()=>_teamScale=v??_teamScale))),
              SizedBox(width:width,child:_dropdown('Territory',_territory,_territories,(v)=>setState(()=>_territory=v??_territory))),
              SizedBox(width:width,child:_dropdown('Delivery / integration',_integration,_integrations,(v)=>setState(()=>_integration=v??_integration))),
            ]);}),
            const SizedBox(height:12),
            const Text('Capabilities you need',style:TextStyle(fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            Wrap(spacing:7,runSpacing:7,children:_capabilityOptions.map((cap)=>FilterChip(selected:_capabilities.contains(cap),label:Text(cap),onSelected:(selected)=>setState(()=>selected?_capabilities.add(cap):_capabilities.remove(cap)))).toList()),
            const SizedBox(height:12),
            Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(onPressed:_busy?null:_previewFit,icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Preview best fit')),FilledButton.tonalIcon(onPressed:_busy?null:_saveFit,icon:const Icon(Icons.save_rounded),label:const Text('Save onboarding + recommendation'))]),
            const SizedBox(height:12),
            _fitCard(),
          ],
          if(_tab==2) Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            SwitchListTile(value:_inApp,onChanged:(v)=>setState(()=>_inApp=v),title:const Text('In-app notifications')),
            SwitchListTile(value:_push,onChanged:(v)=>setState(()=>_push=v),title:const Text('Device push notifications')),
            SwitchListTile(value:_critical,onChanged:(v)=>setState(()=>_critical=v),title:const Text('Critical / high-priority opportunities')),
            SwitchListTile(value:_followUps,onChanged:(v)=>setState(()=>_followUps=v),title:const Text('Saved follow-ups / next actions')),
            SwitchListTile(value:_sourceHealth,onChanged:(v)=>setState(()=>_sourceHealth=v),title:const Text('Source health / freshness alerts')),
            SwitchListTile(value:_dailyBrief,onChanged:(v)=>setState(()=>_dailyBrief=v),title:const Text('Daily intelligence brief')),
            const SizedBox(height:8),
            Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:_busy?null:_saveNotifications,icon:const Icon(Icons.save_rounded),label:const Text('Save notifications'))),
          ]))),
          if(_tab==3) Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            SwitchListTile(value:_largeText,onChanged:(v)=>setState(()=>_largeText=v),title:const Text('Larger text')),
            SwitchListTile(value:_highContrast,onChanged:(v)=>setState(()=>_highContrast=v),title:const Text('Higher contrast')),
            SwitchListTile(value:_reducedMotion,onChanged:(v)=>setState(()=>_reducedMotion=v),title:const Text('Reduced motion')),
            SwitchListTile(value:_simplified,onChanged:(v)=>setState(()=>_simplified=v),title:const Text('Simplified views')),
            DropdownButtonFormField<String>(initialValue:const ['satellite','street','standard'].contains(_mapStyle)?_mapStyle:'satellite',items:const[DropdownMenuItem(value:'satellite',child:Text('Satellite / aerial-first')),DropdownMenuItem(value:'street',child:Text('Street map')),DropdownMenuItem(value:'standard',child:Text('Standard'))],onChanged:(v)=>setState(()=>_mapStyle=v??'satellite'),decoration:const InputDecoration(labelText:'Default map style')),
            const SizedBox(height:10),
            Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:_busy?null:_saveDisplay,icon:const Icon(Icons.save_rounded),label:const Text('Save display preferences'))),
          ]))),
          const SizedBox(height:10),
          const Text('Commercial truth rule: BUILDING/ROADMAP packages are never presented as immediately purchasable. Checkout uses the live Stripe contract, trial eligibility, current delivery disclosures and account entitlements.',style:TextStyle(color:_amber,fontSize:10,height:1.45)),
        ]);
      },
    );
  }
}
