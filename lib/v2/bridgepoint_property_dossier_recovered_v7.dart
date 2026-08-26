import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';
import 'bridgepoint_property_dossier_recovered_v6.dart' as evidence_v6;

/// Primary BridgePoint property workspace.
///
/// V7 keeps the visual experience simple: 3D, Front, Aerial and History live
/// in one property surface. The full evidence dossier remains one tap away.
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
  State<BridgePointPropertyDossierV2> createState() => _PropertyTwinV7State();
}

enum _TwinView { site3d, front, aerial, history }

class _PropertyTwinV7State extends State<BridgePointPropertyDossierV2> {
  static const _bg = Color(0xFF030A12);
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
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_twin_v918',
        params: <String, dynamic>{'p_property_id': widget.propertyId},
      );
      return _map(raw);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    if (mounted) setState(() => _future = next);
    await next;
  }

  String _address() {
    for (final key in <String>[
      'full_address',
      'address',
      'property_address',
      'street_address',
    ]) {
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
    final body = FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TwinLoading();
        }
        final twin = snapshot.data ?? const <String, dynamic>{};
        if (twin.isEmpty) {
          return _TwinFailure(onRetry: _refresh, onEvidence: _openEvidence);
        }
        return _TwinWorkspace(
          address: _address(),
          twin: twin,
          view: _view,
          onView: (value) => setState(() => _view = value),
          onRefresh: _refresh,
          onEvidence: _openEvidence,
        );
      },
    );

    if (!widget.asPage) return body;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF06111E),
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Property Twin',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              _address(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 10.5),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh property twin',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: _cyan),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _TwinWorkspace extends StatelessWidget {
  const _TwinWorkspace({
    required this.address,
    required this.twin,
    required this.view,
    required this.onView,
    required this.onRefresh,
    required this.onEvidence,
  });

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
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String _clean(dynamic value, [String fallback = '—']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _date(dynamic value) {
    final raw = _clean(value, 'date varies by source');
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final caps = _map(twin['capabilities']);
    final queued = _map(twin['enrichment_queued']);
    final site = _map(twin['site_3d']);
    final media = _map(twin['media']);
    final geometry = _map(twin['geometry']);
    final intelligence = _map(twin['intelligence']);
    final front = _map(media['front']);
    final aerial = _map(media['aerial_current']);
    final history = _rows(media['aerial_history']);
    final live = caps.values.where((value) => value == true).length;
    final upgrading = queued.values.where((value) => value == true).length;

    return ColoredBox(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0E2A41), Color(0xFF071321)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _cyan.withValues(alpha: .24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.hub_rounded, color: _cyan),
                      SizedBox(width: 8),
                      Text(
                        'LIVE PROPERTY TWIN',
                        style: TextStyle(
                          color: _cyan,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      _Pill('$live live', _green),
                      if (upgrading > 0) _Pill('$upgrading upgrading', _amber),
                      _Pill('${site['building_count'] ?? 0} nearby structures', _cyan),
                      _Pill(_clean(site['structure_mode'], 'physical context'), _muted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                _viewChip(_TwinView.site3d, '3D', Icons.view_in_ar_rounded),
                _viewChip(_TwinView.front, 'Front', Icons.home_rounded),
                _viewChip(_TwinView.aerial, 'Aerial', Icons.satellite_alt_rounded),
                _viewChip(_TwinView.history, 'History', Icons.history_rounded),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: MediaQuery.sizeOf(context).width < 650 ? 1.18 : 1.8,
              child: _visual(
                site: site,
                front: front,
                aerial: aerial,
                history: history,
                queued: queued,
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'What this means in plain English',
              icon: Icons.translate_rounded,
              color: _cyan,
              lines: <String>[
                caps['geocoded'] == true
                    ? 'This property is pinned to a real map location.'
                    : 'BridgePoint is still resolving the exact location and will not guess it.',
                _structurePlain(site, queued),
                _frontPlain(front, queued),
                _aerialPlain(aerial, history),
              ],
            ),
            const SizedBox(height: 10),
            _InfoCard(
              title: 'Intelligence, not a mystery score',
              icon: Icons.insights_rounded,
              color: _green,
              lines: _intelligenceLines(intelligence),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEvidence,
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Full evidence'),
                  ),
                ),
                if (geometry.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openStructure(context, geometry),
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
                children: <Widget>[
                  const Icon(Icons.verified_outlined, color: _amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _clean(
                        site['truth_notice'],
                        'BridgePoint separates source-backed facts from visualization estimates and keeps the evidence available for review.',
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

  Widget _viewChip(_TwinView value, String label, IconData icon) {
    final selected = value == view;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onView(value),
      avatar: Icon(icon, size: 17, color: selected ? Colors.black : _cyan),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: _cyan,
      backgroundColor: const Color(0xFF0A1725),
      side: BorderSide(color: _cyan.withValues(alpha: selected ? .75 : .22)),
    );
  }

  Widget _visual({
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
        return _EvidenceImage(
          item: front,
          emptyIcon: Icons.home_rounded,
          emptyTitle: queued['front_imagery'] == true
              ? 'Front imagery is upgrading'
              : 'Front imagery is not attached yet',
          emptyBody:
              'BridgePoint will not manufacture a house photo. The 3D and aerial views stay usable while approved imagery sources are searched.',
        );
      case _TwinView.aerial:
        return _EvidenceImage(
          item: aerial,
          emptyIcon: Icons.satellite_alt_rounded,
          emptyTitle: 'Current aerial context is upgrading',
          emptyBody: 'Aerial context appears as soon as the property location is resolved.',
        );
      case _TwinView.history:
        if (history.isEmpty) {
          return const _VisualEmpty(
            icon: Icons.history_rounded,
            title: 'Historical imagery is expanding nationally',
            body:
                'Current imagery stays separate from dated historical evidence. BridgePoint does not relabel a live basemap as history.',
          );
        }
        return PageView(
          children: history
              .map((item) => _EvidenceImage(item: item))
              .toList(growable: false),
        );
    }
  }

  void _openStructure(BuildContext context, Map<String, dynamic> geometry) {
    Navigator.of(context).push(
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
    );
  }

  String _structurePlain(Map<String, dynamic> site, Map<String, dynamic> queued) {
    final mode = _clean(site['structure_mode'], 'TARGET_BUILDING_PENDING');
    if (mode == 'SOURCE_FOOTPRINT_HEIGHT') {
      return 'The building footprint and displayed height come from source-backed physical data.';
    }
    if (mode == 'SOURCE_FOOTPRINT_ESTIMATED_HEIGHT') {
      return 'The footprint is source-backed. Displayed height is clearly labeled as a visualization estimate, not a measurement.';
    }
    if (queued['building_geometry'] == true) {
      return 'The site is usable now and a better building model has been queued automatically.';
    }
    return 'BridgePoint keeps upgrading the physical model when better geometry becomes available.';
  }

  String _frontPlain(Map<String, dynamic> front, Map<String, dynamic> queued) {
    if (front.isNotEmpty) {
      return 'A real exterior/street image is attached from ${_clean(front['source_name'], 'an approved source')}, captured ${_date(front['captured_at'])}.';
    }
    if (queued['front_imagery'] == true) {
      return 'BridgePoint is automatically searching approved exterior imagery sources for this property.';
    }
    return 'No synthetic front photo is used; the physical and aerial views remain available instead.';
  }

  String _aerialPlain(Map<String, dynamic> aerial, List<Map<String, dynamic>> history) {
    if (aerial.isNotEmpty && history.isNotEmpty) {
      return 'Current aerial context is available with ${history.length} dated historical observation${history.length == 1 ? '' : 's'}.';
    }
    if (aerial.isNotEmpty) {
      return 'Current aerial context is available. Historical imagery remains separate until BridgePoint has a dated source.';
    }
    return 'Aerial context is not fabricated; it appears when location resolution supports it.';
  }

  List<String> _intelligenceLines(Map<String, dynamic> intelligence) {
    if (intelligence.isEmpty) {
      return const <String>[
        'The physical property view remains usable while customer-safe intelligence is assembled.',
      ];
    }
    final score = _map(intelligence['score']);
    final signals = _rows(intelligence['signals']);
    final patterns = _rows(intelligence['patterns']);
    final lines = <String>[];
    if (score['available'] == true) {
      lines.add(
        'Priority is ${_clean(score['priority_tier'], 'reviewed')} and is tied to linked evidence, not one unexplained number.',
      );
    }
    lines.add('${signals.length} visible signal${signals.length == 1 ? '' : 's'} are linked to this property.');
    lines.add('${patterns.length} multi-signal pattern${patterns.length == 1 ? '' : 's'} are visible.');
    return lines;
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF081624),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ...lines.where((line) => line.trim().isNotEmpty).map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
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
}

class _EvidenceImage extends StatelessWidget {
  const _EvidenceImage({
    required this.item,
    this.emptyIcon = Icons.image_not_supported_outlined,
    this.emptyTitle = 'Visual evidence is upgrading',
    this.emptyBody = 'BridgePoint keeps other verified property views available while this source is enriched.',
  });

  final Map<String, dynamic> item;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  String _url() {
    for (final key in <String>['thumbnail_url', 'media_url']) {
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
        children: <Widget>[
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
                  body:
                      'BridgePoint keeps the property usable and can retry or use the next approved visual source.',
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
                <String>[
                  if (source.isNotEmpty && source != 'null') source,
                  if (captured.isNotEmpty && captured != 'null')
                    'captured ${captured.split('T').first}',
                  if (item['reference_only'] == true) 'context only',
                ].join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualEmpty extends StatelessWidget {
  const _VisualEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const RadialGradient(
          center: Alignment(.1, -.35),
          radius: 1.2,
          colors: <Color>[Color(0xFF102A42), Color(0xFF040B14)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 42, color: const Color(0xFF48E1FF)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB5C6D9),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  double _gestureZoom = 1;
  Offset _travel = Offset.zero;
  bool _walk = false;

  List<Map<String, dynamic>> get _buildings {
    final raw = widget.site['buildings'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final buildings = _buildings;
    if (buildings.isEmpty) {
      return const _VisualEmpty(
        icon: Icons.view_in_ar_rounded,
        title: '3D site is live; structure detail is upgrading',
        body:
            'The property location remains usable while national footprint lanes attach a source-backed structure automatically.',
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _gestureZoom = _zoom,
            onScaleUpdate: (details) {
              setState(() {
                if (_walk) {
                  _travel += details.focalPointDelta;
                } else {
                  _yaw += details.focalPointDelta.dx * .010;
                  _pitch = (_pitch - details.focalPointDelta.dy * .005)
                      .clamp(.18, 1.25)
                      .toDouble();
                }
                if (details.pointerCount > 1) {
                  _zoom = (_gestureZoom * details.scale)
                      .clamp(.45, 4.5)
                      .toDouble();
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
            child: Row(
              children: <Widget>[
                _modeButton(false, Icons.threed_rotation_rounded, 'Orbit'),
                const SizedBox(width: 6),
                _modeButton(true, Icons.directions_walk_rounded, 'Walk'),
              ],
            ),
          ),
          Positioned(
            right: 9,
            top: 9,
            child: IconButton.filledTonal(
              tooltip: 'Reset 3D view',
              onPressed: _reset,
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
              ),
              child: Text(
                '${widget.site['building_count'] ?? buildings.length} structures • '
                '${widget.site['structure_mode'] ?? 'physical context'} • '
                'drag to ${_walk ? 'move through site' : 'orbit'} • pinch to zoom',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(bool walk, IconData icon, String label) {
    final selected = _walk == walk;
    return FilledButton.tonalIcon(
      onPressed: () => setState(() => _walk = walk),
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: selected ? const Color(0xFF48E1FF) : Colors.white,
      ),
    );
  }

  void _reset() {
    setState(() {
      _yaw = -.58;
      _pitch = .60;
      _zoom = 1;
      _gestureZoom = 1;
      _travel = Offset.zero;
    });
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
    if (geometry is! Map) return const <List<Offset>>[];
    final data = Map<String, dynamic>.from(geometry);
    final type = '${data['type'] ?? ''}';
    final coordinates = data['coordinates'];
    final output = <List<Offset>>[];

    void addRing(dynamic value) {
      if (value is! List) return;
      final ring = <Offset>[];
      for (final point in value) {
        if (point is List &&
            point.length >= 2 &&
            point[0] is num &&
            point[1] is num) {
          ring.add(
            Offset(
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ),
          );
        }
      }
      if (ring.length >= 3) output.add(ring);
    }

    if (type == 'Polygon' && coordinates is List && coordinates.isNotEmpty) {
      addRing(coordinates.first);
    } else if (type == 'MultiPolygon' && coordinates is List) {
      for (final polygon in coordinates) {
        if (polygon is List && polygon.isNotEmpty) addRing(polygon.first);
      }
    }
    return output;
  }

  double _number(dynamic value, [double fallback = 8.5]) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? fallback;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scene = <_SceneBuilding>[];
    final allPoints = <Offset>[];

    for (final building in buildings) {
      for (final ring in _rings(building['geometry'])) {
        allPoints.addAll(ring);
        scene.add(
          _SceneBuilding(
            ring: ring,
            height: _number(building['render_height_m'])
                .clamp(2.0, 180.0)
                .toDouble(),
            target: building['is_target'] == true,
            estimated:
                '${building['height_source'] ?? ''}' == 'ESTIMATED_VISUALIZATION_ONLY',
          ),
        );
      }
    }
    if (allPoints.isEmpty) return;

    var minX = allPoints.first.dx;
    var maxX = allPoints.first.dx;
    var minY = allPoints.first.dy;
    var maxY = allPoints.first.dy;
    for (final point in allPoints.skip(1)) {
      minX = math.min(minX, point.dx).toDouble();
      maxX = math.max(maxX, point.dx).toDouble();
      minY = math.min(minY, point.dy).toDouble();
      maxY = math.max(maxY, point.dy).toDouble();
    }

    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;
    final span = math
        .max((maxX - minX).abs(), (maxY - minY).abs())
        .toDouble();
    final shortest = math.min(size.width, size.height).toDouble();
    final scale = span <= 0 ? 1.0 : (shortest * .68 / span) * zoom;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final pitchScale = .28 + math.cos(pitch).abs() * .62;
    final center = size.center(Offset.zero) + travel;

    Offset project(Offset point, [double z = 0]) {
      final x = (point.dx - cx) * scale;
      final y = -(point.dy - cy) * scale;
      final rx = x * cosYaw - y * sinYaw;
      final ry = x * sinYaw + y * cosYaw;
      return center + Offset(rx, ry * pitchScale - z * (2.0 + pitch * 1.1));
    }

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = -7; i <= 7; i++) {
      canvas.drawLine(
        Offset(0, center.dy + i * 32.0),
        Offset(size.width, center.dy + i * 32.0),
        grid,
      );
      canvas.drawLine(
        Offset(center.dx + i * 42.0, 0),
        Offset(center.dx + i * 42.0, size.height),
        grid,
      );
    }

    scene.sort((a, b) {
      final ay = a.ring.fold<double>(0, (sum, p) => sum + p.dy) / a.ring.length;
      final by = b.ring.fold<double>(0, (sum, p) => sum + p.dy) / b.ring.length;
      return by.compareTo(ay);
    });

    for (final building in scene) {
      final base = building.ring.map((point) => project(point)).toList();
      final top = building.ring
          .map((point) => project(point, building.height))
          .toList();
      if (base.isEmpty || top.isEmpty) continue;

      final accent = building.target
          ? const Color(0xFF48E1FF)
          : const Color(0xFF7896B2);
      final walls = Paint()
        ..color = accent.withValues(alpha: building.target ? .38 : .22)
        ..style = PaintingStyle.fill;
      final roof = Paint()
        ..color = accent.withValues(alpha: building.estimated ? .48 : .72)
        ..style = PaintingStyle.fill;
      final edge = Paint()
        ..color = accent.withValues(alpha: building.target ? .95 : .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = building.target ? 1.8 : 1.0;

      for (var i = 0; i < base.length; i++) {
        final next = (i + 1) % base.length;
        final wall = Path()
          ..moveTo(base[i].dx, base[i].dy)
          ..lineTo(base[next].dx, base[next].dy)
          ..lineTo(top[next].dx, top[next].dy)
          ..lineTo(top[i].dx, top[i].dy)
          ..close();
        canvas.drawPath(wall, walls);
      }

      final roofPath = Path()..moveTo(top.first.dx, top.first.dy);
      for (final point in top.skip(1)) {
        roofPath.lineTo(point.dx, point.dy);
      }
      roofPath.close();
      canvas.drawPath(roofPath, roof);
      canvas.drawPath(roofPath, edge);

      if (building.estimated) {
        final estimateMark = Paint()
          ..color = const Color(0xFFFFC95E).withValues(alpha: .78)
          ..style = PaintingStyle.fill;
        for (var i = 0; i < top.length; i += 2) {
          canvas.drawCircle(top[i], 1.8, estimateMark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SitePainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.travel != travel ||
        oldDelegate.buildings != buildings;
  }
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
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF030A12),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 13),
              Text(
                'Assembling live property twin…',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
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
}

class _TwinFailure extends StatelessWidget {
  const _TwinFailure({required this.onRetry, required this.onEvidence});

  final Future<void> Function() onRetry;
  final VoidCallback onEvidence;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF030A12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.sync_problem_rounded, color: Color(0xFFFFC95E), size: 38),
              const SizedBox(height: 10),
              const Text(
                'Property Twin could not refresh',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Retry the unified twin or open the underlying property evidence.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB5C6D9), height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () {
                      onRetry();
                    },
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
}
