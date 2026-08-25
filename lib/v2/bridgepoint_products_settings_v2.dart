import 'package:flutter/material.dart';

import 'settings/bridgepoint_display_settings_v2.dart';
import 'settings/bridgepoint_legal_trust_v2.dart';
import 'settings/bridgepoint_notifications_settings_v2.dart';
import 'settings/bridgepoint_package_fit_v2.dart';
import 'settings/bridgepoint_packages_v2.dart';

class BridgePointProductsSettingsV2 extends StatefulWidget {
  const BridgePointProductsSettingsV2({super.key});

  @override
  State<BridgePointProductsSettingsV2> createState() =>
      _BridgePointProductsSettingsV2State();
}

class _BridgePointProductsSettingsV2State
    extends State<BridgePointProductsSettingsV2> {
  int _tab = 0;

  static const _muted = Color(0xFF8FA5BF);

  Widget _page() => switch (_tab) {
        0 => const BridgePointPackagesV2(),
        1 => const BridgePointPackageFitV2(),
        2 => const BridgePointNotificationsSettingsV2(),
        3 => const BridgePointDisplaySettingsV2(),
        _ => const BridgePointLegalTrustV2(),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Products & Settings',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Commercial access, replayable onboarding, alerts, accessibility, privacy and security controls—organized without hiding backend truth.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.workspace_premium_outlined),
                label: Text('Packages'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.tune_rounded),
                label: Text('Find my fit'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.notifications_active_outlined),
                label: Text('Notifications'),
              ),
              ButtonSegment(
                value: 3,
                icon: Icon(Icons.accessibility_new_rounded),
                label: Text('Display'),
              ),
              ButtonSegment(
                value: 4,
                icon: Icon(Icons.verified_user_outlined),
                label: Text('Legal & Trust'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (value) =>
                setState(() => _tab = value.first),
          ),
        ),
        const SizedBox(height: 14),
        _page(),
      ],
    );
  }
}
