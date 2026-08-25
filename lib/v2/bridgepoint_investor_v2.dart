import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointInvestorV2 extends StatefulWidget {
  const BridgePointInvestorV2({super.key});

  @override
  State<BridgePointInvestorV2> createState() => _BridgePointInvestorV2State();
}

class _BridgePointInvestorV2State extends State<BridgePointInvestorV2> {
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  String _state = 'CT';
  List<Map<String, dynamic>> _stateRows = const [];
  late Future<List<dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
    _loadStates();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'error': '$e', 'rpc': rpc};
    }
  }

  Future<void> _loadStates() async {
    final raw = await _safe('bridgepoint_flutter_map_state_status_v838');
    final rows = _rows(raw is Map ? raw['states'] : raw);
    if (!mounted || rows.isEmpty) return;
    final codes = rows.map((row) => '${row['state_code'] ?? ''}').toSet();
    setState(() {
      _stateRows = rows;
      if (!codes.contains(_state)) {
        _state = '${rows.first['state_code'] ?? 'CT'}';
        _request = _load();
      }
    });
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe(
          'bridgepoint_flutter_dashboard_state_v344',
          {
            'p_state_code': _state,
            'p_model_key': 'property_investor',
            'p_limit': 20,
          },
        ),
        _safe(
          'bridgepoint_flutter_opportunities_state_v341',
          {
            'p_state_code': _state,
            'p_model_key': 'property_investor',
            'p_limit': 50,
            'p_offset': 0,
            'p_priority': null,
            'p_stage': null,
          },
        ),
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
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in const [
        'opportunities',
        'ranked_opportunities',
        'states',
        'rows',
        'items',
      ]) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Map<String, dynamic> get _stateRow {
    for (final row in _stateRows) {
      if ('${row['state_code'] ?? ''}' == _state) return row;
    }
    return const {};
  }

  void _refresh() => setState(() => _request = _load());

  void _selectState(String? value) {
    if (value == null || value == _state) return;
    setState(() {
      _state = value;
      _request = _load();
    });
  }

  String _statusExplanation(
    Map<String, dynamic> dashboard,
    Map<String, dynamic> stateRow,
    int opportunityCount,
  ) {
    final intelligenceStatus =
        '${dashboard['intelligence_status'] ?? ''}'.toUpperCase();
    final buildStatus = '${stateRow['build_status'] ?? 'BUILDING'}'.toUpperCase();
    final foundation = _int(
      stateRow['canonical_property_count'] ??
          _map(dashboard['market'])['canonical_property_count'],
    );

    if (dashboard['locked'] == true) {
      return '$_state has BridgePoint coverage metadata, but this account does not currently have the required geography or investor-ranking access.';
    }
    if (opportunityCount > 0 || intelligenceStatus == 'OPPORTUNITIES_AVAILABLE') {
      return '$_state investor intelligence is active. Ranked opportunities below are real model outputs tied to current property evidence.';
    }
    if (intelligenceStatus == 'INTELLIGENCE_PROCESSING' || buildStatus == 'SCORING') {
      return '$_state has a property foundation and scoring activity, but the Property Investor model has not produced ranked opportunities for this state yet. This screen will populate automatically when it does.';
    }
    if (foundation > 0) {
      return '$_state already has ${_number(foundation)} properties in the BridgePoint foundation. Investor scoring/opportunities are still building, so the empty opportunity feed does not mean the state has no data.';
    }
    return '$_state is still building its property foundation. Investor rankings will remain empty until real property and evidence coverage exists.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        final dashboard = values.isNotEmpty
            ? _map(values[0])
            : const <String, dynamic>{};
        final oppPayload = values.length > 1
            ? _map(values[1])
            : const <String, dynamic>{};
        final opportunities = _rows(oppPayload).isNotEmpty
            ? _rows(oppPayload)
            : _rows(_map(dashboard['opportunities']));
        final stateRow = _stateRow;
        final market = _map(dashboard['market']);
        final foundationCount = _int(
          stateRow['canonical_property_count'] ?? market['canonical_property_count'],
        );
        final sourceCount = _int(stateRow['verified_source_count']);
        final scoreStatus =
            '${dashboard['intelligence_status'] ?? stateRow['build_status'] ?? 'BUILDING'}';
        final high = opportunities.where((row) {
          final p = '${row['priority'] ?? ''}'.toLowerCase();
          return p == 'critical' || p == 'high';
        }).length;
        final assessed = opportunities.fold<double>(0, (sum, row) {
          final raw = row['assessed_total_value'];
          final n = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
          return sum + (n ?? 0);
        });
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final statusText =
            _statusExplanation(dashboard, stateRow, opportunities.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_panel, _green.withValues(alpha: .08)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withValues(alpha: .16)),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final compact = c.maxWidth < 760;
                  final title = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.real_estate_agent_rounded,
                          color: _green,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BridgePoint Investor',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'State-aware investor intelligence: property foundation readiness is shown separately from investor scoring, so a state never looks empty just because its investment model is still catching up.',
                              style: TextStyle(color: _muted, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final controls = SizedBox(
                    width: compact ? double.infinity : 310,
                    child: DropdownButtonFormField<String>(
                      initialValue: _state,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Investor state',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: (_stateRows.isEmpty
                              ? <Map<String, dynamic>>[
                                  {'state_code': _state, 'state_name': _state},
                                ]
                              : _stateRows)
                          .map(
                            (row) => DropdownMenuItem<String>(
                              value: '${row['state_code']}',
                              child: Text(
                                '${row['state_code']} • ${row['state_name'] ?? row['state_code']} • ${row['build_status'] ?? 'BUILDING'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: loading ? null : _selectState,
                    ),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: 15),
                        controls,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 18),
                      controls,
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: loading ? null : _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Investor',
                      ),
                    ],
                  );
                },
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _statusColor(scoreStatus, opportunities.isNotEmpty)
                    .withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _statusColor(scoreStatus, opportunities.isNotEmpty)
                      .withValues(alpha: .22),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _statusIcon(scoreStatus, opportunities.isNotEmpty),
                    color: _statusColor(scoreStatus, opportunities.isNotEmpty),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_state • ${scoreStatus.replaceAll('_', ' ')}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 620 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: _Metric(
                        '$_state PROPERTY FOUNDATION',
                        _number(foundationCount),
                        foundationCount > 0
                            ? 'Actual properties already in BridgePoint'
                            : 'Property foundation still building',
                        Icons.apartment_rounded,
                        _blue,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'INVESTOR OPPORTUNITIES',
                        _number(
                          oppPayload['total_results'] ?? opportunities.length,
                        ),
                        'Property Investor model • $_state',
                        Icons.track_changes_rounded,
                        _cyan,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'HIGH PRIORITY',
                        '$high',
                        'Critical + high on this state feed',
                        Icons.priority_high_rounded,
                        _amber,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'VERIFIED SOURCES',
                        _number(sourceCount),
                        assessed <= 0
                            ? '$_state source readiness'
                            : 'Feed assessed value shown: \$${_number(assessed.round())}',
                        Icons.hub_outlined,
                        _green,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_state Investor Opportunity Feed',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Only actual Property Investor model outputs appear here. Foundation data by itself never gets relabeled as an investor opportunity.',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                  const SizedBox(height: 13),
                  if (dashboard['locked'] == true || oppPayload['locked'] == true)
                    const _InvestorEmpty(
                      icon: Icons.lock_outline_rounded,
                      title: 'Investor ranking is locked for this selection',
                      detail:
                          'The state may still have a property foundation, but this account/package does not currently expose its investor-ranking feed.',
                    )
                  else if (opportunities.isEmpty && foundationCount > 0)
                    _InvestorEmpty(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Foundation ready • investor intelligence building',
                      detail:
                          '$_state already has ${_number(foundationCount)} properties. Ranked investor opportunities will appear here automatically when scoring and evidence gates produce real results.',
                    )
                  else if (opportunities.isEmpty)
                    const _InvestorEmpty(
                      icon: Icons.travel_explore_rounded,
                      title: 'State foundation still building',
                      detail:
                          'There are no investor opportunities to show yet because the underlying state property/evidence foundation is not ready.',
                    )
                  else
                    ...opportunities.take(50).map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _InvestorCard(row: row),
                          ),
                        ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(String status, bool hasOpportunities) {
    if (hasOpportunities || status.toUpperCase().contains('OPPORTUNITIES')) {
      return _green;
    }
    if (status.toUpperCase().contains('PROCESS') ||
        status.toUpperCase().contains('SCORING')) {
      return _cyan;
    }
    if (_int(_stateRow['canonical_property_count']) > 0) return _blue;
    return _amber;
  }

  IconData _statusIcon(String status, bool hasOpportunities) {
    if (hasOpportunities || status.toUpperCase().contains('OPPORTUNITIES')) {
      return Icons.check_circle_outline_rounded;
    }
    if (status.toUpperCase().contains('PROCESS') ||
        status.toUpperCase().contains('SCORING')) {
      return Icons.analytics_outlined;
    }
    if (_int(_stateRow['canonical_property_count']) > 0) {
      return Icons.storage_rounded;
    }
    return Icons.construction_rounded;
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail, this.icon, this.color);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BridgePointInvestorV2State._panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 11),
            Text(
              label,
              style: const TextStyle(
                color: _BridgePointInvestorV2State._muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _BridgePointInvestorV2State._muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
}

class _InvestorEmpty extends StatelessWidget {
  const _InvestorEmpty({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _BridgePointInvestorV2State._soft.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 2),
            Icon(icon, color: _BridgePointInvestorV2State._cyan),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: _BridgePointInvestorV2State._muted,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _InvestorCard extends StatelessWidget {
  const _InvestorCard({required this.row});
  final Map<String, dynamic> row;

  Color _priority(String value) {
    final p = value.toLowerCase();
    if (p.contains('critical')) return _BridgePointInvestorV2State._red;
    if (p.contains('high')) return _BridgePointInvestorV2State._amber;
    if (p.contains('medium')) return _BridgePointInvestorV2State._cyan;
    return _BridgePointInvestorV2State._green;
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: ListView(
              children: [
                Text(
                  '${row['full_address'] ?? row['municipality'] ?? 'Investor opportunity'}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in row.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${entry.key.replaceAll('_', ' ')}: ${entry.value}',
                      style: const TextStyle(
                        color: _BridgePointInvestorV2State._muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priority = '${row['priority'] ?? 'monitor'}';
    final color = _priority(priority);
    final signal =
        '${row['top_signal_type'] ?? row['opportunity_type'] ?? row['title'] ?? 'property intelligence'}'
            .replaceAll('_', ' ');
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _BridgePointInvestorV2State._soft.withValues(alpha: .68),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.house_siding_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row['full_address'] ?? row['municipality'] ?? 'Property'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row['municipality'] ?? ''}, ${row['state_code'] ?? ''} • ${row['property_type'] ?? 'Property'} • $signal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BridgePointInvestorV2State._muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${row['score'] ?? row['opportunity_score'] ?? '—'}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                Text(
                  priority.toUpperCase(),
                  style: const TextStyle(
                    color: _BridgePointInvestorV2State._muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: _BridgePointInvestorV2State._muted,
            ),
          ],
        ),
      ),
    );
  }
}
