import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointPortfolioRiskV2 extends StatefulWidget {
  const BridgePointPortfolioRiskV2({super.key});

  @override
  State<BridgePointPortfolioRiskV2> createState() =>
      _BridgePointPortfolioRiskV2State();
}

class _BridgePointPortfolioRiskV2State
    extends State<BridgePointPortfolioRiskV2> {
  late Future<Map<String, dynamic>> _watchlists;
  String? _selectedWatchlist;
  Map<String, dynamic> _portfolio = const {};
  Map<String, dynamic> _climate = const {};
  Map<String, dynamic> _outcomes = const {};
  bool _busy = false;
  String? _message;

  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF7E7E);
  static const _muted = Color(0xFFB5C6D9);

  @override
  void initState() {
    super.initState();
    _watchlists = _loadWatchlists();
    _loadOutcomes();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return <String, dynamic>{'items': value};
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in const [
        'watchlists',
        'items',
        'results',
        'properties',
        'portfolio',
        'outcomes',
      ]) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  num? _number(dynamic value) {
    if (value is num) return value;
    return num.tryParse('${value ?? ''}');
  }

  String _compact(dynamic value) {
    final n = _number(value);
    if (n == null) return '—';
    final d = n.toDouble();
    if (d.abs() >= 1000000000) {
      return '${(d / 1000000000).toStringAsFixed(1)}B';
    }
    if (d.abs() >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
    if (d.abs() >= 1000) return '${(d / 1000).toStringAsFixed(1)}K';
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }

  String _money(dynamic value) {
    final n = _number(value);
    if (n == null) return '\$0';
    final d = n.toDouble();
    if (d.abs() >= 1000000) return '\$${(d / 1000000).toStringAsFixed(1)}M';
    if (d.abs() >= 1000) return '\$${(d / 1000).toStringAsFixed(1)}K';
    return '\$${d.toStringAsFixed(0)}';
  }

  Future<dynamic> _safe(String name, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(name, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<Map<String, dynamic>> _loadWatchlists() async =>
      _map(await _safe('bridgepoint_watchlists_v88'));

  Future<void> _loadOutcomes() async {
    final raw = await _safe('bridgepoint_outcome_funnel_v86', {'p_days': 90});
    if (mounted) setState(() => _outcomes = _map(raw));
  }

  List<Map<String, dynamic>> _climateScores(Map<String, dynamic> portfolio) {
    final scores = <Map<String, dynamic>>[];
    for (final row in _rows(portfolio['items'])) {
      final top = _map(row['top_score']);
      final score = _number(top['final_score'] ?? top['score']);
      if (score != null) scores.add(<String, dynamic>{'score': score});
    }
    return scores;
  }

  Future<void> _loadPortfolio(String watchlistId) async {
    setState(() {
      _busy = true;
      _message = null;
      _selectedWatchlist = watchlistId;
      _portfolio = const {};
      _climate = const {};
    });
    try {
      final portfolio = _map(await _safe(
        'bridgepoint_portfolio_intelligence_v460',
        <String, dynamic>{'p_watchlist_id': watchlistId, 'p_limit': 100},
      ));
      final climateScores = _climateScores(portfolio);
      Map<String, dynamic> climate = const {};
      if (climateScores.isNotEmpty) {
        climate = _map(await _safe(
          'bridgepoint_portfolio_climate_summary_v509',
          <String, dynamic>{
            'p_scores': climateScores,
            'p_horizon_year': 2050,
            'p_scenario_key': 'CMRA_MULTI_HAZARD',
          },
        ));
      }
      if (!mounted) return;
      setState(() {
        _portfolio = portfolio;
        _climate = climate;
        if (portfolio['locked'] == true) {
          _message = 'This portfolio needs Property Profiles access.';
        } else if (portfolio['available'] == false) {
          _message = 'Portfolio intelligence is temporarily unavailable.';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    Color color = _cyan,
    String? hint,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 230),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1B2C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: _muted, fontSize: 12.5)),
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(hint, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String subtitle, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 13),
            child,
          ],
        ),
      ),
    );
  }

  Widget _portfolioSummary() {
    if (_portfolio.isEmpty) {
      return const Text('Choose a watchlist to load portfolio intelligence.',
          style: TextStyle(color: _muted));
    }
    if (_portfolio['locked'] == true) {
      return const Text('Property Profiles access is required for this portfolio.',
          style: TextStyle(color: _amber));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metric('Properties analyzed', _compact(_portfolio['portfolio_size_returned']),
            Icons.home_work_outlined),
        _metric('States represented', _compact(_portfolio['state_count']),
            Icons.public_rounded),
        _metric(
          'With verified opportunities',
          _compact(_portfolio['properties_with_verified_opportunities']),
          Icons.verified_rounded,
          color: _green,
        ),
        _metric('Signals across portfolio', _compact(_portfolio['signal_count_total']),
            Icons.radar_rounded),
        _metric('Average top score', _compact(_portfolio['average_top_score']),
            Icons.insights_rounded,
            color: _amber),
        _metric('Highest top score', _compact(_portfolio['max_top_score']),
            Icons.trending_up_rounded,
            color: _red),
      ],
    );
  }

  Widget _climateSummary() {
    if (_climate.isEmpty) {
      return const Text(
        'Climate rollup appears after the selected portfolio has valid scored properties.',
        style: TextStyle(color: _muted),
      );
    }
    if ('${_climate['status'] ?? ''}' != 'OK') {
      return const Text('No valid climate scores are available for this portfolio yet.',
          style: TextStyle(color: _muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metric('Properties scored', _compact(_climate['property_count']),
                Icons.location_city_rounded),
            _metric('Average risk', _compact(_climate['average_risk_score']),
                Icons.thermostat_rounded,
                color: _amber),
            _metric('90th percentile risk', _compact(_climate['p90_risk_score']),
                Icons.show_chart_rounded,
                color: _red),
            _metric('High or worse', _compact(_climate['high_or_worse_count']),
                Icons.warning_amber_rounded,
                color: _amber),
            _metric('Very high', _compact(_climate['very_high_count']),
                Icons.crisis_alert_rounded,
                color: _red),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${_climate['scenario_key'] ?? 'CMRA_MULTI_HAZARD'} • horizon ${_climate['horizon_year'] ?? 2050}',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _outcomeSummary() {
    final totals = _map(_outcomes['totals']);
    if (totals.isEmpty) {
      return const Text('No outcome-learning activity is available for the last 90 days.',
          style: TextStyle(color: _muted));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metric('Recorded outcomes', _compact(totals['recorded']),
            Icons.fact_check_outlined),
        _metric('Conversions', _compact(totals['conversions']), Icons.handshake_outlined,
            color: _green),
        _metric('Positive outcomes', _compact(totals['positive']),
            Icons.thumb_up_alt_outlined,
            color: _green),
        _metric('Revenue attributed', _money(totals['revenue']), Icons.payments_outlined,
            color: _green),
        _metric('Contract value', _money(totals['contract_value']),
            Icons.receipt_long_outlined),
        _metric('Profit attributed', _money(totals['profit']), Icons.savings_outlined,
            color: _green),
      ],
    );
  }

  Widget _propertyList() {
    final items = _rows(_portfolio['items']);
    if (items.isEmpty) return const SizedBox.shrink();
    final ranked = [...items];
    ranked.sort((a, b) {
      final ascore = _number(_map(a['top_score'])['final_score']) ?? -1;
      final bscore = _number(_map(b['top_score'])['final_score']) ?? -1;
      return bscore.compareTo(ascore);
    });
    return _section(
      'Highest-ranked properties',
      'The strongest properties in this saved set, ordered by the current top intelligence score.',
      Column(
        children: ranked.take(20).map((row) {
          final property = _map(row['property']);
          final topScore = _map(row['top_score']);
          final address =
              '${property['full_address'] ?? property['address'] ?? property['property_address'] ?? 'Property'}';
          final municipality = '${property['municipality'] ?? ''}';
          final state = '${row['state_code'] ?? property['state_code'] ?? ''}';
          final score = _compact(topScore['final_score'] ?? topScore['score']);
          final signals = _compact(row['signal_count']);
          final opportunities = _compact(row['verified_opportunity_count']);
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: _cyan.withValues(alpha: .12),
              child: const Icon(Icons.location_on_outlined, color: _cyan, size: 19),
            ),
            title: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [municipality, state].where((e) => e.trim().isNotEmpty).join(', '),
              style: const TextStyle(color: _muted),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Score $score',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('$signals signals • $opportunities opps',
                    style: const TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _watchlists,
      builder: (context, snapshot) {
        final rows = _rows(snapshot.data ?? const {});
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Portfolio & Risk',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                        SizedBox(height: 5),
                        Text(
                          'Saved-property intelligence, concentration, climate exposure and measured outcomes in one portfolio view.',
                          style: TextStyle(color: _muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh portfolios',
                    onPressed: () {
                      setState(() {
                        _watchlists = _loadWatchlists();
                        _loadOutcomes();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, color: _cyan),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(color: _cyan),
              if (_busy) const LinearProgressIndicator(color: _cyan),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!, style: const TextStyle(color: _amber)),
              ],
              if (rows.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No saved portfolios are available yet. Save properties to a watchlist to build a portfolio view.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: rows.map((row) {
                    final id = '${row['watchlist_id'] ?? row['id'] ?? ''}';
                    final count = _compact(row['item_count']);
                    final name = '${row['name'] ?? row['label'] ?? 'Portfolio'}';
                    return ChoiceChip(
                      selected: id.isNotEmpty && id == _selectedWatchlist,
                      label: Text('$name • $count'),
                      onSelected: id.isEmpty ? null : (_) => _loadPortfolio(id),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              _section(
                'Portfolio intelligence',
                'Entitlement-safe property, signal and verified-opportunity rollup.',
                _portfolioSummary(),
              ),
              const SizedBox(height: 12),
              _section(
                'Climate & peril exposure',
                '2050 CMRA multi-hazard screening rollup from the selected portfolio’s real property scores.',
                _climateSummary(),
              ),
              const SizedBox(height: 12),
              _section(
                'Outcome learning — last 90 days',
                'Measured customer outcomes tied back to BridgePoint activity.',
                _outcomeSummary(),
              ),
              const SizedBox(height: 12),
              _propertyList(),
              const SizedBox(height: 10),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Climate scores are scenario-conditioned screening estimates, not guarantees. BridgePoint preserves the scenario, horizon and property-level evidence instead of presenting modeled risk as observed fact.',
                    style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
