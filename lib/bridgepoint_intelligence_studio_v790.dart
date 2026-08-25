import 'package:flutter/material.dart';

class BridgePointIntelligenceStudio extends StatefulWidget {
  const BridgePointIntelligenceStudio({
    super.key,
    required this.onNavigate,
    this.ownerMode = false,
  });

  final ValueChanged<int> onNavigate;
  final bool ownerMode;

  @override
  State<BridgePointIntelligenceStudio> createState() =>
      _BridgePointIntelligenceStudioState();
}

class _BridgePointIntelligenceStudioState
    extends State<BridgePointIntelligenceStudio> {
  String _query = '';
  String _lane = 'ALL';

  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

  static const _stages = <_StudioStage>[
    _StudioStage(
      order: 1,
      lane: 'DATA',
      title: 'Sources & provenance',
      description:
          'Public, licensed, customer-authorized and partner data enters through source-specific adapters with freshness, rights and provenance rules.',
      keywords:
          'sources ingestion adapters provenance licensing api files gis weather permits claims imagery',
      icon: Icons.hub_outlined,
      color: _blue,
      navigationIndex: 6,
    ),
    _StudioStage(
      order: 2,
      lane: 'PROPERTY',
      title: 'Canonical property / asset identity',
      description:
          'BridgePoint resolves parcel, address, building, ownership and asset references into one canonical property identity instead of letting each source become its own silo.',
      keywords:
          'property matching parcel address building ownership entity resolution canonical asset',
      icon: Icons.home_work_outlined,
      color: _cyan,
      navigationIndex: 4,
    ),
    _StudioStage(
      order: 3,
      lane: 'INTELLIGENCE',
      title: 'Evidence & signals',
      description:
          'Normalized observations become evidence-backed signals with source, time, confidence and property match context.',
      keywords:
          'evidence signals confidence observations timing source quality direct match corroboration',
      icon: Icons.radar_outlined,
      color: _amber,
      navigationIndex: 5,
    ),
    _StudioStage(
      order: 4,
      lane: 'INTELLIGENCE',
      title: 'Patterns & temporal change',
      description:
          'BridgePoint connects multiple observations over time to detect change, compound conditions and stronger property stories.',
      keywords:
          'patterns temporal change history ownership transitions physical change sequence anomaly',
      icon: Icons.account_tree_outlined,
      color: _amber,
      navigationIndex: 5,
    ),
    _StudioStage(
      order: 5,
      lane: 'AI / MODELS',
      title: 'Models, rules & evaluations',
      description:
          'Models evaluate only evidence-supported properties. Unevidenced assets can be evaluated without receiving a fake 0/100 score.',
      keywords:
          'models ai scoring rules evaluation no active signals machine learning predictive risk',
      icon: Icons.psychology_alt_outlined,
      color: _blue,
      navigationIndex: 11,
    ),
    _StudioStage(
      order: 6,
      lane: 'ACTION',
      title: 'Ranked opportunities',
      description:
          'Qualified evidence becomes finite, explainable opportunities with confidence, priority, why-this-property context and next-step actions.',
      keywords:
          'opportunities leads rank priority explainability score next action qualification',
      icon: Icons.bolt_rounded,
      color: _green,
      navigationIndex: 1,
    ),
    _StudioStage(
      order: 7,
      lane: 'GEO',
      title: 'Geospatial intelligence',
      description:
          'Map property, parcel, building, hazard, radar, infrastructure, imagery and opportunity layers at the resolution where each source is actually meaningful.',
      keywords:
          'map satellite aerial radar weather hail wind fire flood parcel building roof 3d lidar imagery',
      icon: Icons.public_rounded,
      color: _cyan,
      navigationIndex: 3,
    ),
    _StudioStage(
      order: 8,
      lane: 'WORKFLOW',
      title: 'Workflows, field work & follow-up',
      description:
          'Save properties, assign follow-ups, manage notes, field activity, claims context and operational next actions without leaving the intelligence system.',
      keywords:
          'workflow tasks notes calendar saved opportunities field claims crm follow up team',
      icon: Icons.work_history_rounded,
      color: _green,
      navigationIndex: 7,
    ),
    _StudioStage(
      order: 9,
      lane: 'DATA',
      title: 'Permits & regulatory context',
      description:
          'Permit, building-code and jurisdiction context remains tied to the same canonical property and source-provenance model.',
      keywords:
          'permits building code jurisdiction regulation inspection municipal construction',
      icon: Icons.construction_rounded,
      color: _amber,
      navigationIndex: 8,
    ),
    _StudioStage(
      order: 10,
      lane: 'ENTERPRISE',
      title: 'Coverage & expansion truth',
      description:
          'See where BridgePoint is truly live, still building, or unavailable. Geographic visibility never means a state or source is commercially ready.',
      keywords:
          'coverage states national expansion source readiness geography live building locked',
      icon: Icons.travel_explore_rounded,
      color: _blue,
      navigationIndex: 9,
    ),
    _StudioStage(
      order: 11,
      lane: 'ENTERPRISE',
      title: 'Integrations & data exchange',
      description:
          'BridgePoint can exchange canonical intelligence with authorized property, claims, risk, GIS, property-management and AI ecosystems through governed adapters.',
      keywords:
          'integrations api mcp webhook cotality corelogic verisk palantir yardi nearmap eagleview appfolio gis export import',
      icon: Icons.cable_rounded,
      color: _cyan,
      navigationIndex: 14,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lanes = <String>{'ALL', ..._stages.map((stage) => stage.lane)}.toList()
      ..sort((a, b) => a == 'ALL' ? -1 : a.compareTo(b));
    final needle = _query.trim().toLowerCase();
    final visible = _stages.where((stage) {
      if (_lane != 'ALL' && stage.lane != _lane) return false;
      if (needle.isEmpty) return true;
      return '${stage.title} ${stage.description} ${stage.keywords} ${stage.lane}'
          .toLowerCase()
          .contains(needle);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Intelligence Studio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'One operating model for everything BridgePoint knows: where data came from, how it matched, what changed, how intelligence was derived, what is actionable, and where it can flow next.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cyan.withOpacity(.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cyan.withOpacity(.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schema_outlined, color: _cyan, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.ownerMode
                      ? 'Owner mode adds the execution/worker truth in Owner Center; this Studio is the product-facing map of the intelligence architecture. Backend capability is not considered product-complete until it has a deliberate UI, integration/API, or internal-only classification.'
                      : 'Every stage stays explainable. Scores do not replace evidence, map layers do not hide their source, and integrations do not become “connected” until they are actually verified.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 390,
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Find a capability',
                  hintText: 'Try “roof,” “claims,” “ownership,” “AI,” “radar,” or “Palantir”',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _lane,
                dropdownColor: _panelSoft,
                decoration: const InputDecoration(
                  labelText: 'Lane',
                  border: OutlineInputBorder(),
                ),
                items: lanes
                    .map((lane) => DropdownMenuItem(
                          value: lane,
                          child: Text(lane),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _lane = value ?? 'ALL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          const Card(
            color: _panel,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No matching capability. The backend-to-UI coverage requirement treats genuinely unclassified capabilities as unfinished work rather than hiding them.',
                style: TextStyle(color: _muted),
              ),
            ),
          )
        else
          ...visible.map((stage) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _stageCard(stage),
              )),
      ],
    );
  }

  Widget _stageCard(_StudioStage stage) {
    return Card(
      color: _panel,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onNavigate(stage.navigationIndex),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: stage.color.withOpacity(.11),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: stage.color.withOpacity(.2)),
                ),
                child: Center(
                  child: Text(
                    '${stage.order}',
                    style: TextStyle(
                      color: stage.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(stage.icon, color: stage.color, size: 19),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            stage.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          stage.lane,
                          style: TextStyle(
                            color: stage.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stage.description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: _muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioStage {
  const _StudioStage({
    required this.order,
    required this.lane,
    required this.title,
    required this.description,
    required this.keywords,
    required this.icon,
    required this.color,
    required this.navigationIndex,
  });

  final int order;
  final String lane;
  final String title;
  final String description;
  final String keywords;
  final IconData icon;
  final Color color;
  final int navigationIndex;
}
