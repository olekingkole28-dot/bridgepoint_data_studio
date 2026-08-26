import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_source_surface_model_v2.dart';

class BridgePointBuildingGeometryV2 extends StatefulWidget {
  const BridgePointBuildingGeometryV2({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  State<BridgePointBuildingGeometryV2> createState() =>
      _BridgePointBuildingGeometryRecoveredV3State();
}

class _BridgePointBuildingGeometryRecoveredV3State
    extends State<BridgePointBuildingGeometryV2> {
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  bool _massing = true;
  double _yaw = -.62;
  double _pitch = .62;
  double _zoom = 1;
  double _gestureZoom = 1;
  bool _sourceLoading = false;
  Map<String, dynamic> _source3d = const {};

  @override
  void initState() {
    super.initState();
    _loadSource3d();
  }

  @override
  void didUpdateWidget(covariant BridgePointBuildingGeometryV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ('${oldWidget.payload['property_id'] ?? ''}' !=
        '${widget.payload['property_id'] ?? ''}') {
      _source3d = const {};
      _reset();
      _loadSource3d();
    }
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _yaw = -.62;
      _pitch = .62;
      _zoom = 1;
    });
  }

  Future<void> _loadSource3d() async {
    final id = '${widget.payload['property_id'] ?? ''}'.trim();
    if (id.isEmpty || _sourceLoading) return;
    if (mounted) setState(() => _sourceLoading = true);
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_property_source_3d_v855',
        params: {'p_property_id': id},
      );
      if (!mounted) return;
      setState(() {
        _source3d = raw is Map<String, dynamic>
            ? raw
            : raw is Map
                ? Map<String, dynamic>.from(raw)
                : const {};
      });
    } catch (_) {
      // The L1 footprint/height model remains useful if L2 source XYZ is absent.
    } finally {
      if (mounted) setState(() => _sourceLoading = false);
    }
  }

  List<Map<String, dynamic>> get _rows {
    final raw = widget.payload['geometry'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  String _fidelity(List<Map<String, dynamic>> rows) {
    final values = rows
        .map((row) => '${row['fidelity_level'] ?? ''}'.toUpperCase())
        .toSet();
    if (values.any((x) => x.contains('L2'))) return 'L2 source surfaces';
    if (values.any((x) => x.contains('L1'))) return 'L1 building massing';
    return 'L0 footprint / shell';
  }

  String _height(List<Map<String, dynamic>> rows) {
    final heights = rows
        .map((row) => _double(row['height_m']))
        .whereType<double>()
        .where((x) => x > 0)
        .toList();
    if (heights.isEmpty) return 'Height unavailable';
    return 'Height ${heights.reduce(math.max).toStringAsFixed(1)} m';
  }

  String _source(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 'No linked geometry source';
    final row = rows.first;
    final provider =
        '${row['source_provider'] ?? row['source_name'] ?? 'Source-backed'}'
            .trim();
    final year = '${row['source_year'] ?? ''}'.trim();
    return year.isEmpty ? provider : '$provider • $year';
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.payload['locked'] == true;
    final rows = _rows;
    final sourceAvailable = _source3d['available'] == true;
    final truth = '${widget.payload['truth_notice'] ?? ''}'.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.view_in_ar_rounded, color: _cyan),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interactive property 3D',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Best available source geometry, with fidelity shown honestly',
                        style: TextStyle(color: _muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Reset view',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded, color: _cyan),
                ),
              ],
            ),
            if (_sourceLoading) ...[
              const SizedBox(height: 9),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 10),
            if (locked)
              const _Empty3d(
                title: '3D is locked for this account',
                body:
                    'The property can still be used, but this account does not include the Digital Twin / imagery-change geometry entitlement.',
                icon: Icons.lock_outline_rounded,
              )
            else if (sourceAvailable) ...[
              BridgePointSourceSurfaceModelV2(payload: _source3d),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Show schematic fallback too',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Footprint + height massing retained as supporting geometry',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                  children: [_massingViewer(rows)],
                ),
              ],
            ] else if (rows.isNotEmpty)
              _massingViewer(rows)
            else
              const _Empty3d(
                title: 'No linked 3D geometry yet',
                body:
                    'BridgePoint has not linked a source-backed building footprint to this property yet. It does not invent a building model just to fill the screen.',
                icon: Icons.layers_clear_outlined,
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(sourceAvailable ? 'Best: source XYZ' : _fidelity(rows), _cyan),
                if (rows.isNotEmpty) _Badge(_height(rows), _blue),
                if (rows.isNotEmpty) _Badge(_source(rows), _muted),
                _Badge(
                  sourceAvailable
                      ? 'Drag to rotate • pinch to zoom'
                      : rows.isNotEmpty
                          ? 'Drag to rotate • pinch to zoom'
                          : 'Awaiting geometry',
                  _amber,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              sourceAvailable
                  ? 'Plain English: this property has higher-fidelity source XYZ surfaces. That is stronger than a simple footprint extrusion, but it still is not called an engineering survey or exact replica unless the source evidence supports that claim.'
                  : rows.isNotEmpty
                      ? 'Plain English: BridgePoint is turning the real linked building footprint into a rotatable shape using the best available height. The footprint is source-backed; the walls/roof form are schematic massing, not a photograph, BIM file, engineering survey, or exact replica.'
                      : 'Plain English: there is not enough verified physical geometry for BridgePoint to draw a truthful building yet.',
              style: const TextStyle(color: _amber, fontSize: 12.2, height: 1.45),
            ),
            if (truth.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                truth,
                style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
              ),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 6),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Where this geometry came from',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
                children: [
                  for (final row in rows.take(12)) _Provenance(row: row),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _massingViewer(List<Map<String, dynamic>> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.crop_square_rounded, size: 16),
                label: Text('Footprint'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.view_in_ar_rounded, size: 16),
                label: Text('3D massing'),
              ),
            ],
            selected: {_massing},
            onSelectionChanged: (value) =>
                setState(() => _massing = value.first),
          ),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxWidth < 460 ? 340.0 : 470.0;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => _gestureZoom = _zoom,
              onScaleUpdate: (details) {
                setState(() {
                  _yaw += details.focalPointDelta.dx * .012;
                  _pitch = (_pitch - details.focalPointDelta.dy * .0065)
                      .clamp(.12, 1.30);
                  if (details.pointerCount > 1) {
                    _zoom = (_gestureZoom * details.scale).clamp(.58, 2.7);
                  }
                });
              },
              child: Container(
                height: h,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(.18, -.20),
                    radius: 1.25,
                    colors: [Color(0xFF112841), Color(0xFF040B13)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cyan.withValues(alpha: .25)),
                ),
                child: CustomPaint(
                  painter: _RotatableMassingPainter(
                    rows: rows,
                    massing: _massing,
                    yaw: _yaw,
                    pitch: _pitch,
                    zoom: _zoom,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.swipe_rounded, size: 17, color: _cyan),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Drag around the property • pinch to zoom • reset with the arrow above',
                style: TextStyle(color: _muted, fontSize: 11.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
        ),
      );
}

class _Empty3d extends StatelessWidget {
  const _Empty3d({required this.title, required this.body, required this.icon});
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF07131F),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFB5C6D9)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(color: Color(0xFFB5C6D9), height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _P3 {
  const _P3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

class _Face {
  const _Face(this.points, this.depth, this.roof);
  final List<Offset> points;
  final double depth;
  final bool roof;
}

class _MassingPoly {
  const _MassingPoly(this.ring, this.heightM);
  final List<_P3> ring;
  final double heightM;
}

class _RotatableMassingPainter extends CustomPainter {
  const _RotatableMassingPainter({
    required this.rows,
    required this.massing,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  final List<Map<String, dynamic>> rows;
  final bool massing;
  final double yaw;
  final double pitch;
  final double zoom;

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);

  @override
  void paint(Canvas canvas, Size size) {
    final polys = <_MassingPoly>[];
    for (final row in rows) {
      final g = row['geometry'];
      if (g is! Map) continue;
      final h = _asDouble(row['height_m']) ?? 0;
      for (final ring in _rings2d(Map<String, dynamic>.from(g))) {
        if (ring.length >= 3) {
          polys.add(_MassingPoly(ring, massing ? math.max(0, h) : 0));
        }
      }
    }

    if (polys.isEmpty) {
      _text(canvas, size, 'Geometry unavailable');
      return;
    }

    final points = polys.expand((p) => p.ring).toList();
    final lon0 = points.map((p) => p.x).reduce((a, b) => a + b) / points.length;
    final lat0 = points.map((p) => p.y).reduce((a, b) => a + b) / points.length;
    final cosLat = math.max(.25, math.cos(lat0 * math.pi / 180));

    _P3 local(_P3 p) => _P3(
          (p.x - lon0) * 111320 * cosLat,
          (p.y - lat0) * 110540,
          p.z,
        );

    _P3 rotate(_P3 p) {
      final cy = math.cos(yaw), sy = math.sin(yaw);
      return _P3(p.x * cy - p.y * sy, p.x * sy + p.y * cy, p.z);
    }

    Offset project(_P3 p) {
      final cp = math.cos(pitch), sp = math.sin(pitch);
      return Offset(p.x, -(p.y * cp - p.z * sp));
    }

    final transformed = <_P3>[];
    for (final poly in polys) {
      for (final p in poly.ring) {
        transformed.add(rotate(local(p)));
        if (poly.heightM > 0) {
          transformed.add(rotate(local(_P3(p.x, p.y, poly.heightM))));
        }
      }
    }
    final projected = transformed.map(project).toList();
    var minX = projected.map((p) => p.dx).reduce(math.min);
    var maxX = projected.map((p) => p.dx).reduce(math.max);
    var minY = projected.map((p) => p.dy).reduce(math.min);
    var maxY = projected.map((p) => p.dy).reduce(math.max);
    if ((maxX - minX).abs() < .01) maxX = minX + 1;
    if ((maxY - minY).abs() < .01) maxY = minY + 1;

    final pad = math.min(size.width, size.height) * .10;
    final baseScale = math.min(
      (size.width - pad * 2) / (maxX - minX),
      (size.height - pad * 2) / (maxY - minY),
    );
    final scale = baseScale * zoom;
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    Offset screen(_P3 p) {
      final q = project(rotate(local(p)));
      return Offset(
        size.width / 2 + (q.dx - cx) * scale,
        size.height / 2 + (q.dy - cy) * scale,
      );
    }

    _grid(canvas, size);
    final faces = <_Face>[];
    for (final poly in polys) {
      final base = poly.ring;
      if (base.length < 3) continue;
      final h = poly.heightM;
      final bottomPoints = base.map(screen).toList();
      if (h <= 0) {
        final depth = base
                .map((p) => rotate(local(p)).y)
                .reduce((a, b) => a + b) /
            base.length;
        faces.add(_Face(bottomPoints, depth, true));
        continue;
      }

      final top = base.map((p) => _P3(p.x, p.y, h)).toList();
      final topPoints = top.map(screen).toList();
      final topDepth = top
              .map((p) => rotate(local(p)).y)
              .reduce((a, b) => a + b) /
          top.length;
      faces.add(_Face(topPoints, topDepth + 9999, true));

      for (var i = 0; i < base.length; i++) {
        final j = (i + 1) % base.length;
        final wall3d = [base[i], base[j], top[j], top[i]];
        final depth = wall3d
                .map((p) => rotate(local(p)).y)
                .reduce((a, b) => a + b) /
            wall3d.length;
        faces.add(_Face(wall3d.map(screen).toList(), depth, false));
      }
    }

    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      if (face.points.length < 3) continue;
      final path = Path()..moveTo(face.points.first.dx, face.points.first.dy);
      for (final p in face.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      final baseColor = face.roof ? _cyan : _blue;
      canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withValues(alpha: face.roof ? .25 : .17)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withValues(alpha: .82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = face.roof ? 1.35 : .8,
      );
    }

    final label = massing ? 'ROTATABLE L1 SCHEMATIC MASSING' : 'SOURCE FOOTPRINT';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFB5C6D9),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(13, size.height - tp.height - 11));
  }

  void _grid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB5C6D9).withValues(alpha: .10)
      ..strokeWidth = .6;
    const gap = 30.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _text(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFFB5C6D9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _RotatableMassingPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.massing != massing ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.zoom != zoom;
}

List<List<_P3>> _rings2d(Map<String, dynamic> geometry) {
  final type = '${geometry['type'] ?? ''}';
  final raw = geometry['coordinates'];
  if (raw is! List) return const [];

  List<_P3> ring(dynamic coords) {
    if (coords is! List) return const [];
    final out = <_P3>[];
    for (final p in coords) {
      if (p is! List || p.length < 2 || p[0] is! num || p[1] is! num) {
        continue;
      }
      out.add(_P3((p[0] as num).toDouble(), (p[1] as num).toDouble(), 0));
    }
    if (out.length > 2 &&
        out.first.x == out.last.x &&
        out.first.y == out.last.y) {
      out.removeLast();
    }
    return out;
  }

  if (type == 'Polygon') {
    if (raw.isEmpty) return const [];
    final r = ring(raw.first);
    return r.length >= 3 ? [r] : const [];
  }
  if (type == 'MultiPolygon') {
    final out = <List<_P3>>[];
    for (final polygon in raw) {
      if (polygon is! List || polygon.isEmpty) continue;
      final r = ring(polygon.first);
      if (r.length >= 3) out.add(r);
    }
    return out;
  }
  return const [];
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}

class _Provenance extends StatelessWidget {
  const _Provenance({required this.row});
  final Map<String, dynamic> row;

  String _v(dynamic x, [String fallback = '—']) {
    final s = '${x ?? ''}'.trim();
    return s.isEmpty || s == 'null' ? fallback : s;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _v(row['source_provider'] ?? row['source_name'], 'Source');
    final year = _v(row['source_year'], 'Year unavailable');
    final confidence = _v(row['match_confidence'], '—');
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF07131F),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined,
              size: 18, color: Color(0xFF48E1FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$provider • $year\nMatch confidence $confidence • ${_v(row['fidelity_level'], 'fidelity not supplied')}',
              style: const TextStyle(
                color: Color(0xFFB5C6D9),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
