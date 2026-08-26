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
  String _category = 'ALL';
  String _query = '';

  static const _panel = Color(0xFF0E2035);
  static const _muted = Color(0xFFB5C6D9);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
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

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  void _refresh() => setState(() => _request = _load());

  Color _statusColor(String status) => switch (status) {
        'PROVEN_DONE' => _green,
        'IN_PROGRESS' => _cyan,
        'BLOCKED' => _red,
        _ => _amber,
      };

  String _clean(String value) => value.replaceAll('_', ' ');

  Widget _filter({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    double width = 190,
  }) => SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          items: values
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(_clean(item)),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _evidence(Map<String, dynamic> row) {
    final status = '${row['status'] ?? 'TODO'}';
    final verification = _map(row['verification']);
    final metadata = _map(row['metadata']);
    final surface = '${row['surface_kind'] ?? 'UNASSIGNED'}';
    final items = <MapEntry<String, dynamic>>[
      ...verification.entries,
      if (metadata['surface_reference'] != null)
        MapEntry('surface_reference', metadata['surface_reference']),
      if (metadata['source_reference'] != null)
        MapEntry('source_reference', metadata['source_reference']),
      if (metadata['source_context'] != null)
        MapEntry('source_context', metadata['source_context']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _statusColor(status).withValues(alpha: .055),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _statusColor(status).withValues(alpha: .15),
            ),
          ),
          child: Text(
            status == 'PROVEN_DONE'
                ? 'Completion is evidence-backed. If the underlying evidence disappears or the capability regresses, this item should reopen.'
                : verification.isEmpty
                    ? 'No completion evidence is recorded yet. This requirement remains open by design.'
                    : 'Partial evidence exists, but it is not sufficient for strict completion yet.',
            style: TextStyle(
              color: status == 'PROVEN_DONE' ? _green : _muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('P${row['priority']}')),
            Chip(label: Text('${row['audience'] ?? 'UNCLASSIFIED'}')),
            Chip(label: Text(surface)),
            Chip(label: Text('${row['source_type'] ?? ''}')),
          ],
        ),
        const SizedBox(height: 9),
        if (items.isEmpty)
          const Text(
            'Verification: none yet.',
            style: TextStyle(color: _muted, fontSize: 9),
          )
        else
          ...items.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _clean(entry.key).toUpperCase(),
                      style: const TextStyle(
                        color: _cyan,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      '${entry.value}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 5),
        Text(
          'Requirement key: ${row['source_key']}\nLast synchronized: ${row['updated_at'] ?? 'unknown'}',
          style: const TextStyle(
            color: _muted,
            fontSize: 12.5,
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _requirementCard(Map<String, dynamic> row) {
    final status = '${row['status'] ?? 'TODO'}';
    final color = _statusColor(status);
    return Card(
      color: _panel,
      child: ExpansionTile(
        leading: Container(
          width: 9,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        title: Text(
          '${row['requirement'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${row['category']} • P${row['priority']} • ${row['audience']} • ${row['surface_kind'] ?? 'UNASSIGNED'}',
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ),
        trailing: Text(
          _clean(status),
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _evidence(row),
        ],
      ),
    );
  }

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
        final categories = <String>{
          'ALL',
          ...rows.map((row) => '${row['category'] ?? ''}'),
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
          final category = '${row['category'] ?? ''}';
          if (_status != 'ALL' && status != _status) return false;
          if (_source != 'ALL' && source != _source) return false;
          if (_category != 'ALL' && category != _category) return false;
          if (needle.isEmpty) return true;
          return [
            row['source_key'],
            row['category'],
            row['requirement'],
            row['audience'],
            row['surface_kind'],
            row['verification'],
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
                              'Legacy requirements + discovered backend capabilities + recent rebuild requirements. Expand any row to see the evidence—or the reason it is still open.',
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
                            labelText: 'Search requirement + evidence',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      _filter(
                        label: 'Category',
                        value: _category,
                        values: categories,
                        width: 220,
                        onChanged: (value) =>
                            setState(() => _category = value ?? 'ALL'),
                      ),
                      _filter(
                        label: 'Source',
                        value: _source,
                        values: sources,
                        width: 210,
                        onChanged: (value) =>
                            setState(() => _source = value ?? 'ALL'),
                      ),
                      _filter(
                        label: 'Status',
                        value: _status,
                        values: statuses,
                        onChanged: (value) =>
                            setState(() => _status = value ?? 'ALL'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${visible.length} matching requirements shown',
                    style: const TextStyle(color: _muted, fontSize: 9),
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
                      itemBuilder: (context, index) =>
                          _requirementCard(visible[index]),
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value ?? 0}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
