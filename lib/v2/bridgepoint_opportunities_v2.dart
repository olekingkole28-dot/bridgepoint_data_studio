import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOpportunitiesV2 extends StatefulWidget {
  const BridgePointOpportunitiesV2({super.key});

  @override
  State<BridgePointOpportunitiesV2> createState() =>
      _BridgePointOpportunitiesV2State();
}

class _BridgePointOpportunitiesV2State
    extends State<BridgePointOpportunitiesV2> {
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  static const int _pageSize = 25;

  String _state = 'CT';
  String _model = 'all';
  String? _priority;
  int _offset = 0;
  bool _busy = false;
  String? _message;
  late Future<List<dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'error': '$e', 'rpc': rpc};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_map_state_status_v838'),
        _safe('bridgepoint_flutter_opportunities_state_v341', {
          'p_state_code': _state,
          'p_model_key': _model,
          'p_limit': _pageSize,
          'p_offset': _offset,
          'p_priority': _priority,
          'p_stage': null,
        }),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value, [String? key]) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      if (key != null && value[key] is List) return _rows(value[key]);
      for (final k in const ['opportunities', 'states', 'items', 'rows']) {
        if (value[k] is List) return _rows(value[k]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}') ?? 0;
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

  String _money(dynamic value) {
    final raw = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (raw == null) return '—';
    if (raw >= 1000000) return '\$${(raw / 1000000).toStringAsFixed(raw >= 10000000 ? 0 : 1)}M';
    if (raw >= 1000) return '\$${(raw / 1000).toStringAsFixed(0)}K';
    return '\$${raw.toStringAsFixed(0)}';
  }

  Color _priorityColor(String? priority, dynamic score) {
    final p = '${priority ?? ''}'.toLowerCase();
    final n = score is num ? score.toDouble() : double.tryParse('${score ?? ''}') ?? 0;
    if (p == 'critical' || n >= 85) return _red;
    if (p == 'high' || n >= 70) return _amber;
    if (p == 'medium' || n >= 55) return _cyan;
    return _green;
  }

  Future<void> _refresh({String? message}) async {
    if (!mounted) return;
    setState(() {
      _message = message;
      _request = _load();
    });
  }

  void _setStateCode(String state) {
    setState(() {
      _state = state;
      _model = 'all';
      _priority = null;
      _offset = 0;
      _request = _load();
    });
  }

  void _setModel(String model) {
    setState(() {
      _model = model;
      _offset = 0;
      _request = _load();
    });
  }

  void _setPriority(String? priority) {
    setState(() {
      _priority = priority == 'all' ? null : priority;
      _offset = 0;
      _request = _load();
    });
  }

  Future<void> _save(Map<String, dynamic> row) async {
    final opportunityId = '${row['opportunity_id'] ?? ''}'.trim();
    final propertyId = '${row['property_id'] ?? ''}'.trim();
    if (opportunityId.isEmpty || propertyId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_save_opportunity_v70',
        params: {
          'p_opportunity_id': opportunityId,
          'p_property_id': propertyId,
          'p_title': '${row['title'] ?? 'BridgePoint opportunity'}',
          'p_address': '${row['full_address'] ?? ''}',
          'p_score': row['score'],
          'p_reason': '${row['explanation'] ?? row['title'] ?? ''}',
          'p_recommended_action': '${row['recommended_action'] ?? ''}',
          'p_vertical_key': '${row['model_key'] ?? 'all'}',
          'p_next_action_at': null,
        },
      );
      await _refresh(message: 'Opportunity saved to your BridgePoint workspace.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save opportunity: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: ListView(
              children: [
                Text(
                  '${row['full_address'] ?? row['title'] ?? 'BridgePoint opportunity'}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '${row['title'] ?? 'Ranked property opportunity'} • ${row['state_code'] ?? _state}',
                  style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Score ${row['score'] ?? '—'}')),
                    Chip(label: Text('${row['priority'] ?? 'monitor'}'.toUpperCase())),
                    Chip(label: Text('${row['confidence_score'] ?? '—'}% confidence')),
                    Chip(label: Text('${row['signal_count'] ?? 0} signals')),
                    Chip(label: Text('${row['source_count'] ?? 0} sources')),
                  ],
                ),
                const SizedBox(height: 14),
                if ('${row['explanation'] ?? ''}'.trim().isNotEmpty)
                  _DetailSection(
                    title: 'Why BridgePoint surfaced it',
                    child: Text(
                      '${row['explanation']}',
                      style: const TextStyle(color: _muted, height: 1.5),
                    ),
                  ),
                if ('${row['recommended_action'] ?? ''}'.trim().isNotEmpty)
                  _DetailSection(
                    title: 'Recommended action',
                    child: Text(
                      '${row['recommended_action']}',
                      style: const TextStyle(color: _muted, height: 1.5),
                    ),
                  ),
                _DetailSection(
                  title: 'Property context',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Fact('Type', row['property_type']),
                      _Fact('Built', row['year_built']),
                      _Fact('Assessed', _money(row['assessed_total_value'])),
                      _Fact('Municipality', row['municipality']),
                      _Fact('County', row['county']),
                      _Fact('Parcel', row['parcel_number']),
                    ],
                  ),
                ),
                _DetailSection(
                  title: 'Evidence counts',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Fact('Direct signals', row['direct_signal_count']),
                      _Fact('Patterns', row['pattern_count']),
                      _Fact('Matched patterns', row['matched_pattern_count']),
                      _Fact('Sources', row['source_count']),
                      _Fact('Direct sources', row['direct_source_count']),
                      _Fact('Evidence families', row['independent_evidence_families']),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _save(row),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save opportunity'),
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
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        final statesPayload = values.isNotEmpty ? _map(values[0]) : const <String, dynamic>{};
        final payload = values.length > 1 ? _map(values[1]) : const <String, dynamic>{};
        final states = _rows(statesPayload, 'states');
        final opportunities = _rows(payload, 'opportunities');
        final total = _int(payload['total_results']);
        final hasMore = payload['has_more'] == true;
        final locked = payload['locked'] == true;
        final allowedModels = payload['allowed_model_keys'] is List
            ? (payload['allowed_model_keys'] as List)
                .map((e) => '$e')
                .where((e) => e.trim().isNotEmpty)
                .toSet()
                .toList()
            : <String>[];
        if (!allowedModels.contains(_model) && _model != 'all') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _setModel('all');
          });
        }
        Map<String, dynamic>? stateTruth;
        for (final row in states) {
          if ('${row['state_code'] ?? ''}'.toUpperCase() == _state) {
            stateTruth = row;
            break;
          }
        }
        final foundation = _int(
          stateTruth?['property_foundation_count'] ??
              stateTruth?['canonical_property_count'],
        );
        final knownStateOpps = _int(stateTruth?['opportunity_count']);
        final oppStatus = '${stateTruth?['opportunity_status'] ?? 'MISSING'}';
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final first = total == 0 ? 0 : _offset + 1;
        final last = total == 0 ? 0 : (_offset + opportunities.length).clamp(0, total);
        final availableStates = states
            .where((row) => '${row['state_code'] ?? ''}'.length == 2)
            .toList()
          ..sort((a, b) => '${a['state_code']}'.compareTo('${b['state_code']}'));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opportunities',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Ranked property opportunities across every entitled state. Property foundations can exist before scoring; BridgePoint shows that difference instead of making a building state look empty.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh opportunities',
                  onPressed: waiting || _busy ? null : () => _refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (waiting || _busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: const TextStyle(color: _cyan, fontSize: 10)),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 900 ? 3 : 1;
                final width = (c.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'PROPERTY FOUNDATION',
                        _number(foundation),
                        '$_state properties available to BridgePoint',
                        Icons.home_work_outlined,
                        _blue,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'STATE OPPORTUNITY TRUTH',
                        _number(knownStateOpps),
                        oppStatus.replaceAll('_', ' '),
                        Icons.track_changes_rounded,
                        knownStateOpps > 0 ? _green : _amber,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        'MATCHING RANKED RESULTS',
                        _number(total),
                        total == 0 ? 'No current match for this filter' : '$first–$last shown',
                        Icons.leaderboard_rounded,
                        _cyan,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: availableStates.any(
                              (row) => '${row['state_code']}' == _state)
                          ? _state
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        prefixIcon: Icon(Icons.public_rounded),
                      ),
                      items: [
                        for (final row in availableStates)
                          DropdownMenuItem(
                            value: '${row['state_code']}',
                            child: Text(
                              '${row['state_code']} • ${_number(row['property_foundation_count'] ?? row['canonical_property_count'])}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: waiting ? null : (value) {
                        if (value != null) _setStateCode(value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      initialValue: _model,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        prefixIcon: Icon(Icons.psychology_alt_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All included models')),
                        for (final model in allowedModels)
                          if (model != 'all')
                            DropdownMenuItem(
                              value: model,
                              child: Text(model.replaceAll('_', ' '), overflow: TextOverflow.ellipsis),
                            ),
                      ],
                      onChanged: waiting ? null : (value) {
                        if (value != null) _setModel(value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority ?? 'all',
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All priorities')),
                        DropdownMenuItem(value: 'critical', child: Text('Critical')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: waiting ? null : _setPriority,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (locked)
              _StateMessage(
                icon: Icons.lock_outline_rounded,
                color: _amber,
                title: 'This opportunity feed is locked for the current account.',
                body:
                    'Required access: ${payload['required_feature'] ?? payload['required_geography'] ?? 'package / geography entitlement'}.',
              )
            else if (opportunities.isEmpty)
              _StateMessage(
                icon: foundation > 0
                    ? Icons.hourglass_top_rounded
                    : Icons.travel_explore_rounded,
                color: foundation > 0 ? _amber : _muted,
                title: foundation > 0
                    ? '$_state exists in BridgePoint; ranked opportunities are still building for this filter.'
                    : 'No property foundation is visible for $_state yet.',
                body: foundation > 0
                    ? 'BridgePoint already has ${_number(foundation)} property records here. Opportunity truth is $oppStatus. This screen will populate automatically as scoring and evidence reach this state.'
                    : 'As the national expansion pipeline establishes property coverage, this state will begin appearing automatically.',
              )
            else
              ...opportunities.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _OpportunityCard(
                      row: row,
                      color: _priorityColor('${row['priority']}', row['score']),
                      money: _money(row['assessed_total_value']),
                      onOpen: () => _open(row),
                      onSave: () => _save(row),
                      busy: _busy,
                    ),
                  )),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _offset <= 0 || waiting
                      ? null
                      : () {
                          setState(() {
                            _offset = (_offset - _pageSize).clamp(0, 1 << 30);
                            _request = _load();
                          });
                        },
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                ),
                Text(
                  total == 0 ? '0 results' : '$first–$last of ${_number(total)}',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                FilledButton.tonalIcon(
                  onPressed: !hasMore || waiting
                      ? null
                      : () {
                          setState(() {
                            _offset += _pageSize;
                            _request = _load();
                          });
                        },
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                ),
              ],
            ),
          ],
        );
      },
    );
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
          color: _BridgePointOpportunitiesV2State._panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 11),
            Text(
              label,
              style: const TextStyle(
                color: _BridgePointOpportunitiesV2State._muted,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                color: _BridgePointOpportunitiesV2State._muted,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      );
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.row,
    required this.color,
    required this.money,
    required this.onOpen,
    required this.onSave,
    required this.busy,
  });
  final Map<String, dynamic> row;
  final Color color;
  final String money;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final bool busy;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _BridgePointOpportunitiesV2State._panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: .16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.bolt_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['full_address'] ?? row['title'] ?? 'Property opportunity'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${row['title'] ?? row['model_key'] ?? 'BridgePoint intelligence'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _BridgePointOpportunitiesV2State._cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${row['explanation'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _BridgePointOpportunitiesV2State._muted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _Mini('Score ${row['score'] ?? '—'}'),
                          _Mini('${row['priority'] ?? 'monitor'}'.toUpperCase()),
                          _Mini('${row['confidence_score'] ?? '—'}% confidence'),
                          _Mini('${row['signal_count'] ?? 0} signals'),
                          if (money != '—') _Mini('Assessed $money'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Save opportunity',
                  onPressed: busy ? null : onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                const Icon(Icons.chevron_right_rounded, color: _BridgePointOpportunitiesV2State._muted),
              ],
            ),
          ),
        ),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _BridgePointOpportunitiesV2State._soft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _BridgePointOpportunitiesV2State._muted,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _BridgePointOpportunitiesV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 27),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: const TextStyle(
                      color: _BridgePointOpportunitiesV2State._muted,
                      fontSize: 10,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _BridgePointOpportunitiesV2State._panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: _BridgePointOpportunitiesV2State._soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label: ${value ?? '—'}',
          style: const TextStyle(
            color: _BridgePointOpportunitiesV2State._muted,
            fontSize: 9,
          ),
        ),
      );
}
