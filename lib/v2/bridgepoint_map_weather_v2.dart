import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Customer-readable intelligence map. Radar is stable on the latest frame by
// default, every marker is tappable, and the map explains icon/color meaning.
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

  bool satellite = true;
  bool radar = true;
  bool properties = true;
  bool opportunities = true;
  bool signals = true;
  bool playing = false;
  bool locating = false;
  bool viewportBusy = false;
  int frame = 0;
  int _viewportSerial = 0;
  double _zoom = 4;
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
    _radarTimer = Timer.periodic(const Duration(milliseconds: 5500), (_) {
      if (!mounted || !radar || !playing || _radarFrames.length <= 1) return;
      setState(() {
        if (frame < _radarFrames.length - 1) {
          frame += 1;
        } else {
          playing = false;
        }
      });
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

  double? _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}');

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

  String _value(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final raw = row[key];
      if (raw == null) continue;
      final text = '$raw'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  String _plain(String value) {
    if (value.trim().isEmpty) return '';
    final words = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.length <= 2
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}');
    return words.join(' ');
  }

  String _wmsTime(DateTime value) {
    final u = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}.${three(u.millisecond)}Z';
  }

  String _clock(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String get _radarStatus {
    if (_radarFrames.isEmpty) return 'NOAA • latest';
    final latest = frame >= _radarFrames.length - 1;
    if (latest) return 'NOAA • Latest • ${_clock(_radarTime)}';
    return 'NOAA • Frame ${frame + 1}/${_radarFrames.length} • ${_clock(_radarTime)}';
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
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) return;
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
      if (frames.length > 18) frames = frames.sublist(frames.length - 18);
      if (frames.isEmpty || !mounted) return;
      final wasPlaying = playing;
      setState(() {
        _radarFrames = frames;
        if (wasPlaying) {
          frame = frame.clamp(0, frames.length - 1);
        } else {
          frame = frames.length - 1;
        }
      });
    } catch (_) {
      // WMS is still allowed to request the latest image when frame discovery
      // is temporarily unavailable.
    }
  }

  Future<void> _loadOverview() async {
    final values = await Future.wait([
      _safe('bridgepoint_flutter_map_state_status_v838'),
      _safe(
        'bridgepoint_flutter_intelligence_map_national_v346',
        {
          'p_model_key': 'all',
          'p_min_lat': null,
          'p_max_lat': null,
          'p_min_lng': null,
          'p_max_lng': null,
          'p_min_score': 42,
          'p_opportunity_limit': 120,
          'p_signal_limit': 90,
        },
      ),
    ]);
    if (!mounted) return;
    setState(() {
      final s = values[0];
      final i = values[1];
      _states = s is Map ? _rows(s['states']) : const [];
      _opportunities = i is Map ? _rows(i['opportunities']) : const [];
      _signals = i is Map ? _rows(i['signals']) : const [];
      _message =
          'Tap any marker to see what it is, why BridgePoint is showing it, and how to interpret it. Zoom into a state for property detail.';
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
      _safe(
        'bridgepoint_flutter_property_map_viewport_v838',
        {
          'p_min_lat': bounds.south,
          'p_max_lat': bounds.north,
          'p_min_lng': bounds.west,
          'p_max_lng': bounds.east,
          'p_limit': 220,
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
          'p_min_score': 42,
          'p_opportunity_limit': 120,
          'p_signal_limit': 80,
        },
      ),
    ]);
    if (!mounted || serial != _viewportSerial) return;
    final p = values[0];
    final i = values[1];
    setState(() {
      _properties = p is Map ? _rows(p['properties']) : const [];
      _opportunities = i is Map ? _rows(i['opportunities']) : const [];
      _signals = i is Map ? _rows(i['signals']) : const [];
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

  void _toggleRadarPlayback() {
    if (_radarFrames.length <= 1) return;
    setState(() {
      if (playing) {
        playing = false;
      } else {
        if (frame >= _radarFrames.length - 1) frame = 0;
        playing = true;
      }
    });
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
      '${row['opportunity_type'] ?? ''} ${row['opportunity_family'] ?? ''} ${row['title'] ?? ''}'
          .toLowerCase();

  String _signalText(Map<String, dynamic> row) =>
      '${row['signal_type'] ?? ''} ${row['signal_family'] ?? ''} ${row['event_type'] ?? ''} ${row['title'] ?? ''}'
          .toLowerCase();

  IconData _opportunityIcon(Map<String, dynamic> row) {
    final text = _opportunityText(row);
    if (text.contains('roof')) return Icons.roofing_rounded;
    if (text.contains('storm') || text.contains('hail') || text.contains('wind')) {
      return Icons.thunderstorm_rounded;
    }
    if (text.contains('fire')) return Icons.local_fire_department_rounded;
    if (text.contains('flood') || text.contains('water')) {
      return Icons.water_damage_outlined;
    }
    if (text.contains('solar')) return Icons.solar_power_rounded;
    if (text.contains('invest') ||
        text.contains('sale') ||
        text.contains('transfer')) {
      return Icons.real_estate_agent_rounded;
    }
    if (text.contains('develop')) return Icons.construction_rounded;
    if (text.contains('permit')) return Icons.fact_check_outlined;
    return Icons.location_searching_rounded;
  }

  IconData _signalIcon(Map<String, dynamic> row) {
    final text = _signalText(row);
    if (text.contains('storm') ||
        text.contains('weather') ||
        text.contains('hail') ||
        text.contains('wind') ||
        text.contains('lightning')) {
      return Icons.thunderstorm_rounded;
    }
    if (text.contains('fire')) return Icons.local_fire_department_rounded;
    if (text.contains('flood') || text.contains('water')) {
      return Icons.water_drop_outlined;
    }
    if (text.contains('permit')) return Icons.fact_check_outlined;
    if (text.contains('sale') || text.contains('transfer')) {
      return Icons.real_estate_agent_outlined;
    }
    return Icons.bolt_rounded;
  }

  String _opportunityCategory(Map<String, dynamic> row) {
    final text = _opportunityText(row);
    if (text.contains('roof')) return 'Roofing opportunity';
    if (text.contains('storm') || text.contains('hail') || text.contains('wind')) {
      return 'Storm / weather opportunity';
    }
    if (text.contains('fire')) return 'Fire-related opportunity';
    if (text.contains('flood') || text.contains('water')) {
      return 'Flood / water opportunity';
    }
    if (text.contains('solar')) return 'Solar opportunity';
    if (text.contains('invest') ||
        text.contains('sale') ||
        text.contains('transfer')) {
      return 'Sale / transfer / investment opportunity';
    }
    if (text.contains('develop')) return 'Development opportunity';
    if (text.contains('permit')) return 'Permit-related opportunity';
    return 'Property opportunity';
  }

  String _signalCategory(Map<String, dynamic> row) {
    final text = _signalText(row);
    if (text.contains('storm') ||
        text.contains('weather') ||
        text.contains('hail') ||
        text.contains('wind') ||
        text.contains('lightning')) {
      return 'Weather signal';
    }
    if (text.contains('fire')) return 'Fire signal';
    if (text.contains('flood') || text.contains('water')) return 'Water / flood signal';
    if (text.contains('permit')) return 'Permit signal';
    if (text.contains('sale') || text.contains('transfer')) return 'Ownership / transfer signal';
    return 'Property evidence signal';
  }

  String _markerTitle(String kind, Map<String, dynamic> row) {
    if (kind == 'Property') {
      final address = _value(row, const [
        'full_address',
        'address',
        'property_address',
        'display_address',
      ]);
      return address.isEmpty ? 'Property record' : address;
    }
    if (kind == 'Opportunity') {
      final title = _value(row, const ['title', 'opportunity_name', 'label']);
      return title.isEmpty ? _opportunityCategory(row) : _plain(title);
    }
    final title = _value(row, const ['title', 'signal_name', 'label']);
    return title.isEmpty ? _signalCategory(row) : _plain(title);
  }

  String _whatItMeans(String kind, Map<String, dynamic> row) {
    if (kind == 'Property') {
      return 'This house icon is a property record BridgePoint can connect to evidence, timelines, scores and opportunities available to your account.';
    }
    if (kind == 'Opportunity') {
      return 'BridgePoint combined available evidence and scoring rules into a potential action or lead. Higher priority means stronger qualification under the active model, not guaranteed damage or guaranteed revenue.';
    }
    return 'A signal is evidence or context BridgePoint found near or on a property. It can strengthen a timeline or score, but a signal by itself is not proof of damage.';
  }

  String _whatItDoesNotProve(String kind) {
    if (kind == 'Property') {
      return 'A property marker does not mean the property has damage, a claim, or an active opportunity.';
    }
    if (kind == 'Opportunity') {
      return 'An opportunity is a ranked intelligence result. It does not prove loss, coverage, ownership intent, or that work is required.';
    }
    return 'Area-level or matched evidence does not automatically prove that the exact building was affected. Check the evidence level, source and property timeline.';
  }

  List<MapEntry<String, String>> _detailRows(
    String kind,
    Map<String, dynamic> row,
  ) {
    final rows = <MapEntry<String, String>>[];
    void add(String label, List<String> keys, {bool plain = false}) {
      final value = _value(row, keys);
      if (value.isNotEmpty) {
        rows.add(MapEntry(label, plain ? _plain(value) : value));
      }
    }

    add('Address', const [
      'full_address',
      'address',
      'property_address',
      'display_address',
    ]);
    if (kind == 'Opportunity') {
      rows.add(MapEntry('Icon means', _opportunityCategory(row)));
      add('Opportunity type', const [
        'opportunity_type',
        'opportunity_family',
        'category',
      ], plain: true);
      add('Priority', const ['priority', 'priority_band'], plain: true);
      add('Score', const ['score', 'opportunity_score']);
    } else if (kind == 'Signal') {
      rows.add(MapEntry('Icon means', _signalCategory(row)));
      add('Signal type', const [
        'signal_type',
        'signal_family',
        'event_type',
        'category',
      ], plain: true);
    }
    add('Evidence level', const [
      'evidence_level',
      'scope',
      'match_scope',
      'evidence_scope',
    ], plain: true);
    add('Confidence', const [
      'confidence',
      'confidence_score',
      'match_confidence',
    ]);
    add('Date', const [
      'event_date',
      'occurred_at',
      'observed_at',
      'detected_at',
      'created_at',
    ]);
    add('Source', const [
      'source_name',
      'source',
      'provider_name',
      'provider',
    ], plain: true);
    add('Match method', const [
      'match_method',
      'matching_method',
      'match_type',
    ], plain: true);
    return rows;
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 12.2, height: 1.35),
              ),
            ),
          ],
        ),
      );

  void _showMarkerDetail(String kind, Map<String, dynamic> row) {
    final color = kind == 'Opportunity'
        ? _opportunityColor(row)
        : (kind == 'Signal' ? _cyan : Colors.white);
    final icon = kind == 'Opportunity'
        ? _opportunityIcon(row)
        : (kind == 'Signal' ? _signalIcon(row) : Icons.home_rounded);
    final details = _detailRows(kind, row);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071321),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: .55)),
                    ),
                    child: Icon(icon, color: color, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _markerTitle(kind, row),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'What this means',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                _whatItMeans(kind, row),
                style: const TextStyle(color: _muted, height: 1.45),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),
                for (final detail in details) _infoRow(detail.key, detail.value),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _amber.withValues(alpha: .3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: _amber, size: 18),
                        SizedBox(width: 7),
                        Text(
                          'What this does NOT prove',
                          style: TextStyle(
                            color: _amber,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _whatItDoesNotProve(kind),
                      style: const TextStyle(color: _muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow(IconData icon, Color color, String title, String text) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: color.withValues(alpha: .45)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: const TextStyle(color: _muted, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  void _showMapKey() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071321),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'What am I seeing?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text(
                'Every map marker is tappable. BridgePoint will explain the item, the evidence level and what it does not prove.',
                style: TextStyle(color: _muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              _legendRow(
                Icons.home_rounded,
                Colors.white,
                'Property',
                'A property record in the current map view. A house icon alone does not mean damage or an opportunity.',
              ),
              _legendRow(
                Icons.bolt_rounded,
                _cyan,
                'Signal / evidence',
                'A matched piece of property or area context. The icon changes for weather, fire, water, permits and transfers when BridgePoint can identify the category.',
              ),
              _legendRow(
                Icons.roofing_rounded,
                _amber,
                'Opportunity',
                'A scored lead/action candidate. Opportunity icons identify the category: roof, storm, fire, water, solar, sale/transfer, development or permit.',
              ),
              _legendRow(
                Icons.radar_rounded,
                _blue,
                'NOAA radar',
                'Weather reflectivity context. Radar stays on the latest frame until you press Play; it is not property-damage proof.',
              ),
              const Divider(height: 26),
              const Text(
                'Opportunity border priority',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _PriorityKey(color: _red, label: 'Critical / 85+'),
                  _PriorityKey(color: _amber, label: 'High / 70+'),
                  _PriorityKey(color: _cyan, label: '55+'),
                  _PriorityKey(color: _green, label: 'Lower qualified'),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Color is an extra cue only. Tap the marker to read the actual category, priority and score.',
                style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _stateMarkers() => _states
      .map((row) {
        final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
        final center = _stateCenters[code];
        if (center == null || _int(row['canonical_property_count']) <= 0) {
          return null;
        }
        final color = _int(row['opportunity_count']) > 0
            ? _green
            : (_int(row['signal_count']) > 0 ? _cyan : _blue);
        return Marker(
          point: center,
          width: 64,
          height: 44,
          child: GestureDetector(
            onTap: () => _mapController.move(center, 7.7),
            child: Tooltip(
              message: '$code • tap to zoom',
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xF2071321),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: TextStyle(color: color, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${_short(row['canonical_property_count'])} properties',
                      maxLines: 1,
                      style: const TextStyle(fontSize: 7.3, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      })
      .whereType<Marker>()
      .toList();

  List<Marker> _propertyMarkers() => _properties
      .map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () => _showMarkerDetail('Property', row),
            child: Tooltip(
              message: 'Property • tap for details',
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xEA071321),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: const Icon(Icons.home_rounded, size: 15, color: Colors.white),
              ),
            ),
          ),
        );
      })
      .whereType<Marker>()
      .toList();

  List<Marker> _signalMarkers() => _signals
      .map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        final icon = _signalIcon(row);
        return Marker(
          point: LatLng(lat, lng),
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () => _showMarkerDetail('Signal', row),
            child: Tooltip(
              message: '${_signalCategory(row)} • tap for details',
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF2071321),
                  shape: BoxShape.circle,
                  border: Border.all(color: _cyan, width: 1.5),
                ),
                child: Icon(icon, color: _cyan, size: 15),
              ),
            ),
          ),
        );
      })
      .whereType<Marker>()
      .toList();

  List<Marker> _opportunityMarkers() => _opportunities
      .map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        final color = _opportunityColor(row);
        return Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showMarkerDetail('Opportunity', row),
            child: Tooltip(
              message: '${_opportunityCategory(row)} • tap for details',
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF5071321),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: .22), blurRadius: 9),
                  ],
                ),
                child: Icon(_opportunityIcon(row), color: color, size: 21),
              ),
            ),
          ),
        );
      })
      .whereType<Marker>()
      .toList();

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
              label: const Text('Weather radar'),
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
              avatar: const Icon(Icons.location_searching_rounded, size: 16),
              onSelected: (v) => setState(() => opportunities = v),
            ),
            FilterChip(
              selected: signals,
              label: const Text('Signals / evidence'),
              avatar: const Icon(Icons.bolt_rounded, size: 16),
              onSelected: (v) => setState(() => signals = v),
            ),
            ActionChip(
              avatar: const Icon(Icons.help_outline_rounded, size: 16),
              label: const Text('What am I seeing?'),
              onPressed: _showMapKey,
            ),
            ActionChip(
              avatar: const Icon(Icons.my_location_rounded, size: 16),
              label: Text(locating ? 'Locating…' : 'My location'),
              onPressed: locating ? null : _recenterToUser,
            ),
          ],
        ),
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
                          _radarFrames.isEmpty
                              ? 'bp-radar-latest-v3'
                              : 'bp-radar-${_radarTime.millisecondsSinceEpoch}',
                        ),
                        wmsOptions: WMSTileLayerOptions(
                          baseUrl:
                              'https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?',
                          layers: const ['0'],
                          format: 'image/png',
                          transparent: true,
                          version: '1.3.0',
                          otherParameters: _radarFrames.isEmpty
                              ? const <String, String>{}
                              : {'TIME': _wmsTime(_radarTime)},
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
                            width: 30,
                            height: 30,
                            child: Tooltip(
                              message: 'Your location',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: .22),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _green, width: 2),
                                ),
                                child: const Icon(
                                  Icons.person_pin_circle_rounded,
                                  color: _green,
                                  size: 18,
                                ),
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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showMapKey,
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'BRIDGEPOINT MAP',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Icon(Icons.help_outline_rounded, size: 14),
                              ],
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Tap markers for plain-English details',
                              style: TextStyle(fontSize: 9.5, color: _muted),
                            ),
                          ],
                        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            const Icon(Icons.radar_rounded, color: _cyan, size: 18),
                            const SizedBox(width: 7),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _radarStatus,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _cyan,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (_radarFrames.length > 1)
                              Expanded(
                                flex: 3,
                                child: Slider(
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
                                ),
                              )
                            else
                              const Expanded(
                                flex: 3,
                                child: Text(
                                  'Latest reflectivity',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted, fontSize: 10.5),
                                ),
                              ),
                            IconButton(
                              tooltip: playing ? 'Pause radar' : 'Animate past 4 hours',
                              onPressed:
                                  _radarFrames.length > 1 ? _toggleRadarPlayback : null,
                              icon: Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
        const SizedBox(height: 9),
        const Text(
          'Radar stays on the latest NOAA/NWS MRMS reflectivity frame unless you press Play. You can zoom into a property without the radar intentionally disappearing. Radar is regional weather context; a blank area can mean no measurable reflectivity, and radar pixels are not proof of property damage.',
          style: TextStyle(color: _muted, fontSize: 11.2, height: 1.4),
        ),
      ],
    );
  }
}

class _PriorityKey extends StatelessWidget {
  const _PriorityKey({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
