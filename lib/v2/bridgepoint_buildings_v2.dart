import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';

class BridgePointBuildingsV2 extends StatefulWidget {
  const BridgePointBuildingsV2({super.key});

  @override
  State<BridgePointBuildingsV2> createState() => _BridgePointBuildingsV2State();
}

class _BridgePointBuildingsV2State extends State<BridgePointBuildingsV2> {
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  final _query = TextEditingController();
  late Future<dynamic> _summary;
  List<Map<String, dynamic>> _stateRows = const [];
  String _state = 'CT';
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic> _geometry = const {};
  Map<String, dynamic> _twin = const {};
  Map<String, dynamic>? _selected;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<dynamic> _loadSummary() async {
    final values = await Future.wait([
      _safe('bridgepoint_owner_expansion_status_v736'),
      _safe('bridgepoint_twin_ingestion_requirements_v509'),
      _safe('bridgepoint_flutter_map_state_status_v838'),
    ]);
    final statePayload = values[2];
    final rows = _rows(
      statePayload is Map ? statePayload['states'] : statePayload,
    );
    if (mounted && rows.isNotEmpty) {
      final codes = rows.map((row) => '${row['state_code'] ?? ''}').toSet();
      setState(() {
        _stateRows = rows;
        if (!codes.contains(_state)) {
          _state = '${rows.first['state_code'] ?? 'CT'}';
        }
      });
    }
    return {
      'owner': values[0],
      'requirements': values[1],
      'state_status': values[2],
    };
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
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
        'suggestions',
        'states',
        'items',
        'results',
        'rows',
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

  Map<String, dynamic> get _stateRow {
    for (final row in _stateRows) {
      if ('${row['state_code'] ?? ''}' == _state) return row;
    }
    return const {};
  }

  void _selectState(String? value) {
    if (value == null || value == _state) return;
    setState(() {
      _state = value;
      _results = const [];
      _geometry = const {};
      _twin = const {};
      _selected = null;
      _query.clear();
    });
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_flutter_properties_state_browse_v840',
        params: <String, dynamic>{
          'p_state_code': _state,
          'p_search': q,
          'p_municipality': null,
          'p_property_type': null,
          'p_limit': 12,
          'p_offset': 0,
        },
      );
      final rows = _rows(raw).take(12).toList();
      if (!mounted) return;
      setState(() {
        _results = rows;
        if (rows.isEmpty) _error = 'No matching $_state properties were found.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Property search is temporarily unavailable. Try a shorter address or parcel search.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> property) async {
    final id = '${property['property_id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    setState(() {
      _busy = true;
      _selected = property;
      _geometry = const {};
      _twin = const {};
      _error = null;
    });
    final values = await Future.wait([
      _safe('bridgepoint_property_geometry_v837', {
        'p_property_id': id,
        'p_limit': 25,
      }),
      _safe('bridgepoint_digital_twin_summary_v509', {'p_property_id': id}),
    ]);
    if (!mounted) return;
    setState(() {
      _geometry = _map(values[0]);
      _twin = _map(values[1]);
      _busy = false;
    });
  }

  Color _statusColor(String status, int count) {
    final s = status.toUpperCase();
    if (count > 0 && (s == 'READY' || s == 'LIVE')) return _green;
    if (count > 0) return _cyan;
    if (_int(_stateRow['canonical_property_count']) > 0) return _blue;
    return _muted;
  }

  String _physicalStatusText(Map<String, dynamic> stateRow) {
    final propertyCount = _int(stateRow['canonical_property_count']);
    final twoD = _int(stateRow['building_2d_count']);
    final threeD = _int(stateRow['building_3d_count']);
    if (threeD > 0) {
      return '$_state has live 3D building-geometry coverage. Property models below use the actual geometry/twin payload returned for the selected property.';
    }
    if (twoD > 0) {
      return '$_state has 2D building coverage. 3D geometry is still building and will surface automatically when the state truth layer reports it.';
    }
    if (propertyCount > 0) {
      return '$_state already has ${_number(propertyCount)} properties, but state-level 2D/3D physical geometry is not ready yet. That is shown as a readiness gap—not as missing property data.';
    }
    return '$_state property and physical-intelligence foundations are still building.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = _map(snapshot.data);
        final owner = _map(summary['owner']);
        final us = _map(owner['us']);
        final physical = _map(owner['physical']);
        final stateRow = _stateRow;
        final twoDCount = _int(stateRow['building_2d_count']);
        final threeDCount = _int(stateRow['building_3d_count']);
        final twoDStatus = '${stateRow['building_2d_status'] ?? 'MISSING'}';
        final threeDStatus = '${stateRow['building_3d_status'] ?? 'MISSING'}';
        final foundation = _int(stateRow['canonical_property_count']);

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
                        'Buildings & Digital Twin',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '2D footprints, 3D source geometry, national building-geometry materialization and property digital twins—with state readiness shown separately so physical coverage appears as it actually comes online.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(() => _summary = _loadSummary()),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh building intelligence',
                ),
              ],
            ),
            if (snapshot.connectionState == ConnectionState.waiting) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 720;
                final selector = DropdownButtonFormField<String>(
                  initialValue: _state,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Physical intelligence state',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: (_stateRows.isEmpty
                          ? <Map<String, dynamic>>[
                              {'state_code': _state, 'state_name': _state},
                            ]
                          : _stateRows)
                      .map(
                        (row) => DropdownMenuItem<String>(
                          value: '${row['state_code']}',
                          child: Text(
                            '${row['state_code']} • ${row['state_name'] ?? row['state_code']} • ${row['build_status'] ?? 'BUILDING'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _selectState,
                );
                final status = Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _statusColor(threeDStatus, threeDCount)
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _statusColor(threeDStatus, threeDCount)
                          .withValues(alpha: .20),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        threeDCount > 0
                            ? Icons.view_in_ar_rounded
                            : twoDCount > 0
                                ? Icons.layers_rounded
                                : Icons.construction_rounded,
                        color: _statusColor(threeDStatus, threeDCount),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_state • 2D $twoDStatus • 3D $threeDStatus',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _physicalStatusText(stateRow),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [selector, const SizedBox(height: 9), status],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 340, child: selector),
                    const SizedBox(width: 10),
                    Expanded(child: status),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 620 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: _BuildingMetric(
                        '$_state PROPERTY FOUNDATION',
                        _number(foundation),
                        '${stateRow['build_status'] ?? 'BUILDING'} state foundation',
                        Icons.apartment_rounded,
                        _blue,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _BuildingMetric(
                        '$_state 2D BUILDINGS',
                        _number(twoDCount),
                        twoDStatus,
                        Icons.crop_square_rounded,
                        _cyan,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _BuildingMetric(
                        '$_state 3D GEOMETRY',
                        _number(threeDCount),
                        threeDStatus,
                        Icons.threed_rotation_rounded,
                        _green,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _BuildingMetric(
                        'DIGITAL TWINS',
                        _number(physical['digital_twins']),
                        '${_number(physical['us_digital_twins'])} U.S. twins • ${_number(us['building_geometry_states'])} geometry states',
                        Icons.account_tree_rounded,
                        _amber,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Open a real $_state property model',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Search a property, then inspect the highest-fidelity verified geometry BridgePoint has for it. Properties with source XYZ surfaces open the rotatable source-surface model; footprint and massing remain truthful fallbacks when stronger geometry is not available.',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            labelText: '$_state address, parcel or municipality',
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _busy ? null : _search,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Find model'),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: _amber, fontSize: 10),
                    ),
                  ],
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._results.map(
                      (row) => InkWell(
                        onTap: () => _open(row),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: _soft.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.home_work_outlined,
                                color: _cyan,
                                size: 18,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  '${row['full_address'] ?? row['municipality'] ?? row['parcel_number'] ?? 'Property'}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                '${row['state_code'] ?? _state}',
                                style: const TextStyle(
                                  color: _blue,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: _muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 14),
              Text(
                '${_selected!['full_address'] ?? _selected!['municipality'] ?? 'Selected property'}',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              BridgePointBuildingGeometryV2(payload: _geometry),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_tree_rounded, color: _amber),
                        SizedBox(width: 8),
                        Text(
                          'Digital Twin',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _TwinSummary(payload: _twin),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BuildingMetric extends StatelessWidget {
  const _BuildingMetric(this.label, this.value, this.detail, this.icon, this.color);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BridgePointBuildingsV2State._panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 11),
            Text(
              label,
              style: const TextStyle(
                color: _BridgePointBuildingsV2State._muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _BridgePointBuildingsV2State._muted,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
}

class _TwinSummary extends StatelessWidget {
  const _TwinSummary({required this.payload});
  final dynamic payload;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _label(String value) => value
      .replaceAll('L0_PROPERTY_SHELL', 'Property shell')
      .replaceAll('L1_BUILDING_MASSING', 'Building massing')
      .replaceAll('L2_SOURCE_SURFACE_MODEL', 'Source XYZ surface model')
      .replaceAll('L2_ROOF_FACADE', 'Roof + facade model')
      .replaceAll('L3_SEMANTIC_BIM', 'Semantic BIM')
      .replaceAll('L4_OPERATIONAL_TWIN', 'Operational twin');

  String _pct(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '—';
    return '${(n * 100).clamp(0, 100).toStringAsFixed(0)}%';
  }

  Widget _metric(String label, String value, IconData icon, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 155, maxWidth: 265),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF081625),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 11.5)),
          ])),
        ]),
      );

  Widget _readiness(String label, dynamic raw) {
    final value = _map(raw);
    final ready = value['ready'] == true;
    return Chip(
      avatar: Icon(ready ? Icons.check_circle_rounded : Icons.pending_outlined,
          size: 16,
          color: ready ? _BridgePointBuildingsV2State._green : _BridgePointBuildingsV2State._muted),
      label: Text('$label • ${ready ? 'ready' : 'needs more evidence'}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final twin = _map(payload);
    if (twin.isEmpty || twin['available'] == false) {
      return const Text('Digital-twin intelligence is not available for this property yet.',
          style: TextStyle(color: _BridgePointBuildingsV2State._muted));
    }
    final fidelity = _label('${twin['fidelity_level'] ?? 'Not classified'}');
    final sourceSurface = twin['source_surface_geometry'] == true ||
        '${twin['fidelity_level'] ?? ''}' == 'L2_SOURCE_SURFACE_MODEL';
    final exact = twin['exact_replica_claim_allowed'] == true;
    final readiness = _map(twin['simulation_readiness']);
    final upgrades = twin['upgrade_path'] is List
        ? List<dynamic>.from(twin['upgrade_path'])
        : const <dynamic>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _metric('Fidelity', fidelity, Icons.view_in_ar_rounded, _BridgePointBuildingsV2State._cyan),
        _metric('Overall confidence', _pct(twin['overall_confidence']), Icons.verified_outlined, _BridgePointBuildingsV2State._green),
        _metric('Source XYZ surfaces', sourceSurface ? 'Available' : 'Not linked yet', Icons.layers_rounded,
            sourceSurface ? _BridgePointBuildingsV2State._green : _BridgePointBuildingsV2State._muted),
        _metric('Exact replica claim', exact ? 'Verified' : 'Not claimed', Icons.fact_check_outlined,
            exact ? _BridgePointBuildingsV2State._green : _BridgePointBuildingsV2State._amber),
      ]),
      if (readiness.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Simulation readiness', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _readiness('Wind envelope', readiness['wind_envelope']),
          _readiness('Roof water pooling', readiness['roof_water_pooling']),
          _readiness('Flood site flow', readiness['flood_site_flow']),
          _readiness('Window retrofit', readiness['thermal_window_retrofit']),
        ]),
      ],
      if (upgrades.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('What would raise fidelity', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(upgrades.take(4).map((e) => '${e ?? ''}'.replaceAll('_', ' ')).where((e) => e.trim().isNotEmpty).join(' • '),
            style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 12, height: 1.45)),
      ],
      const SizedBox(height: 10),
      const Text(
        'Source-surface geometry can reproduce observed roof and wall form, but BridgePoint does not call it photorealistic or an exact replica until imagery, mesh, or other verified facade evidence supports that claim.',
        style: TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 11.5, height: 1.4),
      ),
    ]);
  }
}

class _Payload extends StatelessWidget {
  const _Payload({required this.payload});
  final dynamic payload;

  @override
  Widget build(BuildContext context) {
    if (payload is Map) {
      final entries = (payload as Map).entries.take(60).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in entries)
            if (e.value is! Map && e.value is! List)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${e.key.toString().replaceAll('_', ' ')}: ${e.value}',
                  style: const TextStyle(
                    color: _BridgePointBuildingsV2State._muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              )
            else
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  e.key.toString().replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: _Payload(payload: e.value),
                  ),
                ],
              ),
        ],
      );
    }
    if (payload is List) {
      return Column(
        children: [
          for (final item in (payload as List).take(30)) _Payload(payload: item),
        ],
      );
    }
    return Text(
      '$payload',
      style: const TextStyle(
        color: _BridgePointBuildingsV2State._muted,
        fontSize: 12.5,
      ),
    );
  }
}
