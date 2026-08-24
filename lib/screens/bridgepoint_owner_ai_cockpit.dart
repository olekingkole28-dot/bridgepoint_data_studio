import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner-only AI cockpit. Backend RPCs enforce owner access and retain all
/// source-code/model-internals boundaries. This surface is for operating the
/// BridgePoint reasoning/control plane, not exposing privileged internals to customers.
class BridgePointOwnerAiCockpit extends StatefulWidget {
  const BridgePointOwnerAiCockpit({super.key});

  @override
  State<BridgePointOwnerAiCockpit> createState() =>
      _BridgePointOwnerAiCockpitState();
}

class _BridgePointOwnerAiCockpitState
    extends State<BridgePointOwnerAiCockpit> {
  late Future<Map<String, dynamic>> _status;
  final _prompt = TextEditingController();
  bool _working = false;
  String? _output;

  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

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

  Future<Map<String, dynamic>> _rpc(
    String name, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) async {
    final dynamic result =
        await Supabase.instance.client.rpc(name, params: params);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List) return <String, dynamic>{'items': result};
    return <String, dynamic>{'result': result};
  }

  Future<Map<String, dynamic>> _load() async {
    final values = await Future.wait<Map<String, dynamic>>([
      _rpc('bridgepoint_owner_ai_control_center_v582'),
      _rpc('bridgepoint_owner_ai_fleet_v557'),
      _rpc('bridgepoint_owner_autonomy_status_v621'),
      _rpc('bridgepoint_owner_ai_control_local_v598'),
    ]);
    return <String, dynamic>{
      'control': values[0],
      'fleet': values[1],
      'autonomy': values[2],
      'local': values[3],
    };
  }

  String _pretty(dynamic value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  Future<void> _run(
    String label,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (_working) return;
    setState(() {
      _working = true;
      _output = '$label…';
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _output = _pretty(result);
        _status = _load();
      });
    } catch (error) {
      if (mounted) setState(() => _output = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _ask() async {
    final value = _prompt.text.trim();
    if (value.isEmpty) return;
    await _run(
      'BridgePoint AI',
      () => _rpc('bridgepoint_owner_ai_ask_v557',
          <String, dynamic>{'p_message': value}),
    );
  }

  Future<void> _submitIntent() async {
    final value = _prompt.text.trim();
    if (value.isEmpty) return;
    await _run(
      'Owner intent',
      () => _rpc('bridgepoint_owner_intent_submit_v572',
          <String, dynamic>{'p_message': value}),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle,
                style: const TextStyle(
                    color: _muted, fontSize: 11, height: 1.45)),
            const SizedBox(height: 12),
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
        width: 245,
        child: FilledButton(
          onPressed: _working ? null : onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(14),
            backgroundColor: _panelSoft,
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(.09)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(hint,
                        style: const TextStyle(
                            color: _muted, fontSize: 10, height: 1.35)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Owner AI Cockpit',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text(
                          'Operate BridgePoint AI, local reasoning, fleet status and owner intents from inside the app.',
                          style: TextStyle(color: _muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh AI status',
                    onPressed: () => setState(() => _status = _load()),
                    icon: const Icon(Icons.refresh_rounded, color: _cyan),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(color: _cyan)
              else if (snapshot.hasError)
                Text(snapshot.error.toString(),
                    style: const TextStyle(color: _amber))
              else ...[
                _card(
                  title: 'Command BridgePoint in plain English',
                  subtitle:
                      'Ask for analysis now, or submit a durable owner intent so the control plane can track the request instead of losing it in chat history.',
                  child: Column(
                    children: [
                      TextField(
                        controller: _prompt,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          hintText:
                              'Example: find the biggest unfinished customer-facing gaps and prioritize the ones most likely to produce a paid trial.',
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
                              style: FilledButton.styleFrom(
                                backgroundColor: _cyan,
                                foregroundColor: const Color(0xFF00151C),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _working ? null : _submitIntent,
                              icon: const Icon(Icons.task_alt_rounded),
                              label: const Text('Lock as owner intent'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'AI operating controls',
                  subtitle:
                      'Read the canonical owner control plane instead of guessing whether an AI lane is actually running.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _quick(
                        Icons.hub_rounded,
                        'AI fleet',
                        'Workers, queues and ownership.',
                        () => _run('AI fleet',
                            () => _rpc('bridgepoint_owner_ai_fleet_v557')),
                      ),
                      _quick(
                        Icons.memory_rounded,
                        'Local AI',
                        'Local-first reasoning status and enrollment.',
                        () => _run('Local AI', () =>
                            _rpc('bridgepoint_owner_ai_control_local_v598')),
                      ),
                      _quick(
                        Icons.monitor_heart_rounded,
                        'Autonomy health',
                        'Growth, expansion, backup and supervisor truth.',
                        () => _run('Autonomy health', () =>
                            _rpc('bridgepoint_owner_autonomy_status_v621')),
                      ),
                      _quick(
                        Icons.psychology_alt_rounded,
                        'Reasoning queue',
                        'Recent owner reasoning tasks and status.',
                        () => _run(
                          'Reasoning queue',
                          () => _rpc('bridgepoint_owner_ai_chat_history_v557',
                              <String, dynamic>{'p_limit': 40}),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Live control-plane snapshot',
                  subtitle:
                      'This is raw owner-only status for debugging and verification. Customer surfaces remain plain-language and package-scoped.',
                  child: SelectableText(
                    _pretty(data),
                    style: const TextStyle(
                        color: _muted,
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 1.45),
                  ),
                ),
              ],
              if (_output != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panelSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _green.withOpacity(.28)),
                  ),
                  child: SelectableText(
                    _output!,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 1.45),
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
