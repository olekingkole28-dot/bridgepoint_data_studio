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

  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF7E7E);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF0E2035);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  String _text(dynamic value, [String fallback = '']) {
    final raw = '${value ?? ''}'.trim();
    return raw.isEmpty || raw == 'null' ? fallback : raw;
  }

  Future<void> _ask() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _answer = const {};
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_ai_answer_ui_v322',
        params: {'p_query': text},
      );
      if (mounted) setState(() => _answer = _map(raw));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'BridgePoint AI is temporarily unavailable. Your property data and other product surfaces are unaffected.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _fact(Map<String, dynamic> row) => Container(
        constraints: const BoxConstraints(minWidth: 145, maxWidth: 245),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _cyan.withValues(alpha: .15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(row['label'], 'FACT').toUpperCase(),
              style: const TextStyle(
                color: _cyan,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _text(row['value'], '—'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );

  Widget _evidenceCard(Map<String, dynamic> row) {
    final title = _text(row['title'] ?? row['signal_name'], 'Evidence');
    final family = _text(row['signal_family']);
    final scope = _text(row['scope']).replaceAll('_', ' ');
    final confidence = row['confidence'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _cyan.withValues(alpha: .12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.radar_rounded, color: _cyan, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                if (family.isNotEmpty || scope.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [family, scope]
                        .where((value) => value.trim().isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ],
                if (confidence != null) ...[
                  const SizedBox(height: 3),
                  Text('Confidence $confidence',
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _opportunityCard(Map<String, dynamic> row) {
    final title = _text(row['title'], 'Qualified opportunity');
    final why = _text(row['why_now']);
    final action = _text(row['recommended_action']);
    final score = row['score'] ?? row['final_score'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _green.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: _green, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (score != null)
                Text('$score',
                    style: const TextStyle(
                        color: _green,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
            ],
          ),
          if (why.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(why, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ],
          if (action.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Next: $action',
                style: const TextStyle(
                    color: _cyan, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }

  Widget _upgradeCard(Map<String, dynamic> row) {
    final name = _text(row['package_name'], 'BridgePoint package');
    final description = _text(row['description']);
    final monthly = row['monthly_price'];
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withValues(alpha: .16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium_outlined, color: _amber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                if (description.isNotEmpty)
                  Text(description,
                      style: const TextStyle(color: _muted, fontSize: 11.5)),
              ],
            ),
          ),
          if (monthly != null)
            Text('\$$monthly/mo',
                style: const TextStyle(
                    color: _amber, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _seedQuickAction(Map<String, dynamic> row) {
    final label = _text(row['label']);
    final target = _text(row['target']).toUpperCase();
    final prompt = switch (target) {
      'PROPERTY' => 'Explain this property and its strongest evidence.',
      'INTELLIGENCE_MAP' => 'What should I look for on the intelligence map right now?',
      'OPPORTUNITIES' => 'What are my strongest qualified opportunities right now?',
      'PACKAGES' => 'Which BridgePoint package best fits what I am trying to do?',
      'COVERAGE' => 'What is BridgePoint geographic coverage and expansion status?',
      'SETTINGS' => 'Explain my current BridgePoint access and settings.',
      'BILLING' => 'Explain my BridgePoint billing and subscription status.',
      _ => label,
    };
    if (prompt.trim().isEmpty) return;
    _query.text = prompt;
    _query.selection = TextSelection.collapsed(offset: _query.text.length);
  }

  Widget _answerView() {
    final headline = _text(
      _answer['headline'],
      _text(_answer['message'], 'BridgePoint response'),
    );
    final summary = _text(_answer['summary']);
    final topic = _text(_answer['topic'], _text(_answer['topic_label'], 'GENERAL'));
    final status = _text(_answer['answer_status']);
    final facts = _rows(_answer['facts']);
    final signals = _rows(_answer['signals']);
    final opportunities = _rows(_answer['opportunities']);
    final upgrades = _rows(_answer['upgrade_suggestions']);
    final quickActions = _rows(_answer['quick_actions'])
        .where((row) => row['enabled'] != false)
        .toList();
    final privacy = _text(_answer['privacy_notice']);
    final grounding = _text(_answer['grounding_notice']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: _cyan),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                      if (topic.isNotEmpty || status.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (topic.isNotEmpty)
                              Chip(label: Text(topic.replaceAll('_', ' '))),
                            if (status.isNotEmpty)
                              Chip(
                                avatar: Icon(
                                  status == 'FOUND'
                                      ? Icons.verified_outlined
                                      : Icons.info_outline_rounded,
                                  size: 16,
                                  color: status == 'FOUND' ? _green : _amber,
                                ),
                                label: Text(status.replaceAll('_', ' ')),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(summary,
                  style: const TextStyle(fontSize: 14, height: 1.55)),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: facts.map(_fact).toList(),
              ),
            ],
            if (signals.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Evidence BridgePoint used',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              ...signals.take(8).map(_evidenceCard),
            ],
            if (opportunities.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Qualified opportunities',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              ...opportunities.take(6).map(_opportunityCard),
            ],
            if (upgrades.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Access that would unlock more',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              ...upgrades.take(3).map(_upgradeCard),
            ],
            if (quickActions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: quickActions
                    .map((row) => ActionChip(
                          avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: Text(_text(row['label'], 'Ask another question')),
                          onPressed: () => _seedQuickAction(row),
                        ))
                    .toList(),
              ),
            ],
            if (grounding.isNotEmpty || privacy.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _cyan.withValues(alpha: .12)),
                ),
                child: Text(
                  [grounding, privacy]
                      .where((value) => value.trim().isNotEmpty)
                      .join('\n\n'),
                  style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ask BridgePoint AI',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
          'Ask naturally. BridgePoint AI resolves the question against your entitled property intelligence and system contracts, and says when reliable evidence is missing instead of inventing an answer.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final field = TextField(
              controller: _query,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(
                labelText: 'Ask BridgePoint AI',
                hintText: 'Example: Why is this property a priority, and which sources support it?',
                prefixIcon: Icon(Icons.auto_awesome_rounded),
              ),
            );
            final button = FilledButton.icon(
              onPressed: _busy ? null : _ask,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Ask'),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 8), button],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: field),
                const SizedBox(width: 10),
                button,
              ],
            );
          },
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: _red)),
        ],
        const SizedBox(height: 14),
        if (_answer.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Try an address, a state, your package/access, BridgePoint coverage, permit/source status, or an owner operating question if this account has owner access.',
                style: TextStyle(color: _muted, height: 1.45),
              ),
            ),
          )
        else
          _answerView(),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(13),
            child: Text(
              'AI safety/truth boundary: a generated answer does not turn weak evidence into proof. Property condition, damage, claim validity and causal conclusions still require appropriate source evidence and human/field verification.',
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}
