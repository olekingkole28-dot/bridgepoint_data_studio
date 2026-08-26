import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointIntegrationsHubV790 extends StatefulWidget {
  const BridgePointIntegrationsHubV790({super.key});

  @override
  State<BridgePointIntegrationsHubV790> createState() =>
      _BridgePointIntegrationsHubV790State();
}

class _BridgePointIntegrationsHubV790State
    extends State<BridgePointIntegrationsHubV790> {
  late Future<Map<String, dynamic>> _request;
  String _query = '';
  String _ecosystem = 'ALL';
  String _state = 'ALL';

  static const _panel = Color(0xFF0E2035);
  static const _panelSoft = Color(0xFF16324E);
  static const _muted = Color(0xFFB5C6D9);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await Supabase.instance.client.rpc(
      'bridgepoint_integration_catalog_v790',
    );
    if (raw is! Map) {
      throw const FormatException('Unexpected integration catalog response.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<dynamic> _list(dynamic value) => value is List ? value : const [];

  String _clean(String value) => value.replaceAll('_', ' ');

  Color _stateColor(String state) => switch (state) {
        'CONNECTED_VERIFIED' => _green,
        'EXPORT_READY' => _cyan,
        'CONFIGURABLE_SANDBOX' => _amber,
        'PROVIDER_ACCESS_REQUIRED' => _amber,
        'NOT_CURRENTLY_ACTIVATABLE' => _red,
        _ => _muted,
      };

  IconData _stateIcon(String state) => switch (state) {
        'CONNECTED_VERIFIED' => Icons.verified_rounded,
        'EXPORT_READY' => Icons.ios_share_rounded,
        'CONFIGURABLE_SANDBOX' => Icons.science_outlined,
        'PROVIDER_ACCESS_REQUIRED' => Icons.key_outlined,
        'NOT_CURRENTLY_ACTIVATABLE' => Icons.block_rounded,
        _ => Icons.extension_outlined,
      };

  void _refresh() => setState(() => _request = _load());

  Future<void> _requestActivation(Map<String, dynamic> connector) async {
    final key = '${connector['connector_key'] ?? ''}';
    final name = '${connector['display_name'] ?? key}';
    final note = TextEditingController();
    var existingAccount = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Request $name'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This records setup/interest only. BridgePoint will not show this connector as connected until credentials and a governed exchange are verified.',
                  style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I already have an account'),
                  value: existingAccount,
                  onChanged: (value) =>
                      setDialogState(() => existingAccount = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Setup note (optional)',
                    border: OutlineInputBorder(),
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
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Request activation'),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;

    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_request_integration_activation_v790',
        params: {
          'p_connector_key': key,
          'p_note': note.text.trim().isEmpty ? null : note.text.trim(),
          'p_existing_account': existingAccount,
        },
      );
      final result = _map(raw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['status'] == 'ALREADY_CONNECTED_VERIFIED'
                ? '$name is already connected and verified.'
                : 'Activation request recorded for $name.',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request activation: $error')),
      );
    }
  }

  Widget _metric(String label, Object? value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 3),
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _connectorCard(Map<String, dynamic> row) {
    final state = '${row['activation_state'] ?? 'UNKNOWN'}';
    final color = _stateColor(state);
    final latest = _map(row['latest_request']);
    final objects = _list(row['supported_objects']);
    final requirements = row['requirements'];
    final canRequest = state != 'CONNECTED_VERIFIED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(_stateIcon(state), color: color),
        ),
        title: Text(
          '${row['display_name'] ?? row['connector_key'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${row['ecosystem'] ?? 'Other'} • ${_clean('${row['integration_mode'] ?? 'UNKNOWN'}')}',
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ),
        trailing: Text(
          _clean(state),
          textAlign: TextAlign.right,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.swap_horiz_rounded, size: 17),
                label: Text(_clean('${row['integration_mode'] ?? 'UNKNOWN'}')),
              ),
              Chip(
                avatar: Icon(
                  row['canonical_export_enabled'] == true
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 17,
                ),
                label: Text(row['canonical_export_enabled'] == true
                    ? 'Canonical export ready'
                    : 'No canonical export'),
              ),
              Chip(
                avatar: Icon(
                  row['native_write_enabled'] == true
                      ? Icons.edit_outlined
                      : Icons.lock_outline,
                  size: 17,
                ),
                label: Text(row['native_write_enabled'] == true
                    ? 'Native write enabled'
                    : 'Writes disabled'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (objects.isNotEmpty) ...[
            const Text('SUPPORTED OBJECTS',
                style: TextStyle(
                    color: _cyan,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: objects
                  .map((item) => Chip(label: Text(_clean('$item'))))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (requirements != null) ...[
            const Text('ACTIVATION REQUIREMENTS',
                style: TextStyle(
                    color: _cyan,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            SelectableText('$requirements',
                style: const TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 12),
          ],
          if ('${row['notes'] ?? ''}'.trim().isNotEmpty) ...[
            Text('${row['notes']}',
                style: const TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 12),
          ],
          if (latest.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _panelSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Latest request: ${_clean('${latest['request_mode'] ?? 'REQUEST'}')} • ${_clean('${latest['status'] ?? 'UNKNOWN'}')}\n${latest['requested_at'] ?? ''}',
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: canRequest
                ? FilledButton.icon(
                    onPressed: () => _requestActivation(row),
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('Request setup'),
                  )
                : const Chip(
                    avatar: Icon(Icons.verified_rounded, color: _green),
                    label: Text('Connected + verified'),
                  ),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load integrations: ${snapshot.error}',
                  style: const TextStyle(color: _red)),
            ),
          );
        }

        final payload = snapshot.data ?? const <String, dynamic>{};
        final allRows = (payload['connectors'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        final ecosystems = <String>{
          'ALL',
          ...allRows.map((row) => '${row['ecosystem'] ?? ''}'),
        }.where((value) => value.isNotEmpty).toList()
          ..sort((a, b) => a == 'ALL' ? -1 : a.compareTo(b));
        final states = <String>{
          'ALL',
          ...allRows.map((row) => '${row['activation_state'] ?? ''}'),
        }.where((value) => value.isNotEmpty).toList()
          ..sort((a, b) => a == 'ALL' ? -1 : a.compareTo(b));
        final needle = _query.trim().toLowerCase();
        final rows = allRows.where((row) {
          if (_ecosystem != 'ALL' && '${row['ecosystem']}' != _ecosystem) {
            return false;
          }
          if (_state != 'ALL' && '${row['activation_state']}' != _state) {
            return false;
          }
          if (needle.isEmpty) return true;
          return [
            row['connector_key'],
            row['display_name'],
            row['ecosystem'],
            row['integration_mode'],
            row['activation_state'],
            row['supported_objects'],
            row['requirements'],
            row['notes'],
          ].join(' ').toLowerCase().contains(needle);
        }).toList();

        final connected = allRows
            .where((row) => row['activation_state'] == 'CONNECTED_VERIFIED')
            .length;
        final exportReady = allRows
            .where((row) => row['canonical_export_enabled'] == true)
            .length;
        final requests = allRows
            .where((row) => _map(row['latest_request']).isNotEmpty)
            .length;

        return RefreshIndicator(
          onRefresh: () async {
            _refresh();
            await _request;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Integrations Hub',
                            style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text(
                          'Truthful connector state across BridgePoint. Connected means verified credentials plus a successful governed exchange—never just a configured button.',
                          style: TextStyle(color: _muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh integrations',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metric('CONNECTORS', allRows.length, _cyan),
                  _metric('VERIFIED', connected, _green),
                  _metric('EXPORT READY', exportReady, _cyan),
                  _metric('REQUESTED', requests, _amber),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'Search connector or supported object',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _ecosystem,
                      items: ecosystems
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(_clean(item)),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _ecosystem = value ?? 'ALL'),
                      decoration: const InputDecoration(
                        labelText: 'Ecosystem',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 245,
                    child: DropdownButtonFormField<String>(
                      initialValue: _state,
                      items: states
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(_clean(item)),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _state = value ?? 'ALL'),
                      decoration: const InputDecoration(
                        labelText: 'Connection state',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('${rows.length} matching connectors',
                  style: const TextStyle(color: _muted, fontSize: 11.5)),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Card(
                  color: _panel,
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No matching connectors.',
                        style: TextStyle(color: _muted)),
                  ),
                )
              else
                ...rows.map(_connectorCard),
              const SizedBox(height: 8),
              Text(
                '${payload['truth_rule'] ?? ''}',
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
            ],
          ),
        );
      },
    );
  }
}
