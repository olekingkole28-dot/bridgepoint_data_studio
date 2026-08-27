import 'package:flutter/material.dart';

import 'bridgepoint_owner_command_center_v3.dart';

/// Compatibility entry point used by the BridgePoint application shell.
/// V3 keeps normal owner operations readable and moves raw diagnostics into Advanced.
class BridgePointOwnerCommandCenter extends StatelessWidget {
  const BridgePointOwnerCommandCenter({super.key});

  @override
  Widget build(BuildContext context) => const BridgePointOwnerCommandCenterV3();
}
