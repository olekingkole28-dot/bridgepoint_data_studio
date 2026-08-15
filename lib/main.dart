Warning: truncated output (original token count: 71391)
Total output lines: 7756

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
      return const DashboardScreen();
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
  final email=TextEditingController(); final password=TextEditingController();
  bool create=false,loading=false; String? error;
  Future<void> submit() async {
    setState(()=>loading=true); error=null;
    try {
      if(create) {
        final response=await Supabase.instance.client.auth.signUp(email:email.text.trim(),password:password.text);
        if(response.session==null&&mounted) setState(()=>error='Check your email to confirm the account, then sign in.');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
    } catch(e) { if(mounted) setState(()=>error=e.toString()); }
    finally { if(mounted) setState(()=>loading=false); }
  }
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:_ExperienceBackground(child:Center(child:SingleChildScrollView(child:Card(child:Container(
    width:430,padding:const EdgeInsets.all(30),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Icon(Icons.hub_rounded,color:AppTheme.cyan,size:48),const SizedBox(height:14),
      const Text('BRIDGEPOINT INTELLIGENCE',textAlign:TextAlign.center,style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,letterSpacing:1)),
      const SizedBox(height:8),Text(create?'Create your 7-day trial':'Sign in to live property intelligence',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textMuted)),
      const SizedBox(height:24),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),
      const SizedBox(height:12),TextField(controller:password,obscureText:true,onSubmitted:(_)=>submit(),decoration:const InputDecoration(labelText:'Password',border:OutlineInputBorder())),
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
  const DashboardScreen({super.key});

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
  int _liveRefreshTick = 0;
  int _refreshSeconds = 120;

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
    _NavigationItem('Overview', Icons.grid_view_rounded),
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
    dashboardRequest = _loadDashboard();
    sourcesRequest = _loadSources();
    settingsRequest = _loadRuntimeSettings();
    healthRequest = _loadSystemHealth();
    _scheduleLiveRefresh(_refreshSeconds);
    _configureFromServer();
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
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
    _liveRefreshTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => _refreshLiveWorkspace(),
    );
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
        return _OverviewContent(
          selectedPackage: selectedPackage,
          dashboardRequest: dashboardRequest,
          sourcesRequest: sourcesRequest,
          onRefresh: _refreshDashboard,
          onNavigate: _navigateTo,
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
      default:
        return _ComingSoonPage(
          title: navigationItems[selectedNavigation].label,
          icon: navigationItems[selectedNavigation].icon,
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
                    items: navigationItems,
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
                        onNotifications: () => _showInfoDialog(
                          context,
                          'Notifications',
                          'Live alerts and notification history will appear here as your account workflow is activated.',
                        ),
                      ),
                      if (!desktop)
                        _CompactNavigation(
                          items: navigationItems,
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
                    const SizedBox(width: 8),…31391 tokens truncated…d(
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
                  const Text(
                    'Why BridgePoint surfaced this property',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    explanation,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Recommended action',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (opportunity['recommended_action'] ??
                            'Continue monitoring')
                        .toString(),
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
          ])),
        ])))),
        SizedBox(width:width,child:Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _PanelHeader(title:'Notes & Calendar',subtitle:'Preset actions and scheduled follow-ups',action:'Next action'),const SizedBox(height:12),
          if(notes.isEmpty)const SizedBox(height:180,child:Center(child:Text('Customer notes and follow-ups will appear here.',style:TextStyle(color:AppTheme.textMuted))))
          else ...notes.map((item)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppTheme.panelSoft.withOpacity(.5),borderRadius:BorderRadius.circular(12)),child:Row(children:[
            Container(width:38,height:38,decoration:BoxDecoration(color:AppTheme.amber.withOpacity(.1),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.event_note_rounded,color:AppTheme.amber,size:19)),
            const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item['preset_key']?.toString().replaceAll('_',' ')??'NOTE',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:AppTheme.cyan)),const SizedBox(height:4),Text(item['note_text']?.toString()??'',style:const TextStyle(fontSize:11,height:1.4))])),
            Text(item['follow_up_at']==null?'UNSCHEDULED':item['follow_up_at'].toString().substring(0,10),style:const TextStyle(color:AppTheme.textMuted,fontSize:9,fontWeight:FontWeight.w700)),
          ])),
        ])))),
      ]);}),
    ]);
  });
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
    required this.settingsRequest,
    required this.healthRequest,
    required this.refreshSeconds,
    required this.onRefreshSecondsChanged,
    required this.onRefresh,
  });

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

  if (explicit == 'flood' || category.contains('FLOOD')) {
    return Icons.flood_outlined;
  }
  if (explicit == 'grid' || category.contains('GRID')) {
    return Icons.electric_bolt_outlined;
  }
  if (explicit == 'transition' || category.contains('TRANSITION')) {
    return Icons.swap_horiz_rounded;
  }
  if (category.contains('FIRE')) {
    return Icons.local_fire_department_outlined;
  }
  if (category.contains('WEATHER') || category.contains('STORM')) {
    return Icons.thunderstorm_outlined;
  }
  return Icons.hub_outlined;
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
