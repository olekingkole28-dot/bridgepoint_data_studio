import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerEngineHealthV777 extends StatefulWidget {
  const BridgePointOwnerEngineHealthV777({super.key});

  @override
  State<BridgePointOwnerEngineHealthV777> createState() =>
      _BridgePointOwnerEngineHealthV777State();
}

class _BridgePointOwnerEngineHealthV777State
    extends State<BridgePointOwnerEngineHealthV777> {
  late Future<Map<String, dynamic>> _request;

  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF0E2035);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  num _number(dynamic value) {
    if (value is num) return value;
    return num.tryParse('${value ?? 0}') ?? 0;
  }

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait<dynamic>([
      Supabase.instance.client.rpc('bridgepoint_owner_system_health_v777'),
      Supabase.instance.client.rpc(
        'bridgepoint_owner_v2_requirements_v832',
        params: {'p_category': null, 'p_status': null, 'p_limit': 1},
      ),
    ]);
    return <String, dynamic>{
      'health': _map(results[0]),
      'requirements': _map(results[1]),
    };
  }

  void _refresh() => setState(() => _request = _load());

  Widget _metric(String label, dynamic value, Color color, {String? detail}) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${value ?? 0}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 10.5)),
          ],
        ],
      ),
    );
  }

  Widget _statusRow(String label, dynamic value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label.replaceAll('_', ' '),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${value ?? 0}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(String title, Map<String, dynamic> values) {
    final ordered = values.entries.toList()
      ..sort((a, b) => _number(b.value).compareTo(_number(a.value)));
    return Card(
      color: _panel,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (ordered.isEmpty)
              const Text('No current rows.', style: TextStyle(color: _muted))
            else
              for (final entry in ordered)
                _statusRow(
                  entry.key,
                  entry.value,
                  entry.key == 'LIVE' || entry.key == 'SUCCEEDED'
                      ? _green
                      : entry.key == 'FAILED' || entry.key == 'BLOCKED'
                          ? _red
                          : entry.key == 'QUEUED'
                              ? _amber
                              : _cyan,
                ),
          ],
        ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _amber, size: 34),
                  const SizedBox(height: 10),
                  const Text(
                    'Engine health could not load.',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final payload = snapshot.data ?? const <String, dynamic>{};
        final health = _map(payload['health']);
        final requirements = _map(payload['requirements']);
        final throughput = _map(health['throughput']);
        final usBuild = _map(health['us_build_status']);
        final usSources = _map(health['us_source_tasks']);
        final geoSources = _map(health['geographic_source_tasks']);
        final mode = '${throughput['mode'] ?? 'UNKNOWN'}';
        final healthy = mode == 'SPRINT' &&
            _number(throughput['long_queries']) == 0 &&
            _number(throughput['recent_cron_failures']) == 0;

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Engine Health + Completion',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Live ingestion, matching, scoring, patterns, national source work, and the authoritative Clean V2 backlog.',
                          style: TextStyle(color: _muted.withValues(alpha: .95), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh live engine health',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (healthy ? _green : _amber).withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (healthy ? _green : _amber).withValues(alpha: .24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      healthy ? Icons.speed_rounded : Icons.tune_rounded,
                      color: healthy ? _green : _amber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        healthy
                            ? 'Production engine is in SPRINT with no long-query or recent-cron-failure pressure.'
                            : 'The governor is protecting production while one or more pressure signals are active.',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      mode,
                      style: TextStyle(
                        color: healthy ? _green : _amber,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric('V2 REQUIREMENTS', requirements['total'], _cyan),
                  _metric('PROVEN DONE', requirements['proven_done'], _green),
                  _metric('IN PROGRESS', requirements['in_progress'], _cyan),
                  _metric('TODO', requirements['todo'], _amber),
                  _metric('PROPERTY QUEUE', throughput['property_pending'], _cyan),
                  _metric('PATTERN QUEUE', throughput['pattern_pending'], _cyan),
                  _metric('ENTITY QUEUE', throughput['entity_pending'], _cyan),
                  _metric(
                    'EVALUATIONS',
                    health['property_evaluations_estimate'],
                    _green,
                    detail: 'estimated live rows',
                  ),
                  _metric('ACTIVE CLIENTS', throughput['active_clients'], _cyan),
                  _metric('LONG QUERIES', throughput['long_queries'], _red),
                  _metric('CRON FAILURES', throughput['recent_cron_failures'], _red),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 900;
                  final cards = [
                    Expanded(child: _statusCard('U.S. BUILD STATUS', usBuild)),
                    Expanded(child: _statusCard('U.S. SOURCE TASKS', usSources)),
                    Expanded(child: _statusCard('GEOGRAPHIC SOURCE TASKS', geoSources)),
                  ];
                  if (narrow) {
                    return Column(
                      children: [
                        for (final card in cards) ...[
                          SizedBox(width: double.infinity, child: card.child),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cards[0],
                      const SizedBox(width: 10),
                      cards[1],
                      const SizedBox(width: 10),
                      cards[2],
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Last governor action: ${throughput['last_action'] ?? 'none'}\nUpdated: ${throughput['updated_at'] ?? health['generated_at'] ?? 'unknown'}',
                style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}
