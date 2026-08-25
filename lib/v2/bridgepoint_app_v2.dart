import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bridgepoint_integrations_hub_v790.dart';
import '../bridgepoint_intelligence_studio_v790.dart';
import '../screens/bridgepoint_owner_command_center.dart';
import 'bridgepoint_ai_v2.dart';
import 'bridgepoint_buildings_v2.dart';
import 'bridgepoint_calendar_v2.dart';
import 'bridgepoint_chrome_v2.dart';
import 'bridgepoint_claims_v2.dart';
import 'bridgepoint_home_v2.dart';
import 'bridgepoint_intelligence_surfaces_v2.dart';
import 'bridgepoint_investment_valuation_v2.dart';
import 'bridgepoint_investor_v2.dart';
import 'bridgepoint_map_weather_v2.dart';
import 'bridgepoint_operations_workspace_v2.dart';
import 'bridgepoint_opportunities_v2.dart';
import 'bridgepoint_portfolio_risk_v2.dart';
import 'bridgepoint_products_settings_v2.dart';
import 'bridgepoint_properties_v2.dart';
import 'bridgepoint_property_360_v2.dart';
import 'bridgepoint_public_landing_v2.dart';
import 'bridgepoint_saved_alerts_v2.dart';
import 'settings/bridgepoint_account_support_v2.dart';

class BridgePointV2App extends StatelessWidget {
  const BridgePointV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: const _BridgePointRoot(),
    );
  }
}

ThemeData _theme() {
  const bg = Color(0xFF06111E);
  const panel = Color(0xFF0D1A2B);
  const cyan = Color(0xFF35D2E8);
  final scheme = ColorScheme.fromSeed(
    seedColor: cyan,
    brightness: Brightness.dark,
    surface: panel,
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    cardTheme: const CardThemeData(color: panel, margin: EdgeInsets.zero),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A1727),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 68,
      backgroundColor: Color(0xFF091727),
      indicatorColor: Color(0x2235D2E8),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF091727),
      indicatorColor: Color(0x2235D2E8),
      selectedIconTheme: IconThemeData(color: cyan),
    ),
    useMaterial3: true,
  );
}

class _BridgePointRoot extends StatefulWidget {
  const _BridgePointRoot();

  @override
  State<_BridgePointRoot> createState() => _BridgePointRootState();
}

class _BridgePointRootState extends State<_BridgePointRoot> {
  bool _showAuth = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) return const _WorkspaceV2();
        if (_showAuth) {
          return _AuthPageV2(onBack: () => setState(() => _showAuth = false));
        }
        return BridgePointPublicLandingV2(
          onSignIn: () => setState(() => _showAuth = true),
        );
      },
    );
  }
}

class _AuthPageV2 extends StatefulWidget {
  const _AuthPageV2({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_AuthPageV2> createState() => _AuthPageV2State();
}

class _AuthPageV2State extends State<_AuthPageV2> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  bool showPassword = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (create) {
        await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BridgePointMotionBackgroundV2(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 470,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xED0D1A2B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x3335D2E8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 32,
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
                      tooltip: 'Back to public site',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const Center(child: BridgePointMarkV2(size: 66)),
                  const SizedBox(height: 14),
                  const Text(
                    'BridgePoint Intelligence',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Property intelligence operating system',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8FA5BF)),
                  ),
                  const SizedBox(height: 24),
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
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(create ? 'Create account' : 'Sign in'),
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
}

enum _AreaV2 {
  home,
  map,
  properties,
  opportunities,
  investment,
  investor,
  property,
  signals,
  sources,
  models,
  savedAlerts,
  buildings,
  operations,
  claims,
  calendar,
  portfolio,
  ai,
  studio,
  integrations,
  products,
  accountSupport,
  owner,
}

class _AreaSpecV2 {
  const _AreaSpecV2(this.area, this.label, this.icon);
  final _AreaV2 area;
  final String label;
  final IconData icon;
}

const _baseAreasV2 = <_AreaSpecV2>[
  _AreaSpecV2(_AreaV2.home, 'Home', Icons.space_dashboard_rounded),
  _AreaSpecV2(_AreaV2.map, 'Map & Weather', Icons.public_rounded),
  _AreaSpecV2(_AreaV2.properties, 'Properties', Icons.holiday_village_rounded),
  _AreaSpecV2(_AreaV2.opportunities, 'Opportunities', Icons.bolt_rounded),
  _AreaSpecV2(_AreaV2.investor, 'Property Investor', Icons.real_estate_agent_rounded),
  _AreaSpecV2(_AreaV2.property, 'Property 360', Icons.home_work_rounded),
  _AreaSpecV2(_AreaV2.signals, 'Signals', Icons.radar_rounded),
  _AreaSpecV2(_AreaV2.sources, 'Sources', Icons.hub_rounded),
  _AreaSpecV2(_AreaV2.models, 'Models', Icons.psychology_alt_rounded),
  _AreaSpecV2(_AreaV2.savedAlerts, 'Saved & Alerts', Icons.bookmark_added_outlined),
  _AreaSpecV2(_AreaV2.operations, 'Operations', Icons.track_changes_rounded),
  _AreaSpecV2(_AreaV2.claims, 'Claims', Icons.assignment_outlined),
  _AreaSpecV2(_AreaV2.calendar, 'Calendar', Icons.calendar_month_rounded),
  _AreaSpecV2(_AreaV2.portfolio, 'Portfolio & Risk', Icons.account_tree_outlined),
  _AreaSpecV2(_AreaV2.ai, 'Ask BridgePoint AI', Icons.auto_awesome_rounded),
  _AreaSpecV2(_AreaV2.studio, 'Intelligence Studio', Icons.schema_rounded),
  _AreaSpecV2(_AreaV2.integrations, 'Integrations', Icons.cable_rounded),
  _AreaSpecV2(
    _AreaV2.products,
    'Products & Settings',
    Icons.workspace_premium_outlined,
  ),
  _AreaSpecV2(
    _AreaV2.accountSupport,
    'Account / Billing / Help',
    Icons.manage_accounts_outlined,
  ),
];

class _WorkspaceV2 extends StatefulWidget {
  const _WorkspaceV2();

  @override
  State<_WorkspaceV2> createState() => _WorkspaceV2State();
}

class _WorkspaceV2State extends State<_WorkspaceV2> {
  _AreaV2 selected = _AreaV2.home;
  bool owner = false;
  bool ownerChecked = false;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_owner_v2_requirements_v832',
        params: {'p_category': null, 'p_status': null, 'p_limit': 1},
      );
      owner = true;
    } catch (_) {
      owner = false;
    }
    if (mounted) setState(() => ownerChecked = true);
  }

  List<_AreaSpecV2> get areas => [
        ..._baseAreasV2,
        if (owner)
          const _AreaSpecV2(
            _AreaV2.investment,
            'Investment / Worth',
            Icons.show_chart_rounded,
          ),
        if (owner)
          const _AreaSpecV2(
            _AreaV2.buildings,
            'Buildings / Twin',
            Icons.view_in_ar_rounded,
          ),
        if (owner)
          const _AreaSpecV2(
            _AreaV2.owner,
            'Owner Backend',
            Icons.admin_panel_settings_rounded,
          ),
      ];

  List<_AreaV2> get _primary => [
        _AreaV2.home,
        _AreaV2.map,
        _AreaV2.properties,
        owner ? _AreaV2.investment : _AreaV2.investor,
      ];

  void _navigateFromStudio(int oldIndex) {
    final target = switch (oldIndex) {
      1 || 4 || 8 => _AreaV2.property,
      3 => _AreaV2.map,
      5 => _AreaV2.sources,
      6 => _AreaV2.products,
      7 => _AreaV2.models,
      14 => _AreaV2.integrations,
      _ => _AreaV2.studio,
    };
    setState(() => selected = target);
  }

  Widget _page() => switch (selected) {
        _AreaV2.home => const BridgePointHomeV2(),
        _AreaV2.map => const BridgePointMapWeatherV2(),
        _AreaV2.properties => const BridgePointPropertiesV2(),
        _AreaV2.opportunities => const BridgePointOpportunitiesV2(),
        _AreaV2.investment => const BridgePointInvestmentValuationV2(),
        _AreaV2.investor => const BridgePointInvestorV2(),
        _AreaV2.property => const BridgePointProperty360V2(),
        _AreaV2.signals => const BridgePointSignalsV2(),
        _AreaV2.sources => const BridgePointSourcesV2(),
        _AreaV2.models => const BridgePointModelsV2(),
        _AreaV2.savedAlerts => const BridgePointSavedAlertsV2(),
        _AreaV2.buildings => const BridgePointBuildingsV2(),
        _AreaV2.operations => const BridgePointOperationsWorkspaceV2(),
        _AreaV2.claims => const BridgePointClaimsV2(),
        _AreaV2.calendar => const BridgePointCalendarV2(),
        _AreaV2.portfolio => const BridgePointPortfolioRiskV2(),
        _AreaV2.ai => const BridgePointAiV2(),
        _AreaV2.studio => BridgePointIntelligenceStudio(
            onNavigate: _navigateFromStudio,
            ownerMode: owner,
          ),
        _AreaV2.integrations => const BridgePointIntegrationsHub(),
        _AreaV2.products => const BridgePointProductsSettingsV2(),
        _AreaV2.accountSupport => const BridgePointAccountSupportV2(),
        _AreaV2.owner => const BridgePointOwnerCommandCenter(),
      };

  bool get _bounded => selected == _AreaV2.owner;

  void _showMore() {
    final primary = _primary;
    final more = areas.where((x) => !primary.contains(x.area));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .86,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: BridgePointBrandLockupV2(),
              ),
              for (final spec in more)
                ListTile(
                  leading: Icon(spec.icon),
                  title: Text(spec.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => selected = spec.area);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ownerChecked) {
      return const Scaffold(
        body: BridgePointMotionBackgroundV2(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 820;

    if (compact) {
      final primary = _primary;
      final current = primary.contains(selected) ? primary.indexOf(selected) : 4;
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          title: Row(
            children: [
              const BridgePointMarkV2(size: 32),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _title(selected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (owner)
              IconButton(
                tooltip: 'Owner Backend',
                onPressed: () => setState(() => selected = _AreaV2.owner),
                icon: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF35D2E8),
                ),
              ),
            IconButton(
              tooltip: 'Ask BridgePoint AI',
              onPressed: () => setState(() => selected = _AreaV2.ai),
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
          ],
        ),
        body: _PageFrameV2(scroll: !_bounded, child: _page()),
        bottomNavigationBar: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: (index) {
            if (index == 4) {
              _showMore();
            } else {
              setState(() => selected = primary[index]);
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.public_rounded),
              label: 'Map',
            ),
            const NavigationDestination(
              icon: Icon(Icons.holiday_village_rounded),
              label: 'Properties',
            ),
            NavigationDestination(
              icon: Icon(
                owner ? Icons.show_chart_rounded : Icons.real_estate_agent_rounded,
              ),
              label: owner ? 'Worth' : 'Investor',
            ),
            const NavigationDestination(
              icon: Icon(Icons.apps_rounded),
              label: 'More',
            ),
          ],
        ),
      );
    }

    final specs = areas;
    final selectedIndex = specs.indexWhere((x) => x.area == selected);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: width >= 1280,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selected = specs[index].area),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: width >= 1280
                  ? const BridgePointBrandLockupV2()
                  : const BridgePointMarkV2(size: 42),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: IconButton(
                    tooltip: 'Sign out',
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final spec in specs)
                NavigationRailDestination(
                  icon: Icon(spec.icon),
                  label: Text(spec.label),
                ),
            ],
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: Color(0xE8091727),
                    border: Border(
                      bottom: BorderSide(color: Color(0x2235D2E8)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const BridgePointMarkV2(size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(selected),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'BRIDGEPOINT INTELLIGENCE',
                              style: TextStyle(
                                color: Color(0xFF35D2E8),
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (owner)
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => selected = _AreaV2.investment),
                          icon: const Icon(
                            Icons.show_chart_rounded,
                            color: Color(0xFF38D49A),
                          ),
                          label: const Text('Worth'),
                        ),
                      if (owner)
                        TextButton.icon(
                          onPressed: () => setState(() => selected = _AreaV2.owner),
                          icon: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFF35D2E8),
                          ),
                          label: const Text('Owner Backend'),
                        ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => setState(() => selected = _AreaV2.ai),
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF35D2E8),
                        ),
                        label: const Text('Ask AI'),
                      ),
                      const SizedBox(width: 6),
                      const _LiveBadgeV2(),
                    ],
                  ),
                ),
                Expanded(
                  child: _PageFrameV2(scroll: !_bounded, child: _page()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _title(_AreaV2 area) => switch (area) {
      _AreaV2.home => 'BridgePoint Intelligence',
      _AreaV2.map => 'Geospatial Intelligence',
      _AreaV2.properties => 'Properties',
      _AreaV2.opportunities => 'Opportunities',
      _AreaV2.investment => 'Investment / BridgePoint Worth',
      _AreaV2.investor => 'Property Investor',
      _AreaV2.property => 'Property 360',
      _AreaV2.signals => 'Signals',
      _AreaV2.sources => 'Sources',
      _AreaV2.models => 'Models',
      _AreaV2.savedAlerts => 'Saved & Alerts',
      _AreaV2.buildings => 'Buildings & Digital Twin',
      _AreaV2.operations => 'Operations Workspace',
      _AreaV2.claims => 'Claims Workspace',
      _AreaV2.calendar => 'Calendar & Day Plan',
      _AreaV2.portfolio => 'Portfolio & Risk',
      _AreaV2.ai => 'Ask BridgePoint AI',
      _AreaV2.studio => 'Intelligence Studio',
      _AreaV2.integrations => 'Integrations & Data Exchange',
      _AreaV2.products => 'Products & Settings',
      _AreaV2.accountSupport => 'Account, Billing & Help',
      _AreaV2.owner => 'Owner Backend',
    };

class _PageFrameV2 extends StatelessWidget {
  const _PageFrameV2({required this.child, this.scroll = true});
  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = scroll
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: child,
          )
        : Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox.expand(child: child),
          );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.45,
          colors: [Color(0x1835D2E8), Color(0xFF06111E)],
        ),
      ),
      child: BridgePointMotionBackgroundV2(child: content),
    );
  }
}

class _LiveBadgeV2 extends StatelessWidget {
  const _LiveBadgeV2();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF38D49A).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF38D49A).withValues(alpha: .2),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF38D49A)),
          SizedBox(width: 6),
          Text(
            'LIVE BACKEND',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
