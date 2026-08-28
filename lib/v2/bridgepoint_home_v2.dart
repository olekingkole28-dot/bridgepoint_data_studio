import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointHomeV2 extends StatefulWidget {
  const BridgePointHomeV2({super.key});

  @override
  State<BridgePointHomeV2> createState() => _BridgePointHomeV2State();
}

class _BridgePointHomeV2State extends State<BridgePointHomeV2> {
  static const _panel = Color(0xE80A192A);
  static const _soft = Color(0xFF10243A);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _gold = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  Timer? _timer;
  bool _busy = false;
  bool _loading = true;
  bool _hasPulse = false;
  bool _ownerChecked = false;
  bool _isOwner = false;
  Map<String, dynamic> _pulse = const {};
  Map<String, dynamic> _owner = const {};
  Map<String, int> _delta = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _rpc(String name) async {
    try {
      final value = await Supabase.instance.client.rpc(name);
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {}
    return const {};
  }

  Future<void> _refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final next = await _rpc('bridgepoint_public_system_pulse_v957');
      Map<String, dynamic> owner = _owner;

      if (!_ownerChecked || _isOwner) {
        final candidate = await _rpc('bridgepoint_owner_live_activity_v958');
        if (!_ownerChecked) {
          _ownerChecked = true;
          _isOwner = candidate['available'] == true;
        }
        if (_isOwner && candidate['available'] == true) owner = candidate;
      }

      final delta = <String, int>{};
      for (final key in const [
        'total_parcels',
        'scored_properties',
        'detected_patterns',
        'signals',
        'active_opportunities',
        'ingested_source_records',
      ]) {
        delta[key] = _hasPulse ? _toInt(next[key]) - _toInt(_pulse[key]) : 0;
      }

      if (mounted) {
        setState(() {
          _pulse = next;
          _owner = owner;
          _delta = delta;
          _hasPulse = next['available'] == true;
          _loading = false;
        });
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcels = _toInt(_pulse['total_parcels']);
    final parcelTarget = _toInt(_pulse['national_target_parcels']);
    final parcelPct = _toDouble(_pulse['parcel_completion_pct']);
    final matchingDone = _toInt(_pulse['matching_states_complete']);
    final matchingTotal = _toInt(_pulse['matching_states_total']);
    final matchingPct = _toDouble(_pulse['matching_completion_pct']);
    final scored = _toInt(_pulse['scored_properties']);
    final scoringPct = _toDouble(_pulse['scoring_coverage_pct']);
    final signals = _toInt(_pulse['signals']);
    final patterns = _toInt(_pulse['detected_patterns']);
    final opportunities = _toInt(_pulse['active_opportunities']);
    final sources = _toInt(_pulse['registered_sources']);
    final sourceRecords = _toInt(_pulse['ingested_source_records']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF20A192A), Color(0xEF0A2136), Color(0xEB10182E)],
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _cyan.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BridgePoint is building the U.S. property intelligence network live. These are real production totals from Supabase—not demo numbers. Keep Home open and you can watch parcels, matching, scoring, signals, patterns and opportunities change as the system works.',
                      style: TextStyle(fontSize: 14.5, height: 1.48, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _LivePill(),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Auto-refreshes every 3 seconds',
                style: TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 7),
          const LinearProgressIndicator(minHeight: 3),
        ],
        const SizedBox(height: 13),
        _Section(
          title: 'Live national completion',
          subtitle: 'One view of the three things that matter most right now.',
          child: LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 620 ? 2 : 1;
              final width = (c.maxWidth - (columns - 1) * 10) / columns;
              final cards = [
                _CompletionCard(
                  label: 'PARCEL INGESTION',
                  percent: parcelPct,
                  color: _cyan,
                  icon: Icons.home_work_rounded,
                  value: parcels,
                  detail: '${_fmt(parcels)} of ${_fmt(parcelTarget)} strict U.S. parcel floor',
                  delta: _delta['total_parcels'] ?? 0,
                ),
                _CompletionCard(
                  label: 'MATCHING',
                  percent: matchingPct,
                  color: _blue,
                  icon: Icons.join_inner_rounded,
                  valueText: '$matchingDone / $matchingTotal',
                  detail: 'Jurisdictions through the normalize + match quality gate',
                  delta: 0,
                ),
                _CompletionCard(
                  label: 'SCORING COVERAGE',
                  percent: scoringPct,
                  color: _green,
                  icon: Icons.speed_rounded,
                  value: scored,
                  detail: 'Scored properties as a share of currently ingested parcels',
                  delta: _delta['scored_properties'] ?? 0,
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final card in cards) SizedBox(width: width, child: card)],
              );
            },
          ),
        ),
        const SizedBox(height: 13),
        _Section(
          title: 'Live intelligence output',
          subtitle: 'These counters animate when production changes so you can literally watch BridgePoint working.',
          child: LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 1050 ? 5 : c.maxWidth >= 650 ? 3 : 2;
              final width = (c.maxWidth - (columns - 1) * 8) / columns;
              final cards = [
                _LiveCounter('SIGNALS', signals, _delta['signals'] ?? 0, Icons.bolt_rounded, _cyan),
                _LiveCounter('PATTERNS', patterns, _delta['detected_patterns'] ?? 0, Icons.hub_rounded, _blue),
                _LiveCounter('OPPORTUNITIES', opportunities, _delta['active_opportunities'] ?? 0, Icons.location_searching_rounded, _green),
                _LiveCounter('SOURCES', sources, 0, Icons.dataset_linked_outlined, _gold),
                _LiveCounter('SOURCE RECORDS', sourceRecords, _delta['ingested_source_records'] ?? 0, Icons.sync_alt_rounded, _cyan),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final card in cards) SizedBox(width: width, child: card)],
              );
            },
          ),
        ),
        if (_isOwner) ...[
          const SizedBox(height: 13),
          _OwnerActivity(activity: _owner),
        ],
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: _green, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Progress is evidence-first: the counters show what BridgePoint has actually ingested or produced. Coverage depth still varies while the national build continues.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.label,
    required this.percent,
    required this.color,
    required this.icon,
    required this.detail,
    required this.delta,
    this.value,
    this.valueText,
  });

  final String label;
  final double percent;
  final Color color;
  final IconData icon;
  final String detail;
  final int delta;
  final int? value;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _BridgePointHomeV2State._soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: p / 100),
                        duration: const Duration(milliseconds: 850),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 9,
                          backgroundColor: Colors.white.withValues(alpha: .06),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${p.toStringAsFixed(p >= 10 ? 1 : 2)}%', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        const Text('COMPLETE', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .45)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 17),
                        const SizedBox(width: 5),
                        Expanded(child: Text(label, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .5))),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (value != null)
                      _RollingNumber(value: value!, fontSize: 21)
                    else
                      Text(valueText ?? '—', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    if (delta > 0)
                      Text('+${_fmt(delta)} in the last 3 sec', style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900))
                    else
                      const Text('LIVE PRODUCTION', style: TextStyle(color: _BridgePointHomeV2State._green, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: p / 100),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: .06),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(detail, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }
}

class _LiveCounter extends StatelessWidget {
  const _LiveCounter(this.label, this.value, this.delta, this.icon, this.color);
  final String label;
  final int value;
  final int delta;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 7),
            Text(label, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 8.8, fontWeight: FontWeight.w900, letterSpacing: .5)),
            const SizedBox(height: 3),
            _RollingNumber(value: value, fontSize: 18),
            const SizedBox(height: 3),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: delta > 0
                  ? Text('+${_fmt(delta)} / 3 sec', key: ValueKey('$label-$delta'), style: TextStyle(color: color, fontSize: 9.3, fontWeight: FontWeight.w900))
                  : const Text('live', key: ValueKey('live'), style: TextStyle(color: _BridgePointHomeV2State._green, fontSize: 9.3, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}

class _RollingNumber extends StatefulWidget {
  const _RollingNumber({required this.value, required this.fontSize});
  final int value;
  final double fontSize;

  @override
  State<_RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<_RollingNumber> {
  late int _from;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
  }

  @override
  void didUpdateWidget(covariant _RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: _from.toDouble(), end: widget.value.toDouble()),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          _fmt(v.round()),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w900),
        ),
      );
}

class _OwnerActivity extends StatelessWidget {
  const _OwnerActivity({required this.activity});
  final Map<String, dynamic> activity;

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final regions = _rows(activity['signin_flow_regions_24h']);
    final signins = _rows(activity['recent_signins']);
    return _Section(
      title: 'Owner-only activity',
      subtitle: 'This section is private to your platform-owner/admin account.',
      accent: _BridgePointHomeV2State._gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _OwnerStat('USERS', _fmt(_toInt(activity['total_users']))),
              _OwnerStat('ACTIVE 15M', _fmt(_toInt(activity['active_users_15m']))),
              _OwnerStat('SIGN-INS 24H', _fmt(_toInt(activity['signins_24h']))),
              _OwnerStat('SIGNUPS 24H', _fmt(_toInt(activity['signups_24h']))),
            ],
          ),
          if (regions.isNotEmpty) ...[
            const SizedBox(height: 11),
            const Text('COARSE SIGN-IN REGIONS', style: TextStyle(color: _BridgePointHomeV2State._gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final row in regions.take(10)) Chip(label: Text('${row['region_code'] ?? 'UNKNOWN'} • ${_fmt(_toInt(row['visitors']))}')),
              ],
            ),
          ],
          if (signins.isNotEmpty) ...[
            const SizedBox(height: 11),
            const Text('RECENT SIGN-INS', style: TextStyle(color: _BridgePointHomeV2State._gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .5)),
            const SizedBox(height: 4),
            for (final row in signins.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline_rounded, color: _BridgePointHomeV2State._gold, size: 18),
                title: Text('${row['email'] ?? 'Account'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_time(row['last_sign_in_at']), style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10)),
              ),
          ],
          const Text(
            'Location is coarse browser-region telemetry around account/sign-in flows, not precise GPS location.',
            style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _OwnerStat extends StatelessWidget {
  const _OwnerStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._gold.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _BridgePointHomeV2State._gold.withValues(alpha: .13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _BridgePointHomeV2State._gold, fontSize: 8.3, fontWeight: FontWeight.w900, letterSpacing: .45)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child, this.accent});
  final String title;
  final String subtitle;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? _BridgePointHomeV2State._cyan;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BridgePointHomeV2State._panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: .13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10.8, height: 1.35)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._green.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _BridgePointHomeV2State._green.withValues(alpha: .22)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: _BridgePointHomeV2State._green, size: 7),
            SizedBox(width: 4),
            Text('LIVE', style: TextStyle(color: _BridgePointHomeV2State._green, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .45)),
          ],
        ),
      );
}

int _toInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String _fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}${b.toString()}';
}

String _time(dynamic value) {
  final dt = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (dt == null) return '—';
  final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.month}/${dt.day} $hour:$minute $ap';
}
