import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointClaimsV2 extends StatefulWidget {
  const BridgePointClaimsV2({super.key});

  @override
  State<BridgePointClaimsV2> createState() => _BridgePointClaimsV2State();
}

class _BridgePointClaimsV2State extends State<BridgePointClaimsV2> {
  late Future<Map<String, dynamic>> _request;
  bool _busy = false;
  String? _message;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _amber = Color(0xFFFFC857);

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
    final raw = await Supabase.instance.client.rpc('bridgepoint_claims_workspace_v833', params: {'p_limit': 200});
    return _map(raw);
  }

  void _refresh() => setState(() => _request = _load());

  Future<void> _openClaim(Map<String, dynamic> saved) async {
    final carrier = TextEditingController();
    final damage = TextEditingController();
    final lossDate = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open claim workflow'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${saved['title'] ?? saved['address'] ?? 'Saved opportunity'}'),
            const SizedBox(height: 12),
            TextField(controller: lossDate, decoration: const InputDecoration(labelText: 'Date of loss (YYYY-MM-DD)')),
            const SizedBox(height: 10),
            TextField(controller: damage, decoration: const InputDecoration(labelText: 'Damage / claim type')),
            const SizedBox(height: 10),
            TextField(controller: carrier, decoration: const InputDecoration(labelText: 'Carrier')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open claim')),
        ],
      ),
    );
    if (approved != true) return;
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_open_claim_v78', params: {
        'p_saved_opportunity_id': saved['saved_opportunity_id'],
        'p_date_of_loss': lossDate.text.trim().isEmpty ? null : lossDate.text.trim(),
        'p_damage_type': damage.text.trim().isEmpty ? null : damage.text.trim(),
        'p_carrier_name': carrier.text.trim().isEmpty ? null : carrier.text.trim(),
      });
      final result = _map(raw);
      if (mounted) setState(() { _message = '${result['message'] ?? 'Claim opened.'}'; _request = _load(); });
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not open claim: $e');
    } finally {
      carrier.dispose(); damage.dispose(); lossDate.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateClaim(Map<String, dynamic> claim, List<String> stages) async {
    String stage = '${claim['claim_stage'] ?? 'CLAIM_FILED'}';
    final number = TextEditingController(text: '${claim['claim_number'] ?? ''}');
    final adjuster = TextEditingController(text: '${claim['adjuster_name'] ?? ''}');
    final estimate = TextEditingController(text: claim['estimate_amount'] == null ? '' : '${claim['estimate_amount']}');
    final approvedAmount = TextEditingController(text: claim['approved_amount'] == null ? '' : '${claim['approved_amount']}');
    final nextAction = TextEditingController(text: '${claim['next_action_at'] ?? ''}');
    final notes = TextEditingController(text: '${claim['notes_summary'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: const Text('Update claim'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(initialValue: stages.contains(stage) ? stage : stages.first, items: stages.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(), onChanged: (v) => setLocal(() => stage = v ?? stage), decoration: const InputDecoration(labelText: 'Stage')),
            const SizedBox(height: 10),
            TextField(controller: number, decoration: const InputDecoration(labelText: 'Claim number')),
            const SizedBox(height: 10),
            TextField(controller: adjuster, decoration: const InputDecoration(labelText: 'Adjuster name')),
            const SizedBox(height: 10),
            TextField(controller: estimate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimate amount')),
            const SizedBox(height: 10),
            TextField(controller: approvedAmount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Approved amount')),
            const SizedBox(height: 10),
            TextField(controller: nextAction, decoration: const InputDecoration(labelText: 'Next action timestamp (ISO, optional)')),
            const SizedBox(height: 10),
            TextField(controller: notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes / summary')),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save update')),
        ],
      )),
    );
    if (ok != true) return;
    setState(() { _busy = true; _message = null; });
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_update_claim_v78', params: {
        'p_claim_id': claim['claim_id'],
        'p_claim_stage': stage,
        'p_claim_number': number.text.trim().isEmpty ? null : number.text.trim(),
        'p_adjuster_name': adjuster.text.trim().isEmpty ? null : adjuster.text.trim(),
        'p_next_action_at': nextAction.text.trim().isEmpty ? null : nextAction.text.trim(),
        'p_estimate_amount': num.tryParse(estimate.text.trim()),
        'p_approved_amount': num.tryParse(approvedAmount.text.trim()),
        'p_notes_summary': notes.text.trim().isEmpty ? null : notes.text.trim(),
      });
      final result = _map(raw);
      if (mounted) setState(() { _message = 'Claim ${result['status'] ?? 'updated'}.'; _request = _load(); });
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not update claim: $e');
    } finally {
      number.dispose(); adjuster.dispose(); estimate.dispose(); approvedAmount.dispose(); nextAction.dispose(); notes.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _claimIntelligence(String claimId) async {
    final raw = await Supabase.instance.client.rpc('bridgepoint_claim_intelligence_v836', params: {'p_claim_id': claimId});
    return _map(raw);
  }

  Future<void> _showClaimIntelligence(Map<String, dynamic> claim) async {
    final claimId = '${claim['claim_id'] ?? ''}';
    if (claimId.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    Map<String, dynamic> intelligence;
    try {
      intelligence = await _claimIntelligence(claimId);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _message = 'Claim Intelligence unavailable: $e'; });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) {
        final access = _map(intelligence['access']);
        final caseInfo = _map(intelligence['case']);
        final damage = _rows(intelligence['damage_observations']);
        final estimates = _rows(intelligence['estimate_runs']);
        final policies = _rows(intelligence['policy_documents']);
        final findings = _rows(intelligence['policy_findings']);
        final gaps = _rows(intelligence['supplement_gaps']);
        final packets = _rows(intelligence['supplement_packets']);
        Future<void> runGapAnalysis() async {
          try {
            final raw = await Supabase.instance.client.rpc('bridgepoint_supplement_gap_v519', params: {'p_claim_id': claimId});
            final result = _map(raw);
            intelligence = await _claimIntelligence(claimId);
            setLocal(() {});
            if (mounted) setState(() => _message = 'Supplement analysis: ${result['status'] ?? 'complete'}');
          } catch (e) {
            if (mounted) setState(() => _message = 'Supplement analysis unavailable: $e');
          }
        }
        Future<void> createPacket() async {
          try {
            final raw = await Supabase.instance.client.rpc('bridgepoint_create_supplement_packet_v520', params: {'p_claim_id': claimId});
            final result = _map(raw);
            intelligence = await _claimIntelligence(claimId);
            setLocal(() {});
            if (mounted) setState(() => _message = 'Supplement packet: ${result['status'] ?? 'created'}');
          } catch (e) {
            if (mounted) setState(() => _message = 'Supplement packet unavailable: $e');
          }
        }
        return AlertDialog(
          title: const Row(children: [Icon(Icons.auto_awesome_rounded, color: _cyan), SizedBox(width: 8), Expanded(child: Text('Claim Intelligence'))]),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (intelligence['locked'] == true)
                  const _ClaimNotice('Claims Intelligence is not included in the active package.')
                else if ('${intelligence['status']}' == 'CLAIM_AI_CASE_NOT_READY')
                  const _ClaimNotice('Claim AI case is not ready yet. BridgePoint will not fabricate estimate/policy/supplement output before the required evidence pipeline exists.')
                else ...[
                  _ClaimSection('AI case status', caseInfo),
                  const SizedBox(height: 10),
                  _ClaimSection('Damage observations', {'count': damage.length, 'items': damage}),
                  const SizedBox(height: 10),
                  _ClaimSection('Evidence integrity', {'sealed_evidence_count': intelligence['evidence_seal_count'] ?? 0}),
                  const SizedBox(height: 10),
                  if (access['claim_estimate_ai'] == true)
                    _ClaimSection('AI repair estimates', {'runs': estimates})
                  else
                    const _ClaimNotice('AI Repair Estimate is not included in this package.'),
                  const SizedBox(height: 10),
                  if (access['policy_translation_ai'] == true) ...[
                    _ClaimSection('Policy documents', {'documents': policies}),
                    const SizedBox(height: 8),
                    _ClaimSection('Policy findings', {'findings': findings}),
                  ] else
                    const _ClaimNotice('Policy Translation is not included in this package.'),
                  const SizedBox(height: 10),
                  if (access['supplement_intelligence'] == true) ...[
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.tonalIcon(onPressed: runGapAnalysis, icon: const Icon(Icons.compare_arrows_rounded), label: const Text('Analyze supplement gaps')),
                      FilledButton.tonalIcon(onPressed: createPacket, icon: const Icon(Icons.inventory_2_outlined), label: const Text('Create review packet')),
                    ]),
                    const SizedBox(height: 8),
                    _ClaimSection('Supplement gaps', {'gaps': gaps}),
                    const SizedBox(height: 8),
                    _ClaimSection('Supplement packets', {'packets': packets}),
                  ] else
                    const _ClaimNotice('Smart Supplement Intelligence is not included in this package.'),
                ],
                const SizedBox(height: 12),
                Text('${intelligence['truth_notice'] ?? 'Claim intelligence requires human/professional review where indicated.'}', style: const TextStyle(color: _amber, fontSize: 10, height: 1.45)),
              ]),
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        );
      }),
    );
  }

  Widget _claimCard(Map<String, dynamic> claim, List<String> stages) {
    final tasks = _rows(claim['open_tasks']);
    final events = _rows(claim['recent_events']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${claim['title'] ?? claim['address'] ?? 'Claim'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text('${claim['address'] ?? ''}', style: const TextStyle(color: _muted, fontSize: 10)),
            ])),
            Chip(label: Text('${claim['claim_stage'] ?? 'CLAIM_FILED'}'.replaceAll('_', ' '))),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 6, children: [
            if (claim['claim_number'] != null) Text('Claim # ${claim['claim_number']}'),
            if (claim['carrier_name'] != null) Text('Carrier: ${claim['carrier_name']}'),
            if (claim['date_of_loss'] != null) Text('Loss: ${claim['date_of_loss']}'),
            if (claim['damage_type'] != null) Text('Type: ${claim['damage_type']}'),
            if (claim['estimate_amount'] != null) Text('Estimate: \$${claim['estimate_amount']}'),
            if (claim['approved_amount'] != null) Text('Approved: \$${claim['approved_amount']}'),
          ]),
          if ('${claim['notes_summary'] ?? ''}'.trim().isNotEmpty) ...[const SizedBox(height: 8), Text('${claim['notes_summary']}', style: const TextStyle(color: _muted))],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(onPressed: _busy ? null : () => _updateClaim(claim, stages), icon: const Icon(Icons.edit_note_rounded), label: const Text('Update claim')),
            FilledButton.tonalIcon(onPressed: _busy ? null : () => _showClaimIntelligence(claim), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Claim Intelligence')),
          ]),
          if (tasks.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Open tasks', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ...tasks.take(8).map((t) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.task_alt_outlined, size: 18, color: _cyan), title: Text('${t['title'] ?? t['task_type']}'), subtitle: Text('Due ${t['due_at'] ?? 'unscheduled'}'))),
          ],
          if (events.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Recent claim timeline', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ...events.take(8).map((e) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history_rounded, size: 18), title: Text('${e['title'] ?? e['event_type']}'), subtitle: Text('${e['occurred_at'] ?? ''}${e['description'] == null ? '' : ' • ${e['description']}'}'))),
          ],
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
        final claims = _rows(data['claims']);
        final eligible = _rows(data['eligible_saved_opportunities']);
        final stages = data['claim_stage_options'] is List ? List<String>.from(data['claim_stage_options']) : <String>['CLAIM_FILED'];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Claims Workspace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('Open, track and update claim workflows, then use entitled evidence, estimate, policy and supplement intelligence with human-review gates.', style: TextStyle(color: _muted, height: 1.45)),
            ])),
            IconButton.filledTonal(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          ]),
          if (_busy || snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: const TextStyle(color: _cyan))),
          const SizedBox(height: 12),
          if (eligible.isNotEmpty) ...[
            const Text('Start from saved opportunities', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: eligible.take(30).map((s) => ActionChip(avatar: const Icon(Icons.add_task_rounded), label: Text('${s['title'] ?? s['address'] ?? 'Saved opportunity'}'), onPressed: _busy ? null : () => _openClaim(s))).toList()),
            const SizedBox(height: 14),
          ],
          if (claims.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No claims opened yet. Save an opportunity in Operations, then start its claim workflow here.', style: TextStyle(color: _muted))))
          else
            ...claims.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _claimCard(c, stages))),
          const SizedBox(height: 10),
          Text('${data['truth_notice'] ?? 'Claims intelligence is decision support and does not independently establish coverage, damage, causation, liability or entitlement.'}', style: const TextStyle(color: _amber, fontSize: 10, height: 1.45)),
        ]);
      },
    );
  }
}

class _ClaimNotice extends StatelessWidget {
  const _ClaimNotice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(text, style: const TextStyle(color: Color(0xFF8FA5BF), height: 1.4))));
}

class _ClaimSection extends StatelessWidget {
  const _ClaimSection(this.title, this.value);
  final String title;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 7, children: value.entries.map((entry) {
            final raw = '${entry.value}';
            final text = raw.length > 1200 ? '${raw.substring(0, 1200)}…' : raw;
            return ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: SelectableText('${entry.key.replaceAll('_', ' ')}: $text', style: const TextStyle(fontSize: 9, height: 1.4)));
          }).toList()),
        ]),
      ),
    );
  }
}
