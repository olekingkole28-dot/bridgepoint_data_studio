import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BridgePointPlansV942 extends StatefulWidget {
  const BridgePointPlansV942({super.key});

  @override
  State<BridgePointPlansV942> createState() => _BridgePointPlansV942State();
}

class _BridgePointPlansV942State extends State<BridgePointPlansV942> {
  static const _gold = Color(0xFFFFC95E);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _panel = Color(0xFF0D1B2C);
  static const _soft = Color(0xFF14283F);
  static const _muted = Color(0xFFB5C6D9);

  late Future<dynamic> _request;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _request = Supabase.instance.client.rpc('bridgepoint_flutter_packages_core_v429');
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

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _key(Map<String, dynamic> p) => '${p['package_key'] ?? p['key'] ?? ''}'.trim();

  dynamic _field(Map<String, dynamic> p, String key) {
    if (p[key] != null) return p[key];
    final config = _map(p['configuration']);
    return config[key];
  }

  bool _bool(Map<String, dynamic> p, String key) {
    final v = _field(p, key);
    return v == true || '$v'.toLowerCase() == 'true';
  }

  bool _buyable(Map<String, dynamic> p) {
    final delivery = '${_field(p, 'delivery_status') ?? ''}'.toUpperCase();
    final mode = '${_field(p, 'purchase_mode') ?? ''}'.toUpperCase();
    final self = _bool(p, 'available_for_self_checkout') || _bool(p, 'checkout_ready');
    return !delivery.contains('BUILD') && !delivery.contains('ROADMAP') &&
        ((self && !mode.contains('APPROVAL') && !mode.contains('MANAGED')) ||
            (mode == 'IMMEDIATE' && delivery == 'READY'));
  }

  String _money(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '—';
    return '\$${n == n.roundToDouble() ? n.round() : n.toStringAsFixed(2)}';
  }

  Future<void> _buy(Map<String, dynamic> package, String interval) async {
    final key = _key(package);
    if (key.isEmpty || _busy) return;
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
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Could not open checkout');
      if (mounted) setState(() => _message = 'Secure Stripe checkout opened.');
    } catch (_) {
      if (mounted) setState(() => _message = 'Checkout could not open right now. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _plan(Map<String, dynamic> p) {
    final name = '${p['package_name'] ?? p['name'] ?? _key(p)}';
    final description = '${p['description'] ?? ''}'.trim();
    final monthly = p['monthly_price'] ?? p['price_monthly'];
    final yearly = p['yearly_price'] ?? p['annual_price'] ?? p['price_annual'];
    final trial = int.tryParse('${p['trial_days'] ?? 0}') ?? 0;
    final buyable = _buyable(p);
    final building = '${_field(p, 'delivery_status') ?? ''}'.toUpperCase().contains('BUILD');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panel, buyable ? const Color(0xFF2B2514) : _soft],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: buyable ? _gold.withValues(alpha: .55) : Colors.white.withValues(alpha: .10)),
        boxShadow: buyable
            ? [BoxShadow(color: _gold.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 12))]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (buyable ? _gold : _cyan).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.workspace_premium_rounded, color: buyable ? _gold : _cyan),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            if (buyable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: _gold.withValues(alpha: .13), borderRadius: BorderRadius.circular(999)),
                child: const Text('READY', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900)),
              )
            else if (building)
              const Text('BUILDING', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 14),
          if (monthly != null)
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_money(monthly), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const Padding(padding: EdgeInsets.only(bottom: 5, left: 3), child: Text('/mo', style: TextStyle(color: _muted))),
            ]),
          if (yearly != null) Text('${_money(yearly)} / year', style: const TextStyle(color: _muted, fontSize: 12)),
          if (trial > 0) ...[
            const SizedBox(height: 7),
            Text('$trial-day free trial', style: const TextStyle(color: _gold, fontWeight: FontWeight.w900)),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(description, style: const TextStyle(color: _muted, height: 1.45)),
          ],
          const Spacer(),
          const SizedBox(height: 14),
          if (buyable)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF1A1200),
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _busy ? null : () => _buy(p, 'month'),
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(trial > 0 ? 'Start free trial' : 'Choose plan'),
            )
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(building ? 'In development' : 'Contact BridgePoint for access'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _request,
      builder: (context, snapshot) {
        final all = _rows(snapshot.data);
        final customer = all
            .where((p) => !_key(p).startsWith('technology_'))
            .where((p) => !{'custom_model', 'pattern_intelligence'}.contains(_key(p)))
            .toList()
          ..sort((a, b) {
            final ab = _buyable(a) ? 0 : 1;
            final bb = _buyable(b) ? 0 : 1;
            if (ab != bb) return ab.compareTo(bb);
            final ap = (a['monthly_price'] as num?)?.toDouble() ?? 999999;
            final bp = (b['monthly_price'] as num?)?.toDouble() ?? 999999;
            return ap.compareTo(bp);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF16130A), Color(0xFF302611), Color(0xFF071321)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _gold.withValues(alpha: .42)),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.workspace_premium_rounded, color: _gold),
                  SizedBox(width: 9),
                  Text('BRIDGEPOINT PLANS', style: TextStyle(color: _gold, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                ]),
                SizedBox(height: 12),
                Text('Choose the intelligence that fits your work.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                SizedBox(height: 7),
                Text('Start with a 7-day trial on eligible plans. Upgrade without digging through settings or backend menus.', style: TextStyle(color: _muted, height: 1.45)),
              ]),
            ),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(color: _gold)),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message!, style: const TextStyle(color: _green))),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
              const Center(child: CircularProgressIndicator(color: _gold))
            else if (snapshot.hasError)
              const Text('Plans could not load right now. Please refresh and try again.', style: TextStyle(color: _muted))
            else
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 650 ? 2 : 1;
                final width = (c.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final p in customer) SizedBox(width: width, height: 390, child: _plan(p))],
                );
              }),
          ],
        );
      },
    );
  }
}
