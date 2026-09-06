import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BridgePointOwnerDownloadCenterV1896 extends StatelessWidget {
  const BridgePointOwnerDownloadCenterV1896({super.key});

  static const _base = 'https://bridgepointintelligence.online/app';
  static const _panel = Color(0xFF0B1A2B);
  static const _cyan = Color(0xFF48E1FF);
  static const _gold = Color(0xFFFFC95E);
  static const _green = Color(0xFF45E6A6);
  static const _muted = Color(0xFFB5C6D9);

  Future<void> _open(BuildContext context, String path) async {
    final uri = Uri.parse('$_base$path');
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String detail,
    required String button,
    required String path,
    String? warning,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 11),
        color: _panel,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 10),
              Text(detail,
                  style: const TextStyle(color: _muted, height: 1.45)),
              if (warning != null) ...[
                const SizedBox(height: 8),
                Text(warning,
                    style: const TextStyle(
                        color: _gold,
                        height: 1.4,
                        fontWeight: FontWeight.w800)),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _open(context, path),
                icon: const Icon(Icons.download_rounded),
                label: Text(button),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Owner Downloads & 3D',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text(
            'Direct owner tools for the local computer and the new 3D world. Final export remains deliberately locked until the build is finished, storage is checked, and Node is upgraded.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.public_rounded,
            color: _cyan,
            title: 'Launch BridgePoint 3D World',
            detail:
                'Open the new Cesium-based continuous 3D world shell. It streams BridgePoint viewport building geometry by camera level-of-detail and can resolve bound buildings into the live property profile.',
            button: 'Open 3D World',
            path: '/bridgepoint-3d-world/',
          ),
          _card(
            context,
            icon: Icons.storage_rounded,
            color: _green,
            title: 'Storage readiness PowerShell',
            detail:
                'Read-only disk-space, Node/npm, and largest-folder report for the owner computer. It does not delete anything and does not start an export.',
            button: 'Download storage check',
            path: '/owner-downloads/bridgepoint-storage-check.ps1',
          ),
          _card(
            context,
            icon: Icons.developer_mode_rounded,
            color: _cyan,
            title: 'Local Node readiness PowerShell',
            detail:
                'Checks the current local Node/npm state and prints the exact sequencing rule: finish build → check storage → upgrade Node → verify version → only then consider final export.',
            button: 'Download Node helper',
            path: '/owner-downloads/bridgepoint-local-node-readiness.ps1',
          ),
          _card(
            context,
            icon: Icons.inventory_2_outlined,
            color: _gold,
            title: 'Full export readiness instructions',
            detail:
                'Download the final-export gate/checklist now so it is ready on the computer. This is intentionally instructions-only until the owner declares the build ready.',
            warning:
                'This button does NOT start the database export. Automatic final export is still forbidden.',
            button: 'Download export instructions',
            path: '/owner-downloads/bridgepoint-full-export-readiness.md',
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: .22)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: _gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nearmap API: locked/paused. Nothing in this screen creates an API or gives Nearmap bulk access. A later agreement must define the exact allowed products and fields first.',
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
