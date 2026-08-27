import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../v2/settings/bridgepoint_package_fit_v2.dart';

class BridgePointProductsSettingsV2 extends StatefulWidget {
  const BridgePointProductsSettingsV2({super.key});

  @override
  State<BridgePointProductsSettingsV2> createState() => _BridgePointProductsSettingsV2State();
}

class _BridgePointProductsSettingsV2State extends State<BridgePointProductsSettingsV2> {
  static const _gold = Color(0xFFFFC95E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xEE0A192A);

  late Future<dynamic> _request;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _request = Supabase.instance.client.rpc('bridgepoint_customer_plans_v944');
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map && value['packages'] is List) return _rows(value['packages']);
    return const [];
  }

  List<String> _strings(dynamic value) {
    if (value is List) return value.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  String _money(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '';
    return n == n.roundToDouble() ? '\$${n.round()}' : '\$${n.toStringAsFixed(2)}';
  }

  Future<void> _checkout(Map<String, dynamic> package, String interval) async {
    final key = '${package['package_key'] ?? ''}'.trim();
    if (key.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'bridgepoint-checkout-v67',
        body: {'package_key': key, 'interval': interval},
      );
      final data = _map(response.data);
      final url = '${data['url'] ?? ''}'.trim();
      if (data['complete'] != true || url.isEmpty) throw StateError('Checkout unavailable');
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) throw StateError('Could not open checkout');
      if (mounted) setState(() => _message = 'Secure checkout opened for ${package['package_name'] ?? 'BridgePoint'}.');
    } catch (_) {
      if (mounted) setState(() => _message = 'Checkout could not open right now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Find my BridgePoint plan')),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: BridgePointPackageFitV2(),
          ),
        ),
      ),
    );
  }

  Color _accent(String key) => switch (key) {
        'homeowner' => _cyan,
        'home' => _blue,
        'investor' => _gold,
        'commercial' => _green,
        'company' => const Color(0xFFB88CFF),
        _ => const Color(0xFFFFD86B),
      };

  IconData _icon(String key) => switch (key) {
        'homeowner' => Icons.home_outlined,
        'home' => Icons.roofing_outlined,
        'investor' => Icons.real_estate_agent_outlined,
        'commercial' => Icons.domain_outlined,
        'company' => Icons.groups_outlined,
        _ => Icons.workspace_premium_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _request,
      builder: (context, snapshot) {
        final payload = _map(snapshot.data);
        final plans = _rows(payload);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2D2208), Color(0xFF171B28), Color(0xFF0A192A)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _gold.withValues(alpha: .42)),
                boxShadow: const [BoxShadow(color: Color(0x33FFC95E), blurRadius: 30, offset: Offset(0, 14))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _gold.withValues(alpha: .13), borderRadius: BorderRadius.circular(999), border: Border.all(color: _gold.withValues(alpha: .28))),
                  child: const Text('7-DAY FREE TRIAL', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8)),
                ),
                const SizedBox(height: 14),
                const Text('Choose the BridgePoint access that fits your work.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.08)),
                const SizedBox(height: 7),
                const ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 760),
                  child: Text(
                    'The plan chooser is intentionally limited to customer-ready BridgePoint packages. Internal engines, roadmap technology and backend components are not mixed into this screen.',
                    style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF241700)),
                  onPressed: _fit,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Help me choose'),
                ),
              ]),
            ),
            if (snapshot.connectionState == ConnectionState.waiting) ...[const SizedBox(height: 10), const LinearProgressIndicator()],
            if (_message != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _cyan.withValues(alpha: .08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _cyan.withValues(alpha: .15))),
                child: Text(_message!, style: const TextStyle(color: _cyan, fontWeight: FontWeight.w800)),
              ),
            ],
            const SizedBox(height: 14),
            if (snapshot.hasError)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('BridgePoint plans are temporarily unavailable. Please refresh and try again.')))
            else if (plans.isEmpty && snapshot.connectionState != ConnectionState.waiting)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No customer-ready plans were returned.')))
            else
              LayoutBuilder(builder: (context, c) {
                final columns = c.maxWidth >= 1050 ? 3 : c.maxWidth >= 650 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final plan in plans) SizedBox(width: width, child: _planCard(plan))],
                );
              }),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .08))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lock_outline_rounded, color: _green, size: 18),
                SizedBox(width: 9),
                Expanded(child: Text('Checkout opens through BridgePoint’s secure Stripe flow. Package availability and geography access still follow the live entitlement rules for your account.', style: TextStyle(color: _muted, fontSize: 12.2, height: 1.45))),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final key = '${plan['package_key'] ?? ''}';
    final color = _accent(key);
    final includes = _strings(plan['includes']);
    final monthly = plan['monthly_price'];
    final yearly = plan['yearly_price'];
    final featured = plan['featured'] == true;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_panel, color.withValues(alpha: featured ? .10 : .045)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: featured ? .30 : .15)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: featured ? .07 : .03), blurRadius: 22)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(_icon(key), color: color)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${plan['package_name'] ?? key}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            if (featured) ...[
              const SizedBox(height: 3),
              Text('FEATURED', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
            ],
          ])),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_money(monthly), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const Padding(padding: EdgeInsets.only(bottom: 4, left: 3), child: Text('/mo', style: TextStyle(color: _muted, fontSize: 11))),
        ]),
        if (plan['trial_days'] != null) ...[const SizedBox(height: 4), Text('${plan['trial_days']}-day free trial', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))],
        if ('${plan['description'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${plan['description']}', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.42)),
        ],
        if ('${plan['best_for'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('BEST FOR', style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .6)),
          const SizedBox(height: 3),
          Text('${plan['best_for']}', style: const TextStyle(fontSize: 12.2, height: 1.4)),
        ],
        if (includes.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final item in includes.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_rounded, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(item, style: const TextStyle(color: _muted, fontSize: 11.7, height: 1.35))),
              ]),
            ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: key == 'investor' || key == 'all_intelligence' ? const Color(0xFF241700) : const Color(0xFF021018)),
          onPressed: _busy ? null : () => _checkout(plan, 'month'),
          icon: const Icon(Icons.credit_card_rounded),
          label: const Text('Start monthly'),
        ),
        if (yearly != null) ...[
          const SizedBox(height: 7),
          OutlinedButton(onPressed: _busy ? null : () => _checkout(plan, 'year'), child: Text('Annual • ${_money(yearly)}')),
        ],
      ]),
    );
  }
}
