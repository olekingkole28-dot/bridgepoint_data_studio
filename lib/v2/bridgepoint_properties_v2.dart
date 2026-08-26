import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_property_dossier_v2.dart';

class BridgePointPropertiesV2 extends StatefulWidget {
  const BridgePointPropertiesV2({super.key});

  @override
  State<BridgePointPropertiesV2> createState() => _BridgePointPropertiesV2State();
}

class _BridgePointPropertiesV2State extends State<BridgePointPropertiesV2> {
  static const _panel = Color(0xFF0E2035);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  final _search = TextEditingController();
  final _municipality = TextEditingController();
  final _type = TextEditingController();
  late Future<dynamic> _request;
  List<Map<String, dynamic>> _stateRows = const [];
  String _state = 'CT';
  int _offset = 0;
  static const _limit = 25;

  @override
  void initState() {
    super.initState();
    _request = _load();
    _loadStates();
  }

  @override
  void dispose() {
    _search.dispose();
    _municipality.dispose();
    _type.dispose();
    super.dispose();
  }

  String? _clean(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _loadStates() async {
    try {
      final raw = await Supabase.instance.client
          .rpc('bridgepoint_flutter_map_state_status_v838');
      final rows = _rows(raw is Map ? raw['states'] : raw);
      if (!mounted || rows.isEmpty) return;
      final codes = rows.map((row) => '${row['state_code'] ?? ''}').toSet();
      setState(() {
        _stateRows = rows;
        if (!codes.contains(_state)) {
          _state = '${rows.first['state_code'] ?? 'CT'}';
          _offset = 0;
          _request = _load();
        }
      });
    } catch (_) {
      // The property browser still works with the selected state if this
      // lightweight status request is temporarily unavailable.
    }
  }

  Future<dynamic> _load() => Supabase.instance.client.rpc(
        'bridgepoint_flutter_properties_state_browse_v840',
        params: {
          'p_state_code': _state,
          'p_search': _clean(_search.text),
          'p_municipality': _clean(_municipality.text),
          'p_property_type': _clean(_type.text),
          'p_limit': _limit,
          'p_offset': _offset,
        },
      );

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in const ['properties', 'states', 'items', 'rows', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Map<String, dynamic> get _selectedStateRow {
    for (final row in _stateRows) {
      if ('${row['state_code'] ?? ''}' == _state) return row;
    }
    return const {};
  }

  void _reload({bool reset = false}) {
    if (reset) _offset = 0;
    setState(() => _request = _load());
  }

  void _selectState(String? value) {
    if (value == null || value == _state) return;
    setState(() {
      _state = value;
      _offset = 0;
      _request = _load();
    });
  }

  Future<void> _openProperty(Map<String, dynamic> property) async {
    final id = '${property['property_id'] ?? ''}'.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BridgePointPropertyDossierV2(
          propertyId: id,
          seed: property,
          asPage: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _request,
      builder: (context, snapshot) {
        final payload = _map(snapshot.data);
        final rows = _rows(payload);
        final hasMore = payload['has_more'] == true;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final stateRow = _selectedStateRow;
        final foundationCount = stateRow['canonical_property_count'];
        final status = '${stateRow['build_status'] ?? 'FOUNDATION'}';

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
                        'Properties',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Browse actual state property foundations even before a state has scores or opportunities. Search narrows that foundation by address, parcel, municipality or property type.',
                        style: TextStyle(color: _muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: loading ? null : () => _reload(),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh properties',
                ),
              ],
            ),
            if (loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 820;
                final stateField = DropdownButtonFormField<String>(
                  initialValue: _state,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: (_stateRows.isEmpty
                          ? <Map<String, dynamic>>[
                              {'state_code': _state, 'state_name': _state},
                            ]
                          : _stateRows)
                      .map(
                        (row) => DropdownMenuItem<String>(
                          value: '${row['state_code']}',
                          child: Text(
                            '${row['state_code']} • ${row['state_name'] ?? row['state_code']} • ${row['build_status'] ?? 'BUILDING'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: loading ? null : _selectState,
                );
                final searchField = TextField(
                  controller: _search,
                  onSubmitted: (_) => _reload(reset: true),
                  decoration: const InputDecoration(
                    labelText: 'Address or parcel',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                );
                final municipalityField = TextField(
                  controller: _municipality,
                  onSubmitted: (_) => _reload(reset: true),
                  decoration: const InputDecoration(
                    labelText: 'Municipality',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                );
                final typeField = TextField(
                  controller: _type,
                  onSubmitted: (_) => _reload(reset: true),
                  decoration: const InputDecoration(
                    labelText: 'Property type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stateField,
                      const SizedBox(height: 8),
                      searchField,
                      const SizedBox(height: 8),
                      municipalityField,
                      const SizedBox(height: 8),
                      typeField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: stateField),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: searchField),
                    const SizedBox(width: 8),
                    Expanded(child: municipalityField),
                    const SizedBox(width: 8),
                    Expanded(child: typeField),
                  ],
                );
              },
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: loading ? null : () => _reload(reset: true),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Load properties'),
                ),
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () {
                          _search.clear();
                          _municipality.clear();
                          _type.clear();
                          _reload(reset: true);
                        },
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear filters'),
                ),
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 17),
                  label: Text('$_state • $status'),
                ),
                if (foundationCount != null)
                  Chip(
                    avatar: const Icon(Icons.storage_rounded, size: 17),
                    label: Text('${_number(foundationCount)} state properties'),
                  ),
                if (stateRow['verified_source_count'] != null)
                  Chip(
                    avatar: const Icon(Icons.hub_outlined, size: 17),
                    label: Text(
                      '${_number(stateRow['verified_source_count'])} verified sources',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (snapshot.hasError)
              _MessageCard(
                icon: Icons.error_outline_rounded,
                text: '${snapshot.error}',
                color: _amber,
              )
            else if (!loading && rows.isEmpty)
              _MessageCard(
                icon: Icons.search_off_rounded,
                text:
                    'No property rows matched in $_state. If the state is still building, its foundation/status will continue updating automatically as ingestion advances.',
                color: _muted,
              )
            else
              ...rows.map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _PropertyCard(
                    property: property,
                    onTap: () => _openProperty(property),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _offset > 0 && !loading
                      ? () {
                          _offset = (_offset - _limit).clamp(0, 1 << 30);
                          _reload();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: hasMore && !loading
                      ? () {
                          _offset += _limit;
                          _reload();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                ),
                const Spacer(),
                Text(
                  '$_state • page ${(_offset ~/ _limit) + 1} • ${rows.length} shown',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, required this.onTap});
  final Map<String, dynamic> property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final address =
        '${property['full_address'] ?? property['address'] ?? ''}'.trim();
    final municipality = '${property['municipality'] ?? 'Unknown'}';
    final state = '${property['state_code'] ?? ''}';
    final parcel = '${property['parcel_number'] ?? 'No parcel'}';
    final priority =
        '${property['opportunity_priority'] ?? property['priority'] ?? ''}';
    final signal = '${property['top_signal_type'] ?? ''}'.replaceAll('_', ' ');
    final score = property['opportunity_score'] ?? property['final_score'];
    final display = address.isEmpty
        ? '$municipality, $state • $parcel'
        : address;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _BridgePointPropertiesV2State._panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxWidth < 760;
            final left = Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _BridgePointPropertiesV2State._cyan.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.home_work_rounded,
                    color: _BridgePointPropertiesV2State._cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$municipality, $state • $parcel • ${property['property_type'] ?? 'Property'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _BridgePointPropertiesV2State._muted,
                          fontSize: 12.5,
                        ),
                      ),
                      if (signal.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          signal,
                          style: const TextStyle(
                            color: _BridgePointPropertiesV2State._green,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
            final right = Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.end,
              children: [
                _Tag(state, _BridgePointPropertiesV2State._blue),
                if (score != null)
                  _Tag('SCORE $score', _BridgePointPropertiesV2State._cyan),
                if (priority.trim().isNotEmpty)
                  _Tag(
                    priority.toUpperCase(),
                    _BridgePointPropertiesV2State._amber,
                  ),
                if (property['year_built'] != null)
                  _Tag(
                    'BUILT ${property['year_built']}',
                    _BridgePointPropertiesV2State._blue,
                  ),
                const _Tag('OPEN', _BridgePointPropertiesV2State._green),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 10), right],
              );
            }
            return Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Flexible(child: right),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _BridgePointPropertiesV2State._muted,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PropertyDetailSheet extends StatefulWidget {
  const _PropertyDetailSheet({required this.property});
  final Map<String, dynamic> property;

  @override
  State<_PropertyDetailSheet> createState() => _PropertyDetailSheetState();
}

class _PropertyDetailSheetState extends State<_PropertyDetailSheet> {
  late Future<List<dynamic>> _request;

  @override
  void initState() {
    super.initState();
    final id = '${widget.property['property_id']}';
    _request = Future.wait([
      _safe('bridgepoint_flutter_property_detail_v344', {'p_property_id': id}),
      _safe('bridgepoint_property_timeline_v78', {
        'p_property_id': id,
        'p_limit': 100,
      }),
      _safe('bridgepoint_property_geometry_v837', {
        'p_property_id': id,
        'p_limit': 25,
      }),
      _safe('bridgepoint_digital_twin_summary_v509', {'p_property_id': id}),
    ]);
  }

  Future<dynamic> _safe(String rpc, Map<String, dynamic> params) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return const <String, dynamic>{'available': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    final address =
        '${widget.property['full_address'] ?? widget.property['municipality'] ?? 'Property'}';
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .9,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: FutureBuilder<List<dynamic>>(
            future: _request,
            builder: (context, snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  address,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Property intelligence • timeline • building geometry • digital twin',
                  style: TextStyle(
                    color: _BridgePointPropertiesV2State._muted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (snapshot.hasError)
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(
                      color: _BridgePointPropertiesV2State._amber,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      _PayloadBlock(
                        title: 'Property 360',
                        icon: Icons.home_work_rounded,
                        payload: snapshot.data != null && snapshot.data!.isNotEmpty
                            ? snapshot.data![0]
                            : widget.property,
                      ),
                      const SizedBox(height: 10),
                      _PayloadBlock(
                        title: 'Property Timeline',
                        icon: Icons.timeline_rounded,
                        payload: snapshot.data != null && snapshot.data!.length > 1
                            ? snapshot.data![1]
                            : const {},
                      ),
                      const SizedBox(height: 10),
                      _PayloadBlock(
                        title: '2D / 3D Building Geometry',
                        icon: Icons.view_in_ar_rounded,
                        payload: snapshot.data != null && snapshot.data!.length > 2
                            ? snapshot.data![2]
                            : const {},
                      ),
                      const SizedBox(height: 10),
                      _PayloadBlock(
                        title: 'Digital Twin',
                        icon: Icons.threed_rotation_rounded,
                        payload: snapshot.data != null && snapshot.data!.length > 3
                            ? snapshot.data![3]
                            : const {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayloadBlock extends StatelessWidget {
  const _PayloadBlock({
    required this.title,
    required this.icon,
    required this.payload,
  });
  final String title;
  final IconData icon;
  final dynamic payload;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _BridgePointPropertiesV2State._panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: _BridgePointPropertiesV2State._cyan,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            _CompactPayload(payload: payload),
          ],
        ),
      );
}

class _CompactPayload extends StatelessWidget {
  const _CompactPayload({required this.payload});
  final dynamic payload;

  @override
  Widget build(BuildContext context) {
    if (payload is List) {
      final list = payload as List;
      return Column(
        children: [
          for (final item in list.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _CompactPayload(payload: item),
            ),
        ],
      );
    }
    if (payload is Map) {
      final entries = (payload as Map).entries.take(50).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in entries)
            if (e.value is! Map && e.value is! List)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${e.key.toString().replaceAll('_', ' ')}: ${e.value}',
                  style: const TextStyle(
                    color: _BridgePointPropertiesV2State._muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              )
            else
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  e.key.toString().replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10, bottom: 8),
                    child: _CompactPayload(payload: e.value),
                  ),
                ],
              ),
        ],
      );
    }
    return Text(
      '$payload',
      style: const TextStyle(
        color: _BridgePointPropertiesV2State._muted,
        fontSize: 12.5,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _BridgePointPropertiesV2State._panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: _BridgePointPropertiesV2State._muted,
                ),
              ),
            ),
          ],
        ),
      );
}
