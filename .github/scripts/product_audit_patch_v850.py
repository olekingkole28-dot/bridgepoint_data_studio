from pathlib import Path
import re

ROOT = Path('.')


def read(path: str) -> str:
    return (ROOT / path).read_text()


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f'{label}: expected source block not found')


# ---------------------------------------------------------------------------
# App shell: preserve OS accessibility scale, keep Investor in mobile primary,
# stop leaking raw auth errors, and repair Studio's stale integer routing map.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_app_v2.dart'
s = read(path)
s = replace_once(
    s,
    """      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.size.width < 820 ? 1.06 : 1.04;
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
""",
    """      builder: (context, child) {
        final media = MediaQuery.of(context);
        final appBump = media.size.width < 820 ? 1.06 : 1.04;
        final userScale = media.textScaler.scale(1.0);
        final effectiveScale = (userScale * appBump).clamp(0.8, 2.5);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(effectiveScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
""",
    'app text scaling',
)
s = replace_once(
    s,
    """    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
""",
    """    } catch (e) {
      if (mounted) {
        final message = e is AuthException
            ? e.message
            : 'BridgePoint could not complete authentication right now. Please try again.';
        setState(() => error = message);
      }
    } finally {
""",
    'auth error UX',
)
s = replace_once(
    s,
    """  List<_AreaV2> get _primary => [
        _AreaV2.home,
        _AreaV2.map,
        _AreaV2.properties,
        owner ? _AreaV2.investment : _AreaV2.investor,
      ];
""",
    """  List<_AreaV2> get _primary => const [
        _AreaV2.home,
        _AreaV2.map,
        _AreaV2.properties,
        _AreaV2.investor,
      ];
""",
    'mobile primary navigation',
)
s = replace_once(
    s,
    """  void _navigateFromStudio(int oldIndex) {
    final target = switch (oldIndex) {
      1 || 4 || 8 => _AreaV2.property,
      3 => _AreaV2.map,
      5 => _AreaV2.sources,
      6 => _AreaV2.products,
      7 => _AreaV2.models,
      14 => _AreaV2.integrations,
      _ => _AreaV2.studio,
    };
    setState(() => selected = target);
  }
""",
    """  void _navigateFromStudio(int oldIndex) {
    final target = switch (oldIndex) {
      1 => _AreaV2.opportunities,
      3 => _AreaV2.map,
      4 => _AreaV2.property,
      5 => _AreaV2.signals,
      6 => _AreaV2.sources,
      7 => _AreaV2.operations,
      8 => _AreaV2.sources,
      9 => _AreaV2.map,
      11 => _AreaV2.models,
      14 => _AreaV2.integrations,
      _ => _AreaV2.studio,
    };
    setState(() => selected = target);
  }
""",
    'Studio routing',
)
write(path, s)


# ---------------------------------------------------------------------------
# Buildings/Twin: state-scoped search, no raw DB exceptions, truthful L2 source
# surface copy, and human digital-twin summary instead of recursive JSON.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_buildings_v2.dart'
s = read(path)
s = replace_once(
    s,
    """  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'error': '$e', 'rpc': rpc};
    }
  }
""",
    """  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }
""",
    'Buildings safe RPC',
)
s = replace_once(
    s,
    """  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_suggestions_v192',
        params: {'p_query': q, 'p_limit': 20},
      );
      final rows = _rows(raw).where((row) {
        final state = '${row['state_code'] ?? ''}'.toUpperCase();
        return state.isEmpty || state == _state;
      }).take(12).toList();
      if (mounted) setState(() => _results = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
""",
    """  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_flutter_properties_state_browse_v840',
        params: <String, dynamic>{
          'p_state_code': _state,
          'p_search': q,
          'p_municipality': null,
          'p_property_type': null,
          'p_limit': 12,
          'p_offset': 0,
        },
      );
      final rows = _rows(raw).take(12).toList();
      if (!mounted) return;
      setState(() {
        _results = rows;
        if (rows.isEmpty) _error = 'No matching $_state properties were found.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Property search is temporarily unavailable. Try a shorter address or parcel search.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
""",
    'Buildings state search',
)
s = s.replace(
    'Search a property, then switch between source footprint and schematic massing in the interactive geometry viewer. If the selected property has no geometry yet, the payload stays explicit about that instead of inventing a model.',
    'Search a property, then inspect the highest-fidelity verified geometry BridgePoint has for it. Properties with source XYZ surfaces open the rotatable source-surface model; footprint and massing remain truthful fallbacks when stronger geometry is not available.',
)
s = s.replace(
    "labelText: '$_state address, parcel, owner or municipality'",
    "labelText: '$_state address, parcel or municipality'",
)
s = s.replace('_Payload(payload: _twin)', '_TwinSummary(payload: _twin)')
if 'class _TwinSummary extends StatelessWidget' not in s:
    marker = 'class _Payload extends StatelessWidget {'
    if marker not in s:
        raise SystemExit('Buildings payload marker missing')
    twin_class = r'''class _TwinSummary extends StatelessWidget {
  const _TwinSummary({required this.payload});
  final dynamic payload;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _label(String value) => value
      .replaceAll('L0_PROPERTY_SHELL', 'Property shell')
      .replaceAll('L1_BUILDING_MASSING', 'Building massing')
      .replaceAll('L2_SOURCE_SURFACE_MODEL', 'Source XYZ surface model')
      .replaceAll('L2_ROOF_FACADE', 'Roof + facade model')
      .replaceAll('L3_SEMANTIC_BIM', 'Semantic BIM')
      .replaceAll('L4_OPERATIONAL_TWIN', 'Operational twin');

  String _pct(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '—';
    return '${(n * 100).clamp(0, 100).toStringAsFixed(0)}%';
  }

  Widget _metric(String label, String value, IconData icon, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 155, maxWidth: 265),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF081625),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 11.5)),
          ])),
        ]),
      );

  Widget _readiness(String label, dynamic raw) {
    final value = _map(raw);
    final ready = value['ready'] == true;
    return Chip(
      avatar: Icon(ready ? Icons.check_circle_rounded : Icons.pending_outlined,
          size: 16,
          color: ready ? _BridgePointBuildingsV2State._green : _BridgePointBuildingsV2State._muted),
      label: Text('$label • ${ready ? 'ready' : 'needs more evidence'}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final twin = _map(payload);
    if (twin.isEmpty || twin['available'] == false) {
      return const Text('Digital-twin intelligence is not available for this property yet.',
          style: TextStyle(color: _BridgePointBuildingsV2State._muted));
    }
    final fidelity = _label('${twin['fidelity_level'] ?? 'Not classified'}');
    final sourceSurface = twin['source_surface_geometry'] == true ||
        '${twin['fidelity_level'] ?? ''}' == 'L2_SOURCE_SURFACE_MODEL';
    final exact = twin['exact_replica_claim_allowed'] == true;
    final readiness = _map(twin['simulation_readiness']);
    final upgrades = twin['upgrade_path'] is List
        ? List<dynamic>.from(twin['upgrade_path'])
        : const <dynamic>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _metric('Fidelity', fidelity, Icons.view_in_ar_rounded, _BridgePointBuildingsV2State._cyan),
        _metric('Overall confidence', _pct(twin['overall_confidence']), Icons.verified_outlined, _BridgePointBuildingsV2State._green),
        _metric('Source XYZ surfaces', sourceSurface ? 'Available' : 'Not linked yet', Icons.layers_rounded,
            sourceSurface ? _BridgePointBuildingsV2State._green : _BridgePointBuildingsV2State._muted),
        _metric('Exact replica claim', exact ? 'Verified' : 'Not claimed', Icons.fact_check_outlined,
            exact ? _BridgePointBuildingsV2State._green : _BridgePointBuildingsV2State._amber),
      ]),
      if (readiness.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Simulation readiness', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _readiness('Wind envelope', readiness['wind_envelope']),
          _readiness('Roof water pooling', readiness['roof_water_pooling']),
          _readiness('Flood site flow', readiness['flood_site_flow']),
          _readiness('Window retrofit', readiness['thermal_window_retrofit']),
        ]),
      ],
      if (upgrades.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('What would raise fidelity', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(upgrades.take(4).map((e) => '${e ?? ''}'.replaceAll('_', ' ')).where((e) => e.trim().isNotEmpty).join(' • '),
            style: const TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 12, height: 1.45)),
      ],
      const SizedBox(height: 10),
      const Text(
        'Source-surface geometry can reproduce observed roof and wall form, but BridgePoint does not call it photorealistic or an exact replica until imagery, mesh, or other verified facade evidence supports that claim.',
        style: TextStyle(color: _BridgePointBuildingsV2State._muted, fontSize: 11.5, height: 1.4),
      ),
    ]);
  }
}

'''
    s = s.replace(marker, twin_class + marker, 1)
write(path, s)


# ---------------------------------------------------------------------------
# Property presentation: remove developer payload expanders from customer
# surfaces and make the generic workspace renderer show records/scalars only.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_property_presentation_v2.dart'
s = read(path)
s = re.sub(r"\n\s*_AllFields\(title: '[^\n]+', value: [^\n]+\),", '', s)
if 'class _CustomerSafeSummary extends StatelessWidget' not in s:
    marker = 'class BridgePointGenericWorkspaceSectionV2 extends StatelessWidget {'
    if marker not in s:
        raise SystemExit('Generic workspace marker missing')
    customer_summary = r'''class _CustomerSafeSummary extends StatelessWidget {
  const _CustomerSafeSummary({required this.value});
  final dynamic value;

  List<Map<String, dynamic>> _records(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map) {
      for (final key in const ['items', 'notes', 'watchlists', 'results', 'rows', 'events']) {
        if (raw[key] is List) return _records(raw[key]);
      }
    }
    return const [];
  }

  bool _technical(String key) {
    final k = key.toLowerCase();
    return k == 'metadata' || k == 'payload' || k == 'raw' || k == 'rpc' ||
        k.endsWith('_id') || k.contains('internal') || k.contains('secret') ||
        k.contains('token') || k.contains('version');
  }

  String _title(Map<String, dynamic> row) {
    for (final key in const ['title', 'watchlist_name', 'name', 'note_text', 'label', 'headline', 'address']) {
      final text = '${row[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return 'BridgePoint record';
  }

  String _subtitle(Map<String, dynamic> row) {
    final parts = <String>[];
    for (final key in const ['status', 'description', 'summary', 'created_at', 'follow_up_at', 'updated_at']) {
      final text = '${row[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') parts.add(text);
      if (parts.length == 2) break;
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final records = _records(value);
    if (records.isNotEmpty) {
      return Column(
        children: records.take(25).map((row) {
          final subtitle = _subtitle(row);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline_rounded, color: _bpCyan, size: 18),
            title: Text(_title(row), maxLines: 3, overflow: TextOverflow.ellipsis),
            subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _bpMuted, fontSize: 11.5)),
          );
        }).toList(),
      );
    }
    if (value is Map) {
      final entries = (value as Map).entries
          .where((entry) => entry.value is! Map && entry.value is! List && !_technical('${entry.key}'))
          .take(16)
          .toList();
      if (entries.isEmpty) {
        return const Text('No customer-facing records are available yet.', style: TextStyle(color: _bpMuted));
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.map((entry) => _Metric(_labelKey('${entry.key}'), _text(entry.value))).toList(),
      );
    }
    return Text(_text(value, 'No customer-facing records are available yet.'),
        style: const TextStyle(color: _bpMuted));
  }
}

'''
    s = s.replace(marker, customer_summary + marker, 1)
s = s.replace('_StructuredValue(value: payload),', '_CustomerSafeSummary(value: payload),')
write(path, s)


# ---------------------------------------------------------------------------
# Global Search: keep search nationwide, but stop opening a raw payload tree.
# Reuse the already-productized property presentation and real geometry viewer.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_global_search_v2.dart'
s = read(path)
if "import 'bridgepoint_building_geometry_v2.dart';" not in s:
    s = s.replace(
        "import 'package:supabase_flutter/supabase_flutter.dart';\n",
        "import 'package:supabase_flutter/supabase_flutter.dart';\n\nimport 'bridgepoint_building_geometry_v2.dart';\nimport 'bridgepoint_property_presentation_v2.dart';\n",
        1,
    )
s = replace_once(
    s,
    """    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
""",
    """    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Property search is temporarily unavailable. Try a more specific address, parcel, owner or municipality.');
      }
    } finally {
""",
    'Global Search error',
)
s = replace_once(
    s,
    """  Future<dynamic> _safe(String rpc, Map<String, dynamic> params) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (e) {
      return {'available': false, 'error': '$e', 'rpc': rpc};
    }
  }
""",
    """  Future<dynamic> _safe(String rpc, Map<String, dynamic> params) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }
""",
    'Global Search safe RPC',
)
old_panels = """              _PayloadPanel(title: 'Property intelligence', icon: Icons.home_work_outlined, payload: detail),
              const SizedBox(height: 10),
              _PayloadPanel(title: 'Timeline', icon: Icons.timeline_rounded, payload: timeline),
              const SizedBox(height: 10),
              _PayloadPanel(title: '2D / 3D geometry', icon: Icons.view_in_ar_rounded, payload: geometry),
              const SizedBox(height: 10),
              _PayloadPanel(title: 'Digital twin', icon: Icons.account_tree_rounded, payload: twin),
              const SizedBox(height: 10),
              _PayloadPanel(title: 'Notes & follow-ups', icon: Icons.note_alt_outlined, payload: notes),
"""
new_panels = """              BridgePointPropertyOverviewV2(payload: detail),
              const SizedBox(height: 10),
              BridgePointPropertyTimelineV2(payload: timeline),
              const SizedBox(height: 10),
              BridgePointTwinSummaryV2(payload: twin),
              const SizedBox(height: 10),
              BridgePointBuildingGeometryV2(payload: geometry),
              const SizedBox(height: 10),
              BridgePointGenericWorkspaceSectionV2(
                title: 'Notes & follow-ups',
                payload: notes,
                icon: Icons.note_alt_outlined,
              ),
"""
s = replace_once(s, old_panels, new_panels, 'Global Search product panels')
write(path, s)


# ---------------------------------------------------------------------------
# Claims: friendly failures + turn nested claim intelligence sections into
# readable cards instead of stringified list/map payloads.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_claims_v2.dart'
s = read(path)
for old, new in [
    ("_message = 'Could not open claim: $e'", "_message = 'Could not open this claim workflow right now. Please try again.'"),
    ("_message = 'Could not update claim: $e'", "_message = 'Could not update this claim right now. Please try again.'"),
    ("_message = 'Claim Intelligence unavailable: $e'", "_message = 'Claim Intelligence is temporarily unavailable.'"),
    ("_message = 'Supplement analysis unavailable: $e'", "_message = 'Supplement analysis is temporarily unavailable.'"),
    ("_message = 'Supplement packet unavailable: $e'", "_message = 'Supplement packet creation is temporarily unavailable.'"),
]:
    s = s.replace(old, new)
marker = 'class _ClaimSection extends StatelessWidget {'
if marker not in s:
    raise SystemExit('Claim section marker missing')
prefix = s[:s.index(marker)]
claim_class = r'''class _ClaimSection extends StatelessWidget {
  const _ClaimSection(this.title, this.value);
  final String title;
  final Map<String, dynamic> value;

  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  bool _technical(String key) {
    final k = key.toLowerCase();
    return k.endsWith('_id') || k == 'metadata' || k == 'payload' ||
        k == 'raw' || k.contains('internal') || k.contains('token');
  }

  List<Map<String, dynamic>> _records() {
    for (final key in const ['items', 'runs', 'documents', 'findings', 'gaps', 'packets']) {
      final raw = value[key];
      if (raw is List) {
        return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return const [];
  }

  String _recordTitle(Map<String, dynamic> row) {
    for (final key in const ['title', 'name', 'document_name', 'finding', 'gap_type', 'damage_type', 'status', 'label']) {
      final text = '${row[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') return text.replaceAll('_', ' ');
    }
    return 'Claim intelligence record';
  }

  String _recordDetail(Map<String, dynamic> row) {
    for (final key in const ['summary', 'description', 'reason', 'recommended_action', 'created_at', 'updated_at']) {
      final text = '${row[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scalars = value.entries
        .where((entry) => entry.value is! Map && entry.value is! List && !_technical(entry.key))
        .take(14)
        .toList();
    final records = _records();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (scalars.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: scalars.map((entry) => Chip(
              label: Text('${_label(entry.key)}: ${entry.value ?? '—'}'),
            )).toList()),
          ],
          if (records.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...records.take(20).map((row) {
              final detail = _recordDetail(row);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fact_check_outlined, color: Color(0xFF48E1FF), size: 18),
                title: Text(_recordTitle(row), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: detail.isEmpty ? null : Text(detail, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 11.5)),
              );
            }),
          ],
          if (scalars.isEmpty && records.isEmpty)
            const Text('No customer-facing claim intelligence records are available yet.',
                style: TextStyle(color: Color(0xFFB5C6D9))),
        ]),
      ),
    );
  }
}
'''
s = prefix + claim_class
write(path, s)


# ---------------------------------------------------------------------------
# Property 360, Calendar, Integrations, Worth: suppress raw exception strings.
# ---------------------------------------------------------------------------
path = 'lib/v2/bridgepoint_property_360_v2.dart'
s = read(path)
s = s.replace("return {'available': false, 'rpc': rpc, 'error': '$e'};", "return const <String, dynamic>{'available': false};")
s = s.replace("setState(() => _error = '$e')", "setState(() => _error = 'This BridgePoint action is temporarily unavailable. Please try again.')")
s = s.replace("setState(() => _message = 'Watchlist action unavailable: $e')", "setState(() => _message = 'Watchlist action is temporarily unavailable.')")
s = s.replace("setState(() => _message = 'BridgePoint AI unavailable: $e')", "setState(() => _message = 'BridgePoint AI is temporarily unavailable.')")
write(path, s)

path = 'lib/v2/bridgepoint_calendar_v2.dart'
s = read(path)
s = s.replace("_message = 'Could not add calendar item: $e'", "_message = 'Could not add this calendar item. Check the date/time and try again.'")
s = s.replace("_message = 'Could not remove item: $e'", "_message = 'Could not remove this calendar item right now.'")
s = s.replace("_message = 'Could not schedule route: $e'", "_message = 'Could not schedule this route. Check the date/time and try again.'")
write(path, s)

path = 'lib/bridgepoint_integrations_hub_v790.dart'
s = read(path)
s = s.replace("SnackBar(content: Text('Could not record request: $error'))", "const SnackBar(content: Text('Could not record this integration request right now. Please try again.'))")
s = s.replace('message: snapshot.error.toString(),', "message: 'BridgePoint could not load the integration catalog right now. Please try refresh in a moment.',")
write(path, s)

path = 'lib/v2/bridgepoint_investment_valuation_v2.dart'
s = read(path)
s = s.replace("Text('Valuation room unavailable: ${snapshot.error}')", "const Text('The owner valuation room is temporarily unavailable. Live product data is unaffected.')")
write(path, s)

# Source markers used by CI and handoff review.
checks = {
    'lib/v2/bridgepoint_app_v2.dart': ['_AreaV2.investor', 'userScale', '1 => _AreaV2.opportunities'],
    'lib/v2/bridgepoint_buildings_v2.dart': ['bridgepoint_flutter_properties_state_browse_v840', 'class _TwinSummary', 'Source XYZ surface model'],
    'lib/v2/bridgepoint_global_search_v2.dart': ['BridgePointPropertyOverviewV2', 'BridgePointBuildingGeometryV2'],
    'lib/v2/bridgepoint_claims_v2.dart': ['No customer-facing claim intelligence records'],
    'lib/v2/bridgepoint_property_presentation_v2.dart': ['class _CustomerSafeSummary'],
}
for file, markers in checks.items():
    text = read(file)
    for marker in markers:
        if marker not in text:
            raise SystemExit(f'{file}: missing marker {marker}')

print('V850 product-audit patch complete')
