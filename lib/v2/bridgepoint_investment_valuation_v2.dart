import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointInvestmentValuationV2 extends StatefulWidget {
  const BridgePointInvestmentValuationV2({super.key});

  @override
  State<BridgePointInvestmentValuationV2> createState() =>
      _BridgePointInvestmentValuationV2State();
}

class _BridgePointInvestmentValuationV2State
    extends State<BridgePointInvestmentValuationV2> {
  static const _panel = Color(0xFF0D1A2B);
  static const _soft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _red = Color(0xFFFF6B6B);
  static const _muted = Color(0xFF8FA5BF);

  late Future<dynamic> _request;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _request = _load();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => mounted ? setState(() => _request = _load()) : null,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<dynamic> _load() =>
      Supabase.instance.client.rpc('bridgepoint_owner_investor_room_v314');

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  int _int(dynamic value) => _double(value).round();

  String _money(dynamic value, {bool compact = false}) {
    final n = _double(value);
    if (compact) {
      if (n.abs() >= 1000000000) {
        return '\$${(n / 1000000000).toStringAsFixed(2)}B';
      }
      if (n.abs() >= 1000000) {
        return '\$${(n / 1000000).toStringAsFixed(2)}M';
      }
      if (n.abs() >= 1000) {
        return '\$${(n / 1000).toStringAsFixed(1)}K';
      }
    }
    final s = n.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}\$${b.toString()}';
  }

  String _number(dynamic value) {
    final n = _int(value);
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}${b.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Valuation room unavailable: ${snapshot.error}'),
            ),
          );
        }

        final room = _map(snapshot.data);
        final valuation = _map(room['valuation']);
        final metrics = _map(room['metrics']);
        final headline = _map(metrics['headline']);
        final geo = _map(metrics['geographic_scale']);
        final commercialization = _map(metrics['commercialization']);
        final operating = _map(metrics['operating_system']);
        final history = _rows(valuation['history']);
        final drivers = _rows(valuation['drivers']);
        final benchmarks = _rows(valuation['benchmark_context']);

        final current = _double(valuation['modeled_pre_money_usd']);
        final low = _double(valuation['low_usd']);
        final high = _double(valuation['high_usd']);
        final highWater = _double(valuation['milestone_high_water_usd']);
        final confidence = _double(valuation['confidence_score']);
        final first = history.isNotEmpty
            ? _double(history.first['modeled_pre_money_usd'])
            : current;
        final last = history.isNotEmpty
            ? _double(history.last['modeled_pre_money_usd'])
            : current;
        final delta = last - first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_panel, _cyan.withValues(alpha: .09)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cyan.withValues(alpha: .18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          color: _cyan,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BridgePoint Investment / Valuation',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Owner-only live modeled company value. The number updates from BridgePoint operating scale, coverage, product maturity, commercialization and platform signals.',
                              style: TextStyle(color: _muted, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => setState(() => _request = _load()),
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh valuation',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MODELED PRE-MONEY VALUE',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _money(current, compact: true),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill('LOW ${_money(low, compact: true)}', _blue),
                      _Pill('HIGH ${_money(high, compact: true)}', _green),
                      _Pill('CONFIDENCE ${confidence.toStringAsFixed(0)}/100', _cyan),
                      _Pill('HIGH-WATER ${_money(highWater, compact: true)}', _amber),
                      _Pill(
                        '${delta >= 0 ? '+' : ''}${_money(delta, compact: true)} WINDOW',
                        delta >= 0 ? _green : _red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth >= 1050 ? 4 : c.maxWidth >= 650 ? 2 : 1;
                final width = (c.maxWidth - (columns - 1) * 10) / columns;
                final cards = [
                  _Metric(
                    'ACTIVE PROPERTIES',
                    _number(headline['active_properties']),
                    'Live property foundation',
                    Icons.home_work_rounded,
                    _cyan,
                  ),
                  _Metric(
                    'REGISTERED SOURCES',
                    _number(headline['registered_sources']),
                    '${_number(headline['healthy_sources'])} healthy',
                    Icons.hub_rounded,
                    _green,
                  ),
                  _Metric(
                    'ACTIVE OPPORTUNITIES',
                    _number(headline['active_opportunities']),
                    'Current opportunity engine',
                    Icons.track_changes_rounded,
                    _amber,
                  ),
                  _Metric(
                    'DIGITAL TWINS',
                    _number(headline['digital_twins']),
                    'Physical intelligence asset',
                    Icons.view_in_ar_rounded,
                    _blue,
                  ),
                  _Metric(
                    'US JURISDICTIONS',
                    _number(geo['us_jurisdictions']),
                    '${_number(geo['us_live'])} live • ${_number(geo['us_scoring'])} scoring',
                    Icons.public_rounded,
                    _cyan,
                  ),
                  _Metric(
                    'EXPORT READY',
                    _number(geo['export_ready']),
                    'Jurisdictions ready for export',
                    Icons.file_download_done_rounded,
                    _green,
                  ),
                  _Metric(
                    'PAYING CUSTOMERS',
                    _number(commercialization['paying_customers']),
                    '${_money(commercialization['mrr_usd'])} MRR',
                    Icons.payments_outlined,
                    _amber,
                  ),
                  _Metric(
                    'AUTONOMOUS CONTROL',
                    operating['single_active_conductor'] == true ? 'ACTIVE' : 'CHECK',
                    'Owner operating-system control',
                    Icons.memory_rounded,
                    _blue,
                  ),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final card in cards)
                      SizedBox(width: width, child: card),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 920;
                final trend = _Section(
                  title: 'Automatic valuation history',
                  subtitle: 'Stored hourly snapshots from the live model',
                  icon: Icons.timeline_rounded,
                  child: SizedBox(
                    height: 230,
                    child: CustomPaint(
                      painter: _ValuationTrendPainter(
                        rows: history,
                        low: low,
                        high: high,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
                final driver = _Section(
                  title: 'What is moving the value',
                  subtitle: 'Live model drivers and milestone context',
                  icon: Icons.tune_rounded,
                  child: drivers.isEmpty
                      ? const Text(
                          'No driver rows returned.',
                          style: TextStyle(color: _muted),
                        )
                      : Column(
                          children: [
                            for (final row in drivers.take(12))
                              _DriverRow(row: row),
                          ],
                        ),
                );
                if (stacked) {
                  return Column(
                    children: [trend, const SizedBox(height: 12), driver],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: trend),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: driver),
                  ],
                );
              },
            ),
            if (benchmarks.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Section(
                title: 'Benchmark context',
                subtitle:
                    'Internal planning context only — not an appraisal, offer or financing commitment',
                icon: Icons.compare_arrows_rounded,
                child: Column(
                  children: [
                    for (final row in benchmarks.take(10))
                      _BenchmarkRow(row: row),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Valuation truth rule: this is BridgePoint’s internal modeled pre-money planning range, calculated from current operating metrics and milestone logic. It is not an audited appraisal, investor offer, financing commitment, or guaranteed transaction value.',
              style: TextStyle(color: _muted, fontSize: 9.5, height: 1.45),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail, this.icon, this.color);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BridgePointInvestmentValuationV2State._panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: _BridgePointInvestmentValuationV2State._muted,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _BridgePointInvestmentValuationV2State._muted,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _BridgePointInvestmentValuationV2State._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _BridgePointInvestmentValuationV2State._cyan),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _BridgePointInvestmentValuationV2State._muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final factor = '${row['factor'] ?? 'driver'}'.replaceAll('_', ' ');
    final impact = '${row['impact'] ?? row['status'] ?? ''}'.replaceAll('_', ' ');
    final detail = '${row['detail'] ?? row['reason'] ?? row['value'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _BridgePointInvestmentValuationV2State._soft.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 17,
            color: _BridgePointInvestmentValuationV2State._cyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: _BridgePointInvestmentValuationV2State._muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (impact.isNotEmpty)
            Text(
              impact.toUpperCase(),
              style: const TextStyle(
                color: _BridgePointInvestmentValuationV2State._green,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _BenchmarkRow extends StatelessWidget {
  const _BenchmarkRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _BridgePointInvestmentValuationV2State._soft.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 5,
          children: row.entries
              .take(12)
              .map(
                (e) => Text(
                  '${e.key.replaceAll('_', ' ')}: ${e.value}',
                  style: const TextStyle(fontSize: 9.5),
                ),
              )
              .toList(),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _ValuationTrendPainter extends CustomPainter {
  _ValuationTrendPainter({required this.rows, required this.low, required this.high});
  final List<Map<String, dynamic>> rows;
  final double low;
  final double high;

  @override
  void paint(Canvas canvas, Size size) {
    final values = rows
        .map((row) {
          final value = row['modeled_pre_money_usd'];
          if (value is num) return value.toDouble();
          return double.tryParse('${value ?? ''}');
        })
        .whereType<double>()
        .toList();
    if (values.length < 2) return;

    final minV = math.min(low > 0 ? low : values.reduce(math.min), values.reduce(math.min));
    final maxV = math.max(high > 0 ? high : values.reduce(math.max), values.reduce(math.max));
    final span = math.max(1.0, maxV - minV);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Paint()
      ..color = _BridgePointInvestmentValuationV2State._cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..color = _BridgePointInvestmentValuationV2State._cyan.withValues(alpha: .14)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final normalized = (values[i] - minV) / span;
      final y = size.height - normalized * (size.height - 18) - 9;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _ValuationTrendPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.low != low || oldDelegate.high != high;
}
