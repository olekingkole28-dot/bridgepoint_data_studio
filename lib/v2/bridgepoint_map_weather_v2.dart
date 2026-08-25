import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointMapWeatherV2 extends StatefulWidget {
  const BridgePointMapWeatherV2({super.key});

  @override
  State<BridgePointMapWeatherV2> createState() => _BridgePointMapWeatherV2State();
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

  bool radar = true;
  bool satellite = true;
  bool opportunities = true;
  bool signals = true;
  bool properties = true;
  bool playing = true;
  bool busy = false;
  bool locating = false;
  int frame = 48;
  double _zoom = 8.2;
  Timer? _timer;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _signals = const [];
  List<Map<String, dynamic>> _properties = const [];
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

  @override
  void initState() {
    super.initState();
    _loadIntelligence();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted && radar && playing) {
        setState(() => frame = frame >= 48 ? 0 : frame + 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const [
        'opportunities',
        'signals',
        'points',
        'properties',
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

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadIntelligence() async {
    if (busy) return;
    setState(() {
      busy = true;
      _message = null;
    });

    try {
      var nextOpportunities = <Map<String, dynamic>>[];
      var nextSignals = <Map<String, dynamic>>[];
      var nextProperties = <Map<String, dynamic>>[];
      var usedLegacyCt = false;

      final national = await _safe(
        'bridgepoint_flutter_intelligence_map_national_v346',
        {
          'p_model_key': 'all',
          'p_min_lat': null,
          'p_max_lat': null,
          'p_min_lng': null,
          'p_max_lng': null,
          'p_min_score': 45,
          'p_opportunity_limit': 240,
          'p_signal_limit': 120,
        },
      );
      if (national is Map) {
        nextOpportunities = _rows(national['opportunities']);
        nextSignals = _rows(national['signals']);
      }

      // Proven Connecticut feed used by the working pre-V2 map. If national
      // balancing returns no points, V2 must not degrade into an empty map.
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

      // Always give the map a real property layer when this account has
      // Property Profiles. This is separate from ranked opportunities.
      final propertyPayload = await _safe(
        'bridgepoint_flutter_properties_v725',
        {
          'p_search': null,
          'p_municipality': null,
          'p_property_type': null,
          'p_state_code': 'CT',
          'p_limit': 50,
          'p_offset': 0,
        },
      );
      if (propertyPayload is Map) {
        nextProperties = _rows(propertyPayload['properties']);
      }

      if (!mounted) return;
      setState(() {
        _opportunities = nextOpportunities;
        _signals = nextSignals;
        _properties = nextProperties;
        _message = usedLegacyCt
            ? 'Loaded the proven Connecticut opportunity feed plus live property and weather layers.'
            : 'Live property, opportunity, signal and weather layers refreshed.';
      });

      Map<String, dynamic>? focus;
      for (final row in nextOpportunities) {
        if (_double(row['latitude']) != null &&
            _double(row['longitude']) != null &&
            '${row['state_code'] ?? 'CT'}'.toUpperCase() == 'CT') {
          focus = row;
          break;
        }
      }
      focus ??= nextProperties.cast<Map<String, dynamic>?>().firstWhere(
            (row) =>
                row != null &&
                _double(row['latitude']) != null &&
                _double(row['longitude']) != null,
            orElse: () => null,
          );
      if (focus != null) {
        final lat = _double(focus['latitude']);
        final lng = _double(focus['longitude']);
        if (lat != null && lng != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mapController.move(LatLng(lat, lng), 8.2);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Map refresh error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
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
    final priority = '${row['priority'] ?? row['opportunity_priority'] ?? ''}'.toLowerCase();
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
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
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

  List<Marker> _propertyMarkers() => _properties.map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 22,
          height: 22,
          child: Tooltip(
            message: '${row['full_address'] ?? row['municipality'] ?? 'Property'}',
            child: GestureDetector(
              onTap: () => _showPayload(
                '${row['full_address'] ?? row['municipality'] ?? 'Property'}',
                row,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xDD071321),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .55)),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  size: 12,
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
          width: 36,
          height: 36,
          child: Tooltip(
            message:
                '${row['full_address'] ?? row['title'] ?? 'Opportunity'} • score ${_score(row) ?? '—'}',
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
                    BoxShadow(color: color.withValues(alpha: .30), blurRadius: 10),
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
          width: 24,
          height: 24,
          child: Tooltip(
            message: '${row['signal_name'] ?? row['title'] ?? 'Signal'}',
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
                    'Real properties, BridgePoint opportunities, active signals, satellite imagery and animated NOAA radar on the same Connecticut-first map.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: busy ? null : _loadIntelligence,
              tooltip: 'Refresh map intelligence',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: _green, fontSize: 10)),
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
                    initialCenter: const LatLng(41.60, -72.70),
                    initialZoom: 8.2,
                    minZoom: 3,
                    maxZoom: 18,
                    onPositionChanged: (camera, hasGesture) {
                      if ((camera.zoom - _zoom).abs() > .02 && mounted) {
                        setState(() => _zoom = camera.zoom);
                      }
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
                if (radar && !_showRawRadar)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 78,
                    child: Card(
                      color: const Color(0xF2071321),
                      child: const Padding(
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
              'Map truth contract: properties, ranked opportunities, active signals and weather remain distinct layers. Premium aerial/LiDAR/DSM and other licensed imagery are shown only where provider rights, coverage and readiness allow.',
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
