import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointIntelligenceLiveV2 extends StatefulWidget {
  const BridgePointIntelligenceLiveV2({super.key, required this.ownerMode});

  final bool ownerMode;

  @override
  State<BridgePointIntelligenceLiveV2> createState() =>
      _BridgePointIntelligenceLiveV2State();
}

class _BridgePointIntelligenceLiveV2State
    extends State<BridgePointIntelligenceLiveV2> {
  late Future<Map<String, dynamic>> _request;
  int _tab = 0;
  String _query = '';

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
    if (value is List) return {'items': value};
    return {'value': value};
  }

  List<Map<String, dynamic>> _rows(dynamic value, [List<String>? keys]) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (value is Map) {
      for (final key in keys ?? const ['items', 'rows', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<Map<String, dynamic>> _load() async {
    final futures = <Future<dynamic>>[
      _safe('bridgepoint_flutter_sources'),
      _safe('bridgepoint_flutter_signals', {
        'p_search': null,
        'p_signal_family': null,
        'p_status': 'active',
        'p_limit': 40,
        'p_offset': 0,
      }),
      _safe('bridgepoint_flutter_models'),
      _safe('bridgepoint_pattern_intelligence_v212', {
        'p_state_codes': <String>[],
        'p_limit': 40,
        'p_offset': 0,
      }),
      if (widget.ownerMode)
        _safe('bridgepoint_source_health_v86')
      else
        Future.value({'available': false, 'owner_only': true}),
    ];
    final values = await Future.wait(futures);
    return {
      'sources': _map(values[0]),
      'signals': _map(values[1]),
      'models': _map(values[2]),
      'patterns': _map(values[3]),
      'source_health': _map(values[4]),
    };
  }

  void _refresh() => setState(() => _request = _load());

  bool _matches(Map<String, dynamic> row) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return row.values.join(' ').toLowerCase().contains(needle);
  }

  String _time(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty || raw == 'null') return 'unknown';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  num? _num(dynamic value) => value is num ? value : num.tryParse('$value');

  Color _healthColor(String value) {
    final normalized = value.toUpperCase();
    if (normalized.contains('HEALTH') || normalized.contains('LIVE')) {
      return _green;
    }
    if (normalized.contains('FAIL') || normalized.contains('ERROR')) return _red;
    return _amber;
  }

  Widget _metric(String label, Object? value, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('${value ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _notice(String text, {Color color = _amber}) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: _muted, fontSize: 12.5, height: 1.45)),
            ),
          ],
        ),
      );

  Widget _sources(Map<String, dynamic> data) {
    final sourcePayload = _map(data['sources']);
    final healthPayload = _map(data['source_health']);
    final healthSummary = _map(healthPayload['summary']);
    final rows = _rows(
      widget.ownerMode ? healthPayload : sourcePayload,
      const ['sources', 'items', 'rows'],
    ).where(_matches).toList();

    if (!widget.ownerMode && rows.isEmpty) {
      return _notice(
        '${sourcePayload['message'] ?? 'Detailed provider endpoints and ingestion infrastructure are intentionally owner-only. Customer evidence remains source/provenance-aware at the property, signal and opportunity level.'}',
        color: _cyan,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.ownerMode)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('REGISTERED', healthSummary['registered'], _cyan),
              _metric('ENABLED', healthSummary['enabled'], _cyan),
              _metric('HEALTHY', healthSummary['healthy'], _green),
              _metric('STALE', healthSummary['stale'], _amber),
              _metric('FAILING', healthSummary['failing'], _red),
            ],
          ),
        if (widget.ownerMode) const SizedBox(height: 10),
        ...rows.take(60).map((row) {
          final health = '${row['health_status'] ?? 'UNKNOWN'}';
          final stale = row['is_stale'] == true;
          final color = stale ? _amber : _healthColor(health);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: _panel,
              child: ExpansionTile(
                leading: Icon(Icons.hub_outlined, color: color),
                title: Text('${row['source_name'] ?? row['source_code'] ?? 'Source'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${row['provider'] ?? 'provider unavailable'} • ${row['source_category'] ?? 'uncategorized'} • ${row['state_code'] ?? row['geographic_scope'] ?? 'multi-geo'}',
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
                trailing: Text(
                  stale ? 'STALE' : health,
                  style: TextStyle(
                      color: color, fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Refresh ${row['refresh_interval_minutes'] ?? '—'}m')),
                        Chip(label: Text('Ingested ${row['total_records_ingested'] ?? '—'}')),
                        Chip(label: Text('Failures ${row['consecutive_failures'] ?? 0}')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Last success: ${_time(row['last_successful_import_at'])}\nLast source record: ${_time(row['last_source_record_at'])}${row['last_error'] == null ? '' : '\nLast error: ${row['last_error']}'}',
                      style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _signals(Map<String, dynamic> data) {
    final payload = _map(data['signals']);
    final rows = _rows(payload, const ['signals']).where(_matches).toList();
    if (payload['available'] == false) {
      return _notice('Signal Intelligence is unavailable for this account: ${payload['error'] ?? 'package/readiness restriction'}');
    }
    if (rows.isEmpty) {
      return _notice('No active signals matched this view. An empty signal feed is not converted into fake property scores.', color: _cyan);
    }
    return Column(
      children: rows.map((row) {
        final confidence = _num(row['confidence']);
        final confidencePct = confidence == null
            ? '—'
            : '${(confidence <= 1 ? confidence * 100 : confidence).toStringAsFixed(0)}%';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: _panel,
            child: ExpansionTile(
              leading: const Icon(Icons.bolt_rounded, color: _amber),
              title: Text('${row['signal_name'] ?? row['title'] ?? 'Signal'}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${row['full_address'] ?? [row['municipality'], row['state_code']].where((x) => x != null).join(', ')} • ${_time(row['detected_at'])}',
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
              trailing: Text(confidencePct,
                  style: const TextStyle(
                      color: _cyan, fontWeight: FontWeight.w900, fontSize: 10)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      Chip(label: Text('${row['signal_family'] ?? 'unknown family'}')),
                      Chip(label: Text('${row['evidence_count'] ?? 0} evidence items')),
                      Chip(label: Text('${row['source_count'] ?? 0} sources')),
                      Chip(label: Text('severity ${row['severity'] ?? '—'}')),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${row['description'] ?? row['evidence_summary'] ?? 'No description returned.'}',
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Signal ≠ confirmed damage or causal proof. It is a source-backed observation used for prioritization and further review.',
                    style: TextStyle(color: _amber, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _patterns(Map<String, dynamic> data) {
    final payload = _map(data['patterns']);
    if (payload['available'] == false) {
      return _notice(
        'Pattern Intelligence is protected by package entitlement. ${payload['error'] ?? ''}',
        color: _cyan,
      );
    }
    final rows = _rows(payload, const ['patterns']).where(_matches).toList();
    if (rows.isEmpty) return _notice('No active patterns matched this view.', color: _cyan);
    return Column(
      children: rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: _panel,
              child: ListTile(
                leading: const Icon(Icons.account_tree_outlined, color: _amber),
                title: Text('${row['pattern_name'] ?? row['pattern_key'] ?? 'Pattern'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${row['full_address'] ?? [row['municipality'], row['state_code']].where((x) => x != null).join(', ')}\n${row['signal_count'] ?? 0} signals • ${row['distinct_sources'] ?? 0} sources • ${row['recency_band'] ?? ''}',
                  style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${row['pattern_score'] ?? '—'}',
                        style: const TextStyle(
                            color: _cyan, fontSize: 16, fontWeight: FontWeight.w900)),
                    Text('${row['confidence_pct'] ?? '—'}% conf.',
                        style: const TextStyle(color: _muted, fontSize: 8)),
                  ],
                ),
              ),
            ),
          )).toList(),
    );
  }

  Future<void> _showModelTransparency(Map<String, dynamic> row) async {
    final key = '${row['model_key'] ?? ''}';
    if (key.isEmpty) return;
    final raw = await _safe('bridgepoint_model_transparency_v509', {'p_model_key': key});
    if (!mounted) return;
    final payload = _map(raw);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .78,
          minChildSize: .45,
          maxChildSize: .95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Text('${row['model_name'] ?? key}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text(
                'Model transparency',
                style: TextStyle(color: _cyan, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...payload.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                                color: _muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        SelectableText('${entry.value}',
                            style: const TextStyle(fontSize: 12.5, height: 1.45)),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              const Text(
                'Transparency exposes customer-safe reasoning, evidence expectations, uncertainty and validation context—not proprietary raw weights or protected learning logic.',
                style: TextStyle(color: _amber, fontSize: 11.5, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _models(Map<String, dynamic> data) {
    final payload = _map(data['models']);
    final rows = _rows(payload, const ['models']).where(_matches).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric('ACTIVE MODELS', payload['active_model_count'], _cyan),
            _metric('PACKAGE LINKS', payload['active_package_model_links'], _green),
          ],
        ),
        const SizedBox(height: 10),
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                color: _panel,
                child: InkWell(
                  onTap: () => _showModelTransparency(row),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_alt_outlined, color: _cyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${row['model_name'] ?? row['model_key'] ?? 'Model'}',
                                  style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: _muted),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text('${row['customer_outcome'] ?? row['description'] ?? ''}',
                            style: const TextStyle(fontSize: 12.5, height: 1.45)),
                        const SizedBox(height: 5),
                        Text('Best for: ${row['best_for'] ?? 'general property intelligence'}',
                            style: const TextStyle(color: _muted, fontSize: 9)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            Chip(label: Text('${row['strict_queue_status'] ?? 'status unavailable'}')),
                            Chip(label: Text('${row['strict_qualified_count'] ?? 0} qualified')),
                            Chip(label: Text('${row['package_count'] ?? 0} packages')),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${row['evidence_requirement'] ?? ''}',
                            style: const TextStyle(color: _amber, fontSize: 11.5, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _overview(Map<String, dynamic> data) {
    final signals = _map(data['signals']);
    final models = _map(data['models']);
    final patterns = _map(data['patterns']);
    final sourceHealth = _map(data['source_health']);
    final sourceSummary = _map(sourceHealth['summary']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric('ACTIVE SIGNALS SHOWN', signals['returned_results'], _amber),
            _metric('ACTIVE MODELS', models['active_model_count'], _cyan),
            _metric('PATTERNS SHOWN', _rows(patterns, const ['patterns']).length, _green),
            if (widget.ownerMode)
              _metric('HEALTHY SOURCES', sourceSummary['healthy'], _green),
            if (widget.ownerMode)
              _metric('STALE SOURCES', sourceSummary['stale'], _amber),
          ],
        ),
        const SizedBox(height: 10),
        _notice(
          'Truth chain: source → canonical property match → evidence → signal → temporal pattern → model evaluation → qualified opportunity → workflow outcome. Each stage can be inspected without treating model output as confirmed physical condition.',
          color: _cyan,
        ),
      ],
    );
  }

  Widget _body(Map<String, dynamic> data) => switch (_tab) {
        0 => _overview(data),
        1 => _sources(data),
        2 => _signals(data),
        3 => _patterns(data),
        _ => _models(data),
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        return Card(
          color: const Color(0xFF091727),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live Intelligence',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          SizedBox(height: 3),
                          Text(
                            'Inspect the current source → evidence → signal → pattern → model chain without exposing protected weights or unsafe infrastructure to customer accounts.',
                            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : _refresh,
                      tooltip: 'Refresh intelligence',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Overview'), icon: Icon(Icons.schema_outlined)),
                      ButtonSegment(value: 1, label: Text('Sources'), icon: Icon(Icons.hub_outlined)),
                      ButtonSegment(value: 2, label: Text('Signals'), icon: Icon(Icons.bolt_outlined)),
                      ButtonSegment(value: 3, label: Text('Patterns'), icon: Icon(Icons.account_tree_outlined)),
                      ButtonSegment(value: 4, label: Text('Models'), icon: Icon(Icons.psychology_alt_outlined)),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (value) => setState(() => _tab = value.first),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Filter this intelligence view',
                    hintText: 'Source, address, signal, pattern, model…',
                  ),
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  _notice('Live Intelligence could not load: ${snapshot.error}')
                else
                  _body(data),
              ],
            ),
          ),
        );
      },
    );
  }
}
