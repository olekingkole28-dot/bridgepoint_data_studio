import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';
import 'bridgepoint_property_dossier_recovered_v6.dart' as evidence_v6;

/// Recovery V7 makes the Property Twin the primary property workspace.
/// The older dossier remains available as the full evidence/drill-down view.
class BridgePointPropertyDossierV2 extends StatefulWidget {
  const BridgePointPropertyDossierV2({
    super.key,
    required this.propertyId,
    required this.seed,
    this.asPage = false,
  });

  final String propertyId;
  final Map<String, dynamic> seed;
  final bool asPage;

  @override
  State<BridgePointPropertyDossierV2> createState() =>
      _BridgePointPropertyDossierRecoveryV7State();
}

class _BridgePointPropertyDossierRecoveryV7State
    extends State<BridgePointPropertyDossierV2> {
  static const _bg = Color(0xFF030A12);
  static const _panel = Color(0xFF081624);
  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);

  late Future<Map<String, dynamic>> _future;
  _TwinView _view = _TwinView.site3d;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant BridgePointPropertyDossierV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.propertyId != widget.propertyId) {
      _future = _load();
      _view = _TwinView.site3d;
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_twin_v918',
        params: {'p_property_id': widget.propertyId},
      );
      return _map(raw);
    } catch (_) {
      return const {};
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  String _address() {
    for (final key in ['full_address', 'address', 'property_address', 'street_address']) {
      final text = '${widget.seed[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    final end = widget.propertyId.length < 8 ? widget.propertyId.length : 8;
    return 'Property ${widget.propertyId.substring(0, end)}';
  }

  void _openEvidence() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => evidence_v6.BridgePointPropertyDossierV2(
          propertyId: widget.propertyId,
          seed: widget.seed,
          asPage: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TwinLoading();
        }
        final twin = snapshot.data ?? const <String, dynamic>{};
        if (twin.isEmpty) {
          return _TwinError(onRetry: _refresh, onEvidence: _openEvidence);
        }
        return _TwinWorkspace(
          propertyId: widget.propertyId,
          address: _address(),
          twin: twin,
          view: _view,
          onView: (value) => setState(() => _view = value),
          onRefresh: _refresh,
          onEvidence: _openEvidence,
        );
      },
    );

    if (!widget.asPage) return workspace;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF06111E),
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property Twin',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            Text(
              _address(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 10.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh property twin',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: _cyan),
          ),
        ],
      ),
      body: workspace,
    );
  }
}

enum _TwinView { site3d, front, aerial, history }

class _TwinWorkspace extends StatelessWidget {
  const _TwinWorkspace({
    required this.propertyId,
    required this.address,
    required this.twin,
    required this.view,
    required this.onView,
    required this.onRefresh,
    required this.onEvidence,
  });

  final String propertyId;
  final String address;
  final Map<String, dynamic> twin;
  final _TwinView view;
  final ValueChanged<_TwinView> onView;
  final Future<void> Function() onRefresh;
  final VoidCallback onEvidence;

  static const _bg = Color(0xFF030A12);
  static const _panel = Color(0xFF081624);
  static const _cyan = Color(0xFF48E1FF);
  static const _green = Color(0xFF69E7A7);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
  }

  bool _bool(Map<String, dynamic> map, String key) => map[key] == true;

  String _clean(dynamic value, [String fallback = '—']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _date(dynamic value) {
    final raw = _clean(value, 'Date varies by source');
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final l = dt.toLocal();
    return '${l.month}/${l.day}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final caps = _map(twin['capabilities']);
    final queued = _map(twin['enrichment_queued']);
    final site = _map(twin['site_3d']);
    final media = _map(twin['media']);
    final geometry = _map(twin['geometry']);
    final intel = _map(twin['intelligence']);
    final front = _map(media['front']);
    final aerial = _map(media['aerial_current']);
    final history = _rows(media['aerial_history']);
    final liveCount = caps.values.where((v) => v == true).length;
    final upgrading = queued.values.where((v) => v == true).length;

    return ColoredBox(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0E2A41), Color(0xFF071321)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _cyan.withValues(alpha: .24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: _cyan.withValues(alpha: .28)),
                        ),
                        child: const Icon(Icons.hub_rounded, color: _cyan),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LIVE PROPERTY TWIN',
                              style: TextStyle(
                                color: _cyan,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _StatusPill('$liveCount live', _green),
                      if (upgrading > 0) _StatusPill('$upgrading upgrading', _amber),
                      _StatusPill(
                        '${site['building_count'] ?? 0} nearby structures',
                        _cyan,
                      ),
                      _StatusPill(
                        _clean(site['structure_mode'], 'Physical context'),
                        _muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            SegmentedButton<_TwinView>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _TwinView.site3d,
                  icon: Icon(Icons.view_in_ar_rounded, size: 17),
                  label: Text('3D'),
                ),
                ButtonSegment(
                  value: _TwinView.front,
                  icon: Icon(Icons.home_rounded, size: 17),
                  label: Text('Front'),
                ),
                ButtonSegment(
                  value: _TwinView.aerial,
                  icon: Icon(Icons.satellite_alt_rounded, size: 17),
                  label: Text('Aerial'),
                ),
                ButtonSegment(
                  value: _TwinView.history,
                  icon: Icon(Icons.history_rounded, size: 17),
                  label: Text('History'),
                ),
              ],
              selected: {view},
              onSelectionChanged: (values) => onView(values.first),
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: MediaQuery.sizeOf(context).width < 650 ? 1.18 : 1.8,
              child: _visual(
                context,
                site: site,
                front: front,
                aerial: aerial,
                history: history,
                queued: queued,
              ),
            ),
            const SizedBox(height: 12),
            _PlainEnglishCard(
              title: 'What BridgePoint knows right now',
              icon: Icons.translate_rounded,
              color: _cyan,
              lines: [
                _bool(caps, 'geocoded')
                    ? 'This property is pinned to a real map location.'
                    : 'BridgePoint is still resolving the property location and will not guess it.',
                _structurePlain(site, queued),
                _frontPlain(front, queued),
                _aerialPlain(aerial, history),
              ],
            ),
            const SizedBox(height: 10),
            _PlainEnglishCard(
              title: 'Intelligence, not a mystery score',
              icon: Icons.insights_rounded,
              color: _green,
              lines: _intelligenceLines(intel),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEvidence,
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Full evidence'),
                  ),
                ),
                if (geometry.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            backgroundColor: _bg,
                            appBar: AppBar(title: const Text('Structure model')),
                            body: SafeArea(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: BridgePointBuildingGeometryV2(payload: geometry),
                              ),
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.architecture_rounded),
                      label: const Text('Structure'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _amber.withValues(alpha: .23)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_outlined, color: _amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _clean(
                        site['truth_notice'],
                        'BridgePoint separates measured/source-backed facts from visualization estimates and keeps the original evidence available for review.',
                      ),
                      style: const TextStyle(color: _amber, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visual(
    BuildContext context, {
    required Map<String, dynamic> site,
    required Map<String, dynamic> front,
    required Map<String, dynamic> aerial,
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> queued,
  }) {
    switch (view) {
      case _TwinView.site3d:
        return _SiteTwinCanvas(site: site);
      case _TwinView.front:
        return _NetworkEvidenceImage(
          item: front,
          emptyIcon: Icons.home_rounded,
          emptyTitle: queued['front_imagery'] == true
              ? 'Front imagery is being enriched'
              : 'Front view falls back to physical site context',
          emptyBody:
              'BridgePoint will never manufacture a front photo. Until a lawful source frame is attached, the aerial and 3D site remain available.',
        );
      case _TwinView.aerial:
        return _NetworkEvidenceImage(
          item: aerial,
          emptyIcon: Icons.satellite_alt_rounded,
          emptyTitle: 'Live aerial context',
          emptyBody: 'Current aerial context becomes available for geocoded properties.',
        );
      case _TwinView.history:
        if (history.isEmpty) {
          return _VisualEmpty(
            icon: Icons.history_rounded,
            title: 'Historical imagery is being expanded nationally',
            body:
                'Current aerial remains separate from dated historical observations. BridgePoint does not pretend a live basemap is historical evidence.',
          );
        }
        return PageView(
          children: history.map((item) => _NetworkEvidenceImage(item: item)).toList(),
        );
    }
  }

  String _structurePlain(Map<String, dynamic> site, Map<String, dynamic> queued) {
    final mode = _clean(site['structure_mode'], 'TARGET_BUILDING_PENDING');
    if (mode == 'SOURCE_FOOTPRINT_HEIGHT') {
      return 'The building footprint and displayed height come from a source-backed physical model.';
    }
    if (mode == 'SOURCE_FOOTPRINT_ESTIMATED_HEIGHT') {
      return 'The building footprint is source-backed. Its displayed height is a clearly labeled visualization estimate, not a measurement.';
    }
    if (queued['building_geometry'] == true) {
      return 'The site is located and usable now; BridgePoint has automatically queued a better building model for this property.';
    }
    return 'The site location is usable now and BridgePoint keeps upgrading the physical model as better geometry arrives.';
  }

  String _frontPlain(Map<String, dynamic> front, Map<String, dynamic> queued) {
    if (front.isNotEmpty) {
      return 'A real exterior/street image is attached from ${_clean(front['source_name'], 'a public or licensed source')} and was captured ${_date(front['captured_at'])}.';
    }
    if (queued['front_imagery'] == true) {
      return 'A front/exterior frame is being searched automatically across approved imagery sources.';
    }
    return 'No synthetic front photo is used; BridgePoint keeps the physical/aerial context visible instead.';
  }

  String _aerialPlain(Map<String, dynamic> aerial, List<Map<String, dynamic>> history) {
    if (aerial.isNotEmpty && history.isNotEmpty) {
      return 'Current aerial context is available, plus ${history.length} dated historical aerial observation${history.length == 1 ? '' : 's'}.';
    }
    if (aerial.isNotEmpty) {
      return 'Current aerial context is available. Historical imagery stays separate until BridgePoint has a dated source.';
    }
    return 'Aerial context is not being fabricated; it appears when the property location can be resolved.';
  }

  List<String> _intelligenceLines(Map<String, dynamic> intel) {
    if (intel.isEmpty) {
      return const [
        'The physical property view remains useful even when a customer-safe intelligence snapshot is still being assembled.',
      ];
    }
    final score = _map(intel['score']);
    final signals = _rows(intel['signals']);
    final patterns = _rows(intel['patterns']);
    final lines = <String>[];
    if (score['available'] == true) {
      lines.add(
        'BridgePoint currently prioritizes this property at ${_clean(score['priority_tier'], 'a reviewed tier')} from linked evidence—not from one mystery data point.',
      );
    }
    lines.add('${signals.length} customer-visible signal${signals.length == 1 ? '' : 's'} are linked to this property.');
    lines.add('${patterns.length} multi-signal pattern${patterns.length == 1 ? '' : 's'} are currently visible.');
    return lines;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
      );
}

class _PlainEnglishCard extends StatelessWidget {
  const _PlainEnglishCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF081624),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ...lines.where((x) => x.trim().isNotEmpty).map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(color: Color(0xFFD7E4F0), height: 1.42),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
}

class _NetworkEvidenceImage extends StatelessWidget {
  const _NetworkEvidenceImage({
    required this.item,
    this.emptyIcon = Icons.image_not_supported_outlined,
    this.emptyTitle = 'Visual evidence is still enriching',
    this.emptyBody = 'BridgePoint keeps the other verified property views available while this source is upgraded.',
  });

  final Map<String, dynamic> item;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  String _url() {
    for (final key in ['thumbnail_url', 'media_url']) {
      var value = '${item[key] ?? ''}'.trim();
      if (value.isEmpty || value == 'null') continue;
      value = value.replaceAll('{{sizeprefix}}', 'th');
      return value;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final url = _url();
    if (url.isEmpty) {
      return _VisualEmpty(icon: emptyIcon, title: emptyTitle, body: emptyBody);
    }
    final source = '${item['source_name'] ?? item['provider'] ?? 'Visual source'}'.trim();
    final captured = '${item['captured_at'] ?? ''}'.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFF06111E),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _VisualEmpty(
                  icon: emptyIcon,
                  title: 'Visual source did not render',
                  body: 'The property record remains usable and BridgePoint will retry or use the next approved visual source.',
                ),
              ),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 9,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xE805101C),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Text(
                [
                  if (source.isNotEmpty && source != 'null') source,
                  if (captured.isNotEmpty && captured != 'null') 'captured ${captured.split('T').first}',
                  if (item['reference_only'] == true) 'context only',
                ].join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualEmpty extends StatelessWidget {
  const _VisualEmpty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const RadialGradient(
            center: Alignment(.1, -.35),
            radius: 1.2,
            colors: [Color(0xFF102A42), Color(0xFF040B14)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 42, color: const Color(0xFF48E1FF)),
                const SizedBox(height: 10),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SiteTwinCanvas extends StatefulWidget {
  const _SiteTwinCanvas({required this.site});
  final Map<String, dynamic> site;

  @override
  State<_SiteTwinCanvas> createState() => _SiteTwinCanvasState();
}

class _SiteTwinCanvasState extends State<_SiteTwinCanvas> {
  double _yaw = -.58;
  double _pitch = .60;
  double _zoom = 1;
  double _startZoom = 1;
  Offset _travel = Offset.zero;
  bool _walk = false;

  List<Map<String, dynamic>> get _buildings {
    final raw = widget.site['buildings'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final buildings = _buildings;
    if (buildings.isEmpty) {
      return _VisualEmpty(
        icon: Icons.view_in_ar_rounded,
        title: '3D site is live; structure detail is enriching',
        body:
            'BridgePoint already knows where this property is. The national building-footprint lanes are attaching the source-backed structure automatically.',
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _startZoom = _zoom,
            onScaleUpdate: (d) {
              setState(() {
                if (_walk) {
                  _travel += d.focalPointDelta;
                } else {
                  _yaw += d.focalPointDelta.dx * .010;
                  _pitch = (_pitch - d.focalPointDelta.dy * .005).clamp(.18, 1.25);
                }
                if (d.pointerCount > 1) {
                  _zoom = (_startZoom * d.scale).clamp(.45, 4.5);
                }
              });
            },
            child: ColoredBox(
              color: const Color(0xFF030A12),
              child: CustomPaint(
                painter: _SitePainter(
                  buildings: buildings,
                  yaw: _yaw,
                  pitch: _pitch,
                  zoom: _zoom,
                  travel: _travel,
                ),
              ),
            ),
          ),
          Positioned(
            left: 9,
            top: 9,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.threed_rotation_rounded, size: 15), label: Text('Orbit')),
                ButtonSegment(value: true, icon: Icon(Icons.directions_walk_rounded, size: 15), label: Text('Walk')),
              ],
              selected: {_walk},
              onSelectionChanged: (v) => setState(() => _walk = v.first),
            ),
          ),
          Positioned(
            right: 9,
            top: 9,
            child: IconButton.filledTonal(
              tooltip: 'Reset 3D view',
              onPressed: () => setState(() {
                _yaw = -.58;
                _pitch = .60;
                _zoom = 1;
                _travel = Offset.zero;
              }),
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 9,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xE805101C),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Text(
                '${widget.site['building_count'] ?? buildings.length} structures • ${widget.site['structure_mode'] ?? 'physical context'} • drag to ${_walk ? 'move through site' : 'orbit'} • pinch to zoom',
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SitePainter extends CustomPainter {
  const _SitePainter({
    required this.buildings,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.travel,
  });

  final List<Map<String, dynamic>> buildings;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset travel;

  List<List<Offset>> _rings(dynamic geometry) {
    if (geometry is! Map) return const [];
    final g = Map<String, dynamic>.from(geometry);
    final type = '${g['type'] ?? ''}';
    final coords = g['coordinates'];
    final out = <List<Offset>>[];

    void addRing(dynamic ring) {
      if (ring is! List) return;
      final points = <Offset>[];
      for (final p in ring) {
        if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
          points.add(Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()));
        }
      }
      if (points.length >= 3) out.add(points);
    }

    if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
      addRing(coords.first);
    } else if (type == 'MultiPolygon' && coords is List) {
      for (final poly in coords) {
        if (poly is List && poly.isNotEmpty) addRing(poly.first);
      }
    }
    return out;
  }

  double _n(dynamic value, [double fallback = 8.5]) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scene = <_SceneBuilding>[];
    final all = <Offset>[];
    for (final b in buildings) {
      for (final ring in _rings(b['geometry'])) {
        all.addAll(ring);
        scene.add(
          _SceneBuilding(
            ring: ring,
            height: _n(b['render_height_m']).clamp(2.0, 180.0),
            target: b['is_target'] == true,
            estimated: '${b['height_source'] ?? ''}' == 'ESTIMATED_VISUALIZATION_ONLY',
          ),
        );
      }
    }
    if (all.isEmpty) return;

    var minX = all.first.dx;
    var maxX = all.first.dx;
    var minY = all.first.dy;
    var maxY = all.first.dy;
    for (final p in all.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final span = math.max((maxX - minX).abs(), (maxY - minY).abs());
    final scale = span <= 0 ? 1.0 : (math.min(size.width, size.height) * .68 / span) * zoom;
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final pitchScale = .28 + math.cos(pitch).abs() * .62;
    final center = size.center(Offset.zero) + travel;

    Offset project(Offset p, [double z = 0]) {
      final x = (p.dx - cx) * scale;
      final y = -(p.dy - cy) * scale;
      final rx = x * cosY - y * sinY;
      final ry = x * sinY + y * cosY;
      return center + Offset(rx, ry * pitchScale - z * (2.0 + pitch * 1.1));
    }

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = -7; i <= 7; i++) {
      canvas.drawLine(Offset(0, center.dy + i * 32), Offset(size.width, center.dy + i * 32), grid);
      canvas.drawLine(Offset(center.dx + i * 42, 0), Offset(center.dx + i * 42, size.height), grid);
    }

    scene.sort((a, b) {
      final ay = a.ring.fold<double>(0, (s, p) => s + p.dy) / a.ring.length;
      final by = b.ring.fold<double>(0, (s, p) => s + p.dy) / b.ring.length;
      return by.compareTo(ay);
    });

    for (final item in scene) {
      final base = item.ring.map((p) => project(p)).toList();
      final top = item.ring.map((p) => project(p, item.height)).toList();
      final accent = item.target ? const Color(0xFF48E1FF) : const Color(0xFF7896B2);
      final wall = Paint()
        ..color = accent.withValues(alpha: item.target ? .38 : .22)
        ..style = PaintingStyle.fill;
      final roof = Paint()
        ..color = accent.withValues(alpha: item.estimated ? .48 : .72)
        ..style = PaintingStyle.fill;
      final edge = Paint()
        ..color = accent.withValues(alpha: item.target ? .95 : .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.target ? 1.8 : 1.0;

      for (var i = 0; i < base.length; i++) {
        final j = (i + 1) % base.length;
        final path = Path()
          ..moveTo(base[i].dx, base[i].dy)
          ..lineTo(base[j].dx, base[j].dy)
          ..lineTo(top[j].dx, top[j].dy)
          ..lineTo(top[i].dx, top[i].dy)
          ..close();
        canvas.drawPath(path, wall);
      }
      final roofPath = Path()..moveTo(top.first.dx, top.first.dy);
      for (final p in top.skip(1)) {
        roofPath.lineTo(p.dx, p.dy);
      }
      roofPath.close();
      canvas.drawPath(roofPath, roof);
      canvas.drawPath(roofPath, edge);
      if (item.estimated) {
        final dash = Paint()
          ..color = const Color(0xFFFFC95E).withValues(alpha: .75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        for (var i = 0; i < top.length; i += 2) {
          canvas.drawCircle(top[i], 1.8, dash);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SitePainter oldDelegate) =>
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.zoom != zoom ||
      oldDelegate.travel != travel ||
      oldDelegate.buildings != buildings;
}

class _SceneBuilding {
  const _SceneBuilding({
    required this.ring,
    required this.height,
    required this.target,
    required this.estimated,
  });

  final List<Offset> ring;
  final double height;
  final bool target;
  final bool estimated;
}

class _TwinLoading extends StatelessWidget {
  const _TwinLoading();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF030A12),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 13),
                Text('Assembling live property twin…', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text(
                  'Physical model • imagery • evidence • intelligence',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB5C6D9), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TwinError extends StatelessWidget {
  const _TwinError({required this.onRetry, required this.onEvidence});
  final Future<void> Function() onRetry;
  final VoidCallback onEvidence;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF030A12),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sync_problem_rounded, color: Color(0xFFFFC95E), size: 38),
                const SizedBox(height: 10),
                const Text('Property Twin could not refresh', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                  'The evidence dossier is still available. Retry the unified twin or open the underlying property evidence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB5C6D9), height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async => onRetry(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onEvidence,
                      icon: const Icon(Icons.article_outlined),
                      label: const Text('Full evidence'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
