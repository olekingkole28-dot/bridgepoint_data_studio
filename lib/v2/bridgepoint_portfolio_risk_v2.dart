import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointPortfolioRiskV2 extends StatefulWidget {
  const BridgePointPortfolioRiskV2({super.key});

  @override
  State<BridgePointPortfolioRiskV2> createState() => _BridgePointPortfolioRiskV2State();
}

class _BridgePointPortfolioRiskV2State extends State<BridgePointPortfolioRiskV2> {
  late Future<Map<String, dynamic>> _watchlists;
  String? _selectedWatchlist;
  Map<String, dynamic> _portfolio = const {};
  Map<String, dynamic> _climate = const {};
  Map<String, dynamic> _outcomes = const {};
  bool _busy = false;
  String? _error;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);

  @override
  void initState() {
    super.initState();
    _watchlists = _loadWatchlists();
    _loadOutcomes();
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
      for (final key in const ['watchlists', 'items', 'results', 'properties', 'portfolio']) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (e) {
      return {'available': false, 'rpc': name, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> _loadWatchlists() async =>
      _map(await _safe('bridgepoint_watchlists_v88'));

  Future<void> _loadOutcomes() async {
    final raw = await _safe('bridgepoint_outcome_funnel_v86', {'p_days': 90});
    if (mounted) setState(() => _outcomes = _map(raw));
  }

  Future<void> _loadPortfolio(String watchlistId) async {
    setState(() {
      _busy = true;
      _error = null;
      _selectedWatchlist = watchlistId;
      _portfolio = const {};
      _climate = const {};
    });
    try {
      final portfolioRaw = await _safe('bridgepoint_portfolio_intelligence_v460', {
        'p_watchlist_id': watchlistId,
        'p_limit': 500,
      });
      final portfolio = _map(portfolioRaw);
      final scores = portfolio['scores'] ?? portfolio['climate_scores'] ?? const [];
      final climateRaw = await _safe('bridgepoint_portfolio_climate_summary_v509', {
        'p_scores': scores,
        'p_horizon_year': 2050,
        'p_scenario_key': 'baseline',
      });
      if (!mounted) return;
      setState(() {
        _portfolio = portfolio;
        _climate = _map(climateRaw);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _panel(String title, Map<String, dynamic> value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: _cyan),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 10),
            if (value.isEmpty)
              const Text('Select a portfolio/watchlist to load this intelligence.', style: TextStyle(color: _muted))
            else
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: value.entries.take(45).map((e) {
                  final raw = '${e.value}';
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF081625),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0x2235D2E8)),
                      ),
                      child: Text(
                        '${e.key.replaceAll('_', ' ')}: ${raw.length > 300 ? '${raw.substring(0, 300)}…' : raw}',
                        style: const TextStyle(fontSize: 9, height: 1.35),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _watchlists,
      builder: (context, snapshot) {
        final rows = _rows(snapshot.data ?? const {});
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Portfolio & Risk', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text(
              'Portfolio/property graph intelligence, climate/peril exposure, concentration, next-best actions and outcome learning across saved property sets.',
              style: TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFF7E7E))),
            if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No watchlists/portfolios are currently available to this account.', style: TextStyle(color: _muted)),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rows.map((row) {
                  final id = '${row['watchlist_id'] ?? row['id'] ?? ''}';
                  final name = '${row['name'] ?? row['label'] ?? 'Portfolio'}';
                  return ChoiceChip(
                    selected: id.isNotEmpty && id == _selectedWatchlist,
                    label: Text(name),
                    onSelected: id.isEmpty ? null : (_) => _loadPortfolio(id),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth > 950;
              final width = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: width, child: _panel('Portfolio intelligence / graph', _portfolio, Icons.account_tree_outlined)),
                SizedBox(width: width, child: _panel('Climate / peril portfolio summary', _climate, Icons.climate_mini_split_rounded)),
                SizedBox(width: width, child: _panel('Outcome-learning funnel (90 days)', _outcomes, Icons.insights_rounded)),
              ]);
            }),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Risk estimates and scenarios must remain explainable and source-backed. Long-horizon climate projections are model scenarios, not guarantees. BridgePoint should show uncertainty, horizon, scenario, source date and evidence quality wherever a risk score is used.',
                  style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
