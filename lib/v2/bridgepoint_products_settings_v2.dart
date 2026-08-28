import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings/bridgepoint_package_fit_v2.dart';

class BridgePointProductsSettingsV2 extends StatefulWidget {
  const BridgePointProductsSettingsV2({super.key});

  @override
  State<BridgePointProductsSettingsV2> createState() =>
      _BridgePointProductsSettingsV2State();
}

class _BridgePointProductsSettingsV2State
    extends State<BridgePointProductsSettingsV2> {
  static const _gold = Color(0xFFFFC95E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _red = Color(0xFFFF7474);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xEE0A192A);

  late Future<Map<String, dynamic>> _request;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    dynamic planPayload;
    Map<String, dynamic> access = const {};
    Object? plansError;
    Object? accessError;

    try {
      planPayload = await Supabase.instance.client
          .rpc('bridgepoint_customer_plans_v944');
    } catch (error) {
      plansError = error;
    }

    try {
      access = _map(await Supabase.instance.client
          .rpc('bridgepoint_customer_access_contract_v318'));
    } catch (error) {
      accessError = error;
    }

    return <String, dynamic>{
      'plans': planPayload,
      'access': access,
      'plans_verified': plansError == null,
      'access_verified': accessError == null,
    };
  }

  void _refresh() => setState(() => _request = _load());

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map && value['packages'] is List) return _rows(value['packages']);
    return const [];
  }

  List<String> _strings(dynamic value) => value is List
      ? value.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
      : const [];

  Set<String> _activePackageKeys(Map<String, dynamic> access) {
    final result = <String>{};
    final packages = access['packages'];
    if (packages is List) {
      for (final item in packages) {
        if (item is Map) {
          final key = '${item['package_key'] ?? ''}'.trim();
          if (key.isNotEmpty) result.add(key);
        } else {
          final key = '$item'.trim();
          if (key.isNotEmpty) result.add(key);
        }
      }
    }
    return result;
  }

  Set<String> _features(Map<String, dynamic> access) =>
      _strings(access['features']).toSet();

  String _money(dynamic value) {
    final number =
        value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (number == null) return '';
    return number == number.roundToDouble()
        ? '\$${number.round()}'
        : '\$${number.toStringAsFixed(2)}';
  }

  String _plain(String value) {
    final words = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.length <= 2
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}');
    return words.join(' ');
  }

  String _featureLabel(String key) => switch (key) {
        'opportunity_rankings' => 'Ranked opportunities',
        'map' => 'Intelligence map',
        'property_profiles' => 'Property profiles',
        'favorites' => 'Saved properties',
        'calendar' => 'Calendar & follow-up',
        'weather_intelligence' => 'Weather intelligence & radar',
        'signals' => 'Signals & evidence',
        'community_chat' => 'Community',
        'pattern_intelligence_feed' => 'Pattern intelligence',
        'model_marketplace' => 'Model marketplace',
        _ => _plain(key),
      };

  String _packageName(
    String key,
    List<Map<String, dynamic>> plans,
    Map<String, dynamic> access,
  ) {
    for (final plan in plans) {
      if ('${plan['package_key'] ?? ''}' == key) {
        final name = '${plan['package_name'] ?? ''}'.trim();
        if (name.isNotEmpty) return name;
      }
    }
    final packages = access['packages'];
    if (packages is List) {
      for (final item in packages.whereType<Map>()) {
        if ('${item['package_key'] ?? ''}' == key) {
          final name = '${item['package_name'] ?? item['name'] ?? ''}'.trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    return _plain(key);
  }

  Future<void> _checkout(Map<String, dynamic> plan, String interval) async {
    final key = '${plan['package_key'] ?? ''}'.trim();
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
      if (data['complete'] != true || url.isEmpty) {
        throw StateError('Checkout unavailable');
      }
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open checkout');
      }
      if (mounted) {
        setState(() => _message =
            'Secure checkout opened for ${plan['package_name'] ?? 'BridgePoint'}.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Checkout could not open right now. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fit() => Navigator.of(context).push(
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

  Widget _accessCard(
    bool verified,
    Map<String, dynamic> access,
    List<Map<String, dynamic>> plans,
  ) {
    if (!verified) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _red.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _red.withValues(alpha: .34)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: _red),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BridgePoint could not verify your access',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'We will not guess that you are unentitled. Refresh to re-check the server before changing packages or relying on locked/unlocked labels.',
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: _refresh, child: const Text('Refresh')),
          ],
        ),
      );
    }

    final packages = _activePackageKeys(access);
    final features = _features(access).toList()..sort();
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_panel, _green.withValues(alpha: .075)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withValues(alpha: .34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user_outlined, color: _green),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR BRIDGEPOINT ACCESS',
                      style: TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .9,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'What you have unlocked right now',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh access',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (packages.isEmpty)
            const Text(
              'No active package name was returned by the access contract. If you just paid or started a trial, refresh after entitlement confirmation completes.',
              style: TextStyle(color: _muted, height: 1.4),
            )
          else ...[
            const Text(
              'Current package',
              style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in packages)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _green.withValues(alpha: .4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: _green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _packageName(key, plans, access),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Included with your access',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final feature in features.take(18))
                  Chip(
                    avatar: const Icon(Icons.lock_open_rounded, size: 15, color: _cyan),
                    label: Text(_featureLabel(feature)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'This server access contract is the authority for customer tools. A package card below is an offer; the section above is what this signed-in account is actually entitled to use.',
            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _request,
        builder: (context, snapshot) {
          final payload = snapshot.data ?? const <String, dynamic>{};
          final plansVerified = payload['plans_verified'] == true;
          final accessVerified = payload['access_verified'] == true;
          final plans = _rows(payload['plans']);
          final access = _map(payload['access']);
          final activeKeys = _activePackageKeys(access);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _accessCard(accessVerified, access, plans),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D2208), Color(0xFF171B28), Color(0xFF0A192A)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _gold.withValues(alpha: .42)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '7-DAY FREE TRIAL',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Packages & Access',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.08),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'See what your account has now, then compare only customer-ready BridgePoint packages. Internal engines and backend components stay out of the buying experience.',
                      style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: const Color(0xFF241700),
                      ),
                      onPressed: _fit,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Help me choose'),
                    ),
                  ],
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(
                  _message!,
                  style: const TextStyle(color: _cyan, fontWeight: FontWeight.w800),
                ),
              ],
              const SizedBox(height: 14),
              if (!plansVerified &&
                  snapshot.connectionState != ConnectionState.waiting)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'BridgePoint package offers are temporarily unavailable. Your current access status above is handled separately.',
                          ),
                        ),
                        TextButton(onPressed: _refresh, child: const Text('Refresh')),
                      ],
                    ),
                  ),
                )
              else if (plans.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No customer-ready plans were returned.'),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1050
                        ? 3
                        : (constraints.maxWidth >= 650 ? 2 : 1);
                    final width =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final plan in plans)
                          SizedBox(
                            width: width,
                            child: _planCard(
                              plan,
                              current: accessVerified &&
                                  activeKeys.contains('${plan['package_key'] ?? ''}'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      );

  Widget _planCard(Map<String, dynamic> plan, {required bool current}) {
    final key = '${plan['package_key'] ?? ''}';
    final color = _accent(key);
    final includes = _strings(plan['includes']);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_panel, color.withValues(alpha: .07)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: current ? _green : color.withValues(alpha: .25),
          width: current ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_icon(key), color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  '${plan['package_name'] ?? key}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _green.withValues(alpha: .4)),
                  ),
                  child: const Text(
                    'CURRENT',
                    style: TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_money(plan['monthly_price'])}/mo',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          if (plan['trial_days'] != null)
            Text(
              '${plan['trial_days']}-day free trial',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          if ('${plan['description'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${plan['description']}',
              style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.42),
            ),
          ],
          if (includes.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in includes.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: _muted, fontSize: 11.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          if (current)
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Included in your current access'),
            )
          else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: key == 'investor' || key == 'all_intelligence'
                    ? const Color(0xFF241700)
                    : const Color(0xFF021018),
              ),
              onPressed: _busy ? null : () => _checkout(plan, 'month'),
              icon: const Icon(Icons.credit_card_rounded),
              label: const Text('Start monthly'),
            ),
            if (plan['yearly_price'] != null) ...[
              const SizedBox(height: 7),
              OutlinedButton(
                onPressed: _busy ? null : () => _checkout(plan, 'year'),
                child: Text('Annual • ${_money(plan['yearly_price'])}'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
