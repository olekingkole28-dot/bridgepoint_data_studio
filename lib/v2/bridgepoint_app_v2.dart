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

class BridgePointV2App extends StatelessWidget {
  const BridgePointV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final appBump = media.size.width < 820 ? 1.06 : 1.04;
        final userScale = media.textScaler.scale(1.0);
        final effectiveScale = (userScale * appBump).clamp(0.8, 2.5);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(effectiveScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _BridgePointRoot(),
    );
  }
}

ThemeData _theme() {
  const bg = Color(0xFF040B14);
  const panel = Color(0xFF0E2035);
  const panelRaised = Color(0xFF16324E);
  const cyan = Color(0xFF48E1FF);
  const blue = Color(0xFF6C83FF);
  const green = Color(0xFF45E6A6);
  const amber = Color(0xFFFFC95E);
  const muted = Color(0xFFB5C6D9);
  const ink = Color(0xFFF5F8FC);

  final scheme = const ColorScheme.dark(
    primary: cyan,
    onPrimary: Color(0xFF021018),
    secondary: blue,
    onSecondary: Colors.white,
    tertiary: amber,
    onTertiary: Color(0xFF1A1200),
    surface: panel,
    onSurface: ink,
    error: Color(0xFFFF7474),
    onError: Color(0xFF250000),
  );

  final baseText = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
  ).textTheme.apply(
        fontFamily: 'BridgePointGrotesk',
        bodyColor: ink,
        displayColor: Colors.white,
      );

  final textTheme = baseText.copyWith(
    displayLarge: baseText.displayLarge?.copyWith(
      fontSize: 46,
      fontWeight: FontWeight.w900,
      height: 1.02,
      letterSpacing: -1.4,
    ),
    displayMedium: baseText.displayMedium?.copyWith(
      fontSize: 38,
      fontWeight: FontWeight.w900,
      height: 1.04,
      letterSpacing: -1.0,
    ),
    headlineLarge: baseText.headlineLarge?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      height: 1.08,
      letterSpacing: -.5,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w900,
      height: 1.1,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w900,
      height: 1.18,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      height: 1.25,
    ),
    titleSmall: baseText.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w800,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),
    bodyMedium: baseText.bodyMedium?.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      height: 1.45,
    ),
    bodySmall: baseText.bodySmall?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: muted,
      height: 1.4,
    ),
    labelLarge: baseText.labelLarge?.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w900,
      letterSpacing: .1,
    ),
    labelMedium: baseText.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: .2,
    ),
    labelSmall: baseText.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .25,
    ),
  );

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'BridgePointGrotesk',
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    cardColor: panel,
    iconTheme: const IconThemeData(color: Color(0xFFDDE8F4), size: 23),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF209192A),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFFDDE8F4), size: 24),
    ),
    cardTheme: CardThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0x66000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cyan.withValues(alpha: .14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0B1B2D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(
        color: Color(0xFFC2D2E3),
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: TextStyle(
        color: muted.withValues(alpha: .82),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: cyan,
      suffixIconColor: const Color(0xFFDDE8F4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan.withValues(alpha: .16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cyan.withValues(alpha: .14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cyan, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        backgroundColor: cyan,
        foregroundColor: const Color(0xFF031018),
        textStyle: const TextStyle(
          fontFamily: 'BridgePointGrotesk',
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: const Color(0xFFF5F8FC),
        side: BorderSide(color: blue.withValues(alpha: .65), width: 1.2),
        textStyle: const TextStyle(
          fontFamily: 'BridgePointGrotesk',
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cyan,
        textStyle: const TextStyle(
          fontFamily: 'BridgePointGrotesk',
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: panelRaised.withValues(alpha: .78),
      selectedColor: blue.withValues(alpha: .22),
      side: BorderSide(color: cyan.withValues(alpha: .16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      labelStyle: const TextStyle(
        color: Color(0xFFF1F6FB),
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF8FEFFF),
      textColor: Colors.white,
      titleTextStyle: TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: muted,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      backgroundColor: const Color(0xF209192A),
      indicatorColor: blue.withValues(alpha: .22),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'BridgePointGrotesk',
          color: selected ? Colors.white : muted,
          fontSize: selected ? 12.5 : 12,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? cyan : muted,
          size: selected ? 25 : 23,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xF209192A),
      indicatorColor: blue.withValues(alpha: .20),
      selectedIconTheme: const IconThemeData(color: cyan, size: 25),
      unselectedIconTheme: const IconThemeData(color: muted, size: 22),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: 'BridgePointGrotesk',
        color: muted,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: cyan.withValues(alpha: .12),
      thickness: 1,
      space: 20,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0B1B2D),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFF6C83FF),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0B1B2D),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panelRaised,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10243B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cyan.withValues(alpha: .18)),
      ),
    ),
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
      if (mounted) {
        final message = e is AuthException
            ? e.message
            : 'BridgePoint could not complete authentication right now. Please try again.';
        setState(() => error = message);
      }
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
                    style: TextStyle(color: Color(0xFFB5C6D9)),
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
  search,
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
  _AreaSpecV2(_AreaV2.search, 'Search', Icons.search_rounded),
  _AreaSpecV2(_AreaV2.map, 'Map & Weather', Icons.public_rounded),
  _AreaSpecV2(_AreaV2.properties, 'Properties', Icons.holiday_village_rounded),
  _AreaSpecV2(_AreaV2.opportunities, 'Opportunities', Icons.bolt_rounded),
  _AreaSpecV2(
    _AreaV2.investor,
    'Property Investor',
    Icons.real_estate_agent_rounded,
  ),
  _AreaSpecV2(_AreaV2.property, 'Property 360', Icons.home_work_rounded),
  _AreaSpecV2(_AreaV2.signals, 'Signals', Icons.radar_rounded),
  _AreaSpecV2(_AreaV2.sources, 'Sources', Icons.hub_rounded),
  _AreaSpecV2(_AreaV2.models, 'Models', Icons.psychology_alt_rounded),
  _AreaSpecV2(
    _AreaV2.savedAlerts,
    'Saved & Alerts',
    Icons.bookmark_added_outlined,
  ),
  _AreaSpecV2(_AreaV2.operations, 'Operations', Icons.track_changes_rounded),
  _AreaSpecV2(_AreaV2.claims, 'Claims', Icons.assignment_outlined),
  _AreaSpecV2(_AreaV2.calendar, 'Calendar', Icons.calendar_month_rounded),
  _AreaSpecV2(
    _AreaV2.portfolio,
    'Portfolio & Risk',
    Icons.account_tree_outlined,
  ),
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
  final TextEditingController _globalSearch = TextEditingController();
  String? _searchSeed;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  @override
  void dispose() {
    _globalSearch.dispose();
    super.dispose();
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

  void _openSearch(String raw) {
    final query = raw.trim();
    setState(() {
      _searchSeed = query.length >= 2 ? query : null;
      selected = _AreaV2.search;
    });
  }

  Future<void> _showMobileSearch() async {
    final controller = TextEditingController(text: _globalSearch.text);
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
    final clean = value?.trim();
    controller.dispose();
    if (clean != null && clean.isNotEmpty) {
      _globalSearch.text = clean;
      _openSearch(clean);
    }
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

  List<_AreaV2> get _primary => const [
        _AreaV2.home,
        _AreaV2.map,
        _AreaV2.properties,
        _AreaV2.investor,
      ];

  void _navigateFromStudio(int oldIndex) {
    final target = switch (oldIndex) {
      1 => _AreaV2.opportunities,
      3 => _AreaV2.map,
      4 => _AreaV2.property,
      5 => _AreaV2.signals,
      6 => _AreaV2.sources,
      7 => _AreaV2.operations,
      8 => _AreaV2.sources,
      9 => _AreaV2.map,
      11 => _AreaV2.models,
      14 => _AreaV2.integrations,
      _ => _AreaV2.studio,
    };
    setState(() => selected = target);
  }

  Widget _page() => switch (selected) {
        _AreaV2.home => const BridgePointHomeV2(),
        _AreaV2.search => BridgePointGlobalSearchV2(
            key: ValueKey(_searchSeed),
            initialQuery: _searchSeed,
          ),
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
            IconButton(
              tooltip: 'Search properties',
              onPressed: _showMobileSearch,
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Notifications and saved alerts',
              onPressed: () => setState(() => selected = _AreaV2.savedAlerts),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            if (owner)
              IconButton(
                tooltip: 'Owner Backend',
                onPressed: () => setState(() => selected = _AreaV2.owner),
                icon: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF48E1FF),
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
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: Color(0xF209192A),
                    border: Border(
                      bottom: BorderSide(color: Color(0x3348E1FF)),
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
                                color: Color(0xFF48E1FF),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (width >= 1080) ...[
                        SizedBox(
                          width: width >= 1400 ? 360 : 270,
                          child: TextField(
                            controller: _globalSearch,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _openSearch,
                            decoration: InputDecoration(
                              hintText: 'Search address, parcel, owner…',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: IconButton(
                                tooltip: 'Search',
                                onPressed: () => _openSearch(_globalSearch.text),
                                icon: const Icon(Icons.arrow_forward_rounded),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      IconButton(
                        tooltip: 'Notifications and saved alerts',
                        onPressed: () =>
                            setState(() => selected = _AreaV2.savedAlerts),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      if (owner)
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => selected = _AreaV2.investment),
                          icon: const Icon(
                            Icons.show_chart_rounded,
                            color: Color(0xFF45E6A6),
                          ),
                          label: const Text('Worth'),
                        ),
                      if (owner)
                        TextButton.icon(
                          onPressed: () => setState(() => selected = _AreaV2.owner),
                          icon: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFF48E1FF),
                          ),
                          label: const Text('Owner Backend'),
                        ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => setState(() => selected = _AreaV2.ai),
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF48E1FF),
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
      _AreaV2.search => 'Search BridgePoint',
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x2448E1FF),
            Color(0x181E4FA6),
            Color(0x18281950),
            Color(0xFF040B14),
          ],
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
        color: const Color(0xFF45E6A6).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF45E6A6).withValues(alpha: .2),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF45E6A6)),
          SizedBox(width: 6),
          Text(
            'LIVE BACKEND',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
