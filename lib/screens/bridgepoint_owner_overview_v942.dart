import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerOverviewV942 extends StatefulWidget {
  const BridgePointOwnerOverviewV942({super.key});

  @override
  State<BridgePointOwnerOverviewV942> createState() => _BridgePointOwnerOverviewV942State();
}

class _BridgePointOwnerOverviewV942State extends State<BridgePointOwnerOverviewV942> {
  static const _panel = Color(0xFF0D1B2C);
  static const _soft = Color(0xFF14283F);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);

  late Future<List<dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_owner_parcel_progress_v942'),
        _safe('bridgepoint_source_health_v86'),
        _safe('bridgepoint_us_intelligence_coverage_v755'),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['states', 'lanes', 'sources', 'items', 'rows', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${b.toString()}';
  }

  String _age(dynamic value) {
    final dt = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (dt == null) return 'unknown';
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Color _stateColor(String state) => switch (state) {
        'ACTIVE' => _green,
        'MOVING_SLOWLY' => _amber,
        _ => _red,
      };

  Widget _metric(String label, String value, String detail, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 11),
          Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(color: _muted, fontSize: 12, height: 1.35)),
        ]),
      );

  Widget _section(String title, String subtitle, IconData icon, Widget child) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: _cyan),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5)),
            ])),
          ]),
          const SizedBox(height: 13),
          child,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const [];
        dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
        final parcel = _map(at(0));
        final sourcePayload = _map(at(1));
        final coverage = _map(at(2));
        final states = _rows(parcel['states']);
        final lanes = _rows(parcel['lanes']);
        final sources = _rows(sourcePayload['sources']);
        final summary = _map(sourcePayload['summary']);
        final counties = _map(parcel['county_discovery']);
        final systemState = '${parcel['system_state'] ?? 'NEEDS_ATTENTION'}';
        final systemColor = _stateColor(systemState);

        final enabled = sources.where((r) => r['enabled'] == true).length;
        final healthy = sources.where((r) => '${r['health_status'] ?? ''}'.toUpperCase() == 'HEALTHY').length;
        final notRun = sources.where((r) => '${r['health_status'] ?? ''}'.toUpperCase() == 'NOT_RUN').length;
        final failing = sources.where((r) => '${r['health_status'] ?? ''}'.toUpperCase() == 'FAILING').length;
        final registered = _int(summary['registered']) > 0 ? _int(summary['registered']) : sources.length;
        final disabled = registered > enabled ? registered - enabled : sources.where((r) => r['enabled'] == false).length;

        final priority = states.where((r) => const {'CT', 'MA', 'NY', 'NJ', 'OH', 'FL', 'TX', 'CA'}.contains('${r['state_code']}')).toList();
        priority.sort((a, b) {
          if ('${a['state_code']}' == 'CT') return -1;
          if ('${b['state_code']}' == 'CT') return 1;
          return (_double(b['foundation_progress_pct']) ?? -1).compareTo(_double(a['foundation_progress_pct']) ?? -1);
        });

        return RefreshIndicator(
          onRefresh: () async => setState(() => _request = _load()),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Owner Control', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('The operating picture you need: parcel movement, source health and expansion progress—without raw control-plane JSON.', style: TextStyle(color: _muted, height: 1.45)),
                ])),
                IconButton.filledTonal(onPressed: () => setState(() => _request = _load()), icon: const Icon(Icons.refresh_rounded)),
              ]),
              if (snapshot.connectionState == ConnectionState.waiting) const Padding(padding: EdgeInsets.only(top: 9), child: LinearProgressIndicator()),
              const SizedBox(height: 15),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 640 ? 2 : 1;
                final w = (c.maxWidth - (cols - 1) * 10) / cols;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(width: w, child: _metric('PARCEL ENGINE', systemState.replaceAll('_', ' '), '${parcel['active_lanes'] ?? 0}/${parcel['total_lanes'] ?? 6} lanes active • movement ${_age(parcel['last_lane_activity_at'])}', Icons.route_rounded, systemColor)),
                  SizedBox(width: w, child: _metric('LANE SUCCESSES', _number(parcel['lane_successes']), '${parcel['current_lane_failures'] ?? 0} current consecutive lane failures', Icons.speed_rounded, _green)),
                  SizedBox(width: w, child: _metric('ACTIVE / HEALTHY SOURCES', '$enabled / $healthy', '$notRun enabled need first health run • $failing failing • $disabled disabled inventory', Icons.hub_rounded, failing == 0 ? _cyan : _amber)),
                  SizedBox(width: w, child: _metric('ACTIVE PROPERTIES', _number(coverage['active_properties']), 'Current canonical production property universe', Icons.home_work_rounded, _blue)),
                ]);
              }),
              const SizedBox(height: 14),
              _section(
                'Parcel Expansion',
                'Real state foundation counts and last activity. Unknown statewide denominators stay unknown instead of showing fake percentages.',
                Icons.map_rounded,
                Column(children: [
                  for (final row in priority)
                    _StateProgressRow(row: row, number: _number, age: _age, doubleValue: _double),
                ]),
              ),
              const SizedBox(height: 14),
              _section(
                'Six priority parcel lanes',
                'Each lane should keep cycling. HTTP 200 and recent movement are the quickest signs the lane is doing real work.',
                Icons.multiple_stop_rounded,
                Column(children: [
                  for (final lane in lanes)
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _soft.withValues(alpha: .72), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Container(width: 34, height: 34, decoration: BoxDecoration(color: _green.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Center(child: Text('${lane['lane']}', style: const TextStyle(color: _green, fontWeight: FontWeight.w900)))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(lane['active'] == true ? 'Processing now' : 'Ready for next cycle', style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('Last HTTP ${lane['last_status_code'] ?? '—'} • activity ${_age(lane['last_response_at'] ?? lane['updated_at'])}', style: const TextStyle(color: _muted, fontSize: 12)),
                        ])),
                        Text('${_number(lane['total_successes'])} ✓', style: const TextStyle(color: _green, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              _section(
                'County parcel discovery',
                'The fallback lane is continuously finding county-level sources where a clean statewide foundation is not available.',
                Icons.travel_explore_rounded,
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _StatusPill('Queued', counties['QUEUED'], _blue),
                  _StatusPill('Discovering', counties['DISCOVERING'], _cyan),
                  _StatusPill('Candidate found', counties['CANDIDATE_FOUND'], _green),
                  _StatusPill('Needs review', counties['REVIEW_CANDIDATE'], _amber),
                  _StatusPill('No candidate yet', counties['NO_CANDIDATE'], _muted),
                ]),
              ),
              const SizedBox(height: 14),
              _section(
                'Source inventory',
                'Registry size is inventory—not a vanity “live sources” number. Customer screens should show provenance tied to their evidence, not this catalog.',
                Icons.fact_check_outlined,
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 760 ? 4 : 2;
                  final w = (c.maxWidth - (cols - 1) * 8) / cols;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    SizedBox(width: w, child: _Mini('Registered', '$registered', _blue)),
                    SizedBox(width: w, child: _Mini('Enabled', '$enabled', _cyan)),
                    SizedBox(width: w, child: _Mini('Healthy', '$healthy', _green)),
                    SizedBox(width: w, child: _Mini('Failing', '$failing', failing == 0 ? _green : _red)),
                  ]);
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StateProgressRow extends StatelessWidget {
  const _StateProgressRow({required this.row, required this.number, required this.age, required this.doubleValue});
  final Map<String, dynamic> row;
  final String Function(dynamic) number;
  final String Function(dynamic) age;
  final double? Function(dynamic) doubleValue;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF48E1FF);
    const green = Color(0xFF45E6A6);
    const amber = Color(0xFFFFC95E);
    const muted = Color(0xFFB5C6D9);
    final pct = doubleValue(row['foundation_progress_pct']);
    final live = '${row['data_status']}' == 'LIVE';
    final color = live ? green : pct != null ? cyan : amber;
    final current = number(row['canonical_property_count']);
    final expected = row['expected_foundation_rows'] == null ? null : number(row['expected_foundation_rows']);
    final phase = '${row['current_phase'] ?? 'BUILDING'}'.replaceAll('_', ' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF14283F), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withValues(alpha: .14))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(10)), child: Center(child: Text('${row['state_code']}', style: TextStyle(color: color, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${row['state_name'] ?? row['state_code']}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('$phase • activity ${age(row['last_activity_at'] ?? row['refreshed_at'])}', style: const TextStyle(color: muted, fontSize: 11.5)),
          ])),
          Text(live ? 'LIVE' : pct == null ? 'COUNT $current' : '${pct.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 9),
        if (pct != null)
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), minHeight: 6, color: color, backgroundColor: Colors.white.withValues(alpha: .06))),
        const SizedBox(height: 6),
        Text(expected == null ? '$current canonical properties • statewide denominator not verified yet' : '$current of $expected expected foundation rows', style: const TextStyle(color: muted, fontSize: 11.5)),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, this.value, this.color);
  final String label;
  final dynamic value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(11), border: Border.all(color: color.withValues(alpha: .18))),
        child: Text('$label  ${value ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      );
}
