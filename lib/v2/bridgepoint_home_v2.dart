import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_chrome_v2.dart';
import 'bridgepoint_map_weather_v2.dart';
import 'bridgepoint_opportunities_v2.dart';
import 'bridgepoint_products_settings_v2.dart';
import 'bridgepoint_properties_v2.dart';

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
  static const _red = Color(0xFFFF7474);
  static const _muted = Color(0xFFB5C6D9);

  Timer? _timer;
  bool _loading = true;
  Map<String, dynamic> _pulse = const {};
  Map<String, dynamic> _owner = const {};
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _refresh(quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (!quiet && mounted) setState(() => _loading = true);
    Map<String, dynamic> pulse = const {};
    Map<String, dynamic> owner = const {};
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_public_system_pulse_v957',
      );
      pulse = _map(raw);
    } catch (_) {
      // Keep the previous verified snapshot instead of flashing zeroes.
    }
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_owner_live_activity_v958',
      );
      owner = _map(raw);
    } catch (_) {
      // Expected for customer accounts. Owner metrics stay private.
    }
    if (!mounted) return;
    setState(() {
      if (pulse['available'] == true) _pulse = pulse;
      _owner = owner['available'] == true ? owner : const {};
      _lastRefresh = DateTime.now();
      _loading = false;
    });
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
        .toList();
  }

  int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    final n = _int(value);
    final raw = n.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return '${n < 0 ? '-' : ''}${out.toString()}';
  }

  String _time(DateTime? value) {
    if (value == null) return 'connecting';
    final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _open(String title, Widget page, {bool scroll = true}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: BridgePointMotionBackgroundV2(
            child: scroll
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: page,
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox.expand(child: page),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStateDepth() async {
    final states = _rows(_pulse['parcel_states']);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('U.S. parcel coverage'),
        content: SizedBox(
          width: 720,
          child: states.isEmpty
              ? const Text('BridgePoint is loading state-level parcel depth.')
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final row in states)
                        Container(
                          width: 150,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10243A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _cyan.withValues(alpha: .12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${row['state_code'] ?? '—'}',
                                style: const TextStyle(
                                  color: _cyan,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _number(row['parcel_count']),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _pulse['available'] == true;
    final statesPresent = _int(_pulse['states_present']);
    final ownerMode = _owner['available'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          available: available,
          statesPresent: statesPresent,
          lastRefresh: _lastRefresh,
          timeLabel: _time(_lastRefresh),
          onRefresh: () => _refresh(),
          onMap: () => _open(
            'Intelligence Map',
            const BridgePointMapWeatherV2(),
            scroll: false,
          ),
          onProperties: () => _open(
            'Find a Property',
            const BridgePointPropertiesV2(),
          ),
          onOpportunities: () => _open(
            'Opportunities',
            const BridgePointOpportunitiesV2(),
          ),
          onPackages: () => _open(
            'Packages & Access',
            const BridgePointProductsSettingsV2(),
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 14),
        _SectionHeader(
          title: 'Live U.S. intelligence engine',
          subtitle:
              'Production totals refresh every 5 seconds. These are not demo counters.',
          trailing: TextButton.icon(
            onPressed: _showStateDepth,
            icon: const Icon(Icons.map_outlined),
            label: const Text('State depth'),
          ),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 1080
                ? 4
                : c.maxWidth >= 700
                    ? 3
                    : c.maxWidth >= 470
                        ? 2
                        : 1;
            final width = (c.maxWidth - (columns - 1) * 9) / columns;
            final metrics = [
              _MetricData(
                'U.S. PARCELS',
                _number(_pulse['total_parcels']),
                '$statesPresent states / D.C. jurisdictions represented',
                Icons.home_work_outlined,
                _cyan,
              ),
              _MetricData(
                'INGESTED RECORDS',
                _number(_pulse['ingested_source_records']),
                'Source records flowing through the live ingestion registry',
                Icons.cloud_download_outlined,
                _blue,
              ),
              _MetricData(
                'SCORED PROPERTIES',
                _number(_pulse['scored_properties']),
                'Property score records produced by BridgePoint',
                Icons.speed_rounded,
                _green,
              ),
              _MetricData(
                'DETECTED PATTERNS',
                _number(_pulse['detected_patterns']),
                'Corroborating intelligence patterns detected by the pattern engine',
                Icons.hub_outlined,
                _gold,
              ),
              _MetricData(
                'SIGNALS',
                _number(_pulse['signals']),
                'Source-linked intelligence observations in production',
                Icons.bolt_rounded,
                _cyan,
              ),
              _MetricData(
                'ACTIVE OPPORTUNITIES',
                _number(_pulse['active_opportunities']),
                'Qualified properties currently prioritized for review',
                Icons.location_searching_rounded,
                _green,
              ),
              _MetricData(
                'REGISTERED SOURCES',
                _number(_pulse['registered_sources']),
                'Data sources registered with BridgePoint',
                Icons.source_outlined,
                _blue,
              ),
              _MetricData(
                'U.S. COVERAGE',
                statesPresent == 0 ? '—' : '$statesPresent',
                'Coverage depth is progressive and varies by state/source',
                Icons.public_rounded,
                _gold,
              ),
            ];
            return Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final metric in metrics)
                  SizedBox(width: width, child: _MetricCard(metric: metric)),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (ownerMode) ...[
          _OwnerActivity(owner: _owner, number: _number),
          const SizedBox(height: 14),
        ],
        const _HowToReadBridgePoint(),
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
                  'BridgePoint is evidence-first. A signal, pattern, score or opportunity prioritizes review; it is not proof of damage, coverage, liability, a sale, or a guaranteed outcome.',
                  style: TextStyle(color: _muted, fontSize: 12.2, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.available,
    required this.statesPresent,
    required this.lastRefresh,
    required this.timeLabel,
    required this.onRefresh,
    required this.onMap,
    required this.onProperties,
    required this.onOpportunities,
    required this.onPackages,
  });

  final bool available;
  final int statesPresent;
  final DateTime? lastRefresh;
  final String timeLabel;
  final VoidCallback onRefresh;
  final VoidCallback onMap;
  final VoidCallback onProperties;
  final VoidCallback onOpportunities;
  final VoidCallback onPackages;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF20A192A), Color(0xEE0B2138), Color(0xEA111630)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _BridgePointHomeV2State._cyan.withValues(alpha: .18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
          ],
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
                      Text(
                        'BRIDGEPOINT',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      Text(
                        'PROPERTY INTELLIGENCE',
                        style: TextStyle(
                          color: _BridgePointHomeV2State._cyan,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: (available
                            ? _BridgePointHomeV2State._green
                            : _BridgePointHomeV2State._red)
                        .withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (available
                              ? _BridgePointHomeV2State._green
                              : _BridgePointHomeV2State._red)
                          .withValues(alpha: .28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: available
                            ? _BridgePointHomeV2State._green
                            : _BridgePointHomeV2State._red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        available ? 'LIVE • $timeLabel' : 'RECONNECTING',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Refresh live metrics',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Know what is happening. Know where to look next.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              statesPresent > 0
                  ? 'BridgePoint is actively building, connecting and evaluating property intelligence across the United States. Coverage is progressive—use the live counts below to see the machine moving.'
                  : 'BridgePoint connects property records, weather, changes, imagery, risk and evidence around the property, then helps prioritize what deserves attention first.',
              style: const TextStyle(
                color: _BridgePointHomeV2State._muted,
                fontSize: 14.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 17),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                FilledButton.icon(
                  onPressed: onMap,
                  icon: const Icon(Icons.public_rounded),
                  label: const Text('Open map'),
                ),
                OutlinedButton.icon(
                  onPressed: onProperties,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Find a property'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpportunities,
                  icon: const Icon(Icons.location_searching_rounded),
                  label: const Text('Opportunities'),
                ),
                OutlinedButton.icon(
                  onPressed: onPackages,
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Packages'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _BridgePointHomeV2State._muted,
                    fontSize: 12.2,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class _MetricData {
  const _MetricData(this.label, this.value, this.detail, this.icon, this.color);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _MetricData metric;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: metric.color.withValues(alpha: .17)),
          boxShadow: [
            BoxShadow(color: metric.color.withValues(alpha: .035), blurRadius: 20),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(metric.icon, color: metric.color, size: 21),
            ),
            const SizedBox(height: 11),
            Text(
              metric.label,
              style: const TextStyle(
                color: _BridgePointHomeV2State._muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              metric.detail,
              style: const TextStyle(
                color: _BridgePointHomeV2State._muted,
                fontSize: 11.6,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
}

class _OwnerActivity extends StatelessWidget {
  const _OwnerActivity({required this.owner, required this.number});
  final Map<String, dynamic> owner;
  final String Function(dynamic) number;

  @override
  Widget build(BuildContext context) {
    final regionsRaw = owner['signin_flow_regions_24h'];
    final regions = regionsRaw is List
        ? regionsRaw
            .whereType<Map>()
            .map((row) => '${row['region_code'] ?? ''}'.trim())
            .where((value) => value.isNotEmpty && value != 'UNKNOWN')
            .take(6)
            .toList()
        : const <String>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BridgePointHomeV2State._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _BridgePointHomeV2State._gold.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: _BridgePointHomeV2State._gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Owner live activity',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'PRIVATE',
                style: TextStyle(
                  color: _BridgePointHomeV2State._gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Only platform admins can see this section. Geography is coarse sign-in/account-flow telemetry, not exact verified user location.',
            style: TextStyle(
              color: _BridgePointHomeV2State._muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _OwnerPill('Users', number(owner['total_users'])),
              _OwnerPill('Confirmed', number(owner['confirmed_users'])),
              _OwnerPill('Signups 24h', number(owner['signups_24h'])),
              _OwnerPill('Sign-ins 24h', number(owner['signins_24h'])),
              _OwnerPill('Active 15m', number(owner['active_users_15m'])),
              _OwnerPill('Coarse regions', regions.isEmpty ? '—' : regions.join(' • ')),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerPill extends StatelessWidget {
  const _OwnerPill(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF10243A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _BridgePointHomeV2State._gold.withValues(alpha: .12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label  ',
              style: const TextStyle(
                color: _BridgePointHomeV2State._muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _HowToReadBridgePoint extends StatelessWidget {
  const _HowToReadBridgePoint();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.fact_check_outlined,
        'Signal',
        'A dated source-linked observation. It can matter without proving an outcome.',
        _BridgePointHomeV2State._cyan,
      ),
      (
        Icons.hub_outlined,
        'Pattern',
        'Multiple observations lining up around the same property or context.',
        _BridgePointHomeV2State._blue,
      ),
      (
        Icons.speed_rounded,
        'Score',
        'A prioritization summary of linked evidence—not a probability of damage or sale.',
        _BridgePointHomeV2State._gold,
      ),
      (
        Icons.location_searching_rounded,
        'Opportunity',
        'A property that passed an evidence gate and deserves review, not a guaranteed job.',
        _BridgePointHomeV2State._green,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BridgePointHomeV2State._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to read BridgePoint',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'You should not need a founder beside you to understand the intelligence.',
            style: TextStyle(
              color: _BridgePointHomeV2State._muted,
              fontSize: 12.2,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 900 ? 4 : c.maxWidth >= 520 ? 2 : 1;
              final width = (c.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: item.$4.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: item.$4.withValues(alpha: .14)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$1, color: item.$4, size: 22),
                            const SizedBox(height: 8),
                            Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              item.$3,
                              style: const TextStyle(
                                color: _BridgePointHomeV2State._muted,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
