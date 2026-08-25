import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointProperty360V2 extends StatefulWidget {
  const BridgePointProperty360V2({super.key});

  @override
  State<BridgePointProperty360V2> createState() => _BridgePointProperty360V2State();
}

class _BridgePointProperty360V2State extends State<BridgePointProperty360V2> {
  final _query = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];
  String? _propertyId;
  String? _municipality;
  Map<String, dynamic> _detail = const {};
  Map<String, dynamic> _timeline = const {};
  Map<String, dynamic> _climate = const {};
  Map<String, dynamic> _twin = const {};
  Map<String, dynamic> _permits = const {};
  Map<String, dynamic> _media = const {};
  Map<String, dynamic> _notes = const {};
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
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const ['items','results','properties','suggestions','rows','events','notes','media']) {
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
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _busy = true;
      _error = null;
      _propertyId = null;
      _results = const [];
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_suggestions_v192',
        params: {'p_query': q, 'p_limit': 30},
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
      _propertyId = id;
      _municipality = municipality.isEmpty ? null : municipality;
    });
    final values = await Future.wait([
      _safe('bridgepoint_flutter_property_detail_v344', {'p_property_id': id}),
      _safe('bridgepoint_property_timeline_v78', {'p_property_id': id, 'p_limit': 250}),
      _safe('bridgepoint_property_climate_profile_v510', {'p_property_id': id}),
      _safe('bridgepoint_digital_twin_summary_v509', {'p_property_id': id}),
      municipality.isEmpty
          ? Future.value({'available': false, 'reason': 'Municipality unavailable'})
          : _safe('bridgepoint_flutter_permit_context_v68', {'p_municipality': municipality}),
      _safe('bridgepoint_property_media_bundle_v169', {'p_property_id': id}),
      _safe('bridgepoint_customer_notes_v70', {'p_property_id': id, 'p_limit': 100}),
    ]);
    if (!mounted) return;
    setState(() {
      _detail = _map(values[0]);
      _timeline = _map(values[1]);
      _climate = _map(values[2]);
      _twin = _map(values[3]);
      _permits = _map(values[4]);
      _media = _map(values[5]);
      _notes = _map(values[6]);
      _tab = 0;
      _busy = false;
    });
  }

  Future<void> _saveNote() async {
    final id = _propertyId;
    final text = _note.text.trim();
    if (id == null || text.isEmpty) return;
    setState(() => _busy = true);
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
      final raw = await _safe('bridgepoint_customer_notes_v70', {'p_property_id': id, 'p_limit': 100});
      if (mounted) setState(() => _notes = _map(raw));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(Map<String, dynamic> row) {
    final address = '${row['address'] ?? row['full_address'] ?? row['property_address'] ?? ''}'.trim();
    if (address.isNotEmpty) return address;
    return '${row['property_id'] ?? 'Property'}';
  }

  Widget _section(String title, dynamic value, IconData icon) {
    final rows = _list(value);
    final map = _map(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: _cyan), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 10),
          if (rows.isEmpty) _KeyValues(map) else ...rows.take(40).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _KeyValues(e))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Property 360', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('One canonical property object: identity, owner/provenance, Property DNA, Why Now, climate risk, Digital Twin fidelity, permits, imagery, notes and actions.', style: TextStyle(color: _muted, height: 1.45)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: TextField(controller: _query, onSubmitted: (_) => _search(), decoration: const InputDecoration(labelText: 'Address, parcel, owner, city or property', prefixIcon: Icon(Icons.search_rounded)))),
        const SizedBox(width: 10),
        FilledButton.icon(onPressed: _busy ? null : _search, icon: const Icon(Icons.search_rounded), label: const Text('Search')),
      ]),
      if (_busy) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
      if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Color(0xFFFF7E7E)))],
      const SizedBox(height: 14),
      if (_propertyId == null)
        if (_results.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Search a property to open the full BridgePoint intelligence workspace.', style: TextStyle(color: _muted))))
        else
          ..._results.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0x1635D2E8), child: Icon(Icons.home_work_outlined, color: _cyan)),
                  title: Text(_label(row), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([row['city'], row['state_code'], row['county_name'], row['parcel_id'] ?? row['parcel_number']].where((e) => e != null && '$e'.trim().isNotEmpty).join(' • ')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(row),
                )),
              ))
      else ...[
        Row(children: [
          IconButton.filledTonal(onPressed: () => setState(() => _propertyId = null), icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_label(_detail), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            Text('Property ID $_propertyId${_municipality == null ? '' : ' • $_municipality'}', style: const TextStyle(color: _muted, fontSize: 10)),
          ])),
          const Chip(avatar: Icon(Icons.verified_user_outlined, size: 16), label: Text('SOURCE-BACKED')),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.badge_outlined), label: Text('Overview')),
              ButtonSegment(value: 1, icon: Icon(Icons.timeline_rounded), label: Text('Property DNA')),
              ButtonSegment(value: 2, icon: Icon(Icons.shield_outlined), label: Text('Risk + Twin')),
              ButtonSegment(value: 3, icon: Icon(Icons.photo_library_outlined), label: Text('Permits + Media')),
              ButtonSegment(value: 4, icon: Icon(Icons.task_alt_rounded), label: Text('Notes + Actions')),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
          ),
        ),
        const SizedBox(height: 12),
        if (_tab == 0) _section('Canonical property + Why Now', _detail, Icons.home_work_rounded),
        if (_tab == 1) _section('Property DNA / evidence timeline', _timeline, Icons.timeline_rounded),
        if (_tab == 2) ...[
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 520, child: _section('Climate / peril profile', _climate, Icons.thermostat_rounded)),
            SizedBox(width: 520, child: _section('Digital Twin fidelity', _twin, Icons.view_in_ar_rounded)),
          ]),
          const SizedBox(height: 8),
          const Text('Risk scores are prioritization/model output, not proof of damage or future loss. Twin levels are shown at their actual fidelity; low-fidelity massing is never labeled an exact replica.', style: TextStyle(color: _amber, fontSize: 10)),
        ],
        if (_tab == 3)
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 520, child: _section('Permit / municipal context', _permits, Icons.description_outlined)),
            SizedBox(width: 520, child: _section('Imagery / media history', _media, Icons.photo_library_outlined)),
          ]),
        if (_tab == 4) ...[
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Add property note', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            TextField(controller: _note, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'Observation, follow-up, customer-safe note...')),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _busy ? null : _saveNote, icon: const Icon(Icons.save_rounded), label: const Text('Save note'))),
          ]))),
          const SizedBox(height: 10),
          _section('Notes / follow-up history', _notes, Icons.sticky_note_2_outlined),
        ],
      ],
    ]);
  }
}

class _KeyValues extends StatelessWidget {
  const _KeyValues(this.value);
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const Text('No records returned.', style: TextStyle(color: Color(0xFF8FA5BF)));
    return Wrap(spacing: 10, runSpacing: 7, children: value.entries.take(30).map((entry) {
      final raw = '${entry.value}';
      final text = raw.length > 300 ? '${raw.substring(0, 300)}…' : raw;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF081625), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x2235D2E8))),
          child: Text('${entry.key.replaceAll('_', ' ')}: $text', style: const TextStyle(fontSize: 9, height: 1.35)),
        ),
      );
    }).toList());
  }
}
