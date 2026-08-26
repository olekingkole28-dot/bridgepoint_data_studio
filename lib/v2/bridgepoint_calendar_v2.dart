import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointCalendarV2 extends StatefulWidget {
  const BridgePointCalendarV2({super.key});

  @override
  State<BridgePointCalendarV2> createState() => _BridgePointCalendarV2State();
}

class _BridgePointCalendarV2State extends State<BridgePointCalendarV2> {
  late Future<Map<String, dynamic>> _request;
  bool _busy = false;
  String? _message;

  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);
  static const _amber = Color(0xFFFFC95E);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {'value': value};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> _load() async {
    final now = DateTime.now();
    final raw = await Supabase.instance.client.rpc(
      'bridgepoint_calendar_agenda_v835',
      params: {
        'p_start_at': now.subtract(const Duration(days: 7)).toUtc().toIso8601String(),
        'p_end_at': now.add(const Duration(days: 45)).toUtc().toIso8601String(),
        'p_limit': 750,
      },
    );
    return _map(raw);
  }

  void _refresh() => setState(() => _request = _load());

  DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse('$value')?.toLocal();

  String _when(dynamic value) {
    final dt = _date(value);
    if (dt == null) return 'Unscheduled';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final delta = day.difference(today).inDays;
    final label = delta == 0 ? 'Today' : delta == 1 ? 'Tomorrow' : delta == -1 ? 'Yesterday' : '${dt.month}/${dt.day}/${dt.year}';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$label • $hour:$minute $ampm';
  }

  Color _kindColor(String kind) => switch (kind) {
        'CLAIM' || 'CLAIM_TASK' => const Color(0xFFFFC95E),
        'ROUTE' => const Color(0xFF45E6A6),
        'SAVED_OPPORTUNITY' => _cyan,
        _ => const Color(0xFFB79CFF),
      };

  Future<void> _createEvent() async {
    final title = TextEditingController();
    final start = TextEditingController();
    final end = TextEditingController();
    final notes = TextEditingController();
    String type = 'FOLLOW_UP';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add calendar item'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'FOLLOW_UP', child: Text('Follow-up')),
                    DropdownMenuItem(value: 'APPOINTMENT', child: Text('Appointment')),
                    DropdownMenuItem(value: 'INSPECTION', child: Text('Inspection')),
                    DropdownMenuItem(value: 'FIELD_VISIT', child: Text('Field visit')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 10),
                TextField(controller: start, decoration: const InputDecoration(labelText: 'Start (ISO or YYYY-MM-DD HH:MM)')),
                const SizedBox(height: 10),
                TextField(controller: end, decoration: const InputDecoration(labelText: 'End (optional)')),
                const SizedBox(height: 10),
                TextField(controller: notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true) {
      title.dispose(); start.dispose(); end.dispose(); notes.dispose();
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      DateTime parse(String value) {
        final direct = DateTime.tryParse(value.trim());
        if (direct == null) throw const FormatException('Use a valid date/time.');
        return direct;
      }
      final startsAt = parse(start.text);
      final endsAt = end.text.trim().isEmpty ? null : parse(end.text);
      await Supabase.instance.client.rpc('bridgepoint_calendar_event_upsert_v835', params: {
        'p_calendar_event_id': null,
        'p_title': title.text.trim(),
        'p_event_type': type,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
        'p_property_id': null,
        'p_opportunity_id': null,
        'p_claim_id': null,
        'p_route_plan_id': null,
        'p_notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
        'p_status': 'SCHEDULED',
      });
      if (mounted) setState(() { _message = 'Calendar item added.'; _request = _load(); });
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not add this calendar item. Check the date/time and try again.');
    } finally {
      title.dispose(); start.dispose(); end.dispose(); notes.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCustom(Map<String, dynamic> event) async {
    final id = '${event['source_id'] ?? ''}';
    if (id.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.rpc('bridgepoint_calendar_event_delete_v835', params: {'p_calendar_event_id': id});
      if (mounted) setState(() { _message = 'Calendar item removed.'; _request = _load(); });
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not remove this calendar item right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scheduleRoute(Map<String, dynamic> route) async {
    final input = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Schedule ${route['route_name'] ?? 'route'}'),
        content: SizedBox(width: 420, child: TextField(controller: input, decoration: const InputDecoration(labelText: 'Date/time (ISO or YYYY-MM-DD HH:MM)'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Schedule')),
        ],
      ),
    );
    if (ok != true) { input.dispose(); return; }
    setState(() { _busy = true; _message = null; });
    try {
      final dt = DateTime.tryParse(input.text.trim());
      if (dt == null) throw const FormatException('Use a valid date/time.');
      await Supabase.instance.client.rpc('bridgepoint_schedule_route_v835', params: {
        'p_route_plan_id': route['route_plan_id'],
        'p_scheduled_for': dt.toUtc().toIso8601String(),
      });
      if (mounted) setState(() { _message = 'Route scheduled.'; _request = _load(); });
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not schedule this route. Check the date/time and try again.');
    } finally {
      input.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final kind = '${event['source_kind'] ?? event['event_type'] ?? 'CUSTOM'}'.toUpperCase();
    final color = _kindColor(kind);
    final address = '${event['address'] ?? ''}'.trim();
    final recommended = '${event['recommended_action'] ?? ''}'.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 4, height: 70, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${event['title'] ?? 'Calendar item'}', style: const TextStyle(fontWeight: FontWeight.w900))),
              Chip(label: Text(kind.replaceAll('_', ' '))),
            ]),
            Text(_when(event['starts_at']), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            if (address.isNotEmpty) ...[const SizedBox(height: 3), Text(address, style: const TextStyle(color: _muted, fontSize: 10))],
            if (recommended.isNotEmpty) ...[const SizedBox(height: 4), Text('Next: $recommended', style: const TextStyle(color: _muted, fontSize: 10))],
          ])),
          if (kind == 'CUSTOM') IconButton(tooltip: 'Remove', onPressed: _busy ? null : () => _deleteCustom(event), icon: const Icon(Icons.delete_outline_rounded)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final events = _rows(data['events']);
        final routes = _rows(data['unscheduled_routes']);
        final now = DateTime.now();
        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        final today = events.where((e) {
          final dt = _date(e['starts_at']);
          return dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day;
        }).toList();
        final upcoming = events.where((e) {
          final dt = _date(e['starts_at']);
          return dt != null && dt.isAfter(todayEnd);
        }).toList();
        final overdue = events.where((e) {
          final dt = _date(e['starts_at']);
          return dt != null && dt.isBefore(DateTime(now.year, now.month, now.day));
        }).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Calendar & Day Plan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('Follow-ups, claim tasks, appointments and scheduled field routes from real BridgePoint workflow dates.', style: TextStyle(color: _muted, height: 1.45)),
            ])),
            IconButton.filledTonal(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          ]),
          if (_busy || snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: const TextStyle(color: _cyan))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _busy ? null : _createEvent, icon: const Icon(Icons.add_rounded), label: const Text('Add appointment / follow-up')),
            Chip(label: Text('${today.length} today')),
            Chip(label: Text('${upcoming.length} upcoming')),
            if (overdue.isNotEmpty) Chip(label: Text('${overdue.length} overdue')),
          ]),
          const SizedBox(height: 14),
          if (today.isNotEmpty) ...[
            const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...today.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _eventCard(e))),
            const SizedBox(height: 8),
          ],
          if (overdue.isNotEmpty) ...[
            const Text('Needs attention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _amber)),
            const SizedBox(height: 8),
            ...overdue.take(30).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _eventCard(e))),
            const SizedBox(height: 8),
          ],
          const Text('Upcoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No upcoming dated workflow items in the current window.', style: TextStyle(color: _muted))))
          else
            ...upcoming.take(100).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _eventCard(e))),
          if (routes.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Unscheduled field routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('These routes exist but do not have a real scheduled date yet.', style: TextStyle(color: _muted)),
            const SizedBox(height: 8),
            ...routes.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(child: ListTile(
                leading: const Icon(Icons.route_rounded, color: Color(0xFF45E6A6)),
                title: Text('${r['route_name'] ?? 'Field route'}'),
                subtitle: Text('${r['stop_count'] ?? 0} stops • ${r['route_status'] ?? 'DRAFT'}'),
                trailing: FilledButton.tonal(onPressed: _busy ? null : () => _scheduleRoute(r), child: const Text('Schedule')),
              )),
            )),
          ],
          const SizedBox(height: 12),
          Text('${data['truth_notice'] ?? 'Agenda dates are explicit workflow dates, not inferred timestamps.'}', style: const TextStyle(color: _amber, fontSize: 12.5, height: 1.45)),
        ]);
      },
    );
  }
}
