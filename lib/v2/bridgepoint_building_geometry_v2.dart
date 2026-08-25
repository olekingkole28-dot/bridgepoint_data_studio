import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class BridgePointBuildingGeometryV2 extends StatefulWidget {
  const BridgePointBuildingGeometryV2({
    super.key,
    required this.payload,
  });

  final Map<String, dynamic> payload;

  @override
  State<BridgePointBuildingGeometryV2> createState() => _BridgePointBuildingGeometryV2State();
}

class _BridgePointBuildingGeometryV2State extends State<BridgePointBuildingGeometryV2> {
  bool _massing = true;

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);
  static const _amber = Color(0xFFFFC857);

  List<Map<String, dynamic>> get _rows {
    final raw = widget.payload['geometry'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.payload['locked'] == true;
    final rows = _rows;
    final truth = '${widget.payload['truth_notice'] ?? ''}'.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.view_in_ar_rounded, color: _cyan),
            const SizedBox(width: 8),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Building Geometry', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('Source-backed footprint and schematic massing', style: TextStyle(color: _muted, fontSize: 10)),
            ])),
            if (!locked && rows.isNotEmpty)
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.crop_square_rounded), label: Text('Footprint')),
                  ButtonSegment(value: true, icon: Icon(Icons.view_in_ar_rounded), label: Text('Massing')),
                ],
                selected: {_massing},
                onSelectionChanged: (v) => setState(() => _massing = v.first),
              ),
          ]),
          const SizedBox(height: 12),
          if (locked)
            const _EmptyGeometry(
              icon: Icons.lock_outline_rounded,
              title: 'Digital Twin geometry is package-gated',
              body: 'This account does not currently include the Digital Twin / imagery-change geometry feature.',
            )
          else if (rows.isEmpty)
            const _EmptyGeometry(
              icon: Icons.layers_clear_outlined,
              title: 'No linked building geometry yet',
              body: 'BridgePoint has not linked a source-backed building footprint to this property yet. The property record remains usable without inventing geometry.',
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 420,
                decoration: BoxDecoration(
                  color: const Color(0xFF07131F),
                  border: Border.all(color: const Color(0x2235D2E8)),
                ),
                child: InteractiveViewer(
                  minScale: .7,
                  maxScale: 8,
                  boundaryMargin: const EdgeInsets.all(120),
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: _BuildingGeometryPainter(rows: rows, massing: _massing),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: '${rows.length} linked ${rows.length == 1 ? 'geometry' : 'geometries'}'),
                _InfoChip(label: _fidelity(rows)),
                _InfoChip(label: _height(rows)),
                _InfoChip(label: _source(rows)),
              ],
            ),
            const SizedBox(height: 9),
            const Text(
              'Massing mode extrudes the source footprint using available building height. It is a schematic L1 representation—not a photorealistic scan, BIM model, engineering survey, or exact replica.',
              style: TextStyle(color: _amber, fontSize: 10, height: 1.45),
            ),
            if (truth.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(truth, style: const TextStyle(color: _muted, fontSize: 9, height: 1.4)),
            ],
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Geometry provenance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              children: rows.take(12).map((row) => _GeometryProvenance(row: row)).toList(),
            ),
          ],
        ]),
      ),
    );
  }

  String _fidelity(List<Map<String, dynamic>> rows) {
    final levels = rows.map((e) => '${e['fidelity_level'] ?? 'L0_PROPERTY_SHELL'}').toSet();
    if (levels.contains('L1_BUILDING_MASSING')) return 'L1 building massing';
    return 'L0 property shell';
  }

  String _height(List<Map<String, dynamic>> rows) {
    final heights = rows.map((e) => _asDouble(e['height_m'])).whereType<double>().where((v) => v > 0).toList();
    if (heights.isEmpty) return 'Height unavailable';
    final maxHeight = heights.reduce(math.max);
    return 'Height ${maxHeight.toStringAsFixed(1)} m';
  }

  String _source(List<Map<String, dynamic>> rows) {
    final first = rows.first;
    final provider = '${first['source_provider'] ?? first['source_name'] ?? 'Source-backed'}'.trim();
    final year = '${first['source_year'] ?? ''}'.trim();
    return year.isEmpty ? provider : '$provider • $year';
  }
}

class _BuildingGeometryPainter extends CustomPainter {
  _BuildingGeometryPainter({required this.rows, required this.massing});

  final List<Map<String, dynamic>> rows;
  final bool massing;

  static const _cyan = Color(0xFF35D2E8);

  @override
  void paint(Canvas canvas, Size size) {
    final polygons = <_WorldPolygon>[];
    for (final row in rows) {
      final geometry = row['geometry'];
      if (geometry is! Map) continue;
      final height = _asDouble(row['height_m']) ?? 0;
      polygons.addAll(_geoJsonPolygons(Map<String, dynamic>.from(geometry), height));
    }
    if (polygons.isEmpty) {
      _paintEmpty(canvas, size);
      return;
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final polygon in polygons) {
      for (final p in polygon.outer) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    final dx = math.max(maxX - minX, .0000001);
    final dy = math.max(maxY - minY, .0000001);
    final pad = math.min(size.width, size.height) * .12;
    final availableW = math.max(1, size.width - pad * 2);
    final availableH = math.max(1, size.height - pad * 2);
    final scale = math.min(availableW / dx, availableH / dy);
    final usedW = dx * scale;
    final usedH = dy * scale;
    final offsetX = (size.width - usedW) / 2;
    final offsetY = (size.height - usedH) / 2;

    Offset project(Offset p) => Offset(
          offsetX + (p.dx - minX) * scale,
          size.height - (offsetY + (p.dy - minY) * scale),
        );

    _paintGrid(canvas, size);

    final ordered = [...polygons]..sort((a, b) => a.height.compareTo(b.height));
    for (final polygon in ordered) {
      final base = polygon.outer.map(project).toList();
      if (base.length < 3) continue;
      final h = massing ? math.min(56.0, math.max(6.0, polygon.height * 1.45)) : 0.0;
      final extrusion = Offset(h * .42, -h);
      final top = base.map((p) => p + extrusion).toList();

      if (massing && h > 0) {
        final wallPaint = Paint()
          ..color = _cyan.withValues(alpha: .13)
          ..style = PaintingStyle.fill;
        final wallStroke = Paint()
          ..color = _cyan.withValues(alpha: .36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        for (var i = 0; i < base.length; i++) {
          final j = (i + 1) % base.length;
          final wall = Path()
            ..moveTo(base[i].dx, base[i].dy)
            ..lineTo(base[j].dx, base[j].dy)
            ..lineTo(top[j].dx, top[j].dy)
            ..lineTo(top[i].dx, top[i].dy)
            ..close();
          canvas.drawPath(wall, wallPaint);
          canvas.drawPath(wall, wallStroke);
        }
      }

      final footprint = _path(base);
      final topPath = _path(massing ? top : base);
      canvas.drawPath(
        footprint,
        Paint()
          ..color = _cyan.withValues(alpha: massing ? .05 : .14)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        topPath,
        Paint()
          ..color = _cyan.withValues(alpha: massing ? .20 : .08)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        topPath,
        Paint()
          ..color = _cyan.withValues(alpha: .92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final label = massing ? 'SCHEMATIC L1 MASSING' : 'SOURCE FOOTPRINT';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF8FA5BF), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(14, size.height - painter.height - 12));
  }

  Path _path(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8FA5BF).withValues(alpha: .07)
      ..strokeWidth = .7;
    const gap = 28.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintEmpty(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: const TextSpan(text: 'Geometry unavailable', style: TextStyle(color: Color(0xFF8FA5BF), fontSize: 12)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _BuildingGeometryPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.massing != massing;
}

class _WorldPolygon {
  const _WorldPolygon(this.outer, this.height);
  final List<Offset> outer;
  final double height;
}

List<_WorldPolygon> _geoJsonPolygons(Map<String, dynamic> geometry, double height) {
  final type = '${geometry['type'] ?? ''}';
  final coordinates = geometry['coordinates'];
  final output = <_WorldPolygon>[];

  void addPolygon(dynamic polygon) {
    if (polygon is! List || polygon.isEmpty) return;
    final outer = polygon.first;
    if (outer is! List) return;
    final points = <Offset>[];
    for (final coordinate in outer) {
      if (coordinate is List && coordinate.length >= 2) {
        final x = _asDouble(coordinate[0]);
        final y = _asDouble(coordinate[1]);
        if (x != null && y != null) points.add(Offset(x, y));
      }
    }
    if (points.length >= 3) {
      if (points.first == points.last) points.removeLast();
      output.add(_WorldPolygon(points, height));
    }
  }

  if (type == 'Polygon') {
    addPolygon(coordinates);
  } else if (type == 'MultiPolygon' && coordinates is List) {
    for (final polygon in coordinates) addPolygon(polygon);
  }
  return output;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF081625),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x2235D2E8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
      );
}

class _GeometryProvenance extends StatelessWidget {
  const _GeometryProvenance({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final source = '${row['source_provider'] ?? row['source_name'] ?? 'Unknown source'}';
    final parts = <String>[
      if (row['source_year'] != null) '${row['source_year']}',
      if (row['match_method'] != null) '${row['match_method']}',
      if (row['match_confidence'] != null) 'match ${row['match_confidence']}',
      if (row['footprint_area_m2'] != null) '${row['footprint_area_m2']} m²',
      if (row['height_m'] != null) '${row['height_m']} m high',
      if (row['floors'] != null) '${row['floors']} floors',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF35D2E8)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(source, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          Text(parts.join(' • '), style: const TextStyle(color: Color(0xFF8FA5BF), fontSize: 9)),
        ])),
      ]),
    );
  }
}

class _EmptyGeometry extends StatelessWidget {
  const _EmptyGeometry({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF081625),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x2235D2E8)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF8FA5BF)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: Color(0xFF8FA5BF), fontSize: 10, height: 1.4)),
          ])),
        ]),
      );
}
