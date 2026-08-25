import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BridgePointPackageFitV2 extends StatefulWidget {
  const BridgePointPackageFitV2({super.key});

  @override
  State<BridgePointPackageFitV2> createState() => _BridgePointPackageFitV2State();
}

class _BridgePointPackageFitV2State extends State<BridgePointPackageFitV2> {
  bool _busy = false;
  String? _message;
  String _audience = 'roofing / exterior contractor';
  String _propertyFocus = 'residential homes';
  String _goal = 'find & prioritize opportunities';
  String _teamScale = 'one person';
  String _territory = 'statewide';
  String _integration = 'bridgepoint app';
  final Set<String> _capabilities = {'opportunity scoring', 'weather impact'};
  Map<String, dynamic> _fit = const {};

  static const _cyan = Color(0xFF35D2E8);
  static const _muted = Color(0xFF8FA5BF);

  static const _audiences = [
    'roofing / exterior contractor','restoration / mitigation','home services contractor','public adjuster / claims professional','property investor / acquisitions','commercial real estate / property management','developer / builder','homeowner','solar / energy','insurer / risk / analytics','institutional investor / analytics','government / infrastructure','software / data / platform','other'
  ];
  static const _propertyFocuses = ['residential homes','commercial properties','mixed residential + commercial','development sites','large portfolios','one home','public infrastructure'];
  static const _goals = ['find & prioritize opportunities','understand risk','manage a team workflow','organize evidence','plan field work','monitor changes','acquire / invest','find development / redevelopment','analyze patterns at scale','integrate / build technology','build custom intelligence','ask natural-language property questions','clean / resolve property data','prove data quality','prove roi / learn from outcomes','track infrastructure / public projects','understand my property','expand geographic data coverage'];
  static const _teamScales = ['one person','2-5 people','6-25 people','26+ people','enterprise / institutional'];
  static const _territories = ['one property','local','statewide','multi-state','national'];
  static const _integrations = ['bridgepoint app','api / embed','managed implementation','white-label portal'];
  static const _capabilityOptions = ['opportunity scoring','weather impact','imagery / physical change','evidence reports','field routes','monitoring','natural-language ai','next-best action','pattern intelligence','portfolio relationships','property resolution','property timeline','signal / evidence normalization','source health / provenance','source roi','team roles / entitlements','api access','custom models','coverage readiness','data onboarding','historical replay','marketplace / entitlements','outcome learning','white-label portal'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final raw = await Supabase.instance.client.rpc('bridgepoint_onboarding_state_v70');
      final onboarding = _map(raw);
      final profile = _map(onboarding['profile']);
      final answers = _map(profile['fit_answers']);
      if (answers.isNotEmpty) {
        final a = '${answers['audience'] ?? ''}';
        if (_audiences.contains(a)) _audience = a;
        final p = '${answers['property_focus'] ?? ''}';
        if (_propertyFocuses.contains(p)) _propertyFocus = p;
        final g = '${answers['goal'] ?? ''}';
        if (_goals.contains(g)) _goal = g;
        final s = '${answers['team_scale'] ?? ''}';
        if (_teamScales.contains(s)) _teamScale = s;
        final t = '${answers['territory'] ?? ''}';
        if (_territories.contains(t)) _territory = t;
        final i = '${answers['integration'] ?? ''}';
        if (_integrations.contains(i)) _integration = i;
        final caps = answers['capabilities'];
        if (caps is List) {
          _capabilities
            ..clear()
            ..addAll(caps.map((e) => '$e').where(_capabilityOptions.contains));
        }
      }
      final recommendations = _map(profile['fit_recommendations']);
      if (recommendations.isNotEmpty) _fit = recommendations;
    } catch (e) {
      _message = 'Onboarding state unavailable: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> get _answers => {
        'audience': _audience,
        'property_focus': _propertyFocus,
        'goal': _goal,
        'team_scale': _teamScale,
        'territory': _territory,
        'integration': _integration,
        'capabilities': _capabilities.toList()..sort(),
      };

  Future<void> _preview() async {
    if (_capabilities.isEmpty) {
      setState(() => _message = 'Choose at least one capability.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_package_fit_preview_v315',
        params: {'p_answers': _answers},
      );
      if (mounted) setState(() {
        _fit = _map(raw);
        _message = 'Package fit recalculated.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Fit preview unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_capabilities.isEmpty) {
      setState(() => _message = 'Choose at least one capability.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'bridgepoint_complete_onboarding_v315',
        params: {'p_answers': _answers},
      );
      if (mounted) setState(() {
        _fit = _map(raw);
        _message = 'Onboarding answers and recommended package saved.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not save package fit: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        items: options.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      );

  Widget _recommendation() {
    if (_fit.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Answer the fit questions and preview your best package match.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    final best = _map(_fit['best_actionable']);
    final overall = _map(_fit['best_overall']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Recommended package',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              '${best['package_name'] ?? overall['package_name'] ?? _fit['recommended_package_key'] ?? 'BridgePoint package'}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _cyan,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${best['reason'] ?? overall['reason'] ?? _fit['explanation'] ?? ''}',
              style: const TextStyle(color: _muted, height: 1.45),
            ),
            if (best['action_label'] != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text('${best['action_label']}')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Find my fit',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Replayable onboarding that recommends a package from your actual work—not a mandatory gate that traps you before using the app.',
          style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: _cyan)),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final two = c.maxWidth > 900;
            final width = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(width: width, child: _dropdown('Who are you?', _audience, _audiences, (v) => setState(() => _audience = v ?? _audience))),
                SizedBox(width: width, child: _dropdown('Property focus', _propertyFocus, _propertyFocuses, (v) => setState(() => _propertyFocus = v ?? _propertyFocus))),
                SizedBox(width: width, child: _dropdown('Primary goal', _goal, _goals, (v) => setState(() => _goal = v ?? _goal))),
                SizedBox(width: width, child: _dropdown('Team size', _teamScale, _teamScales, (v) => setState(() => _teamScale = v ?? _teamScale))),
                SizedBox(width: width, child: _dropdown('Territory', _territory, _territories, (v) => setState(() => _territory = v ?? _territory))),
                SizedBox(width: width, child: _dropdown('Delivery / integration', _integration, _integrations, (v) => setState(() => _integration = v ?? _integration))),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Text('Capabilities you need',
            style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _capabilityOptions
              .map((cap) => FilterChip(
                    selected: _capabilities.contains(cap),
                    label: Text(cap),
                    onSelected: (selected) => setState(() => selected
                        ? _capabilities.add(cap)
                        : _capabilities.remove(cap)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _preview,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Preview best fit'),
            ),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save onboarding + recommendation'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _recommendation(),
      ],
    );
  }
}
