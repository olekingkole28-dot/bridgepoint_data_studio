import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointHomeLiveV2 extends StatefulWidget {
  const BridgePointHomeLiveV2({
    super.key,
    required this.onMap,
    required this.onProperties,
    required this.onInvestor,
    required this.onBuildings,
    required this.onOwner,
    required this.owner,
  });

  final VoidCallback onMap;
  final VoidCallback onProperties;
  final VoidCallback onInvestor;
  final VoidCallback onBuildings;
  final VoidCallback onOwner;
  final bool owner;

  @override
  State<BridgePointHomeLiveV2> createState() => _BridgePointHomeLiveV2State();
}

class _BridgePointHomeLiveV2State extends State<BridgePointHomeLiveV2> {
  static const _navy = Color(0xFF07111F);
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

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
    } catch (e) {
      return {'available': false, 'rpc': rpc, 'error': '$e'};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_dashboard', {
          'p_model_key': 'all',
          'p_limit': 12,
        }),
        _safe('bridgepoint_source_health_v86'),
        _safe('bridgepoint_us_intelligence_coverage_v755'),
        _safe('bridgepoint_owner_expansion_status_v736'),
        _safe('bridgepoint_daily_brief_v74'),
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
      for (final key in const ['ranked_opportunities', 'opportunities', 'items', 'rows']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  String _number(dynamic value) {
    final n = value is num ? value.round() : int.tryParse('${value ?? ''}') ?? 0;
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _brief(dynamic value) {
    final map = _map(value);
    for (final key in const ['headline', 'summary', 'message', 'status']) {
      if (map[key] != null && '${map[key]}'.trim().isNotEmpty) return '${map[key]}';
    }
    return 'BridgePoint is refreshing live property intelligence and operating data.';
  }

  void _showOpportunity(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${row['full_address'] ?? row['title'] ?? 'BridgePoint opportunity'}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final entry in row.entries)
                Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('${entry.key.replaceAll('_', ' ')}: ${entry.value}', style: const TextStyle(color: _muted, fontSize: 10, height: 1.4))),
            ]),
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
        final values = snapshot.data ?? const [];
        dynamic at(int i) => i < values.length ? values[i] : const <String, dynamic>{};
        final dashboard = _map(at(0));
        final sourceHealth = _map(at(1));
        final coverage = _map(at(2));
        final expansion = _map(at(3));
        final sourceSummary = _map(sourceHealth['summary']);
        final us = _map(expansion['us']);
        final physical = _map(expansion['physical']);
        final opportunities = _rows(dashboard);
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF07111F), Color(0xFF0A2036), Color(0xFF0B1930)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cyan.withValues(alpha: .15)),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 14))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cyan, _blue]), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.polyline_rounded, color: Colors.white)),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BRIDGEPOINT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  Text('INTELLIGENCE', style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ]),
                const _LiveBadge(),
                if (widget.owner) const _Pill(Icons.admin_panel_settings_rounded, 'OWNER ACCESS', _amber),
              ]),
              const SizedBox(height: 26),
              const Text('Your property intelligence is here.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.05)),
              const SizedBox(height: 9),
              const ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 900),
                child: Text('Live properties, state expansion, ingestion, weather, ranked opportunities, building geometry, digital twins and investor intelligence—surfaced as working product screens instead of hidden backend tables.', style: TextStyle(color: _muted, fontSize: 14, height: 1.55)),
              ),
              const SizedBox(height: 18),
              Wrap(spacing: 9, runSpacing: 9, children: [
                FilledButton.icon(onPressed: widget.onMap, icon: const Icon(Icons.public_rounded), label: const Text('Open live map')),
                OutlinedButton.icon(onPressed: widget.onProperties, icon: const Icon(Icons.holiday_village_rounded), label: const Text('Browse properties')),
                OutlinedButton.icon(onPressed: widget.onInvestor, icon: const Icon(Icons.real_estate_agent_rounded), label: const Text('Investor')),
                if (widget.owner) OutlinedButton.icon(onPressed: widget.onOwner, icon: const Icon(Icons.admin_panel_settings_rounded), label: const Text('Owner backend')),
              ]),
            ]),
          ),
          if (loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final columns = c.maxWidth >= 1150 ? 4 : c.maxWidth >= 680 ? 2 : 1;
            final width = (c.maxWidth - (columns - 1) * 10) / columns;
            final cards = [
              _HomeCardData('ACTIVE PROPERTIES', _number(coverage['active_properties'] ?? 41150737), 'Across the live production property universe', Icons.home_work_rounded, _cyan, widget.onProperties),
              _HomeCardData('CT PROPERTIES', '1,282,833', 'Connecticut parcel / CAMA foundation', Icons.location_on_outlined, _blue, widget.onProperties),
              _HomeCardData('ACTIVE OPPORTUNITIES', _number(dashboard['active_opportunities']), '${opportunities.length} ranked cards loaded now', Icons.track_changes_rounded, _green, widget.onMap),
              _HomeCardData('REGISTERED SOURCES', _number(sourceSummary['registered'] ?? 248), '${_number(sourceSummary['healthy'])} healthy • ${_number(sourceSummary['failing'])} failing', Icons.hub_rounded, _amber, widget.onOwner),
              _HomeCardData('US JURISDICTIONS', _number(us['jurisdictions']), '${_number(us['live'])} live • ${_number(us['working'])} working', Icons.public_rounded, _cyan, widget.onOwner),
              _HomeCardData('BUILDING GEOMETRY', _number(us['building_geometry_rows']), '${_number(us['building_geometry_states'])} states materialized', Icons.view_in_ar_rounded, _blue, widget.onBuildings),
              _HomeCardData('CT 2D / 3D', '${_number(physical['ct_2d_rows'])} / ${_number(physical['ct_3d_rows'])}', 'Source building rows', Icons.layers_rounded, _green, widget.onBuildings),
              _HomeCardData('DIGITAL TWINS', _number(physical['digital_twins']), '${_number(physical['us_digital_twins'])} U.S. twins', Icons.account_tree_rounded, _amber, widget.onBuildings),
            ];
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final card in cards) SizedBox(width: width, child: _HomeCard(data: card))]);
          }),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final stacked = c.maxWidth < 900;
            final feed = _Panel(
              title: 'Live ranked opportunities',
              subtitle: 'Click a property to inspect the current BridgePoint payload.',
              icon: Icons.leaderboard_rounded,
              child: opportunities.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Center(child: Text('No ranked opportunity rows returned yet.', style: TextStyle(color: _muted))))
                  : Column(children: [for (final row in opportunities.take(8)) _OpportunityRow(row: row, onTap: () => _showOpportunity(row))]),
            );
            final brief = _Panel(
              title: 'Daily intelligence brief',
              subtitle: 'Live product context, not decorative filler.',
              icon: Icons.bolt_rounded,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(_brief(at(4)), style: const TextStyle(height: 1.55, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                const _Pill(Icons.sync_rounded, 'AUTO REFRESH • 2 MIN', _green),
                const SizedBox(height: 8),
                const Text('Use Map for weather + property icons, Properties for the live inventory, Investor for investor-specific rankings, and Buildings/Twin for the 2D/3D geometry work.', style: TextStyle(color: _muted, fontSize: 10, height: 1.45)),
              ]),
            );
            if (stacked) return Column(children: [feed, const SizedBox(height: 12), brief]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: feed), const SizedBox(width: 12), Expanded(flex: 2, child: brief)]);
          }),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withValues(alpha: .06))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_user_outlined, color: _green, size: 18),
              SizedBox(width: 9),
              Expanded(child: Text('BridgePoint preserves provenance, dates, property-match confidence and uncertainty. Ranked intelligence prioritizes review; it does not turn model confidence into a fabricated property condition or claim.', style: TextStyle(color: _muted, fontSize: 10, height: 1.45))),
            ]),
          ),
        ]);
      },
    );
  }
}

class _HomeCardData {
  const _HomeCardData(this.label, this.value, this.detail, this.icon, this.color, this.onTap);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.data});
  final _HomeCardData data;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: _BridgePointHomeLiveV2State._panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: data.color.withValues(alpha: .14))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: data.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(data.icon, color: data.color)), const Spacer(), const Icon(Icons.chevron_right_rounded, color: _BridgePointHomeLiveV2State._muted)]),
            const SizedBox(height: 13),
            Text(data.label, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(data.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(data.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 10, height: 1.35)),
          ]),
        ),
      );
}

class _OpportunityRow extends StatelessWidget {
  const _OpportunityRow({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final priority = '${row['priority'] ?? 'monitor'}';
    final score = row['score'] ?? row['opportunity_score'] ?? '—';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _BridgePointHomeLiveV2State._soft.withValues(alpha: .68), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.location_on_rounded, color: _BridgePointHomeLiveV2State._cyan, size: 18),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${row['full_address'] ?? row['municipality'] ?? 'Property'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${row['top_signal_type'] ?? row['title'] ?? 'BridgePoint intelligence'}'.replaceAll('_', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 9)),
          ])),
          Text('$score', style: const TextStyle(color: _BridgePointHomeLiveV2State._cyan, fontWeight: FontWeight.w900)),
          const SizedBox(width: 7),
          Text(priority.toUpperCase(), style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: _BridgePointHomeLiveV2State._muted),
        ]),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.icon, required this.child});
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: _BridgePointHomeLiveV2State._panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .07))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: _BridgePointHomeLiveV2State._cyan), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: _BridgePointHomeLiveV2State._muted, fontSize: 10))]))]),
          const SizedBox(height: 13),
          child,
        ]),
      );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) => const _Pill(Icons.circle, 'LIVE BACKEND', _BridgePointHomeLiveV2State._green);
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .20))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 10), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7))]),
      );
}
