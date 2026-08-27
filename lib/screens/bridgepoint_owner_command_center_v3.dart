import 'package:flutter/material.dart';

import '../bridgepoint_integrations_hub_v790.dart';
import 'bridgepoint_operations_hub.dart';
import 'bridgepoint_owner_ai_cockpit.dart';
import 'bridgepoint_owner_engine_health_v777.dart';
import 'bridgepoint_owner_global_control.dart';
import 'bridgepoint_owner_overview_v3.dart';
import 'bridgepoint_owner_surface_audit_v792.dart';
import 'bridgepoint_owner_v2_requirements_v832.dart';

class BridgePointOwnerCommandCenterV3 extends StatefulWidget {
  const BridgePointOwnerCommandCenterV3({super.key});

  @override
  State<BridgePointOwnerCommandCenterV3> createState() => _BridgePointOwnerCommandCenterV3State();
}

class _BridgePointOwnerCommandCenterV3State extends State<BridgePointOwnerCommandCenterV3> {
  int _tab = 0;
  int? _advanced;

  static const _navy = Color(0xFF071321);
  static const _cyan = Color(0xFF48E1FF);
  static const _gold = Color(0xFFFFC95E);
  static const _muted = Color(0xFFB5C6D9);

  Widget _advancedMenu() {
    if (_advanced != null) {
      final child = switch (_advanced!) {
        0 => const BridgePointOwnerAiCockpit(),
        1 => const BridgePointOperationsHub(),
        2 => const BridgePointOwnerSurfaceAudit(),
        _ => const BridgePointIntegrationsHub(),
      };
      return Column(
        children: [
          Container(
            color: _navy,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _advanced = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Advanced owner tools', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
    }

    final items = const [
      ('AI control', 'Local/provider reasoning status and owner-only AI controls', Icons.auto_awesome_rounded, 0),
      ('Operations', 'Worker, scheduler and execution controls', Icons.precision_manufacturing_outlined, 1),
      ('Surface audit', 'Owner-only UI/surface verification', Icons.visibility_outlined, 2),
      ('Integrations', 'Data exchange and integration controls', Icons.hub_outlined, 3),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Advanced', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
          'Raw diagnostics and specialist controls stay here so the normal owner experience remains readable.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(item.$3, color: _cyan),
              title: Text(item.$1),
              subtitle: Text(item.$2),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() => _advanced = item.$4),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_tab) {
      0 => const BridgePointOwnerOverviewV3(),
      1 => const BridgePointOwnerGlobalControl(),
      2 => const BridgePointOwnerEngineHealthV777(),
      3 => const BridgePointOwnerV2Requirements(),
      _ => _advancedMenu(),
    };

    return Column(
      children: [
        Container(
          color: _navy,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.space_dashboard_rounded), label: Text('Overview')),
                ButtonSegment(value: 1, icon: Icon(Icons.public_rounded), label: Text('Expansion & Export')),
                ButtonSegment(value: 2, icon: Icon(Icons.speed_rounded), label: Text('Automation')),
                ButtonSegment(value: 3, icon: Icon(Icons.rule_folder_rounded), label: Text('Build')),
                ButtonSegment(value: 4, icon: Icon(Icons.tune_rounded, color: _gold), label: Text('Advanced')),
              ],
              selected: <int>{_tab},
              onSelectionChanged: (value) => setState(() {
                _tab = value.first;
                _advanced = null;
              }),
            ),
          ),
        ),
        Expanded(child: page),
      ],
    );
  }
}
