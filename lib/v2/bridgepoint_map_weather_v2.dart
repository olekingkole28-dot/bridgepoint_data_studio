import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointMapWeatherV2 extends StatefulWidget {
  const BridgePointMapWeatherV2({super.key});

  @override
  State<BridgePointMapWeatherV2> createState() =>
      _BridgePointMapWeatherV2State();
}

class _BridgePointMapWeatherV2State extends State<BridgePointMapWeatherV2> {
  final MapController _mapController = MapController();

  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);
  static const _panel = Color(0xFF071321);
  static const _radarMaxHonestZoom = 10.5;
  static const _propertyLoadMinZoom = 7.4;

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

  bool radar = true;
  bool satellite = true;
  bool opportunities = true;
  bool signals = true;
  bool properties = true;
  bool stateReadiness = true;
  bool playing = true;
  bool busy = false;
  bool viewportBusy = false;
  bool locating = false;
  int frame = 48;
  double _zoom = 4.0;
  Timer? _radarTimer;
  Timer? _viewportDebounce;
  Timer? _overviewRefreshTimer;
  int _viewportSerial = 0;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _signals = const [];
  List<Map<String, dynamic>> _properties = const [];
  List<Map<String, dynamic>> _states = const [];
  String? _message;
  String? _locationMessage;

  List<DateTime> get frames {
    final now = DateTime.now().toUtc();
    final rounded = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 5) * 5,
    );
    return List.generate(
      49,
      (i) => rounded.subtract(Duration(minutes: (48 - i) * 5)),
    );
  }

  DateTime get radarTime => frames[frame.clamp(0, 48)];
  bool get _showRawRadar => radar && _zoom <= _radarMaxHonestZoom;
  bool get _showStateReadiness => stateReadiness && _zoom < _propertyLoadMinZoom;

  @override
  void initState() {
    super.initState();
    _loadOverview();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted && radar && playing) {
        setState(() => frame = frame >= 48 ? 0 : frame + 1);
      }
    });
    _overviewRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) _loadOverview(silent: true);
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _viewportDebounce?.cancel();
    _overviewRefreshTimer?.cancel();
    super.dispose();
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
        'opportunities',
        'signals',
        'points',
        'properties',
        'states',
        'items',
        'rows',
      ]) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (busy && !silent) return;
    if (!silent && mounted) {
      setState(() {
        busy = true;
        _message = null;
      });
    }

    try {
      final values = await Future.wait([
        _safe(
          'bridgepoint_flutter_intelligence_map_national_v346',
          {
            'p_model_key': 'all',
            'p_min_lat': null,
            'p_max_lat': null,
            'p_min_lng': null,
            'p_max_lng': null,
            'p_min_score': 45,
            'p_opportunity_limit': 300,
            'p_signal_limit': 180,
          },
        ),
        _safe('bridgepoint_flutter_map_state_status_v838'),
      ]);

      var nextOpportunities = <Map<String, dynamic>>[];
      var nextSignals = <Map<String, dynamic>>[];
      var nextStates = <Map<String, dynamic>>[];
      var usedLegacyCt = false;

      final national = values[0];
      if (national is Map) {
        nextOpportunities = _rows(national['opportunities']);
        nextSignals = _rows(national['signals']);
      }

      final statePayload = values[1];
      if (statePayload is Map) {
        nextStates = _rows(statePayload['states']);
      }

      if (nextOpportunities.isEmpty) {
        final legacy = await _safe(
          'bridgepoint_flutter_intelligence_map',
          {
            'p_model_key': 'all',
            'p_min_lat': null,
            'p_max_lat': null,
            'p_min_lng': null,
            'p_max_lng': null,
            'p_min_score': null,
            'p_limit': 500,
          },
        );
        if (legacy is Map) {
          nextOpportunities = _rows(legacy['points']);
          usedLegacyCt = nextOpportunities.isNotEmpty;
        }
      }

      if (!mounted) return;
      setState(() {
        _opportunities = nextOpportunities;
        _signals = nextSignals;
        _states = nextStates;
        if (!silent) {
          final activeStates = nextStates
              .where((row) => _int(row['canonical_property_count']) > 0)
              .length;
          _message = usedLegacyCt
              ? 'National state readiness is live; Connecticut opportunities are using the proven fallback while other state intelligence comes online.'
              : 'Progressive U.S. map live • $activeStates states currently report a property foundation. Opportunities and signals appear automatically as each state produces them.';
        }
      });

      if (_zoom >= _propertyLoadMinZoom) {
        _scheduleViewportLoad(_mapController.camera);
      }
    } finally {
      if (!silent && mounted) setState(() => busy = false);
    }
  }

  void _scheduleViewportLoad(MapCamera camera) {
    _viewportDebounce?.cancel();
    if (camera.zoom < _propertyLoadMinZoom) {
      if (_properties.isNotEmpty && mounted) {
        setState(() => _properties = const []);
      }
      return;
    }
    final bounds = camera.visibleBounds;
    _viewportDebounce = Timer(
      const Duration(milliseconds: 475),
      () => _loadViewport(bounds),
    );
  }

  Future<void> _loadViewport(LatLngBounds bounds) async {
    final serial = ++_viewportSerial;
    if (mounted) setState(() => viewportBusy = true);

    try {
      final values = await Future.wait([
        _safe(
          'bridgepoint_flutter_property_map_viewport_v838',
          {
            'p_min_lat': bounds.south,
            'p_max_lat': bounds.north,
            'p_min_lng': bounds.west,
            'p_max_lng': bounds.east,
            'p_limit': 350,
          },
        ),
        _safe(
          'bridgepoint_flutter_intelligence_map_national_v346',
          {
            'p_model_key': 'all',
            'p_min_lat': bounds.south,
            'p_max_lat': bounds.north,
            'p_min_lng': bounds.west,
            'p_max_lng': bounds.east,
            'p_min_score': 35,
            'p_opportunity_limit': 350,
            'p_signal_limit': 220,
          },
        ),
      ]);

      if (!mounted || serial != _viewportSerial) return;

      var nextProperties = <Map<String, dynamic>>[];
      var nextOpportunities = <Map<String, dynamic>>[];
      var nextSignals = <Map<String, dynamic>>[];

      if (values[0] is Map) {
        nextProperties = _rows((values[0] as Map)['properties']);
      }
      if (values[1] is Map) {
        nextOpportunities = _rows((values[1] as Map)['opportunities']);
        nextSignals = _rows((values[1] as Map)['signals']);
      }

      setState(() {
        _properties = nextProperties;
        if (nextOpportunities.isNotEmpty || nextSignals.isNotEmpty) {
          _opportunities = nextOpportunities;
          _signals = nextSignals;
        }
        _message = nextProperties.isEmpty
            ? 'This viewport does not have map-ready property points yet. State readiness remains visible and will update automatically as ingestion/geocoding advances.'
            : '${nextProperties.length} property points loaded in this viewport • ${nextOpportunities.length} opportunities • ${nextSignals.length} active signals.';
      });
    } finally {
      if (mounted && serial == _viewportSerial) {
        setState(() => viewportBusy = false);
      }
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
      if (!enabled) throw StateError('Location services are disabled.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _userLocation = point;
        _locationMessage =
            'Recentered locally. Precise device location was not sent to BridgePoint.';
      });
      _mapController.move(point, 14);
    } catch (e) {
      if (mounted) setState(() => _locationMessage = '$e');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  String _clock(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.hour}:$minute';
  }

  dynamic _score(Map<String, dynamic> row) =>
      row['score'] ?? row['opportunity_score'] ?? row['final_score'];

  Color _opportunityColor(Map<String, dynamic> row) {
    final priority =
        '${row['priority'] ?? row['opportunity_priority'] ?? ''}'.toLowerCase();
    final score = _double(_score(row)) ?? 0;
    if (priority.contains('critical') || score >= 85) return _red;
    if (priority.contains('high') || score >= 70) return _amber;
    if (score >= 55) return _cyan;
    return _green;
  }

  IconData _opportunityIcon(Map<String, dynamic> row) {
    final text =
        '${row['opportunity_type'] ?? ''} ${row['top_signal_type'] ?? ''} ${row['title'] ?? ''}'
            .toLowerCase();
    if (text.contains('storm') ||
        text.contains('wind') ||
        text.contains('hail') ||
        text.contains('weather')) {
      return Icons.thunderstorm_rounded;
    }
    if (text.contains('fire')) return Icons.local_fire_department_rounded;
    if (text.contains('flood') || text.contains('water')) {
      return Icons.water_rounded;
    }
    if (text.contains('solar')) return Icons.solar_power_rounded;
    if (text.contains('roof')) return Icons.roofing_rounded;
    if (text.contains('invest') ||
        text.contains('transfer') ||
        text.contains('sale')) {
      return Icons.real_estate_agent_rounded;
    }
    if (text.contains('develop') || text.contains('redevelop')) {
      return Icons.apartment_rounded;
    }
    if (text.contains('permit')) return Icons.description_outlined;
    return Icons.location_on_rounded;
  }

  Color _stateColor(Map<String, dynamic> row) {
    final status = '${row['build_status'] ?? ''}'.toUpperCase();
    final opportunities = _int(row['opportunity_count']);
    final signalsCount = _int(row['signal_count']);
    if (status == 'LIVE') return _green;
    if (opportunities > 0 || signalsCount > 0 || status == 'SCORING') return _cyan;
    if (_int(row['canonical_property_count']) > 0) return _blue;
    return _muted;
  }

  void _showPayload(String title, Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: ListView(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in row.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${entry.key.replaceAll('_', ' ')}: ${entry.value}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Marker> _stateMarkers() => _states.map((row) {
        final code = '${row['state_code'] ?? ''}'.toUpperCase();
        final center = _stateCenters[code];
        if (center == null || _int(row['canonical_property_count']) <= 0) {
          return null;
        }
        final color = _stateColor(row);
        return Marker(
          point: center,
          width: 50,
          height: 42,
          child: Tooltip(
            message:
                '$code • ${row['build_status'] ?? 'BUILDING'} • ${_number(row['canonical_property_count'])} properties',
            child: GestureDetector(
              onTap: () {
                _showPayload(
                  '${row['state_name'] ?? code} • ${row['build_status'] ?? 'BUILDING'}',
                  row,
                );
                _mapController.move(center, 8.3);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xEC071321),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _shortCount(row['canonical_property_count']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  String _shortCount(dynamic value) {
    final n = _int(value);
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 1 : 2)}M';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}K';
    }
    return '$n';
  }

  List<Marker> _propertyMarkers() => _properties.map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 24,
          height: 24,
          child: Tooltip(
            message:
                '${row['full_address'] ?? row['municipality'] ?? 'Property'} • ${row['state_code'] ?? ''}',
            child: GestureDetector(
              onTap: () => _showPayload(
                '${row['full_address'] ?? row['municipality'] ?? 'Property'}',
                row,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xDD071321),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .65),
                  ),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  size: 13,
                  color: Colors.white,
                ),
              ),
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
          width: 38,
          height: 38,
          child: Tooltip(
            message:
                '${row['full_address'] ?? row['title'] ?? 'Opportunity'} • ${row['state_code'] ?? ''} • score ${_score(row) ?? '—'}',
            child: GestureDetector(
              onTap: () => _showPayload(
                '${row['full_address'] ?? row['title'] ?? 'Opportunity'}',
                row,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF2071321),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .30),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(_opportunityIcon(row), size: 18, color: color),
              ),
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
          width: 25,
          height: 25,
          child: Tooltip(
            message:
                '${row['signal_name'] ?? row['title'] ?? 'Signal'} • ${row['state_code'] ?? ''}',
            child: GestureDetector(
              onTap: () => _showPayload(
                '${row['signal_name'] ?? row['title'] ?? 'Signal'}',
                row,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xE6071321),
                  shape: BoxShape.circle,
                  border: Border.all(color: _cyan),
                ),
                child: const Icon(Icons.bolt_rounded, size: 13, color: _cyan),
              ),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  Widget _legend() => Card(
        color: const Color(0xEE071321),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BRIDGEPOINT MAP',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 5),
              _LegendLine(Icons.flag_outlined, 'State data ready/building', _blue),
              _LegendLine(Icons.home_outlined, 'Property', Colors.white),
              _LegendLine(Icons.location_on_rounded, 'Opportunity', _amber),
              _LegendLine(Icons.bolt_rounded, 'Signal', _cyan),
              _LegendLine(Icons.my_location_rounded, 'Your device', _green),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.sizeOf(context).height.clamp(560.0, 860.0);
    final readyStates = _states
        .where((row) => _int(row['canonical_property_count']) > 0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Geospatial Intelligence',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Progressive national map: each state appears as soon as BridgePoint has usable foundation data, then real property, opportunity and signal points densify automatically as you zoom in.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: busy ? null : () => _loadOverview(),
              tooltip: 'Refresh map intelligence',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (busy || viewportBusy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: const TextStyle(color: _green, fontSize: 10),
          ),
        ],
        if (_locationMessage != null) ...[
          const SizedBox(height: 5),
          Text(
            _locationMessage!,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ],
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
            FilterChip(
              selected: stateReadiness,
              label: Text('States ($readyStates)'),
              avatar: const Icon(Icons.flag_outlined, size: 18),
              onSelected: (value) => setState(() => stateReadiness = value),
            ),
            FilterChip(
              selected: properties,
              label: Text('Properties (${_properties.length})'),
              avatar: const Icon(Icons.home_outlined, size: 18),
              onSelected: (value) => setState(() => properties = value),
            ),
            FilterChip(
              selected: opportunities,
              label: Text('Opportunities (${_opportunities.length})'),
              avatar: const Icon(Icons.location_on_outlined, size: 18),
              onSelected: (value) => setState(() => opportunities = value),
            ),
            FilterChip(
              selected: signals,
              label: Text('Signals (${_signals.length})'),
              avatar: const Icon(Icons.bolt_outlined, size: 18),
              onSelected: (value) => setState(() => signals = value),
            ),
            ActionChip(
              avatar: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(playing ? 'Pause weather' : 'Play weather'),
              onPressed: () => setState(() => playing = !playing),
            ),
            ActionChip(
              avatar: locating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('My location'),
              onPressed: locating ? null : _recenterToUser,
            ),
            ActionChip(
              avatar: const Icon(Icons.public_rounded, size: 18),
              label: const Text('United States'),
              onPressed: () => _mapController.move(
                const LatLng(39.50, -98.35),
                4.0,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.center_focus_strong_rounded, size: 18),
              label: const Text('Connecticut'),
              onPressed: () => _mapController.move(
                const LatLng(41.60, -72.70),
                8.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.50, -98.35),
                    initialZoom: 4.0,
                    minZoom: 3,
                    maxZoom: 18,
                    onMapReady: () {
                      _scheduleViewportLoad(_mapController.camera);
                    },
                    onPositionChanged: (camera, hasGesture) {
                      final changed = (camera.zoom - _zoom).abs() > .02;
                      if (changed && mounted) {
                        setState(() => _zoom = camera.zoom);
                      }
                      _scheduleViewportLoad(camera);
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
                    if (_showRawRadar)
                      TileLayer(
                        key: ValueKey(
                          'bp-radar-${radarTime.millisecondsSinceEpoch}',
                        ),
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
                    if (_showStateReadiness && _states.isNotEmpty)
                      MarkerLayer(markers: _stateMarkers()),
                    if (properties && _properties.isNotEmpty)
                      MarkerLayer(markers: _propertyMarkers()),
                    if (signals && _signals.isNotEmpty)
                      MarkerLayer(markers: _signalMarkers()),
                    if (opportunities && _opportunities.isNotEmpty)
                      MarkerLayer(markers: _opportunityMarkers()),
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 34,
                            height: 34,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _green.withValues(alpha: .18),
                                border: Border.all(color: _green, width: 2),
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                size: 18,
                                color: _green,
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
                Positioned(left: 10, top: 10, child: _legend()),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Card(
                    color: const Color(0xEE071321),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      child: Text(
                        'ZOOM ${_zoom.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_zoom < _propertyLoadMinZoom)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 116,
                    child: Card(
                      color: const Color(0xE8071321),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Row(
                          children: [
                            const Icon(Icons.zoom_in_rounded, color: _cyan, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$readyStates states have property-foundation data. Tap a state or zoom in to load its actual property points; opportunities/signals will appear as those state pipelines produce them.',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (radar && !_showRawRadar)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 178,
                    child: const Card(
                      color: Color(0xF2071321),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: _cyan),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Raw NOAA reflectivity is hidden at property-level zoom because the source is regional. BridgePoint keeps property-matched weather evidence without stretching radar pixels into fake roof-level detail.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                  height: 1.35,
                                ),
                              ),
                            ),
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
                      color: const Color(0xEE071321),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'NOAA RADAR • 4 HOURS',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: _cyan,
                                  ),
                                ),
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
                                Text(
                                  _clock(radarTime),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Animated regional reflectivity is weather context. Property markers and BridgePoint signals remain separate evidence layers.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 8.5,
                                height: 1.35,
                              ),
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
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Progressive map truth: a state can be visible as FOUNDATION or SCORING before it reaches full Connecticut parity. Actual property points are loaded only where geocoded map data exists. Opportunities and signals are never fabricated; they appear when those state pipelines actually produce verified rows.',
              style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 8.5)),
          ],
        ),
      );
}
