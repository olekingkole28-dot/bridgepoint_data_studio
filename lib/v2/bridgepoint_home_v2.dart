import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BridgePointHomeV2 extends StatefulWidget {
  const BridgePointHomeV2({super.key});

  @override
  State<BridgePointHomeV2> createState() => _BridgePointHomeV2State();
}

class _BridgePointHomeV2State extends State<BridgePointHomeV2> {
  static const _navy = Color(0xFF07111F);
  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  static const _packageModelKeys = <String, String>{
    'All Intelligence': 'all',
    'BridgePoint Home': 'bridgepoint_home',
    'BridgePoint Commercial': 'bridgepoint_commercial',
    'Roofing Opportunity': 'roofing_opportunity',
    'BridgePoint General': 'bridgepoint_general_v1',
    'Property Investor': 'property_investor',
    'Development Opportunity': 'development_opportunity',
    'Solar Opportunity': 'solar_opportunity',
  };

  late Future<List<dynamic>> _request;
  String _selectedPackage = 'All Intelligence';
  bool _owner = false;

  @override
  void initState() {
    super.initState();
    _request = _load();
    _checkOwner();
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (e) {
      return {'available': false, 'rpc': name, 'error': '$e'};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_dashboard', {
          'p_model_key': _packageModelKeys[_selectedPackage] ?? 'all',
          'p_limit': 10,
        }),
        _safe('bridgepoint_flutter_sources'),
        _safe('bridgepoint_daily_brief_v74'),
        _safe('bridgepoint_user_market_context_v320'),
        _safe('bridgepoint_field_note_of_day_v81'),
        _safe('bridgepoint_notifications_v74', {'p_limit': 20}),
        _safe('bridgepoint_source_health_v86'),
      ]);

  Future<void> _checkOwner() async {
    try {
      await Supabase.instance.client.rpc(
        'bridgepoint_owner_v2_requirements_v832',
        params: {'p_category': null, 'p_status': null, 'p_limit': 1},
      );
      _owner = true;
    } catch (_) {
      _owner = false;
    }
    if (mounted) setState(() {});
  }

  void _refresh() => setState(() => _request = _load());

  void _changePackage(String? value) {
    if (value == null || value == _selectedPackage) return;
    setState(() {
      _selectedPackage = value;
      _request = _load();
    });
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
      for (final key in const ['items', 'results', 'rows', 'sources', 'notifications']) {
        final nested = value[key];
        if (nested is List) return _rows(nested);
      }
    }
    return const [];
  }

  String _summary(dynamic value) {
    final map = _map(value);
    for (final key in const [
      'summary',
      'headline',
      'message',
      'status',
      'condition',
      'state_code',
      'note',
      'quote',
    ]) {
      final v = map[key];
      if (v != null && '$v'.trim().isNotEmpty) return '$v';
    }
    if (map['items'] is List && (map['items'] as List).isNotEmpty) {
      return '${(map['items'] as List).first}';
    }
    if (map.isEmpty) return 'No current response.';
    final first = map.entries.first;
    final text = '${first.value}';
    return text.length > 260 ? '${text.substring(0, 260)}…' : text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    final cleaned = '$value'.replaceAll(',', '').trim();
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatInt(dynamic value) {
    final number = _int(value);
    if (number <= 0) return '—';
    final s = number.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  dynamic _firstKey(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map[key] != null) return map[key];
    }
    return null;
  }

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const [];
        dynamic at(int i) => i < data.length ? data[i] : const <String, dynamic>{};
        final dashboard = _map(at(0));
        final sources = at(1);
        final brief = at(2);
        final market = at(3);
        final fieldNote = at(4);
        final notifications = at(5);
        final sourceHealth = at(6);

        final opportunityRaw = dashboard['ranked_opportunities'];
        final opportunities = opportunityRaw is List
            ? opportunityRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(
              selectedPackage: _selectedPackage,
              packages: _packageModelKeys.keys.toList(),
              onPackageChanged: _changePackage,
              onRefresh: _refresh,
              loading: snapshot.connectionState == ConnectionState.waiting,
              owner: _owner,
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(999)),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 10),
              Text('${snapshot.error}', style: const TextStyle(color: _red)),
            ],
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 1120 ? 4 : c.maxWidth >= 650 ? 2 : 1;
                final cardWidth = (c.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: const _MetricCard(
                        label: 'CT PROPERTIES',
                        value: '1,282,833',
                        detail: 'Canonical statewide CAMA / parcel inventory',
                        icon: Icons.home_work_outlined,
                        accent: _cyan,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'ACTIVE OPPORTUNITIES',
                        value: _formatInt(_firstKey(dashboard, const ['active_opportunities', 'opportunity_count'])),
                        detail: '${opportunities.length} ranked properties loaded now',
                        icon: Icons.track_changes_rounded,
                        accent: _green,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'INTELLIGENCE SOURCES',
                        value: _formatInt(_firstKey(dashboard, const ['connected_source_families', 'source_count'])),
                        detail: 'Property • storm • fire • FEMA • permits • transitions',
                        icon: Icons.hub_outlined,
                        accent: _blue,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'AUTOMATION',
                        value: snapshot.connectionState == ConnectionState.waiting ? 'SYNCING' : 'ACTIVE',
                        detail: 'Live ingestion, matching, scoring and opportunity refresh',
                        icon: Icons.sync_rounded,
                        accent: _amber,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 940;
                final left = _OpportunityPanel(opportunities: opportunities);
                final right = _LiveBriefPanel(
                  brief: brief,
                  market: market,
                  notifications: notifications,
                );
                if (stacked) {
                  return Column(children: [left, const SizedBox(height: 14), right]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: right),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 900;
                final source = _SourcePanel(sources: sources, sourceHealth: sourceHealth);
                final note = _FounderNote(text: _summary(fieldNote), owner: _owner);
                if (stacked) {
                  return Column(children: [source, const SizedBox(height: 14), note]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: source),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: note),
                  ],
                );
              },
            ),
            if (_owner) ...[
              const SizedBox(height: 14),
              _FounderProfile(
                onWebsite: () => _open(Uri.parse('https://bridgepointintelligence.online')),
                onEmail: () => _open(Uri.parse('mailto:bridgepointintelligence@gmail.com')),
                onPhone: () => _open(Uri.parse('tel:2036052389')),
              ),
            ],
            const SizedBox(height: 14),
            const _TruthRule(),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.selectedPackage,
    required this.packages,
    required this.onPackageChanged,
    required this.onRefresh,
    required this.loading,
    required this.owner,
  });

  final String selectedPackage;
  final List<String> packages;
  final ValueChanged<String?> onPackageChanged;
  final VoidCallback onRefresh;
  final bool loading;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 620;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bridgepoint-intelligence-background-v1.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: _BridgePointHomeV2State._panel),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _BridgePointHomeV2State._navy.withValues(alpha: .96),
                    const Color(0xFF071321).withValues(alpha: .82),
                    _BridgePointHomeV2State._blue.withValues(alpha: .20),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(phone ? 18 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const _BrandMark(),
                    const _LivePill(),
                    if (owner) const _MiniPill(icon: Icons.admin_panel_settings_rounded, label: 'OWNER ACCESS'),
                  ],
                ),
                SizedBox(height: phone ? 26 : 38),
                Text(
                  'See the property before the visit.',
                  style: TextStyle(
                    fontSize: phone ? 30 : 43,
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 10),
                const ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 820),
                  child: Text(
                    'One property story from parcel records, public data, weather, permits, risk, ownership change, physical intelligence and BridgePoint scoring—without hiding the evidence or uncertainty.',
                    style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 14, height: 1.55),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: phone ? 360 : 300),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPackage,
                        dropdownColor: _BridgePointHomeV2State._panelSoft,
                        decoration: const InputDecoration(
                          labelText: 'Intelligence view',
                          prefixIcon: Icon(Icons.layers_rounded),
                          isDense: true,
                        ),
                        items: packages
                            .map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: onPackageChanged,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: loading ? null : onRefresh,
                      icon: loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh intelligence'),
                    ),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_BridgePointHomeV2State._cyan, _BridgePointHomeV2State._blue],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: _BridgePointHomeV2State._cyan.withValues(alpha: .20),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.polyline_rounded, color: Colors.white),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BRIDGEPOINT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            Text(
              'INTELLIGENCE',
              style: TextStyle(color: _BridgePointHomeV2State._cyan, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.0),
            ),
          ],
        ),
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) => const _MiniPill(icon: Icons.circle, label: 'LIVE INTELLIGENCE', color: _BridgePointHomeV2State._green);
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.icon, required this.label, this.color = _BridgePointHomeV2State._cyan});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail, required this.icon, required this.accent});
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BridgePointHomeV2State._panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(height: 15),
          Text(label, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.05)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11, height: 1.35)),
        ],
      ),
    );
  }
}

class _OpportunityPanel extends StatelessWidget {
  const _OpportunityPanel({required this.opportunities});
  final List<Map<String, dynamic>> opportunities;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ranked opportunities',
      subtitle: 'Highest-value properties from the active BridgePoint view',
      icon: Icons.leaderboard_rounded,
      child: opportunities.isEmpty
          ? const _EmptyState(icon: Icons.radar_rounded, text: 'No ranked opportunity rows returned for this view yet.')
          : Column(
              children: [
                for (final entry in opportunities.take(6).toList().asMap().entries)
                  Padding(
                    padding: EdgeInsets.only(bottom: entry.key == opportunities.take(6).length - 1 ? 0 : 9),
                    child: _OpportunityRow(rank: entry.key + 1, row: entry.value),
                  ),
              ],
            ),
    );
  }
}

class _OpportunityRow extends StatelessWidget {
  const _OpportunityRow({required this.rank, required this.row});
  final int rank;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final priority = '${row['priority'] ?? row['priority_band'] ?? 'monitor'}'.replaceAll('_', ' ');
    final score = row['score'] ?? row['opportunity_score'] ?? '—';
    final address = '${row['full_address'] ?? row['address'] ?? 'Address unavailable'}';
    final signal = '${row['top_signal_type'] ?? row['why_now'] ?? row['top_signal'] ?? 'intelligence signal'}'.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _BridgePointHomeV2State._panelSoft.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _BridgePointHomeV2State._cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Text('$rank', style: const TextStyle(color: _BridgePointHomeV2State._cyan, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(signal, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score', style: const TextStyle(color: _BridgePointHomeV2State._cyan, fontWeight: FontWeight.w900)),
              Text(priority.toUpperCase(), style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 8, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveBriefPanel extends StatelessWidget {
  const _LiveBriefPanel({required this.brief, required this.market, required this.notifications});
  final dynamic brief;
  final dynamic market;
  final dynamic notifications;

  String _text(dynamic value) {
    if (value is Map) {
      for (final key in const ['headline', 'summary', 'message', 'status', 'state_code']) {
        if (value[key] != null && '${value[key]}'.trim().isNotEmpty) return '${value[key]}';
      }
      if (value.isNotEmpty) return '${value.entries.first.value}';
    }
    if (value is List && value.isNotEmpty) return '${value.first}';
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Daily Brief',
      subtitle: 'What changed, what matters, and what deserves a look',
      icon: Icons.auto_graph_rounded,
      child: Column(
        children: [
          _BriefItem(icon: Icons.bolt_rounded, label: 'INTELLIGENCE', text: _text(brief), accent: _BridgePointHomeV2State._cyan),
          const SizedBox(height: 9),
          _BriefItem(icon: Icons.location_on_outlined, label: 'YOUR MARKET', text: _text(market), accent: _BridgePointHomeV2State._blue),
          const SizedBox(height: 9),
          _BriefItem(icon: Icons.notifications_active_outlined, label: 'NOTIFICATIONS', text: _text(notifications), accent: _BridgePointHomeV2State._amber),
        ],
      ),
    );
  }
}

class _BriefItem extends StatelessWidget {
  const _BriefItem({required this.icon, required this.label, required this.text, required this.accent});
  final IconData icon;
  final String label;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _BridgePointHomeV2State._panelSoft.withValues(alpha: .65), borderRadius: BorderRadius.circular(13)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                  const SizedBox(height: 4),
                  Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({required this.sources, required this.sourceHealth});
  final dynamic sources;
  final dynamic sourceHealth;

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) {
      for (final key in const ['items', 'sources', 'results']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows(sources);
    return _SectionCard(
      title: 'Intelligence coverage',
      subtitle: 'The evidence families feeding property-level decisions',
      icon: Icons.hub_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SourceChip('PARCEL / CAMA', _BridgePointHomeV2State._cyan),
              _SourceChip('STORM / WEATHER', _BridgePointHomeV2State._blue),
              _SourceChip('FIRE / INCIDENTS', _BridgePointHomeV2State._red),
              _SourceChip('FEMA / FLOOD', _BridgePointHomeV2State._amber),
              _SourceChip('PERMITS / 311', _BridgePointHomeV2State._green),
              _SourceChip('OWNERSHIP / SALES', _BridgePointHomeV2State._cyan),
              _SourceChip('IMAGERY / PHYSICAL CHANGE', _BridgePointHomeV2State._blue),
              _SourceChip('ENVIRONMENTAL / UST / SPILLS', _BridgePointHomeV2State._green),
            ],
          ),
          const SizedBox(height: 14),
          if (rows.isNotEmpty)
            Text('${rows.length} source rows returned by the live source registry.', style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11))
          else
            const Text('Live source registry connected. Open Intelligence Studio for deeper source-level status.', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11)),
          const SizedBox(height: 6),
          Text('Source health: ${sourceHealth is Map ? sourceHealth['status'] ?? sourceHealth['summary'] ?? 'connected' : 'connected'}', style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(9), border: Border.all(color: color.withValues(alpha: .18))),
        child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .55)),
      );
}

class _FounderNote extends StatelessWidget {
  const _FounderNote({required this.text, required this.owner});
  final String text;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16170F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BridgePointHomeV2State._amber.withValues(alpha: .25)),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.push_pin_rounded, color: _BridgePointHomeV2State._amber),
              SizedBox(width: 8),
              Text('FIELD NOTE / DAILY REMINDER', style: TextStyle(color: _BridgePointHomeV2State._amber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
            ],
          ),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.5)),
          const SizedBox(height: 16),
          Text(owner ? 'Kole Johnson  •  Founder' : 'BridgePoint Intelligence', style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FounderProfile extends StatelessWidget {
  const _FounderProfile({required this.onWebsite, required this.onEmail, required this.onPhone});
  final VoidCallback onWebsite;
  final VoidCallback onEmail;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_BridgePointHomeV2State._panel, _BridgePointHomeV2State._blue.withValues(alpha: .14)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BridgePointHomeV2State._cyan.withValues(alpha: .18)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 760;
          final identity = const Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _BridgePointHomeV2State._blue,
                child: Icon(Icons.person_rounded, color: Colors.white, size: 30),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kole Johnson', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Founder • BridgePoint Intelligence', style: TextStyle(color: _BridgePointHomeV2State._cyan, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Connecticut-built property intelligence platform • Owner no-charge All Intelligence demo access', style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11, height: 1.35)),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: onWebsite, icon: const Icon(Icons.language_rounded), label: const Text('Website')),
              OutlinedButton.icon(onPressed: onEmail, icon: const Icon(Icons.mail_outline_rounded), label: const Text('Email')),
              OutlinedButton.icon(onPressed: onPhone, icon: const Icon(Icons.phone_outlined), label: const Text('Support')),
            ],
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 14), actions]);
          return Row(children: [Expanded(child: identity), const SizedBox(width: 20), actions]);
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.icon, required this.child});
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: _BridgePointHomeV2State._cyan.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: _BridgePointHomeV2State._cyan, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _BridgePointHomeV2State._panelSoft.withValues(alpha: .55), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: _BridgePointHomeV2State._cyan, size: 28),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 11)),
          ],
        ),
      );
}

class _TruthRule extends StatelessWidget {
  const _TruthRule();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _BridgePointHomeV2State._navy,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: _BridgePointHomeV2State._green, size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'BridgePoint truth rule: preserve provenance, dates, match confidence and uncertainty. Scores and signals prioritize human review; they do not become confirmed property condition, damage, coverage or claim findings merely because a model is confident.',
                style: TextStyle(color: _BridgePointHomeV2State._muted, fontSize: 10, height: 1.45),
              ),
            ),
          ],
        ),
      );
}
