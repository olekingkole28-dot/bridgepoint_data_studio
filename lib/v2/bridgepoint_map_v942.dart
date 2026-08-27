import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointMapV942 extends StatefulWidget {
  const BridgePointMapV942({super.key});

  @override
  State<BridgePointMapV942> createState() => _BridgePointMapV942State();
}

class _BridgePointMapV942State extends State<BridgePointMapV942> {
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF071321);

  static const _propertyLoadMinZoom = 6.35;
  static const _propertyMarkerMinZoom = 10.4;
  static const _opportunityMarkerMinZoom = 7.2;
  static const _signalMarkerMinZoom = 8.1;
  static const _stateLabelMaxZoom = 6.2;
  static const _radarMaxZoom = 11.2;

  final MapController _controller = MapController();
  Timer? _radarTimer;
  Timer? _refreshTimer;
  Timer? _viewportDebounce;

  bool satellite = true;
  bool radar = true;
  bool playing = true;
  bool showProperties = true;
  bool showOpportunities = true;
  bool showSignals = true;
  bool busy = false;
  bool viewportBusy = false;
  bool locating = false;
  bool radarCatalogLive = false;
  int frame = 0;
  int _viewportSerial = 0;
  double zoom = 4;
  LatLng? userLocation;
  String? message;
  String? locationMessage;

  List<DateTime> radarFrames = const [];
  List<Map<String, dynamic>> states = const [];
  List<Map<String, dynamic>> properties = const [];
  List<Map<String, dynamic>> opportunities = const [];
  List<Map<String, dynamic>> signals = const [];

  static const Map<String, LatLng> stateCenters = {
    'AL': LatLng(32.81, -86.79), 'AK': LatLng(61.37, -152.40),
    'AZ': LatLng(33.73, -111.43), 'AR': LatLng(34.97, -92.37),
    'CA': LatLng(36.12, -119.68), 'CO': LatLng(39.06, -105.31),
    'CT': LatLng(41.60, -72.76), 'DE': LatLng(39.32, -75.51),
    'DC': LatLng(38.90, -77.03), 'FL': LatLng(27.77, -81.69),
    'GA': LatLng(33.04, -83.64), 'HI': LatLng(21.09, -157.50),
    'ID': LatLng(44.24, -114.48), 'IL': LatLng(40.35, -88.99),
    'IN': LatLng(39.85, -86.26), 'IA': LatLng(42.01, -93.21),
    'KS': LatLng(38.53, -96.93), 'KY': LatLng(37.67, -84.67),
    'LA': LatLng(31.17, -91.87), 'ME': LatLng(44.69, -69.38),
    'MD': LatLng(39.06, -76.80), 'MA': LatLng(42.23, -71.53),
    'MI': LatLng(43.33, -84.54), 'MN': LatLng(45.69, -93.90),
    'MS': LatLng(32.74, -89.65), 'MO': LatLng(38.46, -92.29),
    'MT': LatLng(46.92, -110.45), 'NE': LatLng(41.13, -98.27),
    'NV': LatLng(38.31, -117.06), 'NH': LatLng(43.45, -71.56),
    'NJ': LatLng(40.30, -74.52), 'NM': LatLng(34.84, -106.25),
    'NY': LatLng(42.17, -74.95), 'NC': LatLng(35.63, -79.81),
    'ND': LatLng(47.53, -99.78), 'OH': LatLng(40.39, -82.76),
    'OK': LatLng(35.57, -96.93), 'OR': LatLng(44.57, -122.07),
    'PA': LatLng(40.59, -77.21), 'RI': LatLng(41.68, -71.51),
    'SC': LatLng(33.86, -80.95), 'SD': LatLng(44.30, -99.44),
    'TN': LatLng(35.75, -86.69), 'TX': LatLng(31.05, -97.56),
    'UT': LatLng(40.15, -111.86), 'VT': LatLng(44.05, -72.71),
    'VA': LatLng(37.77, -78.17), 'WA': LatLng(47.40, -121.49),
    'WV': LatLng(38.49, -80.95), 'WI': LatLng(44.27, -89.62),
    'WY': LatLng(42.76, -107.30),
  };

  @override
  void initState() {
    super.initState();
    _loadRadarFrames();
    _loadOverview();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted && radar && playing && radarFrames.length > 1) {
        setState(() => frame = frame >= radarFrames.length - 1 ? 0 : frame + 1);
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        _loadOverview(silent: true);
        _loadRadarFrames();
      }
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _refreshTimer?.cancel();
    _viewportDebounce?.cancel();
    super.dispose();
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const ['states', 'properties', 'opportunities', 'signals', 'items', 'rows', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  String _short(dynamic value) {
    final n = _int(value);
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 1 : 2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}K';
    return '$n';
  }

  DateTime get radarTime => radarFrames.isEmpty
      ? DateTime.now().toUtc()
      : radarFrames[frame.clamp(0, radarFrames.length - 1)];

  String _clock(DateTime value) {
    final local = value.toLocal();
    final h = local.hour == 0 ? 12 : local.hour > 12 ? local.hour - 12 : local.hour;
    return '$h:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _loadRadarFrames() async {
    try {
      final uri = Uri.parse(
        'https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/'
        'radar_base_reflectivity_time/ImageServer/query',
      ).replace(queryParameters: const {
        'where': '1=1',
        'outFields': 'idp_validtime',
        'returnGeometry': 'false',
        'orderByFields': 'idp_validtime ASC',
        'resultRecordCount': '500',
        'f': 'json',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) return;
      final unique = <int>{};
      for (final feature in decoded['features'] as List) {
        if (feature is! Map || feature['attributes'] is! Map) continue;
        final raw = (feature['attributes'] as Map)['idp_validtime'];
        final epoch = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
        if (epoch != null && epoch > 0) unique.add(epoch);
      }
      var frames = unique.map(DateTime.fromMillisecondsSinceEpoch).map((e) => e.toUtc()).toList()..sort();
      if (frames.length > 48) frames = frames.sublist(frames.length - 48);
      if (!mounted || frames.isEmpty) return;
      setState(() {
        radarFrames = frames;
        radarCatalogLive = true;
        frame = frames.length - 1;
      });
    } catch (_) {
      if (mounted && radarFrames.isEmpty) setState(() => radarCatalogLive = false);
    }
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (!silent && mounted) setState(() => busy = true);
    try {
      final values = await Future.wait([
        _safe('bridgepoint_flutter_map_state_status_v838'),
        _safe('bridgepoint_flutter_intelligence_map_national_v346', {
          'p_model_key': 'all',
          'p_min_lat': null,
          'p_max_lat': null,
          'p_min_lng': null,
          'p_max_lng': null,
          'p_min_score': 45,
          'p_opportunity_limit': 160,
          'p_signal_limit': 100,
        }),
      ]);
      if (!mounted) return;
      final map = values[1];
      setState(() {
        states = values[0] is Map ? _rows((values[0] as Map)['states']) : const [];
        opportunities = map is Map ? _rows(map['opportunities']) : const [];
        signals = map is Map ? _rows(map['signals']) : const [];
        message = 'Map updated • radar ${radarCatalogLive ? 'frames live' : 'latest-image mode'}';
      });
      if (zoom >= _propertyLoadMinZoom) _scheduleViewport(_controller.camera);
    } finally {
      if (!silent && mounted) setState(() => busy = false);
    }
  }

  void _scheduleViewport(MapCamera camera) {
    _viewportDebounce?.cancel();
    if (camera.zoom < _propertyLoadMinZoom) {
      if (properties.isNotEmpty && mounted) setState(() => properties = const []);
      return;
    }
    final bounds = camera.visibleBounds;
    _viewportDebounce = Timer(const Duration(milliseconds: 360), () => _loadViewport(bounds));
  }

  Future<void> _loadViewport(LatLngBounds bounds) async {
    final serial = ++_viewportSerial;
    if (mounted) setState(() => viewportBusy = true);
    try {
      final values = await Future.wait([
        _safe('bridgepoint_flutter_property_map_viewport_v838', {
          'p_min_lat': bounds.south,
          'p_max_lat': bounds.north,
          'p_min_lng': bounds.west,
          'p_max_lng': bounds.east,
          'p_limit': 300,
        }),
        _safe('bridgepoint_flutter_intelligence_map_national_v346', {
          'p_model_key': 'all',
          'p_min_lat': bounds.south,
          'p_max_lat': bounds.north,
          'p_min_lng': bounds.west,
          'p_max_lng': bounds.east,
          'p_min_score': 45,
          'p_opportunity_limit': 140,
          'p_signal_limit': 90,
        }),
      ]);
      if (!mounted || serial != _viewportSerial) return;
      final propertyPayload = values[0];
      final map = values[1];
      setState(() {
        properties = propertyPayload is Map ? _rows(propertyPayload['properties']) : const [];
        opportunities = map is Map ? _rows(map['opportunities']) : const [];
        signals = map is Map ? _rows(map['signals']) : const [];
        message = '${properties.length} properties • ${opportunities.length} prioritized opportunities • ${signals.length} signals loaded';
      });
    } finally {
      if (mounted && serial == _viewportSerial) setState(() => viewportBusy = false);
    }
  }

  Future<void> _locate() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('disabled');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('denied');
      final p = await Geolocator.getCurrentPosition();
      final point = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        userLocation = point;
        locationMessage = 'Centered on your device. This action does not store your precise location.';
      });
      _controller.move(point, 12.8);
    } catch (_) {
      if (mounted) setState(() => locationMessage = 'Location is unavailable. Check device permission and try again.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Color _opportunityColor(Map<String, dynamic> row) {
    final priority = '${row['priority'] ?? ''}'.toLowerCase();
    final score = _double(row['score'] ?? row['opportunity_score']) ?? 0;
    if (priority.contains('critical') || score >= 85) return _red;
    if (priority.contains('high') || score >= 70) return _amber;
    if (score >= 55) return _cyan;
    return _green;
  }

  String _typeText(Map<String, dynamic> row) =>
      '${row['opportunity_type'] ?? ''} ${row['opportunity_family'] ?? ''} ${row['title'] ?? ''}'.toLowerCase();

  IconData _opportunityIcon(Map<String, dynamic> row) {
    final text = _typeText(row);
    if (text.contains('roof')) return Icons.roofing_rounded;
    if (text.contains('storm') || text.contains('hail') || text.contains('wind')) return Icons.thunderstorm_rounded;
    if (text.contains('fire')) return Icons.local_fire_department_rounded;
    if (text.contains('flood') || text.contains('water')) return Icons.water_drop_rounded;
    if (text.contains('solar')) return Icons.solar_power_rounded;
    if (text.contains('permit')) return Icons.assignment_turned_in_rounded;
    if (text.contains('develop') || text.contains('redevelop')) return Icons.apartment_rounded;
    if (text.contains('invest') || text.contains('sale') || text.contains('transfer')) return Icons.real_estate_agent_rounded;
    return Icons.bolt_rounded;
  }

  IconData _signalIcon(Map<String, dynamic> row) {
    final text = '${row['signal_family'] ?? ''} ${row['signal_name'] ?? ''} ${row['title'] ?? ''}'.toLowerCase();
    if (text.contains('storm') || text.contains('wind') || text.contains('hail')) return Icons.thunderstorm_rounded;
    if (text.contains('fire')) return Icons.local_fire_department_rounded;
    if (text.contains('flood') || text.contains('water')) return Icons.water_drop_outlined;
    if (text.contains('environment') || text.contains('spill')) return Icons.science_outlined;
    if (text.contains('permit')) return Icons.assignment_outlined;
    if (text.contains('owner') || text.contains('transfer') || text.contains('sale')) return Icons.key_rounded;
    return Icons.sensors_rounded;
  }

  Widget _markerShell({required IconData icon, required Color color, double size = 34}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xF20A1726),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .9), width: 1.7),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .24), blurRadius: 8)],
        ),
        child: Icon(icon, size: size * .53, color: color),
      );

  void _details(String kind, String title, Map<String, dynamic> row) {
    String safe(dynamic v) => '${v ?? ''}'.trim();
    final lines = <MapEntry<String, String>>[];
    void add(String label, dynamic value) {
      final text = safe(value);
      if (text.isNotEmpty && text != 'null') lines.add(MapEntry(label, text));
    }
    add('Address', row['full_address']);
    add('Municipality', row['municipality']);
    add('State', row['state_code']);
    if (kind == 'Opportunity') {
      add('Type', row['opportunity_type'] ?? row['opportunity_family']);
      add('Priority', row['priority']);
      add('Score', row['score'] ?? row['opportunity_score']);
      add('Why this property', row['reason'] ?? row['explanation']);
      add('Next action', row['recommended_action']);
    } else if (kind == 'Signal') {
      add('Signal', row['signal_name'] ?? row['title']);
      add('Family', row['signal_family']);
      add('Severity', row['severity']);
      add('Description', row['description']);
    } else if (kind == 'Property') {
      add('Parcel', row['parcel_number']);
      add('Type', row['property_type']);
      add('Land use', row['land_use_description']);
      add('Year built', row['year_built']);
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .68,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            children: [
              Text(kind.toUpperCase(), style: const TextStyle(color: _cyan, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 5),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              for (final line in lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0E2035), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(line.key.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(line.value, style: const TextStyle(height: 1.4)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _stateMarkers() => states.take(60).map((row) {
        final code = '${row['state_code'] ?? ''}'.toUpperCase();
        final center = stateCenters[code];
        if (center == null || _int(row['canonical_property_count']) <= 0) return null;
        final live = '${row['build_status'] ?? ''}'.toUpperCase() == 'LIVE';
        final color = live ? _green : _blue;
        return Marker(
          point: center,
          width: 64,
          height: 42,
          child: GestureDetector(
            onTap: () => _controller.move(center, 7.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xE8071321),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: .72)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(code, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
                Text(_short(row['canonical_property_count']), style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _propertyMarkers() => properties.take(140).map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 24,
          height: 24,
          child: GestureDetector(
            onTap: () => _details('Property', '${row['full_address'] ?? row['municipality'] ?? 'Property'}', row),
            child: _markerShell(icon: Icons.home_work_outlined, color: Colors.white, size: 23),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _opportunityMarkers() => opportunities.take(110).map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        final color = _opportunityColor(row);
        return Marker(
          point: LatLng(lat, lng),
          width: 38,
          height: 38,
          child: GestureDetector(
            onTap: () => _details('Opportunity', '${row['full_address'] ?? row['title'] ?? 'Opportunity'}', row),
            child: _markerShell(icon: _opportunityIcon(row), color: color, size: 35),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _signalMarkers() => signals.take(70).map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () => _details('Signal', '${row['signal_name'] ?? row['title'] ?? 'Signal'}', row),
            child: _markerShell(icon: _signalIcon(row), color: _cyan, size: 28),
          ),
        );
      }).whereType<Marker>().toList();

  Widget _chip(String label, bool selected, ValueChanged<bool> changed, {IconData? icon}) => FilterChip(
        selected: selected,
        avatar: icon == null ? null : Icon(icon, size: 16),
        label: Text(label),
        onSelected: changed,
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mapHeight = size.height.clamp(590.0, 880.0);
    final radarVisible = radar && zoom <= _radarMaxZoom;
    final showStates = zoom <= _stateLabelMaxZoom;
    final propsVisible = showProperties && zoom >= _propertyMarkerMinZoom;
    final oppVisible = showOpportunities && zoom >= _opportunityMarkerMinZoom;
    final sigVisible = showSignals && zoom >= _signalMarkerMinZoom;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Intelligence Map', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text('Radar, properties, signals and prioritized opportunities without covering the map in hundreds of identical symbols.', style: TextStyle(color: _muted, height: 1.45)),
        ])),
        IconButton.filledTonal(onPressed: busy ? null : () => _loadOverview(), icon: const Icon(Icons.refresh_rounded)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _chip('Satellite', satellite, (v) => setState(() => satellite = v), icon: Icons.satellite_alt_rounded),
        _chip('NOAA radar', radar, (v) => setState(() => radar = v), icon: Icons.radar_rounded),
        _chip('Opportunities', showOpportunities, (v) => setState(() => showOpportunities = v), icon: Icons.bolt_rounded),
        _chip('Signals', showSignals, (v) => setState(() => showSignals = v), icon: Icons.sensors_rounded),
        _chip('Properties', showProperties, (v) => setState(() => showProperties = v), icon: Icons.home_work_outlined),
        ActionChip(avatar: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16), label: Text(playing ? 'Pause radar' : 'Play radar'), onPressed: () => setState(() => playing = !playing)),
        ActionChip(avatar: const Icon(Icons.my_location_rounded, size: 16), label: Text(locating ? 'Locating…' : 'My location'), onPressed: locating ? null : _locate),
        ActionChip(label: const Text('United States'), onPressed: () => _controller.move(const LatLng(39.5, -98.35), 4)),
        ActionChip(label: const Text('Connecticut'), onPressed: () => _controller.move(const LatLng(41.60, -72.70), 8.2)),
      ]),
      if (busy || viewportBusy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      if (message != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(message!, style: const TextStyle(color: _green, fontSize: 12))),
      if (locationMessage != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(locationMessage!, style: const TextStyle(color: _muted, fontSize: 12))),
      const SizedBox(height: 10),
      SizedBox(
        height: mapHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: const LatLng(39.5, -98.35),
                initialZoom: 4,
                minZoom: 3,
                maxZoom: 18,
                onMapReady: () => _scheduleViewport(_controller.camera),
                onPositionChanged: (camera, _) {
                  if ((camera.zoom - zoom).abs() > .02 && mounted) setState(() => zoom = camera.zoom);
                  _scheduleViewport(camera);
                },
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
                    urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.bridgepoint.data_studio',
                  ),
                if (radarVisible)
                  TileLayer(
                    key: ValueKey('bp-radar-${radarFrames.isEmpty ? 'latest' : radarTime.millisecondsSinceEpoch}'),
                    wmsOptions: WMSTileLayerOptions(
                      baseUrl: 'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                      layers: const ['0'],
                      format: 'image/png',
                      transparent: true,
                      version: '1.3.0',
                      otherParameters: radarFrames.isEmpty
                          ? const <String, String>{}
                          : {'TIME': '${radarTime.millisecondsSinceEpoch}'},
                    ),
                    maxNativeZoom: 10,
                    userAgentPackageName: 'com.bridgepoint.data_studio',
                  ),
                if (showStates && states.isNotEmpty) MarkerLayer(markers: _stateMarkers()),
                if (propsVisible && properties.isNotEmpty) MarkerLayer(markers: _propertyMarkers()),
                if (sigVisible && signals.isNotEmpty) MarkerLayer(markers: _signalMarkers()),
                if (oppVisible && opportunities.isNotEmpty) MarkerLayer(markers: _opportunityMarkers()),
                if (userLocation != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: userLocation!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(color: _green.withValues(alpha: .22), shape: BoxShape.circle, border: Border.all(color: _green, width: 2)),
                        child: const Icon(Icons.my_location_rounded, color: _green, size: 17),
                      ),
                    ),
                  ]),
                RichAttributionWidget(attributions: const [
                  TextSourceAttribution('NOAA / NWS MRMS'),
                  TextSourceAttribution('Esri / OpenStreetMap'),
                ]),
              ],
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xE8071321), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: .12))),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BRIDGEPOINT MAP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  SizedBox(height: 6),
                  _LegendRow(Icons.roofing_rounded, _amber, 'Opportunity category'),
                  _LegendRow(Icons.sensors_rounded, _cyan, 'Verified signal'),
                  _LegendRow(Icons.home_work_outlined, Colors.white, 'Property'),
                ]),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xE8071321), borderRadius: BorderRadius.circular(12)),
                child: Text('ZOOM ${zoom.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            ),
            if (radar)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(color: const Color(0xEE071321), borderRadius: BorderRadius.circular(15), border: Border.all(color: _cyan.withValues(alpha: .24))),
                  child: Row(children: [
                    Icon(radarVisible ? Icons.radar_rounded : Icons.zoom_in_rounded, color: radarVisible ? _cyan : _amber, size: 20),
                    const SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        !radarVisible
                            ? 'RADAR HIDDEN AT PROPERTY ZOOM'
                            : radarCatalogLive ? 'NOAA MRMS • ${radarFrames.length} FRAMES' : 'NOAA MRMS • LATEST FRAME',
                        style: TextStyle(color: radarVisible ? _cyan : _amber, fontSize: 11.5, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        radarVisible
                            ? 'Radar is active. Clear areas stay transparent; precipitation uses NOAA reflectivity colors.'
                            : 'Zoom out slightly for regional radar. Property evidence remains available separately.',
                        style: const TextStyle(color: _muted, fontSize: 10.5),
                      ),
                    ])),
                    if (radarVisible && radarFrames.isNotEmpty) Text(_clock(radarTime), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 9),
      Text(
        'Showing up to ${oppVisible ? 110 : 0} highest-priority opportunity markers and ${sigVisible ? 70 : 0} signals in the current view to keep the map readable. Zoom in for individual properties.',
        style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
      ),
    ]);
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 9.5)),
        ]),
      );
}
