import 'package:flutter/material.dart';

const _bpCyan = Color(0xFF48E1FF);
const _bpGreen = Color(0xFF45E6A6);
const _bpAmber = Color(0xFFFFC95E);
const _bpRed = Color(0xFFFF6B6B);
const _bpMuted = Color(0xFFB5C6D9);
const _bpPanel = Color(0xFF0E2035);

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _rows(dynamic value, [List<String>? keys]) {
  if (value is List) {
    return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }
  if (value is Map) {
    for (final key in keys ?? const ['items', 'rows', 'results']) {
      if (value[key] is List) return _rows(value[key]);
    }
  }
  return const [];
}

String _labelKey(String key) => key
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _text(dynamic value, [String fallback = '—']) {
  if (value == null) return fallback;
  final raw = '$value'.trim();
  return raw.isEmpty || raw == 'null' ? fallback : raw;
}

String _time(dynamic value) {
  final raw = _text(value, 'Unknown time');
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _money(dynamic value) {
  final number = value is num ? value : num.tryParse('$value');
  if (number == null) return _text(value);
  final whole = number.round().toString();
  final chunks = <String>[];
  for (var end = whole.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, whole.length);
    chunks.insert(0, whole.substring(start, end));
  }
  return '\$${chunks.join(',')}';
}

String _percent(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) return _text(value);
  final normalized = number <= 1 ? number * 100 : number;
  return '${normalized.toStringAsFixed(normalized >= 10 ? 0 : 1)}%';
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.color = _bpCyan});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 112, maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .17)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: .45)),
          const SizedBox(height: 3),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.color = _bpAmber, this.icon = Icons.info_outline_rounded});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: .17)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: _bpMuted, fontSize: 11.5, height: 1.45))),
        ]),
      );
}

Widget _responsiveHeading({
  required IconData icon,
  required Color color,
  required String title,
  required Widget trailing,
  String? subtitle,
}) {
  return LayoutBuilder(builder: (context, constraints) {
    final heading = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: _bpMuted, fontSize: 11.5)),
          ],
        ]),
      ),
    ]);
    if (constraints.maxWidth < 400) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 6), trailing]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: heading), const SizedBox(width: 8), trailing]);
  });
}

class BridgePointPropertyOverviewV2 extends StatelessWidget {
  const BridgePointPropertyOverviewV2({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    if (payload['locked'] == true) {
      return const _Notice(
        'This property exists in BridgePoint, but the state is outside this account’s active geography entitlement.',
        color: _bpAmber,
        icon: Icons.lock_outline_rounded,
      );
    }
    final property = _map(payload['property']);
    final intelligence = _map(payload['intelligence']);
    final opportunities = _rows(intelligence, const ['opportunities']);
    if (property.isEmpty) return const _Notice('No canonical property detail was returned for this record.', color: _bpRed);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        color: _bpPanel,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.badge_outlined, color: _bpCyan),
              SizedBox(width: 8),
              Expanded(child: Text('Canonical identity', style: TextStyle(fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Metric('Property type', _text(property['property_type'] ?? property['land_use_description'])),
              _Metric('Parcel', _text(property['parcel_number'])),
              _Metric('Assessor account', _text(property['assessor_account_number'])),
              _Metric('Year built', _text(property['year_built'])),
              _Metric('Buildings', _text(property['building_count'])),
              _Metric('Assessed value', _money(property['assessed_total_value']), color: _bpGreen),
              _Metric('Market value', _money(property['market_total_value']), color: _bpGreen),
              _Metric('Canonical confidence', _percent(property['canonical_confidence'])),
            ]),
            const SizedBox(height: 10),
            Text(
              [property['full_address'], property['municipality'], property['county'], property['state_code'], property['postal_code']]
                  .where((value) => value != null && '$value'.trim().isNotEmpty)
                  .join(' • '),
              style: const TextStyle(color: _bpMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            Text('Property record updated ${_time(property['updated_at'])}', style: const TextStyle(color: _bpMuted, fontSize: 11)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      _responsiveHeading(
        icon: Icons.bolt_rounded,
        color: _bpAmber,
        title: 'Why Now / verified opportunities',
        trailing: Chip(label: Text('${opportunities.length} verified')),
      ),
      const SizedBox(height: 8),
      if (opportunities.isEmpty)
        const _Notice(
          'No package-safe verified opportunity currently qualifies for this property. BridgePoint does not turn missing evidence into a fake lead or zero score.',
          color: _bpCyan,
        )
      else
        ...opportunities.map((opportunity) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: _bpPanel,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.bolt_rounded, color: _bpAmber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_text(opportunity['title'], 'Verified opportunity'), style: const TextStyle(fontWeight: FontWeight.w900))),
                  const SizedBox(width: 8),
                  Text(_text(opportunity['score']), style: const TextStyle(color: _bpCyan, fontSize: 21, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  Chip(label: Text(_text(opportunity['priority'], 'priority unavailable'))),
                  Chip(label: Text('${opportunity['direct_signal_count'] ?? 0} direct signals')),
                  Chip(label: Text('${opportunity['direct_source_count'] ?? 0} direct sources')),
                  Chip(label: Text('${opportunity['independent_evidence_families'] ?? 0} evidence families')),
                  Chip(label: Text('${opportunity['confidence_percent'] ?? '—'}% confidence')),
                ]),
                const SizedBox(height: 7),
                Text(_text(opportunity['why_now'], 'No Why Now explanation returned.'), style: const TextStyle(fontSize: 12.5, height: 1.45)),
                if (_text(opportunity['recommended_action'], '').isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text('Next best action: ${opportunity['recommended_action']}', style: const TextStyle(color: _bpCyan, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ],
                const SizedBox(height: 7),
                Text('Latest direct evidence: ${_time(opportunity['latest_evidence_at'])}', style: const TextStyle(color: _bpMuted, fontSize: 11)),
              ]),
            ),
          ),
        )),
      const SizedBox(height: 4),
      const _Notice(
        'Verified opportunity means BridgePoint’s evidence gate passed. It is still a prioritization/review candidate—not confirmed damage, a guaranteed project, or a guaranteed sale.',
      ),
    ]);
  }
}

class BridgePointPropertyTimelineV2 extends StatelessWidget {
  const BridgePointPropertyTimelineV2({super.key, required this.payload});
  final Map<String, dynamic> payload;

  Color _color(String type) => switch (type.toUpperCase()) {
        'OPPORTUNITY' => _bpGreen,
        'PATTERN' => _bpAmber,
        'CLAIM' => _bpRed,
        'NOTE' => _bpCyan,
        _ => _bpCyan,
      };

  IconData _icon(String type) => switch (type.toUpperCase()) {
        'OPPORTUNITY' => Icons.bolt_rounded,
        'PATTERN' => Icons.account_tree_outlined,
        'CLAIM' => Icons.assignment_outlined,
        'NOTE' => Icons.sticky_note_2_outlined,
        _ => Icons.radar_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final items = _rows(payload, const ['timeline']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _responsiveHeading(
        icon: Icons.timeline_rounded,
        color: _bpCyan,
        title: 'Property DNA',
        subtitle: 'Chronological evidence story: signals, patterns, verified opportunities, your notes and authorized claim events.',
        trailing: Chip(label: Text('${items.length} events')),
      ),
      const SizedBox(height: 10),
      if (items.isEmpty)
        const _Notice('No timeline events are available for this property yet.', color: _bpCyan)
      else
        ...items.map((item) {
          final type = _text(item['timeline_type'], 'SIGNAL');
          final color = _color(type);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: _bpPanel,
              child: ExpansionTile(
                leading: CircleAvatar(backgroundColor: color.withValues(alpha: .11), child: Icon(_icon(type), color: color, size: 18)),
                title: Text(_text(item['title'], type), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${_time(item['timeline_at'])} • ${_text(item['source_label'], 'source unavailable')} • ${_text(item['support_level'], type)}',
                  style: const TextStyle(color: _bpMuted, fontSize: 11),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text(_text(item['description'], 'No description returned.'), style: const TextStyle(fontSize: 12.5, height: 1.45))),
                  if (_text(item['why_it_matters'], '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: Text('Why it matters: ${item['why_it_matters']}', style: const TextStyle(color: _bpCyan, fontSize: 11.5, height: 1.4))),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    if (item['confidence'] != null) Chip(label: Text('Confidence ${_percent(item['confidence'])}')),
                    if (item['match_method'] != null) Chip(label: Text(_text(item['match_method']))),
                    if (item['severity'] != null) Chip(label: Text('Severity ${item['severity']}')),
                    if (item['stage'] != null) Chip(label: Text(_text(item['stage']))),
                  ]),
                  if (_text(item['limitations'], '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: Text('Limitation: ${item['limitations']}', style: const TextStyle(color: _bpAmber, fontSize: 11.5, height: 1.4))),
                  ],
                ],
              ),
            ),
          );
        }),
      if (_text(payload['explanation'], '').isNotEmpty) _Notice(_text(payload['explanation']), color: _bpCyan),
    ]);
  }
}

class BridgePointClimateProfileV2 extends StatelessWidget {
  const BridgePointClimateProfileV2({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    if (payload['available'] == false || payload.isEmpty) return const _Notice('Climate / peril intelligence is unavailable for this account or property.', color: _bpCyan);
    final hazards = _map(payload['observed_hazards']);
    final structural = _map(payload['structural_sensitivity']);
    final coverage = _map(payload['coverage']);
    final future = _map(payload['future_scenario']);
    return Card(
      color: _bpPanel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.thermostat_rounded, color: _bpAmber),
            SizedBox(width: 8),
            Expanded(child: Text('Climate / peril profile', style: TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Metric('Observed signals', _text(coverage['observed_signal_count'], '0'), color: _bpAmber),
            _Metric('Structural screen', _text(structural['screening_score']), color: _bpAmber),
            _Metric('Building age', '${_text(structural['building_age_years'])} years'),
            _Metric('History', _text(coverage['historical_hazard_evidence'])),
          ]),
          const SizedBox(height: 10),
          if (hazards.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: hazards.entries.map((entry) {
              final hazard = _map(entry.value);
              final observed = '${hazard['coverage_status']}' == 'OBSERVED_HISTORY_AVAILABLE';
              return Container(
                constraints: const BoxConstraints(minWidth: 150, maxWidth: 205),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (observed ? _bpAmber : _bpCyan).withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (observed ? _bpAmber : _bpCyan).withValues(alpha: .14)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_labelKey(entry.key), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                  const SizedBox(height: 5),
                  Text(
                    observed ? 'Observed exposure ${_text(hazard['observed_exposure_score'])} • ${hazard['recurrence_count'] ?? 0} observations' : 'No property-level observations yet',
                    style: const TextStyle(color: _bpMuted, fontSize: 13, height: 1.35),
                  ),
                  if (observed) Text('Latest ${_time(hazard['latest_observed_at'])}', style: const TextStyle(color: _bpMuted, fontSize: 8)),
                ]),
              );
            }).toList()),
          const SizedBox(height: 10),
          _Notice(_text(structural['interpretation'], 'Asset sensitivity screening is not an engineering condition assessment.')),
          const SizedBox(height: 8),
          _Notice(
            future['status'] == 'PROJECTION_BINDING_REQUIRED'
                ? 'Future climate projection is not yet spatially bound to this property. BridgePoint will not invent future scenario risk from historical observations alone.'
                : _text(future['reason'], 'Future scenario status unavailable.'),
            color: _bpCyan,
          ),
        ]),
      ),
    );
  }
}

class BridgePointTwinSummaryV2 extends StatelessWidget {
  const BridgePointTwinSummaryV2({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    if (payload['available'] == false || payload.isEmpty) return const _Notice('Digital Twin summary is unavailable for this account or property.', color: _bpCyan);
    final readiness = _map(payload['simulation_readiness']);
    return Card(
      color: _bpPanel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.view_in_ar_rounded, color: _bpCyan),
            SizedBox(width: 8),
            Expanded(child: Text('Digital Twin fidelity', style: TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Metric('Fidelity', _text(payload['fidelity_level'], 'L0_PROPERTY_SHELL')),
            _Metric('Twin status', _text(payload['twin_status'] ?? payload['status'])),
            _Metric('Confidence', _percent(payload['overall_confidence'])),
            _Metric('Exact replica', payload['exact_replica_claim_allowed'] == true ? 'Allowed' : 'No', color: payload['exact_replica_claim_allowed'] == true ? _bpGreen : _bpAmber),
          ]),
          const SizedBox(height: 10),
          const _Notice(
            'L0 property shell = footprint/property shell. L1 building massing = schematic building massing. Higher L2/L3/L4 fidelity requires stronger lawful evidence such as high-resolution LiDAR/drone mesh, semantic BIM/blueprints, materials/envelope data and sensor bindings. Low-fidelity geometry is never labeled an exact replica.',
            color: _bpCyan,
          ),
          if (readiness.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Scenario readiness', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            ...readiness.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.science_outlined, size: 15, color: _bpCyan),
                const SizedBox(width: 7),
                Expanded(child: Text('${_labelKey(entry.key)}: ${entry.value}', style: const TextStyle(color: _bpMuted, fontSize: 11.5, height: 1.35))),
              ]),
            )),
          ],
        ]),
      ),
    );
  }
}

class BridgePointPermitContextV2 extends StatelessWidget {
  const BridgePointPermitContextV2({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    if (payload['available'] == false) return const _Notice('Permit context is unavailable because the property municipality could not be resolved.', color: _bpCyan);
    final rows = _rows(payload, const ['rows']);
    return Card(
      color: _bpPanel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.description_outlined, color: _bpAmber),
            SizedBox(width: 8),
            Expanded(child: Text('Permit / municipal context', style: TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          const _Notice('This current permit feed is municipality/year context, not a property-specific permit claim. Property-specific permit sources can appear separately in the property timeline when matched.'),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text('No municipal permit context returned.', style: TextStyle(color: _bpMuted, fontSize: 11.5))
          else
            ...rows.take(12).map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined, color: _bpCyan),
                title: Text('${row['report_year'] ?? 'Year'} • ${row['municipality'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                subtitle: Text(
                  'Total units ${row['total_units'] ?? '—'} • 1-unit ${row['one_unit'] ?? '—'} • 2-unit ${row['two_unit'] ?? '—'} • 3–4 unit ${row['three_four_units'] ?? '—'} • 5+ ${row['five_plus_units'] ?? '—'} • demolitions ${row['demolitions'] ?? '—'}',
                  style: const TextStyle(color: _bpMuted, fontSize: 11),
                ),
              ),
            )),
        ]),
      ),
    );
  }
}

class BridgePointMediaHistoryV2 extends StatelessWidget {
  const BridgePointMediaHistoryV2({super.key, required this.payload});
  final Map<String, dynamic> payload;

  String? _url(Map<String, dynamic> item) {
    for (final key in const ['media_url', 'thumbnail_url', 'url', 'image_url', 'preview_url']) {
      final value = _text(item[key], '');
      if (value.startsWith('http://') || value.startsWith('https://')) return value;
    }
    return null;
  }

  Widget _imageCard(Map<String, dynamic> item) {
    final url = _url(item);
    final label = _text(item['display_label'] ?? item['media_type'], 'Property media');
    return Card(
      color: _bpPanel,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF081625), child: Center(child: Icon(Icons.broken_image_outlined, color: _bpMuted))),
                ),
              ),
            )
          else
            const AspectRatio(
              aspectRatio: 16 / 10,
              child: ColoredBox(color: Color(0xFF081625), child: Center(child: Icon(Icons.image_not_supported_outlined, color: _bpMuted))),
            ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
          const SizedBox(height: 3),
          Text(
            '${_text(item['source_name'] ?? item['provider'], 'Source unavailable')} • ${_time(item['captured_at'] ?? item['observed_at'] ?? item['capture_date'])}',
            style: const TextStyle(color: _bpMuted, fontSize: 11),
          ),
          if (_text(item['license_note'], '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(_text(item['license_note']), style: const TextStyle(color: _bpMuted, fontSize: 8)),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _rows(payload, const ['items']);
    final history = _rows(payload['aerial_history']);
    final primary = _map(payload['primary']);
    final ordered = <Map<String, dynamic>>[
      if (primary.isNotEmpty) primary,
      ...items.where((item) => primary.isEmpty || item.toString() != primary.toString()),
    ];
    return Card(
      color: _bpPanel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _responsiveHeading(
            icon: Icons.photo_library_outlined,
            color: _bpCyan,
            title: 'Imagery / media history',
            trailing: Chip(label: Text('${items.length} current • ${history.length} history')),
          ),
          const SizedBox(height: 8),
          if (ordered.isEmpty && history.isEmpty)
            _Notice(_text(payload['display_message'], 'Property imagery is not available yet.'), color: _bpCyan)
          else ...[
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 560 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
              final all = [...ordered.take(8), ...history.take(8)];
              return Wrap(spacing: 8, runSpacing: 8, children: all.map((item) => SizedBox(width: width, child: _imageCard(item))).toList());
            }),
            const SizedBox(height: 8),
            Text(_text(payload['priority_rule'], 'Property media is ordered by BridgePoint source/usefulness policy.'), style: const TextStyle(color: _bpMuted, fontSize: 13, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}

class _CustomerSafeSummary extends StatelessWidget {
  const _CustomerSafeSummary({required this.value});
  final dynamic value;

  List<Map<String, dynamic>> _records(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map) {
      for (final key in const ['items', 'notes', 'watchlists', 'results', 'rows', 'events']) {
        if (raw[key] is List) return _records(raw[key]);
      }
    }
    return const [];
  }

  bool _technical(String key) {
    final k = key.toLowerCase();
    return k == 'metadata' || k == 'payload' || k == 'raw' || k == 'rpc' ||
        k.endsWith('_id') || k.contains('internal') || k.contains('secret') ||
        k.contains('token') || k.contains('version');
  }

  String _title(Map<String, dynamic> row) {
    for (final key in const ['title', 'watchlist_name', 'name', 'note_text', 'label', 'headline', 'address']) {
      final text = '${row[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return 'BridgePoint record';
  }

  String _subtitle(Map<String, dynamic> row) {
    final parts = <String>[];
    for (final key in const ['status', 'description', 'summary', 'created_at', 'follow_up_at', 'updated_at']) {
      final text = '${row[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') parts.add(text);
      if (parts.length == 2) break;
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final records = _records(value);
    if (records.isNotEmpty) {
      return Column(
        children: records.take(25).map((row) {
          final subtitle = _subtitle(row);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline_rounded, color: _bpCyan, size: 18),
            title: Text(_title(row), maxLines: 3, overflow: TextOverflow.ellipsis),
            subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _bpMuted, fontSize: 11.5)),
          );
        }).toList(),
      );
    }
    if (value is Map) {
      final entries = (value as Map).entries
          .where((entry) => entry.value is! Map && entry.value is! List && !_technical('${entry.key}'))
          .take(16)
          .toList();
      if (entries.isEmpty) {
        return const Text('No customer-facing records are available yet.', style: TextStyle(color: _bpMuted));
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.map((entry) => _Metric(_labelKey('${entry.key}'), _text(entry.value))).toList(),
      );
    }
    return Text(_text(value, 'No customer-facing records are available yet.'),
        style: const TextStyle(color: _bpMuted));
  }
}

class BridgePointGenericWorkspaceSectionV2 extends StatelessWidget {
  const BridgePointGenericWorkspaceSectionV2({super.key, required this.title, required this.payload, required this.icon});
  final String title;
  final dynamic payload;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        color: _bpPanel,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(icon, color: _bpCyan), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 9),
            _CustomerSafeSummary(value: payload),
          ]),
        ),
      );
}
