import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointIntegrationsHub extends StatefulWidget {
  const BridgePointIntegrationsHub({super.key});

  @override
  State<BridgePointIntegrationsHub> createState() =>
      _BridgePointIntegrationsHubState();
}

class _BridgePointIntegrationsHubState
    extends State<BridgePointIntegrationsHub> {
  late Future<Map<String, dynamic>> _request;
  String _query = '';
  String _ecosystem = 'ALL';
  String? _busyConnector;

  static const _panel = Color(0xFF0E2035);
  static const _panelSoft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

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

  Future<void> _requestActivation(Map<String, dynamic> connector) async {
    final key = '${connector['connector_key'] ?? ''}';
    if (key.isEmpty) return;
    final status = '${connector['status'] ?? ''}';
    final existingController = TextEditingController();
    var existingAccount = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: _panel,
          title: Text('Connect ${connector['display_name']}'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == 'BLOCKED'
                      ? 'This provider is not currently self-activatable. BridgePoint can record your interest without claiming a live connection.'
                      : 'BridgePoint will record a setup request. A request never means the provider is connected; credentials, rights and a successful governed exchange still have to be verified.',
                  style: const TextStyle(color: _muted, height: 1.45),
                ),
                const SizedBox(height: 12),
                if (status != 'BLOCKED')
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: existingAccount,
                    onChanged: (value) =>
                        setLocal(() => existingAccount = value == true),
                    title: const Text(
                      'I already have an authorized provider account / API access',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                TextField(
                  controller: existingController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Setup note (optional)',
                    hintText:
                        'Example: We already use this provider and want BridgePoint to exchange property intelligence with it.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(status == 'BLOCKED'
                  ? 'Register interest'
                  : 'Request connection'),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busyConnector = key);
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_request_integration_activation_v790',
        params: {
          'p_connector_key': key,
          'p_note': existingController.text.trim().isEmpty
              ? null
              : existingController.text.trim(),
          'p_existing_account': existingAccount,
        },
      );
      if (!mounted) return;
      setState(() => _request = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Integration request recorded. BridgePoint will keep it separate from verified connection status.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record request: $error')),
        );
      }
    } finally {
      existingController.dispose();
      if (mounted) setState(() => _busyConnector = null);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'LIVE_VERIFIED':
      case 'READY_CANONICAL_EXPORT':
        return _green;
      case 'SANDBOX':
      case 'PARTNER_ACTIVATION_REQUIRED':
        return _amber;
      default:
        return _muted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'LIVE_VERIFIED':
        return 'CONNECTED • VERIFIED';
      case 'READY_CANONICAL_EXPORT':
        return 'EXPORT READY';
      case 'SANDBOX':
        return 'SANDBOX / CONFIGURABLE';
      case 'PARTNER_ACTIVATION_REQUIRED':
        return 'PROVIDER ACCESS REQUIRED';
      case 'BLOCKED':
        return 'NOT CURRENTLY ACTIVATABLE';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final rows = (snapshot.data?['connectors'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final ecosystems = <String>{
          'ALL',
          ...rows.map((row) => '${row['ecosystem'] ?? 'OTHER'}'),
        }.toList()
          ..sort((a, b) => a == 'ALL' ? -1 : a.compareTo(b));
        final needle = _query.trim().toLowerCase();
        final visible = rows.where((row) {
          final ecosystem = '${row['ecosystem'] ?? ''}';
          if (_ecosystem != 'ALL' && ecosystem != _ecosystem) return false;
          if (needle.isEmpty) return true;
          final haystack = [
            row['display_name'],
            row['ecosystem'],
            row['integration_mode'],
            row['status'],
            ...(row['supported_objects'] as List? ?? const []),
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Integrations Hub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Connect BridgePoint to the systems your team already uses — and move BridgePoint intelligence back out through governed, auditable interfaces.',
              style: TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cyan.withOpacity(.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cyan.withOpacity(.18)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: _cyan, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Truth rule: “Connected” is reserved for verified credentials plus a successful governed exchange. Sandbox, partner-required, blocked and interest-only states stay visibly different.',
                      style:
                          TextStyle(color: _muted, fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ),
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
                      labelText: 'Search integrations or objects',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    value: ecosystems.contains(_ecosystem) ? _ecosystem : 'ALL',
                    decoration: const InputDecoration(
                      labelText: 'Ecosystem',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: _panelSoft,
                    items: ecosystems
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _ecosystem = value ?? 'ALL'),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh integrations',
                  onPressed: () => setState(() => _request = _load()),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _MessageCard(
                icon: Icons.error_outline_rounded,
                title: 'Integration catalog unavailable',
                message: snapshot.error.toString(),
              )
            else if (visible.isEmpty)
              const _MessageCard(
                icon: Icons.search_off_rounded,
                title: 'No matching integrations',
                message: 'Try another provider, object, or ecosystem.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1200
                      ? 3
                      : constraints.maxWidth >= 760
                          ? 2
                          : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: visible
                        .map((row) => SizedBox(
                              width: width,
                              child: _connectorCard(row),
                            ))
                        .toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _connectorCard(Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    final color = _statusColor(status);
    final objects = (row['supported_objects'] as List? ?? const [])
        .map((value) => '$value'.replaceAll('_', ' '))
        .toList();
    final latest = row['latest_request'];
    final busy = _busyConnector == '${row['connector_key']}';
    final canRequest =
        status != 'LIVE_VERIFIED' && status != 'READY_CANONICAL_EXPORT';

    return Card(
      color: _panel,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(.12),
                  child: Icon(Icons.hub_outlined, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['display_name'] ?? row['connector_key']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${row['ecosystem'] ?? ''} • ${row['integration_mode'] ?? ''}',
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(.09),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withOpacity(.2)),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ),
            const SizedBox(height: 11),
            Text(
              'BridgePoint export: ${row['canonical_export_enabled'] == true ? 'available' : 'not enabled'} • Native write: ${row['native_write_enabled'] == true ? 'enabled' : 'disabled until verified'}',
              style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
            ),
            if (objects.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: objects
                    .take(8)
                    .map((value) => Chip(
                          visualDensity: VisualDensity.compact,
                          label:
                              Text(value, style: const TextStyle(fontSize: 8)),
                        ))
                    .toList(),
              ),
            ],
            if (latest is Map) ...[
              const SizedBox(height: 10),
              Text(
                'Latest request: ${latest['status'] ?? 'REQUESTED'} • ${latest['request_mode'] ?? ''}',
                style: const TextStyle(color: _amber, fontSize: 9),
              ),
            ],
            const SizedBox(height: 12),
            if (status == 'LIVE_VERIFIED')
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: _green, size: 18),
                  SizedBox(width: 7),
                  Text('Verified live connection',
                      style: TextStyle(
                          color: _green, fontWeight: FontWeight.w800)),
                ],
              )
            else if (status == 'READY_CANONICAL_EXPORT')
              const Row(
                children: [
                  Icon(Icons.file_download_done_rounded,
                      color: _green, size: 18),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text('Portable BridgePoint export is ready',
                        style: TextStyle(
                            color: _green, fontWeight: FontWeight.w800)),
                  ),
                ],
              )
            else if (canRequest)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => _requestActivation(row),
                  icon: busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cable_rounded),
                  label: Text(status == 'BLOCKED'
                      ? 'Register interest'
                      : latest is Map
                          ? 'Update connection request'
                          : 'Request connection'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _BridgePointIntegrationsHubState._panel,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: _BridgePointIntegrationsHubState._amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(message,
                      style: const TextStyle(
                          color: _BridgePointIntegrationsHubState._muted,
                          fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
