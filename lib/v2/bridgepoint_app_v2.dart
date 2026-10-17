import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bridgepoint_integrations_hub_v790.dart';
import '../bridgepoint_intelligence_studio_v790.dart';
import '../screens/bridgepoint_owner_command_center.dart';
import '../bridgepoint_migration_notice_v5605.dart';
import 'bridgepoint_ai_v2.dart';
import 'bridgepoint_buildings_v2.dart';
import 'bridgepoint_calendar_v2.dart';
import 'bridgepoint_chrome_v2.dart';
import 'bridgepoint_claims_v2.dart';
import 'bridgepoint_global_search_v2.dart';
import 'bridgepoint_home_v2.dart';
import 'bridgepoint_intelligence_surfaces_v2.dart';
import 'bridgepoint_investment_valuation_v2.dart';
import 'bridgepoint_investor_v2.dart';
import 'bridgepoint_world_embed_v2.dart';
import 'bridgepoint_global_intelligence_v1.dart';
import 'bridgepoint_operations_workspace_v2.dart';
import 'bridgepoint_opportunities_v2.dart';
import 'bridgepoint_portfolio_risk_v2.dart';
import 'bridgepoint_products_settings_v2.dart';
import 'bridgepoint_properties_v2.dart';
import 'bridgepoint_property_360_v2.dart';
import 'bridgepoint_public_landing_v2.dart';
import 'bridgepoint_saved_alerts_v2.dart';
import 'settings/bridgepoint_account_support_v2.dart';

const _bridgePointLanguagesV2 = <(String, String)>[
  ('en', 'English'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('pt-BR', 'Português (Brasil)'),
  ('de', 'Deutsch'),
  ('it', 'Italiano'),
  ('nl', 'Nederlands'),
  ('pl', 'Polski'),
  ('ro', 'Română'),
  ('ru', 'Русский'),
  ('uk', 'Українська'),
  ('tr', 'Türkçe'),
  ('ar', 'العربية'),
  ('he', 'עברית'),
  ('hi', 'हिन्दी'),
  ('bn', 'বাংলা'),
  ('pa', 'ਪੰਜਾਬੀ'),
  ('ur', 'اردو'),
  ('zh-Hans', '简体中文'),
  ('zh-Hant', '繁體中文'),
  ('ja', '日本語'),
  ('ko', '한국어'),
  ('vi', 'Tiếng Việt'),
  ('id', 'Bahasa Indonesia'),
  ('tl', 'Filipino / Tagalog'),
  ('th', 'ไทย'),
  ('ht', 'Kreyòl ayisyen'),
];

const _bridgePointStatesV2 = <String>[
  'AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY'
];

String _bridgePointLanguageNameV2(String code) => _bridgePointLanguagesV2
    .where((item) => item.$1 == code)
    .map((item) => item.$2)
    .firstOrNull ??
    'English';

class BridgePointV2App extends StatelessWidget {
  const BridgePointV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: const _Root(),
    );
  }
}

ThemeData _theme() {
  const bg = Color(0xFF030811);
  const panel = Color(0xFF0A192A);
  const cyan = Color(0xFF48E1FF);
  const blue = Color(0xFF6C83FF);
  const gold = Color(0xFFFFC95E);
  const muted = Color(0xFFB5C6D9);
  const ink = Color(0xFFF5F8FC);
  final scheme = const ColorScheme.dark(primary: cyan,onPrimary: Color(0xFF021018),secondary: blue,onSecondary: Colors.white,tertiary: gold,onTertiary: Color(0xFF1A1200),surface: panel,onSurface: ink,error: Color(0xFFFF7474),onError: Color(0xFF250000));
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'BridgePointGrotesk');
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    textTheme: base.textTheme.apply(fontFamily: 'BridgePointGrotesk',bodyColor: ink,displayColor: Colors.white),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xF4071423),foregroundColor: Colors.white,surfaceTintColor: Colors.transparent,elevation: 0,titleTextStyle: TextStyle(fontFamily: 'BridgePointGrotesk',color: Colors.white,fontSize: 20,fontWeight: FontWeight.w900)),
    cardTheme: CardThemeData(color: panel,surfaceTintColor: Colors.transparent,margin: EdgeInsets.zero,elevation: 0,shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),side: BorderSide(color: cyan.withValues(alpha: .13)))),
    inputDecorationTheme: InputDecorationTheme(filled: true,fillColor: const Color(0xFF09192A),contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),borderSide: BorderSide(color: cyan.withValues(alpha: .12))),focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),borderSide: const BorderSide(color: cyan, width: 1.5)),hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 48),backgroundColor: cyan,foregroundColor: const Color(0xFF021018),textStyle: const TextStyle(fontFamily: 'BridgePointGrotesk', fontWeight: FontWeight.w900),shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48),foregroundColor: ink,side: BorderSide(color: blue.withValues(alpha: .55)),textStyle: const TextStyle(fontFamily: 'BridgePointGrotesk', fontWeight: FontWeight.w900),shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF071725),surfaceTintColor: Colors.transparent,dragHandleColor: blue,showDragHandle: true),
    navigationBarTheme: NavigationBarThemeData(height: 72,backgroundColor: const Color(0xF4071423),indicatorColor: blue.withValues(alpha: .22),labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontFamily: 'BridgePointGrotesk',color: states.contains(WidgetState.selected) ? Colors.white : muted,fontSize: 12,fontWeight: states.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w700))),
    navigationRailTheme: const NavigationRailThemeData(backgroundColor: Color(0xF4071423),indicatorColor: Color(0x336C83FF),selectedIconTheme: IconThemeData(color: cyan),unselectedIconTheme: IconThemeData(color: muted),selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),unselectedLabelTextStyle: TextStyle(color: muted, fontWeight: FontWeight.w700)),
  );
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool auth = false;
  String locale = 'en';

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .76,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
            children: [
              const Text(
                'Choose your language',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                '27 languages are available before you enter BridgePoint. Your account creation flow remembers this choice.',
                style: TextStyle(color: Color(0xFFB5C6D9)),
              ),
              const SizedBox(height: 12),
              for (final item in _bridgePointLanguagesV2)
                ListTile(
                  leading: Icon(
                    item.$1 == locale
                        ? Icons.check_circle_rounded
                        : Icons.language_rounded,
                    color: item.$1 == locale
                        ? const Color(0xFF48E1FF)
                        : const Color(0xFFB5C6D9),
                  ),
                  title: Text(item.$2),
                  subtitle: Text(item.$1),
                  onTap: () => Navigator.pop(context, item.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => locale = selected);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (Supabase.instance.client.auth.currentSession != null) {
            return const _Workspace();
          }
          if (auth) {
            return _AuthPage(
              onBack: () => setState(() => auth = false),
              initialLocale: locale,
              onLocaleChanged: (value) => setState(() => locale = value),
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: BridgePointPublicLandingV2(
                  onSignIn: () => setState(() => auth = true),
                ),
              ),
              Positioned(
                right: 12,
                top: MediaQuery.paddingOf(context).top + 10,
                child: Material(
                  color: const Color(0xE6071321),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _pickLanguage,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            color: Color(0xFF48E1FF),
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _bridgePointLanguageNameV2(locale),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({
    required this.onBack,
    required this.initialLocale,
    required this.onLocaleChanged,
  });
  final VoidCallback onBack;
  final String initialLocale;
  final ValueChanged<String> onLocaleChanged;
  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  bool showPassword = false;
  String? error;
  late String locale;
  String industry = 'Roofing';
  String role = 'Owner / Founder';
  String goal = 'Find the best opportunities';
  String stateCode = 'CT';
  String experience = 'Growing business';

  @override
  void initState() {
    super.initState();
    locale = widget.initialLocale;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || !email.text.contains('@')) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    if (password.text.length < 6) {
      setState(() => error = 'Use a password with at least 6 characters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (create) {
        await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {
            'preferred_locale': locale,
            'onboarding_version': 'clean_v2_v974',
            'industry': industry,
            'role': role,
            'primary_goal': goal,
            'primary_state': stateCode,
            'experience': experience,
          },
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthException
              ? e.message
              : 'BridgePoint could not sign in right now.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _drop(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: busy
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BridgePointMotionBackgroundV2(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: create ? 720 : 500,
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: const Color(0xEE0A192A),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x3348E1FF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x77000000),
                      blurRadius: 42,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const Center(child: BridgePointMarkV2(size: 68)),
                    const SizedBox(height: 13),
                    Text(
                      create ? 'Create your BridgePoint account' : 'BridgePoint Intelligence',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      create
                          ? 'Language and a few onboarding questions come first so your workspace starts in the right context.'
                          : 'Property intelligence, without the backend maze.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB5C6D9)),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: locale,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        prefixIcon: Icon(Icons.language_rounded),
                      ),
                      items: _bridgePointLanguagesV2
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.$1,
                              child: Text(item.$2),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => locale = value);
                              widget.onLocaleChanged(value);
                            },
                    ),
                    const SizedBox(height: 12),
                    if (create) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 570;
                          final fields = <Widget>[
                            _drop(
                              'Industry',
                              industry,
                              const [
                                'Roofing',
                                'Restoration / Mitigation',
                                'Public Adjusting',
                                'Insurance / Claims',
                                'Real Estate / Investing',
                                'Property Management',
                                'Homeowner',
                                'Other',
                              ],
                              (v) => setState(() => industry = v),
                            ),
                            _drop(
                              'Your role',
                              role,
                              const [
                                'Owner / Founder',
                                'Manager',
                                'Sales / Field',
                                'Adjuster / Claims',
                                'Analyst',
                                'Homeowner',
                                'Other',
                              ],
                              (v) => setState(() => role = v),
                            ),
                            _drop(
                              'Primary goal',
                              goal,
                              const [
                                'Find the best opportunities',
                                'Evaluate properties',
                                'Manage claims',
                                'Track risk',
                                'Build portfolio intelligence',
                                'Other',
                              ],
                              (v) => setState(() => goal = v),
                            ),
                            _drop(
                              'Primary state',
                              stateCode,
                              _bridgePointStatesV2,
                              (v) => setState(() => stateCode = v),
                            ),
                            _drop(
                              'Experience',
                              experience,
                              const [
                                'Just starting',
                                'Growing business',
                                'Established team',
                                'Enterprise / Carrier',
                              ],
                              (v) => setState(() => experience = v),
                            ),
                          ];
                          if (!wide) {
                            return Column(
                              children: [
                                for (var i = 0; i < fields.length; i++) ...[
                                  fields[i],
                                  if (i < fields.length - 1)
                                    const SizedBox(height: 10),
                                ],
                              ],
                            );
                          }
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final field in fields)
                                SizedBox(
                                  width: (constraints.maxWidth - 10) / 2,
                                  child: field,
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: !showPassword,
                      onSubmitted: (_) => busy ? null : submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => showPassword = !showPassword),
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFFF7E7E)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(create ? 'Create account' : 'Sign in'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => create = !create),
                      child: Text(
                        create
                            ? 'Already have an account? Sign in'
                            : 'New to BridgePoint? Create account',
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

enum _Area { home,map,globalIntelligence,properties,work,plans,search,opportunities,saved,claims,calendar,operations,portfolio,investor,property360,buildings,ai,integrations,account,sources,models,studio,worth,owner }

class _Workspace extends StatefulWidget { const _Workspace(); @override State<_Workspace> createState() => _WorkspaceState(); }
class _WorkspaceState extends State<_Workspace> {
  static const _gold = Color(0xFFFFC95E); static const _cyan = Color(0xFF48E1FF); static const _muted = Color(0xFFB5C6D9);
  _Area selected = _Area.home; bool owner = false; bool ownerChecked = false; String? searchSeed;
  static const primary = <_Area>[_Area.home, _Area.map, _Area.properties, _Area.work];
  @override void initState() { super.initState(); _checkOwner(); }
  Future<void> _checkOwner() async {try {await Supabase.instance.client.rpc('bridgepoint_owner_v2_requirements_v832', params: {'p_category': null, 'p_status': null, 'p_limit': 1}); owner = true;} catch (_) {owner = false;} if (mounted) setState(() => ownerChecked = true);}
  void open(_Area area) => setState(() => selected = area);
  Future<void> _search() async {final controller = TextEditingController();final result = await showDialog<String>(context: context,builder: (context) => AlertDialog(title: const Text('Search BridgePoint'),content: TextField(controller: controller,autofocus: true,textInputAction: TextInputAction.search,onSubmitted: (value) => Navigator.pop(context, value),decoration: const InputDecoration(labelText: 'Address, parcel, owner or municipality', prefixIcon: Icon(Icons.search_rounded))),actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Search'))]));controller.dispose();if (result != null && result.trim().length >= 2) setState(() {searchSeed = result.trim();selected = _Area.search;});}
  Widget _page() => switch (selected) {_Area.home => const BridgePointHomeV2(),_Area.map => const BridgePointWorldEmbedV2(),_Area.globalIntelligence => BridgePointGlobalIntelligenceV1(onOpenWorld: () => open(_Area.map)),_Area.properties => const BridgePointPropertiesV2(),_Area.work => _WorkHub(onOpen: open),_Area.plans => const BridgePointProductsSettingsV2(),_Area.search => BridgePointGlobalSearchV2(key: ValueKey(searchSeed), initialQuery: searchSeed),_Area.opportunities => const BridgePointOpportunitiesV2(),_Area.saved => const BridgePointSavedAlertsV2(),_Area.claims => const BridgePointClaimsV2(),_Area.calendar => const BridgePointCalendarV2(),_Area.operations => const BridgePointOperationsWorkspaceV2(),_Area.portfolio => const BridgePointPortfolioRiskV2(),_Area.investor => const BridgePointInvestorV2(),_Area.property360 => const BridgePointProperty360V2(),_Area.buildings => const BridgePointBuildingsV2(),_Area.ai => const BridgePointAiV2(),_Area.integrations => const BridgePointIntegrationsHub(),_Area.account => const BridgePointAccountSupportV2(),_Area.sources => const BridgePointSourcesV2(),_Area.models => const BridgePointModelsV2(),_Area.studio => BridgePointIntelligenceStudio(onNavigate: (_) => open(_Area.work), ownerMode: owner),_Area.worth => const BridgePointInvestmentValuationV2(),_Area.owner => const BridgePointOwnerCommandCenter()};
  String _title() => switch (selected) {_Area.home=>'BridgePoint Intelligence',_Area.map=>'BridgePoint World',_Area.globalIntelligence=>'Global Intelligence',_Area.properties=>'Properties',_Area.work=>'Work',_Area.plans=>'Plans & Access',_Area.search=>'Search',_Area.opportunities=>'Opportunities',_Area.saved=>'Saved & Alerts',_Area.claims=>'Claims',_Area.calendar=>'Calendar',_Area.operations=>'Operations',_Area.portfolio=>'Portfolio & Risk',_Area.investor=>'Investor Intelligence',_Area.property360=>'Property Intelligence',_Area.buildings=>'Buildings & Structure 3D',_Area.ai=>'Ask BridgePoint AI',_Area.integrations=>'Integrations',_Area.account=>'Account & Help',_Area.sources=>'Source Operations',_Area.models=>'Model Operations',_Area.studio=>'Intelligence Studio',_Area.worth=>'Owner Valuation',_Area.owner=>'Owner Control'};
  void _showExplore() {showModalBottomSheet<void>(context: context,isScrollControlled: true,builder: (context) => SafeArea(child: FractionallySizedBox(heightFactor: .86,child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),children: [const BridgePointBrandLockupV2(),const SizedBox(height: 12),_GoldAction(onTap: () {Navigator.pop(context);open(_Area.plans);}),const SizedBox(height: 14),_Group(title: 'Use BridgePoint',children: [_item(_Area.search,'Search','Address, parcel, owner or municipality',Icons.search_rounded),_item(_Area.ai,'Ask BridgePoint AI','Ask about property intelligence in plain English',Icons.auto_awesome_rounded),_item(_Area.investor,'Investor Intelligence','Ranked investor-oriented property context',Icons.real_estate_agent_outlined)]),_Group(title: 'Global data',children: [_item(_Area.globalIntelligence,'Global Intelligence','Public-source events, property coverage and infrastructure context',Icons.public_outlined)]),_Group(title: 'Property tools',children: [_item(_Area.property360,'Property Intelligence','Signals, evidence and property context',Icons.home_work_outlined),_item(_Area.buildings,'Buildings & Structure 3D','Geometry and physical-property intelligence',Icons.view_in_ar_outlined),_item(_Area.integrations,'Integrations','Connect supported data and workflows',Icons.cable_rounded)]),if (owner) _Group(title:'Owner only',accent:_gold,children:[_item(_Area.owner,'Owner Control','Parcel progress, automation, expansion and advanced diagnostics',Icons.admin_panel_settings_outlined),_item(_Area.worth,'Owner Valuation','Internal planning model — never shown to customers',Icons.show_chart_rounded),_item(_Area.sources,'Source Operations','Registry routing and source health',Icons.hub_outlined),_item(_Area.models,'Model Operations','Internal model controls',Icons.psychology_alt_outlined),_item(_Area.studio,'Intelligence Studio','Advanced capability workspace',Icons.schema_outlined)]),_Group(title:'Account',children:[_item(_Area.account,'Account / Billing / Help','Profile, billing and support',Icons.manage_accounts_outlined)]),const Divider(),ListTile(leading: const Icon(Icons.logout_rounded),title: const Text('Sign out'),onTap: () async {Navigator.pop(context);await Supabase.instance.client.auth.signOut();})]))));}
  Widget _item(_Area area,String title,String subtitle,IconData icon) => ListTile(leading: Icon(icon),title: Text(title),subtitle: Text(subtitle),trailing: const Icon(Icons.chevron_right_rounded),onTap: () {Navigator.pop(context);open(area);});
  @override Widget build(BuildContext context) {if (!ownerChecked) return const Scaffold(body: BridgePointMotionBackgroundV2(child: Center(child: CircularProgressIndicator())));final width=MediaQuery.sizeOf(context).width;final compact=width<820;final isWorld=selected==_Area.map;final content=isWorld?const BridgePointWorldEmbedV2():BridgePointMotionBackgroundV2(child:selected==_Area.owner?Padding(padding:const EdgeInsets.all(8),child:SizedBox.expand(child:_page())):SingleChildScrollView(padding:const EdgeInsets.all(16),child:_page()));final body=Column(children:[const BridgePointMigrationNoticeV5605(),Expanded(child:content)]);if(compact){final index=selected==_Area.plans?4:primary.contains(selected)?primary.indexOf(selected):3;return Scaffold(appBar:isWorld?null:_appBar(compact:true),body:body,bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>open(i==4?_Area.plans:primary[i]),destinations:const [NavigationDestination(icon:Icon(Icons.space_dashboard_outlined),selectedIcon:Icon(Icons.space_dashboard_rounded),label:'Home'),NavigationDestination(icon:Icon(Icons.public_outlined),selectedIcon:Icon(Icons.public_rounded),label:'Map'),NavigationDestination(icon:Icon(Icons.holiday_village_outlined),selectedIcon:Icon(Icons.holiday_village_rounded),label:'Properties'),NavigationDestination(icon:Icon(Icons.work_outline_rounded),selectedIcon:Icon(Icons.work_rounded),label:'Work'),NavigationDestination(icon:Icon(Icons.workspace_premium_outlined,color:_gold),selectedIcon:Icon(Icons.workspace_premium_rounded,color:_gold),label:'Plans')]));}final railAreas=<_Area>[...primary,_Area.plans];final railIndex=railAreas.contains(selected)?railAreas.indexOf(selected):3;return Scaffold(body:Row(children:[NavigationRail(extended:width>=1220,selectedIndex:railIndex,onDestinationSelected:(i)=>open(railAreas[i]),leading:Padding(padding:const EdgeInsets.symmetric(vertical:14),child:width>=1220?const BridgePointBrandLockupV2():const BridgePointMarkV2(size:42)),destinations:const [NavigationRailDestination(icon:Icon(Icons.space_dashboard_outlined),selectedIcon:Icon(Icons.space_dashboard_rounded),label:Text('Home')),NavigationRailDestination(icon:Icon(Icons.public_outlined),selectedIcon:Icon(Icons.public_rounded),label:Text('Map')),NavigationRailDestination(icon:Icon(Icons.holiday_village_outlined),selectedIcon:Icon(Icons.holiday_village_rounded),label:Text('Properties')),NavigationRailDestination(icon:Icon(Icons.work_outline_rounded),selectedIcon:Icon(Icons.work_rounded),label:Text('Work')),NavigationRailDestination(icon:Icon(Icons.workspace_premium_outlined,color:_gold),selectedIcon:Icon(Icons.workspace_premium_rounded,color:_gold),label:Text('Plans'))]),Expanded(child:isWorld?body:Column(children:[_appBar(compact:false),Expanded(child:body)]))]));}
  PreferredSizeWidget _appBar({required bool compact}) => AppBar(automaticallyImplyLeading:false,titleSpacing:compact?8:16,title:Row(children:[if(compact)...[const BridgePointMarkV2(size:31),const SizedBox(width:9)],Expanded(child:Text(_title(),maxLines:1,overflow:TextOverflow.ellipsis))]),actions:[IconButton(onPressed:_search,tooltip:'Search',icon:const Icon(Icons.search_rounded)),IconButton(onPressed:()=>open(_Area.saved),tooltip:'Saved & alerts',icon:const Icon(Icons.notifications_none_rounded)),if(!compact) Padding(padding:const EdgeInsets.symmetric(vertical:9,horizontal:4),child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_gold,foregroundColor:const Color(0xFF241700)),onPressed:()=>open(_Area.plans),icon:const Icon(Icons.workspace_premium_rounded),label:const Text('Plans'))),if(owner) IconButton(onPressed:()=>open(_Area.owner),tooltip:'Owner Control',icon:const Icon(Icons.shield_outlined,color:_cyan)),IconButton(onPressed:_showExplore,tooltip:'Explore BridgePoint',icon:const Icon(Icons.grid_view_rounded)),const SizedBox(width:4)]);
}

class _WorkHub extends StatelessWidget {const _WorkHub({required this.onOpen});final ValueChanged<_Area> onOpen;@override Widget build(BuildContext context){const items=[(_Area.opportunities,'Opportunities','Prioritized properties and why they matter',Icons.location_searching_rounded,Color(0xFF45E6A6)),(_Area.saved,'Saved & Alerts','Properties and follow-ups you want to keep',Icons.bookmark_added_outlined,Color(0xFF48E1FF)),(_Area.claims,'Claims','Property evidence and claim workflow',Icons.assignment_outlined,Color(0xFFFFC95E)),(_Area.calendar,'Calendar','Visits, follow-ups and field planning',Icons.calendar_month_outlined,Color(0xFF6C83FF)),(_Area.operations,'Operations','Team and field execution',Icons.track_changes_rounded,Color(0xFF48E1FF)),(_Area.portfolio,'Portfolio & Risk','Monitor groups of properties and exposure',Icons.account_tree_outlined,Color(0xFF45E6A6)),(_Area.investor,'Investor Intelligence','Investment-oriented ranking and context',Icons.real_estate_agent_outlined,Color(0xFFFFC95E))];return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('Work',style:TextStyle(fontSize:31,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Everything you do after BridgePoint finds the property lives here.',style:TextStyle(color:Color(0xFFB5C6D9),fontSize:14,height:1.4)),const SizedBox(height:16),LayoutBuilder(builder:(context,c){final columns=c.maxWidth>=900?3:c.maxWidth>=560?2:1;final width=(c.maxWidth-(columns-1)*10)/columns;return Wrap(spacing:10,runSpacing:10,children:[for(final item in items) SizedBox(width:width,child:InkWell(borderRadius:BorderRadius.circular(18),onTap:()=>onOpen(item.$1),child:Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:const Color(0xE60A192A),borderRadius:BorderRadius.circular(18),border:Border.all(color:item.$5.withValues(alpha:.18)),boxShadow:[BoxShadow(color:item.$5.withValues(alpha:.04),blurRadius:22)]),child:Row(children:[Container(width:45,height:45,decoration:BoxDecoration(color:item.$5.withValues(alpha:.12),borderRadius:BorderRadius.circular(13)),child:Icon(item.$4,color:item.$5)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.$2,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(item.$3,style:const TextStyle(color:Color(0xFFB5C6D9),fontSize:11.7,height:1.35))])),const Icon(Icons.chevron_right_rounded,color:Color(0xFF48E1FF))]))))]);})]);}}
class _Group extends StatelessWidget {const _Group({required this.title,required this.children,this.accent=const Color(0xFF48E1FF)});final String title;final List<Widget> children;final Color accent;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:Padding(padding:const EdgeInsets.fromLTRB(8,12,8,6),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Text(title.toUpperCase(),style:TextStyle(color:accent,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:.9))),const SizedBox(height:6),...children]))));}
class _GoldAction extends StatelessWidget {const _GoldAction({required this.onTap});final VoidCallback onTap;@override Widget build(BuildContext context)=>InkWell(borderRadius:BorderRadius.circular(17),onTap:onTap,child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF3A2A08),Color(0xFF201B16)]),borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xFFFFC95E),width:1.2),boxShadow:const [BoxShadow(color:Color(0x22FFC95E),blurRadius:24)]),child:const Row(children:[Icon(Icons.workspace_premium_rounded,color:Color(0xFFFFC95E),size:28),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Plans & access',style:TextStyle(color:Color(0xFFFFE6A1),fontSize:17,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('See customer-ready BridgePoint plans and start checkout.',style:TextStyle(color:Color(0xFFD8C58C),fontSize:12.2))])),Icon(Icons.arrow_forward_rounded,color:Color(0xFFFFC95E))])));}
