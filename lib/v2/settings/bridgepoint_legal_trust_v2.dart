import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointLegalTrustV2 extends StatefulWidget {
  const BridgePointLegalTrustV2({super.key});

  @override
  State<BridgePointLegalTrustV2> createState() => _BridgePointLegalTrustV2State();
}

class _BridgePointLegalTrustV2State extends State<BridgePointLegalTrustV2> {
  late Future<Map<String, dynamic>> _request;
  bool _busy = false;
  String? _message;

  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);
  static const _amber = Color(0xFFFFC95E);
  static const _green = Color(0xFF45E6A6);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await Supabase.instance.client.rpc('bridgepoint_security_center_v147');
    return _map(raw);
  }

  void _refresh() => setState(() => _request = _load());

  Future<void> _acceptRequired(Map<String, dynamic> payload) async {
    final legal = _map(payload['legal_state']);
    final docs = _rows(legal['documents']);
    final keys = docs
        .where((d) => d['required'] == true && d['accepted'] != true)
        .map((d) => '${d['document_key'] ?? ''}')
        .where((key) => key.isNotEmpty)
        .toList();
    if (keys.isEmpty) {
      setState(() => _message = 'All required legal documents are already accepted.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept required legal documents?'),
        content: Text(
          'You are accepting ${keys.length} currently required BridgePoint document${keys.length == 1 ? '' : 's'} at the versions shown in this Legal & Trust Center.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept required documents'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_accept_legal_v82',
        params: {
          'p_document_keys': keys,
          'p_acceptance_source': 'CLEAN_V2_LEGAL_TRUST_CENTER',
        },
      );
      if (mounted) {
        setState(() {
          _message = 'Required legal documents accepted.';
          _request = _load();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not record acceptance: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _privacyRequest() async {
    String type = 'ACCESS';
    final message = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Privacy request'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'ACCESS', child: Text('Access my data')),
                    DropdownMenuItem(value: 'CORRECTION', child: Text('Correct my data')),
                    DropdownMenuItem(value: 'DELETION', child: Text('Delete eligible data')),
                    DropdownMenuItem(value: 'EXPORT', child: Text('Export my data')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other privacy request')),
                  ],
                  onChanged: (value) => setLocal(() => type = value ?? 'ACCESS'),
                  decoration: const InputDecoration(labelText: 'Request type'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: message,
                  minLines: 3,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: 'Explain what you need BridgePoint to review.',
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
              child: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) {
      message.dispose();
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_submit_privacy_request_v82',
        params: {'p_request_type': type, 'p_message': message.text.trim()},
      );
      final result = _map(raw);
      if (mounted) {
        setState(() => _message =
            '${result['message'] ?? 'Privacy request submitted.'}');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Privacy request unavailable: $e');
    } finally {
      message.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportIncident() async {
    String severity = 'MEDIUM';
    final type = TextEditingController();
    final description = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Report security concern'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: type,
                  decoration: const InputDecoration(
                    labelText: 'Concern type',
                    hintText: 'Example: suspicious login or unexpected access',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text('Low')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                    DropdownMenuItem(value: 'HIGH', child: Text('High')),
                    DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                  ],
                  onChanged: (value) =>
                      setLocal(() => severity = value ?? 'MEDIUM'),
                  decoration: const InputDecoration(labelText: 'Severity'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: 'What happened?'),
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
              child: const Text('Report concern'),
            ),
          ],
        ),
      ),
    );
    if (submit != true) {
      type.dispose();
      description.dispose();
      return;
    }
    if (type.text.trim().isEmpty || description.text.trim().isEmpty) {
      setState(() => _message = 'Add a concern type and description first.');
      type.dispose();
      description.dispose();
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_report_security_incident_v147',
        params: {
          'p_incident_type': type.text.trim(),
          'p_severity': severity,
          'p_description': description.text.trim(),
          'p_metadata': {'source': 'CLEAN_V2_LEGAL_TRUST_CENTER'},
        },
      );
      final result = _map(raw);
      if (mounted) {
        setState(() {
          _message = '${result['message'] ?? 'Security concern reported.'}';
          _request = _load();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not report concern: $e');
    } finally {
      type.dispose();
      description.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _document(Map<String, dynamic> doc) {
    final accepted = doc['accepted'] == true;
    return Card(
      child: ExpansionTile(
        leading: Icon(
          accepted ? Icons.verified_rounded : Icons.gavel_rounded,
          color: accepted ? _green : _amber,
        ),
        title: Text(
          '${doc['title'] ?? doc['document_key'] ?? 'Legal document'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Version ${doc['document_version'] ?? '—'} • ${accepted ? 'Accepted' : doc['required'] == true ? 'Acceptance required' : 'Available'}',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${doc['summary'] ?? ''}',
              style: const TextStyle(color: _muted, height: 1.45),
            ),
          ),
          if ('${doc['content_markdown'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                '${doc['content_markdown']}',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final legal = _map(data['legal_state']);
        final documents = _rows(legal['documents']);
        final recommendations = _rows(data['recommendations']);
        final events = _rows(data['recent_security_events']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Legal & Trust',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text(
                        'Legal acceptance, privacy controls, security posture and customer trust information from the live BridgePoint contracts.',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh trust state',
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    legal['required_acceptance_missing'] == true
                        ? Icons.warning_amber_rounded
                        : Icons.verified_rounded,
                    size: 17,
                    color: legal['required_acceptance_missing'] == true
                        ? _amber
                        : _green,
                  ),
                  label: Text(
                    legal['required_acceptance_missing'] == true
                        ? '${legal['missing_count'] ?? 0} legal acceptance${legal['missing_count'] == 1 ? '' : 's'} required'
                        : 'Required legal documents accepted',
                  ),
                ),
                Chip(
                  avatar: Icon(
                    data['mfa_active'] == true
                        ? Icons.verified_user_rounded
                        : Icons.shield_outlined,
                    size: 17,
                    color: data['mfa_active'] == true ? _green : _amber,
                  ),
                  label: Text(data['mfa_active'] == true ? 'MFA-backed session' : 'MFA recommended'),
                ),
                Chip(label: Text('${data['open_incidents'] ?? 0} open security incidents')),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _acceptRequired(data),
                  icon: const Icon(Icons.gavel_rounded),
                  label: const Text('Review / accept required legal'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _privacyRequest,
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy request'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _reportIncident,
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('Report security concern'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (documents.isNotEmpty) ...[
              const Text('Legal documents',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...documents.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _document(doc),
                  )),
            ],
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Security recommendations',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...recommendations.map((row) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.shield_outlined, color: _cyan),
                      title: Text('${row['title'] ?? row['key'] ?? 'Recommendation'}'),
                      subtitle: Text('${row['detail'] ?? ''}'),
                      trailing: Text('${row['priority'] ?? ''}',
                          style: const TextStyle(fontSize: 11.5, color: _muted)),
                    ),
                  )),
            ],
            if (events.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Recent security events',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                children: events.map((row) => ListTile(
                      dense: true,
                      title: Text('${row['summary'] ?? row['event_type'] ?? 'Security event'}'),
                      subtitle: Text('${row['event_type'] ?? ''} • ${row['created_at'] ?? ''}'),
                      trailing: Text('${row['severity'] ?? ''}',
                          style: const TextStyle(fontSize: 9)),
                    )).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Attorney review status: ${legal['attorney_review_status'] ?? 'not reported by backend'}. BridgePoint does not represent automated legal text as attorney advice.',
              style: const TextStyle(color: _amber, fontSize: 11.5, height: 1.45),
            ),
          ],
        );
      },
    );
  }
}
