import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';

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
      _BridgePointPropertyDossierV2State();
}

class _BridgePointPropertyDossierV2State
    extends State<BridgePointPropertyDossierV2> {
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  late Future<List<dynamic>> _request;
  int _visual = 0;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<dynamic> _safe(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await Supabase.instance.client.rpc(rpc, params: params);
    } catch (_) {
      return const <String, dynamic>{'available': false};
    }
  }

  Future<List<dynamic>> _load() => Future.wait([
        _safe('bridgepoint_flutter_property_detail_v344', {
          'p_property_id': widget.propertyId,
        }),
        _safe('bridgepoint_property_timeline_v857', {
          'p_property_id': widget.propertyId,
          'p_limit': 100,
        }),
        _safe('bridgepoint_property_geometry_v854', {
          'p_property_id': widget.propertyId,
          'p_limit': 25,
        }),
        _safe('bridgepoint_digital_twin_summary_v856', {
          'p_property_id': widget.propertyId,
        }),
        _safe('bridgepoint_property_imagery_history_v169', {
          'p_property_id': widget.propertyId,
        }),
        _safe('bridgepoint_property_photo_contributions_v266', {
          'p_property_id': widget.propertyId,
        }),
      ]);

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(dynamic value, [List<String> keys = const []]) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      for (final key in keys) {
        if (value[key] is List) return _rows(value[key]);
      }
    }
    return const [];
  }

  Map<String, dynamic> _property(dynamic detail) {
    final d = _map(detail);
    for (final key in const ['property', 'summary', 'result']) {
      if (d[key] is Map) return _map(d[key]);
    }
    return {...widget.seed, ...d};
  }

  String _text(dynamic value, [String fallback = '—']) {
    final v = '${value ?? ''}'.trim();
    if (v.isEmpty || v.toLowerCase() == 'null') return fallback;
    return v;
  }

  String _money(dynamic value) {
    final n = value is num ? value.round() : int.tryParse('${value ?? ''}');
    if (n == null) return '—';
    final s = n.toString();
    final out = StringBuffer(r'$');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  List<Map<String, dynamic>> _aerial(dynamic payload) {
    final p = _map(payload);
    return _rows(p['history'], const ['items', 'history']);
  }

  List<Map<String, dynamic>> _photos(dynamic payload) {
    final p = _map(payload);
    return _rows(p['items'], const ['items']);
  }

  List<Map<String, dynamic>> _timeline(dynamic payload) {
    final p = _map(payload);
    return _rows(p, const ['timeline', 'items', 'events', 'rows']);
  }

  Widget _visualSwitcher(bool hasAerial, bool hasFront, bool hasModel) {
    final choices = <ButtonSegment<int>>[
      ButtonSegment(
        value: 0,
        icon: const Icon(Icons.satellite_alt_rounded),
        label: Text(hasAerial ? 'Aerial' : 'Aerial soon'),
      ),
      ButtonSegment(
        value: 1,
        icon: const Icon(Icons.photo_camera_front_rounded),
        label: Text(hasFront ? 'Front' : 'Front photo'),
      ),
      ButtonSegment(
        value: 2,
        icon: const Icon(Icons.view_in_ar_rounded),
        label: Text(hasModel ? '2D / 3D' : 'Geometry'),
      ),
    ];
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: choices,
        selected: {_visual},
        showSelectedIcon: false,
        onSelectionChanged: (v) => setState(() => _visual = v.first),
      ),
    );
  }

  Widget _aerialView(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const _VisualEmpty(
        icon: Icons.satellite_alt_rounded,
        title: 'Aerial reference not linked yet',
        body:
            'BridgePoint will show dated aerial imagery here when a verified state imagery source is available for this property.',
      );
    }
    return SizedBox(
      height: 360,
      child: PageView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final url = _text(row['media_url'], '');
          final year = _text(row['captured_year'], 'Aerial');
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url.isNotEmpty)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _VisualEmpty(
                      icon: Icons.broken_image_outlined,
                      title: 'Aerial image could not load',
                      body: 'The verified source is registered, but this frame could not be displayed right now.',
                    ),
                  )
                else
                  const _VisualEmpty(
                    icon: Icons.satellite_alt_rounded,
                    title: 'Aerial reference unavailable',
                    body: 'No displayable aerial URL was returned.',
                  ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xDD06101B),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _cyan.withValues(alpha: .35)),
                    ),
                    child: Text(
                      '$year • ${_text(row['provider'], 'Verified imagery')}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (rows.length > 1)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: _Badge('${index + 1}/${rows.length}', _blue),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _frontView(List<Map<String, dynamic>> photos) {
    if (photos.isEmpty) {
      return const _VisualEmpty(
        icon: Icons.add_a_photo_outlined,
        title: 'No verified front photo yet',
        body:
            'BridgePoint has not captured or approved a street/front exterior image for this property yet. Aerial and geometry remain available independently.',
      );
    }
    return _SignedPhoto(item: photos.first);
  }

  Widget _facts(Map<String, dynamic> p) {
    final facts = <_Fact>[
      _Fact('Year built', _text(p['year_built']), Icons.calendar_month_rounded, _amber),
      _Fact('Property type', _text(p['property_type']), Icons.home_work_rounded, _cyan),
      _Fact('Land use', _text(p['land_use_description'] ?? p['property_subtype']), Icons.category_outlined, _blue),
      _Fact('Buildings', _text(p['building_count']), Icons.apartment_rounded, _green),
      _Fact('Market value', _money(p['market_total_value']), Icons.trending_up_rounded, _green),
      _Fact('Assessed value', _money(p['assessed_total_value']), Icons.account_balance_outlined, _blue),
      _Fact('Parcel', _text(p['parcel_number']), Icons.grid_view_rounded, _cyan),
      _Fact('Municipality', _text(p['municipality']), Icons.location_city_rounded, _amber),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 760 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final fact in facts) SizedBox(width: w, child: _FactCard(fact))],
      );
    });
  }

  Widget _timelineView(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const _SectionEmpty(
        icon: Icons.timeline_rounded,
        title: 'No dated events linked yet',
        body: 'Signals, permits, ownership changes, weather and other dated evidence will appear here as they link to this property.',
      );
    }
    return Column(
      children: [
        for (final row in rows.take(20))
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _soft.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, color: _cyan, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(row['title'] ?? row['signal_name'] ?? row['event_type'], 'Property event'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _text(row['description'] ?? row['explanation'], 'Verified BridgePoint property evidence'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, height: 1.4),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _text(row['evidence_at'] ?? row['effective_at'] ?? row['detected_at'] ?? row['event_at'], ''),
                        style: const TextStyle(color: _cyan, fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<dynamic>>(
          future: _request,
          builder: (context, snapshot) {
            final values = snapshot.data ?? const [];
            final detail = values.isNotEmpty ? values[0] : widget.seed;
            final timeline = values.length > 1 ? values[1] : const {};
            final geometry = values.length > 2 ? _map(values[2]) : const <String, dynamic>{};
            final twin = values.length > 3 ? _map(values[3]) : const <String, dynamic>{};
            final imagery = values.length > 4 ? values[4] : const {};
            final photoPayload = values.length > 5 ? values[5] : const {};
            final p = _property(detail);
            final aerial = _aerial(imagery);
            final photos = _photos(photoPayload);
            final geometryRows = _rows(geometry['geometry']);
            final timelineRows = _timeline(timeline);
            final address = _text(
              p['full_address'] ?? widget.seed['full_address'] ?? widget.seed['address'],
              'Property',
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address,
                              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.1),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Badge(_text(p['property_type'], 'Property'), _cyan),
                                if (p['year_built'] != null) _Badge('Built ${p['year_built']}', _amber),
                                if (geometryRows.isNotEmpty) _Badge('${geometryRows.length} geometry linked', _green),
                                if (aerial.isNotEmpty) _Badge('${aerial.length} aerial years', _blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(widget.asPage ? Icons.arrow_back_rounded : Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    children: [
                      const _SectionHeader(
                        eyebrow: 'VISUAL INTELLIGENCE',
                        title: 'See the property first',
                        subtitle: 'Verified imagery and source-backed geometry before the database details.',
                        icon: Icons.visibility_rounded,
                      ),
                      const SizedBox(height: 12),
                      _visualSwitcher(aerial.isNotEmpty, photos.isNotEmpty, geometryRows.isNotEmpty),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _visual == 0
                            ? _aerialView(aerial)
                            : _visual == 1
                                ? _frontView(photos)
                                : BridgePointBuildingGeometryV2(payload: geometry),
                      ),
                      const SizedBox(height: 22),
                      const _SectionHeader(
                        eyebrow: 'PROPERTY 360',
                        title: 'Key property facts',
                        subtitle: 'The facts people actually need at a glance.',
                        icon: Icons.home_work_rounded,
                      ),
                      const SizedBox(height: 12),
                      _facts(p),
                      const SizedBox(height: 22),
                      _SectionHeader(
                        eyebrow: 'DIGITAL TWIN',
                        title: twin['available'] == true ? 'Digital twin context' : 'Digital twin readiness',
                        subtitle: twin['available'] == true
                            ? 'BridgePoint twin-derived property context is available.'
                            : 'No customer-facing twin summary is ready yet; source geometry and imagery remain separate and usable.',
                        icon: Icons.threed_rotation_rounded,
                      ),
                      const SizedBox(height: 10),
                      if (twin['available'] == true)
                        _TwinSummary(payload: twin)
                      else
                        const _SectionEmpty(
                          icon: Icons.view_in_ar_outlined,
                          title: 'Twin summary still building',
                          body: 'BridgePoint will surface a twin only when the underlying evidence supports it. Internal RPC or metering errors are never shown here.',
                        ),
                      const SizedBox(height: 22),
                      const _SectionHeader(
                        eyebrow: 'PROPERTY STORY',
                        title: 'Timeline & evidence',
                        subtitle: 'Dated signals and changes connected to this property.',
                        icon: Icons.timeline_rounded,
                      ),
                      const SizedBox(height: 10),
                      _timelineView(timelineRows),
                    ],
                  ),
                ),
              ],
            );
          },
        );

    if (widget.asPage) {
      return Scaffold(
        backgroundColor: const Color(0xFF040B14),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF05111F), Color(0xFF071B2B), Color(0xFF040B14)],
            ),
          ),
          child: SafeArea(child: content),
        ),
      );
    }
    return SafeArea(
      child: FractionallySizedBox(heightFactor: .95, child: content),
    );
  }
}

class _SignedPhoto extends StatefulWidget {
  const _SignedPhoto({required this.item});
  final Map<String, dynamic> item;

  @override
  State<_SignedPhoto> createState() => _SignedPhotoState();
}

class _SignedPhotoState extends State<_SignedPhoto> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = _load();
  }

  Future<String?> _load() async {
    final bucket = '${widget.item['media_bucket'] ?? ''}'.trim();
    final path = '${widget.item['media_path'] ?? ''}'.trim();
    if (bucket.isEmpty || path.isEmpty) return null;
    try {
      return await Supabase.instance.client.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: _url,
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null || url.isEmpty) {
            return const _VisualEmpty(
              icon: Icons.photo_outlined,
              title: 'Front photo is registered but unavailable',
              body: 'The image exists in BridgePoint media records but could not be opened in this session.',
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 360,
              child: Image.network(url, fit: BoxFit.cover),
            ),
          );
        },
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.eyebrow, required this.title, required this.subtitle, required this.icon});
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_BridgePointPropertyDossierV2State._cyan, _BridgePointPropertyDossierV2State._blue]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: const TextStyle(color: _BridgePointPropertyDossierV2State._cyan, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                const SizedBox(height: 3),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: _BridgePointPropertyDossierV2State._muted, height: 1.4, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );
}

class _Fact {
  const _Fact(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _FactCard extends StatelessWidget {
  const _FactCard(this.fact);
  final _Fact fact;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [fact.color.withValues(alpha: .12), _BridgePointPropertyDossierV2State._panel]),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: fact.color.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(fact.icon, color: fact.color, size: 20),
            const SizedBox(height: 8),
            Text(fact.label.toUpperCase(), style: const TextStyle(color: _BridgePointPropertyDossierV2State._muted, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: .7)),
            const SizedBox(height: 3),
            Text(fact.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _TwinSummary extends StatelessWidget {
  const _TwinSummary({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final useful = <MapEntry<String, dynamic>>[];
    for (final key in const ['fidelity_level', 'building_count', 'footprint_area_m2', 'height_m', 'roof_form', 'change_status', 'confidence']) {
      final value = payload[key];
      if (value != null && '$value'.trim().isNotEmpty) useful.add(MapEntry(key, value));
    }
    if (useful.isEmpty) {
      return const _SectionEmpty(
        icon: Icons.view_in_ar_rounded,
        title: 'Twin is available',
        body: 'BridgePoint has a twin record for this property. Additional customer-facing attributes are still being prepared.',
      );
    }
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (final e in useful)
          _Badge('${e.key.replaceAll('_', ' ')}: ${e.value}', _BridgePointPropertyDossierV2State._green),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900)),
      );
}

class _VisualEmpty extends StatelessWidget {
  const _VisualEmpty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        height: 280,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0B1D31), Color(0xFF07131F)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _BridgePointPropertyDossierV2State._cyan.withValues(alpha: .16)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _BridgePointPropertyDossierV2State._cyan, size: 42),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(color: _BridgePointPropertyDossierV2State._muted, height: 1.45, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BridgePointPropertyDossierV2State._soft.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _BridgePointPropertyDossierV2State._cyan),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: _BridgePointPropertyDossierV2State._muted, height: 1.4, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}
