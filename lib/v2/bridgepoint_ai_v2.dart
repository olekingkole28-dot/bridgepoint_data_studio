import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointAiV2 extends StatefulWidget {
  const BridgePointAiV2({super.key});

  @override
  State<BridgePointAiV2> createState() => _BridgePointAiV2State();
}

class _BridgePointAiV2State extends State<BridgePointAiV2> {
  final _query = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _answer = const {};

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
  }

  Future<void> _ask() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_ai_answer_ui_v322',
        params: {'p_query': text},
      );
      if (mounted) setState(() => _answer = _map(raw));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ask BridgePoint AI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
          'Ask about properties, evidence, sources, weather, permits, models, workflows and BridgePoint capabilities. Answers should stay tied to available BridgePoint evidence and system context.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _query,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(
                labelText: 'Ask BridgePoint AI',
                hintText: 'Example: Why is this property a priority, and which sources support it?',
                prefixIcon: Icon(Icons.auto_awesome_rounded),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(onPressed: _busy ? null : _ask, icon: const Icon(Icons.send_rounded), label: const Text('Ask')),
        ]),
        if (_busy) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Color(0xFFFF7E7E)))],
        const SizedBox(height: 14),
        if (_answer.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('BridgePoint AI is ready for a question.', style: TextStyle(color: _muted)),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: _cyan),
                  SizedBox(width: 8),
                  Text('BridgePoint response', style: TextStyle(fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 10),
                ..._answer.entries.map((entry) {
                  final raw = '${entry.value}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableText(
                      '${entry.key.replaceAll('_', ' ')}\n${raw.length > 2400 ? '${raw.substring(0, 2400)}…' : raw}',
                      style: const TextStyle(height: 1.45),
                    ),
                  );
                }),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(13),
            child: Text(
              'AI safety/truth boundary: a generated answer does not turn weak evidence into proof. Property condition, damage, claim validity and causal conclusions still require appropriate source evidence and human/field verification.',
              style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}
