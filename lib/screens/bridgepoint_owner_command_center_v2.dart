import 'package:flutter/material.dart';

import 'bridgepoint_operations_hub.dart';
import 'bridgepoint_owner_ai_cockpit.dart';
import 'bridgepoint_owner_global_control.dart';
import 'bridgepoint_owner_surface_audit_v792.dart';
import 'bridgepoint_owner_v2_requirements_v832.dart';

class BridgePointOwnerCommandCenterV2 extends StatefulWidget {
  const BridgePointOwnerCommandCenterV2({super.key});

  @override
  State<BridgePointOwnerCommandCenterV2> createState() =>
      _BridgePointOwnerCommandCenterV2State();
}

class _BridgePointOwnerCommandCenterV2State
    extends State<BridgePointOwnerCommandCenterV2> {
  int _tab = 0;

  static const _navy = Color(0xFF071321);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: _navy,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.rule_folder_rounded),
                  label: Text('V2 Requirements'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.auto_awesome_rounded),
                  label: Text('AI Cockpit'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.public_rounded),
                  label: Text('Global / Export'),
                ),
                ButtonSegment(
                  value: 3,
                  icon: Icon(Icons.build_circle_outlined),
                  label: Text('Operations'),
                ),
                ButtonSegment(
                  value: 4,
                  icon: Icon(Icons.visibility_outlined),
                  label: Text('Surfaces'),
                ),
              ],
              selected: <int>{_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => const BridgePointOwnerV2Requirements(),
            1 => const BridgePointOwnerAiCockpit(),
            2 => const BridgePointOwnerGlobalControl(),
            3 => const BridgePointOperationsHub(),
            _ => const BridgePointOwnerSurfaceAudit(),
          },
        ),
      ],
    );
  }
}
