import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointHomeV2 extends StatefulWidget {
  const BridgePointHomeV2({super.key});

  @override
  State<BridgePointHomeV2> createState() => _BridgePointHomeV2State();
}

class _BridgePointHomeV2State extends State<BridgePointHomeV2> {
  late Future<List<dynamic>> _request;

  static const _muted = Color(0xFF8FA5BF);
  static const _cyan = Color(0xFF35D2E8);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (e) {
      return {'available': false, 'rpc': name, 'error': '$e'};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_daily_brief_v74'),
        _safe('bridgepoint_public_system_status_v320'),
        _safe('bridgepoint_user_market_context_v320'),
        _safe('bridgepoint_field_note_of_day_v81'),
        _safe('bridgepoint_notifications_v74', {'p_limit': 20}),
        _safe('bridgepoint_source_health_v86'),
      ]);

  void _refresh() => setState(() => _request = _load());

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
  }

  String _summary(dynamic value) {
    final map = _map(value);
    for (final key in const ['summary', 'headline', 'message', 'status', 'condition', 'state_code']) {
      final v = map[key];
      if (v != null && '$v'.trim().isNotEmpty) return '$v';
    }
    if (map.isEmpty) return 'No current response.';
    final first = map.entries.first;
    final text = '${first.value}';
    return text.length > 260 ? '${text.substring(0, 260)}…' : text;
  }

  Widget _card(String title, dynamic value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _cyan),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(_summary(value), style: const TextStyle(color: _muted, height: 1.45)),
            ],
          ),
        ),
      );

  Widget _details(String title, dynamic value) {
    final map = _map(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: map.entries.take(40).map((e) {
                final raw = '${e.value}';
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF081625),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x2235D2E8)),
                    ),
                    child: Text(
                      '${e.key.replaceAll('_', ' ')}: ${raw.length > 260 ? '${raw.substring(0, 260)}…' : raw}',
                      style: const TextStyle(fontSize: 9, height: 1.35),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BridgePoint Intelligence', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
                      SizedBox(height: 5),
                      Text(
                        'One operating system for property, risk, claims, weather, physical intelligence, workflows, portfolios, models and integrations.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(onPressed: _refresh, tooltip: 'Refresh live brief', icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (snapshot.hasError)
              Text('${snapshot.error}', style: const TextStyle(color: Color(0xFFFF7E7E))),
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth >= 1200 ? 3 : c.maxWidth >= 760 ? 2 : 1;
              final width = (c.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: width, child: _card('Daily intelligence', at(0), Icons.auto_graph_rounded)),
                SizedBox(width: width, child: _card('System readiness', at(1), Icons.monitor_heart_outlined)),
                SizedBox(width: width, child: _card('Your market / geography', at(2), Icons.location_on_outlined)),
                SizedBox(width: width, child: _card('Field note', at(3), Icons.sticky_note_2_outlined)),
                SizedBox(width: width, child: _card('Notifications', at(4), Icons.notifications_active_outlined)),
                SizedBox(width: width, child: _card('Source health', at(5), Icons.hub_outlined)),
              ]);
            }),
            const SizedBox(height: 14),
            _details('What changed / live brief detail', at(0)),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'BridgePoint truth rule: customer-facing intelligence must preserve provenance, dates, match confidence and uncertainty. Scores/signals prioritize human review; they do not become confirmed property condition merely because the model is confident.',
                  style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
