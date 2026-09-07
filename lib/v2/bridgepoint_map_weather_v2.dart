import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// BridgePoint nationwide property + live hazard map.
///
/// Truth boundary:
/// - observed/source-supported physical events may animate;
/// - alerts/forecasts/model nowcasts stay contextual;
/// - flood depth is never invented where only extent is known;
/// - NOAA GLM is satellite lightning detection, not an exact ground-strike feed.
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
  static const _panel = Color(0xF2071321);
  static const _propertyLoadMinZoom = 6.35;
  static const _stateLabelMaxZoom = 6.15;
  static const _physicalFxMinZoom = 6.8;
  static const _maxAnimatedAnchors = 220;

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
    'outage',
    'snow',
    'fire',
    'roof',
    'permit',
    'transfer',
    'solar',
  ];

  bool satellite = true;
  bool radar = true;
  bool floodExtent = true;
  bool liveFx = true;
  bool properties = true;
  bool opportunities = true;
  bool signals = true;
  bool playing = true;
  bool locating = false;
  bool viewportBusy = false;
  bool _radarFramesVerified = false;
  int frame = 0;
  int _viewportSerial = 0;
  int _liveSerial = 0;
  double _zoom = 4;
  String _filter = 'all';
  List<DateTime> _radarFrames = const [];
  Timer? _radarTimer;
  Timer? _refreshTimer;
  Timer? _liveTimer;
  Timer? _viewportDebounce;
  LatLng? _userLocation;
  LatLngBounds? _visibleBounds;
  List<Map<String, dynamic>> _states = const [];
  List<Map<String, dynamic>> _properties = const [];
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _signals = const [];
  List<Map<String, dynamic>> _liveHazards = const [];
  List<Map<String, dynamic>> _liveLayers = const [];
  String? _message;
  String? _liveTruthNotice;

  @override
  void initState() {
    super.initState();
    _loadRadarFrames();
    _loadOverview();
    _loadLiveScene();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted && radar && playing && _radarFrames.length > 1) {
        setState(
          () => frame = frame >= _radarFrames.length - 1 ? 0 : frame + 1,
        );
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      _loadRadarFrames();
      _loadOverview();
    });
    _liveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _loadLiveScene(_visibleBounds);
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _refreshTimer?.cancel();
    _liveTimer?.cancel();
    _viewportDebounce?.cancel();
    super.dispose();
  }

  DateTime get _radarTime => _radarFrames.isEmpty
      ? DateTime.now().toUtc()
      : _radarFrames[frame.clamp(0, _radarFrames.length - 1)];
  bool get _showRadar => radar;
  bool get _showStates => _zoom <= _stateLabelMaxZoom;
  bool get _showFloodWms => floodExtent && (_filter == 'all' || _filter == 'flood');

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
        'events',
        'continuous_layers',
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
    final end = DateTime.utc(now.year, now.month, now.day, now.hour, minute);
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
    final catalog = values[0] is Map
        ? _rows((values[0] as Map)['markets'])
        : const <Map<String, dynamic>>[];
    final truth = values[1] is Map
        ? _rows((values[1] as Map)['states'])
        : const <Map<String, dynamic>>[];
    final intelligence = values[2];
    final signalMap = values[3];
    setState(() {
      _states = _mergeStates(catalog, truth);
      _opportunities = intelligence is Map
          ? _rows(intelligence['opportunities'])
          : const [];
      _signals = signalMap is Map ? _rows(signalMap['signals']) : const [];
      _message =
          '${_states.length} state markets • ${_opportunities.length} ranked opportunities • ${_signals.length} property signals • ${_liveHazards.length} live hazard records.';
    });
  }

  Future<void> _loadLiveScene([LatLngBounds? bounds]) async {
    final serial = ++_liveSerial;
    final value = await _safe('bridgepoint_live_map_weather_scene_v1997', {
      'p_min_lat': bounds?.south,
      'p_max_lat': bounds?.north,
      'p_min_lng': bounds?.west,
      'p_max_lng': bounds?.east,
      'p_limit': _zoom >= 8 ? 1800 : 900,
    });
    if (!mounted || serial != _liveSerial || value is! Map) return;
    setState(() {
      _liveHazards = _rows(value['events']);
      _liveLayers = _rows(value['continuous_layers']);
      _liveTruthNotice = '${value['truth_notice'] ?? ''}'.trim();
      _message =
          '${_states.length} state markets • ${_opportunities.length} ranked opportunities • ${_signals.length} property signals • ${_liveHazards.length} live hazard records.';
    });
  }

  void _scheduleViewport(MapCamera camera) {
    _visibleBounds = camera.visibleBounds;
    _viewportDebounce?.cancel();
    if (camera.zoom < _propertyLoadMinZoom) {
      if (_properties.isNotEmpty && mounted) setState(() => _properties = const []);
      _viewportDebounce = Timer(
        const Duration(milliseconds: 360),
        () => _loadLiveScene(camera.visibleBounds),
      );
      return;
    }
    _viewportDebounce = Timer(const Duration(milliseconds: 360), () async {
      await Future.wait([
        _loadViewport(camera.visibleBounds),
        _loadLiveScene(camera.visibleBounds),
      ]);
    });
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
        'p_limit': 320,
      }),
      _safe('bridgepoint_flutter_intelligence_map_national_v346', {
        'p_model_key': 'all',
        'p_min_lat': bounds.south,
        'p_max_lat': bounds.north,
        'p_min_lng': bounds.west,
        'p_max_lng': bounds.east,
        'p_min_score': 42,
        'p_opportunity_limit': 240,
        'p_signal_limit': 0,
      }),
      _safe('bridgepoint_flutter_signal_map_v80', {
        'p_min_lat': bounds.south,
        'p_max_lat': bounds.north,
        'p_min_lng': bounds.west,
        'p_max_lng': bounds.east,
        'p_limit': 350,
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
          permission == LocationPermission.deniedForever) return;
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
    if (text.contains('power_outage') || text.contains('power outage') ||
        text.contains('grid outage') || text.contains('utility outage')) return 'outage';
    if (text.contains('hail')) return 'hail';
    if (text.contains('tornado') || text.contains('twister')) return 'tornado';
    if (text.contains('wildfire') || text.contains('brush fire') ||
        text.contains('forest fire')) return 'wildfire';
    if (text.contains('hurricane') || text.contains('tropical cyclone') ||
        text.contains('tropical storm')) return 'hurricane';
    if (text.contains('lightning')) return 'lightning';
    if (text.contains('snow') || text.contains('ice storm') ||
        text.contains('winter weather') || text.contains('blizzard') ||
        text.contains('freez')) return 'snow';
    if (text.contains('flood') || text.contains('fema') ||
        text.contains('surge') || text.contains('inundat')) return 'flood';
    if (text.contains('rain') || text.contains('precip')) return 'rain';
    if (text.contains('wind') || text.contains('gust')) return 'wind';
    if (text.contains('fire') || text.contains('smoke')) return 'fire';
    if (text.contains('roof')) return 'roof';
    if (text.contains('permit') || text.contains('construct') ||
        text.contains('develop')) return 'permit';
    if (text.contains('transfer') || text.contains('sale') ||
        text.contains('ownership') || text.contains('probate') ||
        text.contains('foreclos') || text.contains('invest')) return 'transfer';
    if (text.contains('solar')) return 'solar';
    return 'other';
  }

  String _hazardKind(Map<String, dynamic> row) {
    final h = '${row['hazard_type'] ?? ''}'.trim().toUpperCase();
    if (h == 'POWER_OUTAGE') return 'outage';
    if (h.contains('HAIL')) return 'hail';
    if (h.contains('TORNADO')) return 'tornado';
    if (h == 'WILDFIRE') return 'wildfire';
    if (h.contains('HURRICANE') || h.contains('TROPICAL')) return 'hurricane';
    if (h.contains('LIGHTNING')) return 'lightning';
    if (h.contains('SNOW') || h.contains('ICE')) return 'snow';
    if (h.contains('FLOOD')) return 'flood';
    if (h.contains('RAIN')) return 'rain';
    if (h.contains('WIND')) return 'wind';
    if (h.contains('FIRE')) return 'fire';
    return _kind(row);
  }

  bool _matches(Map<String, dynamic> row) =>
      _filter == 'all' || _kind(row) == _filter;
  bool _hazardMatches(Map<String, dynamic> row) =>
      _filter == 'all' || _hazardKind(row) == _filter;

  IconData _kindIcon(String kind) => switch (kind) {
        'hail' => Icons.grain_rounded,
        'tornado' => Icons.tornado_rounded,
        'wildfire' => Icons.local_fire_department_rounded,
        'hurricane' => Icons.cyclone_rounded,
        'rain' => Icons.water_drop_rounded,
        'flood' => Icons.flood_rounded,
        'wind' => Icons.air_rounded,
        'lightning' => Icons.flash_on_rounded,
        'outage' => Icons.power_off_rounded,
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
        'outage' => 'Grid outages',
        'snow' => 'Snow / ice',
        'fire' => 'Fire',
        'roof' => 'Roofing',
        'permit' => 'Permits',
        'transfer' => 'Transfers',
        'solar' => 'Solar',
        _ => 'Other',
      };

  Color _kindColor(String kind) => switch (kind) {
        'hail' => const Color(0xFFB8F2FF),
        'tornado' => _violet,
        'wildfire' => const Color(0xFFFF5A36),
        'hurricane' => const Color(0xFF7EA5FF),
        'rain' => _blue,
        'flood' => const Color(0xFF42BFFF),
        'wind' => const Color(0xFFC5D5E5),
        'lightning' => _amber,
        'outage' => const Color(0xFFFFE070),
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
    return _stateCenters['${row['state_code'] ?? ''}'.trim().toUpperCase()];
  }

  String _stateMode(Map<String, dynamic> row) {
    final hasAccess = row['has_access'] == true;
    final count = _int(row['canonical_property_count']);
    final status = '${row['data_status'] ?? row['build_status'] ?? ''}'.toUpperCase();
    final eta = row['build_eta'];
    final progress = eta is Map ? _double(eta['progress_pct']) ?? 0 : 0;
    if (hasAccess && (count > 0 || status.contains('LIVE') || status.contains('READY'))) {
      return 'live';
    }
    if (status.contains('BUILD') || status.contains('INGEST') ||
        status.contains('EXPAND') || progress > 0 && progress < 100) return 'building';
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
    if (mode == 'building') return '↻';
    return '•';
  }

  List<LatLng> _ring(dynamic coords) {
    if (coords is! List) return const [];
    return coords.whereType<List>().map((p) {
      if (p.length < 2) return null;
      final lng = _double(p[0]);
      final lat = _double(p[1]);
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }).whereType<LatLng>().toList();
  }

  List<List<LatLng>> _geoPolygons(dynamic geometry) {
    if (geometry is! Map) return const [];
    final type = '${geometry['type'] ?? ''}';
    final coords = geometry['coordinates'];
    if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
      final ring = _ring(coords.first);
      return ring.length >= 3 ? [ring] : const [];
    }
    if (type == 'MultiPolygon' && coords is List) {
      final result = <List<LatLng>>[];
      for (final polygon in coords) {
        if (polygon is List && polygon.isNotEmpty) {
          final ring = _ring(polygon.first);
          if (ring.length >= 3) result.add(ring);
        }
      }
      return result;
    }
    return const [];
  }

  LatLng? _eventCenter(Map<String, dynamic> row) {
    final lat = _double(row['latitude']);
    final lng = _double(row['longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);
    final polygons = _geoPolygons(row['geometry_geojson']);
    if (polygons.isEmpty || polygons.first.isEmpty) return null;
    var a = 0.0;
    var o = 0.0;
    for (final p in polygons.first) {
      a += p.latitude;
      o += p.longitude;
    }
    return LatLng(a / polygons.first.length, o / polygons.first.length);
  }

  DateTime? _eventTime(Map<String, dynamic> row) {
    for (final key in const ['observed_at', 'last_seen_at', 'starts_at']) {
      final v = row[key];
      final dt = v is String ? DateTime.tryParse(v)?.toUtc() : null;
      if (dt != null) return dt;
    }
    return null;
  }

  bool _isRecentObserved(Map<String, dynamic> row) {
    if ('${row['effect_mode'] ?? ''}' != 'OBSERVED_PHYSICAL_OR_SOURCE_GEOMETRY') {
      return false;
    }
    final kind = '${row['observation_kind'] ?? ''}'.toUpperCase();
    final time = _eventTime(row);
    if (time == null) return kind == 'CURRENT_STORM' || kind == 'OBSERVED_INCIDENT';
    final age = DateTime.now().toUtc().difference(time);
    final maxAge = switch (kind) {
      'OBSERVED_REPORT' => const Duration(minutes: 30),
      'OBSERVED_RADAR' => const Duration(minutes: 12),
      'SATELLITE_DETECTION' => const Duration(minutes: 5),
      'CURRENT_STORM' => const Duration(hours: 2),
      'OBSERVED_INCIDENT' => const Duration(hours: 8),
      _ => const Duration(minutes: 30),
    };
    return age >= Duration.zero && age <= maxAge;
  }

  List<Polygon> _hazardPolygons() {
    final result = <Polygon>[];
    for (final row in _liveHazards.where(_hazardMatches)) {
      final kind = _hazardKind(row);
      final color = _kindColor(kind);
      final observed = '${row['effect_mode'] ?? ''}' ==
          'OBSERVED_PHYSICAL_OR_SOURCE_GEOMETRY';
      final alpha = observed ? .22 : .09;
      for (final points in _geoPolygons(row['geometry_geojson'])) {
        result.add(Polygon(
          points: points,
          color: color.withValues(alpha: alpha),
          borderColor: color.withValues(alpha: observed ? .92 : .58),
          borderStrokeWidth: observed ? 2.2 : 1.3,
        ));
      }
    }
    return result;
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
          width: 72,
          height: 44,
          child: GestureDetector(
            onTap: () => _mapController.move(center, 7.7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.4),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .18), blurRadius: 12)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(code, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 3),
                    Text(_stateBadge(row), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
                  ]),
                  if (count > 0)
                    Text('${_short(count)} props', maxLines: 1,
                        style: const TextStyle(color: _muted, fontSize: 6.8, fontWeight: FontWeight.w700)),
                ],
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
          width: 27,
          height: 27,
          child: Tooltip(
            message: '${_kindLabel(kind)} signal • ${row['title'] ?? row['signal_name'] ?? ''}',
            child: Container(
              decoration: BoxDecoration(color: _panel, shape: BoxShape.circle, border: Border.all(color: color, width: 1.3)),
              child: Icon(_kindIcon(kind), color: color, size: 14),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _opportunityMarkers() => _opportunities.where(_matches).map((row) {
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
            message: '${_kindLabel(kind)} opportunity • ${row['full_address'] ?? row['municipality'] ?? ''}',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF5071321),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: priorityColor, width: 2),
                boxShadow: [BoxShadow(color: typeColor.withValues(alpha: .25), blurRadius: 10)],
              ),
              child: Icon(_kindIcon(kind), color: typeColor, size: 19),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  List<Marker> _contextHazardMarkers() {
    final result = <Marker>[];
    for (final row in _liveHazards.where(_hazardMatches)) {
      if (_isRecentObserved(row) && liveFx && _zoom >= _physicalFxMinZoom) continue;
      final center = _eventCenter(row);
      if (center == null) continue;
      final kind = _hazardKind(row);
      final color = _kindColor(kind);
      final obs = '${row['observation_kind'] ?? ''}'.toUpperCase();
      result.add(Marker(
        point: center,
        width: 34,
        height: 34,
        child: Tooltip(
          message: '${row['headline'] ?? row['event_name'] ?? _kindLabel(kind)} • $obs',
          child: Container(
            decoration: BoxDecoration(
              color: _panel,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .84), width: 1.4),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .16), blurRadius: 10)],
            ),
            child: Icon(_kindIcon(kind), color: color, size: 18),
          ),
        ),
      ));
      if (result.length >= 350) break;
    }
    return result;
  }

  List<LatLng> _effectAnchors(Map<String, dynamic> row, String kind) {
    final center = _eventCenter(row);
    if (center == null) return const [];
    if (_zoom < 8.4 || !{'hail', 'rain', 'snow', 'wildfire', 'fire', 'flood'}.contains(kind)) {
      return [center];
    }
    final polygons = _geoPolygons(row['geometry_geojson']);
    if (polygons.isEmpty || polygons.first.length < 8) return [center];
    final ring = polygons.first;
    final anchors = <LatLng>[center];
    for (final fraction in const [.12, .37, .63, .86]) {
      final idx = ((ring.length - 1) * fraction).round().clamp(0, ring.length - 1);
      anchors.add(ring[idx]);
    }
    return anchors;
  }

  List<Marker> _physicalHazardMarkers() {
    if (!liveFx || _zoom < _physicalFxMinZoom) return const [];
    final result = <Marker>[];
    for (final row in _liveHazards.where(_hazardMatches)) {
      if (!_isRecentObserved(row)) continue;
      final kind = _hazardKind(row);
      for (final anchor in _effectAnchors(row, kind)) {
        final size = switch (kind) {
          'hurricane' => 102.0,
          'tornado' => 82.0,
          'wildfire' => 74.0,
          'flood' => 70.0,
          _ => 62.0,
        };
        result.add(Marker(
          point: anchor,
          width: size,
          height: size,
          child: Tooltip(
            message: '${row['headline'] ?? row['event_name'] ?? _kindLabel(kind)}\n${row['truth_rule'] ?? ''}',
            child: RepaintBoundary(
              child: _LiveHazardEffect(
                kind: kind,
                color: _kindColor(kind),
                seed: '${row['hazard_event_id'] ?? row['source_ref'] ?? anchor.hashCode}'.hashCode,
                severity: '${row['severity'] ?? ''}',
              ),
            ),
          ),
        ));
        if (result.length >= _maxAnimatedAnchors) return result;
      }
    }
    return result;
  }

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
          const Text('Reflectivity', style: TextStyle(color: _muted, fontSize: 8.5, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Container(
            width: 128,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [
                Color(0xFF1FBE6B), Color(0xFFE8E84F), Color(0xFFFF9B34),
                Color(0xFFFF3E3E), Color(0xFFB73CFF),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          const Text('light → severe', style: TextStyle(color: _muted, fontSize: 8.5)),
        ],
      );

  Widget _layerStatusPill() {
    final activeKinds = _liveLayers.map((e) => '${e['hazard_type'] ?? ''}').toSet().length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withValues(alpha: .34)),
      ),
      child: Text(
        '${_liveHazards.length} live events • ${_liveLayers.length} source layers • $activeKinds hazard classes',
        style: const TextStyle(color: _cyan, fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyAndIntelMarkers = <Marker>[
      if (_showStates) ..._stateMarkers(),
      if (properties) ..._propertyMarkers(),
      if (signals) ..._signalMarkers(),
      if (opportunities) ..._opportunityMarkers(),
    ];
    final hazardPolygons = _hazardPolygons();
    final contextMarkers = _contextHazardMarkers();
    final physicalMarkers = _physicalHazardMarkers();

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
              selected: liveFx,
              label: const Text('Live 3D FX'),
              avatar: const Icon(Icons.blur_on_rounded, size: 16),
              onSelected: (v) => setState(() => liveFx = v),
            ),
            FilterChip(
              selected: floodExtent,
              label: const Text('Flood extent'),
              avatar: const Icon(Icons.waves_rounded, size: 16),
              onSelected: (v) => setState(() => floodExtent = v),
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
              avatar: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
              label: Text(playing ? 'Pause radar' : 'Play radar'),
              onPressed: () => setState(() => playing = !playing),
            ),
            ActionChip(
              avatar: const Icon(Icons.public_rounded, size: 16),
              label: const Text('U.S. view'),
              onPressed: () => _mapController.move(const LatLng(39.4, -98.3), 4),
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
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: _layerStatusPill()),
          if (viewportBusy) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.5)),
          ],
        ]),
        if (_message != null) ...[
          const SizedBox(height: 7),
          Text(_message!, style: const TextStyle(color: _muted, fontSize: 11.2)),
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
                    maxZoom: 19,
                    onPositionChanged: (camera, hasGesture) {
                      _zoom = camera.zoom;
                      _visibleBounds = camera.visibleBounds;
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
                        urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    if (_showFloodWms)
                      Opacity(
                        opacity: .47,
                        child: TileLayer(
                          wmsOptions: WMSTileLayerOptions(
                            baseUrl: 'https://maps.water.noaa.gov/server/services/nwm/ana_inundation_extent/MapServer/WMSServer?',
                            layers: const ['0'],
                            format: 'image/png',
                            transparent: true,
                            version: '1.3.0',
                          ),
                          maxNativeZoom: 12,
                          userAgentPackageName: 'com.bridgepoint.data_studio',
                        ),
                      ),
                    if (_showRadar)
                      Opacity(
                        opacity: .64,
                        child: TileLayer(
                          key: ValueKey('bp-radar-v2045-${_radarTime.millisecondsSinceEpoch}'),
                          wmsOptions: WMSTileLayerOptions(
                            baseUrl: 'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                            layers: const ['0'],
                            format: 'image/png',
                            transparent: true,
                            version: '1.3.0',
                            otherParameters: {'TIME': _wmsTime(_radarTime)},
                          ),
                          maxNativeZoom: 10,
                          userAgentPackageName: 'com.bridgepoint.data_studio',
                        ),
                      ),
                    if (hazardPolygons.isNotEmpty) PolygonLayer(polygons: hazardPolygons),
                    if (propertyAndIntelMarkers.isNotEmpty) MarkerLayer(markers: propertyAndIntelMarkers),
                    if (contextMarkers.isNotEmpty) MarkerLayer(markers: contextMarkers),
                    if (physicalMarkers.isNotEmpty) MarkerLayer(markers: physicalMarkers),
                    if (_userLocation != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _userLocation!, width: 28, height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: .22),
                              shape: BoxShape.circle,
                              border: Border.all(color: _green, width: 2),
                            ),
                            child: const Icon(Icons.person_pin_circle_rounded, color: _green, size: 17),
                          ),
                        ),
                      ]),
                    RichAttributionWidget(attributions: const [
                      TextSourceAttribution('NOAA / NWS / NHC / NWC'),
                      TextSourceAttribution('NIFC / WFIGS'),
                      TextSourceAttribution('Esri / OpenStreetMap'),
                    ]),
                  ],
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Card(
                    color: _panel,
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('BRIDGEPOINT LIVE PHYSICAL-WORLD MAP',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                          SizedBox(height: 5),
                          Text('SOURCE GEOMETRY • LIVE RADAR • OBSERVED FX • ALERT / FORECAST CONTEXT',
                              style: TextStyle(color: _muted, fontSize: 7.6)),
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
                      color: _panel,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            const Icon(Icons.radar_rounded, color: _cyan, size: 18),
                            const SizedBox(width: 7),
                            Text(
                              'NOAA MRMS • ${_radarFramesVerified ? 'live frames' : 'time window'} • ${_radarFrames.isEmpty ? 'latest' : '${frame + 1}/${_radarFrames.length}'}',
                              style: const TextStyle(color: _cyan, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _radarFrames.length > 1
                                  ? Slider(
                                      value: frame.clamp(0, _radarFrames.length - 1).toDouble(),
                                      min: 0,
                                      max: (_radarFrames.length - 1).toDouble(),
                                      divisions: _radarFrames.length - 1,
                                      onChanged: (v) => setState(() { playing = false; frame = v.round(); }),
                                    )
                                  : const Text('Latest reflectivity', textAlign: TextAlign.center,
                                      style: TextStyle(color: _muted, fontSize: 10.5)),
                            ),
                            IconButton(
                              onPressed: () => setState(() => playing = !playing),
                              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                            ),
                          ]),
                          Align(alignment: Alignment.centerLeft, child: _radarLegend()),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _liveTruthNotice?.isNotEmpty == true
              ? _liveTruthNotice!
              : 'Observed physical effects are source-gated. Warning polygons and model forecasts remain contextual. Modeled flood extent is not claimed as exact measured depth, and satellite lightning detections are not labeled as exact ground strikes.',
          style: const TextStyle(color: _muted, fontSize: 11.2, height: 1.4),
        ),
      ],
    );
  }
}

class _LiveHazardEffect extends StatefulWidget {
  const _LiveHazardEffect({
    required this.kind,
    required this.color,
    required this.seed,
    required this.severity,
  });

  final String kind;
  final Color color;
  final int seed;
  final String severity;

  @override
  State<_LiveHazardEffect> createState() => _LiveHazardEffectState();
}

class _LiveHazardEffectState extends State<_LiveHazardEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    final duration = switch (widget.kind) {
      'lightning' => const Duration(milliseconds: 900),
      'tornado' => const Duration(milliseconds: 1500),
      'hurricane' => const Duration(milliseconds: 2100),
      'wildfire' => const Duration(milliseconds: 1300),
      _ => const Duration(milliseconds: 1800),
    };
    controller = AnimationController(vsync: this, duration: duration)..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        painter: _HazardFxPainter(
          kind: widget.kind,
          color: widget.color,
          seed: widget.seed,
          t: controller.value,
          severity: widget.severity,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HazardFxPainter extends CustomPainter {
  const _HazardFxPainter({
    required this.kind,
    required this.color,
    required this.seed,
    required this.t,
    required this.severity,
  });

  final String kind;
  final Color color;
  final int seed;
  final double t;
  final String severity;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final c = Offset(size.width / 2, size.height / 2);
    final severe = severity.toUpperCase() == 'EXTREME' ||
        severity.toUpperCase() == 'SEVERE';
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: .30),
        color.withValues(alpha: .05),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: c, radius: size.shortestSide * .48));
    canvas.drawCircle(c, size.shortestSide * .47, glow);

    switch (kind) {
      case 'hail':
        _hail(canvas, size, rng, severe ? 18 : 12);
        break;
      case 'rain':
        _rain(canvas, size, rng, severe ? 20 : 13);
        break;
      case 'snow':
        _snow(canvas, size, rng, 14);
        break;
      case 'lightning':
        _lightning(canvas, size, rng);
        break;
      case 'tornado':
        _tornado(canvas, size);
        break;
      case 'hurricane':
        _hurricane(canvas, size, rng);
        break;
      case 'wildfire':
      case 'fire':
        _fire(canvas, size, rng);
        break;
      case 'flood':
        _flood(canvas, size);
        break;
      case 'wind':
        _wind(canvas, size, rng);
        break;
      case 'outage':
        _outage(canvas, size, rng);
        break;
      default:
        canvas.drawCircle(c, 5 + 2 * math.sin(t * math.pi * 2).abs(),
            Paint()..color = color.withValues(alpha: .9));
    }
  }

  void _hail(Canvas canvas, Size s, math.Random rng, int count) {
    for (var i = 0; i < count; i++) {
      final phase = (t + rng.nextDouble()) % 1;
      final x = rng.nextDouble() * s.width;
      final y = phase * s.height;
      final r = 1.4 + rng.nextDouble() * 2.8;
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = Color.lerp(Colors.white, color, .45)!.withValues(alpha: .88));
      canvas.drawCircle(Offset(x - .6, y - .7), r * .35,
          Paint()..color = Colors.white.withValues(alpha: .85));
    }
  }

  void _rain(Canvas canvas, Size s, math.Random rng, int count) {
    final p = Paint()
      ..color = color.withValues(alpha: .78)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final phase = (t * 1.35 + rng.nextDouble()) % 1;
      final x = rng.nextDouble() * s.width;
      final y = phase * s.height;
      canvas.drawLine(Offset(x, y), Offset(x - 3.5, y + 10), p);
    }
  }

  void _snow(Canvas canvas, Size s, math.Random rng, int count) {
    for (var i = 0; i < count; i++) {
      final phase = (t * .65 + rng.nextDouble()) % 1;
      final x = (rng.nextDouble() * s.width + math.sin((phase + i) * math.pi * 2) * 4)
          .clamp(0.0, s.width);
      final y = phase * s.height;
      canvas.drawCircle(Offset(x, y), 1.2 + rng.nextDouble() * 2,
          Paint()..color = Colors.white.withValues(alpha: .82));
    }
  }

  void _lightning(Canvas canvas, Size s, math.Random rng) {
    final pulse = ((t * 5) % 1) < .18;
    if (!pulse) return;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .98)
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(s.width * .48, 2);
    var x = s.width * .48;
    var y = 2.0;
    for (var i = 0; i < 6; i++) {
      x += (rng.nextDouble() - .5) * 13;
      y += s.height / 7;
      path.lineTo(x, y);
      if (i == 2 || i == 4) {
        final branch = Path()..moveTo(x, y);
        branch.lineTo(x + (rng.nextDouble() - .5) * 18, y + 12);
        canvas.drawPath(branch, p..strokeWidth = 1.2);
        p.strokeWidth = 2.3;
      }
    }
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(s.width * .5, s.height * .5), s.shortestSide * .38,
        Paint()..color = color.withValues(alpha: .13));
  }

  void _tornado(Canvas canvas, Size s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final y = s.height * (.15 + i * .09);
      final width = s.width * (.78 - i * .075);
      final phase = t * math.pi * 2 + i * .7;
      final rect = Rect.fromCenter(
        center: Offset(s.width / 2 + math.sin(phase) * 3, y),
        width: width,
        height: 7 + i * .5,
      );
      p.color = Color.lerp(Colors.white, color, .55)!.withValues(alpha: .74 - i * .055);
      canvas.drawArc(rect, phase, math.pi * 1.35, false, p);
    }
    final dust = Paint()..color = const Color(0xFFB79D82).withValues(alpha: .28);
    canvas.drawOval(Rect.fromCenter(center: Offset(s.width / 2, s.height * .86), width: s.width * .65, height: 10), dust);
  }

  void _hurricane(Canvas canvas, Size s, math.Random rng) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    final c = Offset(s.width / 2, s.height / 2);
    for (var arm = 0; arm < 4; arm++) {
      final path = Path();
      for (var i = 0; i < 26; i++) {
        final f = i / 25;
        final a = t * math.pi * 2 + arm * math.pi / 2 + f * math.pi * 2.1;
        final r = 5 + f * s.shortestSide * .42;
        final point = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r * .65);
        if (i == 0) path.moveTo(point.dx, point.dy); else path.lineTo(point.dx, point.dy);
      }
      p.color = Color.lerp(Colors.white, color, .45)!.withValues(alpha: .68);
      canvas.drawPath(path, p);
    }
    canvas.drawCircle(c, 4.2, Paint()..color = const Color(0xFF071321));
    final rain = Paint()..color = color.withValues(alpha: .38)..strokeWidth = .9;
    for (var i = 0; i < 10; i++) {
      final x = rng.nextDouble() * s.width;
      final y = ((rng.nextDouble() + t) % 1) * s.height;
      canvas.drawLine(Offset(x, y), Offset(x - 2, y + 7), rain);
    }
  }

  void _fire(Canvas canvas, Size s, math.Random rng) {
    final baseY = s.height * .78;
    for (var i = 0; i < 9; i++) {
      final x = s.width * (.18 + rng.nextDouble() * .64);
      final phase = (t + rng.nextDouble()) % 1;
      final h = 13 + rng.nextDouble() * 23;
      final y = baseY - phase * 13;
      final rect = Rect.fromCenter(center: Offset(x, y), width: 9 + rng.nextDouble() * 8, height: h);
      final flame = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFFD35C), Color(0xFFFF663A), Color(0x00FF3D2E)],
        ).createShader(rect);
      canvas.drawOval(rect, flame);
    }
    final smoke = Paint()..color = Colors.blueGrey.withValues(alpha: .16);
    for (var i = 0; i < 5; i++) {
      final phase = (t * .45 + rng.nextDouble()) % 1;
      canvas.drawCircle(
        Offset(s.width * (.3 + rng.nextDouble() * .4), s.height * .55 - phase * 24),
        5 + phase * 7,
        smoke,
      );
    }
  }

  void _flood(Canvas canvas, Size s) {
    final water = Paint()
      ..shader = LinearGradient(colors: [
        color.withValues(alpha: .12),
        color.withValues(alpha: .38),
        color.withValues(alpha: .12),
      ]).createShader(Rect.fromLTWH(0, s.height * .52, s.width, s.height * .38));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(3, s.height * .53, s.width - 6, s.height * .33), const Radius.circular(16)),
      water,
    );
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 3; i++) {
      final f = (t + i / 3) % 1;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(s.width / 2, s.height * .69), width: 8 + f * s.width * .78, height: 3 + f * 9),
        p..color = Colors.white.withValues(alpha: .55 * (1 - f)),
      );
    }
  }

  void _wind(Canvas canvas, Size s, math.Random rng) {
    final p = Paint()
      ..color = color.withValues(alpha: .72)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final phase = (t + rng.nextDouble()) % 1;
      final y = 7 + rng.nextDouble() * (s.height - 14);
      final x = phase * (s.width + 24) - 18;
      canvas.drawLine(Offset(x, y), Offset(x + 14 + rng.nextDouble() * 12, y - 2), p);
    }
  }

  void _outage(Canvas canvas, Size s, math.Random rng) {
    final flicker = ((t * 6) % 1) > .24;
    final p = Paint()..strokeWidth = 1.2;
    final nodes = <Offset>[];
    for (var i = 0; i < 10; i++) {
      nodes.add(Offset(6 + rng.nextDouble() * (s.width - 12), 6 + rng.nextDouble() * (s.height - 12)));
    }
    p.color = color.withValues(alpha: .22);
    for (var i = 1; i < nodes.length; i++) canvas.drawLine(nodes[i - 1], nodes[i], p);
    for (var i = 0; i < nodes.length; i++) {
      final on = flicker && i % 3 != 0;
      canvas.drawCircle(nodes[i], 2.4, Paint()..color = on ? color.withValues(alpha: .9) : Colors.black.withValues(alpha: .8));
    }
  }

  @override
  bool shouldRepaint(covariant _HazardFxPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.kind != kind || oldDelegate.color != color;
}
