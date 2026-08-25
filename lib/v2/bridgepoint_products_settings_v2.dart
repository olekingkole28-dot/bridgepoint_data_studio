import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BridgePointProductsSettingsV2 extends StatefulWidget {
  const BridgePointProductsSettingsV2({super.key});

  @override
  State<BridgePointProductsSettingsV2> createState() =>
      _BridgePointProductsSettingsV2State();
}

class _BridgePointProductsSettingsV2State
    extends State<BridgePointProductsSettingsV2> {
  late Future<List<dynamic>> _request;
  bool _busy = false;
  String? _message;
  bool _largeText = false;
  bool _highContrast = false;
  bool _reducedMotion = false;
  bool _simplified = false;
  String _mapStyle = 'satellite';

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (e) {
      return {'available': false, 'rpc': name, 'error': '$e'};
    }
  }

  Future<List<dynamic>> _load() async {
    final values = await Future.wait([
      _safe('bridgepoint_flutter_packages_core_v429'),
      _safe('bridgepoint_flutter_settings_v59'),
      _safe('bridgepoint_display_preferences_v80'),
      _safe('bridgepoint_onboarding_state_v70'),
    ]);
    final prefs = _map(values[2]);
    _largeText = prefs['large_text'] == true;
    _highContrast = prefs['high_contrast'] == true;
    _reducedMotion = prefs['reduced_motion'] == true;
    _simplified = prefs['simplified_views'] == true;
    _mapStyle = '${prefs['map_base_style'] ?? 'satellite'}';
    return values;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
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

  String _packageKey(Map<String, dynamic> p) => '${p['package_key'] ?? p['key'] ?? ''}';

  String _action(Map<String, dynamic> p) {
    final delivery = '${p['delivery_status'] ?? ''}'.toUpperCase();
    final mode = '${p['purchase_mode'] ?? ''}'.toUpperCase();
    final self = p['available_for_self_checkout'] == true || p['checkout_ready'] == true;
    final approval = p['owner_approval_required'] == true || mode.contains('APPROVAL');
    if (delivery == 'BUILDING' || delivery == 'ROADMAP') return delivery;
    if (self && (delivery.isEmpty || delivery == 'READY' || delivery == 'IMMEDIATE')) return 'BUY';
    if (approval) return 'REQUEST';
    return 'UNAVAILABLE';
  }

  Future<void> _buy(Map<String, dynamic> package) async {
    final key = _packageKey(package);
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
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open Stripe checkout.');
      }
      if (mounted) setState(() => _message = 'Stripe checkout opened for ${package['package_name'] ?? key}.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Checkout unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestActivation(Map<String, dynamic> package) async {
    final key = _packageKey(package);
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
          'p_note': 'Requested from clean V2 package workspace.',
        },
      );
      final result = _map(raw);
      if (mounted) setState(() => _message = '${result['message'] ?? 'Activation request submitted.'}');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not request activation: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_update_display_preferences_v98',
        params: {
          'p_large_text': _largeText,
          'p_high_contrast': _highContrast,
          'p_reduced_motion': _reducedMotion,
          'p_simplified_views': _simplified,
          'p_map_base_style': _mapStyle,
        },
      );
      if (mounted) setState(() => _message = 'Display preferences saved.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save preferences: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _packageCard(Map<String, dynamic> p) {
    final action = _action(p);
    final name = '${p['package_name'] ?? p['name'] ?? _packageKey(p)}';
    final disclosure = '${p['customer_delivery_disclosure'] ?? p['delivery_disclosure'] ?? p['description'] ?? ''}';
    final monthly = p['monthly_price'] ?? p['price_monthly'];
    final color = action == 'BUY' ? _green : action == 'REQUEST' ? _cyan : _amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            Chip(
              label: Text('${p['delivery_status'] ?? p['purchase_mode'] ?? action}'),
              side: BorderSide(color: color.withValues(alpha: .35)),
            ),
          ]),
          if (monthly != null) ...[
            const SizedBox(height: 6),
            Text('\$$monthly / month', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
          if (disclosure.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(disclosure, style: const TextStyle(color: _muted, fontSize: 10, height: 1.45)),
          ],
          const SizedBox(height: 12),
          if (action == 'BUY')
            FilledButton.icon(onPressed: _busy ? null : () => _buy(p), icon: const Icon(Icons.credit_card_rounded), label: const Text('Buy now'))
          else if (action == 'REQUEST')
            FilledButton.tonalIcon(onPressed: _busy ? null : () => _requestActivation(p), icon: const Icon(Icons.outgoing_mail), label: Text('${p['request_cta'] ?? 'Request activation'}'))
          else
            OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.construction_rounded), label: Text(action == 'BUILDING' ? 'Building — not purchasable yet' : action == 'ROADMAP' ? 'Roadmap / interest only' : 'Not available for self-service')),
        ]),
      ),
    );
  }

  Widget _compactData(String title, dynamic value) {
    final map = _map(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: map.entries.take(30).map((e) => Chip(label: Text('${e.key.replaceAll('_', ' ')}: ${e.value}'))).toList()),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const [];
        dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
        final packages = _rows(at(0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Products & Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text(
              'Commercial access, trials, managed activation, package delivery truth, account settings, accessibility and map preferences.',
              style: TextStyle(color: _muted, height: 1.45),
            ),
            if (_busy) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
            if (_message != null) ...[const SizedBox(height: 8), Text(_message!, style: const TextStyle(color: _cyan))],
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else ...[
              LayoutBuilder(builder: (context, c) {
                final columns = c.maxWidth >= 1200 ? 3 : c.maxWidth >= 760 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(spacing: 12, runSpacing: 12, children: packages.map((p) => SizedBox(width: width, child: _packageCard(p))).toList());
              }),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Accessibility & display', style: TextStyle(fontWeight: FontWeight.w900)),
                    SwitchListTile(value: _largeText, onChanged: (v) => setState(() => _largeText = v), title: const Text('Larger text')),
                    SwitchListTile(value: _highContrast, onChanged: (v) => setState(() => _highContrast = v), title: const Text('Higher contrast')),
                    SwitchListTile(value: _reducedMotion, onChanged: (v) => setState(() => _reducedMotion = v), title: const Text('Reduced motion')),
                    SwitchListTile(value: _simplified, onChanged: (v) => setState(() => _simplified = v), title: const Text('Simplified views')),
                    DropdownButtonFormField<String>(
                      initialValue: const ['satellite', 'street', 'standard'].contains(_mapStyle) ? _mapStyle : 'satellite',
                      items: const [
                        DropdownMenuItem(value: 'satellite', child: Text('Satellite / aerial-first')),
                        DropdownMenuItem(value: 'street', child: Text('Street map')),
                        DropdownMenuItem(value: 'standard', child: Text('Standard')),
                      ],
                      onChanged: (v) => setState(() => _mapStyle = v ?? 'satellite'),
                      decoration: const InputDecoration(labelText: 'Default map style'),
                    ),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _busy ? null : _savePreferences, icon: const Icon(Icons.save_rounded), label: const Text('Save preferences'))),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              _compactData('Account / package settings', at(1)),
              const SizedBox(height: 8),
              _compactData('Onboarding / recommended package state', at(3)),
            ],
          ],
        );
      },
    );
  }
}
