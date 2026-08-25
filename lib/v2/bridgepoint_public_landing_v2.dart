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
  late Future<List<dynamic>> _request;
  int _tab = 0;

  static const _navy = Color(0xFF07111F);
  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

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
    if (value is List) return {'items': value};
    return {'value': value};
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

  Widget _header(bool compact) {
    final brand = const _PublicBrand();
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          brand,
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onSignIn,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign in / Create account'),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: brand),
        TextButton(
          onPressed: () => _open(Uri.parse('mailto:bridgepointintelligence@gmail.com')),
          child: const Text('Contact'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: widget.onSignIn,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Open BridgePoint'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 640;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: _navy),
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _request,
            builder: (context, snapshot) {
              final data = snapshot.data ?? const [];
              dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(phone ? 14 : 24, 14, phone ? 14 : 24, 10),
                    child: _header(phone),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: phone ? 14 : 24),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, icon: Icon(Icons.home_outlined), label: Text('Overview')),
                          ButtonSegment(value: 1, icon: Icon(Icons.dataset_outlined), label: Text('Public Data Desk')),
                          ButtonSegment(value: 2, icon: Icon(Icons.public_rounded), label: Text('Expansion')),
                          ButtonSegment(value: 3, icon: Icon(Icons.extension_outlined), label: Text('Capabilities')),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (value) => setState(() => _tab = value.first),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(phone ? 14 : 24, 10, phone ? 14 : 24, 34),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_tab == 0) ...[
                              _Hero(onOpen: widget.onSignIn),
                              const SizedBox(height: 14),
                              const _StatsStrip(),
                              const SizedBox(height: 14),
                              const _CapabilityShowcase(),
                              const SizedBox(height: 14),
                              _FounderStrip(
                                onWebsite: () => _open(Uri.parse('https://bridgepointintelligence.online')),
                                onEmail: () => _open(Uri.parse('mailto:bridgepointintelligence@gmail.com')),
                              ),
                              const SizedBox(height: 14),
                              _PublicPanel(
                                title: 'Live system readiness',
                                subtitle: 'Aggregate public-safe status from the production system',
                                value: at(0),
                                icon: Icons.monitor_heart_outlined,
                              ),
                            ] else if (_tab == 1) ...[
                              const _SectionHeading(
                                title: 'Public Data Desk',
                                subtitle: 'Registration-free aggregate information with property addresses, customer data and proprietary scoring weights intentionally excluded.',
                              ),
                              const SizedBox(height: 12),
                              _PublicPanel(title: 'System / dataset readiness', subtitle: 'What BridgePoint can safely expose without revealing customer or proprietary data', value: at(0), icon: Icons.dataset_outlined),
                              const SizedBox(height: 12),
                              const _DisclosureCard(),
                            ] else if (_tab == 2) ...[
                              const _SectionHeading(
                                title: 'Expansion readiness',
                                subtitle: 'BridgePoint distinguishes LIVE markets from BUILDING markets. No invented countdowns, fake coverage or fabricated readiness.',
                              ),
                              const SizedBox(height: 12),
                              _PublicPanel(title: 'Markets / bundles', subtitle: 'Current public-safe geography and expansion state', value: at(1), icon: Icons.public_rounded),
                            ] else ...[
                              const _SectionHeading(
                                title: 'Capability directory',
                                subtitle: 'A public-safe view of the platform. Internal automation, model mechanics and proprietary scoring logic stay private.',
                              ),
                              const SizedBox(height: 12),
                              _PublicPanel(title: 'BridgePoint capabilities', subtitle: 'Property intelligence, workflows, risk, evidence, AI and data infrastructure', value: at(2), icon: Icons.extension_outlined),
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

class _PublicBrand extends StatelessWidget {
  const _PublicBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_BridgePointPublicLandingV2State._cyan, _BridgePointPublicLandingV2State._blue]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [BoxShadow(color: _BridgePointPublicLandingV2State._cyan.withValues(alpha: .18), blurRadius: 20)],
          ),
          child: const Icon(Icons.polyline_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BRIDGEPOINT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.1)),
              Text('INTELLIGENCE', style: TextStyle(color: _BridgePointPublicLandingV2State._cyan, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 2.0)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 640;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bridgepoint-intelligence-background-v1.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: _BridgePointPublicLandingV2State._panel),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _BridgePointPublicLandingV2State._navy.withValues(alpha: .98),
                    const Color(0xFF071321).withValues(alpha: .88),
                    _BridgePointPublicLandingV2State._blue.withValues(alpha: .28),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(phone ? 22 : 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(icon: Icons.location_on_outlined, label: 'CONNECTICUT BUILT', color: _BridgePointPublicLandingV2State._cyan),
                    _HeroPill(icon: Icons.circle, label: 'LIVE PRODUCT', color: _BridgePointPublicLandingV2State._green),
                    _HeroPill(icon: Icons.public_rounded, label: 'NATIONAL EXPANSION', color: _BridgePointPublicLandingV2State._blue),
                  ],
                ),
                SizedBox(height: phone ? 30 : 50),
                Text(
                  'See the property\nbefore the visit.',
                  style: TextStyle(fontSize: phone ? 38 : 62, fontWeight: FontWeight.w900, height: .98, letterSpacing: -1.5),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Text(
                    'BridgePoint connects fragmented property records, public data, weather, permits, ownership changes, environmental evidence, physical intelligence and model outputs into one explainable property story—then turns that story into ranked action.',
                    style: TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 15, height: 1.65),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(onPressed: onOpen, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Open BridgePoint')),
                    _HeroPill(icon: Icons.verified_user_outlined, label: 'EVIDENCE + PROVENANCE', color: _BridgePointPublicLandingV2State._amber),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .24))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .75)),
        ]),
      );
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 900 ? 4 : c.maxWidth >= 520 ? 2 : 1;
      final width = (c.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(width: width, child: const _PublicMetric(value: '1,282,833', label: 'CT PROPERTIES', detail: 'Canonical parcel / CAMA inventory', accent: _BridgePointPublicLandingV2State._cyan)),
        SizedBox(width: width, child: const _PublicMetric(value: '33', label: 'LIVE PACKAGES', detail: 'From homeowner to enterprise intelligence', accent: _BridgePointPublicLandingV2State._blue)),
        SizedBox(width: width, child: const _PublicMetric(value: '7 DAYS', label: 'TRIAL', detail: 'Active package trial structure', accent: _BridgePointPublicLandingV2State._green)),
        SizedBox(width: width, child: const _PublicMetric(value: 'PROPERTY DNA', label: 'CORE VIEW', detail: 'Timeline, evidence, signals and Why Now', accent: _BridgePointPublicLandingV2State._amber)),
      ]);
    });
  }
}

class _PublicMetric extends StatelessWidget {
  const _PublicMetric({required this.value, required this.label, required this.detail, required this.accent});
  final String value;
  final String label;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .07))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 30, height: 4, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 13),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10, height: 1.35)),
        ]),
      );
}

class _CapabilityShowcase extends StatelessWidget {
  const _CapabilityShowcase();

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.home_work_rounded, 'Property 360', 'Canonical property identity, parcel facts, geometry, timeline and supporting evidence.', _BridgePointPublicLandingV2State._cyan),
      (Icons.public_rounded, 'Map & Weather', 'Live geospatial intelligence, weather context, layers and property-linked evidence.', _BridgePointPublicLandingV2State._blue),
      (Icons.leaderboard_rounded, 'Ranked Opportunities', 'Prioritized properties with score, confidence, top signal and Why Now explanation.', _BridgePointPublicLandingV2State._green),
      (Icons.history_rounded, 'Property DNA & Timeline', 'Ownership, permits, storms, incidents, physical change and source-backed history.', _BridgePointPublicLandingV2State._amber),
      (Icons.auto_awesome_rounded, 'BridgePoint AI', 'Ask questions across property intelligence without separating the answer from evidence.', _BridgePointPublicLandingV2State._cyan),
      (Icons.track_changes_rounded, 'Operations', 'Saved opportunities, notes, calendar, claims, portfolio risk and next-best-action workflows.', _BridgePointPublicLandingV2State._blue),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 1080 ? 3 : c.maxWidth >= 650 ? 2 : 1;
      final width = (c.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final item in items)
          SizedBox(
            width: width,
            child: _FeatureCard(icon: item.$1, title: item.$2, text: item.$3, accent: item.$4),
          ),
      ]);
    });
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.text, required this.accent});
  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_BridgePointPublicLandingV2State._panel, accent.withValues(alpha: .06)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(text, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 11, height: 1.45)),
          ])),
        ]),
      );
}

class _FounderStrip extends StatelessWidget {
  const _FounderStrip({required this.onWebsite, required this.onEmail});
  final VoidCallback onWebsite;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _BridgePointPublicLandingV2State._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BridgePointPublicLandingV2State._cyan.withValues(alpha: .16)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 760;
        final identity = const Row(children: [
          CircleAvatar(radius: 27, backgroundColor: _BridgePointPublicLandingV2State._blue, child: Icon(Icons.person_rounded, color: Colors.white, size: 28)),
          SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kole Johnson', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            SizedBox(height: 2),
            Text('Founder, BridgePoint Intelligence', style: TextStyle(color: _BridgePointPublicLandingV2State._cyan, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Connecticut-built property intelligence software + data infrastructure • Live product • Early commercialization', style: TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10, height: 1.4)),
          ])),
        ]);
        final actions = Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: onWebsite, icon: const Icon(Icons.language_rounded), label: const Text('Website')),
          OutlinedButton.icon(onPressed: onEmail, icon: const Icon(Icons.mail_outline_rounded), label: const Text('Contact founder')),
        ]);
        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 14), actions]);
        return Row(children: [Expanded(child: identity), const SizedBox(width: 18), actions]);
      }),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Text(subtitle, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, height: 1.5))),
      ]);
}

class _PublicPanel extends StatelessWidget {
  const _PublicPanel({required this.title, required this.subtitle, required this.value, required this.icon});
  final String title;
  final String subtitle;
  final dynamic value;
  final IconData icon;

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['items', 'markets', 'capabilities', 'results', 'bundles']) {
        if (value[key] is List) return _rows(value[key]);
      }
      return [Map<String, dynamic>.from(value)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows(value);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .07))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._cyan.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _BridgePointPublicLandingV2State._cyan)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10)),
          ])),
        ]),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const Text('No public aggregate data returned.', style: TextStyle(color: _BridgePointPublicLandingV2State._muted))
        else
          ...rows.take(80).map((row) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _PublicRow(row))),
      ]),
    );
  }
}

class _PublicRow extends StatelessWidget {
  const _PublicRow(this.value);
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._panelSoft.withValues(alpha: .72), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withValues(alpha: .05))),
      child: Wrap(spacing: 10, runSpacing: 6, children: value.entries.take(28).map((e) {
        final raw = '${e.value}';
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Text('${e.key.replaceAll('_', ' ')}: ${raw.length > 280 ? '${raw.substring(0, 280)}…' : raw}', style: const TextStyle(fontSize: 9, height: 1.35)),
        );
      }).toList()),
    );
  }
}

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _BridgePointPublicLandingV2State._amber.withValues(alpha: .06), borderRadius: BorderRadius.circular(14), border: Border.all(color: _BridgePointPublicLandingV2State._amber.withValues(alpha: .18))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: _BridgePointPublicLandingV2State._amber, size: 18),
          SizedBox(width: 9),
          Expanded(child: Text('Public-data disclosure: BridgePoint “verified opportunity” language refers to a prioritization/review layer, not confirmed damage, a claim, an inspection finding or guaranteed customer intent.', style: TextStyle(color: _BridgePointPublicLandingV2State._muted, fontSize: 10, height: 1.45))),
        ]),
      );
}
