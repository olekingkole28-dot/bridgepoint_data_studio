import 'dart:math' as math;

import 'package:flutter/material.dart';

class BridgePointSourceSurfaceModelV2 extends StatefulWidget {
  const BridgePointSourceSurfaceModelV2({
    super.key,
    required this.payload,
  });

  final Map<String, dynamic> payload;

  @override
  State<BridgePointSourceSurfaceModelV2> createState() =>
      _BridgePointSourceSurfaceModelV2State();
}

class _BridgePointSourceSurfaceModelV2State
    extends State<BridgePointSourceSurfaceModelV2> {
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  double _yaw = -0.55;
  double _pitch = 0.72;
  double _zoom = 1.0;
  double _gestureStartZoom = 1.0;

  Map<String, dynamic> get _geometry {
    final raw = widget.payload['geometry_3d'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  bool get _available => widget.payload['available'] == true && _geometry.isNotEmpty;

  void _reset() => setState(() {
        _yaw = -0.55;
        _pitch = 0.72;
        _zoom = 1.0;
      });

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const _SurfaceEmpty();
    }

    final surfaces = widget.payload['surface_count'] ?? '—';
    final vertices = widget.payload['vertex_count'] ?? '—';
    final provider = '${widget.payload['source_provider'] ?? 'Source 3D'}';
    final year = '${widget.payload['source_year'] ?? ''}'.trim();
    final height = _asDouble(widget.payload['height_m']);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07131F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cyan.withValues(alpha: .32), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: _cyan.withValues(alpha: .08),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _cyan.withValues(alpha: .24),
                        _blue.withValues(alpha: .16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.view_in_ar_rounded, color: _cyan),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Source 3D Surface Model',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$provider${year.isEmpty ? '' : ' • $year'}',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Reset 3D view',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded, color: _cyan),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SurfaceBadge('$surfaces surfaces', _cyan),
                _SurfaceBadge('$vertices vertices', _blue),
                if (height != null)
                  _SurfaceBadge('${height.toStringAsFixed(1)} m Z span', _green),
                const _SurfaceBadge('XYZ source geometry', _amber),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxWidth < 450 ? 360.0 : 480.0;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) => _gestureStartZoom = _zoom,
                onScaleUpdate: (details) {
                  setState(() {
                    _yaw += details.focalPointDelta.dx * .012;
                    _pitch = (_pitch - details.focalPointDelta.dy * .007).clamp(.18, 1.28);
                    if (details.pointerCount > 1) {
                      _zoom = (_gestureStartZoom * details.scale).clamp(.65, 2.4);
                    }
                  });
                },
                child: Container(
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      center: Alignment(.2, -.15),
                      radius: 1.25,
                      colors: [Color(0xFF10243B), Color(0xFF040B13)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  ),
                  child: CustomPaint(
                    painter: _SourceSurfacePainter(
                      geometry: _geometry,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.swipe_rounded, size: 18, color: _cyan),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Drag to rotate • pinch to zoom • actual source roof/wall surfaces when available',
                    style: TextStyle(color: _muted, fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 15),
            child: Text(
              '${widget.payload['truth_notice'] ?? 'Source-backed 3D surface geometry.'}',
              style: const TextStyle(color: _amber, fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceBadge extends StatelessWidget {
  const _SurfaceBadge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .26)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
      );
}

class _SurfaceEmpty extends StatelessWidget {
  const _SurfaceEmpty();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.view_in_ar_outlined, color: Color(0xFFB5C6D9)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detailed source 3D not linked yet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text(
                    'BridgePoint will fall back to source footprint/height massing until a verified XYZ surface model, mesh, LiDAR-derived model, or photogrammetry source is linked.',
                    style: TextStyle(color: Color(0xFFB5C6D9), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

class _Face {
  const _Face(this.points, this.depth, this.roofFactor);
  final List<Offset> points;
  final double depth;
  final double roofFactor;
}

class _SourceSurfacePainter extends CustomPainter {
  const _SourceSurfacePainter({
    required this.geometry,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  final Map<String, dynamic> geometry;
  final double yaw;
  final double pitch;
  final double zoom;

  static const _roof = Color(0xFF48E1FF);
  static const _wall = Color(0xFF6C83FF);
  static const _edge = Color(0xFFE8F5FF);

  @override
  void paint(Canvas canvas, Size size) {
    final rings = _rings3d(geometry);
    if (rings.isEmpty) {
      _centerText(canvas, size, '3D surface geometry unavailable');
      return;
    }

    final all = rings.expand((e) => e).toList();
    final lon0 = all.map((e) => e.x).reduce((a, b) => a + b) / all.length;
    final lat0 = all.map((e) => e.y).reduce((a, b) => a + b) / all.length;
    final z0 = all.map((e) => e.z).reduce(math.min);
    final cosLat = math.cos(lat0 * math.pi / 180.0);

    _Vec3 local(_Vec3 p) => _Vec3(
          (p.x - lon0) * 111320.0 * cosLat,
          (p.y - lat0) * 110540.0,
          p.z - z0,
        );

    final localRings = rings.map((r) => r.map(local).toList()).toList();
    final rotated = <List<_Vec3>>[];
    for (final ring in localRings) {
      rotated.add(ring.map(_rotate).toList());
    }

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;
    for (final ring in rotated) {
      for (final p in ring) {
        final projected = _project(p);
        minX = math.min(minX, projected.dx);
        maxX = math.max(maxX, projected.dx);
        minY = math.min(minY, projected.dy);
        maxY = math.max(maxY, projected.dy);
      }
    }

    final spanX = math.max(.01, maxX - minX);
    final spanY = math.max(.01, maxY - minY);
    final pad = math.min(size.width, size.height) * .10;
    final baseScale = math.min(
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    );
    final scale = baseScale * zoom;
    final ox = size.width / 2 - ((minX + maxX) / 2) * scale;
    final oy = size.height / 2 - ((minY + maxY) / 2) * scale;

    Offset screen(_Vec3 p) {
      final q = _project(p);
      return Offset(ox + q.dx * scale, oy + q.dy * scale);
    }

    final faces = <_Face>[];
    for (final ring in rotated) {
      if (ring.length < 3) continue;
      final normal = _normal(ring);
      final roofFactor = normal == null
          ? 0.0
          : normal.z.abs() / math.max(.0001, math.sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z));
      final depth = ring.map((p) => p.y).reduce((a, b) => a + b) / ring.length;
      faces.add(_Face(ring.map(screen).toList(), depth, roofFactor));
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));

    _grid(canvas, size);

    for (final face in faces) {
      final path = Path()..moveTo(face.points.first.dx, face.points.first.dy);
      for (final point in face.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      final isRoof = face.roofFactor > .48;
      final base = isRoof ? _roof : _wall;
      final alpha = isRoof ? .33 : .19 + face.roofFactor * .10;
      canvas.drawPath(
        path,
        Paint()
          ..color = base.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = (isRoof ? _roof : _edge).withValues(alpha: isRoof ? .84 : .46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isRoof ? 1.25 : .75,
      );
    }

    final glow = Paint()
      ..color = _roof.withValues(alpha: .10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .76),
        width: size.width * .62,
        height: size.height * .16,
      ),
      glow,
    );

    final label = TextPainter(
      text: const TextSpan(
        text: 'L2 • SOURCE XYZ SURFACES',
        style: TextStyle(
          color: Color(0xFF48E1FF),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(14, size.height - label.height - 12));
  }

  _Vec3 _rotate(_Vec3 p) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final x1 = p.x * cy - p.y * sy;
    final y1 = p.x * sy + p.y * cy;
    return _Vec3(x1, y1, p.z);
  }

  Offset _project(_Vec3 p) {
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final screenY = p.y * cp - p.z * sp;
    return Offset(p.x, -screenY);
  }

  _Vec3? _normal(List<_Vec3> ring) {
    if (ring.length < 3) return null;
    final a = ring[0];
    for (var i = 1; i < ring.length - 1; i++) {
      final b = ring[i];
      final c = ring[i + 1];
      final ux = b.x - a.x;
      final uy = b.y - a.y;
      final uz = b.z - a.z;
      final vx = c.x - a.x;
      final vy = c.y - a.y;
      final vz = c.z - a.z;
      final n = _Vec3(
        uy * vz - uz * vy,
        uz * vx - ux * vz,
        ux * vy - uy * vx,
      );
      if (n.x.abs() + n.y.abs() + n.z.abs() > .00001) return n;
    }
    return null;
  }

  void _grid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..strokeWidth = .7;
    const gap = 30.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _centerText(Canvas canvas, Size size, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Color(0xFFB5C6D9))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SourceSurfacePainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.zoom != zoom;
}

List<List<_Vec3>> _rings3d(Map<String, dynamic> geometry) {
  final type = '${geometry['type'] ?? ''}';
  final coordinates = geometry['coordinates'];
  final output = <List<_Vec3>>[];

  void addRing(dynamic ring) {
    if (ring is! List) return;
    final points = <_Vec3>[];
    for (final coordinate in ring) {
      if (coordinate is List && coordinate.length >= 3) {
        final x = _asDouble(coordinate[0]);
        final y = _asDouble(coordinate[1]);
        final z = _asDouble(coordinate[2]);
        if (x != null && y != null && z != null) points.add(_Vec3(x, y, z));
      }
    }
    if (points.length >= 3) {
      if (_same(points.first, points.last)) points.removeLast();
      output.add(points);
    }
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

bool _same(_Vec3 a, _Vec3 b) =>
    (a.x - b.x).abs() < 1e-10 &&
    (a.y - b.y).abs() < 1e-10 &&
    (a.z - b.z).abs() < 1e-6;

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}
