import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_property_dossier_recovered_v3.dart' as recovered_v3;

/// Recovery V4 keeps the proven visual/property dossier intact and adds the
/// customer-safe V907 intelligence snapshot as a persistent property ribbon.
/// Hidden model weights and restricted raw evidence never enter this surface.
class BridgePointPropertyDossierV2 extends StatefulWidget {
  const BridgePointPropertyDossierV2({
    super.key,
    required this.propertyId,
    required this.seed,
    this.asPage = false,
  });

  final String propertyId;
  final Map<String, dynamic> seed;
  final bool asPage;

  @override
  State<BridgePointPropertyDossierV2> createState() =>
      _BridgePointPropertyDossierRecoveryV4State();
}

class _BridgePointPropertyDossierRecoveryV4State
    extends State<BridgePointPropertyDossierV2> {
  static const _bg = Color(0xFF040B14);
  static const _panel = Color(0xF20B1B2C);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF7474);
  static const _muted = Color(0xFFB5C6D9);

  late Future<Map<String, dynamic>> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  @override
  void didUpdateWidget(covariant BridgePointPropertyDossierV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.propertyId != widget.propertyId) {
      _snapshot = _load();
    }
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_intelligence_snapshot_v907',
        params: {'p_property_id': widget.propertyId},
      );
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {
      // The dossier remains fully usable if this additive intelligence call
      // is temporarily unavailable.
    }
    return const <String, dynamic>{
      'complete': false,
      'available': false,
    };
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
        .where((row) => row['locked'] != true)
        .toList();
  }

  String _text(dynamic value, [String fallback = '—']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _scoreText(dynamic value) {
    if (value is num) {
      final d = value.toDouble();
      return d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(1);
    }
    return _text(value);
  }

  Color _tierColor(String tier) {
    final value = tier.toUpperCase();
    if (value.contains('CRITICAL') || value.contains('URGENT')) return _red;
    if (value.contains('HIGH')) return _amber;
    if (value.contains('LOW')) return _muted;
    return _green;
  }

  Future<void> _openIntelligence(Map<String, dynamic> payload) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (context) => FractionallySizedBox(
        heightFactor: .88,
        child: SafeArea(
          child: _IntelligenceDetails(payload: payload),
        ),
      ),
    );
  }

  Widget _ribbon(Map<String, dynamic> payload) {
    final score = _map(payload['score']);
    final signals = _rows(payload['signals']);
    final patterns = _rows(payload['patterns']);
    final scoreAvailable = score['available'] == true;
    final locked = payload['locked'] == true;
    final tier = _text(score['priority_tier'], scoreAvailable ? 'SCORED' : 'NO SCORE');
    final color = _tierColor(tier);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: locked || payload['complete'] == false
            ? null
            : () => _openIntelligence(payload),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cyan.withValues(alpha: .45), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .34),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final scoreBlock = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: color.withValues(alpha: .32)),
                    ),
                    child: Text(
                      scoreAvailable ? _scoreText(score['intelligence_score']) : '—',
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PROPERTY INTELLIGENCE',
                        style: TextStyle(
                          color: _cyan,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locked ? 'Locked by geography/package' : tier,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              );

              final stats = Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _RibbonStat('${signals.length}', 'signals', _cyan),
                  _RibbonStat('${patterns.length}', 'patterns', _green),
                  if (score['source_count'] != null)
                    _RibbonStat('${score['source_count']}', 'sources', _amber),
                  const Icon(Icons.expand_less_rounded, color: _muted),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    scoreBlock,
                    const SizedBox(height: 9),
                    stats,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: scoreBlock),
                  const SizedBox(width: 10),
                  stats,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        recovered_v3.BridgePointPropertyDossierV2(
          propertyId: widget.propertyId,
          seed: widget.seed,
          asPage: widget.asPage,
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _snapshot,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 5,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const LinearProgressIndicator(minHeight: 5),
                  );
                }
                return _ribbon(snapshot.data ?? const {});
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RibbonStat extends StatelessWidget {
  const _RibbonStat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: Text(
          '$value $label',
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _IntelligenceDetails extends StatelessWidget {
  const _IntelligenceDetails({required this.payload});

  final Map<String, dynamic> payload;

  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

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
        .where((row) => row['locked'] != true)
        .toList();
  }

  String _text(dynamic value, [String fallback = '—']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _date(dynamic value) {
    final raw = _text(value, 'Date unavailable');
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _confidence(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '—';
    final p = n <= 1 ? n * 100 : n;
    return '${p.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final score = _map(payload['score']);
    final signals = _rows(payload['signals']);
    final patterns = _rows(payload['patterns']);

    return Scaffold(
      backgroundColor: const Color(0xFF040B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071321),
        title: const Text('Property Intelligence'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (score['available'] == true)
            _SectionCard(
              icon: Icons.speed_rounded,
              color: _cyan,
              title: 'Score ${_text(score['intelligence_score'])} • ${_text(score['priority_tier'], 'Prioritized')}',
              subtitle: _text(
                score['explanation'],
                'BridgePoint summarized the linked evidence into a review priority.',
              ),
              chips: [
                '${score['signal_count'] ?? signals.length} signals',
                '${score['pattern_count'] ?? patterns.length} patterns',
                '${score['source_count'] ?? '—'} sources',
                'Stage ${_text(score['intelligence_stage'])}',
              ],
              note: _text(score['plain_english']),
            )
          else
            const _SectionCard(
              icon: Icons.speed_outlined,
              color: _muted,
              title: 'No customer-visible score yet',
              subtitle:
                  'The property can still have useful facts, imagery and evidence even when a current scoring output is unavailable.',
              chips: [],
              note:
                  'No score is not the same as no activity. It only means this scoring contract has no package-safe current result.',
            ),
          const SizedBox(height: 12),
          _Header('SIGNALS', '${signals.length} source-backed reasons to look closer', _cyan),
          const SizedBox(height: 8),
          if (signals.isEmpty)
            const _EmptyCard('No customer-visible signals are linked right now.')
          else
            ...signals.map(
              (row) => _EvidenceCard(
                icon: Icons.bolt_rounded,
                color: _cyan,
                title: _text(row['title'] ?? row['signal_name'], 'Property signal'),
                subtitle:
                    '${_date(row['event_at'])} • ${_text(row['signal_family'], 'Signal')} • ${_confidence(row['confidence'])} confidence',
                body: _text(row['description'], _text(row['plain_english'])),
                footer: row['verified'] == true
                    ? 'Source record marked verified; interpretation still requires context.'
                    : _text(row['plain_english']),
              ),
            ),
          const SizedBox(height: 16),
          _Header('PATTERNS', '${patterns.length} multi-signal shapes', _green),
          const SizedBox(height: 8),
          if (patterns.isEmpty)
            const _EmptyCard('No customer-visible patterns are linked right now.')
          else
            ...patterns.map(
              (row) => _EvidenceCard(
                icon: Icons.hub_rounded,
                color: _green,
                title: _text(row['pattern_name'], 'Detected pattern'),
                subtitle:
                    '${row['signal_count'] ?? '—'} signals • ${row['distinct_sources'] ?? '—'} sources • ${_confidence(row['pattern_confidence'])} confidence',
                body:
                    'Detected ${_date(row['detected_at'])}; latest linked signal ${_date(row['latest_signal_at'])}.',
                footer: _text(row['plain_english']),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _amber.withValues(alpha: .28)),
            ),
            child: Text(
              _text(
                payload['truth_note'],
                'BridgePoint exposes explainable outputs while keeping hidden model weights and restricted evidence private.',
              ),
              style: const TextStyle(color: _amber, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.eyebrow, this.title, this.color);
  final String eyebrow;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.note,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> chips;
  final String note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(height: 1.45)),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: chips
                    .map(
                      (text) => Chip(
                        label: Text(text),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 9),
            Text(note, style: const TextStyle(color: Color(0xFFFFC95E), height: 1.4)),
          ],
        ),
      );
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String body;
  final String footer;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
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
              const SizedBox(height: 9),
              Text(body, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 7),
              Text(
                footer,
                style: const TextStyle(
                  color: Color(0xFFFFC95E),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFB5C6D9), height: 1.4),
          ),
        ),
      );
}
