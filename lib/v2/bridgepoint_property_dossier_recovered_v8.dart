import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bridgepoint_building_geometry_v2.dart';
import 'bridgepoint_property_dossier_recovered_v6.dart' as evidence_v6;

/// V8 podcast-ready unified Property workspace.
/// Property-specific capability stays contextual here instead of becoming
/// another permanent app tab. Real imagery is preferred; Structure 3D is
/// explicitly source-backed geometry/massing, never a fabricated house photo.
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
  State<BridgePointPropertyDossierV2> createState() => _PropertyV8State();
}

enum _PropertySection { overview, visuals, intelligence, evidence }
enum _VisualMode { front, aerial, structure3d, history }

class _PropertyV8State extends State<BridgePointPropertyDossierV2> {
  static const _bg = Color(0xFF030A12);
  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);
  late Future<Map<String, dynamic>> _future;
  _PropertySection _section = _PropertySection.overview;
  _VisualMode _visual = _VisualMode.front;

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
      _section = _PropertySection.overview;
      _visual = _VisualMode.front;
    }
  }

  Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
      ? value
      : value is Map
          ? Map<String, dynamic>.from(value)
          : const <String, dynamic>{};

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const <Map<String, dynamic>>[];

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
    for (final key in const ['full_address', 'address', 'property_address', 'street_address']) {
      final value = '${widget.seed[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return 'Property ${widget.propertyId.substring(0, widget.propertyId.length < 8 ? widget.propertyId.length : 8)}';
  }

  void _openEvidencePage() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => evidence_v6.BridgePointPropertyDossierV2(
        propertyId: widget.propertyId,
        seed: widget.seed,
        asPage: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final twin = snapshot.data ?? const <String, dynamic>{};
        if (twin.isEmpty) {
          return _ErrorState(onRetry: _refresh, onEvidence: _openEvidencePage);
        }
        return _workspace(twin);
      },
    );

    if (!widget.asPage) return body;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Property', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          Text(_address(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 10.5)),
        ]),
        actions: [
          IconButton(tooltip: 'Refresh property', onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: _cyan)),
        ],
      ),
      body: body,
    );
  }

  Widget _workspace(Map<String, dynamic> twin) {
    final media = _map(twin['media']);
    final caps = _map(twin['capabilities']);
    final queued = _map(twin['enrichment_queued']);
    final front = _map(media['front']);
    final aerial = _map(media['aerial_current']);
    final history = _rows(media['aerial_history']);

    // Image-first: if a real front image is unavailable, show current aerial
    // context before asking the user to look at schematic Structure 3D.
    final effectiveVisual = _visual == _VisualMode.front && front.isEmpty && aerial.isNotEmpty
        ? _VisualMode.aerial
        : _visual;

    return ColoredBox(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            _hero(twin, caps, queued),
            const SizedBox(height: 10),
            _sectionSelector(),
            const SizedBox(height: 12),
            switch (_section) {
              _PropertySection.overview => _overview(twin, media, caps, queued),
              _PropertySection.visuals => _visuals(twin, front, aerial, history, effectiveVisual),
              _PropertySection.intelligence => _intelligence(twin),
              _PropertySection.evidence => _evidenceSummary(twin),
            },
          ],
        ),
      ),
    );
  }

  Widget _hero(Map<String, dynamic> twin, Map<String, dynamic> caps, Map<String, dynamic> queued) {
    final live = caps.values.where((v) => v == true).length;
    final upgrading = queued.values.where((v) => v == true).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0E2A41), Color(0xFF071321)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cyan.withValues(alpha: .24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.home_work_rounded, color: _cyan), SizedBox(width: 8),
          Text('PROPERTY VISUAL + INTELLIGENCE', style: TextStyle(color: _cyan, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
        ]),
        const SizedBox(height: 7),
        Text(_address(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _pill('$live capabilities live', const Color(0xFF69E7A7)),
          if (upgrading > 0) _pill('$upgrading upgrading', const Color(0xFFFFC95E)),
          _pill('${twin['state_code'] ?? ''}', _cyan),
        ]),
      ]),
    );
  }

  Widget _sectionSelector() => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          _sectionChip(_PropertySection.overview, 'Overview', Icons.dashboard_customize_rounded),
          _sectionChip(_PropertySection.visuals, 'Visuals & 3D', Icons.photo_library_outlined),
          _sectionChip(_PropertySection.intelligence, 'Intelligence', Icons.insights_rounded),
          _sectionChip(_PropertySection.evidence, 'Evidence & History', Icons.fact_check_outlined),
        ],
      );

  Widget _sectionChip(_PropertySection value, String label, IconData icon) {
    final selected = _section == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _section = value),
      avatar: Icon(icon, size: 16, color: selected ? Colors.black : _cyan),
      label: Text(label),
      selectedColor: _cyan,
      backgroundColor: const Color(0xFF0A1725),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w800),
    );
  }

  Widget _overview(Map<String, dynamic> twin, Map<String, dynamic> media,
      Map<String, dynamic> caps, Map<String, dynamic> queued) {
    final front = _map(media['front']);
    final aerial = _map(media['aerial_current']);
    final intelligence = _map(twin['intelligence']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: MediaQuery.sizeOf(context).width < 650 ? 1.2 : 1.8,
        child: front.isNotEmpty
            ? _image(front)
            : aerial.isNotEmpty
                ? _image(aerial)
                : _empty(Icons.image_search_rounded, 'Property imagery is upgrading',
                    queued['front_imagery'] == true
                        ? 'BridgePoint is actively searching approved imagery sources. No synthetic house photo is used.'
                        : 'No approved property image is attached yet. BridgePoint keeps the evidence and physical model separate rather than guessing.'),
      ),
      const SizedBox(height: 10),
      _card('What BridgePoint knows now', Icons.verified_outlined, [
        caps['geocoded'] == true ? 'Exact property location resolved.' : 'Exact location still resolving; BridgePoint will not guess.',
        front.isNotEmpty ? 'Real exterior imagery is linked with source context.' : 'No real front image is currently attached.',
        aerial.isNotEmpty ? 'Current aerial context is available.' : 'Current aerial context is still resolving.',
        intelligence.isNotEmpty ? 'Property intelligence is linked to underlying evidence and signals.' : 'Intelligence is still assembling for this property.',
      ]),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: () => setState(() => _section = _PropertySection.visuals),
          icon: const Icon(Icons.photo_library_outlined), label: const Text('Open property visuals')),
    ]);
  }

  Widget _visuals(Map<String, dynamic> twin, Map<String, dynamic> front,
      Map<String, dynamic> aerial, List<Map<String, dynamic>> history, _VisualMode effectiveVisual) {
    final geometry = _map(twin['geometry']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 7, runSpacing: 7, children: [
        _visualChip(_VisualMode.front, 'Front', Icons.home_rounded),
        _visualChip(_VisualMode.aerial, 'Aerial', Icons.satellite_alt_rounded),
        _visualChip(_VisualMode.structure3d, 'Structure 3D', Icons.view_in_ar_rounded),
        _visualChip(_VisualMode.history, 'History', Icons.history_rounded),
      ]),
      const SizedBox(height: 10),
      if (effectiveVisual == _VisualMode.front)
        AspectRatio(aspectRatio: 1.55, child: front.isNotEmpty
            ? _image(front)
            : _empty(Icons.home_rounded, 'Front image not available yet', 'BridgePoint will not manufacture a house photo.'))
      else if (effectiveVisual == _VisualMode.aerial)
        AspectRatio(aspectRatio: 1.55, child: aerial.isNotEmpty
            ? _image(aerial)
            : _empty(Icons.satellite_alt_rounded, 'Aerial context unavailable', 'Aerial context appears when a source-backed location can be rendered.'))
      else if (effectiveVisual == _VisualMode.structure3d)
        geometry.isNotEmpty
            ? BridgePointBuildingGeometryV2(payload: geometry)
            : _empty(Icons.view_in_ar_rounded, 'Structure 3D is upgrading', 'This section uses source-backed geometry/massing. It is not a photorealistic picture of the house.')
      else
        history.isEmpty
            ? _empty(Icons.history_rounded, 'Historical imagery is expanding', 'BridgePoint keeps current imagery separate from dated historical observations.')
            : SizedBox(height: 360, child: PageView(children: history.map(_image).toList())),
      const SizedBox(height: 10),
      _card('Visual truth', Icons.shield_outlined, const [
        'Front and aerial images are shown only when BridgePoint has an approved source.',
        'Structure 3D is source-backed geometry or massing and is labeled separately from photography.',
        'A signal or visual reference does not by itself prove property damage, condition, a claim, or a required repair.',
      ]),
    ]);
  }

  Widget _visualChip(_VisualMode value, String label, IconData icon) {
    final selected = _visual == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _visual = value),
      avatar: Icon(icon, size: 16, color: selected ? Colors.black : _cyan),
      label: Text(label),
      selectedColor: _cyan,
      backgroundColor: const Color(0xFF0A1725),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w800),
    );
  }

  Widget _intelligence(Map<String, dynamic> twin) {
    final intel = _map(twin['intelligence']);
    final score = _map(intel['score']);
    final signals = _rows(intel['signals']);
    final patterns = _rows(intel['patterns']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card('Explainable intelligence', Icons.insights_rounded, [
        score['available'] == true
            ? 'Priority tier: ${score['priority_tier'] ?? 'available'} — tied to evidence rather than one unexplained number.'
            : 'No customer-safe priority score is available yet.',
        '${signals.length} linked signal${signals.length == 1 ? '' : 's'} visible.',
        '${patterns.length} multi-signal pattern${patterns.length == 1 ? '' : 's'} visible.',
        'Signals are prompts for investigation, not automatic conclusions.',
      ]),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _openEvidencePage, icon: const Icon(Icons.article_outlined), label: const Text('Open full evidence dossier')),
    ]);
  }

  Widget _evidenceSummary(Map<String, dynamic> twin) {
    final media = _map(twin['media']);
    final history = _rows(media['aerial_history']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card('Evidence & history', Icons.fact_check_outlined, [
        'Every BridgePoint record keeps source context so users can distinguish a data point from a verified conclusion.',
        '${history.length} dated aerial observation${history.length == 1 ? '' : 's'} currently attached.',
        'The full dossier contains timeline, evidence, property records and supporting intelligence in one property context.',
      ]),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _openEvidencePage, icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open full evidence & timeline')),
    ]);
  }

  Widget _image(Map<String, dynamic> item) {
    String url = '';
    for (final key in const ['media_url', 'thumbnail_url']) {
      final candidate = '${item[key] ?? ''}'.trim().replaceAll('{{sizeprefix}}', 'th');
      if (candidate.startsWith('http')) { url = candidate; break; }
    }
    if (url.isEmpty) return _empty(Icons.image_not_supported_outlined, 'Visual source unavailable', 'BridgePoint keeps the property usable and does not fabricate imagery.');
    final source = '${item['source_name'] ?? item['provider'] ?? 'Visual source'}'.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(fit: StackFit.expand, children: [
        InteractiveViewer(minScale: 1, maxScale: 5,
          child: Image.network(url, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _empty(Icons.broken_image_outlined, 'Visual source did not render', 'BridgePoint can retry or use another approved source.'))),
        Positioned(left: 9, right: 9, bottom: 9,
          child: Container(padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: const Color(0xE805101C), borderRadius: BorderRadius.circular(11)),
            child: Text(source, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)))),
      ]),
    );
  }

  Widget _empty(IconData icon, String title, String body) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const RadialGradient(colors: [Color(0xFF102A42), Color(0xFF040B14)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 40, color: _cyan), const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
        ]),
      );

  Widget _card(String title, IconData icon, List<String> lines) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFF081624), borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _cyan.withValues(alpha: .18))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: _cyan, size: 19), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 8),
          ...lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 6), child: CircleAvatar(radius: 2.5, backgroundColor: _cyan)),
            const SizedBox(width: 8), Expanded(child: Text(line, style: const TextStyle(color: Color(0xFFD7E4F0), height: 1.4))),
          ]))),
        ]),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .22))),
        child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.onEvidence});
  final Future<void> Function() onRetry;
  final VoidCallback onEvidence;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sync_problem_rounded, color: Color(0xFFFFC95E), size: 38),
            const SizedBox(height: 10),
            const Text('Property could not refresh', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: () { onRetry(); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
              OutlinedButton.icon(onPressed: onEvidence, icon: const Icon(Icons.article_outlined), label: const Text('Evidence')),
            ]),
          ]),
        ),
      );
}
