import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bpPanel = Color(0xFF0D1A2B);
const _bpSoft = Color(0xFF122238);
const _bpCyan = Color(0xFF35D2E8);
const _bpBlue = Color(0xFF4F7CFF);
const _bpGreen = Color(0xFF38D49A);
const _bpAmber = Color(0xFFFFC857);
const _bpRed = Color(0xFFFF6B6B);
const _bpMuted = Color(0xFF8FA5BF);

List<Map<String, dynamic>> _bpRows(dynamic value, List<String> keys) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (value is Map) {
    for (final key in keys) {
      if (value[key] is List) return _bpRows(value[key], keys);
    }
  }
  return const [];
}

Map<String, dynamic> _bpMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _bpNumber(dynamic value) {
  final n = value is num
      ? value.round()
      : int.tryParse('${value ?? ''}'.replaceAll(',', '')) ?? 0;
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class BridgePointSignalsV2 extends StatefulWidget {
  const BridgePointSignalsV2({super.key});

  @override
  State<BridgePointSignalsV2> createState() => _BridgePointSignalsV2State();
}

class _BridgePointSignalsV2State extends State<BridgePointSignalsV2> {
  final search = TextEditingController();
  String family = 'all';
  String status = 'active';
  int offset = 0;
  static const limit = 40;
  late Future<dynamic> request;

  @override
  void initState() {
    super.initState();
    request = _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<dynamic> _load() => Supabase.instance.client.rpc(
        'bridgepoint_flutter_signals',
        params: {
          'p_search': search.text.trim().isEmpty ? null : search.text.trim(),
          'p_signal_family': family == 'all' ? null : family,
          'p_status': status == 'all' ? null : status,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

  void reload({bool reset = false}) {
    if (reset) offset = 0;
    setState(() => request = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: request,
      builder: (context, snapshot) {
        final payload = _bpMap(snapshot.data);
        final rows = _bpRows(payload, const ['signals', 'items', 'rows', 'results']);
        final total = payload['total_results'] ?? payload['active_signal_count'] ?? rows.length;
        final families = <String>{
          'all',
          ...rows.map((r) => '${r['signal_family'] ?? r['signal_type'] ?? 'other'}'),
        }.toList();
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SurfaceHeading(
              title: 'Signals',
              subtitle:
                  'Live property-level evidence signals • family • status • confidence • source-backed context',
              icon: Icons.radar_rounded,
              onRefresh: loading ? null : reload,
            ),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 760;
                final searchField = TextField(
                  controller: search,
                  onSubmitted: (_) => reload(reset: true),
                  decoration: const InputDecoration(
                    labelText: 'Search signals',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                );
                final familyField = DropdownButtonFormField<String>(
                  initialValue: family,
                  decoration: const InputDecoration(labelText: 'Family'),
                  items: families
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    family = v;
                    reload(reset: true);
                  },
                );
                final statusField = DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    status = v;
                    reload(reset: true);
                  },
                );
                if (compact) {
                  return Column(children: [searchField, const SizedBox(height: 8), familyField, const SizedBox(height: 8), statusField]);
                }
                return Row(children: [Expanded(flex: 2, child: searchField), const SizedBox(width: 8), Expanded(child: familyField), const SizedBox(width: 8), Expanded(child: statusField)]);
              },
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _SmallMetric('TOTAL', _bpNumber(total), _bpCyan),
              _SmallMetric('SHOWN', '${rows.length}', _bpBlue),
              _SmallMetric('FAMILIES', '${families.length - 1}', _bpGreen),
            ]),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              _ErrorBox('${snapshot.error}')
            else if (rows.isEmpty && !loading)
              const _EmptyBox('No signal rows matched the current filters.')
            else
              ...rows.map((row) => _DataRowCard(
                    icon: Icons.bolt_rounded,
                    accent: _bpCyan,
                    title: '${row['signal_name'] ?? row['signal_type'] ?? row['title'] ?? 'Signal'}'.replaceAll('_', ' '),
                    subtitle:
                        '${row['signal_family'] ?? 'signal'} • ${row['status'] ?? 'active'} • ${row['state_code'] ?? ''}',
                    payload: row,
                  )),
            Row(children: [
              OutlinedButton.icon(
                onPressed: offset > 0 && !loading
                    ? () {
                        offset = (offset - limit).clamp(0, 1 << 30);
                        reload();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: payload['has_more'] == true && !loading
                    ? () {
                        offset += limit;
                        reload();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ]),
          ],
        );
      },
    );
  }
}

class BridgePointSourcesV2 extends StatefulWidget {
  const BridgePointSourcesV2({super.key});

  @override
  State<BridgePointSourcesV2> createState() => _BridgePointSourcesV2State();
}

class _BridgePointSourcesV2State extends State<BridgePointSourcesV2> {
  late Future<List<dynamic>> request;

  @override
  void initState() {
    super.initState();
    request = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
        Supabase.instance.client.rpc('bridgepoint_flutter_sources'),
        Supabase.instance.client.rpc('bridgepoint_source_health_v86'),
      ]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        final sourcePayload = values.isNotEmpty ? _bpMap(values[0]) : const <String, dynamic>{};
        final healthPayload = values.length > 1 ? _bpMap(values[1]) : const <String, dynamic>{};
        var rows = _bpRows(sourcePayload, const ['sources', 'items', 'rows', 'results']);
        if (rows.isEmpty) rows = _bpRows(healthPayload, const ['sources', 'items', 'rows']);
        final summary = _bpMap(healthPayload['summary']);
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SurfaceHeading(
              title: 'Sources',
              subtitle:
                  'Connected intelligence sources • ingestion totals • state coverage • health • refresh status',
              icon: Icons.hub_rounded,
              onRefresh: loading ? null : () => setState(() => request = _load()),
            ),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _SmallMetric('REGISTERED', _bpNumber(summary['registered'] ?? sourcePayload['registered_source_count'] ?? rows.length), _bpCyan),
              _SmallMetric('HEALTHY', _bpNumber(summary['healthy']), _bpGreen),
              _SmallMetric('STALE', _bpNumber(summary['stale']), _bpAmber),
              _SmallMetric('FAILING', _bpNumber(summary['failing']), _bpRed),
            ]),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              _ErrorBox('${snapshot.error}')
            else if (rows.isEmpty && !loading)
              const _EmptyBox('No source rows were returned.')
            else
              LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth >= 1050 ? 3 : c.maxWidth >= 680 ? 2 : 1;
                  final width = (c.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final row in rows)
                        SizedBox(
                          width: width,
                          child: _DataRowCard(
                            icon: _sourceIcon('${row['source_category'] ?? row['source_type'] ?? ''}'),
                            accent: _sourceColor('${row['health_status'] ?? row['status'] ?? ''}'),
                            title: '${row['source_name'] ?? row['name'] ?? row['source_code'] ?? 'Source'}',
                            subtitle:
                                '${row['state_code'] ?? row['geographic_scope'] ?? 'National'} • ${row['source_category'] ?? row['source_type'] ?? ''} • ${row['health_status'] ?? row['status'] ?? 'connected'}',
                            payload: row,
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
  }

  IconData _sourceIcon(String category) {
    final s = category.toLowerCase();
    if (s.contains('weather') || s.contains('storm')) return Icons.thunderstorm_rounded;
    if (s.contains('parcel') || s.contains('assessor')) return Icons.map_outlined;
    if (s.contains('fire')) return Icons.local_fire_department_rounded;
    if (s.contains('permit')) return Icons.description_outlined;
    if (s.contains('imagery') || s.contains('lidar')) return Icons.satellite_alt_rounded;
    return Icons.hub_outlined;
  }

  Color _sourceColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('fail') || s.contains('error')) return _bpRed;
    if (s.contains('stale') || s.contains('warn')) return _bpAmber;
    return _bpGreen;
  }
}

class BridgePointModelsV2 extends StatefulWidget {
  const BridgePointModelsV2({super.key});

  @override
  State<BridgePointModelsV2> createState() => _BridgePointModelsV2State();
}

class _BridgePointModelsV2State extends State<BridgePointModelsV2> {
  late Future<dynamic> request;
  String category = 'all';

  @override
  void initState() {
    super.initState();
    request = Supabase.instance.client.rpc('bridgepoint_flutter_models');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: request,
      builder: (context, snapshot) {
        final payload = _bpMap(snapshot.data);
        final all = _bpRows(payload, const ['models', 'items', 'rows', 'results']);
        final categories = <String>{
          'all',
          ...all.map((m) => '${m['model_category'] ?? 'other'}'),
        }.toList();
        final rows = category == 'all'
            ? all
            : all.where((m) => '${m['model_category'] ?? 'other'}' == category).toList();
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final propertyModels = all.where((m) => '${m['target_entity_type']}' == 'property').length;
        final packageLinks = all.fold<int>(
          0,
          (sum, m) => sum + (m['package_count'] is num ? (m['package_count'] as num).round() : 0),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SurfaceHeading(
              title: 'Models',
              subtitle:
                  'Live BridgePoint scoring models • thresholds • categories • package coverage',
              icon: Icons.psychology_alt_rounded,
              onRefresh: loading
                  ? null
                  : () => setState(() => request = Supabase.instance.client.rpc('bridgepoint_flutter_models')),
            ),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _SmallMetric('ACTIVE MODELS', _bpNumber(payload['active_model_count'] ?? all.length), _bpCyan),
              _SmallMetric('PROPERTY MODELS', '$propertyModels', _bpBlue),
              _SmallMetric('PACKAGE LINKS', _bpNumber(payload['active_package_model_links'] ?? packageLinks), _bpGreen),
            ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((value) {
                  final selected = value == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      selected: selected,
                      label: Text(value.replaceAll('_', ' ')),
                      onSelected: (_) => setState(() => category = value),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              _ErrorBox('${snapshot.error}')
            else if (rows.isEmpty && !loading)
              const _EmptyBox('No models matched this category.')
            else
              LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth >= 1050 ? 3 : c.maxWidth >= 680 ? 2 : 1;
                  final width = (c.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final row in rows)
                        SizedBox(
                          width: width,
                          child: _DataRowCard(
                            icon: Icons.psychology_alt_rounded,
                            accent: row['active'] == false ? _bpMuted : _bpCyan,
                            title: '${row['model_name'] ?? row['model_key'] ?? 'Model'}',
                            subtitle:
                                '${row['model_category'] ?? 'model'} • ${row['target_entity_type'] ?? 'property'} • ${row['active'] == false ? 'inactive' : 'active'}',
                            payload: row,
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
  }
}

class _SurfaceHeading extends StatelessWidget {
  const _SurfaceHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_bpCyan, _bpBlue]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: _bpMuted, height: 1.45)),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: _bpMuted, fontSize: 8, fontWeight: FontWeight.w900)),
            const SizedBox(width: 7),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _DataRowCard extends StatelessWidget {
  const _DataRowCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.payload,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Map<String, dynamic> payload;

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: ListView(
              children: [
                Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                for (final e in payload.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${e.key.replaceAll('_', ' ')}: ${e.value}',
                      style: const TextStyle(color: _bpMuted, fontSize: 10, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _bpPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: .14)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _bpMuted, fontSize: 9.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _bpMuted),
            ],
          ),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bpRed.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _bpRed.withValues(alpha: .20)),
        ),
        child: Text(text, style: const TextStyle(color: _bpRed)),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _bpPanel, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: const TextStyle(color: _bpMuted)),
      );
}
