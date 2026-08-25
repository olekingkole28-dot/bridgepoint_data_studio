import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerSurfaceAudit extends StatefulWidget {
  const BridgePointOwnerSurfaceAudit({super.key});

  @override
  State<BridgePointOwnerSurfaceAudit> createState() =>
      _BridgePointOwnerSurfaceAuditState();
}

class _BridgePointOwnerSurfaceAuditState
    extends State<BridgePointOwnerSurfaceAudit> {
  late Future<Map<String, dynamic>> _request;
  String _query = '';
  String _status = 'ALL';

  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await Supabase.instance.client.rpc(
      'bridgepoint_owner_capability_surface_coverage_v791',
      params: const {'p_limit': 1000},
    );
    if (raw is! Map) {
      throw const FormatException('Unexpected capability-surface response.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Color _color(String status) => switch (status) {
        'COVERED' => _green,
        'PARTIAL' => _amber,
        'UNCLASSIFIED' => _red,
        _ => _muted,
      };

  Widget _metric(String label, dynamic value, Color color) => Container(
        width: 145,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _panelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _cyan));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(snapshot.error.toString(),
                  style: const TextStyle(color: _amber)),
            ),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final allRows = (data['needs_surface'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        final needle = _query.trim().toLowerCase();
        final rows = allRows.where((row) {
          final status = '${row['status'] ?? 'UNCLASSIFIED'}';
          if (_status != 'ALL' && status != _status) return false;
          if (needle.isEmpty) return true;
          return [
            row['capability_key'],
            row['capability_label'],
            row['source_reference'],
            row['audience'],
            row['surface_kind'],
            row['surface_reference'],
          ].join(' ').toLowerCase().contains(needle);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _request = _load());
            await _request;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Backend → Product Surfaces',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text(
                          'Every BridgePoint capability must be deliberately assigned to customer UI, owner UI, an integration/API, internal automation, or security-internal use. UNCLASSIFIED means unfinished.',
                          style: TextStyle(color: _muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh surface audit',
                    onPressed: () => setState(() => _request = _load()),
                    icon: const Icon(Icons.refresh_rounded, color: _cyan),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metric('TOTAL', data['total'] ?? '—', Colors.white),
                  _metric('COVERED', data['covered'] ?? '—', _green),
                  _metric('PARTIAL', data['partial'] ?? '—', _amber),
                  _metric('UNCLASSIFIED', data['unclassified'] ?? '—', _red),
                  _metric('STRICT COVERAGE',
                      '${data['strict_coverage_pct'] ?? '—'}%', _cyan),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _cyan.withOpacity(.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cyan.withOpacity(.18)),
                ),
                child: const Text(
                  'Classification is not the same as customer exposure. Security internals stay internal; automation stays automation. The goal is zero accidental hidden capability, not hundreds of buttons.',
                  style: TextStyle(
                      color: _muted, fontSize: 10, height: 1.45),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 390,
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'Search capability or surface',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      dropdownColor: _panelSoft,
                      decoration: const InputDecoration(
                        labelText: 'Coverage state',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Needs work')),
                        DropdownMenuItem(
                            value: 'UNCLASSIFIED',
                            child: Text('Unclassified')),
                        DropdownMenuItem(
                            value: 'PARTIAL', child: Text('Partial')),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'ALL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const Card(
                  color: _panel,
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No matching unfinished capability surface.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                ...rows.map((row) {
                  final status = '${row['status'] ?? 'UNCLASSIFIED'}';
                  final color = _color(status);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: color.withOpacity(.18)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withOpacity(.1),
                        child: Icon(
                          status == 'UNCLASSIFIED'
                              ? Icons.visibility_off_outlined
                              : Icons.pending_actions_outlined,
                          color: color,
                          size: 17,
                        ),
                      ),
                      title: Text('${row['capability_label']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        '${row['source_reference']}\n${row['audience'] ?? 'UNCLASSIFIED'} • ${row['surface_kind'] ?? 'UNCLASSIFIED'}${row['surface_reference'] == null ? '' : ' • ${row['surface_reference']}'}',
                        style: const TextStyle(
                            color: _muted, fontSize: 9, height: 1.35),
                      ),
                      trailing: Text(status,
                          style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.w900)),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
