import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerOverviewV2 extends StatefulWidget {
  const BridgePointOwnerOverviewV2({super.key});

  @override
  State<BridgePointOwnerOverviewV2> createState() => _BridgePointOwnerOverviewV2State();
}

class _BridgePointOwnerOverviewV2State extends State<BridgePointOwnerOverviewV2> {
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  late Future<List<dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'rpc': rpc, 'error': '$e'};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_owner_expansion_status_v736'),
        _safe('bridgepoint_source_health_v86'),
        _safe('bridgepoint_us_intelligence_coverage_v755'),
        _safe('bridgepoint_owner_global_expansion_status_v721', {'p_limit': 120}),
        _safe('bridgepoint_flutter_national_coverage_v345'),
        _safe('bridgepoint_twin_ingestion_requirements_v509'),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const ['items', 'sources', 'rows', 'states', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    final n = _int(value);
    if (n < 0) return '—';
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _refresh() => setState(() => _request = _load());

  void _showDetail(String title, dynamic payload) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Expanded(child: _JsonFriendlyView(payload: payload)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const [];
        dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
        final expansion = _map(at(0));
        final sourcesPayload = _map(at(1));
        final coverage = _map(at(2));
        final globalRows = _rows(at(3));
        final national = _map(at(4));
        final twin = _map(at(5));
        final us = _map(expansion['us']);
        final physical = _map(expansion['physical']);
        final sourceSummary = _map(sourcesPayload['summary']);
        final sourceRows = _rows(sourcesPayload['sources']);

        final totalIngested = sourceRows.fold<int>(0, (sum, row) => sum + _int(row['total_records_ingested']));
        final insertedLastRuns = sourceRows.fold<int>(0, (sum, row) => sum + _int(row['last_run_records_inserted']));
        final states = <String>{};
        for (final row in sourceRows) {
          final state = '${row['state_code'] ?? ''}'.trim();
          if (state.isNotEmpty) states.add(state);
        }

        final cards = <_OwnerMetricData>[
          _OwnerMetricData('ACTIVE PROPERTIES', _number(coverage['active_properties'] ?? national['active_properties']), 'Production property universe', Icons.home_work_rounded, _cyan, coverage),
          _OwnerMetricData('US JURISDICTIONS', _number(us['jurisdictions']), '${_number(us['live'])} live • ${_number(us['working'])} working', Icons.public_rounded, _blue, expansion),
          _OwnerMetricData('REGISTERED SOURCES', _number(sourceSummary['registered']), '${_number(sourceSummary['healthy'])} healthy • ${_number(sourceSummary['stale'])} stale • ${_number(sourceSummary['failing'])} failing', Icons.hub_rounded, _green, sourcesPayload),
          _OwnerMetricData('SOURCE RECORDS INGESTED', _number(totalIngested), '${_number(insertedLastRuns)} inserted in latest source runs', Icons.download_done_rounded, _amber, sourcesPayload),
          _OwnerMetricData('STATES WITH SOURCES', _number(states.length), 'Distinct state-coded source coverage visible now', Icons.map_outlined, _cyan, sourceRows),
          _OwnerMetricData('BUILDING GEOMETRY', _number(us['building_geometry_rows']), '${_number(us['building_geometry_states'])} states • ${_number(us['matched_buildings'])} property-matched', Icons.view_in_ar_rounded, _blue, expansion),
          _OwnerMetricData('CT 2D BUILDINGS', _number(physical['ct_2d_rows']), '2023 Connecticut 2D building source rows', Icons.layers_rounded, _green, expansion),
          _OwnerMetricData('CT 3D BUILDINGS', _number(physical['ct_3d_rows']), '2023 Connecticut 3D building source rows', Icons.threed_rotation_rounded, _amber, expansion),
          _OwnerMetricData('DIGITAL TWINS', _number(physical['digital_twins']), '${_number(physical['us_digital_twins'])} U.S. twins materialized', Icons.account_tree_rounded, _cyan, expansion),
          _OwnerMetricData('INTELLIGENCE EVALUATIONS', _number(coverage['evaluation_receipts']), '${_number(coverage['scored'])} scored • ${_number(coverage['scoring_pending'])} pending', Icons.analytics_rounded, _blue, coverage),
          _OwnerMetricData('OPEN EXPANSION REQUESTS', _number(globalRows.where((row) => '${row['request_status'] ?? ''}'.toUpperCase() != 'LIVE').length), '${globalRows.length} expansion rows returned', Icons.travel_explore_rounded, _green, globalRows),
          _OwnerMetricData('TWIN INGESTION', twin['complete'] == true ? 'READY' : 'CHECK', 'Open to inspect twin/source requirements', Icons.architecture_rounded, _amber, twin),
        ];

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BridgePoint Owner Backend', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                        SizedBox(height: 5),
                        Text('Live production counts for properties, sources, ingestion, states, expansion, scoring, 2D/3D building geometry and digital twins.', style: TextStyle(color: _muted, height: 1.45)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(onPressed: snapshot.connectionState == ConnectionState.waiting ? null : _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh backend counts'),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final columns = c.maxWidth >= 1150 ? 4 : c.maxWidth >= 760 ? 3 : c.maxWidth >= 500 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final card in cards)
                      SizedBox(width: width, child: _OwnerMetricCard(data: card, onTap: () => _showDetail(card.label, card.payload))),
                  ],
                );
              }),
              const SizedBox(height: 16),
              _OwnerSection(
                title: 'State / Expansion Activity',
                subtitle: 'Click any row to inspect status, compliance, build state and last activity.',
                icon: Icons.flag_outlined,
                child: globalRows.isEmpty
                    ? const Text('No expansion rows returned.', style: TextStyle(color: _muted))
                    : Column(
                        children: [
                          for (final row in globalRows.take(80))
                            InkWell(
                              onTap: () => _showDetail('${row['jurisdiction_name'] ?? row['jurisdiction_key'] ?? 'Expansion'}', row),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 7),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _soft.withValues(alpha: .65), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: .05))),
                                child: Row(children: [
                                  const Icon(Icons.location_on_outlined, color: _cyan, size: 18),
                                  const SizedBox(width: 9),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${row['jurisdiction_name'] ?? row['jurisdiction_key'] ?? 'Jurisdiction'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text('${row['country_code'] ?? ''}${row['region_code'] != null ? ' • ${row['region_code']}' : ''} • ${row['build_status'] ?? row['request_status'] ?? 'unknown'}', style: const TextStyle(color: _muted, fontSize: 10)),
                                  ])),
                                  Text('${row['verified_capabilities'] ?? 0}/${row['required_capabilities'] ?? 0}', style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded, color: _muted),
                                ]),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _OwnerSection(
                title: 'Source Health / Ingestion',
                subtitle: 'Highest-attention source rows first. Click to inspect ingestion totals, last runs and failures.',
                icon: Icons.monitor_heart_outlined,
                child: sourceRows.isEmpty
                    ? const Text('No source rows returned.', style: TextStyle(color: _muted))
                    : Column(
                        children: [
                          for (final row in sourceRows.take(100))
                            InkWell(
                              onTap: () => _showDetail('${row['source_name'] ?? row['source_code'] ?? 'Source'}', row),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 7),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _soft.withValues(alpha: .65), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: .05))),
                                child: Row(children: [
                                  Icon(row['consecutive_failures'] != null && _int(row['consecutive_failures']) > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: row['consecutive_failures'] != null && _int(row['consecutive_failures']) > 0 ? _red : _green, size: 18),
                                  const SizedBox(width: 9),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${row['source_name'] ?? row['source_code'] ?? 'Source'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text('${row['state_code'] ?? row['geographic_scope'] ?? 'national'} • ${row['source_category'] ?? ''} • ${row['health_status'] ?? 'unknown'}', style: const TextStyle(color: _muted, fontSize: 10)),
                                  ])),
                                  Text(_number(row['total_records_ingested']), style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded, color: _muted),
                                ]),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerMetricData {
  const _OwnerMetricData(this.label, this.value, this.detail, this.icon, this.color, this.payload);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final dynamic payload;
}

class _OwnerMetricCard extends StatelessWidget {
  const _OwnerMetricCard({required this.data, required this.onTap});
  final _OwnerMetricData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: _BridgePointOwnerOverviewV2State._panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: data.color.withValues(alpha: .15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 39, height: 39, decoration: BoxDecoration(color: data.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(data.icon, color: data.color, size: 20)),
              const Spacer(),
              const Icon(Icons.open_in_new_rounded, color: _BridgePointOwnerOverviewV2State._muted, size: 15),
            ]),
            const SizedBox(height: 13),
            Text(data.label, style: const TextStyle(color: _BridgePointOwnerOverviewV2State._muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(data.value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(data.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointOwnerOverviewV2State._muted, fontSize: 10, height: 1.35)),
          ]),
        ),
      );
}

class _OwnerSection extends StatelessWidget {
  const _OwnerSection({required this.title, required this.subtitle, required this.icon, required this.child});
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: _BridgePointOwnerOverviewV2State._panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .07))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _BridgePointOwnerOverviewV2State._cyan),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: _BridgePointOwnerOverviewV2State._muted, fontSize: 10)),
            ])),
          ]),
          const SizedBox(height: 13),
          child,
        ]),
      );
}

class _JsonFriendlyView extends StatelessWidget {
  const _JsonFriendlyView({required this.payload});
  final dynamic payload;

  @override
  Widget build(BuildContext context) {
    if (payload is List) {
      return ListView.separated(
        itemCount: (payload as List).length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) => _JsonFriendlyView(payload: (payload as List)[i]),
      );
    }
    if (payload is Map) {
      final entries = (payload as Map).entries.toList();
      return ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = entries[i];
          final complex = e.value is Map || e.value is List;
          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('${e.key}'.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: complex ? null : Text('${e.value}', style: const TextStyle(color: _BridgePointOwnerOverviewV2State._muted)),
            children: complex ? [SizedBox(height: 220, child: _JsonFriendlyView(payload: e.value))] : const [],
          );
        },
      );
    }
    return SelectableText('$payload');
  }
}
