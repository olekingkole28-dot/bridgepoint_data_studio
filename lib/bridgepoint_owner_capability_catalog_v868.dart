import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerCapabilityCatalogV868 extends StatefulWidget {
  const BridgePointOwnerCapabilityCatalogV868({super.key});

  @override
  State<BridgePointOwnerCapabilityCatalogV868> createState() =>
      _BridgePointOwnerCapabilityCatalogV868State();
}

class _BridgePointOwnerCapabilityCatalogV868State
    extends State<BridgePointOwnerCapabilityCatalogV868> {
  late Future<Map<String, dynamic>> _request;
  String _query = '';
  String _domain = 'ALL';
  String _experience = 'ALL';

  static const _panel = Color(0xFF0E2035);
  static const _panelSoft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await Supabase.instance.client.rpc(
      'bridgepoint_capability_experience_v550',
      params: const {'p_include_all': true},
    );
    if (raw is! Map) {
      throw const FormatException('Unexpected capability catalog response.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _clean(String value) => value.replaceAll('_', ' ');

  Color _statusColor(String value) {
    if (value == 'AVAILABLE NOW') return _green;
    if (value.contains('LIVE ENGINE')) return _cyan;
    if (value.contains('BACKEND READY')) return _amber;
    if (value.contains('WAITING')) return _red;
    if (value.contains('PARTIAL')) return _amber;
    return _muted;
  }

  void _refresh() => setState(() => _request = _load());

  Widget _metric(String label, dynamic value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _card(Map<String, dynamic> row) {
    final experience = '${row['experience_status'] ?? 'UNKNOWN'}';
    final color = _statusColor(experience);
    return Card(
      color: _panel,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(Icons.memory_rounded, color: color, size: 18),
        ),
        title: Text(
          '${row['capability_name'] ?? row['capability_key'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${row['domain'] ?? 'OTHER'} • ${_clean('${row['implementation_status'] ?? 'UNKNOWN'}')} • ${_clean('${row['customer_status'] ?? 'UNKNOWN'}')}',
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ),
        trailing: Text(
          experience,
          textAlign: TextAlign.right,
          style: TextStyle(
              color: color, fontSize: 10.5, fontWeight: FontWeight.w900),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ('${row['plain_english'] ?? ''}'.trim().isNotEmpty) ...[
            Text('${row['plain_english']}',
                style: const TextStyle(color: Colors.white, height: 1.45)),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              Chip(label: Text('Automation: ${_clean('${row['automation_status'] ?? 'UNKNOWN'}')}')),
              Chip(label: Text('Validation: ${_clean('${row['validation_status'] ?? 'UNKNOWN'}')}')),
              Chip(label: Text('Dependencies: ${_clean('${row['dependency_status'] ?? 'UNKNOWN'}')}')),
              if (row['workspace_label'] != null)
                Chip(label: Text('Workspace: ${row['workspace_label']}')),
            ],
          ),
          const SizedBox(height: 10),
          if ('${row['truthful_claim'] ?? ''}'.trim().isNotEmpty) ...[
            const Text('TRUTHFUL CLAIM',
                style: TextStyle(
                    color: _green,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            SelectableText('${row['truthful_claim']}',
                style: const TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 10),
          ],
          if ('${row['prohibited_claim'] ?? ''}'.trim().isNotEmpty) ...[
            const Text('DO NOT CLAIM',
                style: TextStyle(
                    color: _red,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            SelectableText('${row['prohibited_claim']}',
                style: const TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 10),
          ],
          if ('${row['what_it_needs'] ?? ''}'.trim().isNotEmpty) ...[
            const Text('WHAT IT NEEDS',
                style: TextStyle(
                    color: _amber,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            SelectableText('${row['what_it_needs']}',
                style: const TextStyle(color: _muted, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Text(
            'Capability key: ${row['capability_key'] ?? ''}',
            style: const TextStyle(
                color: _muted, fontSize: 11.5, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _cyan));
        }
        if (snapshot.hasError) {
          return Card(
            color: _panel,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Capability catalog unavailable: ${snapshot.error}',
                  style: const TextStyle(color: _red)),
            ),
          );
        }
        final payload = snapshot.data ?? const <String, dynamic>{};
        final summary = _map(payload['summary']);
        final rows = (payload['capabilities'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        final domains = <String>{
          'ALL',
          ...rows.map((row) => '${row['domain'] ?? ''}'),
        }.where((value) => value.isNotEmpty).toList()
          ..sort((a, b) => a == 'ALL' ? -1 : a.compareTo(b));
        final experiences = <String>{
          'ALL',
          ...rows.map((row) => '${row['experience_status'] ?? ''}'),
        }.where((value) => value.isNotEmpty).toList()
          ..sort((a, b) => a == 'ALL' ? -1 : a.compareTo(b));
        final needle = _query.trim().toLowerCase();
        final visible = rows.where((row) {
          if (_domain != 'ALL' && '${row['domain']}' != _domain) return false;
          if (_experience != 'ALL' &&
              '${row['experience_status']}' != _experience) return false;
          if (needle.isEmpty) return true;
          return [
            row['capability_key'],
            row['capability_name'],
            row['domain'],
            row['plain_english'],
            row['truthful_claim'],
            row['prohibited_claim'],
            row['what_it_needs'],
            row['workspace_label'],
          ].join(' ').toLowerCase().contains(needle);
        }).toList();

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
                      Text('Owner capability catalog',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text(
                        'Search what BridgePoint can actually do, what is customer-ready, what is internal, what is blocked, and what still needs validation or external access.',
                        style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh capabilities',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metric('SHOWN', summary['shown'] ?? rows.length, _cyan),
                _metric('LIVE', summary['live'] ?? 0, _green),
                _metric('CUSTOMER READY', summary['customer_ready'] ?? 0, _green),
                _metric('HIDDEN', summary['hidden'] ?? 0, _amber),
                _metric('INTERNAL', summary['internal'] ?? 0, _muted),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 390,
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Search backend capability',
                      hintText: 'Try climate, claims, imagery, digital twin, risk…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _domain,
                    items: domains
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_clean(value)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _domain = value ?? 'ALL'),
                    decoration: const InputDecoration(
                      labelText: 'Domain',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: _experience,
                    items: experiences
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _experience = value ?? 'ALL'),
                    decoration: const InputDecoration(
                      labelText: 'Experience state',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${visible.length} matching capabilities',
                style: const TextStyle(color: _muted, fontSize: 11.5)),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              const Card(
                color: _panelSoft,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No matching capabilities.',
                      style: TextStyle(color: _muted)),
                ),
              )
            else
              ...visible.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _card(row),
                  )),
          ],
        );
      },
    );
  }
}
