import 'package:flutter/material.dart';

import '../bridgepoint_integrations_hub_v790.dart';
import 'bridgepoint_operations_hub.dart';
import 'bridgepoint_owner_ai_cockpit.dart';
import 'bridgepoint_owner_engine_health_v777.dart';
import 'bridgepoint_owner_global_control.dart';
import 'bridgepoint_owner_overview_v2.dart';
import 'bridgepoint_owner_surface_audit_v792.dart';
import 'bridgepoint_owner_us_completion_v3.dart';
import 'bridgepoint_owner_v2_requirements_v832.dart';

class BridgePointOwnerCommandCenterV3 extends StatefulWidget {
  const BridgePointOwnerCommandCenterV3({super.key});

  @override
  State<BridgePointOwnerCommandCenterV3> createState() =>
      _BridgePointOwnerCommandCenterV3State();
}

class _BridgePointOwnerCommandCenterV3State
    extends State<BridgePointOwnerCommandCenterV3> {
  int section = 0;
  _Tool? activeTool;

  static const _cyan = Color(0xFF48E1FF);
  static const _muted = Color(0xFFB5C6D9);
  static const _panel = Color(0xFF0D2034);

  @override
  Widget build(BuildContext context) {
    if (activeTool != null) {
      return Column(
        children: [
          Container(
            color: const Color(0xEE071321),
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to Owner Tools',
                  onPressed: () => setState(() => activeTool = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Icon(activeTool!.icon, color: _cyan),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    activeTool!.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: activeTool!.page),
        ],
      );
    }

    return Column(
      children: [
        Container(
          color: const Color(0xEE071321),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.space_dashboard_rounded),
                  label: Text('Overview'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.checklist_rounded),
                  label: Text('U.S. Completion'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.public_rounded),
                  label: Text('Global / Export'),
                ),
                ButtonSegment(
                  value: 3,
                  icon: Icon(Icons.apps_rounded),
                  label: Text('Tools'),
                ),
              ],
              selected: <int>{section},
              onSelectionChanged: (value) =>
                  setState(() => section = value.first),
            ),
          ),
        ),
        Expanded(
          child: switch (section) {
            0 => const BridgePointOwnerOverviewV2(),
            1 => const BridgePointOwnerUsCompletionV3(),
            2 => const BridgePointOwnerGlobalControl(),
            _ => _tools(),
          },
        ),
      ],
    );
  }

  Widget _tools() {
    final tools = <_Tool>[
      const _Tool(
        'Engine Health',
        'Workers, pipelines, throughput, errors and autonomous health.',
        Icons.speed_rounded,
        BridgePointOwnerEngineHealthV777(),
      ),
      const _Tool(
        'Requirements',
        'The detailed owner requirement ledger and implementation truth.',
        Icons.rule_folder_rounded,
        BridgePointOwnerV2Requirements(),
      ),
      const _Tool(
        'AI Cockpit',
        'BridgePoint AI workers, reasoning and controlled AI operations.',
        Icons.auto_awesome_rounded,
        BridgePointOwnerAiCockpit(),
      ),
      const _Tool(
        'Operations',
        'Backend operations, refresh actions and operational workflows.',
        Icons.build_circle_outlined,
        BridgePointOperationsHub(),
      ),
      const _Tool(
        'App Surfaces',
        'Audit what backend capabilities are actually exposed in the app.',
        Icons.visibility_outlined,
        BridgePointOwnerSurfaceAudit(),
      ),
      const _Tool(
        'Integrations',
        'External systems, partner adapters and connection status.',
        Icons.hub_outlined,
        BridgePointIntegrationsHub(),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text(
          'Owner tools',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Everything technical still exists. It just does not need to be a permanent tab.',
          style: TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 3
                : constraints.maxWidth >= 650
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tool in tools)
                  SizedBox(
                    width: width,
                    child: Card(
                      color: _panel,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() => activeTool = tool),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(tool.icon, color: _cyan, size: 28),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: _muted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                tool.label,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tool.detail,
                                style: const TextStyle(
                                  color: _muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Tool {
  const _Tool(this.label, this.detail, this.icon, this.page);
  final String label;
  final String detail;
  final IconData icon;
  final Widget page;
}
