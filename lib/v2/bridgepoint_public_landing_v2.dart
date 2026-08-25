import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointPublicLandingV2 extends StatefulWidget {
  const BridgePointPublicLandingV2({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  State<BridgePointPublicLandingV2> createState() => _BridgePointPublicLandingV2State();
}

class _BridgePointPublicLandingV2State extends State<BridgePointPublicLandingV2> {
  late Future<List<dynamic>> _request;
  int _tab = 0;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);

  @override
  void initState() {
    super.initState();
    _request = Future.wait([
      Supabase.instance.client.rpc('bridgepoint_public_system_status_v320'),
      Supabase.instance.client.rpc('bridgepoint_public_expansion_status_v321'),
      Supabase.instance.client.rpc('bridgepoint_public_capability_directory_v735'),
    ]);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return {'items': value};
    return {'value': value};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['items', 'markets', 'capabilities', 'results', 'bundles']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Widget _panel(String title, dynamic value, IconData icon) {
    final map = _map(value);
    final rows = _rows(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _cyan),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 10),
          if (rows.isNotEmpty)
            ...rows.take(80).map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _PublicRow(row),
                ))
          else
            _PublicRow(map),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.4,
            colors: [Color(0x2235D2E8), Color(0xFF06111E)],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _request,
            builder: (context, snapshot) {
              final data = snapshot.data ?? const [];
              dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(children: [
                      const Icon(Icons.hub_rounded, color: _cyan, size: 30),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('BridgePoint Intelligence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          Text('Property intelligence operating system', style: TextStyle(color: _muted, fontSize: 10)),
                        ]),
                      ),
                      FilledButton.icon(onPressed: widget.onSignIn, icon: const Icon(Icons.login_rounded), label: const Text('Sign in / Create account')),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
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
                  const SizedBox(height: 10),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (_tab == 0) ...[
                          const SizedBox(height: 24),
                          const Text('See the property before the visit.', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          const Text(
                            'BridgePoint connects property records, weather, permits, physical change, risk, imagery, models and workflows around one canonical property identity—then keeps the evidence and uncertainty visible.',
                            style: TextStyle(color: _muted, fontSize: 15, height: 1.6),
                          ),
                          const SizedBox(height: 18),
                          Wrap(spacing: 10, runSpacing: 10, children: const [
                            Chip(label: Text('Property + parcel intelligence')),
                            Chip(label: Text('Claims / risk / weather')),
                            Chip(label: Text('Imagery + Digital Twin')),
                            Chip(label: Text('Portfolio / workflows / AI')),
                            Chip(label: Text('APIs + integrations')),
                          ]),
                          const SizedBox(height: 22),
                          _panel('Live system readiness', at(0), Icons.monitor_heart_outlined),
                        ] else if (_tab == 1) ...[
                          const Text('Public Data Desk', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          const Text(
                            'Registration-free, aggregate-only public information. This surface intentionally excludes property addresses, customer data and proprietary scoring weights.',
                            style: TextStyle(color: _muted, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          _panel('System / dataset readiness', at(0), Icons.dataset_outlined),
                          const SizedBox(height: 10),
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Public-data disclosure: BridgePoint “verified opportunity” language refers to a prioritization/review layer, not confirmed damage, a claim, an inspection finding or guaranteed customer intent.',
                                style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
                              ),
                            ),
                          ),
                        ] else if (_tab == 2) ...[
                          const Text('Expansion readiness', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          const Text('LIVE and BUILDING are different states. BridgePoint does not invent countdowns or market readiness.', style: TextStyle(color: _muted)),
                          const SizedBox(height: 12),
                          _panel('Markets / bundles', at(1), Icons.public_rounded),
                        ] else ...[
                          const Text('Capability directory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          const Text('Public-safe capability descriptions only. Internal automation and proprietary model mechanics stay private.', style: TextStyle(color: _muted)),
                          const SizedBox(height: 12),
                          _panel('BridgePoint capabilities', at(2), Icons.extension_outlined),
                        ],
                      ]),
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

class _PublicRow extends StatelessWidget {
  const _PublicRow(this.value);
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const Text('No public aggregate data returned.', style: TextStyle(color: Color(0xFF8FA5BF)));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF081625),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x2235D2E8)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: value.entries.take(28).map((e) {
          final raw = '${e.value}';
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Text('${e.key.replaceAll('_', ' ')}: ${raw.length > 280 ? '${raw.substring(0, 280)}…' : raw}', style: const TextStyle(fontSize: 9, height: 1.35)),
          );
        }).toList(),
      ),
    );
  }
}
