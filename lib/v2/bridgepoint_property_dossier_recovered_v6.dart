import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';
import 'bridgepoint_property_dossier_recovered_v5.dart' as recovered_v5;

/// Recovery V6 consolidates BridgePoint physical + intelligence capability into
/// a single Property Twin surface. The backend contract always returns the best
/// lawful/verified context available now and queues missing enrichment instead
/// of ending the customer flow at a generic "no data" state.
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
      _BridgePointPropertyDossierRecoveryV6State();
}

class _BridgePointPropertyDossierRecoveryV6State
    extends State<BridgePointPropertyDossierV2> {
  static const _cyan = Color(0xFF48E1FF);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);
  static const _green = Color(0xFF78E6A7);

  late Future<Map<String, dynamic>> _twin;

  @override
  void initState() {
    super.initState();
    _twin = _loadTwin();
  }

  @override
  void didUpdateWidget(covariant BridgePointPropertyDossierV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.propertyId != widget.propertyId) {
      _twin = _loadTwin();
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  Future<Map<String, dynamic>> _loadTwin() async {
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

  Future<void> _refreshTwin() async {
    final next = _loadTwin();
    setState(() => _twin = next);
    await next;
  }

  Future<void> _openTwin() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF040B14),
      barrierColor: Colors.black.withValues(alpha: .76),
      builder: (context) => FractionallySizedBox(
        heightFactor: .94,
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _twin,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final twin = snapshot.data ?? const <String, dynamic>{};
              return _TwinSheet(
                propertyId: widget.propertyId,
                twin: twin,
                onRefresh: _refreshTwin,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        recovered_v5.BridgePointPropertyDossierV2(
          propertyId: widget.propertyId,
          seed: widget.seed,
          asPage: widget.asPage,
        ),
        Positioned(
          left: 16,
          bottom: 92,
          child: SafeArea(
            top: false,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _twin,
              builder: (context, snapshot) {
                final twin = snapshot.data ?? const <String, dynamic>{};
                final caps = _map(twin['capabilities']);
                final queued = _map(twin['enrichment_queued']);
                final live = caps.values.where((v) => v == true).length;
                final upgrading = queued.values.where((v) => v == true).length;
                return FloatingActionButton.extended(
                  heroTag: 'property-twin-${widget.propertyId}',
                  onPressed: _openTwin,
                  backgroundColor: const Color(0xEE0B1B2C),
                  foregroundColor: _cyan,
                  elevation: 8,
                  icon: snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.hub_rounded),
                  label: Text(
                    upgrading > 0
                        ? 'Property Twin • $live live • $upgrading upgrading'
                        : 'Property Twin • $live live',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TwinSheet extends StatelessWidget {
  const _TwinSheet({
    required this.propertyId,
    required this.twin,
    required this.onRefresh,
  });

  final String propertyId;
  final Map<String, dynamic> twin;
  final Future<void> Function() onRefresh;

  static const _cyan = Color(0xFF48E1FF);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);
  static const _green = Color(0xFF78E6A7);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  bool _bool(Map<String, dynamic> map, String key) => map[key] == true;

  @override
  Widget build(BuildContext context) {
    final caps = _map(twin['capabilities']);
    final queued = _map(twin['enrichment_queued']);
    final site = _map(twin['site_3d']);
    final geometry = _map(twin['geometry']);
    final media = _map(twin['media']);
    final intel = _map(twin['intelligence']);
    final siteMode = '${site['site_mode'] ?? ''}';
    final structureMode = '${site['structure_mode'] ?? ''}';

    Widget capability(
      String label,
      IconData icon,
      bool available, {
      bool upgrading = false,
      String? detail,
    }) {
      final color = available ? _green : upgrading ? _amber : _muted;
      final state = available
          ? 'Available now'
          : upgrading
              ? 'Upgrade queued'
              : 'Best context only';
      return Container(
        width: 154,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF071321),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: .34)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(state, style: TextStyle(color: color, fontSize: 11.5)),
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10.5),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.hub_rounded, color: _cyan),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BridgePoint Property Twin',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Best available now • automatic fidelity upgrades',
                      style: TextStyle(color: _muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh twin',
                onPressed: () async => onRefresh(),
                icon: const Icon(Icons.refresh_rounded, color: _cyan),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  capability(
                    'Front',
                    Icons.home_rounded,
                    _bool(caps, 'front_imagery'),
                    upgrading: _bool(queued, 'front_imagery'),
                  ),
                  capability(
                    'Current aerial',
                    Icons.satellite_alt_rounded,
                    _bool(caps, 'aerial'),
                  ),
                  capability(
                    'Aerial history',
                    Icons.history_rounded,
                    _bool(caps, 'historical_aerial'),
                  ),
                  capability(
                    'Site 3D',
                    Icons.location_city_rounded,
                    _bool(caps, 'site_3d'),
                    upgrading: _bool(queued, 'building_geometry'),
                    detail: siteMode,
                  ),
                  capability(
                    'Structure 3D',
                    Icons.view_in_ar_rounded,
                    _bool(caps, 'structure_3d'),
                    upgrading: _bool(queued, 'building_geometry'),
                    detail: structureMode,
                  ),
                  capability(
                    'Intelligence',
                    Icons.insights_rounded,
                    intel.isNotEmpty,
                    detail: '${intel['tier'] ?? intel['score_tier'] ?? ''}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _TwinActionCard(
                icon: Icons.travel_explore_rounded,
                title: 'Walk the site context',
                subtitle:
                    'Navigate the focal property and nearby source-backed buildings. Height estimates are labeled when a measured/source height is not available.',
                enabled: site['site_context_available'] == true,
                queued: _bool(queued, 'building_geometry'),
                onTap: site['site_context_available'] == true
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Property Twin • Site 3D')),
                              body: SafeArea(child: _SiteTwinViewer(site: site)),
                            ),
                          ),
                        )
                    : null,
              ),
              const SizedBox(height: 9),
              _TwinActionCard(
                icon: Icons.view_in_ar_rounded,
                title: 'Open structure model',
                subtitle:
                    'Use the highest-fidelity source surfaces available; otherwise use the source footprint with an explicitly schematic massing height.',
                enabled: geometry.isNotEmpty,
                queued: _bool(queued, 'building_geometry'),
                onTap: geometry.isNotEmpty
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Property Twin • Structure')),
                              body: SafeArea(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: BridgePointBuildingGeometryV2(payload: geometry),
                                ),
                              ),
                            ),
                          ),
                        )
                    : null,
              ),
              const SizedBox(height: 9),
              _TwinActionCard(
                icon: Icons.photo_library_outlined,
                title: 'Physical media evidence',
                subtitle:
                    'Front/street, current aerial reference and dated historical imagery remain separate evidence classes so visual context is never misrepresented as proof of condition.',
                enabled: media.isNotEmpty,
                queued: _bool(queued, 'front_imagery'),
                onTap: null,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF071321),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _amber.withValues(alpha: .30)),
                ),
                child: Text(
                  _truthText(site, queued),
                  style: const TextStyle(color: _amber, fontSize: 11.6, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _truthText(
    Map<String, dynamic> site,
    Map<String, dynamic> queued,
  ) {
    final upgrades = <String>[];
    if (queued['geocode'] == true) upgrades.add('geocoding');
    if (queued['building_geometry'] == true) upgrades.add('building geometry');
    if (queued['front_imagery'] == true) upgrades.add('front imagery');
    final notice = '${site['truth_notice'] ?? ''}'.trim();
    if (upgrades.isEmpty) {
      return notice.isEmpty
          ? 'BridgePoint is showing the best currently verified physical-property context for this record.'
          : notice;
    }
    return 'BridgePoint is actively upgrading ${upgrades.join(', ')} for this property. '
        '${notice.isEmpty ? 'The current view remains usable and clearly labels any estimated visualization layer.' : notice}';
  }
}

class _TwinActionCard extends StatelessWidget {
  const _TwinActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.queued,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool queued;
  final VoidCallback? onTap;

  static const _cyan = Color(0xFF48E1FF);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF071321),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? _cyan : queued ? _amber : _muted),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11.2, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (enabled && onTap != null)
              const Icon(Icons.chevron_right_rounded, color: _cyan)
            else if (queued)
              const Chip(
                avatar: Icon(Icons.autorenew_rounded, size: 15),
                label: Text('Queued', style: TextStyle(fontSize: 10.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SiteTwinViewer extends StatefulWidget {
  const _SiteTwinViewer({required this.site});
  final Map<String, dynamic> site;

  @override
  State<_SiteTwinViewer> createState() => _SiteTwinViewerState();
}

class _SiteTwinViewerState extends State<_SiteTwinViewer> {
  static const _cyan = Color(0xFF48E1FF);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  double _yaw = -.55;
  double _pitch = .58;
  double _zoom = 1;
  double _gestureZoom = 1;
  Offset _travel = Offset.zero;
  bool _walkMode = false;

  List<Map<String, dynamic>> get _buildings {
    final raw = widget.site['buildings'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
  }

  void _reset() => setState(() {
        _yaw = -.55;
        _pitch = .58;
        _zoom = 1;
        _travel = Offset.zero;
      });

  @override
  Widget build(BuildContext context) {
    final buildings = _buildings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.threed_rotation_rounded, size: 16),
                      label: Text('Orbit'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.directions_walk_rounded, size: 16),
                      label: Text('Walk site'),
                    ),
                  ],
                  selected: {_walkMode},
                  onSelectionChanged: (v) => setState(() => _walkMode = v.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Reset scene',
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt_rounded, color: _cyan),
              ),
            ],
          ),
        ),
        Expanded(
          child: buildings.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Site context is geolocated and the building-geometry upgrade is queued. The scene will gain structures automatically as a verified/open geometry source lands.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.45),
                    ),
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (_) => _gestureZoom = _zoom,
                  onScaleUpdate: (d) {
                    setState(() {
                      if (_walkMode) {
                        _travel += d.focalPointDelta;
                      } else {
                        _yaw += d.focalPointDelta.dx * .010;
                        _pitch = (_pitch - d.focalPointDelta.dy * .005).clamp(.18, 1.25);
                      }
                      if (d.pointerCount > 1) {
                        _zoom = (_gestureZoom * d.scale).clamp(.45, 4.0);
                      }
                    });
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(.12, -.25),
                        radius: 1.35,
                        colors: [Color(0xFF112A43), Color(0xFF030A12)],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _SiteTwinPainter(
                        buildings: buildings,
                        yaw: _yaw,
                        pitch: _pitch,
                        zoom: _zoom,
                        travel: _travel,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
          color: const Color(0xFF071321),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_outlined, color: _amber, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${widget.site['building_count'] ?? buildings.length} buildings • '
                  '${widget.site['structure_mode'] ?? 'site context'} • '
                  '${widget.site['truth_notice'] ?? 'Source geometry is preferred; any display-only height estimate is labeled.'}',
                  style: const TextStyle(color: _amber, fontSize: 10.8, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SiteTwinPainter extends CustomPainter {
  const _SiteTwinPainter({
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

  @override
  void paint(Canvas canvas, Size size) {
    final items = <_SceneBuilding>[];
    final all = <Offset>[];
    for (final b in buildings) {
      for (final ring in _rings(b['geometry'])) {
        all.addAll(ring);
        final h = _asDouble(b['render_height_m']) ?? 8.5;
        items.add(_SceneBuilding(
          ring: ring,
          height: h.clamp(2.0, 180.0),
          target: b['is_target'] == true,
          estimated: '${b['height_source'] ?? ''}' == 'ESTIMATED_VISUALIZATION_ONLY',
        ));
      }
    }
    if (all.isEmpty) return;

    var minX = all.first.dx, maxX = all.first.dx, minY = all.first.dy, maxY = all.first.dy;
    for (final p in all.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final span = math.max((maxX - minX).abs(), (maxY - minY).abs());
    final scale = span <= 0 ? 1.0 : (math.min(size.width, size.height) * .70 / span) * zoom;
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final pitchScale = .28 + math.cos(pitch).abs() * .62;
    final center = size.center(Offset.zero) + travel;

    Offset project(Offset p, [double z = 0]) {
      final x = (p.dx - cx) * scale;
      final y = -(p.dy - cy) * scale;
      final rx = x * cosY - y * sinY;
      final ry = x * sinY + y * cosY;
      return center + Offset(rx, ry * pitchScale - z * (2.1 + pitch * 1.2));
    }

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = -6; i <= 6; i++) {
      canvas.drawLine(Offset(0, center.dy + i * 34), Offset(size.width, center.dy + i * 34), grid);
      canvas.drawLine(Offset(center.dx + i * 44, 0), Offset(center.dx + i * 44, size.height), grid);
    }

    items.sort((a, b) {
      final ay = a.ring.fold<double>(0, (s, p) => s + p.dy) / a.ring.length;
      final by = b.ring.fold<double>(0, (s, p) => s + p.dy) / b.ring.length;
      return by.compareTo(ay);
    });

    for (final item in items) {
      final base = item.ring.map((p) => project(p)).toList();
      final top = item.ring.map((p) => project(p, item.height)).toList();
      final wall = Paint()
        ..color = (item.target ? const Color(0xFF48E1FF) : const Color(0xFF587492))
            .withValues(alpha: item.target ? .38 : .24)
        ..style = PaintingStyle.fill;
      final roof = Paint()
        ..color = (item.target ? const Color(0xFF48E1FF) : const Color(0xFF8DB3D4))
            .withValues(alpha: item.estimated ? .48 : .72)
        ..style = PaintingStyle.fill;
      final edge = Paint()
        ..color = (item.target ? const Color(0xFF7AEAFF) : Colors.white)
            .withValues(alpha: item.target ? .90 : .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.target ? 1.8 : .8;

      for (var i = 0; i < base.length; i++) {
        final j = (i + 1) % base.length;
        final side = Path()
          ..moveTo(base[i].dx, base[i].dy)
          ..lineTo(base[j].dx, base[j].dy)
          ..lineTo(top[j].dx, top[j].dy)
          ..lineTo(top[i].dx, top[i].dy)
          ..close();
        canvas.drawPath(side, wall);
      }
      final roofPath = Path()..moveTo(top.first.dx, top.first.dy);
      for (final p in top.skip(1)) roofPath.lineTo(p.dx, p.dy);
      roofPath.close();
      canvas.drawPath(roofPath, roof);
      canvas.drawPath(roofPath, edge);
      if (item.target) {
        final centroid = top.reduce((a, b) => a + b) / top.length.toDouble();
        final marker = Paint()..color = const Color(0xFF48E1FF);
        canvas.drawCircle(centroid, 5.5, marker);
      }
    }
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}');
  }

  @override
  bool shouldRepaint(covariant _SiteTwinPainter oldDelegate) =>
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
