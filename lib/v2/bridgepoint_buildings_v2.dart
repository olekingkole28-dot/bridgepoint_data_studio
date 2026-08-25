import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';

class BridgePointBuildingsV2 extends StatefulWidget {
  const BridgePointBuildingsV2({super.key});

  @override
  State<BridgePointBuildingsV2> createState() => _BridgePointBuildingsV2State();
}

class _BridgePointBuildingsV2State extends State<BridgePointBuildingsV2> {
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

  final _query = TextEditingController();
  late Future<dynamic> _summary;
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
    try { return await Supabase.instance.client.rpc(rpc, params: params); } catch (e) { return {'available': false, 'error': '$e', 'rpc': rpc}; }
  }

  Future<dynamic> _loadSummary() async {
    final values = await Future.wait([
      _safe('bridgepoint_owner_expansion_status_v736'),
      _safe('bridgepoint_twin_ingestion_requirements_v509'),
    ]);
    return {'owner': values[0], 'requirements': values[1]};
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['suggestions', 'items', 'results', 'rows']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  String _number(dynamic value) {
    final n = value is num ? value.round() : int.tryParse('${value ?? ''}') ?? 0;
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() { _busy = true; _error = null; _results = const []; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_property_suggestions_v192', params: {'p_query': q, 'p_limit': 12});
      if (mounted) setState(() => _results = _rows(raw));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> property) async {
    final id = '${property['property_id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    setState(() { _busy = true; _selected = property; _geometry = const {}; _twin = const {}; _error = null; });
    final values = await Future.wait([
      _safe('bridgepoint_property_geometry_v837', {'p_property_id': id, 'p_limit': 25}),
      _safe('bridgepoint_digital_twin_summary_v509', {'p_property_id': id}),
    ]);
    if (!mounted) return;
    setState(() { _geometry = _map(values[0]); _twin = _map(values[1]); _busy = false; });
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
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Buildings & Digital Twin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('The 2D footprints, 3D source geometry, national building-geometry materialization and property digital-twin work are surfaced here instead of being buried behind backend tables.', style: TextStyle(color: _muted, height: 1.45)),
            ])),
            IconButton.filledTonal(onPressed: () => setState(() => _summary = _loadSummary()), icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh building intelligence'),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final columns = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 620 ? 2 : 1;
            final width = (c.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: width, child: _BuildingMetric('CT 2D BUILDINGS', _number(physical['ct_2d_rows']), '2023 2D source rows', Icons.crop_square_rounded, _cyan)),
              SizedBox(width: width, child: _BuildingMetric('CT 3D BUILDINGS', _number(physical['ct_3d_rows']), '2023 3D source rows', Icons.threed_rotation_rounded, _blue)),
              SizedBox(width: width, child: _BuildingMetric('BUILDING GEOMETRY', _number(us['building_geometry_rows']), '${_number(us['building_geometry_states'])} states materialized', Icons.view_in_ar_rounded, _green)),
              SizedBox(width: width, child: _BuildingMetric('DIGITAL TWINS', _number(physical['digital_twins']), '${_number(physical['us_digital_twins'])} U.S. twins', Icons.account_tree_rounded, _amber)),
            ]);
          }),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .07))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Open a real property model', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Search a property, then switch between source footprint and schematic massing in the interactive geometry viewer.', style: TextStyle(color: _muted, fontSize: 10)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: const InputDecoration(labelText: 'Address, parcel, owner or municipality', prefixIcon: Icon(Icons.search_rounded)))),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: _busy ? null : _search, icon: const Icon(Icons.search_rounded), label: const Text('Find model')),
              ]),
              if (_busy) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: _amber, fontSize: 10)),
              ],
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 10),
                ..._results.map((row) => InkWell(
                  onTap: () => _open(row),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: _soft.withValues(alpha: .65), borderRadius: BorderRadius.circular(11)),
                    child: Row(children: [
                      const Icon(Icons.home_work_outlined, color: _cyan, size: 18),
                      const SizedBox(width: 9),
                      Expanded(child: Text('${row['full_address'] ?? row['municipality'] ?? row['parcel_number'] ?? 'Property'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('${row['top_score'] ?? ''}', style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 5),
                      const Icon(Icons.chevron_right_rounded, color: _muted),
                    ]),
                  ),
                )),
              ],
            ]),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 14),
            Text('${_selected!['full_address'] ?? _selected!['municipality'] ?? 'Selected property'}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            BridgePointBuildingGeometryV2(payload: _geometry),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .07))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.account_tree_rounded, color: _amber), SizedBox(width: 8), Text('Digital Twin', style: TextStyle(fontWeight: FontWeight.w900))]),
                const SizedBox(height: 9),
                _Payload(payload: _twin),
              ]),
            ),
          ],
        ]);
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
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _BridgePointBuildingsV2State._panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .13))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 11), Text(label, style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(detail, style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 10))]));
}

class _Payload extends StatelessWidget {
  const _Payload({required this.payload});
  final dynamic payload;
  @override
  Widget build(BuildContext context) {
    if (payload is Map) {
      final entries = (payload as Map).entries.take(60).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final e in entries) if (e.value is! Map && e.value is! List) Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('${e.key.toString().replaceAll('_', ' ')}: ${e.value}', style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 10, height: 1.35))) else ExpansionTile(tilePadding: EdgeInsets.zero, dense: true, title: Text(e.key.toString().replaceAll('_', ' '), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), children: [Padding(padding: const EdgeInsets.only(left: 8, bottom: 8), child: _Payload(payload: e.value))])]);
    }
    if (payload is List) return Column(children: [for (final item in (payload as List).take(30)) _Payload(payload: item)]);
    return Text('$payload', style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 10));
  }
}
