import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BridgePointPackagesV2 extends StatefulWidget {
  const BridgePointPackagesV2({super.key});

  @override
  State<BridgePointPackagesV2> createState() => _BridgePointPackagesV2State();
}

class _BridgePointPackagesV2State extends State<BridgePointPackagesV2> {
  late Future<dynamic> _request;
  bool _busy = false;
  String? _message;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _load() =>
      Supabase.instance.client.rpc('bridgepoint_flutter_packages_core_v429');

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const ['packages', 'items', 'results', 'catalog']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  String _key(Map<String, dynamic> p) => '${p['package_key'] ?? p['key'] ?? ''}';

  String _action(Map<String, dynamic> p) {
    final delivery = '${p['delivery_status'] ?? ''}'.toUpperCase();
    final mode = '${p['purchase_mode'] ?? ''}'.toUpperCase();
    final self = p['available_for_self_checkout'] == true || p['checkout_ready'] == true;
    final approval = p['owner_approval_required'] == true || mode.contains('APPROVAL') || mode.contains('MANAGED');
    if (delivery == 'BUILDING' || delivery == 'ROADMAP') return delivery;
    if (self && (delivery.isEmpty || delivery == 'READY' || delivery == 'IMMEDIATE')) return 'BUY';
    if (approval) return 'REQUEST';
    return 'UNAVAILABLE';
  }

  Future<void> _buy(Map<String, dynamic> package) async {
    final key = _key(package);
    if (key.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'bridgepoint-checkout-v67',
        body: {'package_key': key, 'interval': 'month'},
      );
      final data = _map(response.data);
      final url = '${data['url'] ?? ''}';
      if (data['complete'] != true || url.isEmpty) {
        throw StateError('${data['error'] ?? 'Checkout is not ready.'}');
      }
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open Stripe checkout.');
      }
      if (mounted) {
        setState(() => _message =
            'Stripe checkout opened for ${package['package_name'] ?? key}.');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Checkout unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestActivation(Map<String, dynamic> package) async {
    final key = _key(package);
    if (key.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_request_owner_approved_package_v323',
        params: {
          'p_package_key': key,
          'p_note': 'Requested from Clean V2 package workspace.',
        },
      );
      final result = _map(raw);
      if (mounted) {
        setState(() => _message =
            '${result['message'] ?? 'Activation request submitted.'}');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not request activation: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(Map<String, dynamic> p) {
    final action = _action(p);
    final name = '${p['package_name'] ?? p['name'] ?? _key(p)}';
    final disclosure = '${p['customer_delivery_disclosure'] ?? p['delivery_disclosure'] ?? p['description'] ?? ''}';
    final monthly = p['monthly_price'] ?? p['price_monthly'];
    final annual = p['annual_price'] ?? p['price_annual'];
    final color = action == 'BUY' ? _green : action == 'REQUEST' ? _cyan : _amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                Chip(
                  label: Text('${p['delivery_status'] ?? p['purchase_mode'] ?? action}'),
                  side: BorderSide(color: color.withValues(alpha: .35)),
                ),
              ],
            ),
            if (monthly != null || annual != null) ...[
              const SizedBox(height: 7),
              Text(
                [
                  if (monthly != null) '\$$monthly / month',
                  if (annual != null) '\$$annual / year',
                ].join(' • '),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
            if (p['trial_days'] != null || p['founding_discount'] != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (p['trial_days'] != null) '${p['trial_days']}-day trial',
                  if (p['founding_discount'] != null) '${p['founding_discount']}',
                ].join(' • '),
                style: const TextStyle(color: _cyan, fontSize: 10),
              ),
            ],
            if (disclosure.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(disclosure,
                  style: const TextStyle(
                      color: _muted, fontSize: 10, height: 1.45)),
            ],
            const SizedBox(height: 12),
            if (action == 'BUY')
              FilledButton.icon(
                onPressed: _busy ? null : () => _buy(p),
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Buy now'),
              )
            else if (action == 'REQUEST')
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _requestActivation(p),
                icon: const Icon(Icons.outgoing_mail),
                label: Text('${p['request_cta'] ?? 'Request activation'}'),
              )
            else
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.construction_rounded),
                label: Text(action == 'BUILDING'
                    ? 'Building — not purchasable yet'
                    : action == 'ROADMAP'
                        ? 'Roadmap / interest only'
                        : 'Not available for self-service'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _request,
      builder: (context, snapshot) {
        final packages = _rows(snapshot.data);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy || snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: const TextStyle(color: _cyan)),
            ],
            const SizedBox(height: 10),
            if (snapshot.hasError)
              Text('Package catalog unavailable: ${snapshot.error}')
            else if (packages.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No packages returned for this account.',
                      style: TextStyle(color: _muted)),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth >= 1200
                      ? 3
                      : c.maxWidth >= 760
                          ? 2
                          : 1;
                  final width = (c.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: packages
                        .map((p) => SizedBox(width: width, child: _card(p)))
                        .toList(),
                  );
                },
              ),
            const SizedBox(height: 10),
            const Text(
              'Commercial truth rule: BUILDING/ROADMAP packages are never presented as immediately purchasable. Checkout uses the live Stripe contract, trial eligibility, delivery disclosures and account entitlements.',
              style: TextStyle(color: _amber, fontSize: 10, height: 1.45),
            ),
          ],
        );
      },
    );
  }
}
