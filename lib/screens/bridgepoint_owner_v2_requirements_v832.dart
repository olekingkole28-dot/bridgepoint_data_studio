import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerV2Requirements extends StatefulWidget {
  const BridgePointOwnerV2Requirements({super.key});

  @override
  State<BridgePointOwnerV2Requirements> createState() =>
      _BridgePointOwnerV2RequirementsState();
}

class _BridgePointOwnerV2RequirementsState
    extends State<BridgePointOwnerV2Requirements> {
  late Future<Map<String, dynamic>> _request;
  String _status = 'ALL';
  String _source = 'ALL';
  String _query = '';

  static const _panel = Color(0xFF0D1A2B);
  static const _muted = Color(0xFF8FA5BF);
  static const _cyan = Color(0xFF35D2E8);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await Supabase.instance.client.rpc(
      'bridgepoint_owner_v2_requirements_v832',
      params: {'p_category': null, 'p_status': null, 'p_limit': 2000},
    );
    if (raw is! Map) {
      throw const FormatException('Unexpected V2 requirements response.');
    }
    return Map<String, dynamic>.from(raw);
  }

  void _refresh() => setState(() => _request = _load());

  Color _statusColor(String status) => switch (status) {
        'PROVEN_DONE' => _green,
        'IN_PROGRESS' => _cyan,
        'BLOCKED' => _red,
        _ => _amber,
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load V2 requirements: ${snapshot.error}',
                style: const TextStyle(color: _red),
              ),
            ),
          );
        }

        final payload = snapshot.data ?? const <String, dynamic>{};
        final rows = (payload['requirements'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        final sources = <String>{
          'ALL',
          ...rows.map((row) => '${row['source_type'] ?? ''}'),
        }.where((value) => value.isNotEmpty).toList()
          ..sort((a, b) => a == 'ALL' ? -1 : a.compareTo(b));
        const statuses = <String>[
          'ALL',
          'TODO',
          'IN_PROGRESS',
          'BLOCKED',
          'PROVEN_DONE',
        ];
        final needle = _query.trim().toLowerCase();
        final visible = rows.where((row) {
          final status = '${row['status'] ?? ''}';
          final source = '${row['source_type'] ?? ''}';
          if (_status != 'ALL' && status != _status) return false;
          if (_source != 'ALL' && source != _source) return false;
          if (needle.isEmpty) return true;
          return [
            row['source_key'],
            row['category'],
            row['requirement'],
            row['audience'],
            row['surface_kind'],
          ].join(' ').toLowerCase().contains(needle);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clean V2 — Full Rebuild Contract',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Legacy requirements + every backend capability + recent rebuild requirements. Nothing is complete without verification evidence.',
                              style: TextStyle(color: _muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Refresh requirements',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Metric('TOTAL', payload['total'], _cyan),
                      _Metric('PROVEN', payload['proven_done'], _green),
                      _Metric('IN PROGRESS', payload['in_progress'], _cyan),
                      _Metric('TODO', payload['todo'], _amber),
                      _Metric('BLOCKED', payload['blocked'], _red),
                      _Metric('STRICT %', payload['strict_completion_pct'], _green),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 330,
                        child: TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            labelText: 'Search the entire rebuild',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        child: DropdownButtonFormField<String>(
                          initialValue: _source,
                          items: sources
                              .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.replaceAll('_', ' ')),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _source = value ?? 'ALL'),
                          decoration: const InputDecoration(
                            labelText: 'Source',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          items: statuses
                              .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.replaceAll('_', ' ')),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _status = value ?? 'ALL'),
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching requirements.',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = visible[index];
                        final status = '${row['status'] ?? 'TODO'}';
                        final color = _statusColor(status);
                        return Card(
                          color: _panel,
                          child: Padding(
                            padding: const EdgeInsets.all(13),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 9,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${row['requirement'] ?? ''}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            status.replaceAll('_', ' '),
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${row['source_type']} • ${row['category']} • P${row['priority']} • ${row['audience']} • ${row['surface_kind'] ?? 'UNASSIGNED'}',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 9,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${row['source_key']}',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 8,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);

  final String label;
  final Object? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('${value ?? 0}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }
}
