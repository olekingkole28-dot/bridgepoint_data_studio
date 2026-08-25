import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointInvestorV2 extends StatefulWidget {
  const BridgePointInvestorV2({super.key});

  @override
  State<BridgePointInvestorV2> createState() => _BridgePointInvestorV2State();
}

class _BridgePointInvestorV2State extends State<BridgePointInvestorV2> {
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

  late Future<List<dynamic>> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String rpc, Map<String, dynamic> params) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'error': '$e', 'rpc': rpc};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_dashboard', {'p_model_key': 'property_investor', 'p_limit': 20}),
        _safe('bridgepoint_flutter_opportunities', {
          'p_model_key': 'property_investor',
          'p_limit': 50,
          'p_offset': 0,
          'p_priority': null,
          'p_stage': null,
        }),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['opportunities', 'ranked_opportunities', 'rows', 'items']) {
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

  void _refresh() => setState(() => _request = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        final dashboard = values.isNotEmpty ? _map(values[0]) : const <String, dynamic>{};
        final oppPayload = values.length > 1 ? _map(values[1]) : const <String, dynamic>{};
        final opportunities = _rows(oppPayload).isNotEmpty ? _rows(oppPayload) : _rows(dashboard);
        final high = opportunities.where((row) {
          final p = '${row['priority'] ?? ''}'.toLowerCase();
          return p == 'critical' || p == 'high';
        }).length;
        final assessed = opportunities.fold<double>(0, (sum, row) {
          final raw = row['assessed_total_value'];
          final n = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
          return sum + (n ?? 0);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_panel, _green.withValues(alpha: .08)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withValues(alpha: .16)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: _green.withValues(alpha: .11), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.real_estate_agent_rounded, color: _green, size: 27)),
                const SizedBox(width: 14),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BridgePoint Investor', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('Property transitions, ownership context, assessed value, redevelopment/distress signals, ranked opportunities and Why Now intelligence in a dedicated investor workspace.', style: TextStyle(color: _muted, height: 1.45)),
                ])),
                IconButton.filledTonal(onPressed: snapshot.connectionState == ConnectionState.waiting ? null : _refresh, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh Investor'),
              ]),
            ),
            if (snapshot.connectionState == ConnectionState.waiting) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 620 ? 2 : 1;
              final width = (c.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                SizedBox(width: width, child: _Metric('INVESTOR OPPORTUNITIES', _number(dashboard['active_opportunities'] ?? oppPayload['total_results']), 'Property Investor model', Icons.track_changes_rounded, _cyan)),
                SizedBox(width: width, child: _Metric('HIGH PRIORITY', '$high', 'Critical + high on this feed', Icons.priority_high_rounded, _amber)),
                SizedBox(width: width, child: _Metric('ASSESSED VALUE SHOWN', assessed <= 0 ? '—' : '\$${_number(assessed.round())}', 'Current returned properties', Icons.attach_money_rounded, _green)),
                SizedBox(width: width, child: const _Metric('CT PROPERTY BASE', '1,282,833', 'Statewide parcel/CAMA foundation', Icons.apartment_rounded, _blue)),
              ]);
            }),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .07))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Investor Opportunity Feed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Click any card to inspect the property-specific investor intelligence returned by BridgePoint.', style: TextStyle(color: _muted, fontSize: 10)),
                const SizedBox(height: 13),
                if (opportunities.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No investor opportunity rows returned for this account.', style: TextStyle(color: _muted))))
                else
                  ...opportunities.take(40).map((row) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _InvestorCard(row: row))),
              ]),
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
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _BridgePointInvestorV2State._panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 11), Text(label, style: const TextStyle(color: _BridgePointInvestorV2State._muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(detail, style: const TextStyle(color: _BridgePointInvestorV2State._muted, fontSize: 10))]));
}

class _InvestorCard extends StatelessWidget {
  const _InvestorCard({required this.row});
  final Map<String, dynamic> row;

  Color _priority(String value) {
    final p = value.toLowerCase();
    if (p.contains('critical')) return const Color(0xFFFF6B6B);
    if (p.contains('high')) return _BridgePointInvestorV2State._amber;
    if (p.contains('medium')) return _BridgePointInvestorV2State._cyan;
    return _BridgePointInvestorV2State._green;
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: ListView(children: [
              Text('${row['full_address'] ?? row['municipality'] ?? 'Investor opportunity'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final entry in row.entries)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${entry.key.replaceAll('_', ' ')}: ${entry.value}', style: const TextStyle(color: _BridgePointInvestorV2State._muted, fontSize: 11, height: 1.35))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priority = '${row['priority'] ?? 'monitor'}';
    final color = _priority(priority);
    final signal = '${row['top_signal_type'] ?? row['opportunity_type'] ?? 'property intelligence'}'.replaceAll('_', ' ');
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _BridgePointInvestorV2State._soft.withValues(alpha: .68), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .15))),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.house_siding_rounded, color: color, size: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${row['full_address'] ?? row['municipality'] ?? 'Property'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('${row['municipality'] ?? ''} • ${row['property_type'] ?? 'Property'} • $signal', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointInvestorV2State._muted, fontSize: 10)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${row['score'] ?? row['opportunity_score'] ?? '—'}', style: TextStyle(color: color, fontWeight: FontWeight.w900)), Text(priority.toUpperCase(), style: const TextStyle(color: _BridgePointInvestorV2State._muted, fontSize: 8, fontWeight: FontWeight.w800))]),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right_rounded, color: _BridgePointInvestorV2State._muted),
        ]),
      ),
    );
  }
}
