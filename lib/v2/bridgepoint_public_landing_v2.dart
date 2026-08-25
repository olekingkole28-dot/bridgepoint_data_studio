import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BridgePointPublicLandingV2 extends StatefulWidget {
  const BridgePointPublicLandingV2({super.key, required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  State<BridgePointPublicLandingV2> createState() => _BridgePointPublicLandingV2State();
}

class _BridgePointPublicLandingV2State extends State<BridgePointPublicLandingV2> {
  static const _navy = Color(0xFF07111F);
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

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
    } catch (e) {
      return {'available': false, 'rpc': rpc, 'error': '$e'};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_public_system_status_v320'),
        _safe('bridgepoint_public_expansion_status_v321'),
        _safe('bridgepoint_public_capability_directory_v735'),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (value is Map) {
      for (final key in const ['items', 'markets', 'capabilities', 'results', 'bundles']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

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
              dynamic at(int i) => i < values.length ? values[i] : const <String, dynamic>{};
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(phone ? 14 : 24, 14, phone ? 14 : 24, 10),
                    child: phone
                        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            const _Brand(),
                            const SizedBox(height: 10),
                            FilledButton.icon(onPressed: widget.onSignIn, icon: const Icon(Icons.login_rounded), label: const Text('Sign in / Create account')),
                          ])
                        : Row(children: [
                            const Expanded(child: _Brand()),
                            TextButton(onPressed: () => _open(Uri.parse('mailto:bridgepointintelligence@gmail.com')), child: const Text('Contact')),
                            const SizedBox(width: 8),
                            FilledButton.icon(onPressed: widget.onSignIn, icon: const Icon(Icons.login_rounded), label: const Text('Open BridgePoint')),
                          ]),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: phone ? 14 : 24),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, icon: Icon(Icons.home_outlined), label: Text('Overview')),
                          ButtonSegment(value: 1, icon: Icon(Icons.public_rounded), label: Text('Expansion')),
                          ButtonSegment(value: 2, icon: Icon(Icons.extension_outlined), label: Text('Capabilities')),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (value) => setState(() => _tab = value.first),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(phone ? 14 : 24, 12, phone ? 14 : 24, 36),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1450),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (_tab == 0) ...[
                            _Hero(onOpen: widget.onSignIn),
                            const SizedBox(height: 14),
                            const _Stats(),
                            const SizedBox(height: 14),
                            const _FeatureGrid(),
                            const SizedBox(height: 14),
                            _Founder(
                              onWebsite: () => _open(Uri.parse('https://bridgepointintelligence.online')),
                              onContact: () => _open(Uri.parse('mailto:bridgepointintelligence@gmail.com')),
                            ),
                            const SizedBox(height: 14),
                            _DataPanel(title: 'Live public system status', subtitle: 'Aggregate public-safe production status', payload: at(0), icon: Icons.monitor_heart_outlined),
                          ] else if (_tab == 1) ...[
                            const _Heading(title: 'Expansion readiness', subtitle: 'BridgePoint distinguishes LIVE markets from BUILDING markets. Coverage is not claimed until the underlying readiness gates actually pass.'),
                            const SizedBox(height: 12),
                            _DataPanel(title: 'Markets / expansion', subtitle: 'Current public-safe geography and expansion state', payload: at(1), icon: Icons.public_rounded),
                          ] else ...[
                            const _Heading(title: 'Capability directory', subtitle: 'A public-safe view of the platform. Private scoring weights, internal automation and proprietary learning logic remain private.'),
                            const SizedBox(height: 12),
                            _DataPanel(title: 'BridgePoint capabilities', subtitle: 'Property intelligence, risk, evidence, workflow, AI and data infrastructure', payload: at(2), icon: Icons.extension_outlined),
                          ],
                        ]),
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

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_BridgePointPublicLandingV2State._cyan, _BridgePointPublicLandingV2State._blue]), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.polyline_rounded, color: Colors.white)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BRIDGEPOINT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.1)),
          Text('INTELLIGENCE', style: TextStyle(color: _BridgePointPublicLandingV2State._cyan, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
        ])),
      ]);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 680;
    return Container(
      padding: EdgeInsets.all(phone ? 22 : 38),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF07111F), Color(0xFF0A2036), Color(0xFF10244A)]),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _BridgePointPublicLandingV2State._cyan.withValues(alpha: .16)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 16))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill(Icons.location_on_outlined, 'CONNECTICUT BUILT', _BridgePointPublicLandingV2State._cyan),
          _Pill(Icons.circle, 'LIVE PRODUCT', _BridgePointPublicLandingV2State._green),
          _Pill(Icons.public_rounded, 'NATIONAL EXPANSION', _BridgePointPublicLandingV2State._blue),
        ]),
        SizedBox(height: phone ? 28 : 44),
        Text('See the property\nbefore the visit.', style: TextStyle(fontSize: phone ? 38 : 61, fontWeight: FontWeight.w900, height: .98, letterSpacing: -1.4)),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Text('BridgePoint connects fragmented property records, public data, weather, ownership changes, environmental evidence, physical intelligence, building geometry and model outputs into one explainable property story—then turns that story into ranked action.', style: TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 15, height: 1.65)),
        ),
        const SizedBox(height: 22),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: onOpen, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Open BridgePoint')),
          const _Pill(Icons.verified_user_outlined, 'EVIDENCE + PROVENANCE', _BridgePointPublicLandingV2State._amber),
        ]),
      ]),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth >= 900 ? 4 : c.maxWidth >= 520 ? 2 : 1;
        final width = (c.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: width, child: const _Stat('1,282,833', 'CT PROPERTIES', 'Canonical parcel / CAMA foundation', _BridgePointPublicLandingV2State._cyan)),
          SizedBox(width: width, child: const _Stat('2D + 3D', 'BUILDING INTELLIGENCE', 'Source footprints + schematic massing', _BridgePointPublicLandingV2State._blue)),
          SizedBox(width: width, child: const _Stat('LIVE', 'MAP + WEATHER', 'Properties, icons, satellite and radar', _BridgePointPublicLandingV2State._green)),
          SizedBox(width: width, child: const _Stat('PROPERTY DNA', 'CORE VIEW', 'Timeline, evidence, signals and Why Now', _BridgePointPublicLandingV2State._amber)),
        ]);
      });
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.detail, this.color);
  final String value;
  final String label;
  final String detail;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 30, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))), const SizedBox(height: 12), Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)), const SizedBox(height: 5), Text(detail, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10, height: 1.35))]));
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_work_rounded, 'Property 360', 'Canonical identity, parcel facts, geometry, timeline and supporting evidence.', _BridgePointPublicLandingV2State._cyan),
      (Icons.public_rounded, 'Map & Weather', 'Property markers, intelligence icons, satellite imagery and animated NOAA radar.', _BridgePointPublicLandingV2State._blue),
      (Icons.real_estate_agent_rounded, 'Investor', 'Ownership transitions, assessed value, redevelopment/distress context and ranked opportunities.', _BridgePointPublicLandingV2State._green),
      (Icons.view_in_ar_rounded, '2D / 3D Buildings', 'Source-backed building footprints, schematic massing and digital-twin context.', _BridgePointPublicLandingV2State._amber),
      (Icons.leaderboard_rounded, 'Ranked Opportunities', 'Prioritized properties with score, confidence, signals and Why Now explanation.', _BridgePointPublicLandingV2State._cyan),
      (Icons.auto_awesome_rounded, 'BridgePoint AI', 'Ask questions across property intelligence while keeping the answer attached to evidence.', _BridgePointPublicLandingV2State._blue),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 1080 ? 3 : c.maxWidth >= 650 ? 2 : 1;
      final width = (c.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(spacing: 10, runSpacing: 10, children: [for (final item in items) SizedBox(width: width, child: _Feature(item.$1, item.$2, item.$3, item.$4))]);
    });
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.text, this.color);
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(text, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10, height: 1.45))]))]));
}

class _Founder extends StatelessWidget {
  const _Founder({required this.onWebsite, required this.onContact});
  final VoidCallback onWebsite;
  final VoidCallback onContact;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _BridgePointPublicLandingV2State._cyan.withValues(alpha: .15))), child: LayoutBuilder(builder: (context, c) {
        final identity = const Row(children: [CircleAvatar(radius: 27, backgroundColor: _BridgePointPublicLandingV2State._blue, child: Icon(Icons.person_rounded, color: Colors.white, size: 28)), SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Kole Johnson', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), SizedBox(height: 2), Text('Founder, BridgePoint Intelligence', style: TextStyle(color: _BridgePointPublicLandingV2State._cyan, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Connecticut-built property intelligence software + data infrastructure • Live product • Early commercialization', style: TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10, height: 1.4))]))]);
        final actions = Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: onWebsite, icon: const Icon(Icons.language_rounded), label: const Text('Website')), OutlinedButton.icon(onPressed: onContact, icon: const Icon(Icons.mail_outline_rounded), label: const Text('Contact founder'))]);
        if (c.maxWidth < 760) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 14), actions]);
        return Row(children: [Expanded(child: identity), const SizedBox(width: 18), actions]);
      }));
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 6), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Text(subtitle, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, height: 1.5)))]);
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.title, required this.subtitle, required this.payload, required this.icon});
  final String title;
  final String subtitle;
  final dynamic payload;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final rows = _BridgePointPublicLandingV2State()._rows(payload);
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: _BridgePointPublicLandingV2State._cyan), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10))]))]), const SizedBox(height: 13), if (rows.isEmpty) Text('$payload', style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10)) else ...rows.take(60).map((row) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._soft.withValues(alpha: .65), borderRadius: BorderRadius.circular(11)), child: Wrap(spacing: 10, runSpacing: 5, children: row.entries.take(24).map((e) => Text('${e.key.replaceAll('_', ' ')}: ${e.value}', style: const TextStyle(fontSize: 9, height: 1.3))).toList())))]));
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .2))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 10), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7))]));
}
