import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';
import 'bridgepoint_property_presentation_v2.dart';

class BridgePointProperty360V2 extends StatefulWidget {
  const BridgePointProperty360V2({super.key});

  @override
  State<BridgePointProperty360V2> createState() =>
      _BridgePointProperty360V2State();
}

class _BridgePointProperty360V2State extends State<BridgePointProperty360V2> {
  final _query = TextEditingController();
  final _note = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _message;
  List<Map<String, dynamic>> _results = const [];
  String? _propertyId;
  String? _municipality;
  Map<String, dynamic> _detail = const {};
  Map<String, dynamic> _timeline = const {};
  Map<String, dynamic> _climate = const {};
  Map<String, dynamic> _twin = const {};
  Map<String, dynamic> _geometry = const {};
  Map<String, dynamic> _permits = const {};
  Map<String, dynamic> _media = const {};
  Map<String, dynamic> _notes = const {};
  Map<String, dynamic> _watchlists = const {};
  int _tab = 0;

  static const _muted = Color(0xFF8FA5BF);
  static const _cyan = Color(0xFF35D2E8);
  static const _amber = Color(0xFFFFC857);

  @override
  void dispose() {
    _query.dispose();
    _note.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (value is Map) {
      for (final key in const [
        'items',
        'results',
        'properties',
        'suggestions',
        'rows',
        'events',
        'notes',
        'media',
        'watchlists',
      ]) {
        if (value[key] is List) return _list(value[key]);
      }
    }
    return const [];
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'rpc': rpc, 'error': '$e'};
    }
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _propertyId = null;
      _results = const [];
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_suggestions_v192',
        params: {'p_query': query, 'p_limit': 30},
      );
      if (mounted) setState(() => _results = _list(raw));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = '${row['property_id'] ?? row['id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    final municipality = '${row['municipality'] ?? row['city'] ?? ''}'.trim();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _propertyId = id;
      _municipality = municipality.isEmpty ? null : municipality;
    });

    final values = await Future.wait([
      _safe('bridgepoint_flutter_property_detail_v344', {'p_property_id': id}),
      _safe('bridgepoint_property_timeline_v78', {
        'p_property_id': id,
        'p_limit': 200,
      }),
      _safe('bridgepoint_property_climate_profile_v510', {'p_property_id': id}),
      _safe('bridgepoint_digital_twin_summary_v509', {'p_property_id': id}),
      _safe('bridgepoint_property_geometry_v837', {
        'p_property_id': id,
        'p_limit': 25,
      }),
      municipality.isEmpty
          ? Future.value({
              'available': false,
              'reason': 'Municipality unavailable',
            })
          : _safe('bridgepoint_flutter_permit_context_v68', {
              'p_municipality': municipality,
            }),
      _safe('bridgepoint_property_media_bundle_v169', {'p_property_id': id}),
      _safe('bridgepoint_customer_notes_v70', {
        'p_property_id': id,
        'p_limit': 100,
      }),
      _safe('bridgepoint_watchlists_v88'),
    ]);

    if (!mounted) return;
    setState(() {
      _detail = _map(values[0]);
      _timeline = _map(values[1]);
      _climate = _map(values[2]);
      _twin = _map(values[3]);
      _geometry = _map(values[4]);
      _permits = _map(values[5]);
      _media = _map(values[6]);
      _notes = _map(values[7]);
      _watchlists = _map(values[8]);
      _tab = 0;
      _busy = false;
    });
  }

  Future<void> _saveNote() async {
    final id = _propertyId;
    final text = _note.text.trim();
    if (id == null || text.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_save_customer_note_v70',
        params: {
          'p_property_id': id,
          'p_opportunity_id': null,
          'p_preset_key': null,
          'p_note_text': text,
          'p_follow_up_at': null,
        },
      );
      _note.clear();
      final raw = await _safe(
        'bridgepoint_customer_notes_v70',
        {'p_property_id': id, 'p_limit': 100},
      );
      if (mounted) {
        setState(() {
          _notes = _map(raw);
          _message = 'Property note saved.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToWatchlist() async {
    final propertyId = _propertyId;
    if (propertyId == null) return;
    final rows = _list(_watchlists);
    String? selectedId;
    final newName = TextEditingController();

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Save property to watchlist'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rows.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    items: rows
                        .map((watchlist) {
                          final id =
                              '${watchlist['watchlist_id'] ?? watchlist['id'] ?? ''}';
                          return DropdownMenuItem(
                            value: id,
                            child: Text(
                              '${watchlist['watchlist_name'] ?? watchlist['name'] ?? 'Watchlist'}',
                            ),
                          );
                        })
                        .where((item) => item.value?.isNotEmpty == true)
                        .toList(),
                    onChanged: (value) =>
                        setLocal(() => selectedId = value),
                    decoration:
                        const InputDecoration(labelText: 'Existing watchlist'),
                  ),
                if (rows.isNotEmpty) const SizedBox(height: 12),
                TextField(
                  controller: newName,
                  decoration:
                      const InputDecoration(labelText: 'Or create new watchlist'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save property'),
            ),
          ],
        ),
      ),
    );

    if (choice != 'save') {
      newName.dispose();
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      var watchlistId = selectedId;
      if (newName.text.trim().isNotEmpty) {
        final created = _map(
          await Supabase.instance.client.rpc(
            'bridgepoint_create_watchlist_v88',
            params: {
              'p_name': newName.text.trim(),
              'p_type': 'PROPERTY',
            },
          ),
        );
        watchlistId = '${created['watchlist_id'] ?? ''}';
      }
      if (watchlistId == null || watchlistId.isEmpty) {
        throw StateError('Choose a watchlist or enter a new watchlist name.');
      }
      await Supabase.instance.client.rpc(
        'bridgepoint_add_watchlist_item_v88',
        params: {
          'p_watchlist_id': watchlistId,
          'p_property_id': propertyId,
          'p_item_key': propertyId,
          'p_item_label': _propertyLabel,
          'p_metadata': {'source': 'clean_v2_property_360'},
        },
      );
      final refreshed = await _safe('bridgepoint_watchlists_v88');
      if (mounted) {
        setState(() {
          _watchlists = _map(refreshed);
          _message = 'Property saved to watchlist.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Watchlist action unavailable: $e');
      }
    } finally {
      newName.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askPropertyAi() async {
    final propertyId = _propertyId;
    if (propertyId == null) return;
    final prompt = TextEditingController(
      text:
          'Summarize the Why Now, strongest evidence, uncertainty, risk context, and best next action for this property.',
    );
    final ask = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ask BridgePoint AI about this property'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: prompt,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Question'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Ask AI'),
          ),
        ],
      ),
    );

    if (ask != true) {
      prompt.dispose();
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final query =
          'BridgePoint property ID $propertyId at $_propertyLabel. ${prompt.text.trim()} Keep the answer evidence-backed and distinguish model output from confirmed condition.';
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_ai_answer_ui_v322',
        params: {'p_query': query},
      );
      final answer = _map(raw);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _cyan),
              SizedBox(width: 8),
              Text('BridgePoint AI'),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: BridgePointGenericWorkspaceSectionV2(
                title: 'Evidence-backed answer',
                payload: answer,
                icon: Icons.auto_awesome_rounded,
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _message = 'BridgePoint AI unavailable: $e');
    } finally {
      prompt.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> get _canonicalProperty {
    final property = _detail['property'];
    return property is Map ? Map<String, dynamic>.from(property) : const {};
  }

  String _label(Map<String, dynamic> row) {
    final nested = row['property'];
    if (nested is Map) return _label(Map<String, dynamic>.from(nested));
    final address =
        '${row['address'] ?? row['full_address'] ?? row['property_address'] ?? ''}'
            .trim();
    if (address.isNotEmpty) return address;
    return '${row['property_id'] ?? row['parcel_number'] ?? 'Property'}';
  }

  String get _propertyLabel {
    final label = _label(_canonicalProperty);
    return label == 'Property' ? (_propertyId ?? 'Property') : label;
  }

  Widget _searchBar() => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final field = TextField(
            controller: _query,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
              labelText: 'Address, parcel, owner, city or property',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          );
          final button = FilledButton.icon(
            onPressed: _busy ? null : _search,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [field, const SizedBox(height: 8), button],
            );
          }
          return Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 10),
              button,
            ],
          );
        },
      );

  Widget _propertyHeader() => LayoutBuilder(
        builder: (context, constraints) {
          final property = _canonicalProperty;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                tooltip: 'Back to property search',
                onPressed: () => setState(() => _propertyId = null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _propertyLabel,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        'Property ID $_propertyId',
                        property['parcel_number'],
                        property['municipality'] ?? _municipality,
                        property['state_code'],
                      ]
                          .where((value) =>
                              value != null && '$value'.trim().isNotEmpty)
                          .join(' • '),
                      style: const TextStyle(color: _muted, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _askPropertyAi,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Ask AI'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _saveToWatchlist,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Watchlist'),
              ),
              const Chip(
                avatar: Icon(Icons.verified_user_outlined, size: 16),
                label: Text('SOURCE-BACKED'),
              ),
            ],
          );
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 10), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      );

  Widget _notesActions() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _askPropertyAi,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Ask AI about property'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _saveToWatchlist,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save to watchlist'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add property note',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText:
                          'Observation, follow-up, customer-safe note...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _saveNote,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save note'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          BridgePointGenericWorkspaceSectionV2(
            title: 'Notes / follow-up history',
            payload: _notes,
            icon: Icons.sticky_note_2_outlined,
          ),
          const SizedBox(height: 10),
          BridgePointGenericWorkspaceSectionV2(
            title: 'Watchlists / saved property sets',
            payload: _watchlists,
            icon: Icons.bookmarks_outlined,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Property 360',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'One canonical property object: identity, provenance, Why Now, evidence timeline, climate/peril context, truthful Digital Twin fidelity, permits, imagery, notes and actions.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        _searchBar(),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Color(0xFFFF7E7E))),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: _cyan)),
        ],
        const SizedBox(height: 14),
        if (_propertyId == null)
          if (_results.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Search a property to open the full BridgePoint intelligence workspace.',
                  style: TextStyle(color: _muted),
                ),
              ),
            )
          else
            ..._results.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1635D2E8),
                      child: Icon(Icons.home_work_outlined, color: _cyan),
                    ),
                    title: Text(
                      _label(row),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        row['city'] ?? row['municipality'],
                        row['state_code'],
                        row['county_name'] ?? row['county'],
                        row['parcel_id'] ?? row['parcel_number'],
                      ]
                          .where((value) =>
                              value != null && '$value'.trim().isNotEmpty)
                          .join(' • '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(row),
                  ),
                ),
              ),
            )
        else ...[
          _propertyHeader(),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.badge_outlined),
                  label: Text('Overview'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.timeline_rounded),
                  label: Text('Property DNA'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.shield_outlined),
                  label: Text('Risk + Twin'),
                ),
                ButtonSegment(
                  value: 3,
                  icon: Icon(Icons.photo_library_outlined),
                  label: Text('Permits + Media'),
                ),
                ButtonSegment(
                  value: 4,
                  icon: Icon(Icons.task_alt_rounded),
                  label: Text('Notes + Actions'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (value) =>
                  setState(() => _tab = value.first),
            ),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) BridgePointPropertyOverviewV2(payload: _detail),
          if (_tab == 1) BridgePointPropertyTimelineV2(payload: _timeline),
          if (_tab == 2) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 1080;
                final width = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: BridgePointClimateProfileV2(payload: _climate),
                    ),
                    SizedBox(
                      width: width,
                      child: BridgePointTwinSummaryV2(payload: _twin),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            BridgePointBuildingGeometryV2(payload: _geometry),
            const SizedBox(height: 8),
            const Text(
              'Risk values are screening/prioritization output—not proof of damage or future loss. Twin levels are shown at their actual fidelity; low-fidelity massing is never labeled an exact replica.',
              style: TextStyle(color: _amber, fontSize: 10, height: 1.4),
            ),
          ],
          if (_tab == 3)
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 1080;
                final width = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: BridgePointPermitContextV2(payload: _permits),
                    ),
                    SizedBox(
                      width: width,
                      child: BridgePointMediaHistoryV2(payload: _media),
                    ),
                  ],
                );
              },
            ),
          if (_tab == 4) _notesActions(),
        ],
      ],
    );
  }
}
