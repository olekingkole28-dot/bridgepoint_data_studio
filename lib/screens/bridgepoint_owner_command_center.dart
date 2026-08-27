import 'package:flutter/material.dart';

import 'bridgepoint_owner_command_center_recovered_v3.dart';

/// Recovery branch compatibility entry point. Production stays on its own
/// branch until V3 is verified.
class BridgePointOwnerCommandCenter extends StatelessWidget {
  const BridgePointOwnerCommandCenter({super.key});

  @override
  Widget build(BuildContext context) => const BridgePointOwnerCommandCenterV3();
}
