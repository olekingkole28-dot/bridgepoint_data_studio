import 'package:flutter/material.dart';

import 'bridgepoint_owner_command_center_v2.dart';

/// Compatibility entry point used by the clean BridgePoint shell.
/// The implementation lives in modular V2 owner-control surfaces.
class BridgePointOwnerCommandCenter extends StatelessWidget {
  const BridgePointOwnerCommandCenter({super.key});

  @override
  Widget build(BuildContext context) => const BridgePointOwnerCommandCenterV2();
}
