import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointGlobalIntelligenceV1 extends StatefulWidget {
  const BridgePointGlobalIntelligenceV1({super.key, required this.onOpenWorld});
  final VoidCallback onOpenWorld;

  @override
  State<BridgePointGlobalIntelligenceV1> createState() =>
      _BridgePointGlobalIntelligenceV1State();
}

class _BridgePointGlobalIntelligenceV1State
    extends State<BridgePointGlobalIntelligenceV1> {
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF0E2035);

  late Future<Map<String, dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> _load() async {
    final response = await Supabase.instance.client.functions.invoke(
      'bridgepoint-global-infrastructure-overview-v1',
      body: const <String, dynamic>{},
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Overview request failed (${response.status})');
    }
    final result = _map(response.data);
    if (result['ok'] != true) {
      throw Exception('${result['error'] ?? 'Global overview unavailable'}');
    }
    return result;
  }

  void _refresh() => setState(() => _request = _load());

  String _number(dynamic value) {
    if (value == null) return '—';
    final parsed = value is num
        ? value.round()
        : int.tryParse('$value'.replaceAll(',', ''));
    if (parsed == null) return '$value';
    final text = parsed.toString();
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) out.write(',');
      out.write(text[i]);
    }
    return out.toString();
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return 'Time unavailable';
    final d = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _label(dynamic value) => '$value'
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Widget _metric(String label, dynamic value, Color color, String note) =>
      Container(
        constraints: const BoxConstraints(minWidth: 145),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 7),
            Expanded(child: Text(label, style: const TextStyle(
              color: _muted, fontSize: 12, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 9),
          Text(_number(value), style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(note, style: const TextStyle(
            color: _muted, fontSize: 11, height: 1.35)),
        ]),
      );

  Widget _section(String title, String subtitle, Widget child) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xD9081929),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _cyan.withValues(alpha: .13)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Text(label, style: TextStyle(
          color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
      );

  Widget _eventCard(Map<String, dynamic> event, {bool signal = false}) {
    final metadata = _map(event['metadata']);
    final detailKeys = signal
        ? const ['severity', 'category', 'status', 'updated']
        : const ['mag', 'depth_km', 'place', 'alert_level', 'status', 'country'];
    final details = <String>[];
    for (final key in detailKeys) {
      final value = metadata[key];
      if (value != null && '$value'.trim().isNotEmpty) {
        details.add('${_label(key)}: $value');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071523),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: .17)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 7, runSpacing: 6, children: [
          _pill(_label(event['domain']), _blue),
          _pill(_label(event[signal ? 'signal_type' : 'event_type']), signal ? _amber : _cyan),
        ]),
        const SizedBox(height: 8),
        Text('${event['title'] ?? 'Public-source event'}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(details.join('  •  '),
              style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4)),
        ],
        const SizedBox(height: 7),
        Text('Observed: ${_date(event['observed_at'])}',
            style: const TextStyle(color: _green, fontSize: 11.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text('Source key: ${event['source_key'] ?? 'Unknown'}',
            style: const TextStyle(color: _muted, fontSize: 10.5)),
      ]),
    );
  }

  Widget _countryRow(Map<String, dynamic> country) {
    final sources = '${country['complete_sources'] ?? 0}/${country['source_count'] ?? 0}';
    final updated = _date(country['source_cache_updated_at'] ?? country['updated_at']);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF071523), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _pill('${country['country_code'] ?? '—'}', _cyan),
          const SizedBox(width: 8),
          Expanded(child: Text('${_number(country['active_canonical'])} canonical identities',
              style: const TextStyle(fontWeight: FontWeight.w800))),
          Text(sources, style: const TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        Text('${_number(country['with_boundary'])} boundary-linked  •  ${_number(country['building_footprints'])} building footprints',
            style: const TextStyle(color: _muted, fontSize: 11.5)),
        const SizedBox(height: 3),
        Text('Coverage record updated: $updated',
            style: const TextStyle(color: _muted, fontSize: 10.5)),
      ]),
    );
  }

  Widget _sourceRow(Map<String, dynamic> source) {
    final status = '${source['status'] ?? 'Unknown status'}';
    final discovered = _number(source['discovered_count']);
    final materialized = _number(source['materialized_count']);
    final scope = _label(source['scope']);
    final rights = _label(source['rights_class']);
    final mode = _label(source['ingest_mode']);
    final verified = _date(source['last_verified_at']);
    final hasRecords = (source['materialized_count'] is num)
        ? (source['materialized_count'] as num) > 0
        : int.tryParse('${source['materialized_count'] ?? '0'}')! > 0;
    final statusColor = hasRecords ? _green : _amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071523),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(
            '${source['source_name'] ?? source['source_key'] ?? 'Registered source'}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
          )),
          const SizedBox(width: 8),
          _pill(_label(status), statusColor),
        ]),
        const SizedBox(height: 6),
        Text('Authority: ${source['authority_name'] ?? 'Not specified'}',
            style: const TextStyle(color: _muted, fontSize: 11.5)),
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _pill(scope, _blue),
          _pill(rights, _cyan),
          _pill(mode, _amber),
        ]),
        const SizedBox(height: 7),
        Text('Discovered: $discovered  •  Materialized: $materialized',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
        Text('Last verified: $verified  •  Geometry: ${source['geometry_truth'] ?? 'unspecified'}',
            style: const TextStyle(color: _muted, fontSize: 10.5)),
        Text('Source key: ${source['source_key'] ?? 'Unknown'}',
            style: const TextStyle(color: _muted, fontSize: 10.5)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _request,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final payload = snapshot.data ?? const <String, dynamic>{};
          final progress = _map(payload['global_progress']);
          final summary = _map(payload['summary']);
          final countries = _rows(payload['countries']);
          final events = _rows(payload['recent_public_events']);
          final signals = _rows(payload['space_weather_signals']);
          final sourceRows = _rows(payload['infrastructure_sources']);
          final error = snapshot.error;

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF102B43), Color(0xFF0A1425)]),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: _cyan.withValues(alpha: .32)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 45, height: 45,
                    decoration: BoxDecoration(color: _cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.public_rounded, color: _cyan)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('GLOBAL INTELLIGENCE', style: TextStyle(color: _cyan, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                    SizedBox(height: 3),
                    Text('Infrastructure & public-source signals', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ])),
                  IconButton(tooltip: 'Refresh global overview', onPressed: loading ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded, color: _cyan)),
                ]),
                const SizedBox(height: 10),
                const Text('Connect BridgePoint property coverage with source-backed global events. Each record keeps its observation time and source identity.',
                    style: TextStyle(color: _muted, height: 1.45)),
                const SizedBox(height: 13),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(onPressed: widget.onOpenWorld, icon: const Icon(Icons.language_rounded), label: const Text('Open BridgePoint World')),
                  OutlinedButton.icon(onPressed: loading ? null : _refresh, icon: const Icon(Icons.sync_rounded), label: const Text('Refresh overview')),
                ]),
              ]),
            ),
            if (loading) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _red.withValues(alpha: .08), borderRadius: BorderRadius.circular(13), border: Border.all(color: _red.withValues(alpha: .25))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Global overview unavailable', style: TextStyle(color: _red, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('The endpoint must be deployed to this environment. Missing data is not replaced with sample numbers.',
                      style: TextStyle(color: _muted, height: 1.4)),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: loading ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded), label: const Text('Try again'))),
                ])),
            ],
            if (snapshot.hasData) ...[
              const SizedBox(height: 14),
              const Text('BRIDGEPOINT GLOBAL PROPERTY FOUNDATION', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const SizedBox(height: 9),
              Wrap(spacing: 9, runSpacing: 9, children: [
                _metric('Canonical identities', progress['worldwide_canonical_total'], _cyan, 'Global property identity layer'),
                _metric('Building footprints', progress['global_building_footprints'], _green, 'Footprints recorded in BridgePoint'),
                _metric('Materialized boundaries', progress['materialized_global_boundaries'], _blue, 'Boundary records, not assumed coverage'),
                _metric('Countries represented', progress['materialized_country_count'], _amber, 'Countries with materialized records'),
              ]),
              _section('Infrastructure source readiness',
                'Registered source status, rights class and materialized counts. A discovered or enabled source is not necessarily fully ingested or current.',
                sourceRows.isEmpty
                  ? const Text('No infrastructure source records were returned.', style: TextStyle(color: _muted))
                  : Column(children: sourceRows.take(12).map(_sourceRow).toList())),
              _section('Latest public-source events',
                'Recent earthquake, global-hazard and volcano records. These are records returned to this screen, not a claim of complete worldwide event coverage.',
                events.isEmpty
                  ? const Text('No unexpired public-source event records were returned.', style: TextStyle(color: _muted))
                  : Column(children: events.take(20).map((event) => _eventCard(event)).toList())),
              _section('Space-weather signals',
                'Official-source context with observation time and source key retained.',
                signals.isEmpty
                  ? const Text('No unexpired space-weather signals were returned.', style: TextStyle(color: _muted))
                  : Column(children: signals.take(10).map((event) => _eventCard(event, signal: true)).toList())),
              _section('Global country coverage',
                'Coverage varies by jurisdiction and metric. Canonical identities are distinct from boundary rows and building footprints.',
                countries.isEmpty
                  ? const Text('Country coverage is not available yet.', style: TextStyle(color: _muted))
                  : Column(children: countries.take(12).map(_countryRow).toList())),
              _section('Data trust & interpretation',
                'Observed records are evidence, not automatic conclusions. A missing or stale record does not prove an event, asset or activity is absent.',
                const Wrap(spacing: 7, runSpacing: 7, children: [
                  _TrustBadge(label: 'Source identity retained', color: _cyan),
                  _TrustBadge(label: 'Observation timestamps', color: _green),
                  _TrustBadge(label: 'No inferred certainty', color: _amber),
                  _TrustBadge(label: 'Public-source context', color: _blue),
                ])),
            ],
            const SizedBox(height: 14),
            Text('Overview generated: ${_date(payload['generated_at'])}  •  Events loaded: ${summary['recent_public_events_loaded'] ?? '—'}  •  Signals loaded: ${summary['space_weather_signals_loaded'] ?? '—'}',
                style: const TextStyle(color: _muted, fontSize: 10.5)),
          ]);
        },
      );
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: .24))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
  );
}