import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointGlobalSearchV2 extends StatefulWidget {
  const BridgePointGlobalSearchV2({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  State<BridgePointGlobalSearchV2> createState() => _BridgePointGlobalSearchV2State();
}

class _BridgePointGlobalSearchV2State extends State<BridgePointGlobalSearchV2> {
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  final _query = TextEditingController();
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.length >= 2) {
      _query.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const ['suggestions', 'properties', 'results', 'items', 'rows']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
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
        'bridgepoint_property_suggestions_v192',
        params: {'p_query': q, 'p_limit': 40},
      );
      if (mounted) setState(() => _results = _rows(raw));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<dynamic> _safe(String rpc, Map<String, dynamic> params) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'error': '$e', 'rpc': rpc};
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = '${row['property_id'] ?? row['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    final values = await Future.wait([
      _safe('bridgepoint_flutter_property_detail_v344', {'p_property_id': id}),
      _safe('bridgepoint_property_timeline_v78', {'p_property_id': id, 'p_limit': 120}),
      _safe('bridgepoint_property_geometry_v837', {'p_property_id': id, 'p_limit': 25}),
      _safe('bridgepoint_digital_twin_summary_v509', {'p_property_id': id}),
      _safe('bridgepoint_customer_notes_v70', {'p_property_id': id, 'p_limit': 50}),
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    final detail = _map(values[0]);
    final timeline = _map(values[1]);
    final geometry = _map(values[2]);
    final twin = _map(values[3]);
    final notes = _map(values[4]);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .9,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Text(
                '${row['full_address'] ?? detail['property']?['full_address'] ?? 'Property'}',
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                '${row['municipality'] ?? ''} ${row['state_code'] ?? ''} • ${row['parcel_number'] ?? 'parcel unavailable'}',
                style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _PayloadPanel(title: 'Property intelligence', icon: Icons.home_work_outlined, payload: detail),
              const SizedBox(height: 10),
              _PayloadPanel(title: 'Timeline', icon: Icons.timeline_rounded, payload: timeline),
              const SizedBox(height: 10),
              _PayloadPanel(title: '2D / 3D geometry', icon: Icons.view_in_ar_rounded, payload: geometry),
              const SizedBox(height: 10),
              _PayloadPanel(title: 'Digital twin', icon: Icons.account_tree_rounded, payload: twin),
              const SizedBox(height: 10),
              _PayloadPanel(title: 'Notes & follow-ups', icon: Icons.note_alt_outlined, payload: notes),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Search BridgePoint', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
          'Nationwide property search across the BridgePoint foundation. Search by address, parcel, owner or municipality, then open the connected property intelligence record.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                autofocus: widget.initialQuery == null,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  labelText: 'Address, parcel, owner or municipality',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search'),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: _amber, fontSize: 10)),
        ],
        const SizedBox(height: 14),
        if (_results.isEmpty && !_busy)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
            ),
            child: const Row(
              children: [
                Icon(Icons.travel_explore_rounded, color: _cyan),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search the national BridgePoint property foundation. Results appear as underlying property data becomes available in each state.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ),
              ],
            ),
          )
        else
          ..._results.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: _busy ? null : () => _open(row),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cyan.withValues(alpha: .10)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_work_outlined, color: _cyan),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['full_address'] ?? row['address'] ?? 'Property'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${row['municipality'] ?? row['city'] ?? ''} ${row['state_code'] ?? ''} • ${row['parcel_number'] ?? 'No parcel'} • ${row['property_type'] ?? 'Property'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      if (row['top_score'] != null)
                        Text(
                          '${row['top_score']}',
                          style: const TextStyle(color: _green, fontWeight: FontWeight.w900),
                        ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: _muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PayloadPanel extends StatelessWidget {
  const _PayloadPanel({required this.title, required this.icon, required this.payload});
  final String title;
  final IconData icon;
  final dynamic payload;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: ExpansionTile(
          initiallyExpanded: title == 'Property intelligence',
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: Icon(icon, color: const Color(0xFF48E1FF)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          children: [
            Align(alignment: Alignment.centerLeft, child: _Payload(payload: payload)),
          ],
        ),
      );
}

class _Payload extends StatelessWidget {
  const _Payload({required this.payload});
  final dynamic payload;

  @override
  Widget build(BuildContext context) {
    if (payload is Map) {
      final entries = (payload as Map).entries.take(80).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries)
            if (entry.value is Map || entry.value is List)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${entry.key}'.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: _Payload(payload: entry.value),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${entry.key}'.replaceAll('_', ' ') + ': ${entry.value}',
                  style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 11.5, height: 1.35),
                ),
              ),
        ],
      );
    }
    if (payload is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in (payload as List).take(60))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: _Payload(payload: item),
            ),
        ],
      );
    }
    return Text('$payload', style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 11.5));
  }
}
