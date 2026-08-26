import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointSavedAlertsV2 extends StatefulWidget {
  const BridgePointSavedAlertsV2({super.key});

  @override
  State<BridgePointSavedAlertsV2> createState() => _BridgePointSavedAlertsV2State();
}

class _BridgePointSavedAlertsV2State extends State<BridgePointSavedAlertsV2> {
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);

  late Future<List<dynamic>> _request;
  int _tab = 0;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _publicRpc(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (e) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<dynamic> _apiRpc(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.schema('api').rpc(name, params: params);
    } catch (e) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _publicRpc('bridgepoint_notifications_v74', {'p_limit': 100}),
        _publicRpc('bridgepoint_customer_notes_v70', {
          'p_property_id': null,
          'p_limit': 200,
        }),
        _apiRpc('my_favorites'),
        _apiRpc('my_saved_searches'),
        _publicRpc('bridgepoint_watchlists_v88'),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value, [List<String> keys = const []]) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in keys) {
        if (value[key] is List) return _rows(value[key]);
      }
      for (final key in const ['items', 'rows', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Future<void> _reload([String? message]) async {
    if (!mounted) return;
    setState(() {
      _message = message;
      _request = _load();
    });
  }

  Future<void> _markRead(String id) async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_mark_notifications_read_v74',
        params: {'p_notification_id': id},
      );
      await _reload('Notification marked read.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not update notification: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.schema('api').rpc('mark_all_notifications_read');
      await _reload('All notifications marked read.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not update notifications: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createSavedSearch() async {
    final name = TextEditingController();
    final query = TextEditingController();
    var frequency = 'daily';
    var alert = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Save a search'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Search name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: query,
                  decoration: const InputDecoration(
                    labelText: 'Search text',
                    hintText: 'storm roof Middletown',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: alert,
                  title: const Text('Alert me when results change'),
                  onChanged: (value) => setLocal(() => alert = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Alert frequency'),
                  items: const [
                    DropdownMenuItem(value: 'realtime', child: Text('Realtime / eligible refresh')), 
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  ],
                  onChanged: alert
                      ? (value) => setLocal(() => frequency = value ?? 'daily')
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != true || name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.schema('api').rpc(
        'save_search',
        params: {
          'p_name': name.text.trim(),
          'p_query_text': query.text.trim(),
          'p_entity_types': ['property'],
          'p_filters': <String, dynamic>{},
          'p_alert_enabled': alert,
          'p_alert_frequency': alert ? frequency : 'off',
        },
      );
      await _reload('Saved search created.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save search: $e');
    } finally {
      name.dispose();
      query.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createWatchlist() async {
    final name = TextEditingController();
    var type = 'properties';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create company watchlist'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Watchlist name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'properties', child: Text('Properties')),
                    DropdownMenuItem(value: 'territory', child: Text('Territory')),
                    DropdownMenuItem(value: 'opportunities', child: Text('Opportunities')),
                  ],
                  onChanged: (value) => setLocal(() => type = value ?? 'properties'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (result != true || name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_create_watchlist_v88',
        params: {'p_name': name.text.trim(), 'p_type': type},
      );
      await _reload('Watchlist created.');
    } catch (e) {
      if (mounted) {
        setState(() => _message =
            'Watchlists use a Company workspace. Could not create this one: $e');
      }
    } finally {
      name.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        dynamic at(int i) => i < values.length ? values[i] : const <String, dynamic>{};
        final notificationsPayload = _map(at(0));
        final notesPayload = _map(at(1));
        final favoritesPayload = at(2);
        final searchesPayload = at(3);
        final watchlistsPayload = _map(at(4));
        final notifications = _rows(notificationsPayload, const ['notifications']);
        final notes = _rows(notesPayload, const ['notes']);
        final favorites = _rows(favoritesPayload);
        final searches = _rows(searchesPayload);
        final watchlists = _rows(watchlistsPayload, const ['watchlists']);
        final unread = (notificationsPayload['unread_count'] as num?)?.toInt() ??
            notifications.where((n) => n['read_at'] == null).length;
        final followUps = notes.where((n) => n['follow_up_at'] != null).length;
        final waiting = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved & Alerts',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Favorites, saved-search alerts, company watchlists, property notes, follow-ups and the live BridgePoint notification inbox.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh saved intelligence',
                  onPressed: waiting || _busy ? null : () => _reload(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (waiting || _busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: const TextStyle(color: _cyan, fontSize: 10)),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 1050 ? 5 : c.maxWidth >= 650 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 9) / columns;
                final metrics = [
                  ('UNREAD', '$unread', 'Notifications', Icons.notifications_active_outlined, _red),
                  ('FOLLOW-UPS', '$followUps', 'Notes with dates', Icons.event_available_outlined, _amber),
                  ('FAVORITES', '${favorites.length}', 'Saved entities', Icons.star_rounded, _amber),
                  ('SAVED SEARCHES', '${searches.length}', 'Reusable searches', Icons.manage_search_rounded, _cyan),
                  ('WATCHLISTS', '${watchlists.length}', 'Company lists', Icons.visibility_outlined, _green),
                ];
                return Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final m in metrics)
                      SizedBox(
                        width: width,
                        child: _Metric(
                          label: m.$1,
                          value: m.$2,
                          detail: m.$3,
                          icon: m.$4,
                          color: m.$5,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.notifications_none_rounded),
                    label: Text('Notifications'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.note_alt_outlined),
                    label: Text('Notes & follow-ups'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.star_outline_rounded),
                    label: Text('Favorites'),
                  ),
                  ButtonSegment(
                    value: 3,
                    icon: Icon(Icons.manage_search_rounded),
                    label: Text('Saved searches'),
                  ),
                  ButtonSegment(
                    value: 4,
                    icon: Icon(Icons.visibility_outlined),
                    label: Text('Watchlists'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (value) => setState(() => _tab = value.first),
              ),
            ),
            const SizedBox(height: 12),
            switch (_tab) {
              0 => _Notifications(
                  rows: notifications,
                  unread: unread,
                  onRead: _markRead,
                  onReadAll: _markAllRead,
                ),
              1 => _Notes(rows: notes),
              2 => _Favorites(rows: favorites, error: _map(favoritesPayload)['error']),
              3 => _SavedSearches(
                  rows: searches,
                  error: _map(searchesPayload)['error'],
                  onCreate: _createSavedSearch,
                ),
              _ => _Watchlists(
                  rows: watchlists,
                  error: watchlistsPayload['error'],
                  onCreate: _createWatchlist,
                ),
            },
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _BridgePointSavedAlertsV2State._panel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: .13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: _BridgePointSavedAlertsV2State._muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                color: _BridgePointSavedAlertsV2State._muted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BridgePointSavedAlertsV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _Notifications extends StatelessWidget {
  const _Notifications({
    required this.rows,
    required this.unread,
    required this.onRead,
    required this.onReadAll,
  });
  final List<Map<String, dynamic>> rows;
  final int unread;
  final Future<void> Function(String id) onRead;
  final Future<void> Function() onReadAll;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Notification inbox',
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: onReadAll,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Mark all read'),
            ),
        ],
        child: rows.isEmpty
            ? const _Empty('No notifications right now.')
            : Column(
                children: [
                  for (final row in rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _BridgePointSavedAlertsV2State._soft.withValues(alpha: .68),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: row['read_at'] == null
                              ? _BridgePointSavedAlertsV2State._cyan.withValues(alpha: .2)
                              : Colors.white.withValues(alpha: .04),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            row['read_at'] == null
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            color: row['read_at'] == null
                                ? _BridgePointSavedAlertsV2State._cyan
                                : _BridgePointSavedAlertsV2State._muted,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['title'] ?? row['notification_type'] ?? 'BridgePoint notification'}',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${row['message'] ?? ''}',
                                  style: const TextStyle(
                                    color: _BridgePointSavedAlertsV2State._muted,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${row['created_at'] ?? ''}',
                                  style: const TextStyle(
                                    color: _BridgePointSavedAlertsV2State._muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (row['read_at'] == null && row['notification_id'] != null)
                            IconButton(
                              tooltip: 'Mark read',
                              onPressed: () => onRead('${row['notification_id']}'),
                              icon: const Icon(Icons.done_rounded, size: 18),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      );
}

class _Notes extends StatelessWidget {
  const _Notes({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Property notes & follow-ups',
        child: rows.isEmpty
            ? const _Empty('No property notes or follow-ups yet. Add notes from property workflows and they will appear here.')
            : Column(
                children: [
                  for (final row in rows)
                    _DataRow(
                      icon: row['follow_up_at'] != null ? Icons.event_available_rounded : Icons.note_alt_outlined,
                      color: row['follow_up_at'] != null
                          ? _BridgePointSavedAlertsV2State._amber
                          : _BridgePointSavedAlertsV2State._cyan,
                      title: '${row['note_text'] ?? row['preset_key'] ?? 'Property note'}',
                      subtitle:
                          'Status ${row['status'] ?? 'active'} • property ${row['property_id'] ?? '—'}${row['follow_up_at'] == null ? '' : ' • follow-up ${row['follow_up_at']}'}',
                    ),
                ],
              ),
      );
}

class _Favorites extends StatelessWidget {
  const _Favorites({required this.rows, this.error});
  final List<Map<String, dynamic>> rows;
  final dynamic error;
  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Favorites',
        child: error != null
            ? _Empty('Favorites are not available for this session: $error')
            : rows.isEmpty
                ? const _Empty('No favorites yet. Favorite properties and other supported entities from their detail views.')
                : Column(
                    children: [
                      for (final row in rows)
                        _DataRow(
                          icon: Icons.star_rounded,
                          color: _BridgePointSavedAlertsV2State._amber,
                          title: '${row['entity_type'] ?? 'entity'} • ${row['entity_id'] ?? ''}',
                          subtitle: '${row['notes'] ?? 'Saved ${row['created_at'] ?? ''}'}',
                        ),
                    ],
                  ),
      );
}

class _SavedSearches extends StatelessWidget {
  const _SavedSearches({required this.rows, required this.onCreate, this.error});
  final List<Map<String, dynamic>> rows;
  final VoidCallback onCreate;
  final dynamic error;
  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Saved searches & alerts',
        actions: [
          FilledButton.tonalIcon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Save search'),
          ),
        ],
        child: error != null
            ? _Empty('Saved searches are not available for this session: $error')
            : rows.isEmpty
                ? const _Empty('No saved searches yet. Save a reusable property search and optionally turn on alerts.')
                : Column(
                    children: [
                      for (final row in rows)
                        _DataRow(
                          icon: row['alert_enabled'] == true
                              ? Icons.notifications_active_outlined
                              : Icons.manage_search_rounded,
                          color: row['alert_enabled'] == true
                              ? _BridgePointSavedAlertsV2State._green
                              : _BridgePointSavedAlertsV2State._cyan,
                          title: '${row['name'] ?? row['query_text'] ?? 'Saved search'}',
                          subtitle:
                              '${row['query_text'] ?? ''}${row['alert_enabled'] == true ? ' • alerts ${row['alert_frequency'] ?? 'on'}' : ' • alerts off'} • last results ${row['last_result_count'] ?? '—'}',
                        ),
                    ],
                  ),
      );
}

class _Watchlists extends StatelessWidget {
  const _Watchlists({required this.rows, required this.onCreate, this.error});
  final List<Map<String, dynamic>> rows;
  final VoidCallback onCreate;
  final dynamic error;
  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Company watchlists',
        actions: [
          FilledButton.tonalIcon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New watchlist'),
          ),
        ],
        child: error != null
            ? const _Empty('Watchlists are available inside a BridgePoint Company workspace. Personal favorites and saved searches still work without one.')
            : rows.isEmpty
                ? const _Empty('No company watchlists yet.')
                : Column(
                    children: [
                      for (final row in rows)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.visibility_outlined,
                            color: _BridgePointSavedAlertsV2State._green,
                          ),
                          title: Text(
                            '${row['name'] ?? 'Watchlist'}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${row['type'] ?? 'properties'} • ${row['item_count'] ?? 0} items',
                            style: const TextStyle(
                              color: _BridgePointSavedAlertsV2State._muted,
                              fontSize: 12.5,
                            ),
                          ),
                          children: [
                            for (final item in (row['items'] is List
                                ? (row['items'] as List).whereType<Map>()
                                : const <Map>[]))
                              Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${item['item_label'] ?? item['item_key'] ?? item['property_id'] ?? 'Watchlist item'}',
                                    style: const TextStyle(
                                      color: _BridgePointSavedAlertsV2State._muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
      );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _BridgePointSavedAlertsV2State._soft.withValues(alpha: .68),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _BridgePointSavedAlertsV2State._muted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BridgePointSavedAlertsV2State._muted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      );
}
