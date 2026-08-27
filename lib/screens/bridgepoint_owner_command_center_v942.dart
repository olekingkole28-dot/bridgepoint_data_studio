import 'package:flutter/material.dart';

import '../bridgepoint_integrations_hub_v790.dart';
import 'bridgepoint_operations_hub.dart';
import 'bridgepoint_owner_ai_cockpit.dart';
import 'bridgepoint_owner_engine_health_v777.dart';
import 'bridgepoint_owner_global_control.dart';
import 'bridgepoint_owner_overview_v942.dart';
import 'bridgepoint_owner_surface_audit_v792.dart';
import 'bridgepoint_owner_v2_requirements_v832.dart';

class BridgePointOwnerCommandCenterV942 extends StatefulWidget {
  const BridgePointOwnerCommandCenterV942({super.key});

  @override
  State<BridgePointOwnerCommandCenterV942> createState() => _BridgePointOwnerCommandCenterV942State();
}

class _BridgePointOwnerCommandCenterV942State extends State<BridgePointOwnerCommandCenterV942> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        color: const Color(0xFF071321),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.space_dashboard_rounded), label: Text('Overview')),
              ButtonSegment(value: 1, icon: Icon(Icons.public_rounded), label: Text('Build & Expansion')),
              ButtonSegment(value: 2, icon: Icon(Icons.auto_awesome_rounded), label: Text('AI & Automation')),
              ButtonSegment(value: 3, icon: Icon(Icons.tune_rounded), label: Text('Advanced')),
            ],
            selected: {tab},
            onSelectionChanged: (v) => setState(() => tab = v.first),
          ),
        ),
      ),
      Expanded(
        child: switch (tab) {
          0 => const BridgePointOwnerOverviewV942(),
          1 => const BridgePointOwnerGlobalControl(),
          2 => const BridgePointOwnerAiCockpit(),
          _ => const _AdvancedOwnerHub(),
        },
      ),
    ]);
  }
}

class _AdvancedOwnerHub extends StatefulWidget {
  const _AdvancedOwnerHub();

  @override
  State<_AdvancedOwnerHub> createState() => _AdvancedOwnerHubState();
}

class _AdvancedOwnerHubState extends State<_AdvancedOwnerHub> {
  String? selected;

  Widget _page() => switch (selected) {
        'health' => const BridgePointOwnerEngineHealthV777(),
        'requirements' => const BridgePointOwnerV2Requirements(),
        'operations' => const BridgePointOperationsHub(),
        'surfaces' => const BridgePointOwnerSurfaceAudit(),
        'integrations' => const BridgePointIntegrationsHub(),
        _ => const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    if (selected != null) {
      return Column(children: [
        Container(
          color: const Color(0xFF071321),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(children: [
            IconButton(onPressed: () => setState(() => selected = null), icon: const Icon(Icons.arrow_back_rounded)),
            const SizedBox(width: 4),
            Text(switch (selected) {
              'health' => 'Engine Health',
              'requirements' => 'Requirements',
              'operations' => 'Operations',
              'surfaces' => 'Surface Audit',
              _ => 'Integrations',
            }, style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ),
        Expanded(child: _page()),
      ]);
    }

    const items = [
      ('health', Icons.monitor_heart_outlined, 'Engine Health', 'Schedulers, failures and production-health checks.'),
      ('requirements', Icons.rule_folder_outlined, 'Requirements', 'The locked completion ledger and verification state.'),
      ('operations', Icons.build_circle_outlined, 'Operations', 'Owner operating controls and maintenance workflows.'),
      ('surfaces', Icons.visibility_outlined, 'Surface Audit', 'Owner-only review of customer and admin surfaces.'),
      ('integrations', Icons.hub_outlined, 'Integrations', 'Technical data exchange and integration controls.'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Advanced owner tools', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('Technical controls stay here instead of competing with everyday Owner status.', style: TextStyle(color: Color(0xFFB5C6D9), height: 1.45)),
        const SizedBox(height: 15),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 850 ? 2 : 1;
          final width = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: InkWell(
                  onTap: () => setState(() => selected = item.$1),
                  borderRadius: BorderRadius.circular(17),
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2035),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withValues(alpha: .10)),
                    ),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF48E1FF).withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(item.$2, color: const Color(0xFF48E1FF))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.$3, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(item.$4, style: const TextStyle(color: Color(0xFFB5C6D9), fontSize: 12.5, height: 1.4)),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFB5C6D9)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
      ],
    );
  }
}
