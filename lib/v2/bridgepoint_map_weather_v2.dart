import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointMapWeatherV2 extends StatefulWidget {
  const BridgePointMapWeatherV2({super.key});

  @override
  State<BridgePointMapWeatherV2> createState() => _BridgePointMapWeatherV2State();
}

class _BridgePointMapWeatherV2State extends State<BridgePointMapWeatherV2> {
  final MapController _mapController = MapController();

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF071321);
  static const _propertyLoadMinZoom = 6.35;
  static const _stateLabelMaxZoom = 6.15;
  static const _radarMaxHonestZoom = 10.5;

  static const Map<String, LatLng> _stateCenters = {
    'AL': LatLng(32.806671, -86.791130), 'AK': LatLng(61.370716, -152.404419),
    'AZ': LatLng(33.729759, -111.431221), 'AR': LatLng(34.969704, -92.373123),
    'CA': LatLng(36.116203, -119.681564), 'CO': LatLng(39.059811, -105.311104),
    'CT': LatLng(41.597782, -72.755371), 'DE': LatLng(39.318523, -75.507141),
    'DC': LatLng(38.897438, -77.026817), 'FL': LatLng(27.766279, -81.686783),
    'GA': LatLng(33.040619, -83.643074), 'HI': LatLng(21.094318, -157.498337),
    'ID': LatLng(44.240459, -114.478828), 'IL': LatLng(40.349457, -88.986137),
    'IN': LatLng(39.849426, -86.258278), 'IA': LatLng(42.011539, -93.210526),
    'KS': LatLng(38.526600, -96.726486), 'KY': LatLng(37.668140, -84.670067),
    'LA': LatLng(31.169546, -91.867805), 'ME': LatLng(44.693947, -69.381927),
    'MD': LatLng(39.063946, -76.802101), 'MA': LatLng(42.230171, -71.530106),
    'MI': LatLng(43.326618, -84.536095), 'MN': LatLng(45.694454, -93.900192),
    'MS': LatLng(32.741646, -89.678696), 'MO': LatLng(38.456085, -92.288368),
    'MT': LatLng(46.921925, -110.454353), 'NE': LatLng(41.125370, -98.268082),
    'NV': LatLng(38.313515, -117.055374), 'NH': LatLng(43.452492, -71.563896),
    'NJ': LatLng(40.298904, -74.521011), 'NM': LatLng(34.840515, -106.248482),
    'NY': LatLng(42.165726, -74.948051), 'NC': LatLng(35.630066, -79.806419),
    'ND': LatLng(47.528912, -99.784012), 'OH': LatLng(40.388783, -82.764915),
    'OK': LatLng(35.565342, -96.928917), 'OR': LatLng(44.572021, -122.070938),
    'PA': LatLng(40.590752, -77.209755), 'RI': LatLng(41.680893, -71.511780),
    'SC': LatLng(33.856892, -80.945007), 'SD': LatLng(44.299782, -99.438828),
    'TN': LatLng(35.747845, -86.692345), 'TX': LatLng(31.054487, -97.563461),
    'UT': LatLng(40.150032, -111.862434), 'VT': LatLng(44.045876, -72.710686),
    'VA': LatLng(37.769337, -78.169968), 'WA': LatLng(47.400902, -121.490494),
    'WV': LatLng(38.491226, -80.954453), 'WI': LatLng(44.268543, -89.616508),
    'WY': LatLng(42.755966, -107.302490),
  };

  bool satellite = true;
  bool radar = true;
  bool stateReadiness = true;
  bool properties = true;
  bool opportunities = true;
  bool signals = true;
  bool playing = true;
  bool busy = false;
  bool viewportBusy = false;
  bool locating = false;
  int frame = 0;
  double _zoom = 4;
  int _viewportSerial = 0;
  List<DateTime> _radarFrames = const [];
  bool _radarFramesLive = false;
  Timer? _radarTimer;
  Timer? _viewportDebounce;
  Timer? _refreshTimer;
  LatLng? _userLocation;
  String? _message;
  String? _locationMessage;

  List<Map<String, dynamic>> _states = const [];
  List<Map<String, dynamic>> _properties = const [];
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _signals = const [];

  @override
  void initState() {
    super.initState();
    _loadRadarFrames();
    _loadOverview();
    // 850ms was faster than NOAA WMS tiles could reliably paint on phones.
    // 2.6s leaves each frame visible long enough to load and be understood.
    _radarTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && radar && playing && _radarFrames.length > 1) {
        setState(() => frame = frame >= _radarFrames.length - 1 ? 0 : frame + 1);
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      _loadOverview(silent: true);
      _loadRadarFrames();
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _viewportDebounce?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  DateTime get _radarTime => _radarFrames.isEmpty
      ? DateTime.now().toUtc()
      : _radarFrames[frame.clamp(0, _radarFrames.length - 1)];

  bool get _showRadar => radar && _zoom <= _radarMaxHonestZoom;
  bool get _showStates => stateReadiness && _zoom <= _stateLabelMaxZoom;

  String _wmsTime(DateTime value) {
    final u = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}.${three(u.millisecond)}Z';
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
        'resultRecordCount': '300',
        'f': 'json',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) return;
      final now = DateTime.now().toUtc();
      final byBucket = <int, DateTime>{};
      for (final rawFeature in decoded['features'] as List) {
        if (rawFeature is! Map || rawFeature['attributes'] is! Map) continue;
        final raw = (rawFeature['attributes'] as Map)['idp_validtime'];
        final epoch = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
        if (epoch == null || epoch <= 0) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
        if (dt.isBefore(now.subtract(const Duration(hours: 5))) || dt.isAfter(now.add(const Duration(minutes: 15)))) continue;
        byBucket[epoch ~/ 300000] = dt;
      }
      var frames = byBucket.values.toList()..sort();
      if (frames.length > 18) frames = frames.sublist(frames.length - 18);
      if (frames.isEmpty || !mounted) return;
      setState(() {
        _radarFrames = frames;
        _radarFramesLive = true;
        frame = frames.length - 1;
      });
    } catch (_) {
      if (mounted && _radarFrames.isEmpty) setState(() => _radarFramesLive = false);
    }
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    }
    if (value is Map) {
      for (final key in const ['states', 'properties', 'opportunities', 'signals', 'points', 'items', 'rows', 'results']) {
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

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${out.toString()}';
  }

  String _clock(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0 ? 12 : local.hour > 12 ? local.hour - 12 : local.hour;
    return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
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
          'p_min_score': 42,
          'p_opportunity_limit': 160,
          'p_signal_limit': 110,
        }),
      ]);
      final statePayload = values[0];
      final mapPayload = values[1];
      if (!mounted) return;
      setState(() {
        _states = statePayload is Map ? _rows(statePayload['states']) : const [];
        _opportunities = mapPayload is Map ? _rows(mapPayload['opportunities']) : const [];
        _signals = mapPayload is Map ? _rows(mapPayload['signals']) : const [];
        _message = 'Zoom into a state for property-level detail. Markers are intentionally limited to the highest-value visible intelligence so the map stays readable.';
      });
      if (_zoom >= _propertyLoadMinZoom) _scheduleViewport(_mapController.camera);
    } finally {
      if (!silent && mounted) setState(() => busy = false);
    }
  }

  void _scheduleViewport(MapCamera camera) {
    _viewportDebounce?.cancel();
    if (camera.zoom < _propertyLoadMinZoom) {
      if (_properties.isNotEmpty && mounted) setState(() => _properties = const []);
      return;
    }
    final bounds = camera.visibleBounds;
    _viewportDebounce = Timer(const Duration(milliseconds: 420), () => _loadViewport(bounds));
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
          'p_limit': 260,
        }),
        _safe('bridgepoint_flutter_intelligence_map_national_v346', {
          'p_model_key': 'all',
          'p_min_lat': bounds.south,
          'p_max_lat': bounds.north,
          'p_min_lng': bounds.west,
          'p_max_lng': bounds.east,
          'p_min_score': 42,
          'p_opportunity_limit': 180,
          'p_signal_limit': 120,
        }),
      ]);
      if (!mounted || serial != _viewportSerial) return;
      final propertiesPayload = values[0];
      final intelligencePayload = values[1];
      setState(() {
        _properties = propertiesPayload is Map ? _rows(propertiesPayload['properties']) : const [];
        _opportunities = intelligencePayload is Map ? _rows(intelligencePayload['opportunities']) : const [];
        _signals = intelligencePayload is Map ? _rows(intelligencePayload['signals']) : const [];
        _message = '${_properties.length} properties • ${_opportunities.length} prioritized opportunities • ${_signals.length} signals in this view';
      });
    } finally {
      if (mounted && serial == _viewportSerial) setState(() => viewportBusy = false);
    }
  }

  Future<void> _recenterToUser() async {
    if (locating) return;
    setState(() {
      locating = true;
      _locationMessage = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw StateError('Location disabled');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw StateError('Location denied');
      final pos = await Geolocator.getCurrentPosition();
      final point = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _userLocation = point;
        _locationMessage = 'Centered on this device. BridgePoint does not store this precise location from the map action.';
      });
      _mapController.move(point, 12.8);
    } catch (_) {
      if (mounted) setState(() => _locationMessage = 'Could not read this device location. Check browser/device permission and try again.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Color _stateColor(Map<String, dynamic> row) {
    final status = '${row['build_status'] ?? ''}'.toUpperCase();
    if (_int(row['opportunity_count']) > 0 || status == 'LIVE') return _green;
    if (_int(row['signal_count']) > 0 || status == 'SCORING') return _cyan;
    if (_int(row['canonical_property_count']) > 0) return _blue;
    return _muted;
  }

  Color _opportunityColor(Map<String, dynamic> row) {
    final priority = '${row['priority'] ?? ''}'.toLowerCase();
    final score = _double(row['score'] ?? row['opportunity_score']) ?? 0;
    if (priority.contains('critical') || score >= 85) return _red;
    if (priority.contains('high') || score >= 70) return _amber;
    if (score >= 55) return _cyan;
    return _green;
  }

  String _opportunityText(Map<String, dynamic> row) =>
      '${row['opportunity_type'] ?? ''} ${row['opportunity_family'] ?? ''} ${row['title'] ?? ''}'.toLowerCase();

  IconData _opportunityIcon(Map<String, dynamic> row) {
    final text = _opportunityText(row);
    if (text.contains('roof')) return Icons.roofing_rounded;
    if (text.contains('storm') || text.contains('hail') || text.contains('wind')) return Icons.thunderstorm_rounded;
    if (text.contains('fire')) return Icons.local_fire_department_rounded;
    if (text.contains('flood') || text.contains('water')) return Icons.water_damage_outlined;
    if (text.contains('solar')) return Icons.solar_power_rounded;
    if (text.contains('invest') || text.contains('sale') || text.contains('transfer')) return Icons.real_estate_agent_rounded;
    if (text.contains('develop')) return Icons.construction_rounded;
    if (text.contains('permit')) return Icons.fact_check_outlined;
    return Icons.location_searching_rounded;
  }

  String _opportunityLabel(Map<String, dynamic> row) {
    final text = _opportunityText(row);
    if (text.contains('roof')) return 'Roofing';
    if (text.contains('storm') || text.contains('hail') || text.contains('wind')) return 'Storm';
    if (text.contains('fire')) return 'Fire';
    if (text.contains('flood') || text.contains('water')) return 'Water';
    if (text.contains('solar')) return 'Solar';
    if (text.contains('invest') || text.contains('sale') || text.contains('transfer')) return 'Investor';
    if (text.contains('develop')) return 'Development';
    if (text.contains('permit')) return 'Permit';
    return 'Opportunity';
  }

  void _showDetails(String kind, String title, Map<String, dynamic> row) {
    String text(dynamic value) => '${value ?? ''}'.trim();
    final details = <MapEntry<String, String>>[];
    void add(String label, dynamic value) {
      final v = text(value);
      if (v.isNotEmpty && v != 'null') details.add(MapEntry(label, v));
    }
    add('Address', row['full_address']);
    add('Municipality', row['municipality']);
    add('County', row['county']);
    add('State', row['state_code']);
    if (kind == 'Property') {
      add('Parcel', row['parcel_number']);
      add('Property type', row['property_type']);
      add('Year built', row['year_built']);
    } else if (kind == 'Opportunity') {
      add('Type', _opportunityLabel(row));
      add('Priority', row['priority']);
      add('Score', row['score'] ?? row['opportunity_score']);
      add('Why it ranked', row['reason'] ?? row['explanation']);
      add('Recommended action', row['recommended_action']);
      add('Signals', row['distinct_signal_count'] ?? row['signal_count']);
    } else if (kind == 'Signal') {
      add('Signal', row['signal_name'] ?? row['title']);
      add('Severity', row['severity']);
      add('Description', row['description']);
      add('Detected', row['detected_at']);
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .7,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              Text(kind.toUpperCase(), style: const TextStyle(color: _cyan, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              for (final item in details)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0D2034), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.key.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(item.value, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _stateMarkers() => _states.map((row) {
        final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
        final center = _stateCenters[code];
        if (center == null || _int(row['canonical_property_count']) <= 0) return null;
        final color = _stateColor(row);
        return Marker(
          point: center,
          width: 62,
          height: 43,
          child: GestureDetector(
            onTap: () => _mapController.move(center, 7.7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xF2071321),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.4),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .10), blurRadius: 10)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(code, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900)),
                Text('${_short(row['canonical_property_count'])} properties', maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 7.3, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _propertyMarkers() => _properties.map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 22,
          height: 22,
          child: GestureDetector(
            onTap: () => _showDetails('Property', '${row['full_address'] ?? 'Property'}', row),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xEA071321),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white.withValues(alpha: .85), width: 1.1),
              ),
              child: const Icon(Icons.home_rounded, size: 12, color: Colors.white),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _opportunityMarkers() => _opportunities.map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        final color = _opportunityColor(row);
        return Marker(
          point: LatLng(lat, lng),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showDetails('Opportunity', '${row['full_address'] ?? row['title'] ?? 'Opportunity'}', row),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF5071321),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 9)],
              ),
              child: Icon(_opportunityIcon(row), color: color, size: 19),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _signalMarkers() => _signals.map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 20,
          height: 20,
          child: GestureDetector(
            onTap: () => _showDetails('Signal', '${row['signal_name'] ?? row['title'] ?? 'Signal'}', row),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF2071321),
                shape: BoxShape.circle,
                border: Border.all(color: _cyan.withValues(alpha: .9), width: 1.5),
              ),
              child: const Icon(Icons.bolt_rounded, color: _cyan, size: 12),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  Widget _legend() => Card(
        color: const Color(0xEE071321),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('BRIDGEPOINT MAP', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            _legendRow(Icons.home_rounded, Colors.white, 'Property'),
            _legendRow(Icons.location_searching_rounded, _amber, 'Opportunity'),
            _legendRow(Icons.bolt_rounded, _cyan, 'Signal'),
            _legendRow(Icons.cloud_rounded, _blue, 'NOAA radar'),
          ]),
        ),
      );

  Widget _legendRow(IconData icon, Color color, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _filter(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => FilterChip(
        selected: value,
        avatar: Icon(icon, size: 16, color: value ? _cyan : _muted),
        label: Text(label),
        onSelected: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final readyStates = _states.where((r) => _int(r['canonical_property_count']) > 0).length;
    final height = MediaQuery.sizeOf(context).height;
    final mapHeight = math.max(520.0, math.min(820.0, height * .68));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Property Map & Weather', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text('Properties, prioritized opportunities, verified signals and regional NOAA radar in one view.', style: TextStyle(color: _muted, height: 1.4)),
          ])),
          IconButton.filledTonal(onPressed: busy ? null : () => _loadOverview(), icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh map'),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _Metric('STATES', '$readyStates', _blue),
          _Metric('PROPERTIES IN VIEW', '${_properties.length}', Colors.white),
          _Metric('OPPORTUNITIES', '${_opportunities.length}', _amber),
          _Metric('SIGNALS', '${_signals.length}', _cyan),
          _Metric('RADAR FRAMES', '${_radarFrames.length}', _green),
        ]),
        if (busy || viewportBusy) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
        if (_message != null) ...[const SizedBox(height: 7), Text(_message!, style: const TextStyle(color: _muted, fontSize: 11.5))],
        if (_locationMessage != null) ...[const SizedBox(height: 4), Text(_locationMessage!, style: const TextStyle(color: _muted, fontSize: 11.5))],
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _filter('Satellite', Icons.satellite_alt_outlined, satellite, (v) => setState(() => satellite = v)),
          _filter('Radar', Icons.cloud_outlined, radar, (v) => setState(() => radar = v)),
          _filter('States', Icons.map_outlined, stateReadiness, (v) => setState(() => stateReadiness = v)),
          _filter('Properties', Icons.home_outlined, properties, (v) => setState(() => properties = v)),
          _filter('Opportunities', Icons.location_searching_rounded, opportunities, (v) => setState(() => opportunities = v)),
          _filter('Signals', Icons.bolt_outlined, signals, (v) => setState(() => signals = v)),
          ActionChip(avatar: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 17), label: Text(playing ? 'Pause radar' : 'Play radar'), onPressed: () => setState(() => playing = !playing)),
          ActionChip(avatar: const Icon(Icons.my_location_rounded, size: 17), label: Text(locating ? 'Locating…' : 'My location'), onPressed: locating ? null : _recenterToUser),
          ActionChip(avatar: const Icon(Icons.flag_outlined, size: 17), label: const Text('Connecticut'), onPressed: () => _mapController.move(const LatLng(41.60, -72.70), 8.2)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(39.50, -98.35),
                  initialZoom: 4,
                  minZoom: 3,
                  maxZoom: 18,
                  onMapReady: () => _scheduleViewport(_mapController.camera),
                  onPositionChanged: (camera, hasGesture) {
                    if ((camera.zoom - _zoom).abs() > .02 && mounted) setState(() => _zoom = camera.zoom);
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
                  if (_showRadar)
                    TileLayer(
                      key: ValueKey(_radarFrames.isEmpty ? 'bp-radar-latest-v3' : 'bp-radar-${_radarTime.millisecondsSinceEpoch}'),
                      wmsOptions: WMSTileLayerOptions(
                        baseUrl: 'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                        layers: const ['0'],
                        format: 'image/png',
                        transparent: true,
                        version: '1.3.0',
                        otherParameters: _radarFrames.isEmpty ? const <String, String>{} : {'TIME': _wmsTime(_radarTime)},
                      ),
                      maxNativeZoom: 10,
                      userAgentPackageName: 'com.bridgepoint.data_studio',
                    ),
                  if (_showStates && _states.isNotEmpty) MarkerLayer(markers: _stateMarkers()),
                  if (properties && _properties.isNotEmpty) MarkerLayer(markers: _propertyMarkers()),
                  if (signals && _signals.isNotEmpty) MarkerLayer(markers: _signalMarkers()),
                  if (opportunities && _opportunities.isNotEmpty) MarkerLayer(markers: _opportunityMarkers()),
                  if (_userLocation != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _userLocation!,
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(color: _green.withValues(alpha: .22), shape: BoxShape.circle, border: Border.all(color: _green, width: 2)),
                          child: const Icon(Icons.person_pin_circle_rounded, color: _green, size: 17),
                        ),
                      ),
                    ]),
                  RichAttributionWidget(attributions: const [TextSourceAttribution('NOAA / NWS MRMS'), TextSourceAttribution('Esri / OpenStreetMap')]),
                ],
              ),
              Positioned(left: 10, top: 10, child: _legend()),
              Positioned(
                right: 10,
                top: 10,
                child: Card(
                  color: const Color(0xEE071321),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Text('ZOOM ${_zoom.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              if (radar && !_showRadar)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 92,
                  child: const Card(
                    color: Color(0xF2071321),
                    child: Padding(
                      padding: EdgeInsets.all(9),
                      child: Text('Radar is regional weather context. Zoom out to view reflectivity; BridgePoint keeps property-specific weather evidence separate from radar pixels.', style: TextStyle(color: _muted, fontSize: 10.5, height: 1.35)),
                    ),
                  ),
                ),
              if (radar)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Card(
                    color: const Color(0xF2071321),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                      child: Row(children: [
                        const Icon(Icons.radar_rounded, color: _cyan, size: 18),
                        const SizedBox(width: 7),
                        Text(_radarFramesLive ? 'NOAA • ${_radarFrames.length} frames' : 'NOAA • latest', style: const TextStyle(color: _cyan, fontSize: 11.5, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _radarFrames.length > 1
                              ? Slider(
                                  value: frame.clamp(0, _radarFrames.length - 1).toDouble(),
                                  min: 0,
                                  max: (_radarFrames.length - 1).toDouble(),
                                  divisions: _radarFrames.length - 1,
                                  onChanged: (value) => setState(() {
                                    playing = false;
                                    frame = value.round();
                                  }),
                                )
                              : const Text('Latest reflectivity', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 10.5)),
                        ),
                        Text(_radarFrames.isEmpty ? 'LATEST' : _clock(_radarTime), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 9),
        const Text('Radar source: NOAA/NWS MRMS. A blank radar area can mean no measurable reflectivity in the current view; it is not used as proof that a specific property was or was not damaged.', style: TextStyle(color: _muted, fontSize: 11.2, height: 1.4)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(11), border: Border.all(color: color.withValues(alpha: .16))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5)),
        ]),
      );
}
