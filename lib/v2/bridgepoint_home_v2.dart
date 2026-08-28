import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_chrome_v2.dart';
import 'bridgepoint_map_weather_v2.dart';
import 'bridgepoint_opportunities_v2.dart';
import 'bridgepoint_properties_v2.dart';
import 'bridgepoint_property_360_v2.dart';

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
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
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
        _safe('bridgepoint_public_system_pulse_v957'),
        _safe('bridgepoint_flutter_map_state_status_v838'),
        _safe('bridgepoint_owner_live_activity_v958'),
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

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  String _number(dynamic value) => _formatInt(_int(value));

  static String _formatInt(int n) {
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${b.toString()}';
  }

  String _pct(double value) {
    final decimals = value >= 10 ? 1 : 2;
    return '${value.toStringAsFixed(decimals)}%';
  }

  String _time(dynamic value) {
    final dt = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (dt == null) return '—';
    final h = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day} $h:$m $ap';
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
        final pulse = _map(at(1));
        final statesPayload = at(2);
        final owner = _map(at(3));
        final states = _rows(statesPayload is Map ? statesPayload['states'] : statesPayload);
        final opportunities = _rows(dashboard);
        final recentSignins = _rows(owner['recent_signins']);
        final regions = _rows(owner['signin_flow_regions_24h']);
        final isOwner = owner['available'] == true;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        final totalParcels = _int(pulse['total_parcels']);
        final nationalTarget = _int(pulse['national_target_parcels']);
        final parcelPct = _double(pulse['parcel_completion_pct']);
        final matchingDone = _int(pulse['matching_states_complete']);
        final matchingTotal = _int(pulse['matching_states_total']);
        final matchingPct = _double(pulse['matching_completion_pct']);
        final scored = _int(pulse['scored_properties']);
        final scoringPct = _double(pulse['scoring_coverage_pct']);
        final patterns = _int(pulse['detected_patterns']);
        final signals = _int(pulse['signals']);
        final activeOpportunities = _int(pulse['active_opportunities']);
        final registeredSources = _int(pulse['registered_sources']);
        final sourceRecords = _int(pulse['ingested_source_records']);
        final propertyStates = states.where((row) => _int(row['canonical_property_count']) > 0).length;
        final opportunityStates = states.where((row) => _int(row['opportunity_count']) > 0).length;

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
                  Row(
                    children: [
                      const BridgePointMarkV2(size: 48),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BRIDGEPOINT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                            Text('PROPERTY INTELLIGENCE', style: TextStyle(color: _cyan, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      const _LivePill(),
                      if (isOwner) ...[
                        const SizedBox(width: 7),
                        const _OwnerPill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Know where to look next.', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.04, letterSpacing: -.6)),
                  const SizedBox(height: 9),
                  const ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 820),
                    child: Text(
                      'BridgePoint is building and refreshing the property intelligence network live. The numbers below come straight from production Supabase and update every five seconds while you are on Home.',
                      style: TextStyle(color: _muted, fontSize: 15, height: 1.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      FilledButton.icon(onPressed: () => _open('Property Map & Weather', const BridgePointMapWeatherV2()), icon: const Icon(Icons.public_rounded), label: const Text('Open map')),
                      OutlinedButton.icon(onPressed: () => _open('Properties', const BridgePointPropertiesV2()), icon: const Icon(Icons.holiday_village_rounded), label: const Text('Find a property')),
                      OutlinedButton.icon(onPressed: () => _open('Opportunities', const BridgePointOpportunitiesV2()), icon: const Icon(Icons.location_searching_rounded), label: const Text('View opportunities')),
                    ],
                  ),
                ],
              ),
            ),
            if (loading) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(19), border: Border.all(color: _cyan.withValues(alpha: .15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Live nationwide build', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Watch production totals move as BridgePoint ingests, matches, scores and detects intelligence.', style: TextStyle(color: _muted, fontSize: 12.2)),
                  ])),
                  _RefreshBadge(updatedAt: pulse['updated_at']),
                ]),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, c) {
                  final columns = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 620 ? 2 : 1;
                  final width = (c.maxWidth - (columns - 1) * 10) / columns;
                  final cards = [
                    _ProgressCard(
                      label: 'PARCEL INGESTION',
                      count: totalParcels,
                      percent: parcelPct,
                      detail: '${_number(totalParcels)} of ${_number(nationalTarget)} strict U.S. parcel floor',
                      icon: Icons.home_work_outlined,
                      color: _cyan,
                    ),
                    _ProgressCard(
                      label: 'MATCHING',
                      valueText: '$matchingDone / $matchingTotal jurisdictions',
                      percent: matchingPct,
                      detail: 'Jurisdictions that cleared BridgePoint normalize/match quality gates',
                      icon: Icons.join_inner_rounded,
                      color: _blue,
                    ),
                    _ProgressCard(
                      label: 'SCORING COVERAGE',
                      count: scored,
                      percent: scoringPct,
                      detail: 'Scored properties as a share of parcels currently ingested',
                      icon: Icons.speed_rounded,
                      color: _green,
                    ),
                  ];
                  return Wrap(spacing: 10, runSpacing: 10, children: [for (final card in cards) SizedBox(width: width, child: card)]);
                }),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, c) {
                  final columns = c.maxWidth >= 1100 ? 5 : c.maxWidth >= 680 ? 3 : 2;
                  final width = (c.maxWidth - (columns - 1) * 8) / columns;
                  final counters = [
                    _CounterCard('SIGNALS', signals, Icons.bolt_rounded, _cyan),
                    _CounterCard('PATTERNS', patterns, Icons.hub_rounded, _blue),
                    _CounterCard('OPPORTUNITIES', activeOpportunities, Icons.location_searching_rounded, _green),
                    _CounterCard('SOURCES', registeredSources, Icons.dataset_linked_outlined, _gold),
                    _CounterCard('SOURCE RECORDS', sourceRecords, Icons.sync_alt_rounded, _cyan),
                  ];
                  return Wrap(spacing: 8, runSpacing: 8, children: [for (final card in counters) SizedBox(width: width, child: card)]);
                }),
                const SizedBox(height: 10),
                Text(
                  'Current footprint: $propertyStates states/DC with property data • $opportunityStates with opportunity output. Counts are live production totals; state depth varies while the national build continues.',
                  style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                ),
              ]),
            ),
            if (isOwner) ...[
              const SizedBox(height: 14),
              _OwnerActivityPanel(
                owner: owner,
                recentSignins: recentSignins,
                regions: regions,
                number: _number,
                time: _time,
              ),
            ],
            const SizedBox(height: 14),
            _HowItWorks(onProperty: () => _open('Property Intelligence', const BridgePointProperty360V2())),
            const SizedBox(height: 14),
            _OpportunityPreview(rows: opportunities),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .08))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.verified_user_outlined, color: _green, size: 19),
                SizedBox(width: 9),
                Expanded(child: Text('BridgePoint is evidence-first. A score or signal helps prioritize review; it is not proof of property damage, claim coverage, legal status or a guaranteed outcome.', style: TextStyle(color: _muted, fontSize: 12.2, height: 1.45))),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.label, required this.percent, required this.detail, required this.icon, required this.color, this.count, this.valueText});
  final String label;
  final int? count;
  final String? valueText;
  final double percent;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF10243A), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 21)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(999)), child: Text('${p >= 10 ? p.toStringAsFixed(1) : p.toStringAsFixed(2)}%', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11))),
        ]),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .6)),
        const SizedBox(height: 4),
        if (count != null)
          _RollingCount(value: count!, fontSize: 24)
        else
          Text(valueText ?? '—', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: p / 100, minHeight: 7, backgroundColor: Colors.white.withValues(alpha: .06), valueColor: AlwaysStoppedAnimation<Color>(color))),
        const SizedBox(height: 8),
        Text(detail, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11.3, height: 1.35)),
      ]),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xB30C1D31), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .07))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .5)),
          const SizedBox(height: 3),
          _RollingCount(value: value, fontSize: 18),
        ]),
      );
}

class _RollingCount extends StatefulWidget {
  const _RollingCount({required this.value, this.fontSize = 22});
  final int value;
  final double fontSize;

  @override
  State<_RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<_RollingCount> {
  late int _begin;

  @override
  void initState() {
    super.initState();
    _begin = widget.value;
  }

  @override
  void didUpdateWidget(covariant _RollingCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _begin = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: _begin.toDouble(), end: widget.value.toDouble()),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        onEnd: () => _begin = widget.value,
        builder: (context, value, _) => Text(_BridgePointHomeV2State._formatInt(value.round()), style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
      );
}

class _RefreshBadge extends StatelessWidget {
  const _RefreshBadge({required this.updatedAt});
  final dynamic updatedAt;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: _BridgePointHomeV2State._green.withValues(alpha: .08), borderRadius: BorderRadius.circular(999), border: Border.all(color: _BridgePointHomeV2State._green.withValues(alpha: .18))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.sync_rounded, color: _BridgePointHomeV2State._green, size: 13), SizedBox(width: 5), Text('AUTO • 5 SEC', style: TextStyle(color: _BridgePointHomeV2State._green, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .5))]),
      );
}

class _OwnerActivityPanel extends StatelessWidget {
  const _OwnerActivityPanel({required this.owner, required this.recentSignins, required this.regions, required this.number, required this.time});
  final Map<String, dynamic> owner;
  final List<Map<String, dynamic>> recentSignins;
  final List<Map<String, dynamic>> regions;
  final String Function(dynamic) number;
  final String Function(dynamic) time;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: _BridgePointHomeV2State._panel, borderRadius: BorderRadius.circular(19), border: Border.all(color: _BridgePointHomeV2State._gold.withValues(alpha: .18))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.admin_panel_settings_rounded, color: _BridgePointHomeV2State._gold, size: 21), SizedBox(width: 8), Expanded(child: Text('Owner-only live activity', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), _OwnerPill()]),
          const SizedBox(height: 4),
          const Text('Only your owner/admin account gets this section. Customer accounts never receive these user or sign-in details.', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 13),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _OwnerStat('TOTAL USERS', number(owner['total_users'])),
            _OwnerStat('ACTIVE 15M', number(owner['active_users_15m'])),
            _OwnerStat('SIGN-INS 24H', number(owner['signins_24h'])),
            _OwnerStat('SIGNUPS 24H', number(owner['signups_24h'])),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final stacked = c.maxWidth < 760;
            final signins = _OwnerListPanel(
              title: 'Recent sign-ins',
              child: recentSignins.isEmpty
                  ? const Text('No recent authenticated sign-ins returned.', style: TextStyle(color: _BridgePointHomeV2State._muted))
                  : Column(children: [for (final row in recentSignins.take(8)) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_outline_rounded, color: _BridgePointHomeV2State._gold), title: Text('${row['email'] ?? 'Account'}', maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(time(row['last_sign_in_at'])),)]),
            );
            final where = _OwnerListPanel(
              title: 'Coarse sign-in regions',
              child: regions.isEmpty
                  ? const Text('No coarse browser region telemetry returned.', style: TextStyle(color: _BridgePointHomeV2State._muted))
                  : Wrap(spacing: 7, runSpacing: 7, children: [for (final row in regions.take(10)) Chip(label: Text('${row['region_code'] ?? 'UNKNOWN'} • ${number(row['visitors'])}'))]),
            );
            return stacked ? Column(children: [signins, const SizedBox(height: 10), where]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: signins), const SizedBox(width: 10), Expanded(child: where)]);
          }),
          const SizedBox(height: 8),
          Text('${owner['geography_note'] ?? 'Region data is coarse telemetry, not precise GPS location.'}', style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10.5, height: 1.35)),
        ]),
      );
}

class _OwnerStat extends StatelessWidget {
  const _OwnerStat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: _BridgePointHomeV2State._gold.withValues(alpha: .06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _BridgePointHomeV2State._gold.withValues(alpha: .12))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _BridgePointHomeV2State._gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .5)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]));
}

class _OwnerListPanel extends StatelessWidget {
  const _OwnerListPanel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF10243A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .06))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), child]));
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
      decoration: BoxDecoration(color: _BridgePointHomeV2State._panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('How BridgePoint thinks about a property', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('The complicated backend stays underneath this simple flow.', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 12.2))])),
          TextButton.icon(onPressed: onProperty, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Open property view')),
        ]),
        const SizedBox(height: 13),
        LayoutBuilder(builder: (context, c) {
          final columns = c.maxWidth >= 900 ? 4 : c.maxWidth >= 520 ? 2 : 1;
          final width = (c.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(spacing: 8, runSpacing: 8, children: [for (final step in steps) SizedBox(width: width, child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: step.$4.withValues(alpha: .06), borderRadius: BorderRadius.circular(14), border: Border.all(color: step.$4.withValues(alpha: .14))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(step.$1, color: step.$4, size: 22), const SizedBox(height: 9), Text(step.$2, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(step.$3, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11.5, height: 1.35))])))]);
        }),
      ]),
    );
  }
}

class _OpportunityPreview extends StatelessWidget {
  const _OpportunityPreview({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: _BridgePointHomeV2State._panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('What deserves attention now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          const Text('A short preview, not another giant dashboard.', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 12.2)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('BridgePoint is loading prioritized opportunities.', style: TextStyle(color: _BridgePointHomeV2State._muted))
          else
            for (final row in rows.take(5))
              Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: const Color(0xFF10243A), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.location_searching_rounded, color: _BridgePointHomeV2State._green, size: 20),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${row['full_address'] ?? row['title'] ?? 'Property opportunity'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('${row['reason'] ?? row['explanation'] ?? 'Evidence-backed property intelligence'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11.2, height: 1.3)),
                  ])),
                ]),
              ),
        ]),
      );
}

class _LivePill extends StatelessWidget {
  const _LivePill();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: _BridgePointHomeV2State._green.withValues(alpha: .10), borderRadius: BorderRadius.circular(999), border: Border.all(color: _BridgePointHomeV2State._green.withValues(alpha: .24))), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: _BridgePointHomeV2State._green, size: 7), SizedBox(width: 5), Text('LIVE', style: TextStyle(color: _BridgePointHomeV2State._green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7))]));
}

class _OwnerPill extends StatelessWidget {
  const _OwnerPill();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: _BridgePointHomeV2State._gold.withValues(alpha: .09), borderRadius: BorderRadius.circular(999), border: Border.all(color: _BridgePointHomeV2State._gold.withValues(alpha: .18))), child: const Text('OWNER', style: TextStyle(color: _BridgePointHomeV2State._gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .6)));
}
