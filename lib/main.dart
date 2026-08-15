import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _supabaseUrl = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
// Supabase publishable keys are intentionally safe for client applications.
// Never place a service_role or sb_secret key in Flutter source code.
const _supabasePublishableKey =
    'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';

Map<String, String> _apiHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return {
    'apikey': _supabasePublishableKey,
    if (token != null) 'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabasePublishableKey,
  );
  runApp(const BridgePointApp());
}

class BridgePointApp extends StatelessWidget {
  const BridgePointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, _) => Supabase.instance.client.auth.currentSession == null
        ? const _AuthScreen()
        : const _WorkspaceGate(),
  );
}

Future<Map<String, dynamic>> _callRpc(String name, Map<String, dynamic> body) async {
  final response = await http.post(
    Uri.parse('$_supabaseUrl/rest/v1/rpc/$name'),
    headers: _apiHeaders(),
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 30));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) throw const FormatException('Unexpected BridgePoint response.');
  return Map<String, dynamic>.from(decoded);
}

class _WorkspaceGate extends StatefulWidget {
  const _WorkspaceGate();
  @override State<_WorkspaceGate> createState()=>_WorkspaceGateState();
}
class _WorkspaceGateState extends State<_WorkspaceGate> {
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_onboarding_state_v70',const {});}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting)return const Scaffold(body:Center(child:CircularProgressIndicator(color:AppTheme.cyan)));
      if(snapshot.hasError)return Scaffold(body:Center(child:_DashboardError(message:snapshot.error.toString(),onRetry:()=>setState(()=>request=_callRpc('bridgepoint_onboarding_state_v70',const {})))));
      if(snapshot.data?['onboarding_complete']!=true)return _OnboardingScreen(onComplete:()=>setState(()=>request=_callRpc('bridgepoint_onboarding_state_v70',const {})));
      return DashboardScreen(ownerMode:snapshot.data?['owner_bypass']==true);
    },
  );
}

class _OnboardingScreen extends StatefulWidget {
  const _OnboardingScreen({required this.onComplete});
  final VoidCallback onComplete;
  @override State<_OnboardingScreen> createState()=>_OnboardingScreenState();
}
class _OnboardingScreenState extends State<_OnboardingScreen>{
  String industry='Roofing',role='Owner',goal='Find the best leads',territory='Statewide Connecticut',experience='Growing business';
  bool loading=false; String? error;
  Future<void> submit() async {setState(()=>loading=true);try{
    final result=await _callRpc('bridgepoint_complete_onboarding_v70',{
      'p_industry':industry,'p_role_name':role,'p_primary_goal':goal,'p_territory':territory,'p_experience_level':experience});
    if(!mounted)return;
    await showDialog(context:context,builder:(context)=>AlertDialog(
      title:const Row(children:[Icon(Icons.auto_awesome_rounded,color:AppTheme.cyan),SizedBox(width:10),Text('Your recommended workspace')]),
      content:Text('${_packageName(result['recommended_package_key'])}\n\n${result['reason']}',style:const TextStyle(height:1.5)),
      actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Open my workspace'))],));
    widget.onComplete();
  }catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>loading=false);}}
  static String _packageName(dynamic key)=>const {
    'roofing_opportunity':'Roofing Opportunity','bridgepoint_commercial':'BridgePoint Commercial',
    'property_investor':'Property Investor','solar_opportunity':'Solar Opportunity',
    'development_opportunity':'Development Opportunity','bridgepoint_home':'BridgePoint Home','all':'All Intelligence'
  }[key]??'All Intelligence';
  Widget drop(String label,String value,List<String> options,ValueChanged<String?> change)=>DropdownButtonFormField<String>(
    value:value,dropdownColor:AppTheme.panel,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
    items:options.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:loading?null:change);
  @override Widget build(BuildContext context)=>Scaffold(body:_ExperienceBackground(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Card(child:Container(
    width:680,padding:const EdgeInsets.all(30),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.route_rounded,color:AppTheme.cyan,size:48),const SizedBox(height:12),
      const Text('Let’s build the right BridgePoint workspace',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),const Text('Choose the answers that fit you best. BridgePoint will recommend the package and intelligence most useful for your work.',textAlign:TextAlign.center,style:TextStyle(color:AppTheme.textMuted,height:1.5)),
      const SizedBox(height:24),drop('What kind of work do you do?',industry,const ['Roofing','Home services','Restoration','Public adjusting','Commercial real estate','Property investing','Development','Solar','Other'],(v)=>setState(()=>industry=v??industry)),
      const SizedBox(height:12),drop('What is your role?',role,const ['Owner','Sales manager','Sales representative','Estimator','Investor','Developer','Operations','Other'],(v)=>setState(()=>role=v??role)),
      const SizedBox(height:12),drop('What is your main goal?',goal,const ['Find the best leads','Prioritize my current leads','Monitor properties','Plan field visits','Find development opportunities','Track customer follow-ups'],(v)=>setState(()=>goal=v??goal)),
      const SizedBox(height:12),drop('Where do you work?',territory,const ['Statewide Connecticut','One municipality','One county','Multiple counties','New England'],(v)=>setState(()=>territory=v??territory)),
      const SizedBox(height:12),drop('Which best describes your business?',experience,const ['Just getting started','Growing business','Established team','Multi-location operation'],(v)=>setState(()=>experience=v??experience)),
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber))],
      const SizedBox(height:20),FilledButton.icon(onPressed:loading?null:submit,icon:const Icon(Icons.auto_awesome_rounded),label:Text(loading?'Building recommendation…':'Show my recommendation')),
    ]),
  ))))));
}

class _AuthScreen extends StatefulWidget {
  const _AuthScreen();
  @override
  State<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<_AuthScreen> {
  final displayName=TextEditingController(); final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false,showPassword=false; String? error;
  Future<void> submit() async {
    setState(()=>loading=true); error=null;
    try {
      if(create) {
        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text,
          data:{'display_name':displayName.text.trim()});
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
    } catch(e) { if(mounted) setState(()=>error=e.toString()); }
    finally { if(mounted) setState(()=>loading=false); }
  }
  @override void dispose(){displayName.dispose();email.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:_ExperienceBackground(child:Center(child:SingleChildScrollView(child:Card(child:Container(
    width:430,padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.hub_rounded,color:AppTheme.cyan,size:48),const SizedBox(height:14),
      const Text('BRIDGEPOINT INTELLIGENCE',textAlign:TextAlign.center,style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,letterSpacing:1)),
      const SizedBox(height:8),Text(create?'Create your 7-day trial':'Sign in to live property intelligence',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted)),
      const SizedBox(height:24),if(create)...[TextField(controller:displayName,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Profile name',hintText:'How BridgePoint should welcome you',border:OutlineInputBorder())),const SizedBox(height:12)],TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),
      const SizedBox(height:12),TextField(
        controller:password,obscureText:!showPassword,onSubmitted:(_)=>submit(),
        decoration:InputDecoration(
          labelText:'Password',border:const OutlineInputBorder(),
          suffixIcon:IconButton(
            tooltip:showPassword?'Hide password':'Show password',
            onPressed:()=>setState(()=>showPassword=!showPassword),
            icon:Icon(showPassword?Icons.visibility_off_rounded:Icons.visibility_rounded),
          ),
        ),
      ),
      if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:AppTheme.amber,fontSize:11))],
      const SizedBox(height:18),FilledButton(onPressed:loading?null:submit,child:Text(loading?'Please wait…':create?'Start free trial':'Sign in')),
      TextButton(onPressed:loading?null:()=>setState(()=>create=!create),child:Text(create?'Already have an account? Sign in':'New here? Start 7-day trial')),
    ]),
  ))))));
}

class _ExperienceBackground extends StatelessWidget {
  const _ExperienceBackground({required this.child});
  final Widget child;
  @override Widget build(BuildContext context)=>Container(
    decoration:const BoxDecoration(image:DecorationImage(
      image:AssetImage('assets/images/bridgepoint-intelligence-background-v1.webp'),fit:BoxFit.cover)),
    child:Container(
      decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:[AppTheme.navy.withOpacity(.30),AppTheme.navy.withOpacity(.72)])),
      child:child,
    ),
  );
}

Future<void> _openStripeFlow(BuildContext context,String functionName,Map<String,dynamic> body) async {
  final session=Supabase.instance.client.auth.currentSession;
  if(session==null){_showInfoDialog(context,'Sign in required','Please sign in before managing billing.');return;}
  try{
    final response=await http.post(Uri.parse('$_supabaseUrl/functions/v1/$functionName'),headers:{
      'apikey':_supabasePublishableKey,'Authorization':'Bearer ${session.accessToken}','Content-Type':'application/json'
    },body:jsonEncode(body)).timeout(const Duration(seconds:30));
    final decoded=jsonDecode(response.body);
    if(response.statusCode<200||response.statusCode>=300||decoded is! Map||decoded['url']==null) throw Exception(decoded is Map?decoded['error']:'Billing request failed');
    if(!await launchUrl(Uri.parse(decoded['url'].toString()),mode:LaunchMode.externalApplication)) throw Exception('Could not open Stripe');
  }catch(e){if(context.mounted)_showInfoDialog(context,'Billing unavailable',e.toString());}
}

Future<void> _startCheckout(BuildContext context,Map<String,dynamic> package,String interval)=>
  _openStripeFlow(context,'bridgepoint-checkout-v67',{'package_key':package['package_key'],'interval':interval});

Future<void> _openBillingPortal(BuildContext context)=>
  _openStripeFlow(context,'bridgepoint-billing-portal-v66',const {});

class AppTheme {
  static const Color navy = Color(0xFF07111F);
  static const Color panel = Color(0xFF0D1A2B);
  static const Color panelSoft = Color(0xFF122238);
  static const Color cyan = Color(0xFF35D2E8);
  static const Color blue = Color(0xFF4F7CFF);
  static const Color green = Color(0xFF38D49A);
  static const Color amber = Color(0xFFFFC857);
  static const Color red = Color(0xFFFF6B6B);
  static const Color textMuted = Color(0xFF8FA5BF);

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      surface: panel,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: navy,
      fontFamily: 'Segoe UI',
      dividerColor: Colors.white.withOpacity(0.08),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key,this.ownerMode=false});
  final bool ownerMode;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedNavigation = 0;
  String selectedPackage = 'BridgePoint Home';
  late Future<Map<String, dynamic>> dashboardRequest;
  late Future<Map<String, dynamic>> sourcesRequest;
  late Future<Map<String, dynamic>> settingsRequest;
  late Future<Map<String, dynamic>> healthRequest;
  Timer? _liveRefreshTimer;
  Timer? _liveCountdownTimer;
  int _liveRefreshTick = 0;
  int _refreshSeconds = 120;
  int _secondsToRefresh = 120;

  static const packageModelKeys = <String, String>{
    'All Intelligence': 'all',
    'BridgePoint Home': 'bridgepoint_home',
    'BridgePoint Commercial': 'bridgepoint_commercial',
    'Roofing Opportunity': 'roofing_opportunity',
    'BridgePoint General': 'bridgepoint_general_v1',
    'Property Investor': 'property_investor',
    'Development Opportunity': 'development_opportunity',
    'Solar Opportunity': 'solar_opportunity',
  };

  static const navigationItems = <_NavigationItem>[
    _NavigationItem('Daily Brief', Icons.wb_sunny_outlined),
    _NavigationItem('Opportunities', Icons.bolt_rounded),
    _NavigationItem('Intelligence Map', Icons.map_rounded),
    _NavigationItem('Properties', Icons.home_work_rounded),
    _NavigationItem('Signals', Icons.radar_rounded),
    _NavigationItem('Sources', Icons.hub_rounded),
    _NavigationItem('My Work', Icons.work_history_rounded),
    _NavigationItem('Permit Context', Icons.construction_rounded),
    _NavigationItem('Packages', Icons.inventory_2_outlined),
    _NavigationItem('Models', Icons.psychology_alt_rounded),
    _NavigationItem('Settings', Icons.settings_rounded),
  ];

  List<_NavigationItem> get visibleNavigationItems=>[
    ...navigationItems,
    if(widget.ownerMode)
      const _NavigationItem('Owner Center',Icons.admin_panel_settings_rounded),
  ];

  static const packages = <String>[
    'All Intelligence',
    'BridgePoint Home',
    'BridgePoint Commercial',
    'Roofing Opportunity',
    'BridgePoint General',
    'Property Investor',
    'Development Opportunity',
    'Solar Opportunity',
  ];

  @override
  void initState() {
    super.initState();
    if(widget.ownerMode)selectedPackage='All Intelligence';
    dashboardRequest = _loadDashboard();
    sourcesRequest = _loadSources();
    settingsRequest = _loadRuntimeSettings();
    healthRequest = _loadSystemHealth();
    _scheduleLiveRefresh(_refreshSeconds);
    _configureFromServer();
    if(!widget.ownerMode){
      WidgetsBinding.instance.addPostFrameCallback((_)=>_maybeOfferWalkthrough());
    }
  }

  Future<void> _maybeOfferWalkthrough() async {
    try {
      final state=await _callRpc('bridgepoint_walkthrough_state_v73',const {});
      if(!mounted||state['should_offer']!=true)return;
      final start=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
        backgroundColor:AppTheme.panel,
        title:const Text('Want a 2-minute guided tour?'),
        content:const Text('We will show you how to read an opportunity, use the map, save leads, plan follow-ups, and control alerts. You can skip this and reopen it later in Settings.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Not now')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Show me around')),
        ],
      ));
      if(start==true){
        await _callRpc('bridgepoint_set_walkthrough_v73',{'p_status':'STARTED'});
        if(!mounted)return;
        await showDialog<void>(context:context,builder:(context)=>const _WalkthroughDialog());
        await _callRpc('bridgepoint_set_walkthrough_v73',{'p_status':'COMPLETED'});
      }else{
        await _callRpc('bridgepoint_set_walkthrough_v73',{'p_status':'DISMISSED'});
      }
    }catch(_){/* Never block the workspace if the optional tour is unavailable. */}
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _liveCountdownTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_dashboard_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_model_key': packageModelKeys[selectedPackage] ?? 'all',
            'p_limit': 10,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint API response.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _loadSources() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_sources',
          ),
          headers: _apiHeaders(),
          body: '{}',
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Sources API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Sources response.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _loadSimpleRpc(String functionName) async {
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/$functionName'),
      headers: _apiHeaders(),
      body: '{}',
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('BridgePoint API ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Unexpected API response.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _loadRuntimeSettings() =>
      _loadSimpleRpc('bridgepoint_flutter_settings_v59');

  Future<Map<String, dynamic>> _loadSystemHealth() =>
      _loadSimpleRpc('bridgepoint_flutter_system_health_v59');

  Future<void> _configureFromServer() async {
    try {
      final payload = await settingsRequest;
      final settings = payload['settings'];
      if (settings is Map) {
        final seconds = (settings['auto_refresh_seconds'] as num?)?.toInt();
        if (seconds != null && seconds >= 30 && mounted) {
          _scheduleLiveRefresh(seconds);
          setState(() => _refreshSeconds = seconds);
        }
      }
    } catch (_) {
      // The workspace remains usable with the safe 120-second default.
    }
  }

  void _scheduleLiveRefresh(int seconds) {
    _liveRefreshTimer?.cancel();
    _liveCountdownTimer?.cancel();
    _secondsToRefresh=seconds;
    _liveRefreshTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) {
        _secondsToRefresh=seconds;
        _refreshLiveWorkspace();
      },
    );
    _liveCountdownTimer=Timer.periodic(const Duration(seconds:1),(_){
      if(!mounted)return;
      setState(()=>_secondsToRefresh=_secondsToRefresh<=1?seconds:_secondsToRefresh-1);
    });
  }

  void _setRefreshSeconds(int seconds) {
    _scheduleLiveRefresh(seconds);
    setState(() => _refreshSeconds = seconds);
  }

  void _selectPackage(String value) {
    setState(() {
      selectedPackage = value;
      dashboardRequest = _loadDashboard();
    });
  }

  void _refreshDashboard() {
    final nextDashboard = _loadDashboard();
    final nextSources = _loadSources();
    setState(() {
      dashboardRequest = nextDashboard;
      sourcesRequest = nextSources;
    });
  }

  void _refreshLiveWorkspace() {
    if (!mounted) return;
    final nextDashboard = _loadDashboard();
    final nextSources = _loadSources();
    setState(() {
      dashboardRequest = nextDashboard;
      sourcesRequest = nextSources;
      healthRequest = _loadSystemHealth();
      _liveRefreshTick++;
    });
  }

  void _navigateTo(int index) {
    setState(() {
      selectedNavigation = index;
      _liveRefreshTick++;
    });
  }

  Widget _buildSelectedPage() {
    switch (selectedNavigation) {
      case 0:
        return _DailyBriefPage(
          key:ValueKey('brief-$_liveRefreshTick-$selectedPackage'),
          overview:_OverviewContent(
            selectedPackage: selectedPackage,
            dashboardRequest: dashboardRequest,
            sourcesRequest: sourcesRequest,
            onRefresh: _refreshDashboard,
            onNavigate: _navigateTo,
          ),
        );
      case 1:
        return _OpportunitiesPage(
          modelKey: packageModelKeys[selectedPackage] ?? 'all',
          packageName: selectedPackage,
        );
      case 2:
        return _IntelligenceMapPage(
          modelKey: packageModelKeys[selectedPackage] ?? 'all',
          packageName: selectedPackage,
        );
      case 3:
        return const _PropertiesPage();
      case 4:
        return const _SignalsPage();
      case 5:
        return _SourcesPage(
          sourcesRequest: sourcesRequest,
          onRefresh: _refreshDashboard,
        );
      case 6:
        return const _MyWorkPage();
      case 7:
        return const _PermitContextPage();
      case 8:
        return const _PackagesPage();
      case 9:
        return const _ModelsPage();
      case 10:
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
      case 11:
        if(widget.ownerMode)return const _OwnerCenterPage();
        return const _ComingSoonPage(
          title:'Owner Center',icon:Icons.admin_panel_settings_rounded,
        );
      default:
        return _ComingSoonPage(
          title: visibleNavigationItems[selectedNavigation].label,
          icon: visibleNavigationItems[selectedNavigation].icon,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1100;

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  _SideNavigation(
                    items: visibleNavigationItems,
                    selectedIndex: selectedNavigation,
                    onSelected: (index) {
                      setState(() => selectedNavigation = index);
                    },
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        desktop: desktop,
                        package: selectedPackage,
                        packages: packages,
                        onPackageChanged: (value) {
                          if (value != null) {
                            _selectPackage(value);
                          }
                        },
                        onSearch: (_) => _navigateTo(3),
                        onNotifications: () => showDialog<void>(
                          context:context,
                          builder:(context)=>const _NotificationCenterDialog(),
                        ),
                      ),
                      _LiveSyncStrip(
                        secondsRemaining:_secondsToRefresh,
                        refreshSeconds:_refreshSeconds,
                      ),
                      if (!desktop)
                        _CompactNavigation(
                          items: visibleNavigationItems,
                          selectedIndex: selectedNavigation,
                          onSelected: (index) {
                            setState(() => selectedNavigation = index);
                          },
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 28 : 16,
                            8,
                            desktop ? 28 : 16,
                            36,
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(_liveRefreshTick),
                            child: _buildSelectedPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SideNavigation extends StatelessWidget {
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
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: const Color(0xFF091525),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 18, 28),
            child: _Brand(),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == selectedIndex;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.cyan.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.cyan.withOpacity(0.25)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: selected ? AppTheme.cyan : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 13),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? Colors.white : AppTheme.textMuted,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.green.withOpacity(0.18)),
            ),
            child: const Row(
              children: [
                _PulseDot(color: AppTheme.green),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SYSTEM ONLINE',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Background scoring active',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.cyan, AppTheme.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.polyline_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BRIDGEPOINT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'INTELLIGENCE',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 2.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.desktop,
    required this.package,
    required this.packages,
    required this.onPackageChanged,
    required this.onSearch,
    required this.onNotifications,
  });

  final bool desktop;
  final String package;
  final List<String> packages;
  final ValueChanged<String?> onPackageChanged;
  final ValueChanged<String> onSearch;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 16),
      child: Row(
        children: [
          if (!desktop) ...[
            const SizedBox(width: 180, child: _Brand()),
            const SizedBox(width: 14),
          ],
          if (desktop)
            Expanded(
              child: _SearchBox(onSubmitted: onSearch),
            )
          else
            const Spacer(),
          const SizedBox(width: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 230),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: package,
                dropdownColor: AppTheme.panelSoft,
                icon: const Icon(Icons.expand_more_rounded),
                isExpanded: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                items: packages
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: onPackageChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _IconButton(
            icon: Icons.notifications_none_rounded,
            onTap: onNotifications,
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 19,
            backgroundColor: AppTheme.blue,
            child: Text(
              'KJ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSyncStrip extends StatelessWidget{
  const _LiveSyncStrip({required this.secondsRemaining,required this.refreshSeconds});
  final int secondsRemaining,refreshSeconds;
  @override Widget build(BuildContext context){
    final progress=refreshSeconds<=0?0.0:(1-(secondsRemaining/refreshSeconds)).clamp(0.0,1.0);
    return Container(
      height:24,
      padding:const EdgeInsets.symmetric(horizontal:18),
      child:Row(children:[
        const _PulseDot(color:AppTheme.green),const SizedBox(width:8),
        const Text('LIVE INTELLIGENCE',style:TextStyle(color:AppTheme.green,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.8)),
        const SizedBox(width:10),
        Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(
          value:progress,minHeight:3,backgroundColor:Colors.white10,valueColor:const AlwaysStoppedAnimation(AppTheme.cyan),
        ))),
        const SizedBox(width:10),
        Text('Next sync ${secondsRemaining}s',style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700)),
      ]),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: TextField(
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted),
          hintText: 'Search property, address, parcel, or signal',
          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _CompactNavigation extends StatelessWidget {
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
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = index == selectedIndex;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(index),
            avatar: Icon(item.icon, size: 17),
            label: Text(item.label),
          );
        },
      ),
    );
  }
}

class _DailyBriefPage extends StatefulWidget{
  const _DailyBriefPage({super.key,required this.overview});
  final Widget overview;
  @override State<_DailyBriefPage> createState()=>_DailyBriefPageState();
}

class _DailyBriefPageState extends State<_DailyBriefPage>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_daily_brief_v74',const {});}
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final overnight=data['overnight'] is Map?Map<String,dynamic>.from(data['overnight'] as Map):const <String,dynamic>{};
      final top=(data['top_opportunities'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:46,height:46,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppTheme.cyan,AppTheme.blue]),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.wb_sunny_outlined,color:Colors.white)),
            const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Welcome to BridgePoint Intelligence, ${data['display_name']??'there'}',style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),
              const SizedBox(height:4),Text(snapshot.connectionState==ConnectionState.waiting?'Building your live Daily Brief…':'Here is what changed in the last 24 hours and what deserves attention now.',style:const TextStyle(color:AppTheme.textMuted,fontSize:11)),
            ])),
            IconButton(tooltip:'Refresh Daily Brief',onPressed:()=>setState(()=>request=_callRpc('bridgepoint_daily_brief_v74',const {})),icon:const Icon(Icons.refresh_rounded,color:AppTheme.cyan)),
          ]),
          if(snapshot.hasError)...[const SizedBox(height:12),Text('The Daily Brief could not load yet. Your main workspace is still available.',style:TextStyle(color:AppTheme.amber))],
          if(snapshot.hasData)...[const SizedBox(height:18),Wrap(spacing:10,runSpacing:10,children:[
            _MiniStat(label:'NEW EVIDENCE',value:_compactNumber(overnight['new_signals'])),
            _MiniStat(label:'SOURCES REFRESHED',value:_compactNumber(overnight['refreshed_sources'])),
            _MiniStat(label:'OPPORTUNITY UPDATES',value:_compactNumber(overnight['strict_opportunity_updates'])),
            _MiniStat(label:'FOLLOW-UPS DUE',value:_compactNumber(overnight['follow_ups_due'])),
            _MiniStat(label:'UNREAD ALERTS',value:_compactNumber(data['unread_notifications'])),
          ]),
          if(top.isNotEmpty)...[const SizedBox(height:18),const Text('Start here today',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:14)),const SizedBox(height:8),
            ...top.take(3).map((o)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(12)),child:Row(children:[
              Icon(_opportunityTypeIcon(o),color:_opportunityTypeColor(o),size:20),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${o['full_address']??o['title']}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:11)),Text('${o['title']} • ${o['recommended_action']??'Review the evidence'}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.35))])),Text('${(o['score'] as num?)?.toStringAsFixed(1)??'—'}',style:const TextStyle(color:AppTheme.green,fontWeight:FontWeight.w900,fontSize:16)),
            ])))),
          ],
          ],
        ]))),
        const SizedBox(height:18),widget.overview,
      ]);
    });
}

class _WalkthroughDialog extends StatefulWidget{
  const _WalkthroughDialog();
  @override State<_WalkthroughDialog> createState()=>_WalkthroughDialogState();
}
class _WalkthroughDialogState extends State<_WalkthroughDialog>{
  int step=0;
  static const steps=<({IconData icon,String title,String body})>[
    (icon:Icons.wb_sunny_outlined,title:'Start with your Daily Brief',body:'BridgePoint welcomes you by profile name and summarizes new evidence, refreshed sources, opportunity changes, alerts, and follow-ups from the last 24 hours.'),
    (icon:Icons.map_rounded,title:'See different opportunities instantly',body:'Map colors identify the opportunity: amber for roofing, red for fire, purple for storms, blue for flood/FEMA, green for solar or investment, and cyan for commercial or development.'),
    (icon:Icons.psychology_alt_rounded,title:'Understand why—without jargon',body:'Opportunity score ranks potential. Confidence measures evidence reliability. “Why this property,” “Why now,” evidence counts, and a suggested next action explain every lead.'),
    (icon:Icons.bookmark_add_outlined,title:'Turn intelligence into work',body:'Save an opportunity, choose a lead stage, add a preset or custom note, and schedule the next action. My Work keeps the pipeline and calendar together.'),
    (icon:Icons.notifications_active_outlined,title:'Stay ahead automatically',body:'Choose which alerts you want. BridgePoint refreshes in the background and keeps your Daily Brief and notification history synchronized across devices.'),
  ];
  @override Widget build(BuildContext context){final s=steps[step];return Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:620),child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Skip tour'))),
    Container(width:70,height:70,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.12),shape:BoxShape.circle),child:Icon(s.icon,color:AppTheme.cyan,size:34)),const SizedBox(height:18),
    Text(s.title,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text(s.body,textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted,height:1.55,fontSize:12)),const SizedBox(height:22),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(steps.length,(i)=>Container(width:i==step?24:8,height:8,margin:const EdgeInsets.symmetric(horizontal:3),decoration:BoxDecoration(color:i==step?AppTheme.cyan:AppTheme.panelSoft,borderRadius:BorderRadius.circular(9))))),const SizedBox(height:22),
    Row(children:[if(step>0)OutlinedButton(onPressed:()=>setState(()=>step--),child:const Text('Back')),const Spacer(),FilledButton.icon(onPressed:(){if(step==steps.length-1){Navigator.pop(context);}else{setState(()=>step++);}},icon:Icon(step==steps.length-1?Icons.check_rounded:Icons.arrow_forward_rounded),label:Text(step==steps.length-1?'Finish':'Next'))]),
  ]))));}
}

class _NotificationCenterDialog extends StatefulWidget{
  const _NotificationCenterDialog();
  @override State<_NotificationCenterDialog> createState()=>_NotificationCenterDialogState();
}
class _NotificationCenterDialogState extends State<_NotificationCenterDialog>{
  late Future<Map<String,dynamic>> request;
  bool inApp=true,device=false,critical=true,followUps=true,sourceHealth=true,daily=true;
  @override void initState(){super.initState();request=_load();}
  Future<Map<String,dynamic>> _load() async{final d=await _callRpc('bridgepoint_notifications_v74',{'p_limit':50});final p=d['preferences'];if(p is Map){inApp=p['in_app_enabled']!=false;device=p['device_push_enabled']==true;critical=p['critical_opportunities']!=false;followUps=p['saved_follow_ups']!=false;sourceHealth=p['source_health']!=false;daily=p['daily_brief']!=false;}return d;}
  Future<void> _save() async{await _callRpc('bridgepoint_update_notification_preferences_v74',{'p_in_app_enabled':inApp,'p_device_push_enabled':device,'p_critical_opportunities':critical,'p_saved_follow_ups':followUps,'p_source_health':sourceHealth,'p_daily_brief':daily});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Notification preferences saved.')));}
  @override Widget build(BuildContext context)=>Dialog(backgroundColor:AppTheme.panel,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760,maxHeight:720),child:FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){final d=snapshot.data??const <String,dynamic>{};final items=(d['notifications'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();return Padding(padding:const EdgeInsets.all(22),child:Column(children:[
    Row(children:[const Icon(Icons.notifications_active_outlined,color:AppTheme.cyan),const SizedBox(width:10),const Expanded(child:Text('Notification Center',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900))),Text('${d['unread_count']??0} unread',style:const TextStyle(color:AppTheme.cyan,fontSize:11)),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
    const SizedBox(height:8),Wrap(spacing:8,runSpacing:4,children:[FilterChip(label:const Text('Daily Brief'),selected:daily,onSelected:(v)=>setState(()=>daily=v)),FilterChip(label:const Text('Critical opportunities'),selected:critical,onSelected:(v)=>setState(()=>critical=v)),FilterChip(label:const Text('Saved follow-ups'),selected:followUps,onSelected:(v)=>setState(()=>followUps=v)),FilterChip(label:const Text('Source health'),selected:sourceHealth,onSelected:(v)=>setState(()=>sourceHealth=v)),FilterChip(label:const Text('In-app alerts'),selected:inApp,onSelected:(v)=>setState(()=>inApp=v)),FilterChip(label:const Text('Device push'),selected:device,onSelected:(v)=>setState(()=>device=v))]),
    const SizedBox(height:10),Row(children:[FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Save preferences')),const SizedBox(width:8),TextButton(onPressed:()async{await _callRpc('bridgepoint_mark_notifications_read_v74',{'p_notification_id':null});if(mounted)setState(()=>request=_load());},child:const Text('Mark all read'))]),const Divider(),
    Expanded(child:snapshot.connectionState==ConnectionState.waiting?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('No alerts yet. BridgePoint will add them as your intelligence changes.',style:TextStyle(color:AppTheme.textMuted))):ListView.separated(itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(context,i){final n=items[i];final unread=n['read_at']==null;return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),leading:CircleAvatar(backgroundColor:(unread?AppTheme.cyan:AppTheme.textMuted).withOpacity(.12),child:Icon(_notificationIcon('${n['notification_type']}'),color:unread?AppTheme.cyan:AppTheme.textMuted,size:20)),title:Text('${n['title']}',style:TextStyle(color:Colors.white,fontWeight:unread?FontWeight.w800:FontWeight.w500)),subtitle:Text('${n['message']}',style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),trailing:unread?const Icon(Icons.circle,color:AppTheme.cyan,size:8):null);}))
  ]));})));
}

IconData _notificationIcon(String type){if(type.contains('CRITICAL'))return Icons.bolt_rounded;if(type.contains('FOLLOW'))return Icons.event_available_outlined;if(type.contains('SOURCE'))return Icons.hub_outlined;return Icons.wb_sunny_outlined;}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.selectedPackage,
    required this.dashboardRequest,
    required this.sourcesRequest,
    required this.onRefresh,
    required this.onNavigate,
  });

  final String selectedPackage;
  final Future<Map<String, dynamic>> dashboardRequest;
  final Future<Map<String, dynamic>> sourcesRequest;
  final VoidCallback onRefresh;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: dashboardRequest,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 18,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Intelligence Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$selectedPackage • Connecticut statewide',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.green.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (loading)
                            const SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.green,
                              ),
                            )
                          else
                            const _PulseDot(color: AppTheme.green),
                          const SizedBox(width: 8),
                          Text(
                            loading ? 'SYNCING LIVE DATA' : 'LIVE DATA',
                            style: const TextStyle(
                              color: AppTheme.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconButton(
                      icon: Icons.refresh_rounded,
                      onTap: loading ? () {} : onRefresh,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: onRefresh,
              )
            else ...[
              _MetricGrid(
                data: data,
                loading: loading,
                onNavigate: onNavigate,
              ),
              const SizedBox(height: 20),
              _MainDashboardRow(data: data, loading: loading),
              const SizedBox(height: 20),
              _SourcesPanel(sourcesRequest: sourcesRequest),
            ],
          ],
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.data,
    required this.loading,
    required this.onNavigate,
  });

  final Map<String, dynamic>? data;
  final bool loading;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050 ? 4 : (width >= 620 ? 2 : 1);
        const gap = 14.0;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _MetricCard(
              width: itemWidth,
              label: 'CT PROPERTIES',
              value: loading
                  ? '—'
                  : _formatInteger(data?['property_count_estimate']),
              detail: 'Imported CT CAMA / parcel inventory',
              icon: Icons.home_work_outlined,
              accent: AppTheme.cyan,
              onTap: () => onNavigate(3),
            ),
            _MetricCard(
              width: itemWidth,
              label: 'INTELLIGENCE SOURCES',
              value: loading
                  ? '—'
                  : _formatInteger(data?['connected_source_families']),
              detail: 'Storm • Fire • FEMA • Grid • Transitions',
              icon: Icons.hub_outlined,
              accent: AppTheme.blue,
              onTap: () => onNavigate(5),
            ),
            _MetricCard(
              width: itemWidth,
              label: 'ACTIVE PATTERNS',
              value: loading
                  ? '—'
                  : _formatInteger(data?['active_patterns']),
              detail: 'V36 compound property intelligence',
              icon: Icons.account_tree_outlined,
              accent: AppTheme.amber,
              onTap: () => onNavigate(4),
            ),
            _MetricCard(
              width: itemWidth,
              label: 'AUTOMATION',
              value: loading ? 'SYNCING' : 'ACTIVE',
              detail: loading
                  ? 'Loading current intelligence'
                  : '${_formatInteger(data?['active_opportunities'])} active opportunities',
              icon: Icons.sync_rounded,
              accent: AppTheme.green,
              onTap: () => onNavigate(1),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withOpacity(0.25),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainDashboardRow extends StatelessWidget {
  const _MainDashboardRow({required this.data, required this.loading});

  final Map<String, dynamic>? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              _OpportunityPanel(data: data, loading: loading),
              const SizedBox(height: 20),
              _CoveragePanel(data: data, loading: loading),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _OpportunityPanel(data: data, loading: loading),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _CoveragePanel(data: data, loading: loading),
            ),
          ],
        );
      },
    );
  }
}

class _OpportunityPanel extends StatelessWidget {
  const _OpportunityPanel({required this.data, required this.loading});

  final Map<String, dynamic>? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final rawRows = data?['ranked_opportunities'];
    final opportunities = rawRows is List
        ? rawRows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
        : <Map<String, dynamic>>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              title: 'Ranked Opportunities',
              subtitle: 'Highest-value properties from active models',
              action: 'View all',
            ),
            const SizedBox(height: 18),
            if (loading)
              const _OpportunityLoading()
            else if (opportunities.isEmpty)
              const _OpportunityEmpty()
            else
              ...opportunities.take(5).toList().asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == opportunities.take(5).length - 1
                            ? 0
                            : 10,
                      ),
                      child: _OpportunityRow(
                        rank: entry.key + 1,
                        opportunity: entry.value,
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            _ModelProgress(
              label: 'Property matching',
              status: loading ? 'Connecting…' : 'Connected',
              color: AppTheme.cyan,
              value: loading ? null : 1,
            ),
            const SizedBox(height: 12),
            _ModelProgress(
              label: 'Live opportunity feed',
              status: loading
                  ? 'Loading…'
                  : '${opportunities.length} ranked rows loaded',
              color: AppTheme.blue,
              value: loading ? null : 1,
            ),
            const SizedBox(height: 12),
            _ModelProgress(
              label: 'Package filter',
              status: loading ? 'Loading…' : 'Active',
              color: AppTheme.green,
              value: loading ? null : 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpportunityRow extends StatelessWidget {
  const _OpportunityRow({
    required this.rank,
    required this.opportunity,
  });

  final int rank;
  final Map<String, dynamic> opportunity;

  @override
  Widget build(BuildContext context) {
    final priority = (opportunity['priority'] ?? 'monitor').toString();
    final priorityColor = _priorityColor(priority);
    final score = _formatDecimal(opportunity['score']);
    final confidence = _formatDecimal(opportunity['confidence_score']);
    final address = (opportunity['full_address'] ?? 'Address unavailable')
        .toString();
    final signal = (opportunity['top_signal_type'] ?? 'intelligence signal')
        .toString()
        .replaceAll('_', ' ');

    return InkWell(
      onTap: () => _showPropertyInventoryDetail(context, opportunity),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppTheme.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_titleCase(signal)} • $confidence% confidence',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: priorityColor.withOpacity(0.25)),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _OpportunityLoading extends StatelessWidget {
  const _OpportunityLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.cyan, strokeWidth: 2.5),
          SizedBox(height: 13),
          Text(
            'Loading ranked opportunities…',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OpportunityEmpty extends StatelessWidget {
  const _OpportunityEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.radar_rounded, color: AppTheme.cyan, size: 34),
            SizedBox(height: 10),
            Text(
              'No active opportunities in this package yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'BridgePoint will display them here as scoring completes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppTheme.red),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live dashboard could not load',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.data, required this.loading});

  final Map<String, dynamic>? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              title: 'Connecticut Coverage',
              subtitle: 'Current intelligence foundation',
              action: 'Map',
            ),
            const SizedBox(height: 18),
            Container(
              height: 164,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.blue.withOpacity(0.17),
                    AppTheme.cyan.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.cyan.withOpacity(0.14)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.cyan,
                          size: 38,
                        ),
                        SizedBox(height: 7),
                        Text(
                          'STATEWIDE CT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '8 counties • 169 municipalities',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CoverageRow(
              'Property records',
              loading
                  ? '—'
                  : _formatCompact(data?['property_count_estimate']),
              AppTheme.cyan,
            ),
            _CoverageRow(
              'Active source families',
              loading
                  ? '—'
                  : _formatInteger(data?['connected_source_families']),
              AppTheme.blue,
            ),
            _CoverageRow(
              'Intelligence packages',
              loading
                  ? '—'
                  : _formatInteger(data?['active_property_packages']),
              AppTheme.green,
            ),
            const _CoverageRow('Grid source records', '175', AppTheme.amber),
          ],
        ),
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.sourcesRequest});

  final Future<Map<String, dynamic>> sourcesRequest;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: sourcesRequest,
      builder: (context, snapshot) {
        final raw = snapshot.data?['sources'];
        final sources = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelHeader(
                  title: 'Connected Intelligence Sources',
                  subtitle: 'Live source registry • Connecticut intelligence',
                  action: 'Source health',
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox(
                    height: 110,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.cyan,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  _InlineError(message: snapshot.error.toString())
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 980
                          ? 3
                          : (constraints.maxWidth >= 560 ? 2 : 1);
                      const gap = 12.0;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) / columns;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: sources
                            .map(
                              (source) => _LiveSourceCard(
                                width: width,
                                source: source,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}







class _ModelsPage extends StatefulWidget {
  const _ModelsPage();

  @override
  State<_ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<_ModelsPage> {
  late Future<Map<String, dynamic>> _request;
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_models'),
          headers: _apiHeaders(),
          body: '{}',
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Models API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Models response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['models'];
        final allModels = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        final categories = <String>{
          'all',
          ...allModels.map((m) => '${m['model_category'] ?? 'other'}'),
        }.toList();

        final models = _category == 'all'
            ? allModels
            : allModels
                .where((m) => '${m['model_category'] ?? 'other'}' == _category)
                .toList();

        final loading = snapshot.connectionState == ConnectionState.waiting;
        final propertyModels = allModels
            .where((m) => '${m['target_entity_type']}' == 'property')
            .length;
        final unbundled =
            allModels.where((m) => (m['package_count'] as num? ?? 0) == 0).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Models',
              subtitle:
                  'Live BridgePoint scoring models • thresholds • package coverage',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE MODELS',
                      value: '${data?['active_model_count'] ?? allModels.length}',
                      detail: 'Live intelligence engines',
                      icon: Icons.psychology_alt_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PROPERTY MODELS',
                      value: '$propertyModels',
                      detail: 'Models targeting properties',
                      icon: Icons.home_work_outlined,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PACKAGE LINKS',
                      value: '${data?['active_package_model_links'] ?? 0}',
                      detail: '$unbundled active model${unbundled == 1 ? '' : 's'} not bundled',
                      icon: Icons.account_tree_outlined,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 280,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        color: AppTheme.cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CATEGORY',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: categories.map((category) {
                            final selected = category == _category;
                            return ChoiceChip(
                              label: Text(
                                category.replaceAll('_', ' ').toUpperCase(),
                              ),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                              labelStyle: TextStyle(
                                color:
                                    selected ? Colors.white : AppTheme.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 1100
                      ? (constraints.maxWidth - 28) / 3
                      : constraints.maxWidth >= 720
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: models
                        .map(
                          (model) => SizedBox(
                            width: cardWidth,
                            child: _LiveModelCard(model: model),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LiveModelCard extends StatelessWidget {
  const _LiveModelCard({required this.model});

  final Map<String, dynamic> model;

  @override
  Widget build(BuildContext context) {
    final rawPackages = model['packages'];
    final packages = rawPackages is List
        ? rawPackages
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final category = '${model['model_category'] ?? 'intelligence'}';
    final target = '${model['target_entity_type'] ?? 'entity'}';

    return Card(
      child: InkWell(
        onTap: () => _showModelDetail(context, model),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _modelIcon(category),
                      color: AppTheme.cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${category.toUpperCase()} • ${target.toUpperCase()}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _OpportunityChip(
                    label: model['active'] == true ? 'ACTIVE' : 'INACTIVE',
                    color: model['active'] == true
                        ? AppTheme.green
                        : AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                '${model['description'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _ModelThreshold(
                      label: 'WATCH',
                      value: model['watch_threshold'],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModelThreshold(
                      label: 'DEFAULT',
                      value: model['default_threshold'],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModelThreshold(
                      label: 'HIGH',
                      value: model['high_threshold'],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ModelThreshold(
                      label: 'PRIORITY',
                      value: model['priority_threshold'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'AVAILABLE IN',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 7),
              if (packages.isEmpty)
                const Text(
                  'Internal / not currently bundled',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: packages
                      .map(
                        (p) => _OpportunityChip(
                          label: '${p['package_name'] ?? p['package_key']}',
                          color: p['featured'] == true
                              ? AppTheme.cyan
                              : AppTheme.blue,
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Text(
                    '${packages.length} package${packages.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Inspect model',
                    style: TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.cyan,
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelThreshold extends StatelessWidget {
  const _ModelThreshold({
    required this.label,
    required this.value,
  });

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(.55),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: Column(
        children: [
          Text(
            '${value ?? '—'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _modelIcon(String category) {
  switch (category) {
    case 'residential':
      return Icons.home_outlined;
    case 'commercial':
    case 'business':
      return Icons.business_center_outlined;
    case 'contractor':
      return Icons.roofing_outlined;
    case 'development':
      return Icons.location_city_outlined;
    case 'energy':
      return Icons.solar_power_outlined;
    case 'infrastructure':
      return Icons.construction_outlined;
    case 'investment':
      return Icons.trending_up_rounded;
    case 'custom':
      return Icons.tune_rounded;
    default:
      return Icons.psychology_alt_outlined;
  }
}

void _showModelDetail(
  BuildContext context,
  Map<String, dynamic> model,
) {
  final rawPackages = model['packages'];
  final packages = rawPackages is List
      ? rawPackages
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _modelIcon('${model['model_category'] ?? ''}'),
                      color: AppTheme.cyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${model['description'] ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'CATEGORY',
                      value: '${model['model_category'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'TARGET',
                      value: '${model['target_entity_type'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'PACKAGES',
                      value: '${model['package_count'] ?? packages.length}',
                    ),
                    _MiniStat(
                      label: 'STATUS',
                      value: model['active'] == true ? 'Active' : 'Inactive',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Scoring thresholds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ModelThreshold(
                        label: 'WATCH',
                        value: model['watch_threshold'],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModelThreshold(
                        label: 'DEFAULT',
                        value: model['default_threshold'],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModelThreshold(
                        label: 'HIGH',
                        value: model['high_threshold'],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModelThreshold(
                        label: 'PRIORITY',
                        value: model['priority_threshold'],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Package coverage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (packages.isEmpty)
                  const Text(
                    'This active model is not currently linked to a customer-facing package.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  )
                else
                  ...packages.map(
                    (p) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft.withOpacity(.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            color: AppTheme.cyan,
                            size: 17,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '${p['package_name'] ?? p['package_key'] ?? 'Package'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${p['package_type'] ?? ''}'.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Model key: ${model['model_key'] ?? '—'}\n'
                  'Model ID: ${model['model_id'] ?? '—'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.30),
                    fontSize: 9,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PackagesPage extends StatefulWidget {
  const _PackagesPage();

  @override
  State<_PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<_PackagesPage> {
  late Future<Map<String, dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_packages'),
          headers: _apiHeaders(),
          body: '{}',
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Packages API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Packages response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['packages'];
        final packages = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final featured =
            packages.where((p) => p['featured'] == true).length;
        final modelCount = (data?['active_model_count'] as num?)?.toInt() ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Packages',
              subtitle:
                  'Live BridgePoint product catalog • models • trials • intelligence scope',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE PACKAGES',
                      value: '${data?['active_package_count'] ?? packages.length}',
                      detail: 'Live product catalog',
                      icon: Icons.inventory_2_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE MODELS',
                      value: '$modelCount',
                      detail: 'Intelligence models available',
                      icon: Icons.psychology_alt_outlined,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'FEATURED',
                      value: '$featured',
                      detail: 'Primary BridgePoint packages',
                      icon: Icons.star_outline_rounded,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 1150
                      ? (constraints.maxWidth - 28) / 3
                      : constraints.maxWidth >= 760
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: packages
                        .map(
                          (package) => SizedBox(
                            width: cardWidth,
                            child: _LivePackageCard(package: package),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _LivePackageCard extends StatelessWidget {
  const _LivePackageCard({required this.package});

  final Map<String, dynamic> package;

  @override
  Widget build(BuildContext context) {
    final rawModels = package['models'];
    final models = rawModels is List
        ? rawModels.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final featured = package['featured'] == true;
    final trialDays = (package['trial_days'] as num?)?.toInt();
    final monthly = package['monthly_price'] as num?;
    final yearly = package['yearly_price'] as num?;
    final type = '${package['package_type'] ?? 'standard'}';

    return Card(
      child: InkWell(
        onTap: () => _showPackageDetail(context, package),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: AppTheme.cyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${package['package_name'] ?? 'BridgePoint Package'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (featured)
                    const _OpportunityChip(
                      label: 'FEATURED',
                      color: AppTheme.green,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${package['description'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OpportunityChip(
                    label: '${models.length} MODEL${models.length == 1 ? '' : 'S'}',
                    color: AppTheme.blue,
                  ),
                  if (trialDays != null)
                    _OpportunityChip(
                      label: '$trialDays DAY TRIAL',
                      color: AppTheme.cyan,
                    ),
                  _OpportunityChip(
                    label: package['active'] == true ? 'ACTIVE' : 'INACTIVE',
                    color: package['active'] == true
                        ? AppTheme.green
                        : AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (models.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.panelSoft.withOpacity(.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Custom intelligence model builder',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                )
              else
                ...models.take(4).map(
                  (model) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppTheme.green,
                          size: 14,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (models.length > 4)
                Text(
                  '+ ${models.length - 4} more models',
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      monthly == null && yearly == null
                          ? 'Pricing not configured'
                          : monthly != null
                              ? '\$${monthly.toStringAsFixed(0)} / month'
                              : '\$${yearly!.toStringAsFixed(0)} / year',
                      style: TextStyle(
                        color: monthly == null && yearly == null
                            ? AppTheme.textMuted
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _packageIcon(String key) {
  switch (key) {
    case 'home':
      return Icons.home_work_outlined;
    case 'commercial':
      return Icons.business_outlined;
    case 'solar':
      return Icons.solar_power_outlined;
    case 'investor':
      return Icons.trending_up_rounded;
    case 'infrastructure':
      return Icons.construction_outlined;
    case 'custom_model':
      return Icons.tune_rounded;
    case 'all_intelligence':
      return Icons.all_inclusive_rounded;
    default:
      return Icons.inventory_2_outlined;
  }
}

void _showPackageDetail(
  BuildContext context,
  Map<String, dynamic> package,
) {
  final rawModels = package['models'];
  final models = rawModels is List
      ? rawModels.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: AppTheme.cyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${package['package_name'] ?? 'BridgePoint Package'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${package['description'] ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'MODELS',
                      value: '${models.length}',
                    ),
                    _MiniStat(
                      label: 'TRIAL',
                      value: '${package['trial_days'] ?? '—'} days',
                    ),
                    _MiniStat(
                      label: 'TYPE',
                      value: '${package['package_type'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'STATUS',
                      value: package['active'] == true ? 'Active' : 'Inactive',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Included intelligence models',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (models.isEmpty)
                  const Text(
                    'This add-on creates personalized intelligence models rather than bundling a fixed prebuilt model.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  )
                else
                  ...models.map(
                    (model) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft.withOpacity(.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${model['description'] ?? ''}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${model['model_category'] ?? 'intelligence'} • ${model['target_entity_type'] ?? 'entity'} • priority ${model['priority_threshold'] ?? '—'}',
                            style: const TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cyan.withOpacity(.16)),
                  ),
                  child: const Text(
                    'Start with a 7-day free trial. Founding customers #1–10 receive 50% off their first 6 monthly payments.',
                    style: TextStyle(color: AppTheme.cyan,fontSize:10,height:1.45,fontWeight:FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children:[
                  Expanded(child:FilledButton.icon(
                    onPressed:package['monthly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'month');},
                    icon:const Icon(Icons.bolt_rounded),
                    label:Text(package['monthly_price']==null?'Monthly unavailable':'Start monthly • \$${(package['monthly_price'] as num).toStringAsFixed(0)}'),
                  )),
                  const SizedBox(width:10),
                  Expanded(child:OutlinedButton(
                    onPressed:package['yearly_price']==null?null:(){Navigator.of(context).pop();_startCheckout(context,package,'year');},
                    child:Text(package['yearly_price']==null?'Annual unavailable':'Annual • \$${(package['yearly_price'] as num).toStringAsFixed(0)}'),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _IntelligenceMapPage extends StatefulWidget {
  const _IntelligenceMapPage({
    required this.modelKey,
    required this.packageName,
  });

  final String modelKey;
  final String packageName;

  @override
  State<_IntelligenceMapPage> createState() => _IntelligenceMapPageState();
}

class _IntelligenceMapPageState extends State<_IntelligenceMapPage> {
  late Future<Map<String, dynamic>> _request;
  final MapController _mapController = MapController();
  double? _minimumScore;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void didUpdateWidget(covariant _IntelligenceMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelKey != widget.modelKey) {
      _request = _load();
    }
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_intelligence_map_v57'),
      headers: _apiHeaders(),
      body: jsonEncode({
        'p_model_key': widget.modelKey,
        'p_min_lat': null,
        'p_max_lat': null,
        'p_min_lng': null,
        'p_max_lng': null,
        'p_min_score': _minimumScore,
        'p_limit': 500,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Intelligence Map API ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected Intelligence Map response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['points'];
        final points = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final highPriority = points.where((p) {
          final v = '${p['priority']}'.toLowerCase();
          return v == 'critical' || v == 'high';
        }).length;
        final avgScore = points.isEmpty
            ? 0.0
            : points.fold<double>(
                    0,
                    (sum, p) =>
                        sum + ((p['opportunity_score'] as num?)?.toDouble() ?? 0),
                  ) /
                  points.length;

        final markers = <Marker>[];
        for (final point in points) {
          final lat = (point['latitude'] as num?)?.toDouble();
          final lng = (point['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final priority = '${point['priority'] ?? 'medium'}';
          final typeColor=_opportunityTypeColor(point);
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 34,
              height: 34,
              child: Tooltip(
                message: '${point['full_address'] ?? point['municipality'] ?? 'Opportunity'}',
                child: GestureDetector(
                  onTap: () => _showMapOpportunityDetail(context, point),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:typeColor.withOpacity(.94),
                      border:Border.all(color:_opportunityPriorityColor(priority),width:2.4),
                      boxShadow: [
                        BoxShadow(
                          color:typeColor.withOpacity(.38),blurRadius:11,spreadRadius:1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _opportunityMapIcon(point),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Intelligence Map',
              subtitle:
                  '${widget.packageName} • live Connecticut opportunity geography',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'MAPPED',
                      value: '${markers.length}',
                      detail: data?['has_more'] == true
                          ? 'Top intelligence points • more available'
                          : 'Opportunity points returned',
                      icon: Icons.map_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'HIGH PRIORITY',
                      value: '$highPriority',
                      detail: 'Critical + high on current map',
                      icon: Icons.priority_high_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'AVG SCORE',
                      value: points.isEmpty ? '—' : avgScore.toStringAsFixed(1),
                      detail: 'Mapped opportunity intelligence',
                      icon: Icons.analytics_outlined,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.layers_outlined, color: AppTheme.cyan, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'OPPORTUNITIES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
                      _MapLegendDot(color:AppTheme.amber,label:'Roofing'),const SizedBox(width:12),
                      _MapLegendDot(color:AppTheme.red,label:'Fire'),const SizedBox(width:12),
                      const _MapLegendDot(color:Color(0xFF9B7BFF),label:'Storm'),const SizedBox(width:12),
                      _MapLegendDot(color:AppTheme.blue,label:'Flood/FEMA'),const SizedBox(width:12),
                      _MapLegendDot(color:AppTheme.green,label:'Solar/Investor'),const SizedBox(width:12),
                      _MapLegendDot(color:AppTheme.cyan,label:'Commercial/Other'),
                    ]))),
                    const SizedBox(width:12),
                    PopupMenuButton<double?>(
                      tooltip: 'Minimum opportunity score',
                      onSelected: (value) {
                        _minimumScore = value;
                        _reload();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: null, child: Text('All scores')),
                        PopupMenuItem(value: 50.0, child: Text('Score 50+')),
                        PopupMenuItem(value: 70.0, child: Text('Score 70+')),
                        PopupMenuItem(value: 85.0, child: Text('Score 85+')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _minimumScore == null
                              ? 'All scores'
                              : '${_minimumScore!.toStringAsFixed(0)}+ score',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _DashboardError(message: snapshot.error.toString(), onRetry: _reload)
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 610,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: LatLng(41.60, -72.70),
                          initialZoom: 8.2,
                          minZoom: 7,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.bridgepoint.data_studio',
                          ),
                          MarkerLayer(markers: markers),
                          RichAttributionWidget(
                            attributions: const [
                              TextSourceAttribution('OpenStreetMap contributors'),
                            ],
                          ),
                        ],
                      ),
                      if(!loading)const Positioned.fill(child:IgnorePointer(child:_MapScanOverlay())),
                      if (loading)
                        Positioned.fill(
                          child: Container(
                            color: AppTheme.panel.withOpacity(.45),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.cyan,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Column(
                          children: [
                            _MapControlButton(
                              icon: Icons.add_rounded,
                              tooltip: 'Zoom in',
                              onTap: () {
                                final camera = _mapController.camera;
                                _mapController.move(
                                  camera.center,
                                  camera.zoom + 1,
                                );
                              },
                            ),
                            const SizedBox(height: 7),
                            _MapControlButton(
                              icon: Icons.remove_rounded,
                              tooltip: 'Zoom out',
                              onTap: () {
                                final camera = _mapController.camera;
                                _mapController.move(
                                  camera.center,
                                  camera.zoom - 1,
                                );
                              },
                            ),
                            const SizedBox(height: 7),
                            _MapControlButton(
                              icon: Icons.center_focus_strong_rounded,
                              tooltip: 'Reset Connecticut',
                              onTap: () => _mapController.move(
                                const LatLng(41.60, -72.70),
                                8.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MapLegendDot extends StatelessWidget {
  const _MapLegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
        ),
      ],
    );
  }
}

class _MapScanOverlay extends StatefulWidget{
  const _MapScanOverlay();
  @override State<_MapScanOverlay> createState()=>_MapScanOverlayState();
}
class _MapScanOverlayState extends State<_MapScanOverlay> with SingleTickerProviderStateMixin{
  late final AnimationController controller;
  @override void initState(){super.initState();controller=AnimationController(vsync:this,duration:const Duration(seconds:6))..repeat();}
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:controller,builder:(context,_)=>
    Align(alignment:Alignment(0,-1+controller.value*2),child:Container(height:2,decoration:BoxDecoration(
      gradient:LinearGradient(colors:[Colors.transparent,AppTheme.cyan.withOpacity(.34),Colors.transparent]),
      boxShadow:[BoxShadow(color:AppTheme.cyan.withOpacity(.16),blurRadius:12,spreadRadius:4)],
    ))));
}

IconData _opportunityMapIcon(Map<String, dynamic> opportunity) {
  final value = '${opportunity['vertical_key'] ?? ''} '
          '${opportunity['model_key'] ?? ''} '
          '${opportunity['title'] ?? ''} '
          '${opportunity['model_name'] ?? ''}'
      .toLowerCase();
  if (value.contains('roof')) return Icons.roofing_rounded;
  if (value.contains('restoration')) return Icons.handyman_rounded;
  if (value.contains('adjust')) return Icons.policy_rounded;
  if (value.contains('invest')) return Icons.real_estate_agent_rounded;
  if (value.contains('contract')) return Icons.construction_rounded;
  if (value.contains('solar')) return Icons.solar_power_rounded;
  if (value.contains('commercial') || value.contains('business')) {
    return Icons.business_rounded;
  }
  if (value.contains('development')) return Icons.location_city_rounded;
  if (value.contains('fire')) return Icons.local_fire_department_rounded;
  if (value.contains('flood') || value.contains('water')) {
    return Icons.flood_rounded;
  }
  return Icons.bolt_rounded;
}

Color _opportunityTypeColor(Map<String,dynamic> opportunity){
  final value='${opportunity['vertical_key']??''} ${opportunity['model_key']??''} ${opportunity['title']??''} ${opportunity['model_name']??''} ${opportunity['top_signal_type']??''}'.toLowerCase();
  if(value.contains('fire'))return AppTheme.red;
  if(value.contains('storm')||value.contains('wind')||value.contains('hail')||value.contains('lightning'))return const Color(0xFF9B7BFF);
  if(value.contains('flood')||value.contains('fema')||value.contains('water'))return AppTheme.blue;
  if(value.contains('roof')||value.contains('restoration')||value.contains('contract'))return AppTheme.amber;
  if(value.contains('solar')||value.contains('invest'))return AppTheme.green;
  if(value.contains('commercial')||value.contains('business')||value.contains('development'))return AppTheme.cyan;
  return const Color(0xFF5BC0EB);
}

IconData _opportunityTypeIcon(Map<String,dynamic> opportunity)=>_opportunityMapIcon(opportunity);

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.panel.withOpacity(.94),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ReasoningPanel extends StatelessWidget{
  const _ReasoningPanel({required this.opportunity});
  final Map<String,dynamic> opportunity;
  Widget line(IconData icon,String title,String body,Color color)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color,size:18),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800)),const SizedBox(height:3),Text(body,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.5))]))]));
  @override Widget build(BuildContext context){
    final explanation='${opportunity['explanation']??opportunity['score_explanation']??opportunity['reason']??'BridgePoint found enough independent evidence to place this property in the review queue.'}';
    final stage='${opportunity['stage']??opportunity['intelligence_stage']??'active intelligence'}'.replaceAll('_',' ').toLowerCase();
    final events=opportunity['event_count']??opportunity['signal_count']??0;
    final patterns=opportunity['pattern_count']??0;
    final sources=opportunity['source_count']??opportunity['verified_event_count']??0;
    final action='${opportunity['recommended_action']??'Review the evidence, confirm property fit, and choose the next customer action.'}';
    return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppTheme.panelSoft,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.psychology_alt_rounded,color:AppTheme.cyan,size:20),SizedBox(width:8),Text('BridgePoint Reasoning',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:13))]),
      const SizedBox(height:5),const Text('Score ranks the opportunity. Confidence tells you how reliable and consistent the supporting evidence is.',style:TextStyle(color:AppTheme.textMuted,fontSize:9,height:1.4)),const Divider(height:22),
      line(Icons.home_work_outlined,'Why this property',explanation,AppTheme.cyan),
      line(Icons.schedule_rounded,'Why now','The property is in the “$stage” stage and its latest evidence kept it inside BridgePoint’s strict review threshold.',AppTheme.amber),
      line(Icons.fact_check_outlined,'Evidence you can verify','$events signals • $patterns compound patterns • $sources independent sources',AppTheme.blue),
      line(Icons.arrow_circle_right_outlined,'Suggested next step',action,AppTheme.green),
    ]));
  }
}

void _showMapOpportunityDetail(
  BuildContext context,
  Map<String, dynamic> point,
) {
  final score = (point['opportunity_score'] as num?)?.toDouble();
  final confidence =
      (point['opportunity_confidence_percent'] as num?)?.toDouble();

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppTheme.cyan),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${point['full_address'] ?? point['municipality'] ?? 'Opportunity'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'OPPORTUNITY',
                      value: score?.toStringAsFixed(1) ?? '—',
                    ),
                    _MiniStat(
                      label: 'PRIORITY',
                      value: '${point['priority'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'CONFIDENCE',
                      value: confidence == null
                          ? '—'
                          : '${confidence.toStringAsFixed(0)}%',
                    ),
                    _MiniStat(
                      label: 'EVENTS',
                      value: '${point['event_count'] ?? 0}',
                    ),
                    _MiniStat(
                      label: 'SIGNALS',
                      value: '${point['distinct_signal_count'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ReasoningPanel(opportunity:point),
                const SizedBox(height: 18),
                Text(
                  'Model: ${point['model_name'] ?? point['model_key'] ?? '—'}\n'
                  'Property: ${point['property_type'] ?? '—'}\n'
                  'Municipality: ${point['municipality'] ?? '—'}\n'
                  'County: ${point['county'] ?? '—'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SignalsPage extends StatefulWidget {
  const _SignalsPage();

  @override
  State<_SignalsPage> createState() => _SignalsPageState();
}

class _SignalsPageState extends State<_SignalsPage> {
  static const int _pageSize = 25;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _familyController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  late Future<Map<String, dynamic>> _request;
  int _offset = 0;
  String? _search;
  String? _family;
  String? _status;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _familyController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  String? _clean(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_signals'),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_search': _search,
            'p_signal_family': _family,
            'p_status': _status,
            'p_limit': _pageSize,
            'p_offset': _offset,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Signals API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Signals response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() {
    setState(() => _request = _load());
  }

  void _applyFilters() {
    _offset = 0;
    _search = _clean(_searchController.text);
    _family = _clean(_familyController.text);
    _status = _clean(_statusController.text);
    _reload();
  }

  void _clearFilters() {
    _searchController.clear();
    _familyController.clear();
    _statusController.clear();
    _offset = 0;
    _search = null;
    _family = null;
    _status = null;
    _reload();
  }

  void _previous() {
    if (_offset <= 0) return;
    _offset = (_offset - _pageSize).clamp(0, 1 << 30);
    _reload();
  }

  void _next() {
    _offset += _pageSize;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['signals'];
        final signals = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final hasMore = data?['has_more'] == true;

        final activeCount =
            signals.where((s) => '${s['status']}'.toLowerCase() == 'active').length;
        final highCount = signals.where((s) {
          final sev = s['severity'];
          return sev is num && sev >= 80;
        }).length;
        final avgConfidence = signals.isEmpty
            ? 0.0
            : signals.fold<double>(
                  0,
                  (sum, s) => sum + ((s['confidence'] as num?)?.toDouble() ?? 0),
                ) /
                signals.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Signals',
              subtitle:
                  'Live property intelligence • evidence • strength • confidence',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE ON PAGE',
                      value: '$activeCount',
                      detail: '${signals.length} signals returned',
                      icon: Icons.radar_rounded,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'HIGH SEVERITY',
                      value: '$highCount',
                      detail: 'Severity 80+ on this page',
                      icon: Icons.warning_amber_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'AVG CONFIDENCE',
                      value: signals.isEmpty
                          ? '—'
                          : '${(avgConfidence * 100).toStringAsFixed(0)}%',
                      detail: 'Current page evidence confidence',
                      icon: Icons.verified_outlined,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fields = [
                          _signalField(
                            controller: _searchController,
                            label: 'Signal, detector, or description',
                            icon: Icons.search_rounded,
                          ),
                          _signalField(
                            controller: _familyController,
                            label: 'Signal family',
                            icon: Icons.account_tree_outlined,
                          ),
                          _signalField(
                            controller: _statusController,
                            label: 'Status',
                            icon: Icons.toggle_on_outlined,
                          ),
                        ];
                        if (constraints.maxWidth < 800) {
                          return Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 10),
                              fields[1],
                              const SizedBox(height: 10),
                              fields[2],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 2, child: fields[0]),
                            const SizedBox(width: 10),
                            Expanded(child: fields[1]),
                            const SizedBox(width: 10),
                            Expanded(child: fields[2]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: loading ? null : _applyFilters,
                          icon: const Icon(Icons.filter_alt_rounded, size: 17),
                          label: const Text('Apply'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: loading ? null : _clearFilters,
                          icon: const Icon(Icons.clear_rounded, size: 17),
                          label: const Text('Clear'),
                        ),
                        const Spacer(),
                        Text(
                          'Newest signals first',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.38),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (signals.isEmpty)
              const Card(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No signals match these filters.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Signal Intelligence',
                        subtitle:
                            'Property-linked detections and supporting evidence',
                        action: 'Inspect signal',
                      ),
                      const SizedBox(height: 14),
                      ...signals.map((signal) => _SignalListCard(signal: signal)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _offset > 0 && !loading ? _previous : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: hasMore && !loading ? _next : null,
                            icon:
                                const Icon(Icons.chevron_right_rounded, size: 18),
                            label: const Text('Next'),
                          ),
                          const Spacer(),
                          Text(
                            'Page ${(_offset ~/ _pageSize) + 1} • ${signals.length} returned',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _signalField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => _applyFilters(),
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
        isDense: true,
        filled: true,
        fillColor: AppTheme.panelSoft.withOpacity(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.cyan),
        ),
      ),
    );
  }
}

class _SignalListCard extends StatelessWidget {
  const _SignalListCard({required this.signal});

  final Map<String, dynamic> signal;

  @override
  Widget build(BuildContext context) {
    final title =
        (signal['signal_name'] ?? signal['title'] ?? 'Signal').toString();
    final address = (signal['full_address'] ?? '').toString();
    final municipality = (signal['municipality'] ?? 'Unknown').toString();
    final family = (signal['signal_family'] ?? 'uncategorized').toString();
    final status = (signal['status'] ?? 'unknown').toString();
    final severity = (signal['severity'] as num?)?.toDouble();
    final strength = (signal['strength'] as num?)?.toDouble();
    final confidence = (signal['confidence'] as num?)?.toDouble();
    final evidenceCount = (signal['evidence_count'] as num?)?.toInt() ?? 0;
    final detector = (signal['detector_key'] ?? '—').toString();

    return InkWell(
      onTap: () => _showSignalDetail(context, signal),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: AppTheme.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    address.trim().isEmpty ? municipality : address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detector,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OpportunityChip(
                    label: family.replaceAll('_', ' ').toUpperCase(),
                    color: AppTheme.blue,
                  ),
                  _OpportunityChip(
                    label: status.toUpperCase(),
                    color: status.toLowerCase() == 'active'
                        ? AppTheme.green
                        : AppTheme.textMuted,
                  ),
                  if (severity != null)
                    _OpportunityChip(
                      label: 'SEV ${severity.toStringAsFixed(0)}',
                      color: severity >= 80 ? AppTheme.cyan : AppTheme.blue,
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 125,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    strength == null
                        ? 'Strength —'
                        : 'Strength ${strength.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    confidence == null
                        ? 'Confidence —'
                        : '${(confidence * 100).toStringAsFixed(0)}% confidence',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$evidenceCount evidence item${evidenceCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

void _showSignalDetail(
  BuildContext context,
  Map<String, dynamic> signal,
) {
  final title =
      (signal['signal_name'] ?? signal['title'] ?? 'Signal').toString();
  final confidence = (signal['confidence'] as num?)?.toDouble();
  final evidence = signal['evidence_summary'];
  final evidenceText = evidence is Map
      ? const JsonEncoder.withIndent('  ').convert(evidence)
      : (evidence?.toString() ?? 'No evidence summary.');

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: AppTheme.cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${signal['full_address'] ?? signal['municipality'] ?? 'Property intelligence'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(
                      label: 'SEVERITY',
                      value: '${signal['severity'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'STRENGTH',
                      value: '${signal['strength'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'CONFIDENCE',
                      value: confidence == null
                          ? '—'
                          : '${(confidence * 100).toStringAsFixed(0)}%',
                    ),
                    _MiniStat(
                      label: 'EVIDENCE',
                      value: '${signal['evidence_count'] ?? 0}',
                    ),
                    _MiniStat(
                      label: 'STATUS',
                      value: '${signal['status'] ?? '—'}',
                    ),
                    _MiniStat(
                      label: 'PROPERTY',
                      value: '${signal['property_type'] ?? '—'}',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Family: ${signal['signal_family'] ?? '—'}\n'
                  'Signal key: ${signal['signal_key'] ?? '—'}\n'
                  'Detector: ${signal['detector_key'] ?? '—'}\n'
                  'Direction: ${signal['direction'] ?? '—'}\n'
                  'Detected: ${signal['detected_at'] ?? '—'}\n'
                  'Effective: ${signal['effective_at'] ?? '—'}\n'
                  'Expires: ${signal['expires_at'] ?? '—'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Evidence summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.panelSoft.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: SelectableText(
                    evidenceText,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Signal ID: ${signal['signal_id'] ?? '—'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.30),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PropertiesPage extends StatefulWidget {
  const _PropertiesPage();

  @override
  State<_PropertiesPage> createState() => _PropertiesPageState();
}

class _PropertiesPageState extends State<_PropertiesPage> {
  static const int _pageSize = 25;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _municipalityController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  late Future<Map<String, dynamic>> _request;
  int _offset = 0;
  String? _search;
  String? _municipality;
  String? _propertyType;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _municipalityController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_properties',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_search': _search,
            'p_municipality': _municipality,
            'p_property_type': _propertyType,
            'p_limit': _pageSize,
            'p_offset': _offset,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Properties API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected BridgePoint Properties response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() {
    final next = _load();
    setState(() => _request = next);
  }

  void _applyFilters() {
    _offset = 0;
    _search = _clean(_searchController.text);
    _municipality = _clean(_municipalityController.text);
    _propertyType = _clean(_typeController.text);
    _reload();
  }

  String? _clean(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _clearFilters() {
    _searchController.clear();
    _municipalityController.clear();
    _typeController.clear();
    _offset = 0;
    _search = null;
    _municipality = null;
    _propertyType = null;
    _reload();
  }

  void _previous() {
    if (_offset <= 0) return;
    _offset = (_offset - _pageSize).clamp(0, 1 << 30);
    _reload();
  }

  void _next() {
    _offset += _pageSize;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['properties'];
        final properties = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        final estimate =
            (data?['property_count_estimate'] as num?)?.toInt() ?? 0;
        final hasMore = data?['has_more'] == true;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Properties',
              subtitle:
                  'Connecticut property universe • search, inspect, and open intelligence',
              onRefresh: _reload,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'PROPERTY INVENTORY',
                      value: '1,282,833',
                      detail: 'Imported Connecticut CAMA / parcel rows',
                      icon: Icons.home_work_outlined,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PAGE',
                      value: '${(_offset ~/ _pageSize) + 1}',
                      detail:
                          '${properties.isEmpty ? 0 : _offset + 1}–${_offset + properties.length}',
                      icon: Icons.view_list_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'SEARCH MODE',
                      value: _search == null &&
                              _municipality == null &&
                              _propertyType == null
                          ? 'Browse'
                          : 'Filtered',
                      detail: '25 properties per request',
                      icon: Icons.manage_search_rounded,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 800) {
                          return Column(
                            children: [
                              _propertyField(
                                controller: _searchController,
                                label: 'Address or parcel',
                                icon: Icons.search_rounded,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                              const SizedBox(height: 10),
                              _propertyField(
                                controller: _municipalityController,
                                label: 'Municipality',
                                icon: Icons.location_city_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                              const SizedBox(height: 10),
                              _propertyField(
                                controller: _typeController,
                                label: 'Property type',
                                icon: Icons.category_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _propertyField(
                                controller: _searchController,
                                label: 'Address or parcel',
                                icon: Icons.search_rounded,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _propertyField(
                                controller: _municipalityController,
                                label: 'Municipality',
                                icon: Icons.location_city_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _propertyField(
                                controller: _typeController,
                                label: 'Property type',
                                icon: Icons.category_outlined,
                                onSubmitted: (_) => _applyFilters(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: loading ? null : _applyFilters,
                          icon: const Icon(Icons.search_rounded, size: 17),
                          label: const Text('Search'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: loading ? null : _clearFilters,
                          icon: const Icon(Icons.clear_rounded, size: 17),
                          label: const Text('Clear'),
                        ),
                        const Spacer(),
                        Text(
                          'Search narrows properties before intelligence joins',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.38),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (properties.isEmpty)
              const Card(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No properties match this search.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Connecticut Properties',
                        subtitle:
                            'Inventory • property facts • attached intelligence',
                        action: 'Open property',
                      ),
                      const SizedBox(height: 14),
                      ...properties.map(
                        (property) => _PropertyListCard(property: property),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _offset > 0 && !loading ? _previous : null,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                            ),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: hasMore && !loading ? _next : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                            label: const Text('Next'),
                          ),
                          const Spacer(),
                          Text(
                            '${properties.length} returned',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _propertyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
        ),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
        isDense: true,
        filled: true,
        fillColor: AppTheme.panelSoft.withOpacity(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.cyan),
        ),
      ),
    );
  }
}

class _PropertyListCard extends StatelessWidget {
  const _PropertyListCard({required this.property});

  final Map<String, dynamic> property;

  @override
  Widget build(BuildContext context) {
    final address = (property['full_address'] ?? '').toString();
    final municipality = (property['municipality'] ?? 'Unknown').toString();
    final county = (property['county'] ?? '').toString();
    final parcel = (property['parcel_number'] ?? 'No parcel').toString();
    final type = (property['property_type'] ?? 'UNKNOWN').toString();
    final score = property['final_score'] as num?;
    final opportunityScore = property['opportunity_score'] as num?;
    final priority = property['opportunity_priority']?.toString();
    final signal = property['top_signal_type']?.toString();
    final assessed = property['assessed_total_value'] as num?;
    final yearBuilt = property['year_built'];

    final displayAddress =
        address.trim().isEmpty || address == '${property['postal_code']}, CT'
            ? '$municipality, CT • $parcel'
            : address;

    return InkWell(
      onTap: () => _showPropertyInventoryDetail(context, property),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                color: AppTheme.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      municipality,
                      if (county.isNotEmpty) '$county County',
                      parcel,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OpportunityChip(label: type, color: AppTheme.blue),
                  if (score != null)
                    _OpportunityChip(
                      label: 'SCORE ${score.toStringAsFixed(1)}',
                      color: AppTheme.cyan,
                    ),
                  if (priority != null)
                    _OpportunityChip(
                      label: priority.toUpperCase(),
                      color: _opportunityPriorityColor(priority),
                    ),
                  if (signal != null)
                    _OpportunityChip(
                      label: signal.replaceAll('_', ' ').toUpperCase(),
                      color: AppTheme.green,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 135,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    opportunityScore == null
                        ? 'No active opportunity'
                        : 'Opportunity ${opportunityScore.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: opportunityScore == null
                          ? AppTheme.textMuted
                          : AppTheme.cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (yearBuilt != null) 'Built $yearBuilt',
                      if (assessed != null)
                        '\$${_formatInteger(assessed)} assessed',
                    ].isEmpty
                        ? 'Property record'
                        : [
                            if (yearBuilt != null) 'Built $yearBuilt',
                            if (assessed != null)
                              '\$${_formatInteger(assessed)} assessed',
                          ].join(' • '),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}


void _showPropertyInventoryDetail(
  BuildContext context,
  Map<String, dynamic> property,
) {
  final propertyId = property['property_id']?.toString();
  if (propertyId == null || propertyId.isEmpty) return;

  showDialog<void>(
    context: context,
    builder: (context) => _PropertyIntelligenceDialog(propertyId: propertyId),
  );
}

class _PropertyIntelligenceDialog extends StatefulWidget {
  const _PropertyIntelligenceDialog({required this.propertyId});

  final String propertyId;

  @override
  State<_PropertyIntelligenceDialog> createState() =>
      _PropertyIntelligenceDialogState();
}

class _PropertyIntelligenceDialogState
    extends State<_PropertyIntelligenceDialog> {
  late Future<Map<String, dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_property_detail_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({'p_property_id': widget.propertyId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Property Intelligence API ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected property intelligence response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _reload() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.panel,
      insetPadding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 850),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const SizedBox(
                height: 520,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.cyan,
                    strokeWidth: 2.5,
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DashboardError(
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data ?? <String, dynamic>{};
            final property = data['property'] is Map
                ? Map<String, dynamic>.from(data['property'] as Map)
                : <String, dynamic>{};
            final summary = data['summary'] is Map
                ? Map<String, dynamic>.from(data['summary'] as Map)
                : <String, dynamic>{};
            final scores = _detailList(data['scores']);
            final opportunities = _detailList(data['opportunities']);
            final signals = _detailList(data['signals']);
            final timeline = _detailList(data['timeline']);
            final physical = data['physical_intelligence'] is Map
                ? Map<String, dynamic>.from(
                    data['physical_intelligence'] as Map,
                  )
                : <String, dynamic>{};
            final solar = data['solar_intelligence'] is Map
                ? Map<String, dynamic>.from(data['solar_intelligence'] as Map)
                : <String, dynamic>{};
            final propertyDna = data['property_dna'] is Map
                ? Map<String, dynamic>.from(data['property_dna'] as Map)
                : <String, dynamic>{};
            final building2d = _detailList(physical['building_2d']);
            final building3d = _detailList(physical['building_3d']);
            final solarInstallations = _detailList(solar['installations']);
            final solarPotential = _detailList(solar['potential']);
            final patterns = _detailList(data['patterns']);
            final relationships = _detailList(data['relationships']);
            final modernScores = _detailList(data['modern_scores']);
            final modernPatterns = _detailList(data['modern_patterns']);
            final modernOpportunities =
                _detailList(data['modern_opportunities']);

            final address =
                '${property['full_address'] ?? '${property['municipality'] ?? 'Connecticut'} property'}';
            final assessed = property['assessed_total_value'] as num?;
            final market = property['market_total_value'] as num?;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hub_outlined,
                        color: AppTheme.cyan,
                        size: 25,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PROPERTY INTELLIGENCE RECORD • ${property['municipality'] ?? 'CT'} • ${property['parcel_number'] ?? 'No parcel'}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh intelligence',
                        onPressed: _reload,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withOpacity(.06)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniStat(
                              label: 'MODEL SCORES',
                              value: '${summary['score_count'] ?? scores.length}',
                            ),
                            _MiniStat(
                              label: 'OPPORTUNITIES',
                              value:
                                  '${summary['active_opportunity_count'] ?? opportunities.length}',
                            ),
                            _MiniStat(
                              label: 'SIGNALS',
                              value: '${summary['signal_count'] ?? signals.length}',
                            ),
                            _MiniStat(
                              label: 'TIMELINE',
                              value:
                                  '${summary['timeline_item_count'] ?? timeline.length}',
                            ),
                            _MiniStat(
                              label: 'PHYSICAL',
                              value:
                                  '${propertyDna['physical_record_count'] ?? building2d.length + building3d.length}',
                            ),
                            _MiniStat(
                              label: 'PATTERNS',
                              value:
                                  '${propertyDna['pattern_count'] ?? patterns.length}',
                            ),
                            _MiniStat(
                              label: 'RELATIONSHIPS',
                              value:
                                  '${propertyDna['relationship_count'] ?? relationships.length}',
                            ),
                            _MiniStat(
                              label: 'V37 SCORE',
                              value: modernScores.isEmpty
                                  ? '—'
                                  : _formatDecimal(
                                      modernScores.first['intelligence_score'],
                                    ),
                            ),
                            _MiniStat(
                              label: 'V38 OPPORTUNITIES',
                              value: '${modernOpportunities.length}',
                            ),
                            _MiniStat(
                              label: 'ASSESSED',
                              value: assessed == null
                                  ? '—'
                                  : '\$${_formatInteger(assessed)}',
                            ),
                            _MiniStat(
                              label: 'MARKET',
                              value: market == null
                                  ? '—'
                                  : '\$${_formatInteger(market)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _DetailSection(
                          title: 'Property',
                          subtitle: 'Canonical Connecticut property record',
                          child: Wrap(
                            spacing: 22,
                            runSpacing: 10,
                            children: [
                              _DetailFact('Type', property['property_type']),
                              _DetailFact('Land use', property['land_use_description']),
                              _DetailFact('Year built', property['year_built']),
                              _DetailFact('Buildings', property['building_count']),
                              _DetailFact('Acreage', property['acreage']),
                              _DetailFact('Tax year', property['tax_year']),
                              _DetailFact('County', property['county']),
                              _DetailFact('Postal', property['postal_code']),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Modern BridgePoint Intelligence',
                          subtitle:
                              'V37 scoring, V36 compound patterns and V38 opportunity decisions',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'This property has not reached the modern intelligence engines yet.',
                            records: <Map<String, dynamic>>[
                              ...modernScores.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'V37 Property Score',
                                  ...row,
                                },
                              ),
                              ...modernPatterns.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'V36 Pattern',
                                  ...row,
                                },
                              ),
                              ...modernOpportunities.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'V38 Opportunity',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Physical & Building Intelligence',
                          subtitle:
                              'Connecticut 2023 2D and 3D building baselines linked to this property',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'No matched building baseline currently attached.',
                            records: <Map<String, dynamic>>[
                              ...building2d.map(
                                (row) => <String, dynamic>{
                                  'record_type': '2D building baseline',
                                  ...row,
                                },
                              ),
                              ...building3d.map(
                                (row) => <String, dynamic>{
                                  'record_type': '3D building baseline',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Solar Intelligence',
                          subtitle:
                              'Known installations and property-level solar potential',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'No solar installation or potential record currently attached.',
                            records: <Map<String, dynamic>>[
                              ...solarInstallations.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Solar installation',
                                  ...row,
                                },
                              ),
                              ...solarPotential.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Solar potential',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Patterns & Relationships',
                          subtitle:
                              'Cross-source patterns, ownership and connected-entity intelligence',
                          child: _JsonIntelligenceList(
                            emptyMessage:
                                'No active patterns or relationships currently attached.',
                            records: <Map<String, dynamic>>[
                              ...patterns.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Pattern',
                                  ...row,
                                },
                              ),
                              ...relationships.map(
                                (row) => <String, dynamic>{
                                  'record_type': 'Relationship',
                                  ...row,
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Model Scores',
                          subtitle:
                              'Current BridgePoint scoring results for this property',
                          child: scores.isEmpty
                              ? const _EmptyDetail('No current model scores.')
                              : Column(
                                  children: scores
                                      .map((s) => _ScoreDetailRow(score: s))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Active Opportunities',
                          subtitle:
                              'Qualified actions currently surfaced by BridgePoint',
                          child: opportunities.isEmpty
                              ? const _EmptyDetail(
                                  'No active opportunities currently attached.',
                                )
                              : Column(
                                  children: opportunities
                                      .map(
                                        (o) => _OpportunityDetailRow(
                                          opportunity: o,
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Signals & Evidence',
                          subtitle:
                              'Property evidence and area/context intelligence are labeled separately',
                          child: signals.isEmpty
                              ? const _EmptyDetail('No signals attached.')
                              : Column(
                                  children: signals
                                      .map((s) => _SignalDetailRow(signal: s))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 14),
                        _DetailSection(
                          title: 'Intelligence Timeline',
                          subtitle:
                              'Signals and opportunities ordered by detection time',
                          child: timeline.isEmpty
                              ? const _EmptyDetail('No timeline items.')
                              : Column(
                                  children: timeline
                                      .map((t) => _TimelineDetailRow(item: t))
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Property ID: ${data['property_id'] ?? widget.propertyId}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.25),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _detailList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

class _JsonIntelligenceList extends StatelessWidget {
  const _JsonIntelligenceList({
    required this.records,
    required this.emptyMessage,
  });

  final List<Map<String, dynamic>> records;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return _EmptyDetail(emptyMessage);
    return Column(
      children: records.take(25).map((record) {
        final visible = record.entries.where((entry) {
          final value = entry.value;
          return value != null &&
              '$value'.trim().isNotEmpty &&
              value is! Map &&
              value is! List;
        }).take(10).toList();
        final title = '${record['record_type'] ?? 'Intelligence record'}';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.025),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 18,
                runSpacing: 7,
                children: visible
                    .where((entry) => entry.key != 'record_type')
                    .map(
                      (entry) => _DetailFact(
                        _intelligenceLabel(entry.key),
                        entry.value,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _intelligenceLabel(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft.withOpacity(.38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.055)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailFact extends StatelessWidget {
  const _DetailFact(this.label, this.value);

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${value ?? '—'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreDetailRow extends StatelessWidget {
  const _ScoreDetailRow({required this.score});
  final Map<String, dynamic> score;

  @override
  Widget build(BuildContext context) {
    final finalScore = score['final_score'] as num?;
    final confidence = score['confidence_score'] as num?;
    return _DetailRowShell(
      icon: Icons.speed_rounded,
      title: '${score['model_name'] ?? score['model_key'] ?? 'Model score'}',
      subtitle: '${score['explanation'] ?? 'Current intelligence score'}',
      chips: [
        if (finalScore != null)
          _OpportunityChip(
            label: 'SCORE ${finalScore.toStringAsFixed(1)}',
            color: AppTheme.cyan,
          ),
        if (score['score_status'] != null)
          _OpportunityChip(
            label: '${score['score_status']}'.toUpperCase(),
            color: AppTheme.blue,
          ),
        if (confidence != null)
          _OpportunityChip(
            label: '${confidence.toStringAsFixed(0)}% CONF',
            color: AppTheme.green,
          ),
        _OpportunityChip(
          label: '${score['event_count'] ?? 0} EVENTS',
          color: AppTheme.textMuted,
        ),
      ],
    );
  }
}

class _OpportunityDetailRow extends StatelessWidget {
  const _OpportunityDetailRow({required this.opportunity});
  final Map<String, dynamic> opportunity;

  @override
  Widget build(BuildContext context) {
    final score = opportunity['score'] as num?;
    final priority = '${opportunity['priority'] ?? 'medium'}';
    return _DetailRowShell(
      icon: Icons.bolt_rounded,
      title: '${opportunity['title'] ?? 'Opportunity'}',
      subtitle:
          '${opportunity['recommended_action'] ?? opportunity['explanation'] ?? ''}',
      chips: [
        if (score != null)
          _OpportunityChip(
            label: 'SCORE ${score.toStringAsFixed(1)}',
            color: AppTheme.cyan,
          ),
        _OpportunityChip(
          label: priority.toUpperCase(),
          color: _opportunityPriorityColor(priority),
        ),
        if (opportunity['model_name'] != null)
          _OpportunityChip(
            label: '${opportunity['model_name']}',
            color: AppTheme.blue,
          ),
      ],
    );
  }
}

class _SignalDetailRow extends StatelessWidget {
  const _SignalDetailRow({required this.signal});
  final Map<String, dynamic> signal;

  @override
  Widget build(BuildContext context) {
    final evidence = signal['evidence_summary'] is Map
        ? Map<String, dynamic>.from(signal['evidence_summary'] as Map)
        : <String, dynamic>{};
    final precision = '${evidence['matching_precision'] ?? ''}';
    final contextual = precision.startsWith('AREA_') ||
        '${evidence['storage_mode'] ?? ''}'.contains('area_context');
    final severity = signal['severity'] as num?;
    final confidence = signal['confidence'] as num?;

    return _DetailRowShell(
      icon: contextual ? Icons.public_rounded : Icons.place_outlined,
      title: '${signal['signal_name'] ?? signal['title'] ?? 'Signal'}',
      subtitle: contextual
          ? 'Area/context intelligence • ${evidence['provider'] ?? signal['signal_family'] ?? ''}'
          : 'Property evidence • ${evidence['provider'] ?? signal['signal_family'] ?? ''}',
      chips: [
        _OpportunityChip(
          label: contextual ? 'AREA CONTEXT' : 'PROPERTY EVIDENCE',
          color: contextual ? AppTheme.blue : AppTheme.green,
        ),
        if (severity != null)
          _OpportunityChip(
            label: 'SEV ${severity.toStringAsFixed(0)}',
            color: AppTheme.cyan,
          ),
        if (confidence != null)
          _OpportunityChip(
            label: '${(confidence * 100).toStringAsFixed(0)}% CONF',
            color: AppTheme.textMuted,
          ),
        _OpportunityChip(
          label: '${signal['evidence_count'] ?? 0} EVIDENCE',
          color: AppTheme.textMuted,
        ),
      ],
    );
  }
}

class _TimelineDetailRow extends StatelessWidget {
  const _TimelineDetailRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = '${item['timeline_type'] ?? 'SIGNAL'}';
    final when = '${item['timeline_at'] ?? ''}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(.045)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            type == 'OPPORTUNITY'
                ? Icons.bolt_rounded
                : Icons.radio_button_checked_rounded,
            color: type == 'OPPORTUNITY' ? AppTheme.cyan : AppTheme.blue,
            size: 15,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['title'] ?? type}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  when.length >= 10 ? when.substring(0, 10) : when,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          _OpportunityChip(
            label: type,
            color: type == 'OPPORTUNITY' ? AppTheme.cyan : AppTheme.blue,
          ),
        ],
      ),
    );
  }
}

class _DetailRowShell extends StatelessWidget {
  const _DetailRowShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(.045)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.cyan, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 8,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 10,
      ),
    );
  }
}

class _OpportunitiesPage extends StatefulWidget {
  const _OpportunitiesPage({
    required this.modelKey,
    required this.packageName,
  });

  final String modelKey;
  final String packageName;

  @override
  State<_OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<_OpportunitiesPage> {
  static const int _pageSize = 25;

  late Future<Map<String, dynamic>> _request;
  int _offset = 0;
  String? _priority;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void didUpdateWidget(covariant _OpportunitiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelKey != widget.modelKey) {
      _offset = 0;
      _priority = null;
      _request = _load();
    }
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .post(
          Uri.parse(
            '$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_opportunities_v57',
          ),
          headers: _apiHeaders(),
          body: jsonEncode({
            'p_model_key': widget.modelKey,
            'p_limit': _pageSize,
            'p_offset': _offset,
            'p_priority': _priority,
            'p_stage': null,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'BridgePoint Opportunities API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException(
        'Unexpected BridgePoint Opportunities response.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _request = next;
    });
  }

  void _setPriority(String? value) {
    _offset = 0;
    _priority = value == 'all' ? null : value;
    _refresh();
  }

  void _previousPage() {
    if (_offset <= 0) return;
    _offset = (_offset - _pageSize).clamp(0, 1 << 30);
    _refresh();
  }

  void _nextPage() {
    _offset += _pageSize;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['opportunities'];
        final opportunities = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        final total = (data?['total_results'] as num?)?.toInt() ?? 0;
        final hasMore = data?['has_more'] == true;
        final loading =
            snapshot.connectionState == ConnectionState.waiting;
        final first = total == 0 ? 0 : _offset + 1;
        final last = total == 0
            ? 0
            : (_offset + opportunities.length).clamp(0, total);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Opportunities',
              subtitle:
                  '${widget.packageName} • live ranked Connecticut property intelligence',
              onRefresh: _refresh,
              loading: loading,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'MATCHING OPPORTUNITIES',
                      value: loading && data == null
                          ? '—'
                          : _formatInteger(total),
                      detail: widget.packageName,
                      icon: Icons.bolt_rounded,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'CURRENT PAGE',
                      value: total == 0
                          ? '0'
                          : '${(_offset ~/ _pageSize) + 1}',
                      detail: '$first–$last of ${_formatInteger(total)}',
                      icon: Icons.view_list_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'FILTER',
                      value: _priority == null
                          ? 'All'
                          : _priority!.toUpperCase(),
                      detail: 'Priority filter',
                      icon: Icons.filter_alt_outlined,
                      accent: AppTheme.amber,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.cyan,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Priority',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _priority ?? 'all',
                      dropdownColor: AppTheme.panel,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text('Critical'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('High'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: loading ? null : _setPriority,
                    ),
                    const Spacer(),
                    Text(
                      '25 results per page',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              )
            else if (loading && data == null)
              const Card(
                child: SizedBox(
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.cyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            else if (opportunities.isEmpty)
              const Card(
                child: SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No opportunities match the current filters.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Ranked Property Opportunities',
                        subtitle:
                            'Live scoring • signals • evidence • recommended action',
                        action: 'Open property',
                      ),
                      const SizedBox(height: 14),
                      ...opportunities.map(
                        (opportunity) => _OpportunityListCard(
                          opportunity: opportunity,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _offset > 0 && !loading ? _previousPage : null,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                            ),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed:
                                hasMore && !loading ? _nextPage : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
                            label: const Text('Next'),
                          ),
                          const Spacer(),
                          Text(
                            '$first–$last of ${_formatInteger(total)}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OpportunityListCard extends StatelessWidget {
  const _OpportunityListCard({required this.opportunity});

  final Map<String, dynamic> opportunity;

  @override
  Widget build(BuildContext context) {
    final score = opportunity['score'] as num?;
    final confidence = opportunity['confidence_score'] as num? ??
        opportunity['opportunity_confidence_percent'] as num?;
    final priority =
        (opportunity['priority'] ?? 'medium').toString().toLowerCase();
    final priorityColor = _opportunityPriorityColor(priority);
    final rank = opportunity['rank_value'];
    final address =
        (opportunity['full_address'] ?? 'Address unavailable').toString();
    final signal =
        (opportunity['top_signal_type'] ?? 'No top signal').toString();
    final events = (opportunity['event_count'] as num?)?.toInt() ?? 0;
    final distinctSignals =
        (opportunity['distinct_signal_count'] as num?)?.toInt() ?? 0;
    final stage = (opportunity['stage'] ?? 'monitor').toString();
    final action =
        (opportunity['recommended_action'] ?? 'Continue monitoring').toString();

    return InkWell(
      onTap: () => _showOpportunityDetail(context, opportunity),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                children: [
                  Text(
                    rank == null ? '—' : '#$rank',
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score == null ? '—' : score.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 52,
              color: Colors.white.withOpacity(0.07),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${opportunity['model_name'] ?? opportunity['model_key'] ?? 'BridgePoint'} • $signal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OpportunityChip(
                    label: priority.toUpperCase(),
                    color: priorityColor,
                  ),
                  _OpportunityChip(
                    label: stage.replaceAll('_', ' ').toUpperCase(),
                    color: AppTheme.blue,
                  ),
                  _OpportunityChip(
                    label: '$events EVENTS',
                    color: AppTheme.cyan,
                  ),
                  _OpportunityChip(
                    label: '$distinctSignals SIGNALS',
                    color: AppTheme.green,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 145,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    confidence == null
                        ? 'Confidence —'
                        : 'Confidence ${confidence.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpportunityChip extends StatelessWidget {
  const _OpportunityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

Color _priorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return AppTheme.red;
    case 'high':
      return AppTheme.amber;
    case 'medium':
      return AppTheme.cyan;
    default:
      return AppTheme.textMuted;
  }
}

Future<void> _saveOpportunity(BuildContext context,Map<String,dynamic> opportunity) async {
  try{
    await _callRpc('bridgepoint_save_opportunity_v70',{
      'p_opportunity_id':opportunity['opportunity_id'],'p_property_id':opportunity['property_id'],
      'p_title':opportunity['title']??opportunity['model_name']??'BridgePoint opportunity',
      'p_address':opportunity['full_address']??'','p_score':opportunity['score'],
      'p_reason':opportunity['explanation']??'','p_recommended_action':opportunity['recommended_action']??'',
      'p_vertical_key':opportunity['vertical_key']??opportunity['model_key']??'','p_next_action_at':null});
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Opportunity saved to My Work.')));
  }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save',e.toString());}
}

Future<void> _showAddNoteDialog(BuildContext context,Map<String,dynamic> opportunity) async {
  final note=TextEditingController(); String preset='CALL';
  await showDialog(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
    title:const Text('Add a customer note'),
    content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Choose what happens next, then add anything your team should remember.',style:TextStyle(color:AppTheme.textMuted,height:1.45)),
      const SizedBox(height:14),DropdownButtonFormField<String>(value:preset,dropdownColor:AppTheme.panel,
        decoration:const InputDecoration(labelText:'Preset action',border:OutlineInputBorder()),
        items:const {'CALL':'Call customer','VISIT':'Visit property','QUOTE':'Prepare quote','FOLLOW_UP':'Follow up','NOT_INTERESTED':'Not interested','WON':'Won','LOST':'Lost','GENERAL':'General note'}
          .entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setState(()=>preset=v??preset)),
      const SizedBox(height:12),TextField(controller:note,maxLines:4,decoration:const InputDecoration(labelText:'Note',hintText:'Example: Owner asked for a call Tuesday afternoon.',border:OutlineInputBorder())),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:() async{
      if(note.text.trim().isEmpty)return;
      try{await _callRpc('bridgepoint_save_customer_note_v70',{
        'p_property_id':opportunity['property_id'],'p_opportunity_id':opportunity['opportunity_id'],
        'p_preset_key':preset,'p_note_text':note.text.trim(),'p_follow_up_at':null});
        if(dialogContext.mounted)Navigator.pop(dialogContext);
        if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Note saved to My Work.')));
      }catch(e){if(context.mounted)_showInfoDialog(context,'Could not save note',e.toString());}
    },child:const Text('Save note'))],
  )));
  note.dispose();
}

void _showOpportunityDetail(
  BuildContext context,
  Map<String, dynamic> opportunity,
) {
  final score = opportunity['score'] as num?;
  final assessed = opportunity['assessed_total_value'] as num?;
  final explanation = (opportunity['explanation'] ??
          opportunity['score_explanation'] ??
          'No explanation available.')
      .toString();

  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: AppTheme.panel,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.home_work_outlined,
                        color: AppTheme.cyan,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (opportunity['full_address'] ??
                                  'Property Intelligence')
                              .toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(
                        label: 'SCORE',
                        value: score?.toStringAsFixed(2) ?? '—',
                      ),
                      _MiniStat(
                        label: 'RANK',
                        value: opportunity['rank_value'] == null
                            ? '—'
                            : '#${opportunity['rank_value']}',
                      ),
                      _MiniStat(
                        label: 'EVENTS',
                        value: '${opportunity['event_count'] ?? 0}',
                      ),
                      _MiniStat(
                        label: 'SIGNALS',
                        value:
                            '${opportunity['distinct_signal_count'] ?? 0}',
                      ),
                      _MiniStat(
                        label: 'YEAR BUILT',
                        value: '${opportunity['year_built'] ?? '—'}',
                      ),
                      _MiniStat(
                        label: 'ASSESSED',
                        value: assessed == null
                            ? '—'
                            : '\$${_formatInteger(assessed)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _ReasoningPanel(opportunity:{...opportunity,'explanation':explanation}),
                  const SizedBox(height:20),
                  Row(children:[
                    Expanded(child:FilledButton.icon(onPressed:(){_saveOpportunity(context,opportunity);},icon:const Icon(Icons.bookmark_add_rounded),label:const Text('Save opportunity'))),
                    const SizedBox(width:10),
                    Expanded(child:OutlinedButton.icon(onPressed:(){_showAddNoteDialog(context,opportunity);},icon:const Icon(Icons.note_add_rounded),label:const Text('Add note'))),
                  ]),
                  const SizedBox(height: 18),
                  Text(
                    'Property ID: ${opportunity['property_id'] ?? '—'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.32),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _MyWorkPage extends StatefulWidget {
  const _MyWorkPage();
  @override State<_MyWorkPage> createState()=>_MyWorkPageState();
}
class _MyWorkPageState extends State<_MyWorkPage>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('bridgepoint_my_work_v70',const {'p_limit':200});}
  void refresh()=>setState(()=>request=_callRpc('bridgepoint_my_work_v70',const {'p_limit':200}));
  Future<void> stage(Map<String,dynamic> item,String value) async{
    try{await _callRpc('bridgepoint_update_lead_stage_v70',{
      'p_saved_opportunity_id':item['saved_opportunity_id'],'p_lead_stage':value,'p_next_action_at':item['next_action_at']});refresh();}
    catch(e){if(mounted)_showInfoDialog(context,'Could not update lead',e.toString());}
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(future:request,builder:(context,snapshot){
    final savedRaw=snapshot.data?['saved_opportunities'];final noteRaw=snapshot.data?['open_notes'];
    final saved=savedRaw is List?savedRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final notes=noteRaw is List?noteRaw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
    final due=saved.where((e)=>e['next_action_at']!=null).length+notes.where((e)=>e['follow_up_at']!=null).length;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _PageHeading(title:'My Work',subtitle:'Saved opportunities • lead stages • notes • follow-up calendar',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),
      const SizedBox(height:10),const _ExplainerBanner(icon:Icons.lightbulb_rounded,title:'Turn intelligence into action',message:'Save a promising opportunity, move it through your real sales stages, add notes, and schedule the next action. Rankings can change; your saved work stays here.'),
      const SizedBox(height:18),LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=900?3:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
        _MetricCard(width:w,label:'SAVED LEADS',value:_formatInteger(saved.length),detail:'Opportunities kept by you',icon:Icons.bookmarks_rounded,accent:AppTheme.cyan),
        _MetricCard(width:w,label:'OPEN NOTES',value:_formatInteger(notes.length),detail:'Customer and property notes',icon:Icons.sticky_note_2_rounded,accent:AppTheme.green),
        _MetricCard(width:w,label:'CALENDAR ITEMS',value:_formatInteger(due),detail:'Scheduled next actions',icon:Icons.calendar_month_rounded,accent:AppTheme.amber),
      ]);}),
      const SizedBox(height:18),
      if(snapshot.hasError)_DashboardError(message:snapshot.error.toString(),onRetry:refresh)
      else LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=980;final width=wide?(c.maxWidth-16)/2:c.maxWidth;return Wrap(spacing:16,runSpacing:16,children:[
        SizedBox(width:width,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Saved Opportunities',subtitle:'Your working lead list—independent of live ranking changes',action:'Lead stage'),const SizedBox(height:12),
          if(saved.isEmpty)const SizedBox(height:180,child:Center(child:Text('Open an opportunity and choose “Save opportunity.”',style:TextStyle(color:AppTheme.textMuted))))
          else ...saved.map((item)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text(item['address']?.toString().isNotEmpty==true?item['address'].toString():item['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w800))),Text('${item['score']??'—'}',style:const TextStyle(color:AppTheme.cyan,fontWeight:FontWeight.w900))]),
            const SizedBox(height:5),Text(item['reason']?.toString()??'',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),
            const SizedBox(height:9),DropdownButtonFormField<String>(value:item['lead_stage']?.toString()??'NEW',dropdownColor:AppTheme.panel,
              decoration:const InputDecoration(labelText:'Lead stage',isDense:true,border:OutlineInputBorder()),
              items:const ['NEW','REVIEWING','CONTACTED','APPOINTMENT','INSPECTION','ESTIMATE','QUOTE','CONTRACT_CLAIM','WON','LOST'].map((v)=>DropdownMenuItem(value:v,child:Text(v.replaceAll('_',' ')))).toList(),
              onChanged:(v){if(v!=null)stage(item,v);}),
          ]))),
        ])))),
        SizedBox(width:width,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Notes & Calendar',subtitle:'Preset actions and scheduled follow-ups',action:'Next action'),const SizedBox(height:12),
          if(notes.isEmpty)const SizedBox(height:180,child:Center(child:Text('Customer notes and follow-ups will appear here.',style:TextStyle(color:AppTheme.textMuted))))
          else ...notes.map((item)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(12)),child:Row(children:[
            Container(width:38,height:38,decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.1),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.event_note_rounded,color:AppTheme.amber,size:19)),
            const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item['preset_key']?.toString().replaceAll('_',' ')??'NOTE',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:AppTheme.cyan)),const SizedBox(height:4),Text(item['note_text']?.toString()??'',style:const TextStyle(fontSize:11,height:1.4))])),
            Text(item['follow_up_at']==null?'UNSCHEDULED':item['follow_up_at'].toString().substring(0,10),style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700)),
          ]))),
        ])))),
      ]);}),
    ]);
  });
}

class _OwnerCenterPage extends StatefulWidget{
  const _OwnerCenterPage();
  @override State<_OwnerCenterPage> createState()=>_OwnerCenterPageState();
}

class _OwnerCenterPageState extends State<_OwnerCenterPage>{
  late Future<Map<String,dynamic>> request;
  @override void initState(){super.initState();request=_callRpc('owner_dashboard_v63',const {});}
  void refresh()=>setState(()=>request=_callRpc('owner_dashboard_v63',const {}));
  Map<String,dynamic> map(dynamic value)=>value is Map?Map<String,dynamic>.from(value):<String,dynamic>{};
  List<Map<String,dynamic>> rows(dynamic value)=>value is List
      ?value.whereType<Map>().map((item)=>Map<String,dynamic>.from(item)).toList()
      :<Map<String,dynamic>>[];
  String money(dynamic value){final amount=value is num?value.toDouble():double.tryParse('$value')??0;return '\$${amount.toStringAsFixed(0)}';}

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:request,builder:(context,snapshot){
      final data=snapshot.data??const <String,dynamic>{};
      final system=map(data['system']),customers=map(data['customers']),revenue=map(data['revenue']);
      final offer=map(data['founding_offer']),intel=map(data['intelligence']);
      final verticals=rows(data['top_opportunity_verticals']),failures=rows(data['recent_failures']);
      final healthy=(system['failed_runs_15m'] as num? ?? 0)==0;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _PageHeading(title:'Owner Center',subtitle:'Your private daily view of revenue • customers • automation • intelligence',onRefresh:refresh,loading:snapshot.connectionState==ConnectionState.waiting),
        const SizedBox(height:10),_ExplainerBanner(
          icon:healthy?Icons.verified_rounded:Icons.warning_amber_rounded,
          title:healthy?'BridgePoint is operating normally':'BridgePoint needs your attention',
          message:healthy?'Start here each day. This page combines customer growth, revenue readiness, promotion use, automation health, and intelligence production.':'Review the recent failures below. Customer-facing intelligence remains separated from this owner-only page.',
        ),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=1000?4:c.maxWidth>=620?2:1;const gap=14.0;final w=(c.maxWidth-gap*(cols-1))/cols;return Wrap(spacing:gap,runSpacing:gap,children:[
          _MetricCard(width:w,label:'CUSTOMERS',value:_formatInteger(customers['total_accounts']??0),detail:'${customers['new_7d']??0} joined in the last 7 days',icon:Icons.groups_rounded,accent:AppTheme.cyan),
          _MetricCard(width:w,label:'ACTIVE MRR',value:money(revenue['active_mrr']),detail:'${customers['active_paid']??0} active paid accounts',icon:Icons.payments_rounded,accent:AppTheme.green),
          _MetricCard(width:w,label:'TRIAL PIPELINE',value:money(revenue['trial_pipeline_mrr']),detail:'${customers['active_trials']??0} active customer trials',icon:Icons.hourglass_top_rounded,accent:AppTheme.amber),
          _MetricCard(width:w,label:'CRITICAL OPPORTUNITIES',value:_formatInteger(intel['critical_opportunities']??0),detail:'Highest-priority active intelligence',icon:Icons.bolt_rounded,accent:AppTheme.red),
        ]);}),
        const SizedBox(height:18),
        LayoutBuilder(builder:(context,c){final wide=c.maxWidth>=980;final w=wide?(c.maxWidth-16)/2:c.maxWidth;return Wrap(spacing:16,runSpacing:16,children:[
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Customer & Revenue Watch',subtitle:'The items most likely to need a decision today',action:'Private'),const SizedBox(height:14),
            _OwnerStatusRow('Trials ending within 72 hours','${customers['trials_ending_72h']??0}',AppTheme.amber),
            _OwnerStatusRow('Past-due subscriptions','${customers['past_due']??0}',(customers['past_due'] as num? ?? 0)>0?AppTheme.red:AppTheme.green),
            _OwnerStatusRow('Checkout connected',revenue['checkout_connected']==true?'YES':'NOT YET',revenue['checkout_connected']==true?AppTheme.green:AppTheme.amber),
            _OwnerStatusRow('Founding offer remaining','${offer['remaining']??10} of 10',AppTheme.cyan),
            _OwnerStatusRow('Founding discounts applied','${offer['applied']??0}',AppTheme.green),
          ])))),
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Automation & Intelligence',subtitle:'Whether the data-to-opportunity system is moving',action:'Live'),const SizedBox(height:14),
            _OwnerStatusRow('Active scheduled jobs','${system['active_jobs']??0}',AppTheme.cyan),
            _OwnerStatusRow('Failed runs in 15 minutes','${system['failed_runs_15m']??0}',healthy?AppTheme.green:AppTheme.red),
            _OwnerStatusRow('Property scores',_formatInteger(intel['property_scores_v37']??0),AppTheme.blue),
            _OwnerStatusRow('Detected patterns',_formatInteger(intel['patterns_v36']??0),AppTheme.green),
            _OwnerStatusRow('Active opportunities',_formatInteger(intel['opportunities_v38']??0),AppTheme.amber),
          ])))),
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Opportunity Mix',subtitle:'Where BridgePoint currently sees the most actionable volume',action:'Top models'),const SizedBox(height:12),
            if(verticals.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Opportunity mix will appear as models produce results.',style:TextStyle(color:AppTheme.textMuted)))
            else ...verticals.map((item)=>_OwnerStatusRow(item['vertical_key']?.toString().replaceAll('_',' ').toUpperCase()??'MODEL','${_formatInteger(item['opportunity_count']??0)} • avg ${item['average_score']??'—'}',AppTheme.cyan)),
          ])))),
          SizedBox(width:w,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const _PanelHeader(title:'Recent Automation Failures',subtitle:'Only owner-visible operational messages',action:'Last 10'),const SizedBox(height:12),
            if(failures.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Row(children:[Icon(Icons.check_circle_rounded,color:AppTheme.green),SizedBox(width:10),Expanded(child:Text('No recent failures recorded.',style:TextStyle(color:AppTheme.textMuted)))]))
            else ...failures.map((item)=>Container(
              margin:const EdgeInsets.only(bottom:8),
              padding:const EdgeInsets.all(11),
              decoration:BoxDecoration(
                color:AppTheme.red.withOpacity(.06),
                borderRadius:BorderRadius.circular(10),
                border:Border.all(color:AppTheme.red.withOpacity(.14)),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('JOB ${item['jobid']??'—'} • ${item['status']??'FAILED'}',style:const TextStyle(color:AppTheme.red,fontSize:10,fontWeight:FontWeight.w900)),
                const SizedBox(height:4),
                Text(item['message']?.toString()??'No error detail',maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.4)),
              ]),
            )),
          ])))),
        ]);}),
        if(snapshot.hasError)...[const SizedBox(height:16),_DashboardError(message:snapshot.error.toString(),onRetry:refresh)],
      ]);
    },
  );
}

class _OwnerStatusRow extends StatelessWidget{
  const _OwnerStatusRow(this.label,this.value,this.color);
  final String label,value;final Color color;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Expanded(child:Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:11))),Text(value,style:TextStyle(color:color,fontWeight:FontWeight.w900,fontSize:11))]));
}

class _ExplainerBanner extends StatelessWidget{
  const _ExplainerBanner({required this.icon,required this.title,required this.message});final IconData icon;final String title,message;
  @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(
    gradient:LinearGradient(colors:[AppTheme.cyan.withOpacity(.10),AppTheme.blue.withOpacity(.05)]),borderRadius:BorderRadius.circular(14),border:Border.all(color:AppTheme.cyan.withOpacity(.18))),
    child:Row(children:[Icon(icon,color:AppTheme.cyan),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(message,style:const TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45))]))]));
}

class _PermitContextPage extends StatefulWidget {
  const _PermitContextPage();
  @override
  State<_PermitContextPage> createState() => _PermitContextPageState();
}

class _PermitContextPageState extends State<_PermitContextPage> {
  late Future<Map<String, dynamic>> _request;
  final _town = TextEditingController();

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void dispose() {
    _town.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load([String? municipality]) async {
    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/bridgepoint_flutter_permit_context_v68'),
      headers: _apiHeaders(),
      body: jsonEncode({'p_municipality': municipality?.trim().isEmpty == true ? null : municipality?.trim()}),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Permit Context API ${response.statusCode}: ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Unexpected permit context response.');
    return Map<String, dynamic>.from(decoded);
  }

  void _refresh() => setState(() => _request = _load(_town.text));
  void _clear() {
    _town.clear();
    setState(() => _request = _load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _request,
    builder: (context, snapshot) {
      final raw = snapshot.data?['rows'];
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final latestYear = rows.fold<int>(0, (value, row) =>
          ((row['report_year'] as num?)?.toInt() ?? 0) > value
              ? ((row['report_year'] as num?)?.toInt() ?? 0) : value);
      final latest = rows.where((row) => (row['report_year'] as num?)?.toInt() == latestYear).toList();
      final units = latest.fold<int>(0, (sum, row) => sum + ((row['total_units'] as num?)?.toInt() ?? 0));
      final demolitions = latest.fold<int>(0, (sum, row) => sum + ((row['demolitions'] as num?)?.toInt() ?? 0));
      final loading = snapshot.connectionState == ConnectionState.waiting;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PageHeading(
          title: 'Permit Context',
          subtitle: 'Official Connecticut DECD construction activity • municipality-level context',
          onRefresh: _refresh,
          loading: loading,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 3 : 1;
          const gap = 14.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            _MetricCard(width: width,label:'LATEST REPORT',value:latestYear == 0 ? '—' : '$latestYear',detail:'DECD annual construction report',icon:Icons.calendar_month_rounded,accent:AppTheme.cyan),
            _MetricCard(width: width,label:'PERMITTED UNITS',value:_formatInteger(units),detail:'Current filtered latest-year total',icon:Icons.apartment_rounded,accent:AppTheme.green),
            _MetricCard(width: width,label:'DEMOLITIONS',value:_formatInteger(demolitions),detail:'Current filtered latest-year total',icon:Icons.domain_disabled_rounded,accent:AppTheme.amber),
          ]);
        }),
        const SizedBox(height: 18),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
          Expanded(child:TextField(controller:_town,onSubmitted:(_)=>_refresh(),decoration:const InputDecoration(prefixIcon:Icon(Icons.location_city_rounded),labelText:'Filter by municipality',hintText:'Example: Hartford',border:OutlineInputBorder()))),
          const SizedBox(width:10),FilledButton.icon(onPressed:loading?null:_refresh,icon:const Icon(Icons.search_rounded),label:const Text('Apply')),
          const SizedBox(width:8),OutlinedButton(onPressed:loading?null:_clear,child:const Text('Clear')),
        ]))),
        const SizedBox(height: 18),
        if (snapshot.hasError) _DashboardError(message:snapshot.error.toString(),onRetry:_refresh)
        else if (loading && rows.isEmpty) const Card(child:SizedBox(height:240,child:Center(child:CircularProgressIndicator(color:AppTheme.cyan))))
        else Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Municipal Construction Activity',subtitle:'Permitted housing units and demolitions • contextual evidence, not individual permit records',action:'Live source'),
          const SizedBox(height:12),
          ...rows.take(100).map((row)=>Container(
            margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),
            decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(.06))),
            child:Row(children:[
              Container(width:42,height:42,decoration:BoxDecoration(color:AppTheme.cyan.withOpacity(.10),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.construction_rounded,color:AppTheme.cyan,size:20)),
              const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${row['municipality'] ?? 'Unknown'} • ${row['report_year'] ?? '—'}',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800)),
                const SizedBox(height:4),Text('${row['county'] ?? 'Statewide'} County • ${_formatInteger(row['one_unit'])} single-family • ${_formatInteger(row['five_plus_units'])} 5+ unit',style:const TextStyle(color:AppTheme.textMuted,fontSize:10)),
              ])),
              _PermitValue(label:'UNITS',value:_formatInteger(row['total_units']),color:AppTheme.green),
              const SizedBox(width:18),_PermitValue(label:'DEMOS',value:_formatInteger(row['demolitions']),color:AppTheme.amber),
            ]),
          )),
          if(rows.isEmpty) const SizedBox(height:180,child:Center(child:Text('No municipality matched that filter.',style:TextStyle(color:AppTheme.textMuted)))),
        ]))),
      ]);
    },
  );
}

class _PermitValue extends StatelessWidget {
  const _PermitValue({required this.label,required this.value,required this.color});
  final String label,value; final Color color;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
    Text(value,style:TextStyle(color:color,fontSize:15,fontWeight:FontWeight.w900)),
    Text(label,style:const TextStyle(color:AppTheme.textMuted,fontSize:8,fontWeight:FontWeight.w800,letterSpacing:.6)),
  ]);
}

class _SourcesPage extends StatelessWidget {
  const _SourcesPage({
    required this.sourcesRequest,
    required this.onRefresh,
  });

  final Future<Map<String, dynamic>> sourcesRequest;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: sourcesRequest,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raw = data?['sources'];
        final sources = raw is List
            ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        final connected = data?['connected_source_count'];
        final registered = data?['registered_source_count'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(
              title: 'Intelligence Sources',
              subtitle:
                  'Live registry, source health, ingestion volume, and refresh state',
              onRefresh: onRefresh,
              loading: snapshot.connectionState == ConnectionState.waiting,
            ),
            const SizedBox(height: 22),
            if (snapshot.hasError)
              _DashboardError(
                message: snapshot.error.toString(),
                onRetry: onRefresh,
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 3 : 1;
                  const gap = 14.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      _MetricCard(
                        width: width,
                        label: 'CONNECTED',
                        value: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '—'
                            : _formatInteger(connected),
                        detail: 'Enabled Connecticut sources',
                        icon: Icons.hub_rounded,
                        accent: AppTheme.green,
                      ),
                      _MetricCard(
                        width: width,
                        label: 'REGISTERED',
                        value: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '—'
                            : _formatInteger(registered),
                        detail: 'Sources in the live registry',
                        icon: Icons.inventory_2_outlined,
                        accent: AppTheme.cyan,
                      ),
                      _MetricCard(
                        width: width,
                        label: 'RECORDS TRACKED',
                        value: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '—'
                            : _formatCompact(
                                sources.fold<num>(
                                  0,
                                  (sum, source) =>
                                      sum +
                                      ((source['total_records_ingested']
                                              as num?) ??
                                          0),
                                ),
                              ),
                        detail: 'Registry-reported ingested records',
                        icon: Icons.data_usage_rounded,
                        accent: AppTheme.blue,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PanelHeader(
                        title: 'Source Registry',
                        subtitle:
                            'Automatically rendered from Supabase — no hard-coded source cards',
                        action: 'Live',
                      ),
                      const SizedBox(height: 18),
                      if (snapshot.connectionState ==
                          ConnectionState.waiting)
                        const SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.cyan,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1050
                                ? 2
                                : 1;
                            const gap = 14.0;
                            final width =
                                (constraints.maxWidth -
                                        gap * (columns - 1)) /
                                    columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: sources
                                  .map(
                                    (source) => _DetailedSourceCard(
                                      width: width,
                                      source: source,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LiveSourceCard extends StatelessWidget {
  const _LiveSourceCard({required this.width, required this.source});

  final double width;
  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final category = (source['source_category'] ?? 'INTELLIGENCE').toString();
    final color = _sourceColor(category);
    final icon = _sourceIcon(source);
    final healthy = (source['health_status'] ?? '').toString() == 'HEALTHY';

    return InkWell(
      onTap: () => _showSourceDetail(context, source),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (source['source_name'] ?? 'Unnamed source').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _sourceSubtitle(source),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PulseDot(color: healthy ? AppTheme.green : AppTheme.amber),
        ],
        ),
      ),
    );
  }
}

class _DetailedSourceCard extends StatelessWidget {
  const _DetailedSourceCard({
    required this.width,
    required this.source,
  });

  final double width;
  final Map<String, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final category = (source['source_category'] ?? 'INTELLIGENCE').toString();
    final color = _sourceColor(category);
    final health = (source['health_status'] ?? 'NOT_RUN').toString();
    final provider = (source['provider'] ?? 'Provider unavailable').toString();
    final records = _formatInteger(source['total_records_ingested']);
    final refresh =
        (source['refresh_frequency'] ?? 'Not scheduled').toString();
    final confidence = source['default_confidence'] is num
        ? '${((source['default_confidence'] as num) * 100).toStringAsFixed(0)}%'
        : '—';

    return InkWell(
      onTap: () => _showSourceDetail(context, source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.panelSoft.withOpacity(0.52),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_sourceIcon(source), color: color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (source['source_name'] ?? 'Unnamed source').toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      provider,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _HealthBadge(status: health),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _sourceSubtitle(source),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(label: 'RECORDS', value: records),
              _MiniStat(label: 'REFRESH', value: refresh),
              _MiniStat(label: 'CONFIDENCE', value: confidence),
              _MiniStat(label: 'ACCESS', value: '${source['access_method'] ?? '—'}'),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

void _showSourceDetail(
  BuildContext context,
  Map<String, dynamic> source,
) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_rounded, color: AppTheme.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${source['source_name'] ?? 'Intelligence Source'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _sourceSubtitle(source),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: _JsonIntelligenceList(
                    records: [source],
                    emptyMessage: 'No source details available.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showInfoDialog(
  BuildContext context,
  String title,
  String message,
) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(
        message,
        style: const TextStyle(color: AppTheme.textMuted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final healthy = status == 'HEALTHY';
    final color = healthy ? AppTheme.green : AppTheme.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.loading,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        _IconButton(
          icon: Icons.refresh_rounded,
          onTap: loading ? () {} : onRefresh,
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.red.withOpacity(0.18)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.ownerMode,
    required this.settingsRequest,
    required this.healthRequest,
    required this.refreshSeconds,
    required this.onRefreshSecondsChanged,
    required this.onRefresh,
  });

  final bool ownerMode;

  final Future<Map<String, dynamic>> settingsRequest;
  final Future<Map<String, dynamic>> healthRequest;
  final int refreshSeconds;
  final ValueChanged<int> onRefreshSecondsChanged;
  final VoidCallback onRefresh;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late int _refreshSeconds;
  bool _showConfidence = true;
  bool _showPatterns = true;
  bool _showRawSignals = true;
  bool _mapAutoRotate = true;
  String _mapStyle = 'standard';
  String _feedbackCategory = 'SUGGESTION';
  final _feedback = TextEditingController();
  bool _sendingFeedback = false;

  @override
  void initState() {
    super.initState();
    _refreshSeconds = widget.refreshSeconds;
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeconds != widget.refreshSeconds) {
      _refreshSeconds = widget.refreshSeconds;
    }
  }

  @override void dispose(){_feedback.dispose();super.dispose();}
  Future<void> _sendFeedback() async{
    if(_feedback.text.trim().length<3)return;
    setState(()=>_sendingFeedback=true);
    try{await _callRpc('bridgepoint_submit_feedback_v70',{'p_category':_feedbackCategory,'p_page_key':'settings','p_message':_feedback.text.trim()});
      _feedback.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Thank you—your suggestion was received.')));
    }catch(e){if(mounted)_showInfoDialog(context,'Could not send suggestion',e.toString());}
    finally{if(mounted)setState(()=>_sendingFeedback=false);}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeading(
          title: 'Settings',
          subtitle: 'Live workspace controls • security • automation • account readiness',
          onRefresh: widget.onRefresh,
          loading: false,
        ),
        const SizedBox(height: 18),
        FutureBuilder<Map<String, dynamic>>(
          future: widget.healthRequest,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const <String, dynamic>{};
            final cron = data['cron'] is Map
                ? Map<String, dynamic>.from(data['cron'] as Map)
                : const <String, dynamic>{};
            final engines = data['engine_estimates'] is Map
                ? Map<String, dynamic>.from(data['engine_estimates'] as Map)
                : const <String, dynamic>{};
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 4 : 2;
                const gap = 14.0;
                final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _MetricCard(
                      width: width,
                      label: 'SYSTEM',
                      value: '${data['status'] ?? (snapshot.hasError ? 'ATTENTION' : 'LOADING')}',
                      detail: '${cron['recent_failures_15m'] ?? 0} failures in 15 minutes',
                      icon: Icons.health_and_safety_rounded,
                      accent: data['status'] == 'HEALTHY' ? AppTheme.green : AppTheme.amber,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'ACTIVE WORKERS',
                      value: '${cron['active_jobs'] ?? '—'}',
                      detail: '${cron['recent_successes_15m'] ?? '—'} successful runs in 15m',
                      icon: Icons.precision_manufacturing_rounded,
                      accent: AppTheme.cyan,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'OPPORTUNITIES',
                      value: _compactNumber(engines['opportunities_v38']),
                      detail: 'Modern V38 live estimate',
                      icon: Icons.bolt_rounded,
                      accent: AppTheme.blue,
                    ),
                    _MetricCard(
                      width: width,
                      label: 'PROPERTY SCORES',
                      value: _compactNumber(engines['property_scores_v37']),
                      detail: 'Modern V37 live estimate',
                      icon: Icons.analytics_rounded,
                      accent: AppTheme.green,
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final width = wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _SettingsSection(
                    icon: Icons.sync_rounded,
                    title: 'Live refresh',
                    subtitle: 'Control how often the workspace pulls new intelligence.',
                    children: [
                      DropdownButtonFormField<int>(
                        value: _refreshSeconds,
                        dropdownColor: AppTheme.panelSoft,
                        decoration: const InputDecoration(
                          labelText: 'Automatic refresh interval',
                          border: OutlineInputBorder(),
                        ),
                        items: const [30, 60, 120, 300, 600]
                            .map((seconds) => DropdownMenuItem(
                                  value: seconds,
                                  child: Text(seconds < 60
                                      ? '$seconds seconds'
                                      : '${seconds ~/ 60} minute${seconds == 60 ? '' : 's'}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _refreshSeconds = value);
                          widget.onRefreshSecondsChanged(value);
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Applied immediately to this live workspace.',
                        style: TextStyle(color: AppTheme.green, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SettingsSection(
                    icon: Icons.map_rounded,
                    title: 'Intelligence map',
                    subtitle: 'Opportunity markers now use category-specific icons.',
                    children: [
                      DropdownButtonFormField<String>(
                        value: _mapStyle,
                        dropdownColor: AppTheme.panelSoft,
                        decoration: const InputDecoration(
                          labelText: 'Map style',
                          border: OutlineInputBorder(),
                        ),
                        items: const ['standard', 'street', 'satellite']
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value[0].toUpperCase() + value.substring(1)),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _mapStyle = value ?? 'standard'),
                      ),
                      SwitchListTile(
                        value: _mapAutoRotate,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Automatically rotate live results'),
                        onChanged: (value) => setState(() => _mapAutoRotate = value),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SettingsSection(
                    icon: Icons.visibility_rounded,
                    title: 'Evidence display',
                    subtitle: 'Choose which intelligence details appear in property views.',
                    children: [
                      _SettingsSwitch('Confidence scores', _showConfidence,
                          (v) => setState(() => _showConfidence = v)),
                      _SettingsSwitch('Detected patterns', _showPatterns,
                          (v) => setState(() => _showPatterns = v)),
                      _SettingsSwitch('Raw supporting signals', _showRawSignals,
                          (v) => setState(() => _showRawSignals = v)),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: widget.settingsRequest,
                    builder: (context, snapshot) {
                      final authenticated = snapshot.data?['authentication_configured'] == true;
                      return _SettingsSection(
                        icon: Icons.workspace_premium_rounded,
                        title: 'Account & trial',
                        subtitle: 'Every new account receives BridgePoint All Intelligence.',
                        children: [
                          const _SettingsStatusRow(
                            label: 'Free trial',
                            value: '7 days',
                            color: AppTheme.green,
                          ),
                          const _SettingsStatusRow(
                            label: 'Payment method',
                            value: 'Not required for trial',
                            color: AppTheme.cyan,
                          ),
                          _SettingsStatusRow(
                            label: 'Authentication',
                            value: authenticated ? 'Configured' : 'Ready for first account',
                            color: authenticated ? AppTheme.green : AppTheme.amber,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your account, trial and billing settings synchronize securely across devices.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.45),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(width:double.infinity,child:OutlinedButton.icon(
                            onPressed:()=>_openBillingPortal(context),
                            icon:const Icon(Icons.credit_card_rounded),label:const Text('Manage billing'),
                          )),
                          SizedBox(width:double.infinity,child:TextButton.icon(
                            onPressed:()=>Supabase.instance.client.auth.signOut(),
                            icon:const Icon(Icons.logout_rounded),label:const Text('Sign out'),
                          )),
                        ],
                      );
                    },
                  ),
                ),
                if(widget.ownerMode)SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.preview_rounded,title:'Customer experience preview',
                  subtitle:'Your owner account stays free and unlocked. Replay customer-facing moments without changing your access.',
                  children:[
                    SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:()=>showDialog<void>(context:context,builder:(context)=>const _WalkthroughDialog()),
                      icon:const Icon(Icons.route_rounded),label:const Text('Replay guided walkthrough'))),
                    const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(
                      onPressed:()=>showDialog<void>(context:context,builder:(context)=>AlertDialog(
                        backgroundColor:AppTheme.panel,title:const Text('Customer welcome preview'),
                        content:const Text('New customers choose a profile name, answer five dropdown questions, receive a package recommendation, then land on a personalized Daily Brief. Your owner account bypasses those gates while this preview remains available.'),
                        actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Got it'))])),
                      icon:const Icon(Icons.waving_hand_outlined),label:const Text('Preview signup & welcome'))),
                    const SizedBox(height:8),const Text('To see the live personalized welcome, choose Daily Brief in the left menu. To see alerts, tap the bell.',style:TextStyle(color:AppTheme.textMuted,fontSize:10,height:1.45)),
                  ],
                )),
                SizedBox(width:width,child:_SettingsSection(
                  icon:Icons.forum_rounded,title:'Suggestions & feedback',
                  subtitle:'Tell us what would make BridgePoint more useful. Every submission is saved for review.',
                  children:[
                    DropdownButtonFormField<String>(value:_feedbackCategory,dropdownColor:AppTheme.panelSoft,
                      decoration:const InputDecoration(labelText:'Type',border:OutlineInputBorder()),
                      items:const {'SUGGESTION':'Suggestion','BUG':'Something is not working','DATA_REQUEST':'Request a data source','QUESTION':'Question','COMPLIMENT':'What you like'}
                        .entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
                      onChanged:_sendingFeedback?null:(v)=>setState(()=>_feedbackCategory=v??_feedbackCategory)),
                    const SizedBox(height:10),TextField(controller:_feedback,maxLines:4,
                      decoration:const InputDecoration(labelText:'What should we know?',hintText:'Describe the idea, problem, or data you want added.',border:OutlineInputBorder())),
                    const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(
                      onPressed:_sendingFeedback?null:_sendFeedback,icon:const Icon(Icons.send_rounded),label:Text(_sendingFeedback?'Sending…':'Send to BridgePoint'))),
                  ],
                )),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppTheme.cyan, size: 21),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.4)),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        onChanged: onChanged,
      );
}

class _SettingsStatusRow extends StatelessWidget {
  const _SettingsStatusRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

String _compactNumber(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) return '—';
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(2)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
  return number.toStringAsFixed(0);
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        height: 420,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.cyan, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This BridgePoint workspace is next in the live-data build.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _sourceIcon(Map<String, dynamic> source) {
  final explicit = (source['flutter_icon'] ?? '').toString().toLowerCase();
  final category = (source['source_category'] ?? '').toString().toUpperCase();
  final value='${source['source_code']??''} ${source['source_name']??''} ${source['provider']??''} $category $explicit'.toLowerCase();

  if(value.contains('fema')||value.contains('flood'))return Icons.flood_outlined;
  if(value.contains('nfirs')||value.contains('fire'))return Icons.local_fire_department_outlined;
  if(value.contains('noaa')||value.contains('storm')||value.contains('weather'))return Icons.thunderstorm_outlined;
  if(value.contains('ust')||value.contains('tank'))return Icons.oil_barrel_outlined;
  if(value.contains('spill')||value.contains('release'))return Icons.water_drop_outlined;
  if(value.contains('react')||value.contains('remediation')||value.contains('brownfield'))return Icons.science_outlined;
  if(value.contains('solar'))return Icons.solar_power_outlined;
  if(value.contains('usgs')||value.contains('hydrolog')||value.contains('elevation'))return Icons.terrain_outlined;
  if(value.contains('business')||value.contains('registry'))return Icons.business_center_outlined;
  if(value.contains('transition')||value.contains('sale')||value.contains('ownership'))return Icons.swap_horiz_rounded;
  if(value.contains('footprint')||value.contains('building')||value.contains('lidar')||value.contains('3d'))return Icons.architecture_outlined;
  if(value.contains('permit')||value.contains('construction'))return Icons.construction_outlined;
  if(value.contains('grid')||value.contains('outage')||value.contains('electric'))return Icons.electric_bolt_outlined;
  if(value.contains('census')||value.contains('demograph'))return Icons.groups_outlined;
  if(value.contains('311')||value.contains('service request'))return Icons.campaign_outlined;
  if(value.contains('cama')||value.contains('parcel')||value.contains('property'))return Icons.home_work_outlined;
  return Icons.dataset_outlined;
}

Color _sourceColor(String category) {
  final value = category.toUpperCase();
  if (value.contains('FIRE')) return AppTheme.red;
  if (value.contains('GRID')) return AppTheme.amber;
  if (value.contains('FLOOD') || value.contains('DISASTER')) {
    return AppTheme.cyan;
  }
  if (value.contains('TRANSITION')) return AppTheme.green;
  if (value.contains('WEATHER') || value.contains('STORM')) {
    return AppTheme.blue;
  }
  return AppTheme.cyan;
}

String _sourceSubtitle(Map<String, dynamic> source) {
  final description = source['description']?.toString();
  if (description != null && description.trim().isNotEmpty) {
    return description;
  }

  switch ((source['source_category'] ?? '').toString().toUpperCase()) {
    case 'WEATHER':
      return 'Weather exposure, storm events, and proximity intelligence';
    case 'FIRE':
      return 'Fire incidents and property-relevant fire intelligence';
    case 'DISASTER_FLOOD':
      return 'Disaster, flood, and FEMA property intelligence';
    case 'GRID_INFRASTRUCTURE':
      return 'Grid outage, reliability, and infrastructure intelligence';
    case 'PROPERTY_TRANSITION':
      return 'Recorded property sales and ownership-transition intelligence';
    default:
      return (source['source_category'] ?? 'Connected intelligence source')
          .toString()
          .replaceAll('_', ' ');
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(action),
        ),
      ],
    );
  }
}

class _ModelProgress extends StatelessWidget {
  const _ModelProgress({
    required this.label,
    required this.status,
    required this.color,
    this.value,
  });

  final String label;
  final String status;
  final Color color;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              status,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.06),
            value: value,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Icon(icon, color: AppTheme.textMuted, size: 20),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.45), blurRadius: 8),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 24.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

String _formatInteger(dynamic value) {
  final number = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  final digits = number.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }

  return number < 0 ? '-$buffer' : buffer.toString();
}

String _formatCompact(dynamic value) {
  final number = value is num ? value.toDouble() : 0.0;
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(2)}M';
  }
  if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toStringAsFixed(0);
}

String _formatDecimal(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number?.toStringAsFixed(2) ?? '—';
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

Color _opportunityPriorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return AppTheme.red;
    case 'high':
      return AppTheme.amber;
    case 'medium':
      return AppTheme.cyan;
    default:
      return AppTheme.green;
  }
}
