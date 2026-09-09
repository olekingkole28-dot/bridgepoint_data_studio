import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bridgepoint_chrome_v2.dart';

class BridgePointPublicLandingV2 extends StatefulWidget {
  const BridgePointPublicLandingV2({super.key, required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  State<BridgePointPublicLandingV2> createState() =>
      _BridgePointPublicLandingV2State();
}

class _BridgePointPublicLandingV2State
    extends State<BridgePointPublicLandingV2> {
  static const _navy = Color(0xFF06101F);
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  late Future<List<dynamic>> _request;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String rpc) async {
    try {
      return await Supabase.instance.client.rpc(rpc);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_public_system_status_v320'),
        _safe('bridgepoint_public_expansion_status_v321'),
        _safe('bridgepoint_public_capability_directory_v735'),
      ]);

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 680;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.3,
            colors: [Color(0x2235D2E8), _navy],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _request,
            builder: (context, snapshot) {
              final values = snapshot.data ?? const [];
              dynamic at(int i) =>
                  i < values.length ? values[i] : const <String, dynamic>{};
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      phone ? 14 : 24,
                      14,
                      phone ? 14 : 24,
                      10,
                    ),
                    child: phone
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Brand(),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: widget.onSignIn,
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Sign in / Create account'),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              const Expanded(child: _Brand()),
                              TextButton(
                                onPressed: () => _open(Uri.parse(
                                    'https://bridgepointintelligence.online/sample/')),
                                child: const Text('Free preview'),
                              ),
                              TextButton(
                                onPressed: () => _open(Uri.parse(
                                    'mailto:bridgepointintelligence@gmail.com')),
                                child: const Text('Contact'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: widget.onSignIn,
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Open BridgePoint'),
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: phone ? 14 : 24),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.home_outlined),
                            label: Text('Overview'),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: Icon(Icons.public_rounded),
                            label: Text('Expansion'),
                          ),
                          ButtonSegment(
                            value: 2,
                            icon: Icon(Icons.auto_awesome_mosaic_rounded),
                            label: Text('What it can do'),
                          ),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (value) =>
                            setState(() => _tab = value.first),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        phone ? 14 : 24,
                        14,
                        phone ? 14 : 24,
                        38,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1220),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_tab == 0) ...[
                              _Hero(onOpen: widget.onSignIn),
                              const SizedBox(height: 16),
                              const _Stats(),
                              const SizedBox(height: 16),
                              const _Heading(
                                eyebrow: 'THE SIMPLE VERSION',
                                title: 'One property. One connected story.',
                                subtitle:
                                    'BridgePoint is built to reduce the time spent jumping between assessor sites, parcel maps, weather tools, public records and disconnected spreadsheets. It brings supported evidence back to the property and explains why it matters.',
                              ),
                              const SizedBox(height: 12),
                              const _FeatureGrid(),
                              const SizedBox(height: 16),
                              _Founder(
                                onWebsite: () => _open(Uri.parse(
                                    'https://bridgepointintelligence.online')),
                                onContact: () => _open(Uri.parse(
                                    'mailto:bridgepointintelligence@gmail.com')),
                              ),
                              const SizedBox(height: 16),
                              _SystemHealthCard(payload: at(0)),
                            ] else if (_tab == 1) ...[
                              _ExpansionView(
                                payload: at(1),
                                onOpen: widget.onSignIn,
                              ),
                            ] else ...[
                              _CapabilitiesView(
                                payload: at(2),
                                onOpen: widget.onSignIn,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _asRows(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

String _text(dynamic value, [String fallback = '']) {
  final s = value?.toString().trim() ?? '';
  return s.isEmpty ? fallback : s;
}

String _number(dynamic value) {
  final n = value is num ? value.toInt() : int.tryParse('$value');
  if (n == null) return '—';
  final raw = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
    out.write(raw[i]);
  }
  return out.toString();
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          BridgePointMarkV2(size: 46),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRIDGEPOINT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'INTELLIGENCE',
                  style: TextStyle(
                    color: _BridgePointPublicLandingV2State._cyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 680;
    return Container(
      padding: EdgeInsets.all(phone ? 23 : 38),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06101F), Color(0xFF0A2036), Color(0xFF10244A)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _BridgePointPublicLandingV2State._cyan.withValues(alpha: .18),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                Icons.location_on_outlined,
                'CONNECTICUT LIVE',
                _BridgePointPublicLandingV2State._cyan,
              ),
              _Pill(
                Icons.circle,
                'CUSTOMER PRODUCT LIVE',
                _BridgePointPublicLandingV2State._green,
              ),
              _Pill(
                Icons.public_rounded,
                'U.S. EXPANSION ACTIVE',
                _BridgePointPublicLandingV2State._blue,
              ),
            ],
          ),
          SizedBox(height: phone ? 27 : 42),
          Text(
            'See the property\nbefore the visit.',
            style: TextStyle(
              fontSize: phone ? 39 : 61,
              fontWeight: FontWeight.w900,
              height: .98,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 17),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Text(
              'BridgePoint connects property records, ownership changes, weather, environmental context, imagery, physical-property data and other supported evidence around the same property—then helps you understand what deserves attention first and why.',
              style: TextStyle(
                color: _BridgePointPublicLandingV2State._muted,
                fontSize: 15.5,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Create account / Open BridgePoint'),
              ),
              const _Pill(
                Icons.verified_user_outlined,
                'EVIDENCE + SOURCE CONTEXT',
                _BridgePointPublicLandingV2State._amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '7-day trial on eligible self-checkout plans. BridgePoint prioritizes investigation; it does not treat a score or nearby event as proof of damage, causation, claim coverage or customer intent.',
            style: TextStyle(
              color: Color(0xFF91A8BC),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 900 ? 4 : c.maxWidth >= 520 ? 2 : 1;
          final width = (c.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: width,
                child: const _Stat(
                  '1,282,833',
                  'CONNECTICUT PROPERTIES',
                  'Statewide parcel / assessor foundation used as the live launch market.',
                  _BridgePointPublicLandingV2State._cyan,
                ),
              ),
              SizedBox(
                width: width,
                child: const _Stat(
                  'ONE VIEW',
                  'PROPERTY INTELLIGENCE',
                  'Identity, timeline, evidence, signals, imagery and physical context together.',
                  _BridgePointPublicLandingV2State._blue,
                ),
              ),
              SizedBox(
                width: width,
                child: const _Stat(
                  'LIVE',
                  'MAP + WEATHER',
                  'Property geography, weather context, satellite layers and radar.',
                  _BridgePointPublicLandingV2State._green,
                ),
              ),
              SizedBox(
                width: width,
                child: const _Stat(
                  'EXPLAINABLE',
                  'WHY THIS PROPERTY',
                  'Scores and opportunities are designed to point back to supporting evidence.',
                  _BridgePointPublicLandingV2State._amber,
                ),
              ),
            ],
          );
        },
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.detail, this.color);
  final String value;
  final String label;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _BridgePointPublicLandingV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: const TextStyle(
                color: _BridgePointPublicLandingV2State._muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.home_work_rounded,
        'Property workspace',
        'Open one property and keep parcel facts, ownership, evidence, timeline, imagery and intelligence together instead of bouncing between tabs and websites.',
        _BridgePointPublicLandingV2State._cyan,
      ),
      (
        Icons.leaderboard_rounded,
        'Prioritized opportunities',
        'Narrow a large territory to the properties that deserve a closer look, with confidence and plain-language reasons instead of an unexplained lead list.',
        _BridgePointPublicLandingV2State._green,
      ),
      (
        Icons.cloud_outlined,
        'Weather + hazard context',
        'Put storms, flood and available environmental context next to the property while keeping exposure separate from proof of actual impact.',
        _BridgePointPublicLandingV2State._blue,
      ),
      (
        Icons.photo_library_outlined,
        'Imagery + physical context',
        'Use lawful front, aerial, historical imagery and source-backed building geometry where coverage exists, with provenance and fidelity limits preserved.',
        _BridgePointPublicLandingV2State._amber,
      ),
      (
        Icons.auto_awesome_rounded,
        'Ask BridgePoint AI',
        'Ask questions across supported property intelligence without losing the connection to evidence, geography and source limitations.',
        _BridgePointPublicLandingV2State._cyan,
      ),
      (
        Icons.route_outlined,
        'From research to field work',
        'Save properties, organize follow-up, build routes, notes and evidence packets, and bring the intelligence into the real-world workflow.',
        _BridgePointPublicLandingV2State._blue,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 1040 ? 3 : c.maxWidth >= 650 ? 2 : 1;
        final width = (c.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _Feature(item.$1, item.$2, item.$3, item.$4),
              ),
          ],
        );
      },
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.text, this.color);
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: _BridgePointPublicLandingV2State._panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      color: _BridgePointPublicLandingV2State._muted,
                      fontSize: 12.8,
                      height: 1.48,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Founder extends StatelessWidget {
  const _Founder({required this.onWebsite, required this.onContact});
  final VoidCallback onWebsite;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2034), Color(0xFF102640)],
          ),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: _BridgePointPublicLandingV2State._cyan.withValues(alpha: .18),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final identity = const Row(
              children: [
                BridgePointMarkV2(size: 56),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kole Johnson',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Founder · BridgePoint Intelligence',
                        style: TextStyle(
                          color: _BridgePointPublicLandingV2State._cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Connecticut-built property intelligence platform focused on matching fragmented evidence back to the real property and making it useful before the visit.',
                        style: TextStyle(
                          color: _BridgePointPublicLandingV2State._muted,
                          fontSize: 12.7,
                          height: 1.42,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onWebsite,
                  icon: const Icon(Icons.language_rounded),
                  label: const Text('Website'),
                ),
                OutlinedButton.icon(
                  onPressed: onContact,
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Contact'),
                ),
              ],
            );
            if (c.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      );
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({required this.payload});
  final dynamic payload;

  @override
  Widget build(BuildContext context) {
    final data = _asMap(payload);
    final mode = _text(data['mode'], 'UNKNOWN').toUpperCase();
    final blocked = data['app_access_blocked'] == true;
    final message = _text(
      data['public_message'],
      'BridgePoint is monitoring customer access and connected data sources.',
    );
    final healthy = !blocked && mode != 'OFFLINE';
    final recovering = healthy && mode == 'DEGRADED';
    final color = healthy
        ? (recovering
            ? _BridgePointPublicLandingV2State._amber
            : _BridgePointPublicLandingV2State._green)
        : const Color(0xFFFF7B7B);
    final headline = !healthy
        ? 'Customer access issue detected'
        : recovering
            ? 'BridgePoint is online · source recovery active'
            : 'BridgePoint is online';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _BridgePointPublicLandingV2State._panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.monitor_heart_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE PLATFORM STATUS',
                      style: TextStyle(
                        color: _BridgePointPublicLandingV2State._muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill(Icons.circle, healthy ? 'ACCESSIBLE' : 'ISSUE', color),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: _BridgePointPublicLandingV2State._muted,
              fontSize: 13.2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _MiniTrust(
                Icons.verified_user_outlined,
                'Source-aware',
                'BridgePoint tracks source freshness and failures instead of turning missing data into a false “no.”',
              ),
              _MiniTrust(
                Icons.refresh_rounded,
                'Automatic recovery',
                'Supported external-source failures can be rerouted or rediscovered without blocking the entire customer product.',
              ),
              _MiniTrust(
                Icons.fact_check_outlined,
                'Truthful outputs',
                'Scores and signals remain decision support—not proof of physical damage, coverage or guaranteed outcomes.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTrust extends StatelessWidget {
  const _MiniTrust(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: 330,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _BridgePointPublicLandingV2State._soft.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: _BridgePointPublicLandingV2State._cyan, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(
                      color: _BridgePointPublicLandingV2State._muted,
                      fontSize: 11.7,
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ExpansionView extends StatelessWidget {
  const _ExpansionView({required this.payload, required this.onOpen});
  final dynamic payload;
  final VoidCallback onOpen;

  static const priority = ['CT', 'MA', 'NY', 'NJ', 'OH', 'FL', 'TX', 'CA'];

  @override
  Widget build(BuildContext context) {
    final data = _asMap(payload);
    final markets = _asRows(data['markets']);
    final live = markets.where((m) => _text(m['data_status']) == 'LIVE').length;
    final building =
        markets.where((m) => _text(m['data_status']) == 'BUILDING').length;
    final paused = markets.where((m) => _text(m['data_status']) == 'PAUSED').length;
    final selected = <Map<String, dynamic>>[];
    for (final code in priority) {
      final found = markets.where((m) => _text(m['state_code']) == code);
      if (found.isNotEmpty) selected.add(found.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          eyebrow: 'NATIONAL EXPANSION',
          title: 'One platform. State-by-state readiness truth.',
          subtitle:
              'Connecticut is the live customer market. BridgePoint is actively building property foundations, matching, evidence and context across the U.S., but a state is not labeled customer-ready simply because some records exist there.',
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : 1;
            final width = (c.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: _ExpansionStat(
                    '$live',
                    'CUSTOMER-READY MARKET',
                    'Connecticut is live with a reconciled statewide property foundation.',
                    _BridgePointPublicLandingV2State._green,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ExpansionStat(
                    '$building',
                    'MARKETS BUILDING',
                    'Property records and intelligence layers are progressing without being mislabeled as finished.',
                    _BridgePointPublicLandingV2State._blue,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ExpansionStat(
                    '$paused',
                    'WAITING ON SOURCE GAPS',
                    'Some jurisdictions need a better lawful property source before the build can advance.',
                    _BridgePointPublicLandingV2State._amber,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const _Heading(
          eyebrow: 'HOW A STATE BECOMES LIVE',
          title: 'Build the foundation. Match the evidence. Prove the experience.',
          subtitle:
              'The expansion engine is designed around quality gates rather than a marketing countdown.',
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StepCard(
              '1',
              'Property foundation',
              'Find and normalize lawful parcel / assessment foundations and establish the real property universe.',
            ),
            _StepCard(
              '2',
              'Match + enrich',
              'Connect records, events and context back to the correct property with confidence and provenance.',
            ),
            _StepCard(
              '3',
              'Customer readiness',
              'Verify coverage, scoring, explanations, product access and QA before the market is called live.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _Heading(
          eyebrow: 'CURRENT BUILD SNAPSHOT',
          title: 'A few markets people ask about most.',
          subtitle:
              'Progress below is intentionally simplified. BridgePoint does not show misleading multi-year machine ETAs to customers when source coverage or throughput is still changing.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 960 ? 4 : c.maxWidth >= 620 ? 2 : 1;
            final width = (c.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final market in selected)
                  SizedBox(width: width, child: _MarketCard(market: market)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102840), Color(0xFF0C1B2D)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  _BridgePointPublicLandingV2State._cyan.withValues(alpha: .18),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 12,
            children: [
              const SizedBox(
                width: 650,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Want to use BridgePoint now?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Start in Connecticut today. Additional states unlock only when BridgePoint’s readiness gates say the customer experience is ready.',
                      style: TextStyle(
                        color: _BridgePointPublicLandingV2State._muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Open BridgePoint'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpansionStat extends StatelessWidget {
  const _ExpansionStat(this.value, this.label, this.text, this.color);
  final String value;
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _BridgePointPublicLandingV2State._panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6)),
            const SizedBox(height: 7),
            Text(text,
                style: const TextStyle(
                    color: _BridgePointPublicLandingV2State._muted,
                    fontSize: 12.5,
                    height: 1.4)),
          ],
        ),
      );
}

class _StepCard extends StatelessWidget {
  const _StepCard(this.number, this.title, this.text);
  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: 375,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _BridgePointPublicLandingV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  _BridgePointPublicLandingV2State._blue.withValues(alpha: .18),
              child: Text(number,
                  style: const TextStyle(
                      color: _BridgePointPublicLandingV2State._cyan,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(text,
                      style: const TextStyle(
                          color: _BridgePointPublicLandingV2State._muted,
                          fontSize: 12.2,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.market});
  final Map<String, dynamic> market;

  String _phaseLabel(String phase) => switch (phase) {
        'ACTIVATED' => 'Customer ready',
        'PROPERTY_FOUNDATION' => 'Building property foundation',
        'NORMALIZE_MATCH' => 'Matching property records',
        'SIGNALS_EVIDENCE' => 'Building evidence + signals',
        'CONTEXT_LAYERS' => 'Adding context layers',
        'CUSTOMER_QA' => 'Customer-readiness QA',
        'PROPERTY_SOURCE_REQUIRED' => 'Improving source coverage',
        _ => 'Expansion work in progress',
      };

  @override
  Widget build(BuildContext context) {
    final eta = _asMap(market['build_eta']);
    final status = _text(market['data_status'], 'BUILDING');
    final live = status == 'LIVE';
    final paused = status == 'PAUSED';
    final color = live
        ? _BridgePointPublicLandingV2State._green
        : paused
            ? _BridgePointPublicLandingV2State._amber
            : _BridgePointPublicLandingV2State._blue;
    final progress = eta['progress_pct'] is num
        ? (eta['progress_pct'] as num).toDouble().clamp(0, 100)
        : null;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _BridgePointPublicLandingV2State._panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text(market['state_name'], _text(market['state_code'])),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(
                Icons.circle,
                live
                    ? 'LIVE'
                    : paused
                        ? 'SOURCE GAP'
                        : 'BUILDING',
                color,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            _phaseLabel(_text(eta['phase'])),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${_number(market['canonical_property_count'])} property records currently represented',
            style: const TextStyle(
              color: _BridgePointPublicLandingV2State._muted,
              fontSize: 12.2,
              height: 1.35,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFF091522),
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${progress.toStringAsFixed(1)}% of the current property-foundation target',
              style: const TextStyle(
                color: _BridgePointPublicLandingV2State._muted,
                fontSize: 10.8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapabilitiesView extends StatelessWidget {
  const _CapabilitiesView({required this.payload, required this.onOpen});
  final dynamic payload;
  final VoidCallback onOpen;

  static const customerGroups = [
    'Property Intelligence',
    'Intelligence',
    'AI & Search',
    'Hazards',
    'Physical Property',
    'Workflow',
  ];

  @override
  Widget build(BuildContext context) {
    final data = _asMap(payload);
    final capabilities = _asRows(data['capabilities']);
    final packages = _asRows(data['packages']);
    final readyPlans = packages.where((p) {
      final type = _text(p['package_type']);
      final key = _text(p['package_key']);
      return _text(p['delivery_status']) == 'READY' &&
          (type == 'standard' || key == 'all_intelligence');
    }).toList();
    final billing = _asMap(data['billing']);
    final checkoutReady = billing['payments_enabled'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          eyebrow: 'WHAT BRIDGEPOINT CAN DO',
          title: 'A lot underneath. A simpler experience on top.',
          subtitle:
              'BridgePoint’s backend tracks many specialized engines, but customers should not need to understand the infrastructure to use the product. These are the capabilities that matter in the actual property workflow.',
        ),
        const SizedBox(height: 15),
        const _CapabilityHeroGrid(),
        const SizedBox(height: 20),
        const _Heading(
          eyebrow: 'LIVE CAPABILITY DIRECTORY',
          title: 'The useful pieces, grouped by what they help you do.',
          subtitle:
              'Availability can vary by geography and package. “Available” means the capability exists; it does not mean every source or property has equal coverage.',
        ),
        const SizedBox(height: 12),
        for (final group in customerGroups) ...[
          _CapabilityGroup(
            group: group,
            items: capabilities
                .where((c) => _text(c['group']) == group)
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: _Heading(
                eyebrow: 'STARTING OPTIONS',
                title: 'Choose the version that fits the work.',
                subtitle:
                    'Eligible self-checkout plans include a 7-day trial. Enterprise technology and custom integrations stay out of the way unless a customer actually needs them.',
              ),
            ),
            if (checkoutReady)
              const _Pill(
                Icons.lock_rounded,
                'CHECKOUT READY',
                _BridgePointPublicLandingV2State._green,
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 980 ? 3 : c.maxWidth >= 620 ? 2 : 1;
            final width = (c.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final plan in readyPlans)
                  SizedBox(
                    width: width,
                    child: _PlanCard(plan: plan, onOpen: onOpen),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CapabilityHeroGrid extends StatelessWidget {
  const _CapabilityHeroGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.home_work_rounded,
        'Understand one property',
        'Property identity, parcel and assessment context, ownership, timeline, evidence and physical-property context in one workspace.',
      ),
      (
        Icons.bolt_rounded,
        'Find what deserves attention',
        'Signals, patterns and explainable opportunity scoring help narrow large territories without pretending a score is proof.',
      ),
      (
        Icons.cloud_outlined,
        'Add risk context',
        'Weather, storm, flood and environmental records can be connected to the property with source and timing context.',
      ),
      (
        Icons.image_outlined,
        'See physical change',
        'Front, aerial and historical imagery plus source-backed geometry are used where lawful coverage exists.',
      ),
      (
        Icons.auto_awesome_rounded,
        'Ask questions naturally',
        'Search and AI help users get to the property, evidence and explanation without digging through raw source systems.',
      ),
      (
        Icons.workspaces_outline,
        'Turn intelligence into work',
        'Saved properties, routes, notes, reports and follow-up workflows keep the research connected to what happens next.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 640 ? 2 : 1;
        final width = (c.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _Feature(
                  item.$1,
                  item.$2,
                  item.$3,
                  _BridgePointPublicLandingV2State._cyan,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CapabilityGroup extends StatelessWidget {
  const _CapabilityGroup({required this.group, required this.items});
  final String group;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BridgePointPublicLandingV2State._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 2 : 1;
              final width = (c.maxWidth - (cols - 1) * 10) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: _CapabilityLine(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final availability = _text(item['availability'], 'AVAILABLE');
    final building = availability == 'BUILDING';
    final enterprise = availability == 'ENTERPRISE_INTEGRATION';
    final color = building
        ? _BridgePointPublicLandingV2State._amber
        : enterprise
            ? _BridgePointPublicLandingV2State._blue
            : _BridgePointPublicLandingV2State._green;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _BridgePointPublicLandingV2State._soft.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text(item['capability_name'], 'BridgePoint capability'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(
                Icons.circle,
                building
                    ? 'BUILDING'
                    : enterprise
                        ? 'ENTERPRISE'
                        : 'AVAILABLE',
                color,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _text(item['description']),
            style: const TextStyle(
              color: _BridgePointPublicLandingV2State._muted,
              fontSize: 12.1,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onOpen});
  final Map<String, dynamic> plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final monthly = plan['monthly_price'];
    final trial = plan['trial_days'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BridgePointPublicLandingV2State._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _BridgePointPublicLandingV2State._blue.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text(plan['package_name'], 'BridgePoint'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            monthly == null ? 'Contact for pricing' : '\$$monthly / month',
            style: const TextStyle(
              color: _BridgePointPublicLandingV2State._cyan,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _text(plan['description']),
            style: const TextStyle(
              color: _BridgePointPublicLandingV2State._muted,
              fontSize: 12.3,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (trial is num && trial > 0)
                _Pill(
                  Icons.timer_outlined,
                  '${trial.toInt()}-DAY TRIAL',
                  _BridgePointPublicLandingV2State._green,
                ),
              const Spacer(),
              TextButton(
                onPressed: onOpen,
                child: const Text('Start →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String? eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: const TextStyle(
                color: _BridgePointPublicLandingV2State._cyan,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: _BridgePointPublicLandingV2State._muted,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.8,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
      );
}
