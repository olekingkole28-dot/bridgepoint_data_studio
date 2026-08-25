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

  bool radar = true;
  bool satellite = true;
  bool opportunities = true;
  bool signals = true;
  bool playing = true;
  bool intelligenceBusy = false;
  bool locating = false;
  int frame = 48;
  double _zoom = 4;
  Timer? timer;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _opportunities = const [];
  List<Map<String, dynamic>> _signals = const [];
  String? _intelligenceMessage;
  String? _locationMessage;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _amber = Color(0xFFFFC857);
  static const _green = Color(0xFF38D49A);
  static const _radarMaxHonestZoom = 10.5;

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
    _loadNationalIntelligence();
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

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Future<void> _loadNationalIntelligence() async {
    if (intelligenceBusy) return;
    setState(() {
      intelligenceBusy = true;
      _intelligenceMessage = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_flutter_intelligence_map_national_v346',
        params: {
          'p_model_key': 'all',
          'p_min_lat': null,
          'p_max_lat': null,
          'p_min_lng': null,
          'p_max_lng': null,
          'p_min_score': 45,
          'p_opportunity_limit': 240,
          'p_signal_limit': 80,
        },
      );
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _opportunities = _rows(map['opportunities']);
        _signals = _rows(map['signals']);
        if (map['map_intelligence_available'] == false) {
          _intelligenceMessage =
              'Map intelligence is not included in this account package.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _intelligenceMessage = 'Map intelligence unavailable: $e');
      }
    } finally {
      if (mounted) setState(() => intelligenceBusy = false);
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
      if (!enabled) {
        throw StateError('Location services are disabled on this device.');
      }
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
            'Map recentered locally. Your precise device location was not sent to the BridgePoint backend.';
      });
      _mapController.move(point, 14);
    } catch (e) {
      if (mounted) setState(() => _locationMessage = '$e');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  double? _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  String _clock(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.hour}:$minute';
  }

  Color _opportunityColor(Map<String, dynamic> row) {
    final priority = '${row['priority'] ?? ''}'.toLowerCase();
    final score = _double(row['score']) ?? 0;
    if (priority.contains('critical') || score >= 85) {
      return const Color(0xFFFF6B6B);
    }
    if (priority.contains('high') || score >= 70) return _amber;
    if (score >= 55) return _cyan;
    return _green;
  }

  void _showOpportunity(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'WHY THIS RANKED',
                style: TextStyle(
                  color: _cyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${row['title'] ?? row['full_address'] ?? 'Opportunity'}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              if ('${row['full_address'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('${row['full_address']}',
                    style: const TextStyle(color: _muted)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Score ${row['score'] ?? '—'}')),
                  Chip(label: Text('${row['priority'] ?? 'priority unavailable'}')),
                  Chip(label: Text('${row['direct_source_count'] ?? 0} direct sources')),
                  Chip(label: Text('${row['confidence_score'] ?? '—'}% confidence')),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${row['explanation'] ?? row['reason'] ?? 'No explanation returned.'}',
                style: const TextStyle(height: 1.45),
              ),
              if ('${row['recommended_action'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Next best action: ${row['recommended_action']}',
                  style: const TextStyle(
                    color: _cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Evidence families: ${row['independent_evidence_families'] ?? row['evidence_families'] ?? 'unavailable'}',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 8),
              const Text(
                'Opportunity ranking is decision support, not confirmed damage or a guaranteed customer event.',
                style: TextStyle(color: _amber, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignal(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${row['signal_name'] ?? row['title'] ?? 'Signal'}',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                '${row['full_address'] ?? [row['municipality'], row['state_code']].where((x) => x != null).join(', ')}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 10),
              Text(
                '${row['evidence_summary'] ?? row['title'] ?? 'No evidence summary returned.'}',
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 8),
              Text(
                'Family: ${row['signal_family'] ?? 'unknown'} • detected ${row['detected_at'] ?? 'unknown'}',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _opportunityMarkers() => _opportunities.map((row) {
        final lat = _double(row['latitude']);
        final lng = _double(row['longitude']);
        if (lat == null || lng == null) return null;
        final color = _opportunityColor(row);
        return Marker(
          point: LatLng(lat, lng),
          width: 32,
          height: 32,
          child: Tooltip(
            message:
                '${row['title'] ?? row['full_address'] ?? 'Opportunity'} • score ${row['score'] ?? '—'}',
            child: GestureDetector(
              onTap: () => _showOpportunity(row),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xE6071321),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(Icons.home_work_rounded, size: 17, color: color),
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
          width: 22,
          height: 22,
          child: Tooltip(
            message: '${row['signal_name'] ?? row['title'] ?? 'Signal'}',
            child: GestureDetector(
              onTap: () => _showSignal(row),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xD9071321),
                  shape: BoxShape.circle,
                  border: Border.all(color: _cyan),
                ),
                child: const Icon(Icons.bolt_rounded, size: 12, color: _cyan),
              ),
            ),
          ),
        );
      }).whereType<Marker>().toList();

  Widget _legend() => Card(
        color: const Color(0xE6071321),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('MAP KEY',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              _LegendLine(Icons.home_work_rounded, 'Ranked opportunity', _amber),
              _LegendLine(Icons.bolt_rounded, 'Active signal', _cyan),
              _LegendLine(Icons.my_location_rounded, 'Your device', _green),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.sizeOf(context).height.clamp(520.0, 820.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Geospatial Intelligence',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text(
                    'Weather, imagery, verified opportunities and active signals in one source-aware property intelligence map.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: intelligenceBusy ? null : _loadNationalIntelligence,
              tooltip: 'Refresh intelligence',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (intelligenceBusy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_intelligenceMessage != null) ...[
          const SizedBox(height: 8),
          Text(_intelligenceMessage!, style: const TextStyle(color: _amber)),
        ],
        if (_locationMessage != null) ...[
          const SizedBox(height: 8),
          Text(_locationMessage!, style: const TextStyle(color: _muted, fontSize: 10)),
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
              onSelected: (v) => setState(() => satellite = v),
            ),
            FilterChip(
              selected: radar,
              label: const Text('NOAA radar'),
              avatar: const Icon(Icons.radar_rounded, size: 18),
              onSelected: (v) => setState(() => radar = v),
            ),
            FilterChip(
              selected: opportunities,
              label: Text('Opportunities (${_opportunities.length})'),
              avatar: const Icon(Icons.home_work_outlined, size: 18),
              onSelected: (v) => setState(() => opportunities = v),
            ),
            FilterChip(
              selected: signals,
              label: Text('Signals (${_signals.length})'),
              avatar: const Icon(Icons.bolt_outlined, size: 18),
              onSelected: (v) => setState(() => signals = v),
            ),
            ActionChip(
              avatar: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
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
            const Chip(
              avatar: Icon(Icons.layers_outlined, size: 18),
              label: Text('Premium aerial / 3D via licensed connectors'),
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
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.5, -98.35),
                    initialZoom: 4,
                    minZoom: 3,
                    maxZoom: 18,
                    onPositionChanged: (camera, hasGesture) {
                      if ((camera.zoom - _zoom).abs() > 0.02 && mounted) {
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
                    color: const Color(0xE6071321),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      child: Text(
                        'ZOOM ${_zoom.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                if (radar && !_showRawRadar)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 74,
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
                                'Raw NOAA reflectivity is hidden at property-level zoom because the source is roughly 1 km resolution. BridgePoint keeps matched storm/event evidence available without stretching radar pixels into fake roof-level detail.',
                                style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
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
                                  'NOAA MRMS • ~1 KM SOURCE',
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
                              'Four-hour time-enabled radar • about 5-minute frames • raw reflectivity is regional weather context, not roof-level proof.',
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
              'Map truth contract: marker intelligence is sourced from BridgePoint verified ranked opportunities and active property signals with state/package access controls. Nearmap, EagleView, LiDAR/DSM, historical aerial and other premium layers remain gated by provider rights, coverage, resolution and readiness.',
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
