import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';
import 'bridgepoint_property_presentation_v2.dart';

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
      _BridgePointPropertyDossierRecoveredV3State();
}

class _BridgePointPropertyDossierRecoveredV3State
    extends State<BridgePointPropertyDossierV2> {
  static const _bg = Color(0xFF040B14);
  static const _panel = Color(0xFF0E2035);
  static const _soft = Color(0xFF16324E);
  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);
  static const _green = Color(0xFF45E6A6);
  static const _amber = Color(0xFFFFC95E);
  static const _red = Color(0xFFFF7474);
  static const _muted = Color(0xFFB5C6D9);

  late Future<List<dynamic>> _request;
  int _visual = -1;

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

  Future<List<dynamic>> _load() {
    final municipality = '${widget.seed['municipality'] ?? widget.seed['city'] ?? ''}'.trim();
    return Future.wait([
      _safe('bridgepoint_flutter_property_detail_v344', {
        'p_property_id': widget.propertyId,
      }),
      _safe('bridgepoint_property_timeline_v857', {
        'p_property_id': widget.propertyId,
        'p_limit': 200,
      }),
      _safe('bridgepoint_property_geometry_v854', {
        'p_property_id': widget.propertyId,
        'p_limit': 25,
      }),
      _safe('bridgepoint_digital_twin_summary_v856', {
        'p_property_id': widget.propertyId,
      }),
      _safe('bridgepoint_property_media_bundle_v169', {
        'p_property_id': widget.propertyId,
      }),
      _safe('bridgepoint_property_imagery_history_v169', {
        'p_property_id': widget.propertyId,
      }),
      _safe('bridgepoint_property_photo_contributions_v266', {
        'p_property_id': widget.propertyId,
      }),
      _safe('bridgepoint_property_climate_profile_v510', {
        'p_property_id': widget.propertyId,
      }),
      municipality.isEmpty
          ? Future.value(const <String, dynamic>{'available': false})
          : _safe('bridgepoint_flutter_permit_context_v68', {
              'p_municipality': municipality,
            }),
    ]);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  List<Map<String, dynamic>> _rows(
    dynamic value, [
    List<String> keys = const ['items', 'rows', 'results'],
  ]) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
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
    final nested = d['property'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return {...widget.seed, ...d};
  }

  String _text(dynamic value, [String fallback = '—']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _money(dynamic value) {
    final n = value is num ? value.round() : int.tryParse('${value ?? ''}');
    if (n == null) return '—';
    final raw = n.toString();
    final out = StringBuffer(r'$');
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return out.toString();
  }

  String _percent(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (n == null) return '—';
    final p = n <= 1 ? n * 100 : n;
    return '${p.toStringAsFixed(p >= 10 ? 0 : 1)}%';
  }

  String _date(dynamic value) {
    final raw = _text(value, 'Date unavailable');
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _remoteUrl(Map<String, dynamic> row) {
    for (final key in const [
      'thumbnail_url',
      'preview_url',
      'image_url',
      'media_url',
      'url',
    ]) {
      var value = '${row[key] ?? ''}'.trim();
      if (value.isEmpty || value == 'null') continue;
      value = value.replaceAll('{{sizeprefix}}', 'th');
      if (value.startsWith('https://') || value.startsWith('http://')) {
        return value;
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _timeline(dynamic payload) =>
      _rows(payload, const ['timeline', 'items', 'events', 'rows']);

  List<Map<String, dynamic>> _photoContributions(dynamic payload) =>
      _rows(payload, const ['items', 'photos', 'rows']);

  List<Map<String, dynamic>> _aerials(
    Map<String, dynamic> media,
    dynamic historyPayload,
  ) {
    final output = <Map<String, dynamic>>[];
    final seen = <String>{};

    void add(Map<String, dynamic> row) {
      final key = _remoteUrl(row).isNotEmpty
          ? _remoteUrl(row)
          : '${row['media_id'] ?? row['captured_at'] ?? row.hashCode}';
      if (seen.add(key)) output.add(row);
    }

    final current = _map(media['aerial_current']);
    if (current.isNotEmpty) add(current);
    for (final row in _rows(media['aerial_history'], const ['items', 'history'])) {
      add(row);
    }
    final history = _map(historyPayload);
    for (final row in _rows(history['history'], const ['items', 'history'])) {
      add(row);
    }
    return output;
  }

  Map<String, dynamic> _street(Map<String, dynamic> media) {
    final front = _map(media['front']);
    if (front.isNotEmpty) return front;
    for (final row in _rows(media, const ['items'])) {
      final type = '${row['media_type'] ?? ''}'.toUpperCase();
      if (type != 'AERIAL' && type != 'SATELLITE') return row;
    }
    return const {};
  }

  Map<String, dynamic> _intelligence(Map<String, dynamic> detail) {
    final value = detail['intelligence'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  List<Map<String, dynamic>> _opportunities(Map<String, dynamic> detail) {
    final intelligence = _intelligence(detail);
    return _rows(
      intelligence['opportunities'],
      const ['opportunities', 'items', 'rows'],
    );
  }

  Widget _visualTabs({
    required bool hasStreet,
    required bool hasAerial,
    required bool hasGeometry,
    required int selected,
  }) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      selected: {selected},
      segments: [
        ButtonSegment(
          value: 0,
          icon: const Icon(Icons.streetview_rounded),
          label: Text(hasStreet ? 'Street' : 'Street soon'),
        ),
        ButtonSegment(
          value: 1,
          icon: const Icon(Icons.satellite_alt_rounded),
          label: Text(hasAerial ? 'Aerial' : 'Aerial soon'),
        ),
        ButtonSegment(
          value: 2,
          icon: const Icon(Icons.view_in_ar_rounded),
          label: Text(hasGeometry ? '3D / Massing' : 'Geometry'),
        ),
      ],
      onSelectionChanged: (values) => setState(() => _visual = values.first),
    );
  }

  Widget _streetView(
    Map<String, dynamic> street,
    List<Map<String, dynamic>> contributions,
  ) {
    if (street.isEmpty) {
      if (contributions.isNotEmpty) {
        return _SignedContributionPhoto(item: contributions.first);
      }
      return const _VisualEmpty(
        icon: Icons.streetview_outlined,
        title: 'Street-level image not linked yet',
        body:
            'BridgePoint has no usable public street frame or approved exterior photo linked to this property yet.',
      );
    }

    final url = _remoteUrl(street);
    final metadata = _map(street['metadata']);
    final source = _text(
      street['source_name'] ?? metadata['provider'],
      'Public street-level source',
    );
    final distance = metadata['distance_m'];
    final distanceText = distance is num
        ? ' • about ${distance.toStringAsFixed(0)} m from the property point'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 380,
            child: url.isEmpty
                ? const _VisualEmpty(
                    icon: Icons.broken_image_outlined,
                    title: 'Street source is registered',
                    body: 'The record exists, but it does not currently have a displayable image URL.',
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _VisualEmpty(
                      icon: Icons.broken_image_outlined,
                      title: 'Street image could not load',
                      body: 'BridgePoint kept the source and provenance; only the image frame failed to display.',
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$source • ${_date(street['captured_at'])}$distanceText',
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const _TruthNote(
          'Plain English: this is a nearby public street-level reference chosen from the source data. It is not automatically proof that every visible feature belongs to this exact parcel, and it is never treated as damage proof by itself.',
        ),
      ],
    );
  }

  Widget _aerialView(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const _VisualEmpty(
        icon: Icons.satellite_alt_outlined,
        title: 'Aerial image not linked yet',
        body: 'BridgePoint will show dated aerial imagery here when a usable source is linked to this property.',
      );
    }
    return SizedBox(
      height: 380,
      child: PageView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final url = _remoteUrl(row);
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
                      body: 'The source record is still preserved with its date and provenance.',
                    ),
                  )
                else
                  const _VisualEmpty(
                    icon: Icons.image_not_supported_outlined,
                    title: 'Aerial source has no display URL',
                    body: 'BridgePoint has a source record but no image it can render right now.',
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: _OverlayLabel(
                          '${_date(row['captured_at'] ?? row['observed_at'] ?? row['capture_date'])} • ${_text(row['source_name'] ?? row['provider'], 'Aerial source')}',
                        ),
                      ),
                      if (rows.length > 1) ...[
                        const SizedBox(width: 8),
                        _OverlayLabel('${index + 1}/${rows.length}'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _facts(Map<String, dynamic> property) {
    final facts = <_Fact>[
      _Fact('Year built', _text(property['year_built']), Icons.history_rounded, _amber),
      _Fact('Type', _text(property['property_type']), Icons.home_work_rounded, _cyan),
      _Fact('Land use', _text(property['land_use_description'] ?? property['property_subtype']), Icons.category_outlined, _blue),
      _Fact('Buildings', _text(property['building_count']), Icons.apartment_rounded, _green),
      _Fact('Market value', _money(property['market_total_value']), Icons.trending_up_rounded, _green),
      _Fact('Assessed value', _money(property['assessed_total_value']), Icons.account_balance_outlined, _blue),
      _Fact('Parcel', _text(property['parcel_number']), Icons.grid_view_rounded, _cyan),
      _Fact('Match confidence', _percent(property['canonical_confidence']), Icons.link_rounded, _amber),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * 9) / columns;
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final fact in facts)
              SizedBox(width: width, child: _FactCard(fact: fact)),
          ],
        );
      },
    );
  }

  Widget _whyNow(Map<String, dynamic> detail) {
    final rows = _opportunities(detail);
    if (rows.isEmpty) {
      return const _PlainCard(
        icon: Icons.fact_check_outlined,
        title: 'No verified “why now” result yet',
        body:
            'That does not mean nothing happened. It means BridgePoint does not currently have enough package-safe evidence to promote a verified opportunity for this property.',
      );
    }
    return Column(
      children: [
        for (final row in rows.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: _amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _text(row['title'], 'Verified opportunity'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (row['score'] != null)
                          Text(
                            '${row['score']}',
                            style: const TextStyle(
                              color: _cyan,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(
                        row['why_now'] ?? row['explanation'],
                        'BridgePoint found enough linked evidence to move this property higher on the review list.',
                      ),
                      style: const TextStyle(height: 1.45),
                    ),
                    if (_text(row['recommended_action'], '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Next thing to check: ${row['recommended_action']}',
                        style: const TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        const _TruthNote(
          'A BridgePoint opportunity is a prioritization result. It is not a statement that damage definitely occurred, that a permit definitely belongs to this parcel, or that a sale/project is guaranteed.',
        ),
      ],
    );
  }

  Widget _timelineView(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const _PlainCard(
        icon: Icons.timeline_outlined,
        title: 'No dated property events linked yet',
        body:
            'Signals, patterns, ownership changes, permits, weather and other dated evidence appear here only when BridgePoint can link them to the property record.',
      );
    }
    return Column(
      children: [
        for (final row in rows.take(40))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1635D2E8),
                child: Icon(Icons.bolt_rounded, color: _cyan, size: 18),
              ),
              title: Text(
                _text(
                  row['title'] ?? row['signal_name'] ?? row['event_type'],
                  'Property event',
                ),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${_date(row['timeline_at'] ?? row['evidence_at'] ?? row['effective_at'] ?? row['detected_at'] ?? row['event_at'])} • ${_text(row['source_label'] ?? row['source_name'], 'Source recorded')}',
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _text(
                      row['description'] ?? row['explanation'],
                      'BridgePoint linked this dated record to the property intelligence timeline.',
                    ),
                    style: const TextStyle(height: 1.45),
                  ),
                ),
                if (_text(row['why_it_matters'], '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Why it matters: ${row['why_it_matters']}',
                      style: const TextStyle(
                        color: _cyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (_text(row['limitations'], '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'What this does NOT prove: ${row['limitations']}',
                      style: const TextStyle(color: _amber, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _mediaGallery(Map<String, dynamic> media) {
    final items = _rows(media, const ['items']);
    if (items.isEmpty) {
      return const _PlainCard(
        icon: Icons.photo_library_outlined,
        title: 'No additional property media yet',
        body: 'Street, aerial and user-approved imagery appear here with source/date context when available.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * 9) / columns;
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final row in items.take(18))
              SizedBox(
                width: width,
                child: _MediaCard(
                  row: row,
                  url: _remoteUrl(row),
                  date: _date(row['captured_at'] ?? row['observed_at']),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _technicalEvidence({
    required Map<String, dynamic> detail,
    required Map<String, dynamic> geometry,
    required Map<String, dynamic> twin,
    required Map<String, dynamic> media,
    required Map<String, dynamic> climate,
    required Map<String, dynamic> permits,
  }) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.data_object_rounded, color: _cyan),
        title: const Text(
          'More evidence & provenance',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'For deeper review without turning the main property page into a database dump.',
          style: TextStyle(color: _muted),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          BridgePointGenericWorkspaceSectionV2(
            title: 'Property record',
            payload: detail,
            icon: Icons.home_work_outlined,
          ),
          const SizedBox(height: 8),
          BridgePointGenericWorkspaceSectionV2(
            title: 'Geometry provenance',
            payload: geometry,
            icon: Icons.view_in_ar_outlined,
          ),
          const SizedBox(height: 8),
          BridgePointGenericWorkspaceSectionV2(
            title: 'Twin status',
            payload: twin,
            icon: Icons.threed_rotation_rounded,
          ),
          const SizedBox(height: 8),
          BridgePointGenericWorkspaceSectionV2(
            title: 'Media source records',
            payload: media,
            icon: Icons.photo_library_outlined,
          ),
          const SizedBox(height: 8),
          BridgePointGenericWorkspaceSectionV2(
            title: 'Climate / risk source output',
            payload: climate,
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 8),
          BridgePointGenericWorkspaceSectionV2(
            title: 'Permit context source output',
            payload: permits,
            icon: Icons.construction_outlined,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        final detail = values.isNotEmpty ? _map(values[0]) : widget.seed;
        final timelinePayload = values.length > 1 ? values[1] : const {};
        final geometry = values.length > 2 ? _map(values[2]) : const <String, dynamic>{};
        final twin = values.length > 3 ? _map(values[3]) : const <String, dynamic>{};
        final media = values.length > 4 ? _map(values[4]) : const <String, dynamic>{};
        final history = values.length > 5 ? values[5] : const {};
        final photoPayload = values.length > 6 ? values[6] : const {};
        final climate = values.length > 7 ? _map(values[7]) : const <String, dynamic>{};
        final permits = values.length > 8 ? _map(values[8]) : const <String, dynamic>{};

        final property = _property(detail);
        final street = _street(media);
        final contributions = _photoContributions(photoPayload);
        final aerials = _aerials(media, history);
        final geometryRows = _rows(geometry['geometry']);
        final timelineRows = _timeline(timelinePayload);
        final address = _text(
          property['full_address'] ??
              widget.seed['full_address'] ??
              widget.seed['address'],
          'Property',
        );

        final hasStreet = street.isNotEmpty || contributions.isNotEmpty;
        final selected = _visual >= 0
            ? _visual
            : hasStreet
                ? 0
                : aerials.isNotEmpty
                    ? 1
                    : 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _Pill(_text(property['property_type'], 'Property'), _cyan),
                            if (property['year_built'] != null)
                              _Pill('Built ${property['year_built']}', _amber),
                            if (hasStreet) const _Pill('Street image linked', _green),
                            if (aerials.isNotEmpty)
                              _Pill('${aerials.length} aerial frame${aerials.length == 1 ? '' : 's'}', _blue),
                            if (geometryRows.isNotEmpty)
                              _Pill('${geometryRows.length} geometry record${geometryRows.length == 1 ? '' : 's'}', _green),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: widget.asPage ? 'Back' : 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      widget.asPage
                          ? Icons.arrow_back_rounded
                          : Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(minHeight: 2),
            if (snapshot.hasError)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Some property intelligence could not load. BridgePoint is showing the records that are available instead of inventing missing values.',
                  style: TextStyle(color: _red),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                children: [
                  const _SectionTitle(
                    eyebrow: 'VISUAL INTELLIGENCE',
                    title: 'See the property before reading the database',
                    subtitle:
                        'Street-level imagery, dated aerial imagery and honest 3D/massing are separated so you always know what you are looking at.',
                    icon: Icons.visibility_rounded,
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _visualTabs(
                      hasStreet: hasStreet,
                      hasAerial: aerials.isNotEmpty,
                      hasGeometry: geometryRows.isNotEmpty,
                      selected: selected,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: selected == 0
                        ? _streetView(street, contributions)
                        : selected == 1
                            ? _aerialView(aerials)
                            : BridgePointBuildingGeometryV2(payload: geometry),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    eyebrow: 'PROPERTY FACTS',
                    title: 'The basics in normal language',
                    subtitle:
                        'The property identity and value fields BridgePoint has linked to this parcel.',
                    icon: Icons.home_work_rounded,
                  ),
                  const SizedBox(height: 12),
                  _facts(property),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    eyebrow: 'WHY NOW',
                    title: 'What BridgePoint thinks deserves attention',
                    subtitle:
                        'Evidence-backed prioritization with the uncertainty left visible.',
                    icon: Icons.bolt_rounded,
                  ),
                  const SizedBox(height: 10),
                  _whyNow(detail),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    eyebrow: 'WEATHER + RISK',
                    title: 'What could matter physically',
                    subtitle:
                        'Weather and climate context helps decide what to inspect. It does not prove the property was damaged.',
                    icon: Icons.shield_outlined,
                  ),
                  const SizedBox(height: 10),
                  BridgePointClimateProfileV2(payload: climate),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    eyebrow: '3D / DIGITAL TWIN',
                    title: twin['available'] == true
                        ? 'What BridgePoint can actually model'
                        : '3D model readiness',
                    subtitle:
                        'A footprint or height-based massing model is labeled as exactly that. BridgePoint only calls something higher-fidelity when the source supports it.',
                    icon: Icons.threed_rotation_rounded,
                  ),
                  const SizedBox(height: 10),
                  BridgePointTwinSummaryV2(payload: twin),
                  const SizedBox(height: 12),
                  const _TruthNote(
                    'Most current BridgePoint 3D records are source-backed footprints/massing, not photorealistic scans or exact replicas. That distinction stays visible on purpose.',
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    eyebrow: 'PERMITS',
                    title: 'Permit context',
                    subtitle:
                        'Municipal permit data when available. Municipality-level context is not automatically a permit on this exact parcel.',
                    icon: Icons.construction_outlined,
                  ),
                  const SizedBox(height: 10),
                  BridgePointPermitContextV2(payload: permits),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    eyebrow: 'PROPERTY DNA',
                    title: 'The dated evidence story',
                    subtitle:
                        'Signals, patterns, changes and source records in chronological order.',
                    icon: Icons.timeline_rounded,
                  ),
                  const SizedBox(height: 10),
                  _timelineView(timelineRows),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    eyebrow: 'IMAGERY + MEDIA',
                    title: 'Every linked visual source',
                    subtitle:
                        'Date, source and media type stay visible so an image never silently becomes a conclusion.',
                    icon: Icons.photo_library_outlined,
                  ),
                  const SizedBox(height: 10),
                  _mediaGallery(media),
                  const SizedBox(height: 24),
                  _technicalEvidence(
                    detail: detail,
                    geometry: geometry,
                    twin: twin,
                    media: media,
                    climate: climate,
                    permits: permits,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (widget.asPage) {
      return Scaffold(
        backgroundColor: _bg,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF061321), Color(0xFF0A1C30), _bg],
            ),
          ),
          child: SafeArea(child: content),
        ),
      );
    }
    return SafeArea(
      child: FractionallySizedBox(heightFactor: .96, child: content),
    );
  }
}

class _SignedContributionPhoto extends StatefulWidget {
  const _SignedContributionPhoto({required this.item});
  final Map<String, dynamic> item;

  @override
  State<_SignedContributionPhoto> createState() =>
      _SignedContributionPhotoState();
}

class _SignedContributionPhotoState extends State<_SignedContributionPhoto> {
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
      return await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, 3600);
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
              title: 'Exterior photo is registered but unavailable',
              body: 'The contribution record exists, but the image could not be opened in this session.',
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 380,
              child: Image.network(url, fit: BoxFit.cover),
            ),
          );
        },
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF48E1FF), Color(0xFF6C83FF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: Color(0xFF48E1FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB5C6D9),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
  const _FactCard({required this.fact});
  final _Fact fact;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2035),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: fact.color.withValues(alpha: .24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(fact.icon, color: fact.color, size: 20),
            const SizedBox(height: 8),
            Text(
              fact.label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFB5C6D9),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .65,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fact.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xDD06101B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFF48E1FF).withValues(alpha: .30),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
}

class _TruthNote extends StatelessWidget {
  const _TruthNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFC95E).withValues(alpha: .055),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: const Color(0xFFFFC95E).withValues(alpha: .19),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFFC95E),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFB5C6D9),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
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
  Widget build(BuildContext context) => Container(
        height: 300,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B1D31), Color(0xFF07131F)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF48E1FF).withValues(alpha: .16),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF48E1FF), size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB5C6D9),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlainCard extends StatelessWidget {
  const _PlainCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16324E).withValues(alpha: .60),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF48E1FF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFFB5C6D9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.row,
    required this.url,
    required this.date,
  });

  final Map<String, dynamic> row;
  final String url;
  final String date;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: url.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF07131F),
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFFB5C6D9),
                            ),
                          ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF07131F),
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFB5C6D9),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${row['media_type'] ?? 'PROPERTY MEDIA'}'.replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${row['source_name'] ?? row['provider'] ?? 'Source recorded'} • $date',
                style: const TextStyle(
                  color: Color(0xFFB5C6D9),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      );
}
