import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointMapWeatherV2 extends StatefulWidget {
  const BridgePointMapWeatherV2({super.key});

  @override
  State<BridgePointMapWeatherV2> createState() =>
      _BridgePointMapWeatherRecoveredV3State();
}

class _BridgePointMapWeatherRecoveredV3State
    extends State<BridgePointMapWeatherV2> {
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _purple = Color(0xFFA98BFF);
  static const _ice = Color(0xFF93DDF5);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xEE071321);
  static const _propertyLoadMinZoom = 6.3;
  static const _stateLabelMaxZoom = 6.2;
  static const _radarMaxHonestZoom = 11.2;

  static const _liveRadarWms =
      'https://mapservices.weather.noaa.gov/eventdriven/services/radar/'
      'radar_base_reflectivity/MapServer/WMSServer?';

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

  final _mapController = MapController();
  Timer? _debounce;
  Timer? _refreshTimer;
  int _serial = 0;

  bool satellite = true;
  bool radar = true;
  bool states = true;
  bool properties = true;
  bool opportunities = true;
  bool signals = false;
  bool busy = true;
  bool viewportBusy = false;
  double zoom = 4.0;
  String message = 'Loading national intelligence…';

  final Set<String> selectedHazards = {
    'HAIL',
    'FLOOD',
    'RAIN',
    'TORNADO',
    'HURRICANE',
    'WILDFIRE',
  };

  List<Map<String, dynamic>> stateRows = const [];
  List<Map<String, dynamic>> propertyRows = const [];
  List<Map<String, dynamic>> opportunityRows = const [];
  List<Map<String, dynamic>> signalRows = const [];
  List<Map<String, dynamic>> hazardRows = const [];
  List<Map<String, dynamic>> hazardSources = const [];

  @override
  void initState() {
    super.initState();
    _loadOverview();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      _loadOverview(silent: true);
      _scheduleViewport(_mapController.camera, immediate: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
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
      return value
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
    }
    if (value is Map) {
      for (final key in const [
        'states',
        'properties',
        'opportunities',
        'signals',
        'items',
        'rows',
        'sources',
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

  String _short(dynamic value) {
    final n = _int(value);
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (!silent && mounted) setState(() => busy = true);
    final result = await _safe('bridgepoint_flutter_map_state_status_v838');
    if (!mounted) return;
    setState(() {
      stateRows = result is Map ? _rows(result['states']) : const [];
      busy = false;
      final active = stateRows
          .where((x) => _int(x['canonical_property_count']) > 0)
          .length;
      message = '$active states currently have canonical property rows. Zoom or tap a state for live property intelligence.';
    });
    if (_mapController.camera.zoom >= _propertyLoadMinZoom) {
      _scheduleViewport(_mapController.camera, immediate: true);
    } else {
      await _loadHazards(_mapController.camera.visibleBounds);
    }
  }

  void _scheduleViewport(MapCamera camera, {bool immediate = false}) {
    zoom = camera.zoom;
    _debounce?.cancel();
    if (immediate) {
      _loadViewport(camera.visibleBounds);
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => _loadViewport(camera.visibleBounds),
      );
    }
  }

  Future<void> _loadViewport(LatLngBounds bounds) async {
    final serial = ++_serial;
    if (mounted) setState(() => viewportBusy = true);

    final jobs = <Future<dynamic>>[
      _safe('bridgepoint_hazard_layers_v903', {
        'p_hazard_types': null,
        'p_min_lat': bounds.south,
        'p_max_lat': bounds.north,
        'p_min_lng': bounds.west,
        'p_max_lng': bounds.east,
        'p_limit': 1500,
      }),
    ];

    if (zoom >= _propertyLoadMinZoom) {
      jobs.addAll([
        _safe('bridgepoint_flutter_property_map_viewport_v838', {
          'p_min_lat': bounds.south,
          'p_max_lat': bounds.north,
          'p_min_lng': bounds.west,
          'p_max_lng': bounds.east,
          'p_limit': 500,
        }),
        _safe('bridgepoint_flutter_intelligence_map_national_v346', {
          'p_model_key': 'all',
          'p_min_lat': bounds.south,
          'p_max_lat': bounds.north,
          'p_min_lng': bounds.west,
          'p_max_lng': bounds.east,
          'p_min_score': 35,
          'p_opportunity_limit': 400,
          'p_signal_limit': 250,
        }),
      ]);
    }

    final values = await Future.wait(jobs);
    if (!mounted || serial != _serial) return;

    final hazards = values[0];
    var nextProperties = <Map<String, dynamic>>[];
    var nextOpps = <Map<String, dynamic>>[];
    var nextSignals = <Map<String, dynamic>>[];

    if (values.length > 1) {
      final propertyPayload = values[1];
      final intelligencePayload = values[2];
      nextProperties = propertyPayload is Map
          ? _rows(propertyPayload['properties'])
          : <Map<String, dynamic>>[];
      nextOpps = intelligencePayload is Map
          ? _rows(intelligencePayload['opportunities'])
          : <Map<String, dynamic>>[];
      nextSignals = intelligencePayload is Map
          ? _rows(intelligencePayload['signals'])
          : <Map<String, dynamic>>[];
    }

    setState(() {
      hazardRows = hazards is Map ? _rows(hazards['items']) : const [];
      hazardSources = hazards is Map ? _rows(hazards['sources']) : const [];
      propertyRows = nextProperties;
      opportunityRows = nextOpps;
      signalRows = nextSignals;
      viewportBusy = false;
      message = zoom >= _propertyLoadMinZoom
          ? '${propertyRows.length} properties • ${opportunityRows.length} opportunities • ${_visibleHazards.length} selected hazard records in this view.'
          : '${_visibleHazards.length} selected national hazard records in view. Zoom in for properties.';
    });
  }

  Future<void> _loadHazards(LatLngBounds bounds) async {
    final value = await _safe('bridgepoint_hazard_layers_v903', {
      'p_hazard_types': null,
      'p_min_lat': bounds.south,
      'p_max_lat': bounds.north,
      'p_min_lng': bounds.west,
      'p_max_lng': bounds.east,
      'p_limit': 1500,
    });
    if (!mounted) return;
    setState(() {
      hazardRows = value is Map ? _rows(value['items']) : const [];
      hazardSources = value is Map ? _rows(value['sources']) : const [];
    });
  }

  List<Map<String, dynamic>> get _visibleHazards => hazardRows
      .where((row) => selectedHazards.contains(
            '${row['hazard_type'] ?? ''}'.toUpperCase(),
          ))
      .toList();

  Color _hazardColor(String type) => switch (type) {
        'HAIL' => _purple,
        'TORNADO' => _red,
        'HURRICANE' => const Color(0xFFFF8A4C),
        'WILDFIRE' => const Color(0xFFFF5C35),
        'SNOW' => Colors.white,
        'ICE' => _ice,
        'FLOOD' => const Color(0xFF4D8DFF),
        'RAIN' => const Color(0xFF4DB8FF),
        'WIND' => _amber,
        'FIRE_WEATHER' => const Color(0xFFFF7A5C),
        'POWER_OUTAGE' => const Color(0xFFFFE16A),
        _ => _cyan,
      };

  IconData _hazardIcon(String type) => switch (type) {
        'HAIL' => Icons.grain_rounded,
        'TORNADO' => Icons.tornado_rounded,
        'HURRICANE' => Icons.cyclone_rounded,
        'WILDFIRE' => Icons.local_fire_department_rounded,
        'SNOW' => Icons.ac_unit_rounded,
        'ICE' => Icons.severe_cold_rounded,
        'FLOOD' => Icons.flood_rounded,
        'RAIN' => Icons.water_drop_rounded,
        'WIND' => Icons.air_rounded,
        'POWER_OUTAGE' => Icons.power_off_rounded,
        _ => Icons.warning_amber_rounded,
      };

  String _hazardPlainEnglish(Map<String, dynamic> row) {
    final kind = '${row['observation_kind'] ?? ''}'.toUpperCase();
    final type = '${row['hazard_type'] ?? 'hazard'}'.toUpperCase();
    if (kind == 'FORECAST_OUTLOOK') {
      return 'This is a forecast area where $type is considered possible. It is not an observation and it does not prove a property was hit.';
    }
    if (kind == 'ALERT') {
      return 'An official alert covers this area. It means conditions are occurring or expected in the alert area. It does not by itself prove damage at a specific property.';
    }
    if (kind == 'OBSERVED_INCIDENT') {
      return 'This is a reported incident location from the named source. Nearby properties may need review, but proximity alone does not prove impact.';
    }
    if (kind == 'CURRENT_STORM') {
      return 'This is the current reported tropical-cyclone position and storm context. Track and impact zones must be evaluated separately.';
    }
    return 'This is source-backed hazard context. Use the source, time and evidence type before drawing a property-level conclusion.';
  }

  List<List<LatLng>> _polygonRings(dynamic geometry) {
    if (geometry is! Map) return const [];
    final type = '${geometry['type'] ?? ''}';
    final coords = geometry['coordinates'];
    if (coords is! List) return const [];

    List<LatLng> ring(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<List>()
          .where((p) => p.length >= 2)
          .map((p) => LatLng(
                (p[1] as num).toDouble(),
                (p[0] as num).toDouble(),
              ))
          .toList();
    }

    if (type == 'Polygon') {
      if (coords.isEmpty) return const [];
      final r = ring(coords.first);
      return r.length >= 3 ? [r] : const [];
    }
    if (type == 'MultiPolygon') {
      final out = <List<LatLng>>[];
      for (final polygon in coords) {
        if (polygon is! List || polygon.isEmpty) continue;
        final r = ring(polygon.first);
        if (r.length >= 3) out.add(r);
      }
      return out;
    }
    return const [];
  }

  List<Polygon> _hazardPolygons() {
    final out = <Polygon>[];
    for (final row in _visibleHazards) {
      final type = '${row['hazard_type'] ?? ''}'.toUpperCase();
      final color = _hazardColor(type);
      for (final points in _polygonRings(row['geometry_geojson'])) {
        out.add(
          Polygon(
            points: points,
            color: color.withValues(alpha: .13),
            borderColor: color.withValues(alpha: .82),
            borderStrokeWidth: 1.5,
          ),
        );
      }
    }
    return out;
  }

  List<Marker> _hazardMarkers() {
    final out = <Marker>[];
    for (final row in _visibleHazards) {
      final lat = _double(row['latitude']);
      final lng = _double(row['longitude']);
      if (lat == null || lng == null) continue;
      final type = '${row['hazard_type'] ?? ''}'.toUpperCase();
      final color = _hazardColor(type);
      out.add(
        Marker(
          point: LatLng(lat, lng),
          width: 34,
          height: 34,
          child: Tooltip(
            message: '${row['event_name'] ?? type}',
            child: GestureDetector(
              onTap: () => _showHazard(row),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF2071321),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .32),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(_hazardIcon(type), color: color, size: 18),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  List<Marker> _stateMarkers() {
    if (!states || zoom > _stateLabelMaxZoom) return const [];
    final out = <Marker>[];
    for (final row in stateRows) {
      final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
      final center = _stateCenters[code];
      if (center == null || _int(row['canonical_property_count']) <= 0) continue;
      final hasOpps = _int(row['opportunity_count']) > 0;
      final hasSignals = _int(row['signal_count']) > 0;
      final color = hasOpps ? _green : (hasSignals ? _cyan : _muted);
      out.add(
        Marker(
          point: center,
          width: 74,
          height: 48,
          child: GestureDetector(
            onTap: () {
              _mapController.move(center, 7.8);
              _showState(row);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'P ${_short(row['canonical_property_count'])}  S ${_short(row['signal_count'])}  O ${_short(row['opportunity_count'])}',
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  List<Marker> _propertyMarkers() {
    if (!properties) return const [];
    return propertyRows.map((row) {
      final lat = _double(row['latitude']);
      final lng = _double(row['longitude']);
      if (lat == null || lng == null) return null;
      return Marker(
        point: LatLng(lat, lng),
        width: 18,
        height: 18,
        child: GestureDetector(
          onTap: () => _showProperty(row),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xE6071321),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
          ),
        ),
      );
    }).whereType<Marker>().toList();
  }

  List<Marker> _opportunityMarkers() {
    if (!opportunities) return const [];
    return opportunityRows.map((row) {
      final lat = _double(row['latitude']);
      final lng = _double(row['longitude']);
      if (lat == null || lng == null) return null;
      final score = _double(row['score'] ?? row['opportunity_score']) ?? 0;
      final color = score >= 85 ? _red : (score >= 70 ? _amber : _green);
      return Marker(
        point: LatLng(lat, lng),
        width: 28,
        height: 28,
        child: GestureDetector(
          onTap: () => _showGeneric(
            'Opportunity',
            '${row['full_address'] ?? row['title'] ?? 'Opportunity'}',
            [
              ['Score', '${row['score'] ?? row['opportunity_score'] ?? '—'}'],
              ['Priority', '${row['priority'] ?? '—'}'],
              ['Why', '${row['reason'] ?? row['explanation'] ?? 'Open the property dossier for evidence.'}'],
              ['Next step', '${row['recommended_action'] ?? 'Review evidence before acting.'}'],
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _panel,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.2),
            ),
            child: Center(
              child: Text(
                '${score.round()}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 8,
                ),
              ),
            ),
          ),
        ),
      );
    }).whereType<Marker>().toList();
  }

  List<Marker> _signalMarkers() {
    if (!signals) return const [];
    return signalRows.map((row) {
      final lat = _double(row['latitude']);
      final lng = _double(row['longitude']);
      if (lat == null || lng == null) return null;
      return Marker(
        point: LatLng(lat, lng),
        width: 18,
        height: 18,
        child: GestureDetector(
          onTap: () => _showGeneric(
            'Signal',
            '${row['signal_name'] ?? row['title'] ?? 'Signal'}',
            [
              ['Meaning', '${row['description'] ?? 'A source-backed reason to look closer.'}'],
              ['Confidence', '${row['confidence'] ?? '—'}'],
              ['Detected', '${row['detected_at'] ?? '—'}'],
              ['Evidence', '${row['evidence_count'] ?? '—'} records'],
            ],
          ),
          child: Transform.rotate(
            angle: .785398,
            child: Container(
              decoration: BoxDecoration(
                color: _cyan.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      );
    }).whereType<Marker>().toList();
  }

  void _showState(Map<String, dynamic> row) {
    _showGeneric(
      'State build',
      '${row['state_name'] ?? row['state_code'] ?? 'State'}',
      [
        ['Properties', _short(row['canonical_property_count'])],
        ['Signals', _short(row['signal_count'])],
        ['Opportunities', _short(row['opportunity_count'])],
        ['Verified sources', _short(row['verified_source_count'])],
        ['2D buildings', _short(row['building_2d_count'])],
        ['3D buildings', _short(row['building_3d_count'])],
        ['Weather records', _short(row['weather_count'])],
        ['Plain English', 'A state can have parcel coverage before matching, scoring, patterns, media and physical-property coverage are complete.'],
      ],
    );
  }

  void _showProperty(Map<String, dynamic> row) {
    _showGeneric(
      'Property',
      '${row['full_address'] ?? row['municipality'] ?? 'Property'}',
      [
        ['Parcel', '${row['parcel_number'] ?? '—'}'],
        ['Type', '${row['property_type'] ?? row['land_use_description'] ?? '—'}'],
        ['Year built', '${row['year_built'] ?? '—'}'],
        ['State', '${row['state_code'] ?? '—'}'],
        ['Plain English', 'This dot means BridgePoint has a geocoded canonical property here. Open Properties for the full evidence, imagery, timeline, matching, scores, patterns and 3D fidelity.'],
      ],
    );
  }

  void _showHazard(Map<String, dynamic> row) {
    final type = '${row['hazard_type'] ?? 'Hazard'}'.toUpperCase();
    _showGeneric(
      type,
      '${row['headline'] ?? row['event_name'] ?? type}',
      [
        ['Evidence type', '${row['observation_kind'] ?? '—'}'],
        ['Provider', '${row['provider'] ?? '—'}'],
        ['Severity', '${row['severity'] ?? '—'}'],
        ['Certainty', '${row['certainty'] ?? '—'}'],
        ['Starts', '${row['starts_at'] ?? '—'}'],
        ['Ends', '${row['ends_at'] ?? '—'}'],
        ['Area', '${row['area_description'] ?? 'Mapped source geometry'}'],
        ['What this means', _hazardPlainEnglish(row)],
        ['Source', '${row['source_url'] ?? 'Source link retained in backend'}'],
      ],
    );
  }

  void _showGeneric(
    String kind,
    String title,
    List<List<String>> rows,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Text(
                kind.toUpperCase(),
                style: const TextStyle(
                  color: _cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              for (final row in rows)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E2035),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row[0].toUpperCase(),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(row[1], style: const TextStyle(height: 1.35)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(
    String label,
    bool selected,
    ValueChanged<bool> onSelected, {
    IconData? icon,
  }) {
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _hazardToggle(String key, String label) => FilterChip(
        selected: selectedHazards.contains(key),
        onSelected: (value) {
          setState(() {
            if (value) {
              selectedHazards.add(key);
            } else {
              selectedHazards.remove(key);
            }
          });
        },
        avatar: Icon(
          _hazardIcon(key),
          size: 16,
          color: _hazardColor(key),
        ),
        label: Text(label),
      );

  String _sourceHealth(String key) {
    final row = hazardSources.cast<Map<String, dynamic>?>().firstWhere(
          (x) => '${x?['source_key'] ?? ''}' == key,
          orElse: () => null,
        );
    return '${row?['status'] ?? 'UNKNOWN'}';
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = (MediaQuery.sizeOf(context).height * .64)
        .clamp(460.0, 820.0)
        .toDouble();
    final hazardPolygons = _hazardPolygons();
    final hazardMarkers = _hazardMarkers();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INTELLIGENCE MAP',
                    style: TextStyle(
                      color: _cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Weather + property intelligence',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (viewportBusy || busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(color: _muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _toggle(
              'Satellite',
              satellite,
              (v) => setState(() => satellite = v),
              icon: Icons.satellite_alt_rounded,
            ),
            _toggle(
              'Live radar',
              radar,
              (v) => setState(() => radar = v),
              icon: Icons.radar_rounded,
            ),
            _hazardToggle('HAIL', 'Hail'),
            _hazardToggle('FLOOD', 'Flood'),
            _hazardToggle('RAIN', 'Rain alerts'),
            _hazardToggle('SNOW', 'Snow'),
            _hazardToggle('ICE', 'Ice'),
            _hazardToggle('TORNADO', 'Tornado'),
            _hazardToggle('HURRICANE', 'Hurricane'),
            _hazardToggle('WILDFIRE', 'Wildfire'),
            _hazardToggle('POWER_OUTAGE', 'Outages'),
            _toggle('States', states, (v) => setState(() => states = v)),
            _toggle(
              'Properties',
              properties,
              (v) => setState(() => properties = v),
            ),
            _toggle(
              'Opportunities',
              opportunities,
              (v) => setState(() => opportunities = v),
            ),
            _toggle('Signals', signals, (v) => setState(() => signals = v)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HealthPill('NWS', _sourceHealth('NWS_ALERTS')),
            _HealthPill('Hail', _sourceHealth('SPC_DAY1_HAIL')),
            _HealthPill('Tornado', _sourceHealth('SPC_DAY1_TORNADO')),
            _HealthPill('Wildfire', _sourceHealth('WFIGS_CURRENT')),
            _HealthPill('Tropical', _sourceHealth('NHC_CURRENT')),
            _HealthPill('Outages', _sourceHealth('POWER_OUTAGE_ADAPTERS')),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.5, -98.35),
                    initialZoom: 4,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: () =>
                        _scheduleViewport(_mapController.camera, immediate: true),
                    onPositionChanged: (camera, hasGesture) {
                      if ((camera.zoom - zoom).abs() > .03 && mounted) {
                        setState(() => zoom = camera.zoom);
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
                        urlTemplate:
                            'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                      ),
                    if (radar && zoom <= _radarMaxHonestZoom)
                      TileLayer(
                        key: const ValueKey('bridgepoint-live-radar-v3'),
                        wmsOptions: const WMSTileLayerOptions(
                          baseUrl: _liveRadarWms,
                          layers: ['0'],
                          format: 'image/png',
                          transparent: true,
                          version: '1.3.0',
                        ),
                        userAgentPackageName: 'com.bridgepoint.data_studio',
                        maxNativeZoom: 11,
                      ),
                    if (hazardPolygons.isNotEmpty)
                      PolygonLayer(polygons: hazardPolygons),
                    if (_stateMarkers().isNotEmpty)
                      MarkerLayer(markers: _stateMarkers()),
                    if (_propertyMarkers().isNotEmpty)
                      MarkerLayer(markers: _propertyMarkers()),
                    if (_signalMarkers().isNotEmpty)
                      MarkerLayer(markers: _signalMarkers()),
                    if (_opportunityMarkers().isNotEmpty)
                      MarkerLayer(markers: _opportunityMarkers()),
                    if (hazardMarkers.isNotEmpty)
                      MarkerLayer(markers: hazardMarkers),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('NOAA / NWS / SPC / NHC'),
                        TextSourceAttribution('NIFC / WFIGS'),
                        TextSourceAttribution('Esri / OpenStreetMap'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Card(
                    color: _panel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Text(
                        'ZOOM ${zoom.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                if (radar && zoom > _radarMaxHonestZoom)
                  const Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Card(
                      color: _panel,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Live radar is hidden at roof-level zoom because its resolution is regional. Property weather evidence can still be shown without pretending a radar pixel is exact roof damage.',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Plain English: radar colors show precipitation intensity. Hazard polygons show alerts, forecasts or reported incidents. Neither one automatically means a specific property was damaged. BridgePoint keeps those evidence types separate on purpose.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _HealthPill extends StatelessWidget {
  const _HealthPill(this.label, this.status);
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    final color = upper == 'HEALTHY'
        ? const Color(0xFF45E6A6)
        : upper == 'BUILDING'
            ? const Color(0xFFFFC95E)
            : const Color(0xFFFF7474);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        '$label • $upper',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
