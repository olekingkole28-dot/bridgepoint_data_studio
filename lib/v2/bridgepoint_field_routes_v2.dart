import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointFieldRoutesV2 extends StatefulWidget {
  const BridgePointFieldRoutesV2({super.key});

  @override
  State<BridgePointFieldRoutesV2> createState() => _BridgePointFieldRoutesV2State();
}

class _BridgePointFieldRoutesV2State extends State<BridgePointFieldRoutesV2> {
  late Future<dynamic> _request;
  bool _busy = false;
  String? _message;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _statuses = <String>[
    'NAVIGATING',
    'ARRIVED',
    'CONTACTED',
    'NOT_HOME',
    'FOLLOW_UP',
    'APPOINTMENT',
    'INSPECTION',
    'SKIP',
    'COMPLETED',
  ];

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _load() => Supabase.instance.client.rpc(
        'bridgepoint_route_plans_v87',
        params: {'p_status': null, 'p_limit': 100},
      );

  void _refresh() => setState(() => _request = _load());

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const ['routes', 'items', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  List<Map<String, dynamic>> _stops(Map<String, dynamic> route) {
    final value = route['stops'];
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Future<void> _prepareOffline(Map<String, dynamic> route) async {
    final id = '${route['route_plan_id'] ?? route['id'] ?? ''}';
    if (id.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_prepare_offline_route_v154',
        params: {'p_route_plan_id': id, 'p_hours': 24},
      );
      final result = _map(raw);
      if (mounted) {
        setState(() => _message =
            '${result['message'] ?? 'Offline route pack prepared for 24 hours.'}');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Offline pack unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStop(
    Map<String, dynamic> route,
    int stopIndex,
    String status,
    String? note,
  ) async {
    final routeId = '${route['route_plan_id'] ?? route['id'] ?? ''}';
    if (routeId.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_route_stop_update_v154',
        params: {
          'p_route_plan_id': routeId,
          'p_stop_index': stopIndex,
          'p_status': status,
          'p_note': note,
          'p_client_event_id': null,
          'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
          'p_source_mode': 'ONLINE',
        },
      );
      final result = _map(raw);
      if (mounted) {
        setState(() {
          _message =
              'Stop $stopIndex → ${result['status'] ?? status.replaceAll('_', ' ')}';
          _request = _load();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not update route stop: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showStopActions(
    Map<String, dynamic> route,
    int stopIndex,
    Map<String, dynamic> stop,
  ) async {
    var status = '${stop['status'] ?? 'ARRIVED'}'.toUpperCase();
    if (!_statuses.contains(status)) status = 'ARRIVED';
    final note = TextEditingController(text: '${stop['last_note'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Stop $stopIndex'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${stop['full_address'] ?? stop['address'] ?? stop['property_address'] ?? 'Property stop'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if ('${stop['why_now'] ?? stop['explanation'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${stop['why_now'] ?? stop['explanation']}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: _statuses
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.replaceAll('_', ' ')),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setLocal(() => status = value ?? 'ARRIVED'),
                  decoration: const InputDecoration(labelText: 'Field status'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Field note',
                    hintText: 'What happened at this stop?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Record field event'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      await _updateStop(
        route,
        stopIndex,
        status,
        note.text.trim().isEmpty ? null : note.text.trim(),
      );
    }
    note.dispose();
  }

  Widget _routeCard(Map<String, dynamic> route) {
    final stops = _stops(route);
    final status = '${route['route_status'] ?? route['status'] ?? 'DRAFT'}';
    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1635D2E8),
          child: Icon(Icons.route_rounded, color: _cyan),
        ),
        title: Text(
          '${route['route_name'] ?? route['name'] ?? 'Field route'}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${route['stop_count'] ?? stops.length} stops • ${status.replaceAll('_', ' ')}',
          style: const TextStyle(color: _muted),
        ),
        trailing: IconButton(
          tooltip: 'Prepare 24-hour offline pack',
          onPressed: _busy ? null : () => _prepareOffline(route),
          icon: const Icon(Icons.offline_pin_outlined),
        ),
        children: [
          if (stops.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No route stops returned.',
                  style: TextStyle(color: _muted),
                ),
              ),
            )
          else
            for (var i = 0; i < stops.length; i++)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 15,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 10)),
                ),
                title: Text(
                  '${stops[i]['full_address'] ?? stops[i]['address'] ?? stops[i]['property_address'] ?? 'Property stop'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${stops[i]['status'] ?? 'PLANNED'}${stops[i]['recommended_action'] == null ? '' : ' • ${stops[i]['recommended_action']}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
                trailing: FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _showStopActions(route, i + 1, stops[i]),
                  child: const Text('Update'),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _request,
      builder: (context, snapshot) {
        final routes = _rows(snapshot.data);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Field Route Execution',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Each stop update is an auditable BridgePoint field event. Offline packs remain time-bounded and sync back through the same route ledger.',
                        style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _refresh,
                  tooltip: 'Refresh routes',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_busy || snapshot.connectionState == ConnectionState.waiting) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: const TextStyle(color: _cyan)),
            ],
            const SizedBox(height: 10),
            if (snapshot.hasError)
              Text(
                'Could not load field routes: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFFFF7E7E)),
              )
            else if (routes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No saved field routes yet. Select ranked opportunities in Operations and build a route first.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              )
            else
              ...routes.map((route) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _routeCard(route),
                  )),
          ],
        );
      },
    );
  }
}
