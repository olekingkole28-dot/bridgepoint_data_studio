from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

marker = '// bridgepoint-technology-clarity-v796'
if marker in text:
    print('Enterprise technology clarity already applied v796')
    raise SystemExit(0)

start = text.find('void _showPackageDetail(')
end = text.find('\nclass ', start)
if start < 0 or end < 0:
    raise SystemExit('technology-detail: current package detail function missing')
block = text[start:end]

# The modern v778 package truth layer owns purchase/delivery state. Extend that
# exact model instead of reintroducing technology_* purchase guesses.
trial_anchor = "  final trialDays = (package['trial_days'] as num?)?.toInt() ?? 0;\n"
if block.count(trial_anchor) != 1:
    raise SystemExit(
        f'technology-detail-config: expected current v778 trial anchor once, found {block.count(trial_anchor)}')
config = """  final trialDays = (package['trial_days'] as num?)?.toInt() ?? 0;
  final configuration = _packageConfiguration(package);
  final packageKey = '${package['package_key'] ?? ''}'.trim().toLowerCase();
  final technology = packageKey.startsWith('technology_') ||
      '${package['package_type'] ?? ''}'.toLowerCase().contains('technology');
  final bestFor = '${configuration['best_for'] ?? ''}'.trim();
  final problemSolved = '${configuration['problem_solved'] ?? ''}'.trim();
  final delivers = '${configuration['delivers'] ?? ''}'.trim();
  final maturity = '${configuration['maturity'] ?? configuration['delivery_status'] ?? ''}'
      .trim()
      .replaceAll('_', ' ');
  final deliveryModes = (configuration['delivery_modes'] is List
          ? configuration['delivery_modes'] as List
          : const <dynamic>[])
      .map((value) => '$value'.replaceAll('_', ' '))
      .where((value) => value.trim().isNotEmpty)
      .toList();
"""
block = block.replace(trial_anchor, config, 1)

# Insert the enterprise explanation after the authoritative v778 disclosure and
# before the included-model list. It is presentation-only and never changes
# purchase eligibility, entitlement or delivery status.
models_anchor = """                const SizedBox(height: 22),
                const Text(
                  'Included intelligence models',
"""
if block.count(models_anchor) != 1:
    raise SystemExit(
        f'technology-explainer-panel: expected current included-model anchor once, found {block.count(models_anchor)}')
panel = r'''                if (technology) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.amber.withOpacity(.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.apartment_rounded,
                                color: AppTheme.amber, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Enterprise delivery context',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bestFor.isEmpty
                              ? 'Enterprise teams that need this BridgePoint capability inside their own workflow, data platform, or product.'
                              : bestFor,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                        if (problemSolved.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          const Text(
                            'PROBLEM IT SOLVES',
                            style: TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(problemSolved,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  height: 1.45)),
                        ],
                        if (delivers.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          const Text(
                            'WHAT YOU GET',
                            style: TextStyle(
                              color: AppTheme.green,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(delivers,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  height: 1.45)),
                        ],
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (maturity.isNotEmpty)
                              _OpportunityChip(
                                label: maturity.toUpperCase(),
                                color: maturity.toUpperCase().contains('ROADMAP') ||
                                        maturity.toUpperCase().contains('BUILDING')
                                    ? AppTheme.amber
                                    : AppTheme.green,
                              ),
                            ...deliveryModes.take(5).map(
                                  (mode) => _OpportunityChip(
                                    label: mode.toUpperCase(),
                                    color: AppTheme.cyan,
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Where supported, BridgePoint can be delivered through managed service, API/OEM, white-label, private deployment, or governed integration. Protected scoring weights, proprietary learning logic, credentials, and restricted third-party raw data are not transferred by default.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 8.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const Text(
                  'Included intelligence models',
'''
block = block.replace(models_anchor, panel, 1)

# Durable marker belongs inside the generated function but outside visible text.
block = block.replace('void _showPackageDetail(\n', marker + '\nvoid _showPackageDetail(\n', 1)
text = text[:start] + block + text[end:]

for required in [
    marker,
    'Enterprise delivery context',
    'PROBLEM IT SOLVES',
    'WHAT YOU GET',
    '_packageConfiguration(package)',
]:
    if required not in text:
        raise SystemExit(f'technology clarity v796 marker missing: {required}')
if text == original:
    raise SystemExit('No technology clarity changes applied')
path.write_text(text, encoding='utf-8')
print('Applied BridgePoint enterprise technology clarity v100/v796')
