import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_integrations_hub_v790.dart';
import 'bridgepoint_intelligence_studio_v790.dart';
import 'screens/bridgepoint_owner_command_center.dart';

const _supabaseUrl = 'https://xdfsjztwgsbmabshzsjw.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_lM9oWQeHjBmgOIiteeOicQ_PTyAeF25';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const BridgePointV2App());
}

class BridgePointV2App extends StatelessWidget {
  const BridgePointV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BridgePoint Intelligence',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: const _AuthGate(),
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
    cardTheme: const CardThemeData(
      color: panel,
      margin: EdgeInsets.zero,
    ),
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

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const _AuthPage() : const _Workspace();
      },
    );
  }
}

class _AuthPage extends StatefulWidget {
  const _AuthPage();

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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.35,
            colors: [Color(0x2235D2E8), Color(0xFF06111E)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: SizedBox(
                width: 460,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.hub_rounded,
                          color: Color(0xFF35D2E8), size: 44),
                      const SizedBox(height: 14),
                      const Text(
                        'BridgePoint Intelligence',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900),
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
                            icon: Icon(showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded),
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!,
                            style: const TextStyle(color: Color(0xFFFF7E7E))),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(create ? 'Create account' : 'Sign in'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => create = !create),
                        child: Text(create
                            ? 'Already have an account? Sign in'
                            : 'New to BridgePoint? Create account'),
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

enum _Area { home, property, map, workflows, studio, integrations, owner }

class _AreaSpec {
  const _AreaSpec(this.area, this.label, this.icon);
  final _Area area;
  final String label;
  final IconData icon;
}

const _baseAreas = <_AreaSpec>[
  _AreaSpec(_Area.home, 'Home', Icons.space_dashboard_rounded),
  _AreaSpec(_Area.property, 'Property', Icons.home_work_rounded),
  _AreaSpec(_Area.map, 'Map & Weather', Icons.public_rounded),
  _AreaSpec(_Area.workflows, 'Workflows & AI', Icons.auto_awesome_rounded),
  _AreaSpec(_Area.studio, 'Intelligence Studio', Icons.schema_rounded),
  _AreaSpec(_Area.integrations, 'Integrations', Icons.cable_rounded),
];

class _Workspace extends StatefulWidget {
  const _Workspace();

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  _Area selected = _Area.home;
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
        'bridgepoint_owner_master_completion_v768',
        params: {'p_status': null, 'p_limit': 1},
      );
      owner = true;
    } catch (_) {
      owner = false;
    }
    if (mounted) setState(() => ownerChecked = true);
  }

  List<_AreaSpec> get areas => [
        ..._baseAreas,
        if (owner)
          const _AreaSpec(
              _Area.owner, 'Owner Control', Icons.admin_panel_settings_rounded),
      ];

  void _navigateFromStudio(int oldIndex) {
    final target = switch (oldIndex) {
      1 || 4 || 8 => _Area.property,
      3 => _Area.map,
      7 => _Area.workflows,
      14 => _Area.integrations,
      _ => _Area.studio,
    };
    setState(() => selected = target);
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final spec in areas.where((x) =>
                  x.area == _Area.workflows ||
                  x.area == _Area.integrations ||
                  x.area == _Area.owner))
                ListTile(
                  leading: Icon(spec.icon),
                  title: Text(spec.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => selected = spec.area);
                  },
                ),
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

  Widget _page() => switch (selected) {
        _Area.home => const _HomePage(),
        _Area.property => const _PropertyPage(),
        _Area.map => const _MapWeatherPage(),
        _Area.workflows => const _CapabilityLibraryPage(),
        _Area.studio => BridgePointIntelligenceStudio(
            onNavigate: _navigateFromStudio,
            ownerMode: owner,
          ),
        _Area.integrations => const BridgePointIntegrationsHub(),
        _Area.owner => const BridgePointOwnerCommandCenter(),
      };

  @override
  Widget build(BuildContext context) {
    if (!ownerChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 820;

    if (compact) {
      final primary = const [
        _Area.home,
        _Area.property,
        _Area.map,
        _Area.studio,
      ];
      final current = primary.contains(selected) ? primary.indexOf(selected) : 4;
      return Scaffold(
        appBar: AppBar(
          title: Text(_titleFor(selected)),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: _PageFrame(
          scroll: selected != _Area.owner,
          child: _page(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: (index) {
            if (index == 4) {
              _showMore();
            } else {
              setState(() => selected = primary[index]);
            }
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.home_work_rounded), label: 'Property'),
            NavigationDestination(
                icon: Icon(Icons.public_rounded), label: 'Map'),
            NavigationDestination(
                icon: Icon(Icons.schema_rounded), label: 'Studio'),
            NavigationDestination(
                icon: Icon(Icons.apps_rounded), label: 'More'),
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
            extended: width >= 1120,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selected = specs[index].area),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.hub_rounded,
                  color: Color(0xFF35D2E8), size: 30),
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
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    color: Color(0xFF081625),
                    border: Border(
                        bottom: BorderSide(color: Color(0x2235D2E8))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titleFor(selected),
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const _LiveBadge(),
                    ],
                  ),
                ),
                Expanded(
                  child: _PageFrame(
                    scroll: selected != _Area.owner,
                    child: _page(),
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

String _titleFor(_Area area) => switch (area) {
      _Area.home => 'BridgePoint Intelligence',
      _Area.property => 'Property Intelligence',
      _Area.map => 'Geospatial Intelligence',
      _Area.workflows => 'Workflows & AI',
      _Area.studio => 'Intelligence Studio',
      _Area.integrations => 'Integrations & Data Exchange',
      _Area.owner => 'Owner Control',
    };

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child, this.scroll = true});

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
          colors: [Color(0x1435D2E8), Color(0xFF06111E)],
        ),
      ),
      child: content,
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF38D49A).withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF38D49A).withOpacity(.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF38D49A)),
          SizedBox(width: 6),
          Text('LIVE BACKEND',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late Future<List<dynamic>> request;

  @override
  void initState() {
    super.initState();
    request = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
        Supabase.instance.client.rpc('bridgepoint_daily_brief_v74'),
        Supabase.instance.client.rpc('bridgepoint_public_system_status_v320'),
        Supabase.instance.client.rpc('bridgepoint_user_market_context_v320'),
      ]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: request,
      builder: (context, snapshot) {
        final brief = _map(snapshot.data?.elementAtOrNull(0));
        final status = _map(snapshot.data?.elementAtOrNull(1));
        final market = _map(snapshot.data?.elementAtOrNull(2));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('One operating system for property intelligence',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
              'Property, risk, claims, weather, imagery, workflows, models and integrations share one canonical property/evidence layer.',
              style: TextStyle(color: Color(0xFF8FA5BF), height: 1.5),
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (snapshot.hasError)
              _InfoCard(
                icon: Icons.error_outline_rounded,
                title: 'Live backend check failed',
                body: '${snapshot.error}',
              )
            else ...[
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth >= 1000
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _InfoCard(
                        icon: Icons.auto_graph_rounded,
                        title: 'Daily intelligence',
                        body: _summary(brief,
                            preferred: const ['summary', 'headline', 'message']),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _InfoCard(
                        icon: Icons.monitor_heart_outlined,
                        title: 'System status',
                        body: _summary(status,
                            preferred: const ['status', 'message', 'condition']),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _InfoCard(
                        icon: Icons.location_on_outlined,
                        title: 'Your market',
                        body: _summary(market,
                            preferred: const [
                              'market_status',
                              'state_code',
                              'message'
                            ]),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 18),
              _JsonHighlights(title: 'Live daily brief', value: brief),
            ],
          ],
        );
      },
    );
  }
}

class _PropertyPage extends StatefulWidget {
  const _PropertyPage();

  @override
  State<_PropertyPage> createState() => _PropertyPageState();
}

class _PropertyPageState extends State<_PropertyPage> {
  final query = TextEditingController();
  bool loading = false;
  List<Map<String, dynamic>> rows = const [];
  Map<String, dynamic>? detail;
  String? error;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (query.text.trim().length < 2) return;
    setState(() {
      loading = true;
      error = null;
      detail = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_suggestions_v192',
        params: {'p_query': query.text.trim(), 'p_limit': 25},
      );
      final map = _map(raw);
      final candidates = _firstList(map,
          const ['suggestions', 'properties', 'results', 'matches', 'items']);
      if (mounted) setState(() => rows = candidates);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openProperty(Map<String, dynamic> row) async {
    final id = '${row['property_id'] ?? row['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_flutter_property_detail_v344',
        params: {'p_property_id': id},
      );
      if (mounted) setState(() => detail = _map(raw));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property Intelligence',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
          'Search the canonical property layer, then inspect the same evidence-backed property object used by BridgePoint scoring, maps, workflows and integrations.',
          style: TextStyle(color: Color(0xFF8FA5BF), height: 1.45),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: query,
                onSubmitted: (_) => search(),
                decoration: const InputDecoration(
                  labelText: 'Address, parcel, owner, city or property',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: loading ? null : search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search'),
            ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: Color(0xFFFF7E7E))),
        ],
        const SizedBox(height: 14),
        if (detail != null)
          _JsonHighlights(title: 'Property intelligence', value: detail!)
        else if (rows.isNotEmpty)
          ...rows.map((row) {
            final title = _propertyLabel(row);
            final subtitle = [
              row['city'],
              row['state_code'],
              row['county_name'],
              row['parcel_id'] ?? row['parcel_number'],
            ].where((x) => x != null && '$x'.trim().isNotEmpty).join(' • ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1635D2E8),
                    child: Icon(Icons.home_work_outlined,
                        color: Color(0xFF35D2E8)),
                  ),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openProperty(row),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _MapWeatherPage extends StatefulWidget {
  const _MapWeatherPage();

  @override
  State<_MapWeatherPage> createState() => _MapWeatherPageState();
}

class _MapWeatherPageState extends State<_MapWeatherPage> {
  bool radar = true;
  bool satellite = true;
  bool playing = true;
  int frame = 48;
  Timer? timer;

  List<DateTime> get frames {
    final now = DateTime.now().toUtc();
    final rounded =
        DateTime.utc(now.year, now.month, now.day, now.hour, (now.minute ~/ 5) * 5);
    return List.generate(
        49, (i) => rounded.subtract(Duration(minutes: (48 - i) * 5)));
  }

  DateTime get radarTime => frames[frame.clamp(0, 48)];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (mounted && radar && playing) {
        setState(() => frame = frame >= 48 ? 0 : frame + 1);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.sizeOf(context).height.clamp(520.0, 820.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Geospatial Intelligence',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
          'One map for property, weather, imagery and intelligence layers. Raw radar remains regional evidence; BridgePoint does not pretend coarse radar pixels become roof-level observations when you zoom in.',
          style: TextStyle(color: Color(0xFF8FA5BF), height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: satellite,
              label: const Text('Satellite'),
              avatar: const Icon(Icons.satellite_alt_outlined, size: 18),
              onSelected: (value) => setState(() => satellite = value),
            ),
            FilterChip(
              selected: radar,
              label: const Text('NOAA radar'),
              avatar: const Icon(Icons.radar_rounded, size: 18),
              onSelected: (value) => setState(() => radar = value),
            ),
            ActionChip(
              avatar: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(playing ? 'Pause weather' : 'Play weather'),
              onPressed: () => setState(() => playing = !playing),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(39.5, -98.35),
                    initialZoom: 4.0,
                    minZoom: 3,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: satellite
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bridgepoint.data_studio',
                      maxNativeZoom: 19,
                    ),
                    if (satellite)
                      TileLayer(
                        urlTemplate:
                            'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    if (radar)
                      TileLayer(
                        key: ValueKey('bp-radar-${radarTime.millisecondsSinceEpoch}'),
                        wmsOptions: WMSTileLayerOptions(
                          baseUrl:
                              'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                          layers: const ['0'],
                          format: 'image/png',
                          transparent: true,
                          version: '1.3.0',
                          otherParameters: {
                            'TIME': radarTime.toUtc().toIso8601String(),
                          },
                        ),
                        maxNativeZoom: 10,
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('NOAA / NWS MRMS'),
                        TextSourceAttribution('Esri / OpenStreetMap'),
                      ],
                    ),
                  ],
                ),
                if (radar)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      color: const Color(0xEE071321),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text('NOAA MRMS • ~1 KM SOURCE',
                                    style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF35D2E8))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Slider(
                                    value: frame.toDouble(),
                                    min: 0,
                                    max: 48,
                                    divisions: 48,
                                    onChanged: (value) => setState(() {
                                      playing = false;
                                      frame = value.round();
                                    }),
                                  ),
                                ),
                                Text(_clock(radarTime),
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const Text(
                              'Four-hour time-enabled radar • updates about every 5 minutes • raw reflectivity is weather context, not proof of damage at a specific property.',
                              style: TextStyle(
                                  color: Color(0xFF8FA5BF), fontSize: 8.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CapabilityLibraryPage extends StatefulWidget {
  const _CapabilityLibraryPage();

  @override
  State<_CapabilityLibraryPage> createState() => _CapabilityLibraryPageState();
}

class _CapabilityLibraryPageState extends State<_CapabilityLibraryPage> {
  final query = TextEditingController();
  late Future<Map<String, dynamic>> request;

  @override
  void initState() {
    super.initState();
    request = load();
  }

  Future<Map<String, dynamic>> load() async {
    final raw = await Supabase.instance.client.rpc(
      'bridgepoint_capability_library_v831',
      params: {
        'p_query': query.text.trim().isEmpty ? null : query.text.trim(),
        'p_limit': 500,
      },
    );
    return _map(raw);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void reload() => setState(() => request = load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: request,
      builder: (context, snapshot) {
        final rows = _firstList(snapshot.data ?? const {}, const ['capabilities']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Workflows & AI',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text(
              'Search the customer/integration capability catalog. COVERED means the surface is proven; PARTIAL stays visible as unfinished product work instead of being hidden.',
              style: TextStyle(color: Color(0xFF8FA5BF), height: 1.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: query,
                    onSubmitted: (_) => reload(),
                    decoration: const InputDecoration(
                      labelText: 'Find a workflow or capability',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                    onPressed: reload, icon: const Icon(Icons.search_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (snapshot.hasError)
              Text('${snapshot.error}',
                  style: const TextStyle(color: Color(0xFFFF7E7E)))
            else
              ...rows.map((row) {
                final covered = row['status'] == 'COVERED';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        row['surface_kind'] == 'INTEGRATION_API'
                            ? Icons.cable_rounded
                            : Icons.auto_awesome_rounded,
                        color: covered
                            ? const Color(0xFF38D49A)
                            : const Color(0xFFFFC857),
                      ),
                      title: Text('${row['label'] ?? row['capability_key']}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                          '${row['surface_kind'] ?? ''} • ${row['surface_reference'] ?? 'surface being classified'}'),
                      trailing: Text('${row['status'] ?? ''}',
                          style: TextStyle(
                              color: covered
                                  ? const Color(0xFF38D49A)
                                  : const Color(0xFFFFC857),
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF35D2E8)),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 5),
            Text(body,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF8FA5BF), height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _JsonHighlights extends StatelessWidget {
  const _JsonHighlights({required this.title, required this.value});
  final String title;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    final rows = value.entries
        .where((entry) => entry.value != null && '${entry.value}'.trim().isNotEmpty)
        .take(24)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...rows.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text(_pretty(entry.key),
                            style: const TextStyle(
                                color: Color(0xFF8FA5BF), fontSize: 10)),
                      ),
                      Expanded(
                        child: Text(_display(entry.value),
                            style: const TextStyle(fontSize: 10, height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _firstList(
    Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
    }
  }
  return const [];
}

String _propertyLabel(Map<String, dynamic> row) {
  for (final key in const [
    'display_address',
    'full_address',
    'address',
    'property_address',
    'site_address'
  ]) {
    final value = '${row[key] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
  }
  return '${row['property_id'] ?? 'Property'}';
}

String _summary(Map<String, dynamic> value,
    {required List<String> preferred}) {
  for (final key in preferred) {
    final candidate = value[key];
    if (candidate != null && '$candidate'.trim().isNotEmpty) {
      return _display(candidate);
    }
  }
  if (value.isEmpty) return 'Live response returned no summary fields.';
  return value.entries.take(3).map((e) => '${_pretty(e.key)}: ${_display(e.value)}').join('\n');
}

String _display(dynamic value) {
  if (value is Map) {
    return value.entries
        .take(6)
        .map((e) => '${_pretty('${e.key}')}: ${_display(e.value)}')
        .join(' • ');
  }
  if (value is List) {
    return value.take(8).map(_display).join(' • ');
  }
  final text = '$value';
  return text.length > 420 ? '${text.substring(0, 420)}…' : text;
}

String _pretty(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((x) => x.isNotEmpty)
    .map((x) => '${x[0].toUpperCase()}${x.substring(1)}')
    .join(' ');

String _clock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
}

extension<T> on List<T> {
  T? elementAtOrNull(int index) => index >= 0 && index < length ? this[index] : null;
}
