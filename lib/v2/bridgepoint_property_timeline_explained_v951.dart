import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _cyan = Color(0xFF48E1FF);
const _green = Color(0xFF45E6A6);
const _amber = Color(0xFFFFC95E);
const _red = Color(0xFFFF6B6B);
const _muted = Color(0xFFB5C6D9);
const _panel = Color(0xFF0E2035);

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _rows(dynamic value, [List<String>? keys]) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  if (value is Map) {
    for (final key in keys ?? const ['items', 'rows', 'results']) {
      if (value[key] is List) return _rows(value[key]);
    }
  }
  return const [];
}

String _text(dynamic value, [String fallback = '—']) {
  if (value == null) return fallback;
  final raw = '$value'.trim();
  return raw.isEmpty || raw == 'null' ? fallback : raw;
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
    .join(' ');

String _time(dynamic value) {
  final raw = _text(value, 'Unknown date');
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _percent(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) return 'Not scored';
  final normalized = number <= 1 ? number * 100 : number;
  return '${normalized.toStringAsFixed(normalized >= 10 ? 0 : 1)}%';
}

class BridgePointExplainedTimelineV951 extends StatelessWidget {
  const BridgePointExplainedTimelineV951({super.key, required this.payload});

  final Map<String, dynamic> payload;

  Color _color(String type) => switch (type.toUpperCase()) {
        'OPPORTUNITY' => _green,
        'PATTERN' => _amber,
        'CLAIM' => _red,
        'NOTE' => _cyan,
        _ => _cyan,
      };

  IconData _icon(String type) => switch (type.toUpperCase()) {
        'OPPORTUNITY' => Icons.bolt_rounded,
        'PATTERN' => Icons.account_tree_outlined,
        'CLAIM' => Icons.assignment_outlined,
        'NOTE' => Icons.sticky_note_2_outlined,
        _ => Icons.radar_outlined,
      };

  String _typeMeaning(String type) => switch (type.toUpperCase()) {
        'SIGNAL' =>
          'A dated observation from a source that BridgePoint connected to this property or its surrounding area.',
        'PATTERN' =>
          'Multiple observations that line up over time. A pattern strengthens context but is not proof by itself.',
        'OPPORTUNITY' =>
          'BridgePoint’s evidence gate passed and ranked this property for review. It is a priority candidate, not a guaranteed job, claim, loss, or sale.',
        'CLAIM' =>
          'An authorized claim-workflow event associated with this account and property.',
        'NOTE' =>
          'A private note or follow-up saved in this BridgePoint workspace.',
        _ =>
          'A dated BridgePoint intelligence event connected to this property.',
      };

  String _supportMeaning(String support) {
    final normalized = support.toUpperCase();
    if (normalized.contains('AREA')) {
      return 'Area context: the source is relevant to the property location, but it is not evidence that the event happened to this exact building.';
    }
    if (normalized.contains('DIRECT_MODEL')) {
      return 'Direct model evidence: this signal is allowed to directly contribute to one or more BridgePoint opportunity models.';
    }
    if (normalized.contains('VERIFIED_OPPORTUNITY')) {
      return 'Verified opportunity: the configured evidence gate passed. Human verification is still required before acting on material claims.';
    }
    if (normalized.contains('CORROBORATING_PATTERN')) {
      return 'Corroborating pattern: this supports the story around the property but does not replace direct evidence.';
    }
    if (normalized.contains('PRIVATE_CLAIM')) {
      return 'Private workflow data: visible because it belongs to this account’s authorized claims workspace.';
    }
    return 'Supporting context: useful for understanding timing and property history, but not necessarily direct model evidence.';
  }

  String _confidenceMeaning(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) {
      return 'No numeric confidence was returned for this event. Read the source, match method, support level, and limitation instead.';
    }
    final normalized = number <= 1 ? number * 100 : number;
    if (normalized >= 90) {
      return 'Very strong source/match confidence. This still does not mean a 90% chance of damage or a 90% chance of a sale.';
    }
    if (normalized >= 75) {
      return 'Strong source/match confidence, but the event should still be read together with its match method and limitation.';
    }
    if (normalized >= 50) {
      return 'Moderate confidence. Treat this as useful context that deserves verification before customer-facing use.';
    }
    return 'Lower confidence. Use this mainly as a lead for further checking, not as a fact to repeat externally.';
  }

  String _matchMeaning(dynamic raw) {
    final match = _text(raw, 'Property record link');
    final upper = match.toUpperCase();
    if (upper.contains('AREA')) {
      return '$match — matched by geographic area, not necessarily to the exact structure.';
    }
    if (upper.contains('ADDRESS')) {
      return '$match — matched through address/property identity information.';
    }
    if (upper.contains('PARCEL')) {
      return '$match — matched through parcel/property identity information.';
    }
    if (upper.contains('PROPERTY_RECORD_LINK')) {
      return 'Property record link — BridgePoint linked the source observation to the canonical property record.';
    }
    return '$match — the method BridgePoint used to associate this event with the property.';
  }

  String? _sourceUrl(Map<String, dynamic> item) {
    final evidence = _map(item['evidence_summary']);
    for (final value in [
      item['source_url'],
      item['url'],
      evidence['source_url'],
      evidence['url'],
      evidence['record_url'],
    ]) {
      final raw = _text(value, '');
      final uri = Uri.tryParse(raw);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        return raw;
      }
    }
    return null;
  }

  List<String> _modelUses(Map<String, dynamic> item) {
    final value = item['model_uses'];
    if (value is List) {
      return value
          .map((entry) => _text(entry, ''))
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final items = _rows(payload, const ['timeline']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.timeline_rounded, color: _cyan),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Property DNA',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text(
                    'Tap any event to see what it means, how BridgePoint matched it, how confident the match is, and what it does not prove.',
                    style: TextStyle(color: _muted, fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
            Chip(label: Text('${items.length} events')),
          ],
        ),
        const SizedBox(height: 10),
        _legend(),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _notice('No timeline events are available for this property yet.', _cyan)
        else
          ...items.map((item) => _event(context, item)),
        if (_text(payload['explanation'], '').isNotEmpty) ...[
          const SizedBox(height: 4),
          _notice(_text(payload['explanation']), _cyan),
        ],
      ],
    );
  }

  Widget _legend() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _cyan.withValues(alpha: .14)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOW TO READ THIS TIMELINE',
                style: TextStyle(
                    color: _cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .45)),
            SizedBox(height: 7),
            Text(
              'Signal = one source observation.  Pattern = multiple observations that line up.  Verified opportunity = the evidence gate passed for prioritization.  Confidence describes the source/match quality — it is not the probability that a property is damaged or that a sale will happen.',
              style: TextStyle(color: _muted, fontSize: 11.5, height: 1.45),
            ),
          ],
        ),
      );

  Widget _event(BuildContext context, Map<String, dynamic> item) {
    final type = _text(item['timeline_type'], 'SIGNAL');
    final support = _text(item['support_level'], type);
    final color = _color(type);
    final url = _sourceUrl(item);
    final models = _modelUses(item);
    final evidence = _map(item['evidence_summary']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: _panel,
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .11),
            child: Icon(_icon(type), color: color, size: 18),
          ),
          title: Text(_text(item['title'], type),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_time(item['timeline_at'])} • ${_text(item['source_label'], 'Source unavailable')}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _badge(_label(type), color),
                    _badge(_label(support), _cyan),
                    if (item['confidence'] != null)
                      _badge('Confidence ${_percent(item['confidence'])}', _green),
                  ],
                ),
              ],
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _section('What happened',
                _text(item['description'], 'No description was returned for this event.')),
            _section('What this type means', _typeMeaning(type)),
            _section('Why it matters',
                _text(item['why_it_matters'], 'This adds dated context to the property record and should be read together with the source and matching method.')),
            _section('Evidence level', _supportMeaning(support)),
            _section('How BridgePoint matched it', _matchMeaning(item['match_method'])),
            _section('How to read confidence', _confidenceMeaning(item['confidence'])),
            if (models.isNotEmpty)
              _section('Models that can use this signal',
                  models.map(_label).join(', ')),
            if (evidence.isNotEmpty)
              _evidenceSummary(evidence),
            _section(
              'What this does NOT prove',
              _text(item['limitations'],
                  'This event should not be treated as proof of current physical condition, guaranteed damage, a guaranteed claim, or a guaranteed sale without independent verification.'),
              color: _amber,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item['severity'] != null)
                  _badge('Severity ${item['severity']}', color),
                if (item['stage'] != null)
                  _badge('Stage ${_label(_text(item['stage']))}', _cyan),
                if (_text(item['provider'], '').isNotEmpty)
                  _badge('Provider ${_text(item['provider'])}', _cyan),
              ],
            ),
            if (url != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open source record'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _evidenceSummary(Map<String, dynamic> evidence) {
    final fields = <MapEntry<String, dynamic>>[];
    for (final key in const [
      'provider',
      'source',
      'matching_precision',
      'storage_mode',
      'event_type',
      'event_id',
      'record_id',
      'observed_at',
    ]) {
      final value = evidence[key];
      if (_text(value, '').isNotEmpty) fields.add(MapEntry(key, value));
    }
    if (fields.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOURCE DETAILS',
              style: TextStyle(
                  color: _cyan,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4)),
          const SizedBox(height: 6),
          ...fields.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_label(entry.key)}: ${_text(entry.value)}',
                  style: const TextStyle(
                      color: _muted, fontSize: 11.5, height: 1.35),
                ),
              )),
        ],
      ),
    );
  }

  Widget _section(String title, String body, {Color color = _cyan}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4)),
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(fontSize: 12.5, height: 1.45)),
          ],
        ),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Widget _notice(String text, Color color) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: .17)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: _muted, fontSize: 11.5, height: 1.45)),
            ),
          ],
        ),
      );
}
