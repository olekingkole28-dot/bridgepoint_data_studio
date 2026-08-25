import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOperationsWorkspaceV2 extends StatefulWidget {
  const BridgePointOperationsWorkspaceV2({super.key});

  @override
  State<BridgePointOperationsWorkspaceV2> createState() =>
      _BridgePointOperationsWorkspaceV2State();
}

class _BridgePointOperationsWorkspaceV2State
    extends State<BridgePointOperationsWorkspaceV2> {
  int _tab = 0;
  late Future<List<dynamic>> _request;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);

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
        _safe('bridgepoint_flutter_opportunities_v235', {
          'p_model_key': null,
          'p_limit': 100,
          'p_offset': 0,
          'p_priority': null,
          'p_stage': null,
        }),
        _safe('bridgepoint_flutter_signals', {
          'p_search': null,
          'p_signal_family': null,
          'p_status': null,
          'p_limit': 100,
          'p_offset': 0,
        }),
        _safe('bridgepoint_flutter_sources'),
        _safe('bridgepoint_source_health_v86'),
        _safe('bridgepoint_flutter_models'),
        _safe('bridgepoint_watchlists_v88'),
        _safe('bridgepoint_route_plans_v87', {'p_status': null, 'p_limit': 100}),
        _safe('bridgepoint_team_workspace_v80'),
        _safe('bridgepoint_field_team_v81'),
        _safe('bridgepoint_field_note_of_day_v81'),
        _safe('bridgepoint_notifications_v74', {'p_limit': 100}),
        _safe('bridgepoint_flutter_packages_core_v429'),
        _safe('bridgepoint_flutter_settings_v59'),
      ]);

  void _refresh() => setState(() => _request = _load());

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const [
        'items', 'results', 'opportunities', 'signals', 'sources', 'models',
        'watchlists', 'routes', 'notifications', 'packages', 'members', 'team'
      ]) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Widget _dataPanel(String title, dynamic value,
      {IconData icon = Icons.data_object_rounded, int maxRows = 50}) {
    final rows = _rows(value);
    final map = _map(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: _cyan),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              if (rows.isNotEmpty)
                Chip(label: Text('${rows.length} loaded')),
            ]),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              _CompactMap(map)
            else
              ...rows.take(maxRows).map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _CompactMap(row),
                  )),
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
            Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Operations Workspace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text(
                    'Opportunities, evidence, models, field work, teams, alerts and commercial access in one operational surface.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ]),
              ),
              IconButton.filledTonal(onPressed: _refresh, tooltip: 'Refresh live operations', icon: const Icon(Icons.refresh_rounded)),
            ]),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (snapshot.hasError)
              Text('${snapshot.error}', style: const TextStyle(color: Color(0xFFFF7E7E))),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.track_changes_rounded), label: Text('Opportunities')),
                  ButtonSegment(value: 1, icon: Icon(Icons.sensors_rounded), label: Text('Evidence')),
                  ButtonSegment(value: 2, icon: Icon(Icons.model_training_rounded), label: Text('Models')),
                  ButtonSegment(value: 3, icon: Icon(Icons.route_rounded), label: Text('Field + Team')),
                  ButtonSegment(value: 4, icon: Icon(Icons.notifications_active_outlined), label: Text('Alerts')),
                  ButtonSegment(value: 5, icon: Icon(Icons.workspace_premium_outlined), label: Text('Packages + Settings')),
                ],
                selected: {_tab},
                onSelectionChanged: (value) => setState(() => _tab = value.first),
              ),
            ),
            const SizedBox(height: 12),
            if (_tab == 0) ...[
              _dataPanel('Ranked opportunities / Why Now', at(0), icon: Icons.track_changes_rounded),
              const SizedBox(height: 8),
              const _TruthNotice(),
            ] else if (_tab == 1) ...[
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 900;
                final width = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: width, child: _dataPanel('Signals / evidence families', at(1), icon: Icons.sensors_rounded)),
                  SizedBox(width: width, child: _dataPanel('Sources', at(2), icon: Icons.hub_outlined)),
                  SizedBox(width: width, child: _dataPanel('Source health / freshness', at(3), icon: Icons.monitor_heart_outlined)),
                ]);
              }),
            ] else if (_tab == 2) ...[
              _dataPanel('Models and intelligence definitions', at(4), icon: Icons.model_training_rounded),
              const SizedBox(height: 10),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Model output must remain explainable and evidence-backed. BridgePoint distinguishes prioritization/risk estimates from confirmed property condition, damage, claims or inspection findings.',
                    style: TextStyle(color: _amber, fontSize: 10, height: 1.5),
                  ),
                ),
              ),
            ] else if (_tab == 3) ...[
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 900;
                final width = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: width, child: _dataPanel('Watchlists / saved work', at(5), icon: Icons.bookmark_outline_rounded)),
                  SizedBox(width: width, child: _dataPanel('Routes / offline packs', at(6), icon: Icons.route_rounded)),
                  SizedBox(width: width, child: _dataPanel('Team workspace / roles', at(7), icon: Icons.groups_2_outlined)),
                  SizedBox(width: width, child: _dataPanel('Field team', at(8), icon: Icons.engineering_outlined)),
                  SizedBox(width: width, child: _dataPanel('Field note of the day', at(9), icon: Icons.sticky_note_2_outlined)),
                ]);
              }),
            ] else if (_tab == 4) ...[
              _dataPanel('Notifications / follow-ups / health alerts', at(10), icon: Icons.notifications_active_outlined),
            ] else ...[
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 900;
                final width = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: width, child: _dataPanel('Packages / delivery truth', at(11), icon: Icons.workspace_premium_outlined)),
                  SizedBox(width: width, child: _dataPanel('Account / accessibility / refresh settings', at(12), icon: Icons.settings_outlined)),
                ]);
              }),
            ],
          ],
        );
      },
    );
  }
}

class _TruthNotice extends StatelessWidget {
  const _TruthNotice();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_user_outlined, color: Color(0xFF38D49A)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Opportunity ranking is a human-review prioritization layer. Weather exposure, scores and signals are not remote diagnosis or confirmed damage. Strong review candidates should preserve independent evidence families, provenance and match confidence.',
                style: TextStyle(color: Color(0xFF8FA5BF), height: 1.5),
              ),
            ),
          ]),
        ),
      );
}

class _CompactMap extends StatelessWidget {
  const _CompactMap(this.value);
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const Text('No data returned.', style: TextStyle(color: Color(0xFF8FA5BF)));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF081625),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x2235D2E8)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: value.entries.take(24).map((entry) {
          final raw = '${entry.value}';
          final text = raw.length > 220 ? '${raw.substring(0, 220)}…' : raw;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text('${entry.key.replaceAll('_', ' ')}: $text', style: const TextStyle(fontSize: 9, height: 1.35)),
          );
        }).toList(),
      ),
    );
  }
}
