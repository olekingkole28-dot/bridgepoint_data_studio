import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../v2/bridgepoint_chrome_v2.dart';
import '../v2/bridgepoint_map_weather_v2.dart';
import '../v2/bridgepoint_opportunities_v2.dart';
import '../v2/bridgepoint_properties_v2.dart';
import '../v2/bridgepoint_property_360_v2.dart';

class BridgePointHomeV2 extends StatefulWidget {
  const BridgePointHomeV2({super.key});

  @override
  State<BridgePointHomeV2> createState() => _BridgePointHomeV2State();
}

class _BridgePointHomeV2State extends State<BridgePointHomeV2> {
  static const _panel = Color(0xE80A192A);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _gold = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  late Future<List<dynamic>> _request;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _request = _load();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) setState(() => _request = _load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_dashboard', {'p_model_key': 'all', 'p_limit': 8}),
        _safe('bridgepoint_us_intelligence_coverage_v755'),
        _safe('bridgepoint_flutter_map_state_status_v838'),
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
      for (final key in const ['ranked_opportunities', 'opportunities', 'states', 'items', 'rows']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${b.toString()}';
  }

  void _open(String title, Widget page, {bool scroll = true}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: BridgePointMotionBackgroundV2(
            child: scroll
                ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: page)
                : Padding(padding: const EdgeInsets.all(8), child: SizedBox.expand(child: page)),
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
        final data = snapshot.data ?? const <dynamic>[];
        dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
        final dashboard = _map(at(0));
        final coverage = _map(at(1));
        final statesPayload = at(2);
        final states = _rows(statesPayload is Map ? statesPayload['states'] : statesPayload);
        final opportunities = _rows(dashboard);
        final activeProperties = coverage['active_properties'] ?? dashboard['property_count_estimate'];
        final activeOpportunities = dashboard['active_opportunities'] ?? opportunities.length;
        final propertyStates = states.where((row) => _int(row['canonical_property_count']) > 0).length;
        final opportunityStates = states.where((row) => _int(row['opportunity_count']) > 0).length;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF20A192A), Color(0xEE0B2138), Color(0xEA111630)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _cyan.withValues(alpha: .18)),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 34, offset: Offset(0, 16))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      BridgePointMarkV2(size: 48),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BRIDGEPOINT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                            Text('PROPERTY INTELLIGENCE', style: TextStyle(color: _cyan, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      _LivePill(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Know where to look next.',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.04, letterSpacing: -.6),
                  ),
                  const SizedBox(height: 9),
                  const ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 760),
                    child: Text(
                      'BridgePoint connects property records, weather, changes, imagery, risk and other evidence around the property—then helps you decide what deserves attention first.',
                      style: TextStyle(color: _muted, fontSize: 15, height: 1.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _open('Property Map & Weather', const BridgePointMapWeatherV2()),
                        icon: const Icon(Icons.public_rounded),
                        label: const Text('Open map'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _open('Properties', const BridgePointPropertiesV2()),
                        icon: const Icon(Icons.holiday_village_rounded),
                        label: const Text('Find a property'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _open('Opportunities', const BridgePointOpportunitiesV2()),
                        icon: const Icon(Icons.location_searching_rounded),
                        label: const Text('View opportunities'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (loading) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 620 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 10) / columns;
                final cards = [
                  _Metric('PROPERTY UNIVERSE', _number(activeProperties), 'Properties currently represented in the live foundation', Icons.home_work_outlined, _cyan),
                  _Metric('ACTIVE OPPORTUNITIES', _number(activeOpportunities), '${opportunities.length} highest-ranked examples loaded now', Icons.location_searching_rounded, _green),
                  _Metric('STATES WITH PROPERTY DATA', '$propertyStates', 'Property coverage is progressive; state depth varies', Icons.map_outlined, _blue),
                  _Metric('STATES WITH OPPORTUNITIES', '$opportunityStates', 'Only states with actual scored opportunity output count here', Icons.flag_outlined, _gold),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final card in cards) SizedBox(width: width, child: card)],
                );
              },
            ),
            const SizedBox(height: 14),
            _HowItWorks(
              onProperty: () => _open('Property Intelligence', const BridgePointProperty360V2()),
            ),
            const SizedBox(height: 14),
            _OpportunityPreview(rows: opportunities),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: _green, size: 19),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'BridgePoint is evidence-first. A score or signal helps prioritize review; it is not proof of property damage, claim coverage, legal status or a guaranteed outcome.',
                      style: TextStyle(color: _muted, fontSize: 12.2, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail, this.icon, this.color);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .17)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .04), blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .6)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(detail, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 12, height: 1.38)),
          ],
        ),
      );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.onProperty});
  final VoidCallback onProperty;

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.home_work_outlined, 'One property', 'BridgePoint resolves records around the same physical property.', _BridgePointHomeV2State._cyan),
      (Icons.fact_check_outlined, 'Evidence', 'Sources, dates and match confidence stay attached to what BridgePoint found.', _BridgePointHomeV2State._blue),
      (Icons.insights_outlined, 'Intelligence', 'Signals and patterns explain why something deserves attention.', _BridgePointHomeV2State._green),
      (Icons.arrow_circle_right_outlined, 'Action', 'Prioritize the visit, follow-up, claim review or investment research.', _BridgePointHomeV2State._gold),
    ];
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _BridgePointHomeV2State._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How BridgePoint thinks about a property', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text('The complicated backend stays underneath this simple flow.', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 12.2)),
            ])),
            TextButton.icon(onPressed: onProperty, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Open property view')),
          ]),
          const SizedBox(height: 13),
          LayoutBuilder(builder: (context, c) {
            final columns = c.maxWidth >= 850 ? 4 : c.maxWidth >= 500 ? 2 : 1;
            final width = (c.maxWidth - (columns - 1) * 9) / columns;
            return Wrap(spacing: 9, runSpacing: 9, children: [
              for (final step in steps)
                SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: step.$4.withValues(alpha: .07), borderRadius: BorderRadius.circular(14), border: Border.all(color: step.$4.withValues(alpha: .13))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(step.$1, color: step.$4),
                      const SizedBox(height: 8),
                      Text(step.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(step.$3, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11.8, height: 1.38)),
                    ]),
                  ),
                ),
            ]);
          }),
        ],
      ),
    );
  }
}

class _OpportunityPreview extends StatelessWidget {
  const _OpportunityPreview({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _BridgePointHomeV2State._green.withValues(alpha: .13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Highest-ranked examples right now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            const Text('A quick look at real ranked output—not every backend record.', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 12.2)),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text('BridgePoint is refreshing the opportunity feed.', style: TextStyle(color: _BridgePointHomeV2State._muted))
            else
              for (final row in rows.take(5))
                Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xAA112B45), borderRadius: BorderRadius.circular(13)),
                  child: Row(children: [
                    const Icon(Icons.location_searching_rounded, color: _BridgePointHomeV2State._green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${row['full_address'] ?? row['title'] ?? 'Property opportunity'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('${row['title'] ?? 'Opportunity'} • ${row['priority'] ?? 'ranked'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11.5)),
                    ])),
                    if (row['score'] != null) Text('${row['score']}', style: const TextStyle(color: _BridgePointHomeV2State._gold, fontWeight: FontWeight.w900)),
                  ]),
                ),
          ],
        ),
      );
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._green.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _BridgePointHomeV2State._green.withValues(alpha: .18)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, color: _BridgePointHomeV2State._green, size: 7),
          SizedBox(width: 5),
          Text('LIVE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
        ]),
      );
}
