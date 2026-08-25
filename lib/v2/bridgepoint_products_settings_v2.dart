import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
        4 => const BridgePointLegalTrustV2(),
        _ => const _AboutBridgePointV2(),
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
          'Commercial access, onboarding, alerts, accessibility, privacy, security and BridgePoint company information—organized without hiding backend truth.',
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
              ButtonSegment(
                value: 5,
                icon: Icon(Icons.info_outline_rounded),
                label: Text('About BridgePoint'),
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

class _AboutBridgePointV2 extends StatelessWidget {
  const _AboutBridgePointV2();

  static const _panel = Color(0xFF0D1A2B);
  static const _panelSoft = Color(0xFF122238);
  static const _cyan = Color(0xFF35D2E8);
  static const _blue = Color(0xFF4F7CFF);
  static const _green = Color(0xFF38D49A);
  static const _amber = Color(0xFFFFC857);
  static const _muted = Color(0xFF8FA5BF);

  Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.platformDefault);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_panel, _blue.withValues(alpha: .12)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cyan.withValues(alpha: .18)),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 760;
              final identity = const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 31,
                    backgroundColor: _blue,
                    child: Icon(Icons.person_rounded, color: Colors.white, size: 32),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kole Johnson', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                        SizedBox(height: 2),
                        Text('Founder, BridgePoint Intelligence', style: TextStyle(color: _cyan, fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text(
                          'Connecticut-built property intelligence software + data infrastructure • Live product • Early commercialization',
                          style: TextStyle(color: _muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _open(Uri.parse('https://bridgepointintelligence.online')),
                    icon: const Icon(Icons.language_rounded),
                    label: const Text('bridgepointintelligence.online'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(Uri.parse('mailto:bridgepointintelligence@gmail.com')),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('bridgepointintelligence@gmail.com'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(Uri.parse('tel:2036052389')),
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('203-605-2389'),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 16), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: identity), const SizedBox(width: 18), Flexible(child: actions)],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 650 ? 2 : 1;
            final width = (c.maxWidth - (columns - 1) * 10) / columns;
            const cards = [
              _AboutCard(
                icon: Icons.hub_outlined,
                title: 'What BridgePoint is',
                text: 'A property-intelligence operating system that connects fragmented property, public, weather, environmental, transaction, imagery and business evidence around one canonical property identity.',
                accent: _cyan,
              ),
              _AboutCard(
                icon: Icons.track_changes_rounded,
                title: 'What it does',
                text: 'Turns evidence into explainable signals, scores, ranked opportunities, Property DNA timelines, maps, workflows, portfolio context and next-best-action tools.',
                accent: _blue,
              ),
              _AboutCard(
                icon: Icons.verified_user_outlined,
                title: 'Evidence-first standard',
                text: 'BridgePoint preserves source, date, property match confidence and uncertainty. A high score is prioritization—not a substitute for inspection, engineering, legal, insurance or coverage judgment.',
                accent: _green,
              ),
              _AboutCard(
                icon: Icons.location_on_outlined,
                title: 'Connecticut foundation',
                text: 'Connecticut is the first major deployment, anchored by statewide parcel/CAMA inventory and expanding public, weather, environmental, transaction and physical-intelligence coverage.',
                accent: _amber,
              ),
              _AboutCard(
                icon: Icons.public_rounded,
                title: 'Expansion model',
                text: 'BridgePoint separates LIVE from BUILDING geographies and keeps customer visibility gated until coverage and quality requirements are actually met.',
                accent: _cyan,
              ),
              _AboutCard(
                icon: Icons.groups_rounded,
                title: 'Built for action',
                text: 'Homeowners, contractors, adjusters, investors, property teams, carriers and enterprise users get different package views while sharing one evidence-backed property intelligence foundation.',
                accent: _blue,
              ),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final card in cards) SizedBox(width: width, child: card)],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _panelSoft.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .06)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BridgePoint Founder Growth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text(
                'BridgePoint maintains founder/company presence across TikTok, Facebook, Instagram, LinkedIn, X and YouTube Shorts. Use Share BridgePoint and the permanent website link when introducing the platform.',
                style: TextStyle(color: _muted, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.icon, required this.title, required this.text, required this.accent});
  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _AboutBridgePointV2._panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: accent.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 13),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 5),
            Text(text, style: const TextStyle(color: _AboutBridgePointV2._muted, fontSize: 11, height: 1.45)),
          ],
        ),
      );
}
