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
  static const cyan = Color(0xFF48E1FF);
  static const green = Color(0xFF45E6A6);
  static const gold = Color(0xFFFFC95E);
  static const muted = Color(0xFFB5C6D9);
  Timer? timer;
  bool busy = false;
  bool loading = true;
  Map<String, dynamic> catalog = const {};
  Map<String, dynamic> pulse = const {};

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> rpc(String name) async {
    try {
      final value = await Supabase.instance.client.rpc(name);
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {}
    return const {};
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    try {
      final values = await Future.wait([
        rpc('bridgepoint_living_world_catalog_v2652'),
        rpc('bridgepoint_public_system_pulse_v957'),
      ]);
      if (mounted) {
        setState(() {
          catalog = values[0];
          pulse = values[1];
          loading = false;
        });
      }
    } finally {
      busy = false;
    }
  }

  int number(dynamic value) => value is num ? value.round() : int.tryParse('$value') ?? 0;
  String format(dynamic value) => number(value).toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  Map<String, int> groupCounts() {
    final out = <String, int>{};
    final layers = catalog['layers'];
    if (layers is! List) return out;
    for (final raw in layers) {
      if (raw is! Map) continue;
      final name = '${raw['filter_group'] ?? raw['family'] ?? 'World'}';
      out[name] = (out[name] ?? 0) + 1;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final counts = catalog['counts'] is Map
        ? Map<String, dynamic>.from(catalog['counts'] as Map)
        : const <String, dynamic>{};
    final groups = groupCounts().entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(counts),
        if (loading) const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: MediaQuery.sizeOf(context).width < 700 ? 540 : 650,
            decoration: BoxDecoration(
              color: const Color(0xFF020711),
              border: Border.all(color: cyan.withValues(alpha: .18)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const BridgePointWorldEmbedV2(),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          'Everything BridgePoint can build into the world',
          'Generated directly from the governed backend catalog, so future layers are not forgotten by the UI.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in groups)
                Chip(
                  side: BorderSide(color: cyan.withValues(alpha: .12)),
                  backgroundColor: const Color(0xFF10243A),
                  label: Text('${group.key} · ${group.value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          'Property intelligence still runs underneath the world',
          'The V2652 world adds spatial reality without replacing parcels, claims, signals, scoring, patterns, opportunities or evidence.',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat('CANONICAL PARCELS', format(pulse['total_parcels']), Icons.grid_on_rounded, cyan),
              _stat('SIGNALS', format(pulse['signals']), Icons.bolt_rounded, gold),
              _stat('PATTERNS', format(pulse['detected_patterns']), Icons.hub_rounded, green),
              _stat('OPPORTUNITIES', format(pulse['active_opportunities']), Icons.location_searching_rounded, cyan),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xE80A192A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: green, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Observed, source-backed, derived, modeled, forecast and historical states remain distinct. Exact private interiors and sensitive utility detail stay access-controlled. “100%” means verified coverage, not fabricated geometry.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero(Map<String, dynamic> counts) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF20A192A), Color(0xEF08253B), Color(0xE9101831)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cyan.withValues(alpha: .2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(child: Text('Your world is the home screen.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                _LivePill(),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'BridgePoint World V2652 combines the property engine with every governed living-world layer the backend knows. The map catalog updates from Supabase instead of a hardcoded layer list.',
              style: TextStyle(color: muted, height: 1.45, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stat('WORLD LAYERS', format(counts['layers']), Icons.layers_outlined, cyan),
                _stat('ACTIVE SOURCES', format(counts['sources']), Icons.hub_outlined, gold),
                _stat('OBSERVATIONS', format(counts['observations']), Icons.sensors_rounded, green),
                _stat('ROOF ASSETS', format(counts['roof_assets']), Icons.roofing_outlined, cyan),
                _stat('LOCAL DETAIL JOBS', format(counts['detail_jobs']), Icons.travel_explore_rounded, gold),
                _stat('LIDAR DERIVATIONS', format(counts['lidar_derivation_jobs']), Icons.view_in_ar_outlined, green),
              ],
            ),
          ],
        ),
      );

  Widget _panel(String title, String subtitle, Widget child) => Container(
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
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 10.5, height: 1.4)),
            const SizedBox(height: 11),
            child,
          ],
        ),
      );

  Widget _stat(String label, String value, IconData icon, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 145),
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
                Text(label, style: const TextStyle(color: muted, fontSize: 8.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      );
}

class _LivePill extends StatelessWidget {
  const _LivePill();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State.green.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _BridgePointHomeV2State.green.withValues(alpha: .4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: _BridgePointHomeV2State.green),
            SizedBox(width: 6),
            Text('LIVING', style: TextStyle(color: _BridgePointHomeV2State.green, fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
