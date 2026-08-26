import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerUsCompletionV3 extends StatefulWidget {
  const BridgePointOwnerUsCompletionV3({super.key});

  @override
  State<BridgePointOwnerUsCompletionV3> createState() =>
      _BridgePointOwnerUsCompletionV3State();
}

class _BridgePointOwnerUsCompletionV3State
    extends State<BridgePointOwnerUsCompletionV3> {
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF7474);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF0D2034);

  bool busy = true;
  String? error;
  String query = '';
  String statusFilter = 'ALL';
  List<Map<String, dynamic>> states = const [];
  final Map<String, Map<String, dynamic>> liveState = {};
  final Set<String> expanded = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
    }
    return const [];
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    final n = _int(value);
    final raw = n.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return '${n < 0 ? '-' : ''}${out.toString()}';
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        busy = true;
        error = null;
      });
    }
    try {
      final values = await Future.wait([
        Supabase.instance.client.rpc(
          'bridgepoint_owner_state_completion_matrix_v900',
          params: {'p_state_code': null},
        ),
        Supabase.instance.client.rpc('bridgepoint_flutter_map_state_status_v838'),
      ]);

      final matrix = values[0];
      final live = values[1];
      final next = matrix is Map ? _rows(matrix['states']) : <Map<String, dynamic>>[];
      final liveRows = live is Map ? _rows(live['states']) : <Map<String, dynamic>>[];
      liveState.clear();
      for (final row in liveRows) {
        final code = '${row['state_code'] ?? ''}'.trim().toUpperCase();
        if (code.isNotEmpty) liveState[code] = row;
      }
      next.sort((a, b) {
        final ap = _double(a['verified_pct']);
        final bp = _double(b['verified_pct']);
        final cmp = ap.compareTo(bp);
        if (cmp != 0) return cmp;
        return '${a['state_code']}'.compareTo('${b['state_code']}');
      });
      if (!mounted) return;
      setState(() {
        states = next;
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = '$e';
      });
    }
  }

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toUpperCase();
    return states.where((row) {
      final code = '${row['state_code'] ?? ''}'.toUpperCase();
      if (q.isNotEmpty && !code.contains(q)) return false;
      final verified = _double(row['verified_pct']);
      final ready = _double(row['ready_or_verified_pct']);
      return switch (statusFilter) {
        'COMPLETE' => verified >= 99.999,
        'CLOSE' => verified >= 70 && verified < 99.999,
        'ACTIVE' => verified < 70 && ready > 0,
        'EARLY' => ready <= 0,
        _ => true,
      };
    }).toList();
  }

  Map<String, dynamic> _domains(Map<String, dynamic> row) {
    final raw = row['domains'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  List<Map<String, dynamic>> _left(Map<String, dynamic> domain) {
    final raw = domain['left'];
    return _rows(raw);
  }

  int get totalRequired => states.fold(
        0,
        (sum, row) => sum + _int(row['required_features']),
      );

  int get totalVerified => states.fold(
        0,
        (sum, row) => sum + _int(row['verified_features']),
      );

  int get totalReady => states.fold(
        0,
        (sum, row) => sum + _int(row['ready_features']),
      );

  int get completeStates =>
      states.where((row) => _double(row['verified_pct']) >= 99.999).length;

  int get statesWithProperties => liveState.values
      .where((row) => _int(row['canonical_property_count']) > 0)
      .length;

  int get properties => liveState.values.fold(
        0,
        (sum, row) => sum + _int(row['canonical_property_count']),
      );

  int get signals => liveState.values.fold(
        0,
        (sum, row) => sum + _int(row['signal_count']),
      );

  int get opportunities => liveState.values.fold(
        0,
        (sum, row) => sum + _int(row['opportunity_count']),
      );

  Color _statusColor(String status) => switch (status.toUpperCase()) {
        'VERIFIED' => _green,
        'READY' => _cyan,
        'DISCOVERING' => _amber,
        'INTEGRATION_REQUIRED' => _amber,
        'COMPLIANCE' => _amber,
        _ => _red,
      };

  String _plainStatus(String status) => switch (status.toUpperCase()) {
        'VERIFIED' => 'Done and verified',
        'READY' => 'Built/source exists — final coverage still needs verification',
        'DISCOVERING' => 'BridgePoint is looking for or validating a source',
        'INTEGRATION_REQUIRED' => 'Needs an authorized external integration',
        'COMPLIANCE' => 'Held until rights/compliance is satisfied',
        _ => 'Still missing',
      };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'U.S. COMPLETION TRUTH',
                      style: TextStyle(
                        color: _cyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exactly what is left in every state',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh truth',
                onPressed: busy ? null : load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Green means verified. Blue means the capability or source exists but BridgePoint has not yet proven final parity coverage. Red means there is still real work left. Nothing is promoted to “done” just because code or a source record exists.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          if (busy) const LinearProgressIndicator(minHeight: 3),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Could not load owner completion truth: $error',
                  style: const TextStyle(color: _red),
                ),
              ),
            ),
          if (!busy && error == null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 5
                    : constraints.maxWidth >= 650
                        ? 3
                        : 2;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                final cards = [
                  ('States fully verified', '$completeStates / ${states.length}', Icons.verified_rounded),
                  ('States with properties', '$statesWithProperties / ${states.length}', Icons.map_rounded),
                  ('Canonical properties', _number(properties), Icons.holiday_village_rounded),
                  ('Signals', _number(signals), Icons.radar_rounded),
                  ('Opportunities', _number(opportunities), Icons.bolt_rounded),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: width,
                        child: _MetricCard(
                          label: card.$1,
                          value: card.$2,
                          icon: card.$3,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Nationwide capability verification',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '$totalVerified / $totalRequired verified',
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: totalRequired <= 0
                          ? 0
                          : (totalVerified / totalRequired).clamp(0, 1),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalReady more capability/state checks are currently READY but not yet VERIFIED.',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                labelText: 'Find state',
                hintText: 'CT, NY, FL…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final option in const [
                  ('ALL', 'All'),
                  ('COMPLETE', 'Verified'),
                  ('CLOSE', 'Close'),
                  ('ACTIVE', 'Active build'),
                  ('EARLY', 'Early / missing'),
                ])
                  ChoiceChip(
                    selected: statusFilter == option.$1,
                    onSelected: (_) =>
                        setState(() => statusFilter = option.$1),
                    label: Text(option.$2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in filtered) _stateCard(row),
          ],
        ],
      ),
    );
  }

  Widget _stateCard(Map<String, dynamic> row) {
    final code = '${row['state_code'] ?? ''}'.toUpperCase();
    final live = liveState[code] ?? const <String, dynamic>{};
    final verified = _double(row['verified_pct']).clamp(0, 100);
    final ready = _double(row['ready_or_verified_pct']).clamp(0, 100);
    final isExpanded = expanded.contains(code);
    final domains = _domains(row);

    final left = <Map<String, dynamic>>[];
    for (final entry in domains.entries) {
      if (entry.value is! Map) continue;
      final domain = Map<String, dynamic>.from(entry.value as Map);
      for (final item in _left(domain)) {
        left.add({...item, '_domain': entry.key});
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() {
          isExpanded ? expanded.remove(code) : expanded.add(code);
        }),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _cyan.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cyan.withValues(alpha: .24)),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: _cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${verified.toStringAsFixed(1)}% verified',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_int(row['verified_features'])} verified • ${_int(row['ready_features'])} ready • ${_int(row['missing_features'])} missing',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  LinearProgressIndicator(
                    value: (ready / 100).clamp(0, 1),
                    minHeight: 12,
                    color: _cyan.withValues(alpha: .42),
                    backgroundColor: const Color(0xFF071321),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  LinearProgressIndicator(
                    value: (verified / 100).clamp(0, 1),
                    minHeight: 12,
                    color: _green,
                    backgroundColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 6,
                children: [
                  _tiny('Properties', _number(live['canonical_property_count'])),
                  _tiny('Signals', _number(live['signal_count'])),
                  _tiny('Opportunities', _number(live['opportunity_count'])),
                  _tiny('2D', _number(live['building_2d_count'])),
                  _tiny('3D', _number(live['building_3d_count'])),
                  _tiny('Sources', _number(live['verified_source_count'])),
                ],
              ),
              if (isExpanded) ...[
                const Divider(height: 24),
                Text(
                  left.isEmpty ? 'Nothing left in the required contract.' : 'What is still left',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (left.isNotEmpty) const SizedBox(height: 8),
                for (final item in left)
                  Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF091827),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: _statusColor('${item['status'] ?? 'MISSING'}'),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['name'] ?? item['feature_key'] ?? 'Capability'}',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item['_domain'] ?? 'SYSTEM'} • ${_plainStatus('${item['status'] ?? 'MISSING'}')}',
                                style: const TextStyle(color: _muted, fontSize: 11.5),
                              ),
                              if (item['coverage_pct'] != null || item['actual_count'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Coverage: ${item['coverage_pct'] ?? '—'}% • Records: ${item['actual_count'] ?? '—'} • Sources: ${item['source_count'] ?? '—'}',
                                    style: const TextStyle(color: _muted, fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tiny(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF091827),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label $value',
          style: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Icon(icon, color: const Color(0xFF48E1FF), size: 22),
            const SizedBox(height: 9),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
