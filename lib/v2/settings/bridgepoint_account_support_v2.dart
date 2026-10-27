import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bridgepoint_packages_v2.dart';

class BridgePointAccountSupportV2 extends StatefulWidget {
  const BridgePointAccountSupportV2({super.key});

  @override
  State<BridgePointAccountSupportV2> createState() =>
      _BridgePointAccountSupportV2State();
}

class _BridgePointAccountSupportV2State
    extends State<BridgePointAccountSupportV2> {
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);

  int tab = 0;
  late Future<List<dynamic>> request;
  final feedback = TextEditingController();
  String feedbackCategory = 'suggestion';
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    request = _load();
  }

  @override
  void dispose() {
    feedback.dispose();
    super.dispose();
  }

  Future<dynamic> _safe(String rpc) async {
    try {
      return await Supabase.instance.client.rpc(rpc);
    } catch (e) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_settings_v59'),
        _safe('bridgepoint_my_purchases_v223'),
        _safe('bridgepoint_team_workspace_v80'),
        _safe('bridgepoint_display_preferences_v80'),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value, List<String> keys) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in keys) {
        if (value[key] is List) return _rows(value[key], keys);
      }
    }
    return const [];
  }

  Future<void> _openBillingPortal() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'bridgepoint-billing-portal-v66',
        body: const {},
      );
      final data = _map(response.data);
      final url = '${data['url'] ?? ''}'.trim();
      if (data['complete'] != true || url.isEmpty) {
        throw StateError('${data['error'] ?? 'Billing portal unavailable.'}');
      }
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the secure billing portal.');
      }
      if (mounted) setState(() => message = 'Secure Stripe billing portal opened.');
    } catch (e) {
      if (mounted) setState(() => message = 'Billing portal: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendFeedback() async {
    final text = feedback.text.trim();
    if (text.isEmpty) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_submit_feedback_v70',
        params: {
          'p_category': feedbackCategory,
          'p_page_key': 'products_settings_v2',
          'p_message': text,
        },
      );
      feedback.clear();
      if (mounted) setState(() => message = 'Feedback sent to BridgePoint review.');
    } catch (e) {
      if (mounted) setState(() => message = 'Could not send feedback: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _shareBridgePoint() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'BridgePoint Intelligence — property intelligence, live map, evidence, timelines, opportunity scoring and national expansion. https://bridgepointintelligence.online/app/',
        subject: 'BridgePoint Intelligence',
      ),
    );
  }

  Future<void> _contactSupport() => launchUrl(
        Uri.parse('mailto:bridgepointintelligence@gmail.com'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        dynamic at(int i) => i < values.length ? values[i] : const <String, dynamic>{};
        final settingsPayload = _map(at(0));
        final settings = _map(settingsPayload['settings']);
        final purchasesPayload = _map(at(1));
        final purchases = _rows(purchasesPayload, const ['purchases', 'items', 'rows']);
        final team = _map(at(2));
        final display = _map(at(3));
        final user = Supabase.instance.client.auth.currentUser;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.person_outline_rounded), label: Text('Account')),
                    ButtonSegment(value: 1, icon: Icon(Icons.receipt_long_outlined), label: Text('Purchases & billing')),
                    ButtonSegment(value: 5, icon: Icon(Icons.sell_outlined), label: Text('Packages')),
                    ButtonSegment(value: 2, icon: Icon(Icons.groups_outlined), label: Text('Company & team')),
                    ButtonSegment(value: 3, icon: Icon(Icons.help_outline_rounded), label: Text('Help & share')),
                    ButtonSegment(value: 4, icon: Icon(Icons.feedback_outlined), label: Text('Feedback')),
                  ],
                  selected: {tab},
                  onSelectionChanged: (value) => setState(() => tab = value.first),
                ),
              ),
            ),
            if (loading || busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: const TextStyle(color: _cyan)),
            ],
            const SizedBox(height: 12),
            if (tab == 0)
              _AccountPanel(
                email: user?.email ?? 'Signed-in account',
                settings: settings,
                display: display,
                onRefresh: () => setState(() => request = _load()),
                onSignOut: () => Supabase.instance.client.auth.signOut(),
              )
            else if (tab == 1)
              _PurchasesPanel(
                purchases: purchases,
                onPortal: busy ? null : _openBillingPortal,
              )
            else if (tab == 2)
              _TeamPanel(payload: team)
            else if (tab == 3)
              _HelpSharePanel(
                onShare: _shareBridgePoint,
                onSupport: _contactSupport,
              )
            else if (tab == 4)
              _FeedbackPanel(
                controller: feedback,
                category: feedbackCategory,
                onCategory: (value) => setState(() => feedbackCategory = value),
                onSend: busy ? null : _sendFeedback,
              )
            else
              const BridgePointPackagesV2(),
          ],
        );
      },
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.email,
    required this.settings,
    required this.display,
    required this.onRefresh,
    required this.onSignOut,
  });

  final String email;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> display;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Account & runtime',
        subtitle: 'Session, live refresh, map defaults and account-level display state',
        icon: Icons.person_outline_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KeyValue('Signed in as', email),
            _KeyValue('Auto refresh', '${settings['auto_refresh_seconds'] ?? '—'} seconds'),
            _KeyValue('Default package', '${settings['default_package'] ?? '—'}'),
            _KeyValue('Opportunity page size', '${settings['opportunity_page_size'] ?? '—'}'),
            _KeyValue('Map result limit', '${settings['map_result_limit'] ?? '—'}'),
            _KeyValue('Map auto rotate', '${settings['map_auto_rotate'] ?? '—'}'),
            _KeyValue('Larger text', '${display['large_text'] ?? display['preferences']?['large_text'] ?? '—'}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh account state')),
                OutlinedButton.icon(onPressed: onSignOut, icon: const Icon(Icons.logout_rounded), label: const Text('Sign out')),
              ],
            ),
          ],
        ),
      );
}

class _PurchasesPanel extends StatelessWidget {
  const _PurchasesPanel({required this.purchases, required this.onPortal});
  final List<Map<String, dynamic>> purchases;
  final VoidCallback? onPortal;

  String _displayDate(BuildContext context, dynamic value) {
    final parsed = DateTime.tryParse('\${value ?? ''}');
    if (parsed == null) return 'date not reported';
    return MaterialLocalizations.of(context).formatMediumDate(parsed.toLocal());
  }

  String _scheduleLabel(BuildContext context, Map<String, dynamic> row) {
    final status = '\${row['status'] ?? ''}'.toLowerCase();
    final cancelAtEnd = row['cancel_at_period_end'] == true ||
        '\${row['cancel_at_period_end'] ?? ''}'.toLowerCase() == 'true';
    final periodEnd = row['current_period_end'];
    final trialEnd = row['trial_ends_at'];
    if (cancelAtEnd) {
      return 'Cancellation scheduled • access through \${_displayDate(context, periodEnd)}; no renewal is expected after cancellation.';
    }
    if (status.contains('trial') && trialEnd != null) {
      return 'Trial ends \${_displayDate(context, trialEnd)} • confirm the first charge in Stripe.';
    }
    if (periodEnd != null) {
      return 'Next renewal / period end: \${_displayDate(context, periodEnd)} • exact charge amount is in Stripe.';
    }
    return 'Payment schedule not returned • open the secure Stripe portal for invoices and payment status.';
  }

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Purchases & billing',
        subtitle: 'Live subscriptions, access state, delivery mode and secure Stripe management',
        icon: Icons.receipt_long_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              onPressed: onPortal,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open secure Stripe billing portal'),
            ),
            const SizedBox(height: 10),
            if (purchases.isEmpty)
              const Text('No recorded purchases for this account.', style: TextStyle(color: _BridgePointAccountSupportV2State._muted))
            else
              ...purchases.map((row) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _BridgePointAccountSupportV2State._soft.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          row['has_access'] == true ? Icons.verified_rounded : Icons.schedule_rounded,
                          color: row['has_access'] == true
                              ? _BridgePointAccountSupportV2State._green
                              : _BridgePointAccountSupportV2State._amber,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${row['package_name'] ?? row['package_key'] ?? 'Package'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(
                                '${row['status'] ?? 'unknown'} • ${row['purchase_mode'] ?? 'IMMEDIATE'} • access ${row['has_access'] == true ? 'on' : 'pending/off'}',
                                style: const TextStyle(color: _BridgePointAccountSupportV2State._muted, fontSize: 11.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _scheduleLabel(context, row),
                                style: const TextStyle(color: _BridgePointAccountSupportV2State._cyan, fontSize: 10.5, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      );
}

class _TeamPanel extends StatelessWidget {
  const _TeamPanel({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final locked = payload['locked'] == true;
    final members = payload['members'] is List
        ? (payload['members'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];
    return _Panel(
      title: 'Company & team',
      subtitle: 'Shared workspace, roles, seats and backup leadership',
      icon: Icons.groups_outlined,
      child: locked
          ? Text(
              '${payload['message'] ?? 'Team workspace is not included in this package.'}',
              style: const TextStyle(color: _BridgePointAccountSupportV2State._amber),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KeyValue('Organization', '${payload['organization_name'] ?? payload['organization'] ?? 'Company workspace'}'),
                _KeyValue('Members', '${members.length}'),
                if (members.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...members.map((row) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _BridgePointAccountSupportV2State._soft.withValues(alpha: .6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${row['email'] ?? row['user_id'] ?? 'Member'} • ${row['member_role'] ?? row['role'] ?? 'member'} • ${row['active'] == false ? 'inactive' : 'active'}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      )),
                ],
                const SizedBox(height: 6),
                const Text(
                  'Team invitations and role changes remain entitlement-controlled. Company owners/managers can manage shared workspace access where enabled.',
                  style: TextStyle(color: _BridgePointAccountSupportV2State._muted, fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
    );
  }
}

class _HelpSharePanel extends StatelessWidget {
  const _HelpSharePanel({required this.onShare, required this.onSupport});
  final VoidCallback onShare;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _Panel(
            title: 'Help & FAQ',
            subtitle: 'Plain-language setup, package and product guidance',
            icon: Icons.help_outline_rounded,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Faq('Why does a state show BUILDING?', 'BridgePoint can expose a real property foundation before scoring, signals, building geometry or other higher-level intelligence reaches full readiness.'),
                _Faq('Why is a package request-only?', 'Some technology products require owner approval, managed activation, geography setup, API/data-volume configuration or staged delivery.'),
                _Faq('Why is radar hidden when I zoom close?', 'Raw NOAA radar is regional. BridgePoint avoids stretching radar pixels into fake roof-level precision while keeping property-matched weather evidence separate.'),
                _Faq('Where do I manage billing?', 'Open Purchases & billing, then use the secure Stripe billing portal.'),
                _Faq('Where do I report bad data?', 'Use Feedback and choose data source / bug / suggestion so the report enters the BridgePoint review queue.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Panel(
            title: 'Share BridgePoint',
            subtitle: 'Use the permanent app link; you review the recipient before anything sends',
            icon: Icons.ios_share_rounded,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(onPressed: onShare, icon: const Icon(Icons.share_rounded), label: const Text('Share BridgePoint')),
                OutlinedButton.icon(onPressed: onSupport, icon: const Icon(Icons.mail_outline_rounded), label: const Text('Contact support')),
              ],
            ),
          ),
        ],
      );
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.controller,
    required this.category,
    required this.onCategory,
    required this.onSend,
  });

  final TextEditingController controller;
  final String category;
  final ValueChanged<String> onCategory;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Suggestions & feedback',
        subtitle: 'Suggestion • bug • data source request • question • compliment',
        icon: Icons.feedback_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
                DropdownMenuItem(value: 'bug', child: Text('Something is not working')),
                DropdownMenuItem(value: 'data_source_request', child: Text('Request a data source')),
                DropdownMenuItem(value: 'question', child: Text('Question')),
                DropdownMenuItem(value: 'compliment', child: Text('Compliment')),
              ],
              onChanged: (value) {
                if (value != null) onCategory(value);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'What should BridgePoint know?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: onSend, icon: const Icon(Icons.send_rounded), label: const Text('Send to BridgePoint review')),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _BridgePointAccountSupportV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: _BridgePointAccountSupportV2State._cyan),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: _BridgePointAccountSupportV2State._muted, fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label, style: const TextStyle(color: _BridgePointAccountSupportV2State._muted, fontSize: 11.5)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _Faq extends StatelessWidget {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(answer, style: const TextStyle(color: _BridgePointAccountSupportV2State._muted, fontSize: 12.5, height: 1.45)),
          ),
        ],
      );
}
