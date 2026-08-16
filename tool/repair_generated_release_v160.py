from pathlib import Path

path=Path('lib/main.dart')
text=path.read_text(encoding='utf-8')

# Replace Material icon names that are not present in the current Flutter SDK.
text=text.replace('Icons.command_rounded','Icons.tune_rounded')
text=text.replace('Icons.shield_person_outlined','Icons.admin_panel_settings_outlined')

route_start=text.find('class _RouteOfflinePanel extends StatefulWidget{')
route_end=text.find('class _ModelsPage extends StatefulWidget {',route_start)
if route_start<0 or route_end<0:
    raise SystemExit('Generated route block not found')

route_block=r'''class _RouteOfflinePanel extends StatefulWidget {
  const _RouteOfflinePanel({required this.saved});
  final List<Map<String, dynamic>> saved;

  @override
  State<_RouteOfflinePanel> createState() => _RouteOfflinePanelState();
}

class _RouteOfflinePanelState extends State<_RouteOfflinePanel> {
  final SharedPreferencesAsync prefs = SharedPreferencesAsync();
  late Future<Map<String, dynamic>> routesRequest;
  Set<String> offlineReady = <String>{};
  int queuedOffline = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    routesRequest = _loadRoutes();
    unawaited(_loadLocalState());
    _bridgePointConnectionHealth.addListener(_connectionChanged);
  }

  @override
  void dispose() {
    _bridgePointConnectionHealth.removeListener(_connectionChanged);
    super.dispose();
  }

  void _connectionChanged() {
    if (!_bridgePointConnectionHealth.value.spotty) {
      unawaited(_syncPending(silent: true));
    }
  }

  Future<Map<String, dynamic>> _loadRoutes() =>
      _callRpc('bridgepoint_route_plans_v87', const {'p_status': null, 'p_limit': 50});

  void refresh() {
    if (!mounted) return;
    setState(() => routesRequest = _loadRoutes());
  }

  String _packKey(String routeId) => 'bp_offline_pack_$routeId';
  String _queueKey(String routeId) => 'bp_offline_queue_$routeId';

  Future<void> _loadLocalState() async {
    try {
      final keys = await prefs.getKeys();
      final ready = <String>{};
      var queueCount = 0;
      for (final key in keys) {
        if (key.startsWith('bp_offline_pack_')) {
          ready.add(key.substring('bp_offline_pack_'.length));
        }
        if (key.startsWith('bp_offline_queue_')) {
          final raw = await prefs.getString(key);
          if (raw != null) {
            final decoded = jsonDecode(raw);
            if (decoded is List) queueCount += decoded.length;
          }
        }
      }
      if (mounted) {
        setState(() {
          offlineReady = ready;
          queuedOffline = queueCount;
        });
      }
    } catch (_) {
      // Local state is supplemental; server routes remain authoritative.
    }
  }

  Future<void> _buildRoute() async {
    final ids = widget.saved
        .map((item) => item['opportunity_id'])
        .where((value) => value != null && '$value'.isNotEmpty)
        .map((value) => '$value')
        .take(20)
        .toList();
    if (ids.isEmpty) {
      if (mounted) {
        _showInfoDialog(
          context,
          'No routable saved opportunities',
          'Save a few BridgePoint opportunities first, then Build My Route will use them as stops.',
        );
      }
      return;
    }

    final controller = TextEditingController(
      text: 'Field Route ${DateTime.now().month}/${DateTime.now().day}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Build My Route'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Route name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'BridgePoint will use up to ${ids.length} saved opportunities and order nearby stops while keeping score, confidence, Why Now and photo status with each stop.',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.45),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Build route'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    setState(() => busy = true);
    try {
      final result = await _callRpc('bridgepoint_route_build_v154', {
        'p_route_name': name,
        'p_opportunity_ids': ids,
        'p_start_latitude': null,
        'p_start_longitude': null,
        'p_max_stops': 20,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route built with ${result['stop_count']} stops.')),
        );
        refresh();
      }
    } catch (e) {
      if (mounted) _showInfoDialog(context, 'Could not build route', '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _prepareOffline(Map<String, dynamic> route) async {
    setState(() => busy = true);
    try {
      final routeId = '${route['route_plan_id']}';
      final result = await _callRpc('bridgepoint_prepare_offline_route_v154', {
        'p_route_plan_id': routeId,
        'p_hours': 24,
      });
      await prefs.setString(_packKey(routeId), jsonEncode(result['payload']));
      await prefs.setString('bp_offline_active_route', routeId);
      await _loadLocalState();
      if (mounted) {
        _showInfoDialog(
          context,
          'Offline route ready',
          '${route['route_name']} is stored as a lean working set until ${_bpDateTime(result['expires_at'])}.\n\nFree-form customer notes are not cached. Signing out clears BridgePoint offline cache.',
        );
      }
    } catch (e) {
      if (mounted) _showInfoDialog(context, 'Could not prepare Offline Mode', '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _queueStopEvent(
    String routeId,
    int stopIndex,
    String status, {
    String? note,
  }) async {
    final key = _queueKey(routeId);
    final raw = await prefs.getString(key);
    final events = <dynamic>[];
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) events.addAll(decoded);
    }
    events.add({
      'route_plan_id': routeId,
      'stop_index': stopIndex,
      'status': status,
      'note': note,
      'client_event_id': _bpUuidV4(),
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    await prefs.setString(key, jsonEncode(events));
    await _loadLocalState();
  }

  Future<void> _updateStop(String routeId, int stopIndex, String status) async {
    if (_bridgePointConnectionHealth.value.spotty) {
      await _queueStopEvent(routeId, stopIndex, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved offline. BridgePoint will sync when service returns.')),
        );
      }
      return;
    }
    final eventId = _bpUuidV4();
    try {
      await _callRpc('bridgepoint_route_stop_update_v154', {
        'p_route_plan_id': routeId,
        'p_stop_index': stopIndex,
        'p_status': status,
        'p_note': null,
        'p_client_event_id': eventId,
        'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
        'p_source_mode': 'ONLINE',
      });
      refresh();
    } catch (_) {
      await _queueStopEvent(routeId, stopIndex, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network failed; the stop update was queued offline.')),
        );
      }
    }
  }

  Future<void> _syncPending({bool silent = false}) async {
    if (_bridgePointConnectionHealth.value.spotty) return;
    try {
      final keys = await prefs.getKeys();
      var reconciled = 0;
      var remainingFailures = 0;
      for (final key in keys.where((key) => key.startsWith('bp_offline_queue_'))) {
        final raw = await prefs.getString(key);
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! List || decoded.isEmpty) {
          await prefs.remove(key);
          continue;
        }
        final events = List<dynamic>.from(decoded);
        final result = await _callRpc('bridgepoint_offline_sync_v154', {'p_events': events});
        reconciled += (result['synced'] as num?)?.toInt() ?? 0;
        reconciled += (result['duplicates'] as num?)?.toInt() ?? 0;
        final failed = (result['failed'] as num?)?.toInt() ?? 0;
        remainingFailures += failed;
        if (failed == 0) {
          await prefs.remove(key);
        } else {
          final failedIds = _bpRows(result['failures'])
              .map((item) => '${item['client_event_id']}')
              .toSet();
          final remaining = events
              .where((event) => event is Map && failedIds.contains('${event['client_event_id']}'))
              .toList();
          await prefs.setString(key, jsonEncode(remaining));
        }
      }
      await _loadLocalState();
      refresh();
      if (!silent && mounted) {
        final message = remainingFailures == 0
            ? 'Offline sync complete • $reconciled update${reconciled == 1 ? '' : 's'} reconciled.'
            : 'Offline sync finished with $remainingFailures item${remainingFailures == 1 ? '' : 's'} still waiting.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!silent && mounted) _showInfoDialog(context, 'Offline sync could not finish', '$e');
    }
  }

  Future<void> _openRoute(Map<String, dynamic> route) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RouteDetailDialog(
        route: route,
        offlineReady: offlineReady.contains('${route['route_plan_id']}'),
        onPrepareOffline: () => _prepareOffline(route),
        onUpdate: (index, status) => _updateStop('${route['route_plan_id']}', index, status),
      ),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded, color: AppTheme.cyan),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ROUTES & OFFLINE MODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('Build routes • prepare offline • keep stop updates through weak service', style: TextStyle(color: AppTheme.textMuted, fontSize: 8.5)),
                    ],
                  ),
                ),
                if (queuedOffline > 0) ...[
                  _OpportunityChip(label: '$queuedOffline TO SYNC', color: AppTheme.amber),
                  const SizedBox(width: 6),
                ],
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _syncPending(),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: busy ? null : _buildRoute,
                  icon: const Icon(Icons.add_road_rounded, size: 16),
                  label: const Text('Build My Route'),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ValueListenableBuilder<_ConnectionHealth>(
              valueListenable: _bridgePointConnectionHealth,
              builder: (context, health, _) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (health.spotty ? AppTheme.amber : AppTheme.green).withOpacity(.055),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        health.spotty ? Icons.signal_wifi_statusbar_connected_no_internet_4_rounded : Icons.cloud_done_outlined,
                        size: 16,
                        color: health.spotty ? AppTheme.amber : AppTheme.green,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          health.spotty
                              ? 'Connection is spotty. Route actions can be queued offline.'
                              : 'Connection looks healthy. Prepare offline before rural or storm field work.',
                          style: const TextStyle(fontSize: 8.5, color: AppTheme.textMuted),
                        ),
                      ),
                      if (offlineReady.isNotEmpty)
                        Text(
                          '${offlineReady.length} offline-ready',
                          style: const TextStyle(fontSize: 8, color: AppTheme.cyan, fontWeight: FontWeight.w900),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: routesRequest,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const LinearProgressIndicator(color: AppTheme.cyan, minHeight: 2);
                }
                if (snapshot.hasError) return _InlineError(message: snapshot.error.toString());
                final routes = _bpRows(snapshot.data?['routes']);
                if (routes.isEmpty) {
                  return const Text(
                    'No routes yet. Save a few opportunities, then press Build My Route.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 9),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: routes.take(12).map((route) {
                    final id = '${route['route_plan_id']}';
                    final ready = offlineReady.contains(id);
                    return Container(
                      width: 300,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ready ? AppTheme.green.withOpacity(.22) : Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${route['route_name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10))),
                              if (ready) const Icon(Icons.offline_bolt_rounded, color: AppTheme.green, size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${route['stop_count']} stops • ${route['route_status']} • ${route['optimization_strategy']}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 8),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _openRoute(route),
                                icon: const Icon(Icons.route_outlined, size: 15),
                                label: const Text('Open'),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: busy ? null : () => _prepareOffline(route),
                                icon: const Icon(Icons.download_for_offline_outlined, size: 15),
                                label: Text(ready ? 'Refresh offline' : 'Offline'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteDetailDialog extends StatefulWidget {
  const _RouteDetailDialog({
    required this.route,
    required this.onPrepareOffline,
    required this.onUpdate,
    required this.offlineReady,
  });
  final Map<String, dynamic> route;
  final Future<void> Function() onPrepareOffline;
  final Future<void> Function(int, String) onUpdate;
  final bool offlineReady;

  @override
  State<_RouteDetailDialog> createState() => _RouteDetailDialogState();
}

class _RouteDetailDialogState extends State<_RouteDetailDialog> {
  late List<Map<String, dynamic>> stops;

  @override
  void initState() {
    super.initState();
    stops = _bpRows(widget.route['stops']);
  }

  Color _statusColor(String status) {
    if (['CONTACTED', 'APPOINTMENT', 'INSPECTION', 'COMPLETED'].contains(status)) return AppTheme.green;
    if (['NOT_HOME', 'FOLLOW_UP'].contains(status)) return AppTheme.amber;
    if (status == 'SKIP') return AppTheme.red;
    return AppTheme.cyan;
  }

  Future<void> _setStatus(int listIndex, int stopIndex, String status) async {
    await widget.onUpdate(stopIndex, status);
    if (mounted) {
      setState(() => stops[listIndex] = {...stops[listIndex], 'status': status});
    }
  }

  Future<void> _navigate(Map<String, dynamic> stop) async {
    final lat = stop['latitude'];
    final lon = stop['longitude'];
    if (lat == null || lon == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$lat,$lon'});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showInfoDialog(context, 'Navigation unavailable', 'Copy the property address into your preferred navigation app.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.route_rounded, color: AppTheme.cyan),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.route['route_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text('${stops.length} stops • ${widget.route['optimization_strategy']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                      ],
                    ),
                  ),
                  if (widget.offlineReady) ...[
                    const _OpportunityChip(label: 'OFFLINE READY', color: AppTheme.green),
                    const SizedBox(width: 7),
                  ],
                  OutlinedButton.icon(
                    onPressed: widget.onPrepareOffline,
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: const Text('Prepare offline'),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              const _ExplainerBanner(
                icon: Icons.directions_car_filled_outlined,
                title: 'Field route',
                message: 'Route order is an efficiency aid. Obey traffic, safety, access and no-soliciting rules. Do not interact with BridgePoint while driving.',
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: stops.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, listIndex) {
                    final stop = stops[listIndex];
                    final stopIndex = (stop['stop_index'] as num?)?.toInt() ?? listIndex + 1;
                    final status = '${stop['status'] ?? 'PLANNED'}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: _statusColor(status).withOpacity(.13),
                            child: Text('$stopIndex', style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${stop['address'] ?? 'Property'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                const SizedBox(height: 3),
                                Text(
                                  '${stop['opportunity_name'] ?? ''} • Score ${stop['quality_score'] ?? '—'} • Confidence ${stop['confidence_score'] ?? '—'} • Urgency ${stop['urgency_score'] ?? '—'}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 8.5),
                                ),
                                const SizedBox(height: 5),
                                Text('${stop['why_now'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, height: 1.35)),
                                const SizedBox(height: 5),
                                Text(
                                  stop['property_photo_url'] == null ? 'Property photo not available yet' : 'Property photo available',
                                  style: TextStyle(color: stop['property_photo_url'] == null ? AppTheme.textMuted : AppTheme.green, fontSize: 8, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _OpportunityChip(label: status.replaceAll('_', ' '), color: _statusColor(status)),
                              const SizedBox(height: 5),
                              PopupMenuButton<String>(
                                tooltip: 'Update stop',
                                onSelected: (value) => _setStatus(listIndex, stopIndex, value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'NAVIGATING', child: Text('Navigating')),
                                  PopupMenuItem(value: 'ARRIVED', child: Text('Arrived')),
                                  PopupMenuItem(value: 'CONTACTED', child: Text('Contacted')),
                                  PopupMenuItem(value: 'NOT_HOME', child: Text('Not home')),
                                  PopupMenuItem(value: 'FOLLOW_UP', child: Text('Follow-up')),
                                  PopupMenuItem(value: 'APPOINTMENT', child: Text('Appointment')),
                                  PopupMenuItem(value: 'INSPECTION', child: Text('Inspection')),
                                  PopupMenuItem(value: 'SKIP', child: Text('Skip')),
                                  PopupMenuItem(value: 'COMPLETED', child: Text('Completed')),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Row(children: [Icon(Icons.edit_location_alt_outlined, size: 16), SizedBox(width: 4), Text('Status', style: TextStyle(fontSize: 9))]),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _navigate(stop),
                                icon: const Icon(Icons.navigation_outlined, size: 15),
                                label: const Text('Navigate'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

'''
text=text[:route_start]+route_block+text[route_end:]

founder_start=text.find('IconData _trainingIcon(String key)=>')
founder_end=text.find('class _OwnerCenterPage extends StatefulWidget{',founder_start)
if founder_start<0 or founder_end<0:
    raise SystemExit('Generated training/founder block not found')

founder_block=r'''IconData _trainingIcon(String key) {
  switch (key) {
    case 'dashboard': return Icons.dashboard_outlined;
    case 'weather': return Icons.cloud_outlined;
    case 'map': return Icons.map_outlined;
    case 'search': return Icons.search_rounded;
    case 'community': return Icons.groups_2_outlined;
    case 'route': return Icons.route_rounded;
    case 'offline': return Icons.offline_bolt_rounded;
    case 'calendar': return Icons.calendar_month_outlined;
    case 'notifications': return Icons.notifications_active_outlined;
    case 'models': return Icons.psychology_outlined;
    case 'home': return Icons.home_rounded;
    case 'security': return Icons.security_outlined;
    case 'people': return Icons.group_add_outlined;
    case 'expansion': return Icons.public_rounded;
    case 'api': return Icons.api_rounded;
    case 'growth': return Icons.campaign_outlined;
    case 'email': return Icons.mark_email_unread_outlined;
    case 'billing': return Icons.credit_card_outlined;
    case 'demo': return Icons.slideshow_rounded;
    case 'finish': return Icons.rocket_launch_rounded;
    case 'forum': return Icons.forum_outlined;
    case 'visibility': return Icons.visibility_outlined;
    case 'fact_check': return Icons.fact_check_outlined;
    case 'handshake': return Icons.handshake_outlined;
    case 'owner': return Icons.admin_panel_settings_outlined;
    default: return Icons.auto_awesome_rounded;
  }
}

class _CustomerPreviewBanner extends StatelessWidget {
  const _CustomerPreviewBanner({required this.packageName, required this.onExit});
  final String packageName;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.amber.withOpacity(.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.amber.withOpacity(.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: AppTheme.amber, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'CUSTOMER PREVIEW • $packageName — owner-only navigation is hidden; your real backend owner permissions are unchanged.',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onExit,
            icon: const Icon(Icons.close_rounded, size: 15),
            label: const Text('Exit preview'),
          ),
        ],
      ),
    );
  }
}

class _VisualWalkthroughDialog extends StatefulWidget {
  const _VisualWalkthroughDialog({required this.initialData, required this.onNavigateLabel});
  final Map<String, dynamic> initialData;
  final ValueChanged<String> onNavigateLabel;

  @override
  State<_VisualWalkthroughDialog> createState() => _VisualWalkthroughDialogState();
}

class _VisualWalkthroughDialogState extends State<_VisualWalkthroughDialog> {
  late List<Map<String, dynamic>> steps;
  int index = 0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    steps = _bpRows(widget.initialData['steps']);
    final state = _bpMap(widget.initialData['state']);
    final current = (state['current_step'] as num?)?.toInt();
    if (current != null) {
      final found = steps.indexWhere((step) => (step['step_number'] as num?)?.toInt() == current);
      if (found >= 0) index = found;
    }
    if ('${state['status']}' == 'NOT_STARTED' && steps.isNotEmpty) {
      unawaited(_callRpc('bridgepoint_walkthrough_progress_v155', {
        'p_action': 'START',
        'p_step': steps[index]['step_number'],
      }));
    }
  }

  Future<void> _move(int next) async {
    if (steps.isEmpty) return;
    final bounded = next.clamp(0, steps.length - 1);
    setState(() => busy = true);
    try {
      await _callRpc('bridgepoint_walkthrough_progress_v155', {
        'p_action': 'STEP',
        'p_step': steps[bounded]['step_number'],
      });
      if (mounted) setState(() => index = bounded);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _skip() async {
    await _callRpc('bridgepoint_walkthrough_progress_v155', {
      'p_action': 'SKIP',
      'p_step': steps.isEmpty ? 1 : steps[index]['step_number'],
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _next() async {
    if (index >= steps.length - 1) {
      await _callRpc('bridgepoint_walkthrough_progress_v155', {
        'p_action': 'COMPLETE',
        'p_step': steps[index]['step_number'],
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BridgePoint walkthrough complete. Replay it anytime with the training button.')),
        );
      }
      return;
    }
    await _move(index + 1);
  }

  Widget _callout(String label, IconData icon, Color color, String value) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: color.withOpacity(.06), borderRadius: BorderRadius.circular(11)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 9.5, height: 1.45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return AlertDialog(
        title: const Text('Walkthrough'),
        content: const Text('Training steps are not available yet.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
    }
    final step = steps[index];
    final asset = '${step['visual_asset'] ?? 'assets/images/bridgepoint-intelligence-background-v1.webp'}';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cyan.withOpacity(.2)),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 205,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(asset, fit: BoxFit.cover, color: Colors.white.withOpacity(.32), colorBlendMode: BlendMode.modulate),
                      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.12), AppTheme.panel.withOpacity(.96)]))),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(color: AppTheme.cyan.withOpacity(.16), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(_trainingIcon('${step['icon_key']}'), color: AppTheme.cyan, size: 28),
                                ),
                                const Spacer(),
                                Text('STEP ${index + 1} OF ${steps.length}', style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 8),
                                TextButton(onPressed: busy ? null : _skip, child: const Text('Skip for now')),
                              ],
                            ),
                            const Spacer(),
                            Text('${step['title']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.cyan)),
                            const SizedBox(height: 5),
                            Text('${step['headline']}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.08)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              LinearProgressIndicator(
                value: (index + 1) / steps.length,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(AppTheme.cyan),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${step['body']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.65)),
                      if ('${step['why_it_matters'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _callout('WHY IT MATTERS', Icons.insights_outlined, AppTheme.blue, '${step['why_it_matters']}'),
                      ],
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tip = _callout('TIP / TRICK', Icons.lightbulb_outline_rounded, AppTheme.amber, '${step['tip'] ?? ''}');
                          final tryIt = _callout('TRY THIS NOW', Icons.touch_app_outlined, AppTheme.green, '${step['try_this'] ?? ''}');
                          if (constraints.maxWidth > 650) {
                            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: tip), const SizedBox(width: 9), Expanded(child: tryIt)]);
                          }
                          return Column(children: [tip, const SizedBox(height: 9), tryIt]);
                        },
                      ),
                      if ('${step['nav_label'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => widget.onNavigateLabel('${step['nav_label']}'),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text('Show me ${step['nav_label']}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: [
                    TextButton.icon(onPressed: index == 0 || busy ? null : () => _move(index - 1), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back')),
                    const Spacer(),
                    const Text('Replay anytime', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: busy ? null : _next,
                      icon: Icon(index == steps.length - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                      label: Text(index == steps.length - 1 ? 'Finish walkthrough' : 'Next'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerDemoPage extends StatefulWidget {
  const _OwnerDemoPage({required this.onNavigateLabel});
  final ValueChanged<String> onNavigateLabel;

  @override
  State<_OwnerDemoPage> createState() => _OwnerDemoPageState();
}

class _OwnerDemoPageState extends State<_OwnerDemoPage> {
  late Future<Map<String, dynamic>> packagesRequest;
  String? selected;
  Map<String, dynamic>? playbook;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    packagesRequest = _callRpc('bridgepoint_owner_demo_packages_v155', const {});
  }

  Future<void> _loadDemo(String key) async {
    setState(() { selected = key; loading = true; error = null; });
    try {
      final result = await _callRpc('bridgepoint_owner_demo_mode_v155', {'p_package_key': key});
      if (mounted) setState(() => playbook = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(title: 'Owner Demo Mode', subtitle: 'Choose what you are selling • BridgePoint coaches what to say, show and prove', action: 'Owner-only presenter'),
          const SizedBox(height: 10),
          const _ExplainerBanner(
            icon: Icons.slideshow_rounded,
            title: 'You do not have to memorize BridgePoint',
            message: 'Pick a package. Demo Mode gives you an opener, discovery question, screen sequence, “say this,” “show this,” proof point, objection response, transition and close.',
          ),
          const SizedBox(height: 13),
          FutureBuilder<Map<String, dynamic>>(
            future: packagesRequest,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator(color: AppTheme.cyan, minHeight: 2);
              if (snapshot.hasError) return _InlineError(message: snapshot.error.toString());
              final packages = _bpRows(snapshot.data?['packages']);
              return DropdownButtonFormField<String>(
                value: selected,
                dropdownColor: AppTheme.panel,
                decoration: const InputDecoration(labelText: 'Choose package / technology', border: OutlineInputBorder()),
                items: packages.map((package) => DropdownMenuItem<String>(
                  value: '${package['package_key']}',
                  child: Text('${package['package_name']} • ${package['audience']}', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) { if (value != null) _loadDemo(value); },
              );
            },
          ),
          if (loading) ...[const SizedBox(height: 9), const LinearProgressIndicator(color: AppTheme.cyan, minHeight: 2)],
          if (error != null) ...[const SizedBox(height: 9), _InlineError(message: error!)],
          if (playbook != null) ...[const SizedBox(height: 14), _DemoPreview(data: playbook!, onNavigateLabel: widget.onNavigateLabel)],
        ],
      ),
    );
  }
}

class _DemoPreview extends StatelessWidget {
  const _DemoPreview({required this.data, required this.onNavigateLabel});
  final Map<String, dynamic> data;
  final ValueChanged<String> onNavigateLabel;

  @override
  Widget build(BuildContext context) {
    final package = _bpMap(data['package']);
    final playbook = _bpMap(data['playbook']);
    final steps = _bpRows(data['steps']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${package['package_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('${package['description']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9.5, height: 1.45)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.cyan.withOpacity(.05), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OPEN WITH THIS', style: TextStyle(color: AppTheme.cyan, fontSize: 8, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text('${playbook['opener']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.45)),
                  const SizedBox(height: 8),
                  const Text('THEN ASK', style: TextStyle(color: AppTheme.green, fontSize: 8, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${playbook['discovery_question']}', style: const TextStyle(fontSize: 10, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _GuidedDemoDialog(data: data, onNavigateLabel: onNavigateLabel),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Start guided ${package['package_name']} demo'),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: steps.map((step) => _OpportunityChip(label: '${step['step']}. ${step['title']}', color: AppTheme.cyan)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidedDemoDialog extends StatefulWidget {
  const _GuidedDemoDialog({required this.data, required this.onNavigateLabel});
  final Map<String, dynamic> data;
  final ValueChanged<String> onNavigateLabel;

  @override
  State<_GuidedDemoDialog> createState() => _GuidedDemoDialogState();
}

class _GuidedDemoDialogState extends State<_GuidedDemoDialog> {
  int index = 0;

  Widget _box(String label, IconData icon, Color color, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: color.withOpacity(.055), borderRadius: BorderRadius.circular(11)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(fontSize: 9.5, height: 1.45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final package = _bpMap(widget.data['package']);
    final steps = _bpRows(widget.data['steps']);
    final step = steps[index];
    final asset = '${step['visual_asset']}';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 840),
        child: Container(
          decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.green.withOpacity(.2))),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 185,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(asset, fit: BoxFit.cover, color: Colors.white.withOpacity(.28), colorBlendMode: BlendMode.modulate),
                      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black12, AppTheme.panel.withOpacity(.96)]))),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_trainingIcon('${step['icon_key']}'), color: AppTheme.green, size: 30),
                                const SizedBox(width: 10),
                                Expanded(child: Text('${package['package_name']}', style: const TextStyle(color: AppTheme.green, fontSize: 10, fontWeight: FontWeight.w900))),
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('End demo')),
                              ],
                            ),
                            const Spacer(),
                            Text('DEMO STEP ${index + 1} OF ${steps.length}', style: const TextStyle(color: Colors.white70, fontSize: 8)),
                            const SizedBox(height: 4),
                            Text('${step['title']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              LinearProgressIndicator(value: (index + 1) / steps.length, minHeight: 4, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(AppTheme.green)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box('SAY THIS', Icons.record_voice_over_outlined, AppTheme.green, '${step['say_this']}'),
                      const SizedBox(height: 9),
                      _box('SHOW THIS NOW', Icons.visibility_outlined, AppTheme.cyan, '${step['show_this']}'),
                      const SizedBox(height: 7),
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigateLabel('${step['nav_label']}'),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text('Open ${step['nav_label']}'),
                      ),
                      const SizedBox(height: 9),
                      _box('TIP', Icons.lightbulb_outline_rounded, AppTheme.amber, '${step['tip']}'),
                      const SizedBox(height: 9),
                      _box('PROOF POINT', Icons.fact_check_outlined, AppTheme.blue, '${step['proof_point']}'),
                      const SizedBox(height: 9),
                      _box('TRANSITION / OBJECTION', Icons.forward_rounded, AppTheme.cyan, '${step['transition']}'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: [
                    TextButton.icon(onPressed: index == 0 ? null : () => setState(() => index--), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back')),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        if (index == steps.length - 1) {
                          Navigator.pop(context);
                        } else {
                          setState(() => index++);
                        }
                      },
                      icon: Icon(index == steps.length - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                      label: Text(index == steps.length - 1 ? 'Finish demo' : 'Next talking point'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FounderCommandPage extends StatefulWidget {
  const _FounderCommandPage({
    required this.onReplayWalkthrough,
    required this.onOpenDemo,
    required this.onStartCustomerPreview,
    required this.onNavigateLabel,
  });
  final VoidCallback onReplayWalkthrough;
  final VoidCallback onOpenDemo;
  final VoidCallback onStartCustomerPreview;
  final ValueChanged<String> onNavigateLabel;

  @override
  State<_FounderCommandPage> createState() => _FounderCommandPageState();
}

class _FounderCommandPageState extends State<_FounderCommandPage> {
  late Future<Map<String, dynamic>> commandRequest;
  late Future<Map<String, dynamic>> activityRequest;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    commandRequest = _callRpc('bridgepoint_owner_command_center_v153', const {});
    activityRequest = _callRpc('bridgepoint_owner_activity_v158', const {'p_limit': 80});
    if (mounted) setState(() {});
  }

  Future<void> _inviteOwner() async {
    final email = TextEditingController();
    final name = TextEditingController();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Add a full-access owner'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This person will be able to see and operate every package, model, geography and owner tool. Only invite someone you trust with BridgePoint operations.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 9, height: 1.45),
              ),
              const SizedBox(height: 10),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name (optional)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {'email': email.text.trim(), 'name': name.text.trim()}),
            child: const Text('Send full-owner invite'),
          ),
        ],
      ),
    );
    email.dispose();
    name.dispose();
    if (values == null || (values['email'] ?? '').isEmpty) return;

    setState(() => busy = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'bridgepoint-owner-invite-v153',
        body: {'email': values['email'], 'display_name': values['name'], 'redirect_url': _bridgePointLiveUrl},
      );
      final result = _edgeFunctionPayload(response.data);
      if (result['complete'] != true) throw Exception('${result['error'] ?? 'Invite failed'}');
      if (mounted) {
        await _showInfoDialog(
          context,
          result['existing_account'] == true ? 'Owner access granted' : 'Owner invitation sent',
          '${result['message']}',
        );
        _reload();
      }
    } catch (e) {
      if (mounted) _showInfoDialog(context, 'Could not add owner', '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _revokeOwner(Map<String, dynamic> owner) async {
    try {
      await _callRpc('bridgepoint_owner_revoke_full_access_v153', {
        'p_user_id': owner['user_id'],
        'p_confirmation': 'REVOKE FULL OWNER',
      });
      _reload();
    } catch (e) {
      if (mounted) _showInfoDialog(context, 'Could not revoke owner', '$e');
    }
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('New owner task'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Task', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    try {
      await _callRpc('bridgepoint_owner_add_task_v153', {
        'p_title': title,
        'p_description': null,
        'p_priority': 'NORMAL',
        'p_assigned_to': null,
        'p_due_at': null,
        'p_related_area': 'FOUNDER_COMMAND',
      });
      _reload();
    } catch (e) {
      if (mounted) _showInfoDialog(context, 'Could not create task', '$e');
    }
  }

  Future<void> _addNote() async {
    final title = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Private founder decision note'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: note, maxLines: 4, decoration: const InputDecoration(labelText: 'Decision / note', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {'title': title.text.trim(), 'note': note.text.trim()}), child: const Text('Pin note')),
        ],
      ),
    );
    title.dispose();
    note.dispose();
    if (result == null || (result['title'] ?? '').isEmpty || (result['note'] ?? '').isEmpty) return;
    try {
      await _callRpc('bridgepoint_owner_save_note_v153', {
        'p_title': result['title'],
        'p_note': result['note'],
        'p_category': 'DECISION',
        'p_pinned': true,
      });
      _reload();
    } catch (e) {
      if (mounted) _showInfoDialog(context, 'Could not save note', '$e');
    }
  }

  Future<void> _decide(Map<String, dynamic> approval, String decision) async {
    try {
      await _callRpc('bridgepoint_owner_decide_approval_v158', {
        'p_approval_id': approval['approval_id'],
        'p_decision': decision,
        'p_note': null,
      });
      _reload();
    } catch (e) {
      if (mounted) _showInfoDialog(context, 'Could not decide approval', '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<Map<String, dynamic>>(
        future: commandRequest,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const LinearProgressIndicator(color: AppTheme.cyan, minHeight: 2);
          }
          if (snapshot.hasError) return _InlineError(message: snapshot.error.toString());
          final data = snapshot.data ?? const <String, dynamic>{};
          final access = _bpMap(data['owner_access']);
          final owners = _bpRows(access['executives']);
          final invites = _bpRows(access['pending_invites']);
          final tasks = _bpRows(data['tasks']);
          final notes = _bpRows(data['pinned_notes']);
          final approvals = _bpRows(data['approvals']);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeader(title: 'Founder Command Center', subtitle: 'Full owners • handoffs • decisions • approvals • demo/test controls', action: 'Private owner layer'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(onPressed: busy ? null : _inviteOwner, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add full-access owner')),
                  OutlinedButton.icon(onPressed: widget.onReplayWalkthrough, icon: const Icon(Icons.school_outlined), label: const Text('Replay full walkthrough')),
                  OutlinedButton.icon(onPressed: widget.onOpenDemo, icon: const Icon(Icons.slideshow_outlined), label: const Text('Open Demo Mode')),
                  OutlinedButton.icon(onPressed: widget.onStartCustomerPreview, icon: const Icon(Icons.visibility_outlined), label: const Text('Preview as customer')),
                  OutlinedButton.icon(onPressed: _addTask, icon: const Icon(Icons.add_task_rounded), label: const Text('Owner task')),
                  OutlinedButton.icon(onPressed: _addNote, icon: const Icon(Icons.push_pin_outlined), label: const Text('Pin decision note')),
                ],
              ),
              const SizedBox(height: 13),
              _OwnerAccessPanel(owners: owners, invites: invites, onInvite: _inviteOwner, onRevoke: _revokeOwner),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 900 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: width, child: _FounderListCard(title: 'OWNER TASKS', icon: Icons.task_alt_rounded, empty: 'No open founder tasks.', children: tasks.take(12).map((task) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.cyan), title: Text('${task['title']}'), subtitle: Text('${task['description'] ?? ''}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)))).toList())),
                      SizedBox(width: width, child: _FounderListCard(title: 'PINNED DECISIONS', icon: Icons.push_pin_outlined, empty: 'No pinned founder decisions yet.', children: notes.take(10).map((item) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notes_rounded, color: AppTheme.green), title: Text('${item['title']}'), subtitle: Text('${item['note']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)))).toList())),
                    ],
                  );
                },
              ),
              if (approvals.isNotEmpty) ...[
                const SizedBox(height: 10),
                _FounderListCard(
                  title: 'OWNER APPROVALS',
                  icon: Icons.approval_outlined,
                  empty: 'No approvals waiting.',
                  children: approvals.map((approval) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pending_actions_rounded, color: AppTheme.amber),
                    title: Text('${approval['title']}'),
                    subtitle: Text('${approval['detail'] ?? approval['approval_type']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
                    trailing: Wrap(spacing: 5, children: [
                      TextButton(onPressed: () => _decide(approval, 'REJECTED'), child: const Text('Reject')),
                      FilledButton(onPressed: () => _decide(approval, 'APPROVED'), child: const Text('Approve')),
                    ]),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 10),
              FutureBuilder<Map<String, dynamic>>(
                future: activityRequest,
                builder: (context, activitySnapshot) {
                  final items = _bpRows(activitySnapshot.data?['items']);
                  return _FounderListCard(
                    title: 'OWNER ACTIVITY',
                    icon: Icons.history_rounded,
                    empty: 'Owner activity will appear here as actions are recorded.',
                    children: items.take(20).map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_toggle_off_rounded, color: AppTheme.textMuted),
                      title: Text('${item['summary']}'),
                      subtitle: Text('${item['actor']} • ${_bpDateTime(item['created_at'])}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
                    )).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OwnerAccessPanel extends StatelessWidget {
  const _OwnerAccessPanel({required this.owners, required this.invites, required this.onInvite, required this.onRevoke});
  final List<Map<String, dynamic>> owners;
  final List<Map<String, dynamic>> invites;
  final VoidCallback onInvite;
  final Future<void> Function(Map<String, dynamic>) onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.cyan),
                const SizedBox(width: 7),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FULL-ACCESS OWNERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('Add multiple trusted people who can operate every BridgePoint package, model, state and owner tool.', style: TextStyle(color: AppTheme.textMuted, fontSize: 8.5)),
                    ],
                  ),
                ),
                TextButton.icon(onPressed: onInvite, icon: const Icon(Icons.person_add_alt_1_rounded, size: 16), label: const Text('Add another')),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: owners.map((owner) {
                final founder = owner['executive_role'] == 'PRIMARY_FOUNDER';
                return Container(
                  width: 330,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppTheme.panelSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (founder ? AppTheme.green : AppTheme.cyan).withOpacity(.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(founder ? Icons.workspace_premium_outlined : Icons.admin_panel_settings_outlined, color: founder ? AppTheme.green : AppTheme.cyan),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${owner['display_name'] ?? owner['email'] ?? 'Full owner'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
                          if (!founder)
                            IconButton(
                              tooltip: 'Revoke full access',
                              onPressed: () => onRevoke(owner),
                              icon: const Icon(Icons.person_remove_outlined, size: 18),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(founder ? 'PRIMARY FOUNDER' : 'FULL OWNER', style: TextStyle(color: founder ? AppTheme.green : AppTheme.cyan, fontSize: 8, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 5, runSpacing: 5, children: const [
                        _OpportunityChip(label: 'ALL MODELS', color: AppTheme.cyan),
                        _OpportunityChip(label: 'ALL FEATURES', color: AppTheme.green),
                        _OpportunityChip(label: 'ALL STATES', color: AppTheme.blue),
                        _OpportunityChip(label: 'OWNER TOOLS', color: AppTheme.amber),
                      ]),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (invites.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('PENDING / FAILED INVITES', style: TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.w900)),
              ...invites.map((invite) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(invite['status'] == 'FAILED' ? Icons.error_outline_rounded : Icons.mark_email_unread_outlined, color: invite['status'] == 'FAILED' ? AppTheme.red : AppTheme.amber),
                title: Text('${invite['email']}'),
                subtitle: Text('${invite['status']} • ${_bpDateTime(invite['invited_at'])}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _FounderListCard extends StatelessWidget {
  const _FounderListCard({required this.title, required this.icon, required this.empty, required this.children});
  final String title;
  final IconData icon;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: AppTheme.cyan, size: 18), const SizedBox(width: 7), Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 8),
            if (children.isEmpty) Text(empty, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)) else ...children,
          ],
        ),
      ),
    );
  }
}

'''
text=text[:founder_start]+founder_block+text[founder_end:]

path.write_text(text,encoding='utf-8')
print('Repaired generated release UI v160')
