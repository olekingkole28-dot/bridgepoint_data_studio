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
import 'bridgepoint_global_search_v2.dart';
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

/// Recovery V3 deliberately limits permanent navigation to five entrances.
/// Deep capabilities remain available contextually through Work, Explore,
/// Search, AI, Account and the owner-only Engine.
class BridgePointRecoveryV3App extends StatelessWidget {
  const BridgePointRecoveryV3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: _recoveryTheme(),
      home: const _RecoveryRoot(),
    );
  }
}

ThemeData _recoveryTheme() {
  const bg = Color(0xFF040B14);
  const panel = Color(0xFF0D1F33);
  const cyan = Color(0xFF48E1FF);
  const blue = Color(0xFF6C83FF);
  const muted = Color(0xFFB7C7D8);

  final scheme = const ColorScheme.dark(
    primary: cyan,
    onPrimary: Color(0xFF021018),
    secondary: blue,
    onSecondary: Colors.white,
    surface: panel,
    onSurface: Colors.white,
    error: Color(0xFFFF7474),
    onError: Color(0xFF250000),
  );

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    cardColor: panel,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xED071422),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: const Color(0xF2071422),
      indicatorColor: blue.withValues(alpha: .22),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? cyan : muted,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected) ? Colors.white : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xF2071422),
      indicatorColor: blue.withValues(alpha: .22),
      selectedIconTheme: const IconThemeData(color: cyan),
      unselectedIconTheme: const IconThemeData(color: muted),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: muted,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A192A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan.withValues(alpha: .18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan.withValues(alpha: .16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cyan, width: 1.7),
      ),
    ),
    cardTheme: CardThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cyan.withValues(alpha: .12)),
      ),
    ),
    dividerTheme: DividerThemeData(color: cyan.withValues(alpha: .12)),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0A192A),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0A192A),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class _RecoveryRoot extends StatefulWidget {
  const _RecoveryRoot();

  @override
  State<_RecoveryRoot> createState() => _RecoveryRootState();
}

class _RecoveryRootState extends State<_RecoveryRoot> {
  bool showAuth = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (Supabase.instance.client.auth.currentSession != null) {
          return const _RecoveryWorkspace();
        }
        if (showAuth) {
          return _RecoveryAuth(onBack: () => setState(() => showAuth = false));
        }
        return BridgePointPublicLandingV2(
          onSignIn: () => setState(() => showAuth = true),
        );
      },
    );
  }
}

class _RecoveryAuth extends StatefulWidget {
  const _RecoveryAuth({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_RecoveryAuth> createState() => _RecoveryAuthState();
}

class _RecoveryAuthState extends State<_RecoveryAuth> {
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
      if (mounted) {
        setState(() => error = e is AuthException ? e.message : '$e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BridgePointMotionBackgroundV2(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(child: BridgePointBrandLockupV2()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        create ? 'Create your account' : 'Welcome back',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
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
                            onPressed: () => setState(
                              () => showPassword = !showPassword,
                            ),
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Color(0xFFFF7E7E))),
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
                        onPressed: busy ? null : () => setState(() => create = !create),
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
        ),
      ),
    );
  }
}

enum _Area {
  home,
  map,
  properties,
  opportunities,
  work,
  search,
  saved,
  calendar,
  operations,
  claims,
  portfolio,
  investor,
  investment,
  property360,
  signals,
  sources,
  models,
  buildings,
  studio,
  integrations,
  products,
  account,
  ai,
  owner,
}

class _AreaSpec {
  const _AreaSpec(this.area, this.label, this.icon, {this.detail});
  final _Area area;
  final String label;
  final IconData icon;
  final String? detail;
}

const _primary = <_AreaSpec>[
  _AreaSpec(_Area.home, 'Home', Icons.space_dashboard_rounded),
  _AreaSpec(_Area.map, 'Map', Icons.public_rounded),
  _AreaSpec(_Area.properties, 'Properties', Icons.holiday_village_rounded),
  _AreaSpec(_Area.opportunities, 'Opportunities', Icons.bolt_rounded),
  _AreaSpec(_Area.work, 'Work', Icons.workspaces_outline),
];

const _customerDeep = <_AreaSpec>[
  _AreaSpec(_Area.saved, 'Saved & Alerts', Icons.bookmark_added_outlined,
      detail: 'Watchlists, saved opportunities and notifications'),
  _AreaSpec(_Area.calendar, 'Calendar', Icons.calendar_month_rounded,
      detail: 'Follow-ups and scheduled work'),
  _AreaSpec(_Area.operations, 'Operations', Icons.track_changes_rounded,
      detail: 'Field and workflow operations'),
  _AreaSpec(_Area.claims, 'Claims', Icons.assignment_outlined,
      detail: 'Authorized claim workflow surfaces'),
  _AreaSpec(_Area.portfolio, 'Portfolio & Risk', Icons.account_tree_outlined,
      detail: 'Portfolio-level risk and intelligence'),
  _AreaSpec(_Area.investor, 'Property Investor', Icons.real_estate_agent_rounded,
      detail: 'Investor decision workflow'),
  _AreaSpec(_Area.property360, 'Property 360', Icons.home_work_rounded,
      detail: 'Timeline, evidence and property intelligence'),
  _AreaSpec(_Area.signals, 'Signals', Icons.radar_rounded,
      detail: 'Explainable underlying property signals'),
  _AreaSpec(_Area.sources, 'Sources & Freshness', Icons.hub_rounded,
      detail: 'Where information came from and how fresh it is'),
  _AreaSpec(_Area.models, 'Models & Patterns', Icons.psychology_alt_rounded,
      detail: 'Scoring, patterns and model context'),
  _AreaSpec(_Area.integrations, 'Integrations', Icons.cable_rounded,
      detail: 'Connect BridgePoint to external systems'),
  _AreaSpec(_Area.products, 'Packages & Settings', Icons.workspace_premium_outlined,
      detail: 'Plan, package and feature controls'),
  _AreaSpec(_Area.account, 'Account / Billing / Help', Icons.manage_accounts_outlined,
      detail: 'Account, billing, support and trust'),
];

class _RecoveryWorkspace extends StatefulWidget {
  const _RecoveryWorkspace();

  @override
  State<_RecoveryWorkspace> createState() => _RecoveryWorkspaceState();
}

class _RecoveryWorkspaceState extends State<_RecoveryWorkspace> {
  _Area selected = _Area.home;
  bool owner = false;
  bool ownerChecked = false;
  String? searchSeed;

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

  void open(_Area area) => setState(() => selected = area);

  Future<void> showSearch() async {
    final controller = TextEditingController(text: searchSeed ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search BridgePoint'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (text) => Navigator.pop(context, text),
          decoration: const InputDecoration(
            labelText: 'Address, parcel, owner or municipality',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, controller.text),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = value?.trim();
    if (clean != null && clean.isNotEmpty) {
      setState(() {
        searchSeed = clean;
        selected = _Area.search;
      });
    }
  }

  void showExplore() {
    final entries = <_AreaSpec>[
      ..._customerDeep,
      if (owner)
        const _AreaSpec(
          _Area.investment,
          'Investment / Worth',
          Icons.show_chart_rounded,
          detail: 'Owner valuation and investment view',
        ),
      if (owner)
        const _AreaSpec(
          _Area.buildings,
          'Buildings / Digital Twin',
          Icons.view_in_ar_rounded,
          detail: 'Physical geometry, 3D fidelity and twin evidence',
        ),
      if (owner)
        const _AreaSpec(
          _Area.studio,
          'Intelligence Studio',
          Icons.schema_rounded,
          detail: 'Deep intelligence engine surfaces',
        ),
      if (owner)
        const _AreaSpec(
          _Area.owner,
          'Owner Engine',
          Icons.admin_panel_settings_rounded,
          detail: 'Every backend system, completion gap and owner control',
        ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .88,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: Row(
                  children: [
                    Expanded(child: BridgePointBrandLockupV2()),
                    Text(
                      'Everything, without 20 tabs',
                      style: TextStyle(color: Color(0xFFB7C7D8)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
                  children: [
                    for (final spec in entries)
                      ListTile(
                        leading: Icon(spec.icon, color: const Color(0xFF48E1FF)),
                        title: Text(spec.label),
                        subtitle: spec.detail == null ? null : Text(spec.detail!),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          open(spec.area);
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
            ],
          ),
        ),
      ),
    );
  }

  void _studioNavigate(int oldIndex) {
    final target = switch (oldIndex) {
      1 => _Area.opportunities,
      3 => _Area.map,
      4 => _Area.property360,
      5 => _Area.signals,
      6 => _Area.sources,
      7 => _Area.operations,
      8 => _Area.sources,
      9 => _Area.map,
      11 => _Area.models,
      14 => _Area.integrations,
      _ => _Area.studio,
    };
    open(target);
  }

  Widget page() => switch (selected) {
        _Area.home => const BridgePointHomeV2(),
        _Area.map => const BridgePointMapWeatherV2(),
        _Area.properties => const BridgePointPropertiesV2(),
        _Area.opportunities => const BridgePointOpportunitiesV2(),
        _Area.work => _WorkHub(onOpen: open),
        _Area.search => BridgePointGlobalSearchV2(
            key: ValueKey(searchSeed),
            initialQuery: searchSeed,
          ),
        _Area.saved => const BridgePointSavedAlertsV2(),
        _Area.calendar => const BridgePointCalendarV2(),
        _Area.operations => const BridgePointOperationsWorkspaceV2(),
        _Area.claims => const BridgePointClaimsV2(),
        _Area.portfolio => const BridgePointPortfolioRiskV2(),
        _Area.investor => const BridgePointInvestorV2(),
        _Area.investment => const BridgePointInvestmentValuationV2(),
        _Area.property360 => const BridgePointProperty360V2(),
        _Area.signals => const BridgePointSignalsV2(),
        _Area.sources => const BridgePointSourcesV2(),
        _Area.models => const BridgePointModelsV2(),
        _Area.buildings => const BridgePointBuildingsV2(),
        _Area.studio => BridgePointIntelligenceStudio(
            onNavigate: _studioNavigate,
            ownerMode: owner,
          ),
        _Area.integrations => const BridgePointIntegrationsHub(),
        _Area.products => const BridgePointProductsSettingsV2(),
        _Area.account => const BridgePointAccountSupportV2(),
        _Area.ai => const BridgePointAiV2(),
        _Area.owner => const BridgePointOwnerCommandCenter(),
      };

  int get primaryIndex {
    final index = _primary.indexWhere((x) => x.area == selected);
    return index < 0 ? 0 : index;
  }

  String get title {
    for (final spec in [..._primary, ..._customerDeep]) {
      if (spec.area == selected) return spec.label;
    }
    return switch (selected) {
      _Area.search => 'Search',
      _Area.ai => 'Ask BridgePoint AI',
      _Area.owner => 'Owner Engine',
      _Area.buildings => 'Buildings / Digital Twin',
      _Area.investment => 'Investment / Worth',
      _Area.studio => 'Intelligence Studio',
      _ => 'BridgePoint Intelligence',
    };
  }

  PreferredSizeWidget _appBar() => AppBar(
        titleSpacing: 10,
        title: Row(
          children: [
            const BridgePointMarkV2(size: 30),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search everything',
            onPressed: showSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Ask BridgePoint AI',
            onPressed: () => open(_Area.ai),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          if (owner)
            IconButton(
              tooltip: 'Owner Engine',
              onPressed: () => open(_Area.owner),
              icon: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF48E1FF),
              ),
            ),
          IconButton(
            tooltip: 'Explore all capabilities',
            onPressed: showExplore,
            icon: const Icon(Icons.apps_rounded),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!ownerChecked) {
      return const Scaffold(
        body: BridgePointMotionBackgroundV2(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final compact = MediaQuery.sizeOf(context).width < 900;
    final body = BridgePointMotionBackgroundV2(
      child: SafeArea(
        top: false,
        child: KeyedSubtree(
          key: ValueKey(selected),
          child: page(),
        ),
      ),
    );

    if (compact) {
      return Scaffold(
        appBar: _appBar(),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: primaryIndex,
          onDestinationSelected: (index) => open(_primary[index].area),
          destinations: [
            for (final spec in _primary)
              NavigationDestination(icon: Icon(spec.icon), label: spec.label),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: primaryIndex,
            extended: MediaQuery.sizeOf(context).width >= 1280,
            onDestinationSelected: (index) => open(_primary[index].area),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: MediaQuery.sizeOf(context).width >= 1280
                  ? const BridgePointBrandLockupV2()
                  : const BridgePointMarkV2(size: 40),
            ),
            destinations: [
              for (final spec in _primary)
                NavigationRailDestination(
                  icon: Icon(spec.icon),
                  label: Text(spec.label),
                ),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _WorkHub extends StatelessWidget {
  const _WorkHub({required this.onOpen});
  final ValueChanged<_Area> onOpen;

  @override
  Widget build(BuildContext context) {
    const cards = <_AreaSpec>[
      _AreaSpec(_Area.saved, 'Saved & Alerts', Icons.bookmark_added_outlined,
          detail: 'Everything you saved, watchlists, alerts and notifications.'),
      _AreaSpec(_Area.calendar, 'Calendar', Icons.calendar_month_rounded,
          detail: 'Follow-ups, visits and scheduled work.'),
      _AreaSpec(_Area.operations, 'Operations', Icons.track_changes_rounded,
          detail: 'Field work, assignments and operational tracking.'),
      _AreaSpec(_Area.claims, 'Claims', Icons.assignment_outlined,
          detail: 'Authorized claim workflows and evidence.'),
      _AreaSpec(_Area.portfolio, 'Portfolio & Risk', Icons.account_tree_outlined,
          detail: 'See many properties together instead of one at a time.'),
      _AreaSpec(_Area.investor, 'Investor Workspace', Icons.real_estate_agent_rounded,
          detail: 'Investment-focused property workflow.'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
      children: [
        Text(
          'Your work, in one place',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Saved properties, alerts, follow-ups, claims and portfolio work live here instead of becoming separate permanent tabs.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFB7C7D8),
              ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 3
                : constraints.maxWidth >= 650
                    ? 2
                    : 1;
            final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final spec in cards)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onOpen(spec.area),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(spec.icon, color: const Color(0xFF48E1FF), size: 30),
                              const SizedBox(height: 14),
                              Text(
                                spec.label,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                spec.detail ?? '',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFFB7C7D8),
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
        ),
      ],
    );
  }
}
