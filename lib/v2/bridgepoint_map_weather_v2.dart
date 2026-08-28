import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Clean V2 nationwide map. State status is always visible at U.S. zoom,
// property intelligence stays authorization-aware, and weather can be filtered
// without turning the marker vocabulary into a wall of symbols.
class BridgePointMapWeatherV2 extends StatefulWidget {
  const BridgePointMapWeatherV2({super.key});

  @override
  State<BridgePointMapWeatherV2> createState() =>
      _BridgePointMapWeatherV2State();
}

class _BridgePointMapWeatherV2State extends State<BridgePointMapWeatherV2> {
  final MapController _mapController = MapController();

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _violet = Color(0xFF9B7BFF);
  static const _muted = Color(0xFFB5C6D9);
  static const _propertyLoadMinZoom = 6.35;
  static const _stateLabelMaxZoom = 6.15;

  static const Map<String, LatLng> _stateCenters = {
    'AL': LatLng(32.806671, -86.791130),
    'AK': LatLng(61.370716, -152.404419),
    'AZ': LatLng(33.729759, -111.431221),
    'AR': LatLng(34.969704, -92.373123),
    'CA': LatLng(36.116203, -119.681564),
    'CO': LatLng(39.059811, -105.311104),
    'CT': LatLng(41.597782, -72.755371),
    'DE': LatLng(39.318523, -75.507141),
    'DC': LatLng(38.897438, -77.026817),
    'FL': LatLng(27.766279, -81.686783),
    'GA': LatLng(33.040619, -83.643074),
    'HI': LatLng(21.094318, -157.498337),
    'ID': LatLng(44.240459, -114.478828),
    'IL': LatLng(40.349457, -88.986137),
    'IN': LatLng(39.849426, -86.258278),
    'IA': LatLng(42.011539, -93.210526),
    'KS': LatLng(38.526600, -96.726486),
    'KY': LatLng(37.668140, -84.670067),
    'LA': LatLng(31.169546, -91.867805),
    'ME': LatLng(44.693947, -69.381927),
    'MD': LatLng(39.063946, -76.802101),
    'MA': LatLng(42.230171, -71.530106),
    'MI': LatLng(43.326618, -84.536095),
    'MN': LatLng(45.694454, -93.900192),
    'MS': LatLng(32.741646, -89.678696),
    'MO': LatLng(38.456085, -92.288368),
    'MT': LatLng(46.921925, -110.454353),
    'NE': LatLng(41.125370, -98.268082),
    'NV': LatLng(38.313515, -117.055374),
    'NH': LatLng(43.452492, -71.563896),
    'NJ': LatLng(40.298904, -74.521011),
    'NM': LatLng(34.840515, -106.248482),
    'NY': LatLng(42.165726, -74.948051),
    'NC': LatLng(35.630066, -79.806419),
    'ND': LatLng(47.528912, -99.784012),
    'OH': LatLng(40.388783, -82.764915),
    'OK': LatLng(35.565342, -96.928917),
    'OR': LatLng(44.572021, -122.070938),
    'PA': LatLng(40.590752, -77.209755),
    'RI': LatLng(41.680893, -71.511780),
    'SC': LatLng(33.856892, -80.945007),
    'SD': LatLng(44.299782, -99.438828),
    'TN': LatLng(35.747845, -86.692345),
    'TX': LatLng(31.054487, -97.563461),
    'UT': LatLng(40.150032, -111.862434),
    'VT': LatLng(44.045876, -72.710686),
    'VA': LatLng(37.769337, -78.169968),
    'WA': LatLng(47.400902, -121.490494),
    'WV': LatLng(38.491226, -80.954453),
    'WI': LatLng(44.268543, -89.616508),
    'WY': LatLng(42.755966, -107.302490),
  };

  static const _filters = <String>[
    'all',
    'hail',
    'tornado',
    'wildfire',
    'hurricane',
    'rain',
    'flood',
    'wind',
    'lightning',
    'snow',
    'fire',
    'roof',
    'permit',
    'transfer',
    'solar',
  ];

  bool satellite = true;
  bool radar = true;
  bool properties = true;
  bool opportunities = true;
  bool signals = true;
  bool playing = true;
  bool locating = false;
  bool viewportBusy = false;
  bool _radarFramesVerified = false;
  int frame = 0;
  int _viewportSerial = 0;
  double _zoom = 4;
  String _filter = 'all';
  List<DateTime> _radarFrames = const [];
  Timer? _radarTimer;
  Timer? _refreshTimer;
  Timer? _viewportDebounce;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _states = const [];
  List<Map<String, dynamic>> _properties = const [];
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _signals = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadRadarFrames();
    _loadOverview();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted && radar && playing && _radarFrames.length > 1) {
        setState(
          () => frame = frame >= _radarFrames.length - 1 ? 0 : frame + 1,
        );
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        _loadRadarFrames();
        _loadOverview();
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

  DateTime get _radarTime => _radarFrames.isEmpty
      ? DateTime.now().toUtc()
      : _radarFrames[frame.clamp(0, _radarFrames.length - 1)];
  bool get _showRadar => radar;
  bool get _showStates => _zoom <= _stateLabelMaxZoom;

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in const [
        'states',
        'markets',
        'properties',
        'opportunities',
        'signals',
        'items',
        'rows',
        'results',
      ]) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) => value is num
      ? value.round()
      : int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  double? _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
  String _short(dynamic value) {
    final n = _int(value);
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 1 : 2)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}K';
    }
    return '$n';
  }

  String _wmsTime(DateTime value) {
    final u = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}.${three(u.millisecond)}Z';
  }

  void _installRadarFallback() {
    final now = DateTime.now().toUtc();
    final minute = now.minute - (now.minute % 5);
    final end = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      minute,
    );
    final frames = List<DateTime>.generate(
      24,
      (i) => end.subtract(Duration(minutes: (23 - i) * 5)),
    );
    if (!mounted) return;
    setState(() {
      _radarFrames = frames;
      _radarFramesVerified = false;
      frame = frames.length - 1;
    });
  }

  Future<void> _loadRadarFrames() async {
    try {
      final uri = Uri.parse(
        'https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer/query',
      ).replace(queryParameters: const {
        'where': '1=1',
        'outFields': 'idp_validtime',
        'returnGeometry': 'false',
        'orderByFields': 'idp_validtime ASC',
        'resultRecordCount': '300',
        'f': 'json',
      });
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _installRadarFallback();
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) {
        _installRadarFallback();
        return;
      }
      final now = DateTime.now().toUtc();
      final buckets = <int, DateTime>{};
      for (final f in decoded['features'] as List) {
        if (f is! Map || f['attributes'] is! Map) continue;
        final raw = (f['attributes'] as Map)['idp_validtime'];
        final epoch = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
        if (epoch == null || epoch <= 0) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
        if (dt.isBefore(now.subtract(const Duration(hours: 4))) ||
            dt.isAfter(now.add(const Duration(minutes: 15)))) {
          continue;
        }
        buckets[epoch ~/ 300000] = dt;
      }
      var frames = buckets.values.toList()..sort();
      if (frames.length > 24) frames = frames.sublist(frames.length - 24);
      if (frames.length < 2) {
        _installRadarFallback();
        return;
      }
      if (!mounted) return;
      setState(() {
        _radarFrames = frames;
        _radarFramesVerified = true;
        frame = frames.length - 1;
      });
    } catch (_) {
      _installRadarFallback();
    }
  }

  List<Map<String, dynamic>> _mergeStates(
    List<Map<String, dynamic>> catalog,
    List<Map<String, dynamic>> truth,
  ) {
    final byCode = <String, Map<String, dynamic>>{};
    for (final row in catalog) {
      final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
      if (code.isNotEmpty) byCode[code] = Map<String, dynamic>.from(row);
    }
    for (final row in truth) {
      final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
      if (code.isEmpty) continue;
      byCode[code] = <String, dynamic>{...?byCode[code], ...row};
    }
    return byCode.values.toList()
      ..sort((a, b) => '${a['state_code']}'.compareTo('${b['state_code']}'));
  }

  Future<void> _loadOverview() async {
    final values = await Future.wait([
      _safe('bridgepoint_flutter_geographic_catalog_v77'),
      _safe('bridgepoint_flutter_map_state_status_v838'),
      _safe('bridgepoint_flutter_intelligence_map_national_v346', {
        'p_model_key': 'all',
        'p_min_lat': null,
        'p_max_lat': null,
        'p_min_lng': null,
        'p_max_lng': null,
        'p_min_score': 42,
        'p_opportunity_limit': 240,
        'p_signal_limit': 0,
      }),
      _safe('bridgepoint_flutter_signal_map_v80', {
        'p_min_lat': null,
        'p_max_lat': null,
        'p_min_lng': null,
        'p_max_lng': null,
        'p_limit': 300,
      }),
    ]);
    if (!mounted) return;
    final catalog = values[0] is Map ? _rows((values[0] as Map)['markets']) : const <Map<String, dynamic>>[];
    final truth = values[1] is Map ? _rows((values[1] as Map)['states']) : const <Map<String, dynamic>>[];
    final intelligence = values[2];
    final signalMap = values[3];
    setState(() {
      _states = _mergeStates(catalog, truth);
      _opportunities = intelligence is Map
          ? _rows(intelligence['opportunities'])
          : const [];
      _signals = signalMap is Map ? _rows(signalMap['signals']) : const [];
      _message =
          '${_states.length} state markets visible • ${_opportunities.length} ranked opportunities • ${_signals.length} supporting signals. Zoom into a state for property detail.';
    });
  }

  void _scheduleViewport(MapCamera camera) {
    _viewportDebounce?.cancel();
    if (camera.zoom < _propertyLoadMinZoom) {
      if (_properties.isNotEmpty && mounted) {
        setState(() => _properties = const []);
      }
      return;
    }
    _viewportDebounce = Timer(
      const Duration(milliseconds: 420),
      () => _loadViewport(camera.visibleBounds),
    );
  }

  Future<void> _loadViewport(LatLngBounds bounds) async {
    final serial = ++_viewportSerial;
    if (mounted) setState(() => viewportBusy = true);
    final values = await Future.wait([
      _safe('bridgepoint_flutter_property_map_viewport_v838', {
        'p_min_lat': bounds.south,
        'p_max_lat': bounds.north,
        'p_min_lng': bounds.west,
        'p_max_lng': bounds.east,
        'p_limit': 280,
      }),
      _safe('bridgepoint_flutter_intelligence_map_national_v346', {
        'p_model_key': 'all',
        'p_min_lat': bounds.south,
        'p_max_lat': bounds.north,
        'p_min_lng': bounds.west,
        'p_max_lng': bounds.east,
        'p_min_score': 42,
        'p_opportunity_limit': 220,
        'p_signal_limit': 0,
      }),
      _safe('bridgepoint_flutter_signal_map_v80', {
        'p_min_lat': bounds.south,
        'p_max_lat': bounds.north,
        'p_min_lng': bounds.west,
        'p_max_lng': bounds.east,
        'p_limit': 300,
      }),
    ]);
    if (!mounted || serial != _viewportSerial) return;
    final p = values[0];
    final i = values[1];
    final s = values[2];
    setState(() {
      _properties = p is Map ? _rows(p['properties']) : const [];
      _opportunities = i is Map ? _rows(i['opportunities']) : const [];
      _signals = s is Map ? _rows(s['signals']) : const [];
      viewportBusy = false;
    });
  }

  Future<void> _recenterToUser() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = point);
      _mapController.move(point, 12.8);
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  String _intelText(Map<String, dynamic> row) => row.values
      .whereType<String>()
      .join(' ')
      .toLowerCase();

  String _kind(Map<String, dynamic> row) {
    final text = _intelText(row);
    if (text.contains('hail')) return 'hail';
    if (text.contains('tornado') || text.contains('twister')) return 'tornado';
    if (text.contains('wildfire') ||
        text.contains('brush fire') ||
        text.contains('forest fire')) return 'wildfire';
    if (text.contains('hurricane') ||
        text.contains('tropical cyclone') ||
        text.contains('tropical storm')) return 'hurricane';
    if (text.contains('lightning')) return 'lightning';
    if (text.contains('snow') ||
        text.contains('ice storm') ||
        text.contains('winter weather') ||
        text.contains('blizzard') ||
        text.contains('freez')) return 'snow';
    if (text.contains('flood') ||
        text.contains('fema') ||
        text.contains('surge') ||
        text.contains('water')) return 'flood';
    if (text.contains('rain') || text.contains('precip')) return 'rain';
    if (text.contains('wind') || text.contains('gust')) return 'wind';
    if (text.contains('fire') || text.contains('smoke')) return 'fire';
    if (text.contains('roof')) return 'roof';
    if (text.contains('permit') ||
        text.contains('construct') ||
        text.contains('develop')) return 'permit';
    if (text.contains('transfer') ||
        text.contains('sale') ||
        text.contains('ownership') ||
        text.contains('probate') ||
        text.contains('foreclos') ||
        text.contains('invest')) return 'transfer';
    if (text.contains('solar')) return 'solar';
    return 'other';
  }

  bool _matches(Map<String, dynamic> row) =>
      _filter == 'all' || _kind(row) == _filter;

  IconData _kindIcon(String kind) => switch (kind) {
        'hail' => Icons.ac_unit_rounded,
        'tornado' => Icons.filter_tilt_shift_rounded,
        'wildfire' => Icons.local_fire_department_rounded,
        'hurricane' => Icons.rotate_right_rounded,
        'rain' => Icons.water_drop_rounded,
        'flood' => Icons.flood_rounded,
        'wind' => Icons.air_rounded,
        'lightning' => Icons.flash_on_rounded,
        'snow' => Icons.ac_unit_rounded,
        'fire' => Icons.local_fire_department_rounded,
        'roof' => Icons.roofing_rounded,
        'permit' => Icons.construction_rounded,
        'transfer' => Icons.swap_horizontal_circle_rounded,
        'solar' => Icons.solar_power_rounded,
        _ => Icons.circle,
      };

  String _kindLabel(String kind) => switch (kind) {
        'all' => 'All',
        'hail' => 'Hail',
        'tornado' => 'Tornado',
        'wildfire' => 'Wildfire',
        'hurricane' => 'Hurricane',
        'rain' => 'Rain',
        'flood' => 'Flood',
        'wind' => 'Wind',
        'lightning' => 'Lightning',
        'snow' => 'Snow / ice',
        'fire' => 'Fire',
        'roof' => 'Roofing',
        'permit' => 'Permits',
        'transfer' => 'Transfers',
        'solar' => 'Solar',
        _ => 'Other',
      };

  Color _kindColor(String kind) => switch (kind) {
        'hail' => const Color(0xFF8DE8FF),
        'tornado' => _violet,
        'wildfire' => _red,
        'hurricane' => const Color(0xFF7EA5FF),
        'rain' => _blue,
        'flood' => const Color(0xFF42BFFF),
        'wind' => const Color(0xFFC5D5E5),
        'lightning' => _amber,
        'snow' => Colors.white,
        'fire' => _red,
        'roof' => _amber,
        'permit' => const Color(0xFFFF9557),
        'transfer' => const Color(0xFFFF78C6),
        'solar' => _green,
        _ => _cyan,
      };

  Color _priorityColor(Map<String, dynamic> row) {
    final priority = '${row['priority'] ?? ''}'.toLowerCase();
    final score = _double(row['score'] ?? row['opportunity_score']) ?? 0;
    if (priority.contains('critical') || score >= 85) return _red;
    if (priority.contains('high') || score >= 70) return _amber;
    if (score >= 55) return _cyan;
    return _green;
  }

  LatLng? _stateCenter(Map<String, dynamic> row) {
    final lat = _double(row['center_lat']);
    final lng = _double(row['center_lng']);
    if (lat != null && lng != null) return LatLng(lat, lng);
    final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
    return _stateCenters[code];
  }

  String _stateMode(Map<String, dynamic> row) {
    final hasAccess = row['has_access'] == true;
    final count = _int(row['canonical_property_count']);
    final status =
        '${row['data_status'] ?? row['build_status'] ?? ''}'.toUpperCase();
    final eta = row['build_eta'];
    final progress = eta is Map ? _double(eta['progress_pct']) ?? 0 : 0;
    if (hasAccess && (count > 0 || status.contains('LIVE') || status.contains('READY'))) {
      return 'live';
    }
    if (status.contains('BUILD') ||
        status.contains('INGEST') ||
        status.contains('EXPAND') ||
        progress > 0 && progress < 100) return 'building';
    if (row['available_for_purchase'] == true) return 'available';
    return 'planned';
  }

  Color _stateColor(String mode) => switch (mode) {
        'live' => _green,
        'building' => _cyan,
        'available' => _amber,
        _ => const Color(0xFF73869A),
      };

  String _stateBadge(Map<String, dynamic> row) {
    final mode = _stateMode(row);
    if (mode == 'live') return '✓';
    if (mode == 'available') return '+';
    if (mode == 'building') {
      final eta = row['build_eta'];
      final progress = eta is Map ? _double(eta['progress_pct']) : null;
      if (progress != null && progress > 0) return '${progress.round()}%';
      return '↻';
    }
    return '•';
  }

  void _showStateDetails(Map<String, dynamic> row, LatLng center) {
    final code = '${row['state_code'] ?? ''}'.toUpperCase();
    final eta = row['build_eta'];
    final progress = eta is Map ? _double(eta['progress_pct']) : null;
    final phase = eta is Map
        ? '${eta['current_phase'] ?? row['build_status'] ?? row['data_status'] ?? 'Planned'}'
        : '${row['build_status'] ?? row['data_status'] ?? 'Planned'}';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _stateMode(row) == 'live'
                        ? Icons.verified_rounded
                        : _stateMode(row) == 'building'
                            ? Icons.sync_rounded
                            : _stateMode(row) == 'available'
                                ? Icons.add_circle_outline_rounded
                                : Icons.schedule_rounded,
                    color: _stateColor(_stateMode(row)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${row['state_name'] ?? code} • $code',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Status: ${row['data_status'] ?? row['build_status'] ?? 'Planned'}\n'
                'Properties loaded: ${_int(row['canonical_property_count'])}\n'
                '${progress == null ? '' : 'Build progress: ${progress.toStringAsFixed(1)}%\n'}'
                'Current phase: $phase\n'
                'Your access: ${row['has_access'] == true ? 'Available now' : row['available_for_purchase'] == true ? 'State add-on available' : 'Visible / building'}',
                style: const TextStyle(color: _muted, height: 1.55),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _mapController.move(center, 7.7);
                },
                icon: const Icon(Icons.zoom_in_map_rounded),
                label: Text('Open $code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _stateMarkers() => _states.map((row) {
        final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
        final center = _stateCenter(row);
        if (code.isEmpty || center == null) return null;
        final mode = _stateMode(row);
        final color = _stateColor(mode);
        final count = _int(row['canonical_property_count']);
        return Marker(
          point: center,
          width: 68,
          height: 42,
          child: Tooltip(
            message:
                '${row['state_name'] ?? code} • ${row['data_status'] ?? row['build_status'] ?? mode}',
            child: GestureDetector(
              onTap: () => _showStateDetails(row, center),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xF2071321),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: .15), blurRadius: 9),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          code,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _stateBadge(row),
                          style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    if (count > 0)
                      Text(
                        '${_short(count)} properties',
                        maxLines: 1,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 6.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
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
          width: 19,
          height: 19,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xEA071321),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Icon(Icons.home_rounded, size: 10, color: Colors.white),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _signalMarkers() => _signals.where(_matches).map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        final kind = _kind(row);
        final color = _kindColor(kind);
        return Marker(
          point: LatLng(lat, lng),
          width: 28,
          height: 28,
          child: Tooltip(
            message: '${_kindLabel(kind)} signal • ${row['title'] ?? row['signal_name'] ?? ''}',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF2071321),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.4),
              ),
              child: Icon(_kindIcon(kind), color: color, size: 15),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _opportunityMarkers() =>
      _opportunities.where(_matches).map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        final kind = _kind(row);
        final typeColor = _kindColor(kind);
        final priorityColor = _priorityColor(row);
        return Marker(
          point: LatLng(lat, lng),
          width: 37,
          height: 37,
          child: Tooltip(
            message:
                '${_kindLabel(kind)} opportunity • ${row['full_address'] ?? row['municipality'] ?? ''}',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF5071321),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: priorityColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withValues(alpha: .24),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(_kindIcon(kind), color: typeColor, size: 19),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  Widget _weatherFilterBar() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _filters) ...[
              ChoiceChip(
                selected: _filter == filter,
                avatar: filter == 'all'
                    ? const Icon(Icons.tune_rounded, size: 15)
                    : Icon(_kindIcon(filter), size: 15),
                label: Text(_kindLabel(filter)),
                onSelected: (_) => setState(() => _filter = filter),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      );

  Widget _radarLegend() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Reflectivity',
            style: TextStyle(
              color: _muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 128,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1FBE6B),
                  Color(0xFFE8E84F),
                  Color(0xFFFF9B34),
                  Color(0xFFFF3E3E),
                  Color(0xFFB73CFF),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'light → severe',
            style: TextStyle(color: _muted, fontSize: 8.5),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (_showStates) ..._stateMarkers(),
      if (properties) ..._propertyMarkers(),
      if (signals) ..._signalMarkers(),
      if (opportunities) ..._opportunityMarkers(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            FilterChip(
              selected: satellite,
              label: const Text('Satellite'),
              avatar: const Icon(Icons.satellite_alt_rounded, size: 16),
              onSelected: (v) => setState(() => satellite = v),
            ),
            FilterChip(
              selected: radar,
              label: const Text('Radar'),
              avatar: const Icon(Icons.radar_rounded, size: 16),
              onSelected: (v) => setState(() => radar = v),
            ),
            FilterChip(
              selected: properties,
              label: const Text('Properties'),
              avatar: const Icon(Icons.home_rounded, size: 16),
              onSelected: (v) => setState(() => properties = v),
            ),
            FilterChip(
              selected: opportunities,
              label: const Text('Opportunities'),
              avatar: const Icon(Icons.crop_square_rounded, size: 16),
              onSelected: (v) => setState(() => opportunities = v),
            ),
            FilterChip(
              selected: signals,
              label: const Text('Signals'),
              avatar: const Icon(Icons.circle_outlined, size: 16),
              onSelected: (v) => setState(() => signals = v),
            ),
            ActionChip(
              avatar: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 16,
              ),
              label: Text(playing ? 'Pause weather' : 'Play weather'),
              onPressed: () => setState(() => playing = !playing),
            ),
            ActionChip(
              avatar: const Icon(Icons.public_rounded, size: 16),
              label: const Text('U.S. view'),
              onPressed: () => _mapController.move(
                const LatLng(39.4, -98.3),
                4,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.my_location_rounded, size: 16),
              label: Text(locating ? 'Locating…' : 'My location'),
              onPressed: locating ? null : _recenterToUser,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _weatherFilterBar(),
        if (_message != null) ...[
          const SizedBox(height: 7),
          Text(
            _message!,
            style: const TextStyle(color: _muted, fontSize: 11.2),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 720,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.4, -98.3),
                    initialZoom: 4,
                    minZoom: 3,
                    maxZoom: 18,
                    onPositionChanged: (camera, hasGesture) {
                      _zoom = camera.zoom;
                      if (hasGesture) _scheduleViewport(camera);
                      if (mounted) setState(() {});
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
                        urlTemplate:
                            'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    if (_showRadar)
                      TileLayer(
                        key: ValueKey(
                          'bp-radar-v974-${_radarTime.millisecondsSinceEpoch}',
                        ),
                        wmsOptions: WMSTileLayerOptions(
                          baseUrl:
                              'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                          layers: const ['0'],
                          format: 'image/png',
                          transparent: true,
                          version: '1.3.0',
                          otherParameters: {'TIME': _wmsTime(_radarTime)},
                        ),
                        maxNativeZoom: 10,
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    if (markers.isNotEmpty) MarkerLayer(markers: markers),
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 28,
                            height: 28,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: .22),
                                shape: BoxShape.circle,
                                border: Border.all(color: _green, width: 2),
                              ),
                              child: const Icon(
                                Icons.person_pin_circle_rounded,
                                color: _green,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('NOAA / NWS MRMS'),
                        TextSourceAttribution('Esri / OpenStreetMap'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Card(
                    color: const Color(0xEE071321),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'BRIDGEPOINT INTELLIGENCE MAP',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'STATE PILL = COVERAGE  •  SQUARE = OPPORTUNITY  •  CIRCLE = SIGNAL',
                            style: TextStyle(color: _muted, fontSize: 7.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (viewportBusy)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: Card(
                      color: Color(0xEE071321),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                            SizedBox(width: 6),
                            Text('Updating view', style: TextStyle(fontSize: 9)),
                          ],
                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.radar_rounded,
                                  color: _cyan,
                                  size: 18,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'NOAA • ${_radarFramesVerified ? 'live frames' : 'time window'} • ${_radarFrames.isEmpty ? 'latest' : '${frame + 1}/${_radarFrames.length}'}',
                                  style: const TextStyle(
                                    color: _cyan,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _radarFrames.length > 1
                                      ? Slider(
                                          value: frame
                                              .clamp(0, _radarFrames.length - 1)
                                              .toDouble(),
                                          min: 0,
                                          max: (_radarFrames.length - 1).toDouble(),
                                          divisions: _radarFrames.length - 1,
                                          onChanged: (v) => setState(() {
                                            playing = false;
                                            frame = v.round();
                                          }),
                                        )
                                      : const Text(
                                          'Latest reflectivity',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => playing = !playing),
                                  icon: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _radarLegend(),
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
        const SizedBox(height: 9),
        const Text(
          'NOAA/NWS MRMS base reflectivity is animated weather context. BridgePoint does not treat radar pixels as proof of property damage. State pills remain visible nationwide so customers can see what is live, building, available, or planned.',
          style: TextStyle(color: _muted, fontSize: 11.2, height: 1.4),
        ),
      ],
    );
  }
}
