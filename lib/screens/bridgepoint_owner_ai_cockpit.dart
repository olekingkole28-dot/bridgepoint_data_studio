import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerAiCockpit extends StatefulWidget {
  const BridgePointOwnerAiCockpit({super.key});

  @override
  State<BridgePointOwnerAiCockpit> createState() =>
      _BridgePointOwnerAiCockpitState();
}

class _BridgePointOwnerAiCockpitState
    extends State<BridgePointOwnerAiCockpit> {
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);

  final _prompt = TextEditingController();
  late Future<Map<String, dynamic>> _status;
  bool _working = false;
  String? _outputTitle;
  String? _outputBody;

  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> _rpc(
    String name, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) async {
    final result = await Supabase.instance.client.rpc(name, params: params);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List) return {'items': result};
    return {'result': result};
  }

  Future<Map<String, dynamic>> _load() async {
    final values = await Future.wait([
      _rpc('bridgepoint_owner_ai_control_center_v582'),
      _rpc('bridgepoint_owner_ai_fleet_v557'),
      _rpc('bridgepoint_owner_autonomy_status_v621'),
      _rpc('bridgepoint_owner_ai_control_local_v598'),
    ]);
    return {
      'control': values[0],
      'fleet': values[1],
      'autonomy': values[2],
      'local': values[3],
    };
  }

  String _friendlyResult(String label, Map<String, dynamic> result) {
    final message = '${result['message'] ?? result['answer'] ?? result['summary'] ?? result['response'] ?? ''}'.trim();
    if (message.isNotEmpty) return message;
    final status = '${result['status'] ?? result['state'] ?? ''}'.trim();
    if (status.isNotEmpty) return '$label finished with status ${status.replaceAll('_', ' ').toLowerCase()}.';
    if (result['complete'] == true || result['success'] == true) {
      return '$label completed successfully. The live cockpit has been refreshed.';
    }
    return '$label returned successfully. The live cockpit has been refreshed with the newest state.';
  }

  Future<void> _run(
    String label,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (_working) return;
    setState(() {
      _working = true;
      _outputTitle = label;
      _outputBody = 'Working…';
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _outputBody = _friendlyResult(label, result);
        _status = _load();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _outputBody = '$label could not complete right now. Check the runtime-health card below and retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _ask() async {
    final value = _prompt.text.trim();
    if (value.isEmpty) return;
    await _run(
      'BridgePoint AI',
      () => _rpc('bridgepoint_owner_ai_ask_v557', {'p_message': value}),
    );
  }

  Future<void> _submitIntent() async {
    final value = _prompt.text.trim();
    if (value.isEmpty) return;
    await _run(
      'Owner intent',
      () => _rpc('bridgepoint_owner_intent_submit_v572', {'p_message': value}),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .11)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle,
                style: const TextStyle(color: _muted, fontSize: 13, height: 1.42)),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );

  Widget _quick(
    IconData icon,
    String label,
    String hint,
    VoidCallback onPressed,
  ) =>
      SizedBox(
        width: 255,
        child: FilledButton(
          onPressed: _working ? null : onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(14),
            backgroundColor: _soft,
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: .11)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(hint,
                        style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _status,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Owner AI Cockpit',
                            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                        SizedBox(height: 5),
                        Text(
                          'Operate BridgePoint AI, worker lanes, reasoning queues and durable owner intents without reading backend payloads.',
                          style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh AI status',
                    onPressed: () => setState(() => _status = _load()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const LinearProgressIndicator(color: _cyan)
              else if (snapshot.hasError)
                const _FriendlyIssue(
                  title: 'AI status is temporarily unavailable',
                  body: 'BridgePoint could not refresh the owner control plane. Retry from the refresh button; no customer data is affected.',
                )
              else ...[
                _OwnerAiStatusSummary(data: data),
                const SizedBox(height: 12),
                _section(
                  title: 'Command BridgePoint in plain English',
                  subtitle:
                      'Ask for analysis now or lock a durable owner intent so the operating system can track it.',
                  child: Column(
                    children: [
                      TextField(
                        controller: _prompt,
                        minLines: 3,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          hintText: 'Example: find the biggest unfinished customer-facing gaps and rank them by revenue impact.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _working ? null : _ask,
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Ask BridgePoint AI'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _working ? null : _submitIntent,
                              icon: const Icon(Icons.task_alt_rounded),
                              label: const Text('Lock owner intent'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Operating controls',
                  subtitle: 'Open the canonical operating lanes without exposing internal RPC payloads.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _quick(Icons.hub_rounded, 'AI fleet', 'Worker ownership, queues and health.',
                          () => _run('AI fleet', () => _rpc('bridgepoint_owner_ai_fleet_v557'))),
                      _quick(Icons.memory_rounded, 'Local AI', 'Local-first runtime and enrollment status.',
                          () => _run('Local AI', () => _rpc('bridgepoint_owner_ai_control_local_v598'))),
                      _quick(Icons.monitor_heart_rounded, 'Autonomy health', 'Expansion, growth, backup and supervisor truth.',
                          () => _run('Autonomy health', () => _rpc('bridgepoint_owner_autonomy_status_v621'))),
                      _quick(Icons.psychology_alt_rounded, 'Reasoning queue', 'Recent owner reasoning activity.',
                          () => _run('Reasoning queue', () => _rpc('bridgepoint_owner_ai_chat_history_v557', {'p_limit': 40}))),
                    ],
                  ),
                ),
              ],
              if (_outputBody != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _green.withValues(alpha: .25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_outputTitle ?? 'BridgePoint AI',
                          style: const TextStyle(color: _cyan, fontSize: 13, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(_outputBody!, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
              if (_working) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(color: _cyan),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OwnerAiStatusSummary extends StatelessWidget {
  const _OwnerAiStatusSummary({required this.data});
  final Map<String, dynamic> data;

  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  Widget _metric(String label, String value, Color color, IconData icon) => Container(
        width: 145,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final control = _map(data['control']);
    final runtime = _map(control['runtime']);
    final counts = _map(control['task_counts']);
    final provider = _map(control['provider']);
    final workers = _rows(control['workers']);
    final activeTasks = _rows(control['active_tasks']);
    final healthy = runtime['edge_function_ready'] == true && runtime['last_error'] == null;
    final failed = _int(counts['failed']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _cyan.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Live operating status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Worker fleet, task flow and runtime health at a glance.',
              style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _metric('Workers', '${workers.length}', _cyan, Icons.groups_2_rounded),
              _metric('Active tasks', '${activeTasks.length}', _green, Icons.bolt_rounded),
              _metric('Running', '${_int(counts['running'])}', _green, Icons.play_circle_fill_rounded),
              _metric('Queued', '${_int(counts['queued'])}', _amber, Icons.schedule_rounded),
              _metric('Succeeded', '${_int(counts['succeeded'])}', _cyan, Icons.check_circle_rounded),
              _metric('Failed', '$failed', failed == 0 ? _green : _red, Icons.error_outline_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _soft.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: (healthy ? _green : _amber).withValues(alpha: .18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(healthy ? Icons.health_and_safety_rounded : Icons.warning_amber_rounded,
                    color: healthy ? _green : _amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(healthy ? 'Runtime healthy' : 'Runtime needs attention',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        '${runtime['provider_name'] ?? 'BridgePoint local-first'} • edge function ${runtime['edge_function_ready'] == true ? 'ready' : 'not ready'} • hosted provider ${provider['enabled'] == true ? 'enabled' : 'disabled'}',
                        style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (workers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('WORKER FLEET',
                style: TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 7),
            ...workers.take(16).map((worker) {
              final status = '${worker['status'] ?? 'UNKNOWN'}'.toUpperCase();
              final color = status == 'RUNNING'
                  ? _green
                  : status == 'FAILED'
                      ? _red
                      : status == 'IDLE'
                          ? _cyan
                          : _amber;
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _soft.withValues(alpha: .48),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('${worker['display_name'] ?? worker['role'] ?? 'AI worker'}',
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                              ),
                              Text(status,
                                  style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('${worker['mission'] ?? 'BridgePoint autonomous operating lane'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _FriendlyIssue extends StatelessWidget {
  const _FriendlyIssue({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFC95E).withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC95E)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: Color(0xFFB5C6D9), height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}
