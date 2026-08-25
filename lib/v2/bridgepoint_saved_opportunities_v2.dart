import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointSavedOpportunitiesV2 extends StatefulWidget {
  const BridgePointSavedOpportunitiesV2({super.key});

  @override
  State<BridgePointSavedOpportunitiesV2> createState() =>
      _BridgePointSavedOpportunitiesV2State();
}

class _BridgePointSavedOpportunitiesV2State
    extends State<BridgePointSavedOpportunitiesV2> {
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  late Future<dynamic> _request;
  bool _busy = false;
  String? _message;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _load() => Supabase.instance.client.rpc(
        'bridgepoint_saved_opportunities_v842',
        params: {'p_limit': 250, 'p_offset': 0},
      );

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
    if (value is Map && value['saved_opportunities'] is List) {
      return _rows(value['saved_opportunities']);
    }
    return const [];
  }

  String _stage(Map<String, dynamic> row) {
    final value = '${row['lead_stage'] ?? ''}'.trim().toLowerCase();
    return value.isEmpty ? 'saved' : value;
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'won':
      case 'converted':
        return _green;
      case 'lost':
      case 'closed':
        return _red;
      case 'contacted':
      case 'working':
      case 'qualified':
        return _cyan;
      case 'follow_up':
        return _amber;
      default:
        return _muted;
    }
  }

  void _reload([String? message]) {
    setState(() {
      _message = message;
      _request = _load();
    });
  }

  Future<void> _update(
    Map<String, dynamic> row, {
    String? stage,
    DateTime? nextAction,
    bool clearDate = false,
  }) async {
    final id = '${row['saved_opportunity_id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_update_saved_opportunity_v842',
        params: {
          'p_saved_opportunity_id': id,
          'p_lead_stage': stage,
          'p_next_action_at': clearDate
              ? null
              : nextAction?.toUtc().toIso8601String() ?? row['next_action_at'],
        },
      );
      _reload('Saved opportunity updated.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not update saved opportunity: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDate(Map<String, dynamic> row) async {
    final now = DateTime.now();
    final current = DateTime.tryParse('${row['next_action_at'] ?? ''}')?.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null) return;
    await _update(
      row,
      nextAction: DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _editStage(Map<String, dynamic> row) async {
    final current = _stage(row);
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            const ListTile(
              title: Text('Lead stage', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Track what happens after BridgePoint surfaces the opportunity.'),
            ),
            for (final stage in const [
              'saved',
              'qualified',
              'contacted',
              'working',
              'follow_up',
              'won',
              'lost',
            ])
              ListTile(
                leading: Icon(
                  stage == current ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: _stageColor(stage),
                ),
                title: Text(stage.replaceAll('_', ' ').toUpperCase()),
                onTap: () => Navigator.pop(context, stage),
              ),
          ],
        ),
      ),
    );
    if (value != null && value != current) {
      await _update(row, stage: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _request,
      builder: (context, snapshot) {
        final payload = _map(snapshot.data);
        final allRows = _rows(payload);
        final rows = _filter == 'all'
            ? allRows
            : allRows.where((row) => _stage(row) == _filter).toList();
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final due = allRows.where((row) {
          final dt = DateTime.tryParse('${row['next_action_at'] ?? ''}');
          return dt != null && dt.isBefore(DateTime.now().toUtc().add(const Duration(days: 1)));
        }).length;
        final active = allRows.where((row) {
          final stage = _stage(row);
          return stage != 'won' && stage != 'lost' && stage != 'closed';
        }).length;

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
                        'Saved Opportunities',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Your saved BridgePoint leads, team-shared Company queue, lead stage and next-action dates in one working list.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh saved opportunities',
                  onPressed: waiting || _busy ? null : () => _reload(),
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
                final columns = c.maxWidth >= 900 ? 4 : c.maxWidth >= 600 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 9) / columns;
                return Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'SAVED LEADS',
                        value: '${payload['total_results'] ?? allRows.length}',
                        detail: payload['team_shared'] == true ? 'Company shared queue' : 'Personal queue',
                        icon: Icons.bookmark_added_outlined,
                        color: _cyan,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'ACTIVE',
                        value: '$active',
                        detail: 'Still in play',
                        icon: Icons.track_changes_rounded,
                        color: _green,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'DUE / NEXT 24H',
                        value: '$due',
                        detail: 'Needs attention',
                        icon: Icons.schedule_rounded,
                        color: _amber,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'TEAM MODE',
                        value: payload['team_shared'] == true ? 'SHARED' : 'PERSONAL',
                        detail: 'Access follows workspace membership',
                        icon: Icons.groups_rounded,
                        color: payload['team_shared'] == true ? _cyan : _muted,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                selected: {_filter},
                onSelectionChanged: (value) => setState(() => _filter = value.first),
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'saved', label: Text('Saved')),
                  ButtonSegment(value: 'qualified', label: Text('Qualified')),
                  ButtonSegment(value: 'contacted', label: Text('Contacted')),
                  ButtonSegment(value: 'working', label: Text('Working')),
                  ButtonSegment(value: 'follow_up', label: Text('Follow-up')),
                  ButtonSegment(value: 'won', label: Text('Won')),
                  ButtonSegment(value: 'lost', label: Text('Lost')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              _StateMessage(
                title: 'Saved opportunity queue unavailable',
                body: '${snapshot.error}',
                icon: Icons.error_outline_rounded,
                color: _red,
              )
            else if (rows.isEmpty)
              const _StateMessage(
                title: 'No saved opportunities in this view yet.',
                body:
                    'Use the bookmark button in Opportunities to save a ranked lead. It will appear here with its score, reason, recommended action and follow-up workflow.',
                icon: Icons.bookmark_border_rounded,
                color: _muted,
              )
            else
              ...rows.map((row) {
                final stage = _stage(row);
                final color = _stageColor(stage);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: .15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.bolt_rounded, color: color),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row['address'] ?? row['title'] ?? 'Saved opportunity'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${row['title'] ?? row['vertical_key'] ?? 'BridgePoint opportunity'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Pill(stage.replaceAll('_', ' ').toUpperCase(), color),
                          ],
                        ),
                        if ('${row['reason'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(
                            '${row['reason']}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Pill('SCORE ${row['score'] ?? '—'}', _cyan),
                            if (row['next_action_at'] != null)
                              _Pill('NEXT ${row['next_action_at']}', _amber),
                            if (row['team_shared'] == true)
                              const _Pill('TEAM SHARED', _green),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _editStage(row),
                              icon: const Icon(Icons.tune_rounded),
                              label: const Text('Stage'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _chooseDate(row),
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text(row['next_action_at'] == null ? 'Set next action' : 'Change next action'),
                            ),
                            if (row['next_action_at'] != null)
                              TextButton.icon(
                                onPressed: _busy ? null : () => _update(row, clearDate: true),
                                icon: const Icon(Icons.event_busy_outlined),
                                label: const Text('Clear date'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _BridgePointSavedOpportunitiesV2State._panel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: .13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: _BridgePointSavedOpportunitiesV2State._muted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(color: _BridgePointSavedOpportunitiesV2State._muted, fontSize: 9)),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w900),
        ),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _BridgePointSavedOpportunitiesV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(body, style: const TextStyle(color: _BridgePointSavedOpportunitiesV2State._muted, fontSize: 10, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
}
