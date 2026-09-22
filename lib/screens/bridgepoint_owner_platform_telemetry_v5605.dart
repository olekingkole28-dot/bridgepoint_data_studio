import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointOwnerPlatformTelemetryV5605 extends StatefulWidget {
  const BridgePointOwnerPlatformTelemetryV5605({super.key});
  @override
  State<BridgePointOwnerPlatformTelemetryV5605> createState() =>
      _BridgePointOwnerPlatformTelemetryV5605State();
}

class _BridgePointOwnerPlatformTelemetryV5605State
    extends State<BridgePointOwnerPlatformTelemetryV5605> {
  static const bg = Color(0xFF08121F);
  static const panel = Color(0xFF0E1D2E);
  static const panel2 = Color(0xFF13283C);
  static const green = Color(0xFF45D69E);
  static const amber = Color(0xFFFFBD57);
  static const red = Color(0xFFFF6B74);
  static const cyan = Color(0xFF55DDF8);
  static const muted = Color(0xFF9EB1C4);

  String range = 'ALL';
  Future<Map<String, dynamic>>? request;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  DateTime? since() {
    if (range == '24H') return DateTime.now().subtract(const Duration(hours: 24));
    if (range == '7D') return DateTime.now().subtract(const Duration(days: 7));
    if (range == '30D') return DateTime.now().subtract(const Duration(days: 30));
    return null;
  }

  Future<Map<String, dynamic>> load() async {
    final raw = await Supabase.instance.client.rpc(
      'bridgepoint_owner_platform_telemetry_v5605',
      params: {'p_since': since()?.toUtc().toIso8601String()},
    );
    if (raw is! Map) throw const FormatException('Unexpected telemetry payload');
    return Map<String, dynamic>.from(raw);
  }

  void refresh() {
    if (!mounted) return;
    setState(() => request = load());
  }

  Map<String, dynamic> asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> asRows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  String fmt(dynamic value) {
    final n = value is num ? value : num.tryParse(value.toString());
    if (n == null) return '—';
    final whole = n.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    return out.toString();
  }

  Widget metric(String label, dynamic value,
      {Color color = Colors.white, String? sub}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: muted, fontSize: 10.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(value.toString(),
            style: TextStyle(
                color: color, fontSize: 25, fontWeight: FontWeight.w900)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: muted, fontSize: 9.5)),
        ],
      ]),
    );
  }

  Widget history(List<Map<String, dynamic>> daily) {
    if (daily.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Text('No telemetry in this range.', style: TextStyle(color: muted)),
      );
    }
    num maxProbe = 1;
    for (final row in daily) {
      final p = row['resilience_probes'] as num? ?? 0;
      if (p > maxProbe) maxProbe = p;
    }
    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: daily.map((row) {
          final probes = (row['resilience_probes'] as num? ?? 0).toDouble();
          final ok = (row['frontend_success'] as num? ?? 0).toDouble();
          final bad = (probes - ok).clamp(0, double.infinity);
          final totalH = probes == 0 ? 4.0 : 175.0 * probes / maxProbe;
          final okH = probes == 0 ? 0.0 : totalH * ok / probes;
          final badH = probes == 0 ? 0.0 : totalH * bad / probes;
          final day = (row['metric_day'] ?? '').toString();
          return Expanded(
            child: Tooltip(
              message: day + '\n' + fmt(probes) + ' checks\n' +
                  fmt(ok) + ' successful\n' + fmt(bad) + ' failed',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(height: okH, color: green),
                  Container(height: badH, color: red),
                  const SizedBox(height: 7),
                  if (daily.length <= 12 || daily.indexOf(row) % 5 == 0)
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(day.length >= 10 ? day.substring(5) : day,
                          style: const TextStyle(color: muted, fontSize: 8)),
                    )
                  else
                    const SizedBox(height: 34),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: FutureBuilder<Map<String, dynamic>>(
        future: request,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: cyan));
          }
          if (snapshot.hasError) {
            return Center(
              child: Card(
                color: panel,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, color: red),
                    const SizedBox(height: 8),
                    Text('Owner telemetry unavailable\n' + snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: refresh, child: const Text('Retry')),
                  ]),
                ),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final official = asMap(data['official_supabase']);
          final live = asMap(data['current_bridgepoint']);
          final daily = asRows(data['daily']);
          final generated =
              DateTime.tryParse((data['generated_at'] ?? '').toString())?.toLocal();

          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Traffic & Reliability',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text(
                            'Owner-only platform telemetry • Supabase history preserved • local-PC continuation ready for cutover',
                            style: TextStyle(color: muted, height: 1.4),
                          ),
                        ]),
                  ),
                  IconButton.filledTonal(
                      tooltip: 'Refresh',
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh)),
                ]),
                const SizedBox(height: 12),
                Card(
                  color: panel,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.cloud_done_outlined, color: cyan),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('OFFICIAL SUPABASE DASHBOARD SNAPSHOT',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900)),
                            ),
                            Text((official['window_label'] ?? 'LAST 7 DAYS').toString(),
                                style: const TextStyle(
                                    color: muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 13),
                          Wrap(spacing: 9, runSpacing: 9, children: [
                            metric('TOTAL REQUESTS', fmt(official['total_requests'])),
                            metric('SUCCESS RATE',
                                (official['success_rate'] ?? '—').toString() + '%',
                                color: green),
                            metric('API GATEWAY',
                                fmt(official['api_gateway_requests']),
                                color: cyan),
                            metric('WARNINGS', fmt(official['warnings']), color: amber),
                            metric('ERRORS', fmt(official['errors']), color: red),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            official['snapshot_at'] == null
                                ? 'No hosted-platform baseline captured.'
                                : 'Preserved from your Supabase dashboard • ' +
                                    official['snapshot_at'].toString(),
                            style: const TextStyle(color: muted, fontSize: 9.5),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: panel,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.monitor_heart_outlined, color: green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'LIVE BRIDGEPOINT • ' +
                                    (data['runtime_source'] ?? 'UNKNOWN').toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                            DropdownButton<String>(
                              value: range,
                              items: const ['24H', '7D', '30D', 'ALL']
                                  .map((v) => DropdownMenuItem(
                                      value: v, child: Text(v)))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  range = v;
                                  request = load();
                                });
                              },
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 9, runSpacing: 9, children: [
                            metric('DB TRANSACTIONS', fmt(live['db_transactions']),
                                color: cyan,
                                sub: 'Cumulative database counter'),
                            metric('DB SUCCESS',
                                (live['db_transaction_success_rate'] ?? '—').toString() + '%',
                                color: green,
                                sub: 'Commits ÷ commits + rollbacks'),
                            metric('ACTIVE CONNECTIONS',
                                fmt(live['active_connections'])),
                            metric('TRACKED PRODUCT EVENTS',
                                fmt(live['tracked_product_events']),
                                color: cyan,
                                sub: 'BridgePoint-owned telemetry'),
                            metric('FRONTEND HEALTH · 7D',
                                live['frontend_health_pct'] == null
                                    ? '—'
                                    : live['frontend_health_pct'].toString() + '%',
                                color: green,
                                sub: 'Resilience probes'),
                            metric('FREE LOCAL DISK',
                                live['local_free_disk_gb'] == null
                                    ? '—'
                                    : live['local_free_disk_gb'].toString() + ' GB',
                                color: amber),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            Chip(label: Text((live['export_running'] ?? 0).toString() + ' export running')),
                            Chip(label: Text((live['export_queued'] ?? 0).toString() + ' queued')),
                            Chip(label: Text((live['export_retry'] ?? 0).toString() + ' retrying')),
                            Chip(label: Text((live['export_succeeded'] ?? 0).toString() + ' complete')),
                            Chip(label: Text('PC ' + (live['local_node_status'] ?? 'UNKNOWN').toString())),
                          ]),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: panel,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Expanded(
                              child: Text('Reliability history',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900)),
                            ),
                            Container(width: 9, height: 9, color: green),
                            const SizedBox(width: 4),
                            const Text('success',
                                style: TextStyle(color: muted, fontSize: 9)),
                            const SizedBox(width: 10),
                            Container(width: 9, height: 9, color: red),
                            const SizedBox(width: 4),
                            const Text('failed',
                                style: TextStyle(color: muted, fontSize: 9)),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            'Historical BridgePoint telemetry • first available ' +
                                (data['history_first_seen'] ?? '—').toString(),
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                          const SizedBox(height: 14),
                          history(daily),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: panel,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONTINUITY',
                              style: TextStyle(
                                  color: cyan, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Text((data['history_note'] ?? '').toString(),
                              style: const TextStyle(color: muted, height: 1.45)),
                          const SizedBox(height: 7),
                          Text((data['cutover_note'] ?? '').toString(),
                              style: const TextStyle(
                                  color: Colors.white70, height: 1.45)),
                        ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  generated == null
                      ? ''
                      : 'Auto-refreshes every 30 seconds • Updated ' +
                          generated.toString(),
                  style: const TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
