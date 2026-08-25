import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOperationsWorkspaceV2 extends StatefulWidget {
  const BridgePointOperationsWorkspaceV2({super.key});

  @override
  State<BridgePointOperationsWorkspaceV2> createState() => _BridgePointOperationsWorkspaceV2State();
}

class _BridgePointOperationsWorkspaceV2State extends State<BridgePointOperationsWorkspaceV2> {
  int _tab = 0;
  late Future<List<dynamic>> _request;
  final _inviteEmail = TextEditingController();
  String _inviteRole = 'FIELD';
  final Set<String> _routeSelection = {};
  bool _busy = false;
  String? _message;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  @override
  void dispose() {
    _inviteEmail.dispose();
    super.dispose();
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try { return await Supabase.instance.client.rpc(name, params: params); }
    catch (e) { return {'available': false, 'rpc': name, 'error': '$e'}; }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_opportunities_v235', {'p_model_key': 'all','p_limit': 100,'p_offset': 0,'p_priority': null,'p_stage': null}),
        _safe('bridgepoint_flutter_signals', {'p_search': null,'p_signal_family': null,'p_status': null,'p_limit': 100,'p_offset': 0}),
        _safe('bridgepoint_flutter_sources'),
        _safe('bridgepoint_source_health_v86'),
        _safe('bridgepoint_flutter_models'),
        _safe('bridgepoint_watchlists_v88'),
        _safe('bridgepoint_route_plans_v87', {'p_status': null, 'p_limit': 100}),
        _safe('bridgepoint_team_workspace_v80'),
        _safe('bridgepoint_field_team_v81'),
        _safe('bridgepoint_field_note_of_day_v81'),
        _safe('bridgepoint_notifications_v74', {'p_limit': 100}),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
  }

  List<Map<String, dynamic>> _rows(dynamic value, List<String> keys) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in keys) {
        if (value[key] is List) return _rows(value[key], keys);
      }
    }
    return const [];
  }

  num? _num(dynamic value) => value is num ? value : num.tryParse('$value');

  void _refresh() => setState(() => _request = _load());

  Future<void> _saveOpportunity(Map<String, dynamic> row) async {
    final opportunityId = '${row['opportunity_id'] ?? ''}';
    final propertyId = '${row['property_id'] ?? ''}';
    if (opportunityId.isEmpty || propertyId.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_save_opportunity_v70', params: {
        'p_opportunity_id': opportunityId,
        'p_property_id': propertyId,
        'p_title': '${row['title'] ?? 'BridgePoint opportunity'}',
        'p_address': '${row['full_address'] ?? ''}',
        'p_score': _num(row['score'] ?? row['property_intelligence_score']),
        'p_reason': '${row['explanation'] ?? ''}',
        'p_recommended_action': '${row['recommended_action'] ?? ''}',
        'p_vertical_key': '${row['vertical_key'] ?? ''}',
        'p_next_action_at': null,
      });
      if (mounted) setState(() => _message = '${_map(raw)['status'] ?? 'Saved'}');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _feedback(Map<String, dynamic> row, String code) async {
    final propertyId = '${row['property_id'] ?? ''}';
    final opportunityId = '${row['opportunity_id'] ?? ''}';
    if (propertyId.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_record_opportunity_feedback_v88', params: {
        'p_property_id': propertyId,
        'p_opportunity_id': opportunityId.isEmpty ? null : opportunityId,
        'p_feedback_code': code,
        'p_note': 'Recorded from Clean V2 Operations Workspace',
      });
      if (mounted) setState(() => _message = 'Feedback recorded: ${_map(raw)['feedback_code'] ?? code}');
    } catch (e) {
      if (mounted) setState(() => _message = 'Feedback unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buildRoute() async {
    if (_routeSelection.isEmpty) {
      setState(() => _message = 'Select at least one opportunity for the route.');
      return;
    }
    final name = TextEditingController(text: 'BridgePoint Field Route');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Build field route'),
        content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_routeSelection.length} selected opportunities'),
          const SizedBox(height: 10),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Route name')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Build route')),
        ],
      ),
    );
    if (ok != true) { name.dispose(); return; }
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_route_build_v154', params: {
        'p_route_name': name.text.trim().isEmpty ? 'BridgePoint Field Route' : name.text.trim(),
        'p_opportunity_ids': _routeSelection.toList(),
        'p_start_latitude': null,
        'p_start_longitude': null,
        'p_max_stops': 25,
      });
      final result = _map(raw);
      if (mounted) setState(() {
        _message = 'Route built with ${result['stop_count'] ?? _routeSelection.length} stops.';
        _routeSelection.clear();
        _request = _load();
        _tab = 3;
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Route build unavailable: $e');
    } finally {
      name.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareOffline(Map<String, dynamic> route) async {
    final id = '${route['route_plan_id'] ?? route['id'] ?? ''}';
    if (id.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_prepare_offline_route_v154', params: {'p_route_plan_id': id, 'p_hours': 24});
      final result = _map(raw);
      if (mounted) setState(() => _message = '${result['message'] ?? 'Offline route prepared for 24 hours.'}');
    } catch (e) {
      if (mounted) setState(() => _message = 'Offline preparation unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> row) async {
    final id = '${row['notification_id'] ?? row['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await Supabase.instance.client.rpc('bridgepoint_mark_notifications_read_v74', params: {'p_notification_id': id});
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not mark read: $e');
    }
  }

  Future<void> _invite() async {
    final email = _inviteEmail.text.trim();
    if (email.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_invite_team_member_v80', params: {'p_email': email, 'p_member_role': _inviteRole});
      _inviteEmail.clear();
      if (mounted) setState(() { _message = '${_map(raw)['message'] ?? 'Team invite created.'}'; _request = _load(); });
    } catch (e) {
      if (mounted) setState(() => _message = 'Invite unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _opportunityCard(Map<String, dynamic> row) {
    final score = row['score'] ?? row['property_intelligence_score'];
    final opportunityId = '${row['opportunity_id'] ?? ''}';
    final selected = opportunityId.isNotEmpty && _routeSelection.contains(opportunityId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (opportunityId.isNotEmpty)
              Checkbox(value: selected, onChanged: _busy ? null : (value) => setState(() => value == true ? _routeSelection.add(opportunityId) : _routeSelection.remove(opportunityId))),
            Expanded(child: Text('${row['title'] ?? row['full_address'] ?? 'Opportunity'}', style: const TextStyle(fontWeight: FontWeight.w900))),
            if (score != null) Chip(label: Text('Score $score')),
          ]),
          if ('${row['full_address'] ?? ''}'.isNotEmpty) Text('${row['full_address']}', style: const TextStyle(color: _muted, fontSize: 10)),
          const SizedBox(height: 7),
          Text('${row['explanation'] ?? 'No explanation returned.'}', style: const TextStyle(height: 1.45)),
          if ('${row['recommended_action'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Next best action: ${row['recommended_action']}', style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: [
            FilledButton.tonalIcon(onPressed: _busy ? null : () => _saveOpportunity(row), icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Save')),
            OutlinedButton(onPressed: _busy ? null : () => _feedback(row, 'GOOD_MATCH'), child: const Text('Good match')),
            OutlinedButton(onPressed: _busy ? null : () => _feedback(row, 'NOT_RELEVANT'), child: const Text('Not relevant')),
            OutlinedButton(onPressed: _busy ? null : () => _feedback(row, 'WRONG_PROPERTY'), child: const Text('Wrong property')),
            OutlinedButton(onPressed: _busy ? null : () => _feedback(row, 'NO_DAMAGE'), child: const Text('No damage')),
          ]),
          const SizedBox(height: 7),
          Text('${row['direct_source_count'] ?? 0} direct sources • ${row['independent_evidence_families'] ?? row['evidence_families'] ?? 'evidence families unavailable'}', style: const TextStyle(color: _muted, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _routeCard(Map<String, dynamic> route) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${route['route_name'] ?? route['name'] ?? 'Field route'}', style: const TextStyle(fontWeight: FontWeight.w900))),
          Chip(label: Text('${route['route_status'] ?? route['status'] ?? 'DRAFT'}')),
        ]),
        const SizedBox(height: 5),
        Text('${route['stop_count'] ?? _rows(route['stops'], const ['items']).length} stops • ${route['optimization_strategy'] ?? 'BridgePoint route ordering'}', style: const TextStyle(color: _muted)),
        const SizedBox(height: 9),
        Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _busy ? null : () => _prepareOffline(route), icon: const Icon(Icons.offline_pin_outlined), label: const Text('Prepare 24h offline pack'))),
      ]),
    ),
  );

  Widget _dataPanel(String title, dynamic value, IconData icon, List<String> keys) {
    final rows = _rows(value, keys);
    final map = _map(value);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: _cyan), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)))]),
      const SizedBox(height: 10),
      if (rows.isEmpty) _CompactMap(map) else ...rows.take(50).map((row) => Padding(padding: const EdgeInsets.only(bottom: 7), child: _CompactMap(row))),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const [];
        dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
        final opportunities = _rows(at(0), const ['opportunities','items','results']);
        final routes = _rows(at(6), const ['routes','items','results']);
        final notifications = _rows(at(10), const ['notifications','items','results']);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Operations Workspace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Ranked opportunities, evidence, models, field routes, teams and alerts in one operating flow.', style: TextStyle(color: _muted, height: 1.45))])),
            IconButton.filledTonal(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          ]),
          if (_busy || snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: const TextStyle(color: _cyan))),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.track_changes_rounded), label: Text('Opportunities')),
            ButtonSegment(value: 1, icon: Icon(Icons.sensors_rounded), label: Text('Evidence')),
            ButtonSegment(value: 2, icon: Icon(Icons.model_training_rounded), label: Text('Models')),
            ButtonSegment(value: 3, icon: Icon(Icons.route_rounded), label: Text('Field + Team')),
            ButtonSegment(value: 4, icon: Icon(Icons.notifications_active_outlined), label: Text('Alerts')),
          ], selected: {_tab}, onSelectionChanged: (v) => setState(() => _tab = v.first))),
          const SizedBox(height: 12),
          if (_tab == 0) ...[
            if (_routeSelection.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Expanded(child: Text('${_routeSelection.length} selected for field route', style: const TextStyle(fontWeight: FontWeight.w800))), TextButton(onPressed: () => setState(_routeSelection.clear), child: const Text('Clear')), FilledButton.icon(onPressed: _busy ? null : _buildRoute, icon: const Icon(Icons.route_rounded), label: const Text('Build route'))]))),
            if (_routeSelection.isNotEmpty) const SizedBox(height: 8),
            if (opportunities.isEmpty) _dataPanel('Ranked opportunities / Why Now', at(0), Icons.track_changes_rounded, const ['opportunities']) else ...opportunities.map(_opportunityCard),
            const SizedBox(height: 8),
            const Card(child: Padding(padding: EdgeInsets.all(13), child: Text('Opportunity ranking is decision support. Weather exposure, model scores and signals are not confirmed damage. Field feedback is written back to BridgePoint’s learning loop when the account/workspace allows it.', style: TextStyle(color: _muted, fontSize: 10, height: 1.45)))),
          ],
          if (_tab == 1) ...[
            _dataPanel('Signals / evidence', at(1), Icons.sensors_rounded, const ['signals','items','results']),
            const SizedBox(height: 10),
            _dataPanel('Sources', at(2), Icons.hub_outlined, const ['sources','items','results']),
            const SizedBox(height: 10),
            _dataPanel('Source health / freshness', at(3), Icons.monitor_heart_outlined, const ['sources','items','results']),
          ],
          if (_tab == 2) _dataPanel('Models and intelligence definitions', at(4), Icons.model_training_rounded, const ['models','items','results']),
          if (_tab == 3) ...[
            _dataPanel('Watchlists / saved work', at(5), Icons.bookmark_outline_rounded, const ['watchlists','items']),
            const SizedBox(height: 10),
            if (routes.isEmpty) _dataPanel('Routes / offline packs', at(6), Icons.route_rounded, const ['routes','items']) else ...routes.map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _routeCard(r))),
            const SizedBox(height: 10),
            _dataPanel('Team workspace', at(7), Icons.groups_2_outlined, const ['members','team','items']),
            const SizedBox(height: 10),
            Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Invite team member', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 300, child: TextField(controller: _inviteEmail, decoration: const InputDecoration(labelText: 'Email'))),
                SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: _inviteRole, items: const [DropdownMenuItem(value: 'FIELD', child: Text('Field')),DropdownMenuItem(value: 'SUPERVISOR', child: Text('Supervisor')),DropdownMenuItem(value: 'ADMIN', child: Text('Admin'))], onChanged: (v) => setState(() => _inviteRole = v ?? 'FIELD'), decoration: const InputDecoration(labelText: 'Role'))),
                FilledButton.icon(onPressed: _busy ? null : _invite, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Invite')),
              ]),
            ]))),
            const SizedBox(height: 10),
            _dataPanel('Field team', at(8), Icons.engineering_outlined, const ['members','team','items']),
            const SizedBox(height: 10),
            _dataPanel('Field note of the day', at(9), Icons.sticky_note_2_outlined, const ['items']),
          ],
          if (_tab == 4) ...[
            if (notifications.isEmpty) _dataPanel('Notifications / follow-ups', at(10), Icons.notifications_active_outlined, const ['notifications','items']) else ...notifications.map((row) => Card(child: ListTile(title: Text('${row['title'] ?? row['message'] ?? 'Notification'}'), subtitle: Text('${row['message'] ?? row['created_at'] ?? ''}'), trailing: TextButton(onPressed: () => _markRead(row), child: const Text('Mark read'))))),
          ],
        ]);
      },
    );
  }
}

class _CompactMap extends StatelessWidget {
  const _CompactMap(this.value);
  final Map<String, dynamic> value;
  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const Text('No data returned.', style: TextStyle(color: Color(0xFF8FA5BF)));
    return Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF081625), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x2235D2E8))), child: Wrap(spacing: 10, runSpacing: 6, children: value.entries.take(24).map((e) { final raw='${e.value}'; final text=raw.length>220?'${raw.substring(0,220)}…':raw; return ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text('${e.key.replaceAll('_',' ')}: $text', style: const TextStyle(fontSize: 9, height: 1.35))); }).toList()));
  }
}
