import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_world_embed_v2.dart';

class BridgePointHomeV2 extends StatefulWidget {
  const BridgePointHomeV2({super.key});

  @override
  State<BridgePointHomeV2> createState() => _BridgePointHomeV2State();
}

class _BridgePointHomeV2State extends State<BridgePointHomeV2> {
  static const _panel = Color(0xE80A192A);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _gold = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  Timer? _timer;
  bool _busy = false;
  bool _loading = true;
  Map<String, dynamic> _catalog = const {};
  Map<String, dynamic> _pulse = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
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
      final results = await Future.wait([
        _rpc('bridgepoint_living_world_catalog_v2652'),
        _rpc('bridgepoint_public_system_pulse_v957'),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0];
        _pulse = results[1];
        _loading = false;
      });
    } finally {
      _busy = false;
    }
  }

  int _n(dynamic value) => value is num ? value.round() : int.tryParse('$value') ?? 0;
  String _fmt(dynamic value) => _n(value).toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  Map<String, int> _groupCounts() {
    final out = <String, int>{};
    final layers = _catalog['layers'];
    if (layers is! List) return out;
    for (final raw in layers) {
      if (raw is! Map) continue;
      final group = '${raw['filter_group'] ?? raw['family'] ?? 'World'}';
      out[group] = (out[group] ?? 0) + 1;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _catalog['counts'] is Map
        ? Map<String, dynamic>.from(_catalog['counts'] as Map)
        : const <String, dynamic>{};
    final groups = _groupCounts().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final parcels = _n(_pulse['total_parcels']);
    final signals = _n(_pulse['signals']);
    final patterns = _n(_pulse['detected_patterns']);
    final opportunities = _n(_pulse['active_opportunities']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xF20A192A), Color(0xEF08253B), Color(0xE9101831)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cyan.withValues(alpha: .2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your world is the home screen.',
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'BridgePoint World V2652 combines the property engine with every governed living-world layer the backend knows. New source-backed layers can appear here without rebuilding the app navigation.',
                          style: TextStyle(color: _muted, height: 1.45, fontWeight: FontWeight.w650),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _green.withValues(alpha: .4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: _green),
                        SizedBox(width: 6),
                        Text('LIVING', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 11),
                const LinearProgressIndicator(minHeight: 3),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Stat('WORLD LAYERS', _fmt(counts['layers']), Icons.layers_outlined, _cyan),
                  _Stat('ACTIVE SOURCES', _fmt(counts['sources']), Icons.hub_outlined, _gold),
                  _Stat('OBSERVATIONS', _fmt(counts['observations']), Icons.sensors_rounded, _green),
                  _Stat('ROOF ASSETS', _fmt(counts['roof_assets']), Icons.roofing_outlined, _cyan),
                  _Stat('LOCAL DETAIL JOBS', _fmt(counts['detail_jobs']), Icons.travel_explore_rounded, _gold),
                  _Stat('LIDAR DERIVATIONS', _fmt(counts['lidar_derivation_jobs']), Icons.view_in_ar_outlined, _green),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: MediaQuery.sizeOf(context).width < 700 ? 540 : 650,
            decoration: BoxDecoration(
              color: const Color(0xFF020711),
              border: Border.all(color: _cyan.withValues(alpha: .18)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const BridgePointWorldEmbedV2(),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'What BridgePoint can build into the world',
          subtitle: 'This list is generated from the backend catalog, not a hardcoded marketing checklist.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in groups)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10243A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: .06)),
                  ),
                  child: Text(
                    '${group.key} · ${group.value}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w850),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Property intelligence keeps running underneath the world',
          subtitle: 'The world does not replace BridgePoint’s parcel, claims, scoring, pattern, opportunity or evidence engines.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat('CANONICAL PARCELS', _fmt(parcels), Icons.grid_on_rounded, _cyan),
              _Stat('SIGNALS', _fmt(signals), Icons.bolt_rounded, _gold),
              _Stat('PATTERNS', _fmt(patterns), Icons.hub_rounded, _green),
              _Stat('OPPORTUNITIES', _fmt(opportunities), Icons.location_searching_rounded, _cyan),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                  'Truth rule: source registration, materialized coverage and real-time freshness are separate. The map labels observed, source-backed, derived, modeled, forecast and historical states instead of fabricating 100% precision. Exact private interiors and sensitive utility detail stay access-controlled.',
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

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xE80A192A),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 10.5, height: 1.4)),
            const SizedBox(height: 11),
            child,
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF10243A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 8.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      );
}
