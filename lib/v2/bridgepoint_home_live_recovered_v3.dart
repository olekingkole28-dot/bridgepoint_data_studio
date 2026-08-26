import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointHomeLiveV2 extends StatefulWidget {
  const BridgePointHomeLiveV2({
    super.key,
    required this.onMap,
    required this.onProperties,
    required this.onInvestor,
    required this.onBuildings,
    required this.onOwner,
    required this.owner,
  });

  final VoidCallback onMap;
  final VoidCallback onProperties;
  final VoidCallback onInvestor;
  final VoidCallback onBuildings;
  final VoidCallback onOwner;
  final bool owner;

  @override
  State<BridgePointHomeLiveV2> createState() =>
      _BridgePointHomeLiveRecoveredV3State();
}

class _BridgePointHomeLiveRecoveredV3State
    extends State<BridgePointHomeLiveV2> {
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF7474);
  static const _muted = Color(0xFFB5C6D9);

  late Future<List<dynamic>> _request;
  Timer? _timer;
  DateTime _refreshedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _request = _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _refreshedAt = DateTime.now();
        _request = _load();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_dashboard', {
          'p_model_key': 'all',
          'p_limit': 12,
        }),
        _safe('bridgepoint_source_health_v86'),
        _safe('bridgepoint_us_intelligence_coverage_v755'),
        _safe('bridgepoint_flutter_map_state_status_v838'),
        _safe('bridgepoint_daily_brief_v74'),
        if (widget.owner)
          _safe('bridgepoint_owner_expansion_status_v736')
        else
          Future.value(const <String, dynamic>{'available': false}),
        if (widget.owner)
          _safe('bridgepoint_owner_media_status_v161')
        else
          Future.value(const <String, dynamic>{'available': false}),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (value is Map) {
      for (final key in const [
        'ranked_opportunities',
        'opportunities',
        'states',
        'items',
        'rows',
      ]) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  num _num(dynamic value) {
    if (value is num) return value;
    return num.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    if (value == null) return '—';
    final n = _num(value).round();
    final raw = n.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return '${n < 0 ? '-' : ''}${out.toString()}';
  }

  String _compact(dynamic value) {
    final n = _num(value).toDouble();
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 1 : 2)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}K';
    }
    return n.toStringAsFixed(0);
  }

  String _clock(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
            ? value.hour - 12
            : value.hour;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${value.minute.toString().padLeft(2, '0')} $suffix';
  }

  String _dateTime(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return 'activity time unavailable';
    final local = parsed.toLocal();
    return '${local.month}/${local.day} ${_clock(local)}';
  }

  String _brief(dynamic value) {
    final map = _map(value);
    for (final key in const ['headline', 'summary', 'message', 'status']) {
      final text = '${map[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return 'BridgePoint is refreshing live property, source, matching and intelligence data.';
  }

  Map<String, dynamic> _state(
    List<Map<String, dynamic>> rows,
    String code,
  ) {
    for (final row in rows) {
      if ('${row['state_code'] ?? ''}' == code) return row;
    }
    return const {};
  }

  String _latestActivity(List<Map<String, dynamic>> states) {
    DateTime? latest;
    for (final state in states) {
      final parsed = DateTime.tryParse('${state['last_activity_at'] ?? ''}');
      if (parsed != null && (latest == null || parsed.isAfter(latest))) {
        latest = parsed;
      }
    }
    return latest == null ? 'No recent activity timestamp' : _dateTime(latest.toIso8601String());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _refreshedAt = DateTime.now();
      _request = _load();
    });
  }

  void _showOpportunity(Map<String, dynamic> row) {
    final title = '${row['title'] ?? 'BridgePoint opportunity'}';
    final address = '${row['full_address'] ?? row['address'] ?? 'Property'}';
    final explanation = '${row['why_now'] ?? row['explanation'] ?? ''}'.trim();
    final action = '${row['recommended_action'] ?? ''}'.trim();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                address,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: _cyan,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (row['score'] != null) Chip(label: Text('Score ${row['score']}')),
                  if (row['priority'] != null)
                    Chip(label: Text('${row['priority']}'.toUpperCase())),
                  if (row['confidence_score'] != null)
                    Chip(label: Text('${row['confidence_score']}% confidence')),
                  Chip(label: Text('${row['signal_count'] ?? 0} signals')),
                  Chip(label: Text('${row['source_count'] ?? 0} sources')),
                ],
              ),
              if (explanation.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'WHY IT RANKED',
                  style: TextStyle(
                    color: _amber,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(explanation, style: const TextStyle(height: 1.5)),
              ],
              if (action.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'WHAT TO CHECK NEXT',
                  style: TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(action, style: const TextStyle(height: 1.5)),
              ],
              const SizedBox(height: 18),
              const _TruthBox(
                'This is a prioritization result. It is not proof of damage, a guaranteed job, or a guaranteed transaction.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        dynamic at(int index) =>
            index < values.length ? values[index] : const <String, dynamic>{};

        final dashboard = _map(at(0));
        final sourceHealth = _map(at(1));
        final coverage = _map(at(2));
        final statePayload = _map(at(3));
        final expansion = _map(at(5));
        final mediaStatus = _map(at(6));
        final sourceSummary = _map(sourceHealth['summary']);
        final states = _rows(statePayload['states']);
        final ct = _state(states, 'CT');
        final opportunities = _rows(dashboard);
        final loading = snapshot.connectionState == ConnectionState.waiting;

        final activeProperties = _num(coverage['active_properties']);
        final evaluated = _num(coverage['evaluation_receipts']);
        final scored = _num(coverage['scored']);
        final noActive = _num(coverage['evaluated_no_active_signals']);
        final statesWithProperties = states
            .where((row) => _num(row['canonical_property_count']) > 0)
            .length;
        final liveStates = states
            .where(
              (row) => '${row['build_status'] ?? ''}'.toUpperCase() == 'LIVE',
            )
            .length;
        final scoringStates = states
            .where(
              (row) => '${row['build_status'] ?? ''}'.toUpperCase() == 'SCORING',
            )
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF07101E),
                    Color(0xFF0B233A),
                    Color(0xFF09162B),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _cyan.withValues(alpha: .18)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_cyan, _blue],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.polyline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BRIDGEPOINT INTELLIGENCE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'LIVE SYSTEM',
                            style: TextStyle(
                              color: _cyan,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                      const _LiveBadge(),
                      if (widget.owner)
                        const _SmallPill(
                          Icons.admin_panel_settings_rounded,
                          'OWNER • NATIONWIDE',
                          _amber,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'The system should look alive because it is alive.',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'These counters come from the production backend. Property foundations, source coverage, matching, evaluation and scoring move as BridgePoint processes more data.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onMap,
                        icon: const Icon(Icons.public_rounded),
                        label: const Text('Open live map'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onProperties,
                        icon: const Icon(Icons.holiday_village_rounded),
                        label: const Text('Browse properties'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onInvestor,
                        icon: const Icon(Icons.real_estate_agent_rounded),
                        label: const Text('Investor view'),
                      ),
                      if (widget.owner)
                        OutlinedButton.icon(
                          onPressed: widget.onOwner,
                          icon: const Icon(Icons.admin_panel_settings_rounded),
                          label: const Text('Owner backend'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.sync_rounded, color: _green, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Last screen refresh ${_clock(_refreshedAt)} • backend refresh every 30 sec • latest ingestion activity ${_latestActivity(states)}',
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh now',
                  onPressed: loading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1150
                    ? 4
                    : constraints.maxWidth >= 680
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                final cards = <_MetricData>[
                  _MetricData(
                    'PROPERTY FOUNDATIONS',
                    _number(coverage['active_properties']),
                    'Live U.S. property universe currently registered',
                    Icons.home_work_rounded,
                    _cyan,
                    widget.onProperties,
                  ),
                  _MetricData(
                    'PROPERTIES EVALUATED',
                    _number(coverage['evaluation_receipts']),
                    '${_number(noActive)} evaluated with no current active signal',
                    Icons.fact_check_outlined,
                    _green,
                    widget.onOwner,
                  ),
                  _MetricData(
                    'CURRENTLY SCORED',
                    _number(coverage['scored']),
                    'Current intelligence scoring output',
                    Icons.speed_rounded,
                    _blue,
                    widget.onMap,
                  ),
                  _MetricData(
                    'ACTIVE OPPORTUNITIES',
                    _number(dashboard['active_opportunities']),
                    '${opportunities.length} ranked opportunity cards loaded now',
                    Icons.track_changes_rounded,
                    _amber,
                    widget.onMap,
                  ),
                  _MetricData(
                    'REGISTERED SOURCES',
                    _number(sourceSummary['registered']),
                    '${_number(sourceSummary['healthy'])} healthy • ${_number(sourceSummary['failing'])} failing',
                    Icons.hub_rounded,
                    _cyan,
                    widget.onOwner,
                  ),
                  _MetricData(
                    'STATES WITH PROPERTY DATA',
                    '$statesWithProperties/${states.length}',
                    '$liveStates fully live • $scoringStates scoring now',
                    Icons.public_rounded,
                    _green,
                    widget.onMap,
                  ),
                  _MetricData(
                    'CONNECTICUT',
                    _number(ct['canonical_property_count']),
                    '${ct['verified_capabilities'] ?? '—'}/${ct['required_capabilities'] ?? '—'} capability groups • ${ct['build_status'] ?? 'BUILDING'}',
                    Icons.location_on_outlined,
                    _blue,
                    widget.onProperties,
                  ),
                  _MetricData(
                    'STREET / PROPERTY MEDIA',
                    _number(
                      mediaStatus['active_media'] ??
                          mediaStatus['media_rows'] ??
                          mediaStatus['total_media'],
                    ),
                    widget.owner
                        ? 'Owner media coverage status from the live backend'
                        : 'Property media appears when package and geography allow',
                    Icons.photo_library_outlined,
                    _amber,
                    widget.onBuildings,
                  ),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final card in cards)
                      SizedBox(width: width, child: _MetricCard(data: card)),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _ProgressPanel(
              activeProperties: activeProperties,
              evaluated: evaluated,
              scored: scored,
              statesWithProperties: statesWithProperties,
              totalStates: states.length,
              liveStates: liveStates,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 900;
                final feed = _Panel(
                  title: 'Live ranked opportunities',
                  subtitle:
                      'Open a ranked property to see what BridgePoint thinks matters and why.',
                  icon: Icons.leaderboard_rounded,
                  child: opportunities.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 22),
                          child: Center(
                            child: Text(
                              'No ranked opportunity rows returned in this refresh.',
                              style: TextStyle(color: _muted),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final row in opportunities.take(8))
                              _OpportunityRow(
                                row: row,
                                onTap: () => _showOpportunity(row),
                              ),
                          ],
                        ),
                );
                final brief = _Panel(
                  title: 'What changed / what is happening',
                  subtitle: 'A quick owner-friendly system read.',
                  icon: Icons.bolt_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _brief(at(4)),
                        style: const TextStyle(
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _TruthBox(
                        'Fresh means the source or processing lane has a timestamp and current activity. Missing data is shown as missing; BridgePoint does not turn “not loaded yet” into “nothing happened.”',
                      ),
                    ],
                  ),
                );
                if (stacked) {
                  return Column(
                    children: [feed, const SizedBox(height: 12), brief],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: feed),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: brief),
                  ],
                );
              },
            ),
            if (widget.owner && expansion.isNotEmpty) ...[
              const SizedBox(height: 14),
              _StateProgressTable(states: states),
            ],
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(
    this.title,
    this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
  );

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF0E2035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: data.color.withValues(alpha: .22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, color: data.color, size: 20),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB5C6D9),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.title,
                style: TextStyle(
                  color: data.color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                data.subtitle,
                style: const TextStyle(
                  color: Color(0xFFB5C6D9),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.activeProperties,
    required this.evaluated,
    required this.scored,
    required this.statesWithProperties,
    required this.totalStates,
    required this.liveStates,
  });

  final num activeProperties;
  final num evaluated;
  final num scored;
  final int statesWithProperties;
  final int totalStates;
  final int liveStates;

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _muted = Color(0xFFB5C6D9);

  double _ratio(num current, num total) =>
      total <= 0 ? 0 : (current / total).clamp(0, 1).toDouble();

  String _compact(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 1 : 2)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(0);
  }

  Widget _line(String label, num current, num total, Color color) {
    final ratio = _ratio(current, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_compact(current)} / ${_compact(total)} • ${(ratio * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: .06),
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync_rounded, color: _green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live build progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Chip(label: Text('LIVE BACKEND')),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'These bars are calculated from the current production counts. They are meant to visibly move as BridgePoint catches up.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.public_rounded, size: 17),
                    label: Text('$statesWithProperties/$totalStates states with property data'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.verified_rounded, size: 17),
                    label: Text('$liveStates states fully live'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _line(
                'Properties evaluated by the intelligence engine',
                evaluated,
                activeProperties,
                _cyan,
              ),
              const SizedBox(height: 13),
              _line(
                'Properties with current scoring output',
                scored,
                activeProperties,
                _blue,
              ),
            ],
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF48E1FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFFB5C6D9),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _OpportunityRow extends StatelessWidget {
  const _OpportunityRow({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final address = '${row['full_address'] ?? row['address'] ?? 'Property'}';
    final title = '${row['title'] ?? row['top_signal_type'] ?? 'Ranked opportunity'}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: const CircleAvatar(
        backgroundColor: Color(0x1635D2E8),
        child: Icon(Icons.bolt_rounded, color: Color(0xFFFFC95E)),
      ),
      title: Text(
        address,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        title.replaceAll('_', ' '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFB5C6D9)),
      ),
      trailing: Wrap(
        spacing: 6,
        children: [
          if (row['score'] != null) Chip(label: Text('${row['score']}')),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _StateProgressTable extends StatelessWidget {
  const _StateProgressTable({required this.states});
  final List<Map<String, dynamic>> states;

  @override
  Widget build(BuildContext context) {
    final rows = [...states]
      ..sort((a, b) {
        final av = a['last_activity_at'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.tryParse('${a['last_activity_at']}') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final bv = b['last_activity_at'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.tryParse('${b['last_activity_at']}') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        return bv.compareTo(av);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'National expansion activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recent state activity with property count and capability parity. This is owner-facing truth, not a marketing completion claim.',
              style: TextStyle(
                color: Color(0xFFB5C6D9),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${row['state_code'] ?? '—'}',
                        style: const TextStyle(
                          color: Color(0xFF48E1FF),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${row['canonical_property_count'] ?? 0} properties',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${row['ct_parity_pct'] ?? '—'}% parity',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Color(0xFFB5C6D9)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 82,
                      child: Text(
                        '${row['build_status'] ?? 'BUILDING'}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF45E6A6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: .35,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF45E6A6)
                .withValues(alpha: .07 + _controller.value * .05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF45E6A6)
                  .withValues(alpha: .28 + _controller.value * .18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF45E6A6)
                      .withValues(alpha: _controller.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF45E6A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
      );
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _TruthBox extends StatelessWidget {
  const _TruthBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC95E).withValues(alpha: .05),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: const Color(0xFFFFC95E).withValues(alpha: .17),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFB5C6D9),
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      );
}
