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
  int frame = 48;
  double _zoom = 4.0;
  int _viewportSerial = 0;
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
    _loadOverview();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (mounted && radar && playing) {
        setState(() => frame = frame >= 48 ? 0 : frame + 1);
      }
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) _loadOverview(silent: true);
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _viewportDebounce?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<DateTime> get _frames {
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

  DateTime get _radarTime => _frames[frame.clamp(0, 48)];
  bool get _showRadar => radar && _zoom <= _radarMaxHonestZoom;
  bool get _showStates => stateReadiness && _zoom <= _stateLabelMaxZoom;

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'_error': '$e'};
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (value is Map) {
      for (final key in const [
        'states',
        'properties',
        'opportunities',
        'signals',
        'points',
        'items',
        'rows',
        'results',
      ]) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${b.toString()}';
  }

  String _short(dynamic value) {
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

  String _clock(DateTime value) {
    final local = value.toLocal();
    return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        busy = true;
        _message = null;
      });
    }
    try {
      final values = await Future.wait([
        _safe('bridgepoint_flutter_map_state_status_v838'),
        _safe('bridgepoint_flutter_intelligence_map_national_v346', {
          'p_model_key': 'all',
          'p_min_lat': null,
          'p_max_lat': null,
          'p_min_lng': null,
          'p_max_lng': null,
          'p_min_score': 35,
          'p_opportunity_limit': 300,
          'p_signal_limit': 180,
        }),
      ]);

      final statePayload = values[0];
      final mapPayload = values[1];
      final nextStates = statePayload is Map
          ? _rows(statePayload['states'])
          : <Map<String, dynamic>>[];
      final nextOpps = mapPayload is Map
          ? _rows(mapPayload['opportunities'])
          : <Map<String, dynamic>>[];
      final nextSignals = mapPayload is Map
          ? _rows(mapPayload['signals'])
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _states = nextStates;
        _opportunities = nextOpps;
        _signals = nextSignals;
        if (!silent) {
          final ready = nextStates
              .where((row) => _int(row['canonical_property_count']) > 0)
              .length;
          final signalStates = nextStates
              .where((row) => _int(row['signal_count']) > 0)
              .length;
          final opportunityStates = nextStates
              .where((row) => _int(row['opportunity_count']) > 0)
              .length;
          final hadError = mapPayload is Map && mapPayload['_error'] != null;
          _message = hadError
              ? 'State intelligence is live. Zoom into a state to load property-level intelligence.'
              : '$ready states with property data • $signalStates with signals • $opportunityStates with scored opportunities. Zoom in to load property-level points.';
        }
      });

      if (_zoom >= _propertyLoadMinZoom) {
        _scheduleViewport(_mapController.camera);
      }
    } finally {
      if (!silent && mounted) setState(() => busy = false);
    }
  }

  void _scheduleViewport(MapCamera camera) {
    _viewportDebounce?.cancel();
    if (camera.zoom < _propertyLoadMinZoom) {
      if (_properties.isNotEmpty && mounted) {
        setState(() => _properties = const []);
      }
      return;
    }
    final bounds = camera.visibleBounds;
    _viewportDebounce = Timer(
      const Duration(milliseconds: 380),
      () => _loadViewport(bounds),
    );
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
          'p_limit': 400,
        }),
        _safe('bridgepoint_flutter_intelligence_map_national_v346', {
          'p_model_key': 'all',
          'p_min_lat': bounds.south,
          'p_max_lat': bounds.north,
          'p_min_lng': bounds.west,
          'p_max_lng': bounds.east,
          'p_min_score': 35,
          'p_opportunity_limit': 350,
          'p_signal_limit': 220,
        }),
      ]);
      if (!mounted || serial != _viewportSerial) return;

      final propertyPayload = values[0];
      final mapPayload = values[1];
      final nextProperties = propertyPayload is Map
          ? _rows(propertyPayload['properties'])
          : <Map<String, dynamic>>[];
      final nextOpps = mapPayload is Map
          ? _rows(mapPayload['opportunities'])
          : <Map<String, dynamic>>[];
      final nextSignals = mapPayload is Map
          ? _rows(mapPayload['signals'])
          : <Map<String, dynamic>>[];

      setState(() {
        _properties = nextProperties;
        _opportunities = nextOpps;
        _signals = nextSignals;
        _message = '${nextProperties.length} properties • ${nextOpps.length} opportunities • ${nextSignals.length} signals in this view.';
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
        _locationMessage = 'Centered on your device. Your precise location is not stored by this map action.';
      });
      _mapController.move(point, 13.2);
    } catch (e) {
      if (mounted) setState(() => _locationMessage = '$e');
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

  String _opportunityCode(Map<String, dynamic> row) {
    final text = '${row['opportunity_type'] ?? ''} ${row['opportunity_family'] ?? ''} ${row['title'] ?? ''}'.toLowerCase();
    if (text.contains('roof')) return 'R';
    if (text.contains('storm') || text.contains('hail') || text.contains('wind')) return 'W';
    if (text.contains('fire')) return 'F';
    if (text.contains('flood') || text.contains('water')) return 'H';
    if (text.contains('solar')) return 'S';
    if (text.contains('invest') || text.contains('sale') || text.contains('transfer')) return r'$';
    if (text.contains('develop')) return 'D';
    if (text.contains('permit')) return 'P';
    return '!';
  }

  List<MapEntry<String, String>> _details(String kind, Map<String, dynamic> row) {
    String text(dynamic value) => '${value ?? ''}'.trim();
    String percent(dynamic value) {
      final n = _double(value);
      if (n == null) return '';
      return n <= 1 ? '${(n * 100).toStringAsFixed(0)}%' : '${n.toStringAsFixed(0)}%';
    }

    final values = <MapEntry<String, String>>[];
    void add(String label, dynamic value) {
      final v = text(value);
      if (v.isNotEmpty && v != 'null') values.add(MapEntry(label, v));
    }

    if (kind == 'State') {
      add('Status', row['build_status'] ?? 'BUILDING');
      add('Properties', _number(row['canonical_property_count']));
      add('Signals', _number(row['signal_count']));
      add('Opportunities', _number(row['opportunity_count']));
      add('Verified sources', _number(row['verified_source_count']));
      add('2D buildings', _number(row['building_2d_count']));
      add('3D buildings', _number(row['building_3d_count']));
      add('Weather records', _number(row['weather_count']));
      final parity = _double(row['ct_parity_pct']);
      if (parity != null) add('CT parity', '${parity.toStringAsFixed(1)}%');
      return values;
    }

    add('Address', row['full_address']);
    add('Municipality', row['municipality']);
    add('County', row['county']);
    add('State', row['state_code']);

    if (kind == 'Property') {
      add('Parcel', row['parcel_number']);
      add('Property type', row['property_type']);
      add('Land use', row['land_use_description']);
      add('Year built', row['year_built']);
      if (row['assessed_total_value'] != null) {
        add('Assessed value', '\$${_number(row['assessed_total_value'])}');
      }
    } else if (kind == 'Opportunity') {
      add('Opportunity', row['title'] ?? row['opportunity_name']);
      add('Type', row['opportunity_type'] ?? row['opportunity_family']);
      add('Priority', row['priority']);
      add('Score', row['score'] ?? row['opportunity_score']);
      add('Why', row['reason'] ?? row['explanation']);
      add('Recommended action', row['recommended_action']);
      add('Signals', row['distinct_signal_count'] ?? row['signal_count']);
      add('Sources', row['source_count'] ?? row['direct_source_count']);
      add('Latest evidence', row['latest_evidence_at']);
    } else if (kind == 'Signal') {
      add('Signal', row['signal_name'] ?? row['title']);
      add('Family', row['signal_family']);
      add('Severity', row['severity']);
      add('Confidence', percent(row['confidence']));
      add('Description', row['description']);
      add('Detected', row['detected_at']);
      add('Evidence', row['evidence_count']);
      add('Sources', row['source_count']);
    }
    return values;
  }

  void _showDetails(String kind, String title, Map<String, dynamic> row) {
    final details = _details(kind, row);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: ListView(
              children: [
                Text(kind.toUpperCase(), style: const TextStyle(color: _cyan, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 5),
                Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                for (final item in details)
                  Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2035),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.key.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(item.value, style: const TextStyle(fontSize: 13, height: 1.35)),
                      ],
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
        final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
        final center = _stateCenters[code];
        if (center == null || _int(row['canonical_property_count']) <= 0) return null;
        final color = _stateColor(row);
        final p = _short(row['canonical_property_count']);
        final s = _short(row['signal_count']);
        final o = _short(row['opportunity_count']);
        return Marker(
          point: center,
          width: 68,
          height: 50,
          child: GestureDetector(
            onTap: () {
              _mapController.move(center, 7.7);
              _showDetails('State', '${row['state_name'] ?? code} • ${row['build_status'] ?? 'BUILDING'}', row);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xF2071321),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.4),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .12), blurRadius: 7)],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 1),
                  Text('P $p  S $s  O $o', maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 6.3, fontWeight: FontWeight.w800)),
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
          width: 17,
          height: 17,
          child: GestureDetector(
            onTap: () => _showDetails('Property', '${row['full_address'] ?? row['municipality'] ?? 'Property'}', row),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xE6071321),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .8), width: 1.3),
              ),
              child: Center(
                child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
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
          width: 32,
          height: 32,
          child: GestureDetector(
            onTap: () => _showDetails('Opportunity', '${row['full_address'] ?? row['title'] ?? 'Opportunity'}', row),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF2071321),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.3),
                boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 9)],
              ),
              child: Center(
                child: Text(_opportunityCode(row), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
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
          width: 21,
          height: 21,
          child: GestureDetector(
            onTap: () => _showDetails('Signal', '${row['signal_name'] ?? row['title'] ?? 'Signal'}', row),
            child: Transform.rotate(
              angle: .785398,
              child: Container(
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: [BoxShadow(color: _cyan.withValues(alpha: .32), blurRadius: 7)],
                ),
              ),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  Widget _legendDot(Color color, String label, {bool diamond = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: diamond ? .785398 : 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  shape: diamond ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: diamond ? BorderRadius.circular(2) : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 8.2)),
          ],
        ),
      );

  Widget _legend() => Card(
        color: const Color(0xEE071321),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('BRIDGEPOINT MAP', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              _legendDot(_blue, 'State P / S / O'),
              _legendDot(Colors.white, 'Property'),
              _legendDot(_amber, 'Opportunity'),
              _legendDot(_cyan, 'Signal', diamond: true),
              _legendDot(_green, 'Your device'),
            ],
          ),
        ),
      );

  Widget _filter(String label, bool selected, ValueChanged<bool> onSelected) => FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: onSelected,
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mapHeight = size.height.clamp(560.0, 860.0);
    final readyStates = _states.where((r) => _int(r['canonical_property_count']) > 0).length;
    final signalStates = _states.where((r) => _int(r['signal_count']) > 0).length;
    final opportunityStates = _states.where((r) => _int(r['opportunity_count']) > 0).length;

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
                  Text('Geospatial Intelligence', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text(
                    'Properties, scored opportunities, active signals and weather on one progressive U.S. intelligence map.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: busy ? null : () => _loadOverview(),
              tooltip: 'Refresh map',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _MapMetric('STATES', '$readyStates', _blue),
            _MapMetric('SIGNAL STATES', '$signalStates', _cyan),
            _MapMetric('OPPORTUNITY STATES', '$opportunityStates', _green),
            if (_zoom >= _propertyLoadMinZoom) _MapMetric('PROPERTIES', '${_properties.length}', Colors.white),
            _MapMetric('OPPORTUNITIES', '${_opportunities.length}', _amber),
            _MapMetric('SIGNALS', '${_signals.length}', _cyan),
          ],
        ),
        if (busy || viewportBusy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_message != null) ...[
          const SizedBox(height: 7),
          Text(_message!, style: const TextStyle(color: _green, fontSize: 10)),
        ],
        if (_locationMessage != null) ...[
          const SizedBox(height: 4),
          Text(_locationMessage!, style: const TextStyle(color: _muted, fontSize: 11.5)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _filter('Satellite', satellite, (v) => setState(() => satellite = v)),
            _filter('NOAA radar', radar, (v) => setState(() => radar = v)),
            _filter('States', stateReadiness, (v) => setState(() => stateReadiness = v)),
            _filter('Properties', properties, (v) => setState(() => properties = v)),
            _filter('Opportunities', opportunities, (v) => setState(() => opportunities = v)),
            _filter('Signals', signals, (v) => setState(() => signals = v)),
            ActionChip(
              label: Text(playing ? 'Pause weather' : 'Play weather'),
              onPressed: () => setState(() => playing = !playing),
            ),
            ActionChip(
              label: Text(locating ? 'Locating…' : 'My location'),
              onPressed: locating ? null : _recenterToUser,
            ),
            ActionChip(
              label: const Text('United States'),
              onPressed: () => _mapController.move(const LatLng(39.50, -98.35), 4.0),
            ),
            ActionChip(
              label: const Text('Connecticut'),
              onPressed: () => _mapController.move(const LatLng(41.60, -72.70), 8.2),
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
                    onMapReady: () => _scheduleViewport(_mapController.camera),
                    onPositionChanged: (camera, hasGesture) {
                      if ((camera.zoom - _zoom).abs() > .02 && mounted) {
                        setState(() => _zoom = camera.zoom);
                      }
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
                        key: ValueKey('bp-radar-${_radarTime.millisecondsSinceEpoch}'),
                        wmsOptions: WMSTileLayerOptions(
                          baseUrl: 'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                          layers: const ['0'],
                          format: 'image/png',
                          transparent: true,
                          version: '1.3.0',
                          otherParameters: {'TIME': _radarTime.toUtc().toIso8601String()},
                        ),
                        maxNativeZoom: 10,
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    if (_showStates && _states.isNotEmpty) MarkerLayer(markers: _stateMarkers()),
                    if (properties && _properties.isNotEmpty) MarkerLayer(markers: _propertyMarkers()),
                    if (signals && _signals.isNotEmpty) MarkerLayer(markers: _signalMarkers()),
                    if (opportunities && _opportunities.isNotEmpty) MarkerLayer(markers: _opportunityMarkers()),
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: .25),
                                shape: BoxShape.circle,
                                border: Border.all(color: _green, width: 2),
                              ),
                              child: Center(child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle))),
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
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      child: Text('ZOOM ${_zoom.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                if (_zoom < _propertyLoadMinZoom)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 112,
                    child: Card(
                      color: const Color(0xE8071321),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Text(
                          'Each state marker shows P = properties, S = active signals, O = scored opportunities. Tap a state or zoom in to load individual property-level points.',
                          style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.35),
                        ),
                      ),
                    ),
                  ),
                if (radar && !_showRadar)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 160,
                    child: const Card(
                      color: Color(0xF2071321),
                      child: Padding(
                        padding: EdgeInsets.all(9),
                        child: Text(
                          'Regional NOAA reflectivity is hidden at property-level zoom. Property-matched BridgePoint weather evidence remains available without stretching radar pixels into fake roof-level precision.',
                          style: TextStyle(color: _muted, fontSize: 8.8, height: 1.35),
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
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                        child: Row(
                          children: [
                            const Text('NOAA • 4H', style: TextStyle(color: _cyan, fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 7),
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
                            Text(_clock(_radarTime), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
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
          'Map truth: BridgePoint shows only geocoded property rows and verified intelligence returned by the live backend. A state can have parcel coverage before its opportunity scoring reaches full parity.',
          style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
        ),
      ],
    );
  }
}

class _MapMetric extends StatelessWidget {
  const _MapMetric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 7.4, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
          ],
        ),
      );
}
