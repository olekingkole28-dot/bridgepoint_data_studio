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

  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);

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

  Future<void> _updateRouteStop(Map<String, dynamic> route, Map<String, dynamic> stop, int stopIndex) async {
    final routeId = '${route['route_plan_id'] ?? route['id'] ?? ''}';
    if (routeId.isEmpty || stopIndex < 1) return;
    var status = '${stop['status'] ?? 'ARRIVED'}'.toUpperCase();
    const allowed = ['PLANNED','NAVIGATING','ARRIVED','CONTACTED','NOT_HOME','FOLLOW_UP','APPOINTMENT','INSPECTION','SKIP','COMPLETED'];
    if (!allowed.contains(status)) status = 'ARRIVED';
    final note = TextEditingController(text: '${stop['last_note'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: Text('Update stop $stopIndex'),
        content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${stop['address'] ?? stop['opportunity_name'] ?? 'Route stop'}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Field status'),
            items: allowed.map((value) => DropdownMenuItem(value: value, child: Text(value.replaceAll('_', ' ')))).toList(),
            onChanged: (value) => setLocal(() => status = value ?? status),
          ),
          const SizedBox(height: 10),
          TextField(controller: note, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Field note', hintText: 'Contact result, inspection note, follow-up context...')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.task_alt_rounded), label: const Text('Record update')),
        ],
      )),
    );
    if (ok != true) { note.dispose(); return; }
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_route_stop_update_v154', params: {
        'p_route_plan_id': routeId,
        'p_stop_index': stopIndex,
        'p_status': status,
        'p_note': note.text.trim().isEmpty ? null : note.text.trim(),
        'p_source_mode': 'ONLINE',
      });
      final result = _map(raw);
      if (mounted) setState(() {
        _message = 'Stop $stopIndex recorded as ${result['status'] ?? status}.';
        _request = _load();
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Route stop update unavailable: $e');
    } finally {
      note.dispose();
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
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 5, children: [
            if (opportunityId.isNotEmpty)
              Checkbox(value: selected, onChanged: _busy ? null : (value) => setState(() => value == true ? _routeSelection.add(opportunityId) : _routeSelection.remove(opportunityId))),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text('${row['title'] ?? row['full_address'] ?? 'Opportunity'}', style: const TextStyle(fontWeight: FontWeight.w900))),
            if (score != null) Chip(label: Text('Score $score')),
          ]),
          if ('${row['full_address'] ?? ''}'.isNotEmpty) Text('${row['full_address']}', style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
          Text('${row['direct_source_count'] ?? 0} direct sources • ${row['independent_evidence_families'] ?? row['evidence_families'] ?? 'evidence families unavailable'}', style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _routeCard(Map<String, dynamic> route) {
    final stops = _rows(route['stops'], const ['items']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text('${route['route_name'] ?? route['name'] ?? 'Field route'}', style: const TextStyle(fontWeight: FontWeight.w900))),
            Chip(label: Text('${route['route_status'] ?? route['status'] ?? 'DRAFT'}')),
          ]),
          const SizedBox(height: 5),
          Text('${route['stop_count'] ?? stops.length} stops • ${route['optimization_strategy'] ?? 'BridgePoint route ordering'}', style: const TextStyle(color: _muted)),
          if (route['scheduled_for'] != null) Text('Scheduled ${route['scheduled_for']}', style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(onPressed: _busy ? null : () => _prepareOffline(route), icon: const Icon(Icons.offline_pin_outlined), label: const Text('Prepare 24h offline pack')),
          ]),
          if (stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Field stops (${stops.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
              children: [
                for (var i = 0; i < stops.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF081625), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x2235D2E8))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 5, children: [
                          CircleAvatar(radius: 14, backgroundColor: const Color(0x1835D2E8), child: Text('${i + 1}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900))),
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Text('${stops[i]['address'] ?? stops[i]['opportunity_name'] ?? 'Route stop ${i + 1}'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          Chip(label: Text('${stops[i]['status'] ?? 'PLANNED'}')),
                        ]),
                        if ('${stops[i]['why_now'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('${stops[i]['why_now']}', style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4))),
                        if ('${stops[i]['last_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Last note: ${stops[i]['last_note']}', style: const TextStyle(fontSize: 10))),
                        const SizedBox(height: 7),
                        Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _busy ? null : () => _updateRouteStop(route, stops[i], i + 1), icon: const Icon(Icons.edit_location_alt_outlined), label: const Text('Update field status'))),
                      ]),
                    ),
                  ),
              ],
            ),
          ],
        ]),
      ),
    );
  }

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
            if (_routeSelection.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(10), child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [Text('${_routeSelection.length} selected for field route', style: const TextStyle(fontWeight: FontWeight.w800)), TextButton(onPressed: () => setState(_routeSelection.clear), child: const Text('Clear')), FilledButton.icon(onPressed: _busy ? null : _buildRoute, icon: const Icon(Icons.route_rounded), label: const Text('Build route'))]))),
            if (_routeSelection.isNotEmpty) const SizedBox(height: 8),
            if (opportunities.isEmpty) _dataPanel('Ranked opportunities / Why Now', at(0), Icons.track_changes_rounded, const ['opportunities']) else ...opportunities.map(_opportunityCard),
            const SizedBox(height: 8),
            const Card(child: Padding(padding: EdgeInsets.all(13), child: Text('Opportunity ranking is decision support. Weather exposure, model scores and signals are not confirmed damage. Field feedback is written back to BridgePoint’s learning loop when the account/workspace allows it.', style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45)))),
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

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  String _clean(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text.replaceAll('_', ' ');
  }

  String _title() {
    for (final key in const ['title','signal_name','model_name','display_name','route_name','name','source_name','provider']) {
      final v = _clean(value[key]);
      if (v.isNotEmpty) return v;
    }
    return 'BridgePoint intelligence';
  }

  String _subtitle() {
    for (final key in const ['description','customer_outcome','best_for','full_address','privacy','note','message']) {
      final v = _clean(value[key]);
      if (v.isNotEmpty) return v;
    }
    return 'Live BridgePoint workspace data';
  }

  List<MapEntry<String, dynamic>> _details() {
    const preferred = [
      'status','state_code','municipality','county','severity','strength','confidence',
      'source_count','evidence_count','signal_family','model_category','target_entity_type',
      'strict_queue_status','strict_qualified_count','member_role','active','joined_at',
      'stop_count','route_status','scheduled_for','health_status','freshness_status',
      'total_records_ingested','last_successful_import_at','your_pending_count'
    ];
    final out = <MapEntry<String,dynamic>>[];
    for (final key in preferred) {
      final v = value[key];
      if (v == null || _clean(v).isEmpty || v is Map || v is List) continue;
      out.add(MapEntry(key,v));
    }
    return out.take(8).toList();
  }

  String _label(String key) => key
      .replaceAll('_',' ')
      .split(' ')
      .where((x) => x.isNotEmpty)
      .map((x) => '${x[0].toUpperCase()}${x.substring(1)}')
      .join(' ');

  Color _accent() {
    final status = _clean(value['status'] ?? value['health_status'] ?? value['strict_queue_status']).toLowerCase();
    if (status.contains('fail') || status.contains('error') || status.contains('critical')) return _amber;
    if (status.contains('live') || status.contains('healthy') || status.contains('active')) return _green;
    if (value['severity'] is num && (value['severity'] as num) >= 70) return _amber;
    return _cyan;
  }

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty || value['available'] == false) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: const Row(children: [
          Icon(Icons.hourglass_empty_rounded, color: _cyan),
          SizedBox(width: 11),
          Expanded(child: Text('This workspace section is still building or has no customer-facing results yet.', style: TextStyle(color: _muted, fontWeight: FontWeight.w600))),
        ]),
      );
    }
    final accent = _accent();
    final details = _details();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent.withValues(alpha: .10), const Color(0xFF0E2035)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .22)),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0,6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.insights_rounded, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_subtitle(), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, height: 1.4, fontWeight: FontWeight.w600)),
          ])),
        ]),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in details)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFF081625), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .08))),
                child: Text('${_label(e.key)}: ${_clean(e.value)}', style: TextStyle(color: e.key.contains('status') ? accent : _muted, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
          ]),
        ],
      ]),
    );
  }
}
