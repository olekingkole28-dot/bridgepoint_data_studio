import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_operations_hub.dart';
import 'bridgepoint_owner_ai_cockpit.dart';
import 'bridgepoint_owner_global_control.dart';

/// Owner-only command center that makes unfinished work impossible to hide.
/// Backend RPCs remain authoritative; this UI never promotes a requirement to
/// complete merely because an agent ran or returned an answer.
class BridgePointOwnerCommandCenter extends StatefulWidget {
  const BridgePointOwnerCommandCenter({super.key});

  @override
  State<BridgePointOwnerCommandCenter> createState() =>
      _BridgePointOwnerCommandCenterState();
}

class _BridgePointOwnerCommandCenterState
    extends State<BridgePointOwnerCommandCenter> {
  static const _navy = Color(0xFF071321);
  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: _navy.withOpacity(.96),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.fact_check_rounded),
                  label: Text('Completion'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.auto_awesome_rounded),
                  label: Text('AI Cockpit'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.public_rounded),
                  label: Text('Global / Export'),
                ),
                ButtonSegment(
                  value: 3,
                  icon: Icon(Icons.build_circle_outlined),
                  label: Text('Operations'),
                ),
              ],
              selected: <int>{_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => const _OwnerCompletionLedger(),
            1 => const BridgePointOwnerAiCockpit(),
            2 => const BridgePointOwnerGlobalControl(),
            _ => const BridgePointOperationsHub(),
          },
        ),
      ],
    );
  }
}

class _OwnerCompletionLedger extends StatefulWidget {
  const _OwnerCompletionLedger();

  @override
  State<_OwnerCompletionLedger> createState() => _OwnerCompletionLedgerState();
}

class _OwnerCompletionLedgerState extends State<_OwnerCompletionLedger> {
  late Future<Map<String, dynamic>> _request;
  Timer? _timer;
  String _filter = 'ALL';
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _request = _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _autoRefresh) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final dynamic result = await Supabase.instance.client.rpc(
      'bridgepoint_owner_master_completion_v768',
      params: <String, dynamic>{
        'p_status': _filter == 'ALL' ? null : _filter,
        'p_limit': 216,
      },
    );
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const FormatException('Unexpected completion-ledger response.');
  }

  void _refresh({bool silent = false}) {
    if (!mounted) return;
    setState(() => _request = _load());
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing completion truth…')),
      );
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Color _statusColor(String status) => switch (status.toUpperCase()) {
        'PROVEN_DONE' => _BridgePointOwnerCommandCenterState._green,
        'IN_PROGRESS' => _BridgePointOwnerCommandCenterState._cyan,
        'FAILED' || 'BLOCKED' => _BridgePointOwnerCommandCenterState._red,
        _ => _BridgePointOwnerCommandCenterState._amber,
      };

  String _prettyStatus(String status) =>
      status.replaceAll('_', ' ').toUpperCase();

  Widget _metric(String label, dynamic value, Color color) => Container(
        width: 142,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _BridgePointOwnerCommandCenterState._panelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _BridgePointOwnerCommandCenterState._muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _workerCard(Map<String, dynamic> worker) {
    final runs = (worker['runs_8h'] as num?)?.toInt() ?? 0;
    final executed = (worker['executed_8h'] as num?)?.toInt() ?? 0;
    final blocked = (worker['blocked_8h'] as num?)?.toInt() ?? 0;
    final healthy = executed > 0;
    return Container(
      width: 265,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _BridgePointOwnerCommandCenterState._panelSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (healthy
                  ? _BridgePointOwnerCommandCenterState._green
                  : _BridgePointOwnerCommandCenterState._amber)
              .withOpacity(.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                healthy ? Icons.task_alt_rounded : Icons.warning_amber_rounded,
                color: healthy
                    ? _BridgePointOwnerCommandCenterState._green
                    : _BridgePointOwnerCommandCenterState._amber,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${worker['worker_lane'] ?? 'Worker'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$executed executed • $blocked blocked • $runs runs / 8h',
            style: const TextStyle(
              color: _BridgePointOwnerCommandCenterState._muted,
              fontSize: 9,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            healthy
                ? 'Execution evidence exists.'
                : 'No execution evidence yet — analysis does not count.',
            style: TextStyle(
              color: healthy
                  ? _BridgePointOwnerCommandCenterState._green
                  : _BridgePointOwnerCommandCenterState._amber,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nodeCard(Map<String, dynamic> node) {
    final capabilities = _map(node['capabilities']);
    final version = capabilities['agent_version'];
    final online = '${node['status']}'.toUpperCase() == 'ONLINE';
    final current = version == 718;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _BridgePointOwnerCommandCenterState._panelSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (online && current
                  ? _BridgePointOwnerCommandCenterState._green
                  : _BridgePointOwnerCommandCenterState._amber)
              .withOpacity(.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${node['node_name'] ?? 'Local node'}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${node['status'] ?? 'UNKNOWN'} • agent v${version ?? '—'} • ${node['primary_model'] ?? 'model unavailable'}',
            style: const TextStyle(
              color: _BridgePointOwnerCommandCenterState._muted,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Completed ${node['total_completed'] ?? 0} • Failed ${node['total_failed'] ?? 0}',
            style: const TextStyle(
              color: _BridgePointOwnerCommandCenterState._muted,
              fontSize: 9,
            ),
          ),
          if (!current) ...[
            const SizedBox(height: 6),
            const Text(
              'UPGRADE REQUIRED: server requires local agent v718.',
              style: TextStyle(
                color: _BridgePointOwnerCommandCenterState._amber,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: _BridgePointOwnerCommandCenterState._cyan,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(
                  color: _BridgePointOwnerCommandCenterState._amber,
                ),
              ),
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final summary = _map(data['summary']);
        final items = _rows(data['items']);
        final workers = _rows(data['worker_scoreboard']);
        final nodes = _rows(data['local_nodes']);
        final nativeRuns = _rows(data['native_runs']);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _request = _load());
            await _request;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nothing Forgotten',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All master requirements stay visible until independently proven done.',
                          style: TextStyle(
                            color: _BridgePointOwnerCommandCenterState._muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh completion truth',
                    onPressed: _refresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: _BridgePointOwnerCommandCenterState._cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metric('TOTAL', summary['total'] ?? '—', Colors.white),
                  _metric(
                    'PROVEN DONE',
                    summary['proven_done'] ?? '—',
                    _BridgePointOwnerCommandCenterState._green,
                  ),
                  _metric(
                    'OPEN',
                    summary['open'] ?? '—',
                    _BridgePointOwnerCommandCenterState._amber,
                  ),
                  _metric(
                    'IN PROGRESS',
                    summary['in_progress'] ?? '—',
                    _BridgePointOwnerCommandCenterState._cyan,
                  ),
                  _metric(
                    'COMPLETE',
                    '${summary['completion_percent'] ?? '—'}%',
                    _BridgePointOwnerCommandCenterState._green,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _BridgePointOwnerCommandCenterState._panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.07)),
                ),
                child: const Text(
                  'Truth rule: only PROVEN DONE counts as finished. Assignment, analysis, execution and IN PROGRESS remain open until independent production evidence passes.',
                  style: TextStyle(
                    color: _BridgePointOwnerCommandCenterState._cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filter,
                      dropdownColor: _BridgePointOwnerCommandCenterState._panel,
                      decoration: const InputDecoration(
                        labelText: 'Requirement status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All 216')),
                        DropdownMenuItem(
                          value: 'PROVEN_DONE',
                          child: Text('Proven done'),
                        ),
                        DropdownMenuItem(
                          value: 'IN_PROGRESS',
                          child: Text('In progress'),
                        ),
                        DropdownMenuItem(
                          value: 'NOT_STARTED',
                          child: Text('Not started'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filter = value ?? 'ALL';
                          _request = _load();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      const Text(
                        'Auto refresh',
                        style: TextStyle(
                          color: _BridgePointOwnerCommandCenterState._muted,
                          fontSize: 9,
                        ),
                      ),
                      Switch(
                        value: _autoRefresh,
                        onChanged: (value) =>
                            setState(() => _autoRefresh = value),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Worker execution truth',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: workers.map(_workerCard).toList(growable: false),
              ),
              if (nodes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Local AI nodes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: nodes.map(_nodeCard).toList(growable: false),
                ),
              ],
              if (nativeRuns.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Latest native execution',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                ...nativeRuns.take(8).map((run) {
                  final success = run['success'] == true;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(
                      success
                          ? Icons.task_alt_rounded
                          : Icons.error_outline_rounded,
                      color: success
                          ? _BridgePointOwnerCommandCenterState._green
                          : _BridgePointOwnerCommandCenterState._red,
                    ),
                    title: Text(
                      '${run['req_key'] ?? 'Requirement'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    subtitle: Text(
                      '${run['action_group'] ?? 'EXECUTOR'} • ${run['started_at'] ?? ''}',
                      style: const TextStyle(
                        color: _BridgePointOwnerCommandCenterState._muted,
                        fontSize: 9,
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              const Text(
                'Master requirements',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) {
                final status = '${item['status'] ?? 'NOT_STARTED'}';
                final color = _statusColor(status);
                final native = item['action_group'] != null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _BridgePointOwnerCommandCenterState._panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(.18)),
                  ),
                  child: ExpansionTile(
                    iconColor: color,
                    collapsedIconColor:
                        _BridgePointOwnerCommandCenterState._muted,
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: color.withOpacity(.12),
                      child: Text(
                        '${item['priority'] ?? '—'}',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      '${item['req_key'] ?? 'Requirement'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      '${item['category'] ?? 'GENERAL'} • ${_prettyStatus(status)}${native ? ' • NATIVE ${item['action_group']}' : ''}',
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${item['requirement'] ?? ''}',
                          style: const TextStyle(
                            color: _BridgePointOwnerCommandCenterState._muted,
                            fontSize: 10,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Primary: ${item['worker_key'] ?? '—'}',
                              style: const TextStyle(
                                color:
                                    _BridgePointOwnerCommandCenterState._muted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          Text(
                            native
                                ? 'Native runs ${item['native_total_runs'] ?? 0}'
                                : 'AI/review lane',
                            style: const TextStyle(
                              color: _BridgePointOwnerCommandCenterState._muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      if (item['native_last_success'] == false) ...[
                        const SizedBox(height: 6),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Latest native execution did not pass. Requirement remains open.',
                            style: TextStyle(
                              color: _BridgePointOwnerCommandCenterState._red,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
