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

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);

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

  Map<String, dynamic> _configuration(Map<String, dynamic> package) =>
      _map(package['configuration']);

  dynamic _field(Map<String, dynamic> package, String key) {
    if (package[key] != null) return package[key];
    return _configuration(package)[key];
  }

  bool _boolField(Map<String, dynamic> package, String key) {
    final value = _field(package, key);
    if (value is bool) return value;
    return '${value ?? ''}'.toLowerCase() == 'true';
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in const ['packages', 'items', 'results', 'catalog']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

  String _key(Map<String, dynamic> p) => '${p['package_key'] ?? p['key'] ?? ''}';

  String _action(Map<String, dynamic> p) {
    final delivery = '${_field(p, 'delivery_status') ?? ''}'.toUpperCase();
    final mode = '${_field(p, 'purchase_mode') ?? ''}'.toUpperCase();
    final self = _boolField(p, 'available_for_self_checkout') ||
        _boolField(p, 'checkout_ready') && mode == 'IMMEDIATE';
    final approval = _boolField(p, 'owner_approval_required') ||
        mode.contains('APPROVAL') ||
        mode.contains('MANAGED');

    if (delivery == 'BUILDING') return 'BUILDING';
    if (delivery == 'ROADMAP') return 'ROADMAP';
    if (approval) return 'REQUEST';
    if (self &&
        (delivery.isEmpty ||
            delivery == 'READY' ||
            delivery == 'IMMEDIATE' ||
            delivery == 'LIMITED')) {
      return 'BUY';
    }
    if (mode == 'IMMEDIATE' && delivery == 'READY') return 'BUY';
    return 'UNAVAILABLE';
  }

  Color _actionColor(String action) => switch (action) {
        'BUY' => _green,
        'REQUEST' => _cyan,
        'BUILDING' => _amber,
        'ROADMAP' => _blue,
        _ => _red,
      };

  String _money(dynamic value) {
    if (value == null) return '';
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '$value';
    return number == number.roundToDouble()
        ? '\$${number.round()}'
        : '\$${number.toStringAsFixed(2)}';
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
    final config = _configuration(p);
    final action = _action(p);
    final color = _actionColor(action);
    final name = '${p['package_name'] ?? p['name'] ?? _key(p)}';
    final description = '${p['description'] ?? ''}'.trim();
    final disclosure = '${_field(p, 'customer_delivery_disclosure') ??
            _field(p, 'delivery_summary') ??
            _field(p, 'delivery_note') ??
            ''}'
        .trim();
    final monthly = p['monthly_price'] ?? p['price_monthly'];
    final yearly = p['yearly_price'] ?? p['annual_price'] ?? p['price_annual'];
    final trialDays = p['trial_days'];
    final pricingLabel = '${_field(p, 'pricing_label') ?? ''}'.trim();
    final pricingNote = '${_field(p, 'pricing_note') ?? ''}'.trim();
    final bestFor = '${config['best_for'] ?? ''}'.trim();
    final includes = _stringList(config['includes']);
    final modelCount = p['included_model_count'];
    final featured = p['featured'] == true;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _panel,
            color.withValues(alpha: featured ? .10 : .045),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: featured ? .30 : .14),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _key(p).startsWith('technology_')
                        ? Icons.memory_rounded
                        : Icons.workspace_premium_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pricingLabel.isEmpty ? 'BridgePoint package' : pricingLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ),
                ),
                if (featured)
                  const Icon(Icons.star_rounded, color: _amber, size: 19),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (monthly != null)
                  Text(
                    _money(monthly),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (monthly != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 3),
                    child: Text('/mo', style: TextStyle(color: _muted, fontSize: 10)),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: .22)),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (yearly != null) ...[
              const SizedBox(height: 2),
              Text('${_money(yearly)} / year', style: const TextStyle(color: _muted, fontSize: 10)),
            ],
            if (trialDays != null && '$trialDays' != '0') ...[
              const SizedBox(height: 7),
              Text(
                '$trialDays-day free trial',
                style: const TextStyle(
                  color: _cyan,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (modelCount != null) ...[
              const SizedBox(height: 5),
              Text(
                '$modelCount intelligence model${'$modelCount' == '1' ? '' : 's'} included',
                style: const TextStyle(color: _green, fontSize: 10),
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
              ),
            ],
            if (bestFor.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text('BEST FOR', style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
              const SizedBox(height: 3),
              Text(bestFor, style: const TextStyle(fontSize: 12.5, height: 1.4)),
            ],
            if (includes.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: includes.take(5).map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item, style: const TextStyle(fontSize: 11)),
                    )).toList(),
              ),
            ],
            if (disclosure.isNotEmpty || pricingNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                [if (disclosure.isNotEmpty) disclosure, if (pricingNote.isNotEmpty) pricingNote].join(' '),
                style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            if (action == 'BUY')
              FilledButton.icon(
                onPressed: _busy ? null : () => _buy(p),
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Start trial / Buy'),
              )
            else if (action == 'REQUEST')
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _requestActivation(p),
                icon: const Icon(Icons.outgoing_mail),
                label: Text('${_field(p, 'request_cta') ?? 'Request activation'}'),
              )
            else if (action == 'BUILDING')
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.construction_rounded),
                label: const Text('Building — early access not open yet'),
              )
            else if (action == 'ROADMAP')
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.route_rounded),
                label: const Text('Roadmap / interest only'),
              )
            else
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Not available for this purchase path'),
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
        final payload = _map(snapshot.data);
        final packages = _rows(payload);
        final ready = packages.where((p) => _action(p) == 'BUY').length;
        final request = packages.where((p) => _action(p) == 'REQUEST').length;
        final building = packages.where((p) => _action(p) == 'BUILDING').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_panel, _cyan.withValues(alpha: .10)]),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _cyan.withValues(alpha: .14)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: _cyan, size: 28),
                  const Text('BridgePoint Packages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Chip(label: Text('$ready ready to buy')),
                  Chip(label: Text('$request request / approval')),
                  if (building > 0) Chip(label: Text('$building building')),
                  if (payload['catalog_scope'] != null)
                    Chip(label: Text('${payload['catalog_scope']}')),
                ],
              ),
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
            if (snapshot.hasError)
              Text('Package catalog unavailable: ${snapshot.error}')
            else if (packages.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No packages returned for this account.',
                    style: TextStyle(color: _muted),
                  ),
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
              'Commercial truth rule: READY + IMMEDIATE packages use the live Stripe checkout contract. Owner-approval and managed products remain request-based. BUILDING and ROADMAP products are visible without being falsely sold as finished.',
              style: TextStyle(color: _amber, fontSize: 12.5, height: 1.45),
            ),
          ],
        );
      },
    );
  }
}
