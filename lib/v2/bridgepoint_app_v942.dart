import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bridgepoint_integrations_hub_v790.dart';
import '../bridgepoint_intelligence_studio_v790.dart';
import '../screens/bridgepoint_owner_command_center_v942.dart';
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
import 'bridgepoint_map_v942.dart';
import 'bridgepoint_opportunities_v2.dart';
import 'bridgepoint_plans_v942.dart';
import 'bridgepoint_portfolio_risk_v2.dart';
import 'bridgepoint_properties_v2.dart';
import 'bridgepoint_public_landing_v2.dart';
import 'bridgepoint_saved_alerts_v2.dart';
import 'settings/bridgepoint_account_support_v2.dart';

class BridgePointV942App extends StatelessWidget {
  const BridgePointV942App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: const _RootV942(),
    );
  }
}

ThemeData _theme() {
  const cyan = Color(0xFF48E1FF);
  const blue = Color(0xFF6C83FF);
  const gold = Color(0xFFFFC95E);
  const panel = Color(0xFF0D1B2C);
  const muted = Color(0xFFB5C6D9);
  const ink = Color(0xFFF5F8FC);

  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final text = base.textTheme.apply(
    fontFamily: 'BridgePointGrotesk',
    bodyColor: ink,
    displayColor: Colors.white,
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF02060D),
    canvasColor: const Color(0xFF06101C),
    colorScheme: const ColorScheme.dark(
      primary: cyan,
      onPrimary: Color(0xFF021018),
      secondary: blue,
      onSecondary: Colors.white,
      tertiary: gold,
      onTertiary: Color(0xFF1A1200),
      surface: panel,
      onSurface: ink,
      error: Color(0xFFFF7474),
      onError: Color(0xFF250000),
    ),
    fontFamily: 'BridgePointGrotesk',
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.5),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.48, fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.44, fontWeight: FontWeight.w600),
      bodySmall: text.bodySmall?.copyWith(color: muted, height: 1.4),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w900),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF505111F),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontFamily: 'BridgePointGrotesk', fontSize: 19, fontWeight: FontWeight.w900),
    ),
    cardTheme: CardThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cyan.withValues(alpha: .12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A1828),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cyan.withValues(alpha: .13))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cyan, width: 1.5)),
      labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: muted.withValues(alpha: .78)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cyan,
        foregroundColor: const Color(0xFF021018),
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontFamily: 'BridgePointGrotesk', fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: blue.withValues(alpha: .5)),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'BridgePointGrotesk', fontWeight: FontWeight.w900),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF10243A),
      selectedColor: blue.withValues(alpha: .20),
      side: BorderSide(color: cyan.withValues(alpha: .15)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: const Color(0xFA061321),
      indicatorColor: blue.withValues(alpha: .20),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? cyan : muted,
        size: states.contains(WidgetState.selected) ? 25 : 22,
      )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        color: states.contains(WidgetState.selected) ? Colors.white : muted,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w700,
        fontSize: 11.5,
      )),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFA061321),
      indicatorColor: Color(0x332A49FF),
      selectedIconTheme: IconThemeData(color: cyan, size: 25),
      unselectedIconTheme: IconThemeData(color: muted, size: 22),
      selectedLabelTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      unselectedLabelTextStyle: TextStyle(color: muted, fontWeight: FontWeight.w700),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF081728),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: blue,
    ),
  );
}

class _RootV942 extends StatefulWidget {
  const _RootV942();

  @override
  State<_RootV942> createState() => _RootV942State();
}

class _RootV942State extends State<_RootV942> {
  bool showAuth = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        if (Supabase.instance.client.auth.currentSession != null) return const _WorkspaceV942();
        if (showAuth) return _AuthV942(onBack: () => setState(() => showAuth = false));
        return BridgePointPublicLandingV2(onSignIn: () => setState(() => showAuth = true));
      },
    );
  }
}

class _AuthV942 extends StatefulWidget {
  const _AuthV942({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_AuthV942> createState() => _AuthV942State();
}

class _AuthV942State extends State<_AuthV942> {
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
        await Supabase.instance.client.auth.signUp(email: email.text.trim(), password: password.text);
      } else {
        await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } catch (e) {
      if (mounted) setState(() => error = e is AuthException ? e.message : 'BridgePoint could not complete sign in right now.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BridgePointMotionBackgroundV2(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Container(
                width: 460,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xF20A1726),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x3348E1FF)),
                  boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 36, offset: Offset(0, 18))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded))),
                  const Center(child: BridgePointMarkV2(size: 68)),
                  const SizedBox(height: 13),
                  const Text('BridgePoint Intelligence', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 22),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded))),
                  const SizedBox(height: 11),
                  TextField(
                    controller: password,
                    obscureText: !showPassword,
                    onSubmitted: (_) => busy ? null : submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded)),
                    ),
                  ),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 9), child: Text(error!, style: const TextStyle(color: Color(0xFFFF7474)))),
                  const SizedBox(height: 17),
                  FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(create ? 'Create account' : 'Sign in')),
                  TextButton(onPressed: busy ? null : () => setState(() => create = !create), child: Text(create ? 'Already have an account? Sign in' : 'New to BridgePoint? Create account')),
                ]),
              ),
            ),
          ),
        ),
      );
}

enum _AreaV942 {
  home,
  map,
  properties,
  work,
  plans,
  search,
  opportunities,
  saved,
  claims,
  calendar,
  portfolio,
  investor,
  ai,
  account,
  integrations,
  worth,
  buildings,
  owner,
  sources,
  models,
  studio,
}

class _WorkspaceV942 extends StatefulWidget {
  const _WorkspaceV942();

  @override
  State<_WorkspaceV942> createState() => _WorkspaceV942State();
}

class _WorkspaceV942State extends State<_WorkspaceV942> {
  static const _gold = Color(0xFFFFC95E);
  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);

  _AreaV942 selected = _AreaV942.home;
  bool owner = false;
  bool ownerChecked = false;
  String? searchSeed;

  static const primary = <_AreaV942>[
    _AreaV942.home,
    _AreaV942.map,
    _AreaV942.properties,
    _AreaV942.work,
    _AreaV942.plans,
  ];

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    try {
      await Supabase.instance.client.rpc('bridgepoint_owner_v2_requirements_v832', params: {'p_category': null, 'p_status': null, 'p_limit': 1});
      owner = true;
    } catch (_) {
      owner = false;
    }
    if (mounted) setState(() => ownerChecked = true);
  }

  void go(_AreaV942 area) => setState(() => selected = area);

  Future<void> search() async {
    final controller = TextEditingController(text: searchSeed ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search BridgePoint'),
        content: TextField(controller: controller, autofocus: true, textInputAction: TextInputAction.search, onSubmitted: (v) => Navigator.pop(context, v), decoration: const InputDecoration(labelText: 'Address, parcel, owner or municipality', prefixIcon: Icon(Icons.search_rounded))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Search')),
        ],
      ),
    );
    controller.dispose();
    final clean = value?.trim();
    if (clean != null && clean.length >= 2) {
      setState(() {
        searchSeed = clean;
        selected = _AreaV942.search;
      });
    }
  }

  String title(_AreaV942 area) => switch (area) {
        _AreaV942.home => 'BridgePoint Intelligence',
        _AreaV942.map => 'Intelligence Map',
        _AreaV942.properties => 'Properties',
        _AreaV942.work => 'Work',
        _AreaV942.plans => 'Plans & Upgrade',
        _AreaV942.search => 'Search',
        _AreaV942.opportunities => 'Opportunities',
        _AreaV942.saved => 'Saved & Alerts',
        _AreaV942.claims => 'Claims',
        _AreaV942.calendar => 'Calendar',
        _AreaV942.portfolio => 'Portfolio & Risk',
        _AreaV942.investor => 'Investor',
        _AreaV942.ai => 'Ask BridgePoint AI',
        _AreaV942.account => 'Account / Billing / Help',
        _AreaV942.integrations => 'Integrations',
        _AreaV942.worth => 'BridgePoint Worth',
        _AreaV942.buildings => 'Buildings & Twin',
        _AreaV942.owner => 'Owner Control',
        _AreaV942.sources => 'Source Diagnostics',
        _AreaV942.models => 'Model Diagnostics',
        _AreaV942.studio => 'Intelligence Studio',
      };

  Widget page() => switch (selected) {
        _AreaV942.home => const BridgePointHomeV2(),
        _AreaV942.map => const BridgePointMapV942(),
        _AreaV942.properties => const BridgePointPropertiesV2(),
        _AreaV942.work => _WorkHubV942(go: go),
        _AreaV942.plans => const BridgePointPlansV942(),
        _AreaV942.search => BridgePointGlobalSearchV2(key: ValueKey(searchSeed), initialQuery: searchSeed),
        _AreaV942.opportunities => const BridgePointOpportunitiesV2(),
        _AreaV942.saved => const BridgePointSavedAlertsV2(),
        _AreaV942.claims => const BridgePointClaimsV2(),
        _AreaV942.calendar => const BridgePointCalendarV2(),
        _AreaV942.portfolio => const BridgePointPortfolioRiskV2(),
        _AreaV942.investor => const BridgePointInvestorV2(),
        _AreaV942.ai => const BridgePointAiV2(),
        _AreaV942.account => const BridgePointAccountSupportV2(),
        _AreaV942.integrations => const BridgePointIntegrationsHub(),
        _AreaV942.worth => const BridgePointInvestmentValuationV2(),
        _AreaV942.buildings => const BridgePointBuildingsV2(),
        _AreaV942.owner => const BridgePointOwnerCommandCenterV942(),
        _AreaV942.sources => const BridgePointSourcesV2(),
        _AreaV942.models => const BridgePointModelsV2(),
        _AreaV942.studio => BridgePointIntelligenceStudio(ownerMode: true, onNavigate: (_) => go(_AreaV942.owner)),
      };

  List<PopupMenuEntry<_AreaV942?>> menuItems() => [
        const PopupMenuItem(value: _AreaV942.search, child: ListTile(leading: Icon(Icons.search_rounded), title: Text('Search'))),
        const PopupMenuItem(value: _AreaV942.ai, child: ListTile(leading: Icon(Icons.auto_awesome_rounded), title: Text('Ask BridgePoint AI'))),
        const PopupMenuItem(value: _AreaV942.account, child: ListTile(leading: Icon(Icons.manage_accounts_outlined), title: Text('Account / Billing / Help'))),
        if (owner) const PopupMenuDivider(),
        if (owner) const PopupMenuItem(value: _AreaV942.worth, child: ListTile(leading: Icon(Icons.show_chart_rounded), title: Text('Worth'))),
        if (owner) const PopupMenuItem(value: _AreaV942.owner, child: ListTile(leading: Icon(Icons.admin_panel_settings_rounded), title: Text('Owner Control'))),
        if (owner) const PopupMenuItem(value: _AreaV942.buildings, child: ListTile(leading: Icon(Icons.view_in_ar_rounded), title: Text('Buildings / Twin'))),
        if (owner) const PopupMenuItem(value: _AreaV942.sources, child: ListTile(leading: Icon(Icons.hub_outlined), title: Text('Source diagnostics'))),
        if (owner) const PopupMenuItem(value: _AreaV942.models, child: ListTile(leading: Icon(Icons.psychology_alt_outlined), title: Text('Model diagnostics'))),
        if (owner) const PopupMenuItem(value: _AreaV942.studio, child: ListTile(leading: Icon(Icons.schema_outlined), title: Text('Intelligence Studio'))),
        if (owner) const PopupMenuItem(value: _AreaV942.integrations, child: ListTile(leading: Icon(Icons.cable_rounded), title: Text('Integrations'))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: null, child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Sign out'))),
      ];

  void handleMenu(_AreaV942? value) {
    if (value == null) {
      Supabase.instance.client.auth.signOut();
    } else {
      go(value);
    }
  }

  bool get bounded => selected == _AreaV942.owner;

  @override
  Widget build(BuildContext context) {
    if (!ownerChecked) {
      return const Scaffold(body: BridgePointMotionBackgroundV2(child: Center(child: CircularProgressIndicator())));
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 820;
    final primaryIndex = primary.indexOf(selected);
    final current = primaryIndex >= 0 ? primaryIndex : 3;

    final body = _PageFrameV942(scroll: !bounded, child: page());

    if (compact) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          title: Row(children: [
            const BridgePointMarkV2(size: 32),
            const SizedBox(width: 9),
            Expanded(child: Text(title(selected), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          actions: [
            IconButton(onPressed: search, tooltip: 'Search', icon: const Icon(Icons.search_rounded)),
            IconButton(onPressed: () => go(_AreaV942.plans), tooltip: 'Plans & upgrade', icon: const Icon(Icons.workspace_premium_rounded, color: _gold)),
            PopupMenuButton<_AreaV942?>(onSelected: handleMenu, itemBuilder: (_) => menuItems(), icon: const Icon(Icons.more_vert_rounded)),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: (i) => go(primary[i]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.public_rounded), label: 'Map'),
            NavigationDestination(icon: Icon(Icons.holiday_village_rounded), label: 'Properties'),
            NavigationDestination(icon: Icon(Icons.workspaces_outline), label: 'Work'),
            NavigationDestination(icon: Icon(Icons.workspace_premium_rounded, color: _gold), selectedIcon: Icon(Icons.workspace_premium_rounded, color: _gold), label: 'Plans'),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: width >= 1220,
          selectedIndex: primaryIndex >= 0 ? primaryIndex : null,
          onDestinationSelected: (i) => go(primary[i]),
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: width >= 1220 ? const BridgePointBrandLockupV2() : const BridgePointMarkV2(size: 42),
          ),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.space_dashboard_rounded), label: Text('Home')),
            NavigationRailDestination(icon: Icon(Icons.public_rounded), label: Text('Map')),
            NavigationRailDestination(icon: Icon(Icons.holiday_village_rounded), label: Text('Properties')),
            NavigationRailDestination(icon: Icon(Icons.workspaces_outline), label: Text('Work')),
            NavigationRailDestination(icon: Icon(Icons.workspace_premium_rounded, color: _gold), selectedIcon: Icon(Icons.workspace_premium_rounded, color: _gold), label: Text('Plans')),
          ],
        ),
        Expanded(child: Column(children: [
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: const BoxDecoration(color: Color(0xF505111F), border: Border(bottom: BorderSide(color: Color(0x2248E1FF)))),
            child: Row(children: [
              Expanded(child: Text(title(selected), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
              SizedBox(
                width: width >= 1250 ? 330 : 250,
                child: TextField(readOnly: true, onTap: search, decoration: const InputDecoration(hintText: 'Search BridgePoint…', prefixIcon: Icon(Icons.search_rounded), isDense: true)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF1A1200)),
                onPressed: () => go(_AreaV942.plans),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Plans'),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<_AreaV942?>(onSelected: handleMenu, itemBuilder: (_) => menuItems(), tooltip: 'Explore', icon: const Icon(Icons.grid_view_rounded, color: _cyan)),
            ]),
          ),
          Expanded(child: body),
        ])),
      ]),
    );
  }
}

class _WorkHubV942 extends StatelessWidget {
  const _WorkHubV942({required this.go});
  final void Function(_AreaV942 area) go;

  @override
  Widget build(BuildContext context) {
    const items = [
      (_AreaV942.opportunities, Icons.bolt_rounded, 'Opportunities', 'Prioritized properties and the reasons they deserve attention.', Color(0xFFFFC95E)),
      (_AreaV942.saved, Icons.bookmark_added_outlined, 'Saved & Alerts', 'Keep properties, alerts and follow-up in one place.', Color(0xFF48E1FF)),
      (_AreaV942.claims, Icons.assignment_outlined, 'Claims', 'Evidence, timelines and claim-support workflows where authorized.', Color(0xFF6C83FF)),
      (_AreaV942.calendar, Icons.calendar_month_rounded, 'Calendar', 'Plan visits, tasks and follow-up without leaving BridgePoint.', Color(0xFF45E6A6)),
      (_AreaV942.portfolio, Icons.account_tree_outlined, 'Portfolio & Risk', 'Review groups of properties and portfolio-level context.', Color(0xFF9B7BFF)),
      (_AreaV942.investor, Icons.real_estate_agent_rounded, 'Investor', 'Acquisition, transition and redevelopment intelligence.', Color(0xFF48E1FF)),
      (_AreaV942.ai, Icons.auto_awesome_rounded, 'Ask BridgePoint AI', 'Ask property questions without digging through source systems.', Color(0xFF6C83FF)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF081623), Color(0xFF11233A), Color(0xFF10172F)]),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0x3348E1FF)),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Work', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('Everything you do after finding a property lives here. The backend stays underneath instead of becoming another set of tabs.', style: TextStyle(color: Color(0xFFB5C6D9), height: 1.45)),
        ]),
      ),
      const SizedBox(height: 13),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 620 ? 2 : 1;
        final w = (c.maxWidth - (cols - 1) * 11) / cols;
        return Wrap(spacing: 11, runSpacing: 11, children: [
          for (final item in items)
            SizedBox(
              width: w,
              child: InkWell(
                onTap: () => go(item.$1),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2C),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: item.$5.withValues(alpha: .18)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 43, height: 43, decoration: BoxDecoration(color: item.$5.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)), child: Icon(item.$2, color: item.$5)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.$3, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(item.$4, style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 12.5, height: 1.4)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: _muted),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    ]);
  }
}

class _PageFrameV942 extends StatelessWidget {
  const _PageFrameV942({required this.child, required this.scroll});
  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = scroll
        ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)
        : Padding(padding: const EdgeInsets.all(8), child: SizedBox.expand(child: child));
    return BridgePointMotionBackgroundV2(child: content);
  }
}
