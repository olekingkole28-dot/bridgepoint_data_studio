from pathlib import Path

MAIN = Path('lib/main.dart')
MARKER = '// bridgepoint-package-purchase-truth-v778'


def replacement() -> str:
    return r'''// bridgepoint-package-purchase-truth-v778
Map<String, dynamic> _packageConfiguration(Map<String, dynamic> package) {
  final raw = package['configuration'];
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
}

bool _packageBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}

String _packagePurchaseMode(Map<String, dynamic> package) {
  final config = _packageConfiguration(package);
  return '${config['purchase_mode'] ?? ''}'.trim().toUpperCase();
}

String _packageDeliveryStatus(Map<String, dynamic> package) {
  final config = _packageConfiguration(package);
  final value = '${config['delivery_status'] ?? ''}'.trim().toUpperCase();
  return value.isEmpty ? 'UNVERIFIED' : value;
}

String _packageActionKind(Map<String, dynamic> package) {
  final config = _packageConfiguration(package);
  final mode = _packagePurchaseMode(package);
  final delivery = _packageDeliveryStatus(package);
  final checkoutReady = _packageBool(config['checkout_ready']);
  final selfCheckout = _packageBool(config['available_for_self_checkout']);
  final ownerApproval = _packageBool(config['owner_approval_required']);
  final availableNowRaw = config['available_now'];
  final commerciallyRequestableRaw = config['commercially_requestable'];
  final availableNow = availableNowRaw == null
      ? null
      : _packageBool(availableNowRaw);
  final commerciallyRequestable = commerciallyRequestableRaw == null
      ? null
      : _packageBool(commerciallyRequestableRaw);

  if (mode == 'IMMEDIATE' &&
      checkoutReady &&
      selfCheckout &&
      delivery == 'READY') {
    return 'BUY';
  }

  if (delivery == 'BUILDING' ||
      delivery == 'ROADMAP' ||
      availableNow == false ||
      commerciallyRequestable == false) {
    return 'BUILDING';
  }

  if (ownerApproval ||
      mode == 'OWNER_APPROVAL_REQUIRED' ||
      commerciallyRequestable == true) {
    return 'REQUEST';
  }

  return 'BUILDING';
}

String _packageActionLabel(Map<String, dynamic> package) {
  switch (_packageActionKind(package)) {
    case 'BUY':
      return 'BUY NOW';
    case 'REQUEST':
      return 'REQUEST ACTIVATION';
    default:
      return 'BUILDING';
  }
}

Color _packageActionColor(Map<String, dynamic> package) {
  switch (_packageActionKind(package)) {
    case 'BUY':
      return AppTheme.green;
    case 'REQUEST':
      return AppTheme.cyan;
    default:
      return AppTheme.amber;
  }
}

String _packageRequestCta(Map<String, dynamic> package) {
  final config = _packageConfiguration(package);
  final value = '${config['request_cta'] ?? ''}'.trim();
  return value.isEmpty ? 'Request activation' : value;
}

String _packageDisclosure(Map<String, dynamic> package) {
  final config = _packageConfiguration(package);
  for (final key in const [
    'customer_delivery_disclosure',
    'delivery_summary',
    'delivery_note',
    'pricing_note',
  ]) {
    final value = '${config[key] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
  }
  final deliveryMode = '${config['customer_delivery_mode'] ?? ''}'
      .trim()
      .replaceAll('_', ' ');
  final delivery = _packageDeliveryStatus(package).replaceAll('_', ' ');
  final action = _packageActionKind(package);
  if (action == 'BUY') {
    return 'Self-serve access is ready after successful checkout and entitlement confirmation.';
  }
  if (action == 'REQUEST') {
    return deliveryMode.isEmpty
        ? 'BridgePoint reviews scope and activation before anything is billed or enabled.'
        : 'Managed delivery mode: $deliveryMode. BridgePoint reviews scope and activation before anything is billed or enabled.';
  }
  return 'Delivery status: $delivery. This package is visible for roadmap transparency but is not available to purchase or activate yet.';
}

String _packagePriceSummary(Map<String, dynamic> package) {
  final monthly = package['monthly_price'] as num?;
  final yearly = package['yearly_price'] as num?;
  final action = _packageActionKind(package);
  if (action == 'BUILDING') return 'Not available to purchase yet';
  if (monthly != null) {
    final prefix = action == 'REQUEST' ? 'Starting at ' : '';
    return '$prefix\$${monthly.toStringAsFixed(0)} / month';
  }
  if (yearly != null) {
    final prefix = action == 'REQUEST' ? 'Starting at ' : '';
    return '$prefix\$${yearly.toStringAsFixed(0)} / year';
  }
  return action == 'REQUEST' ? 'Request scoped pricing' : 'Pricing not configured';
}

Future<void> _requestPackageActivation(
  BuildContext context,
  Map<String, dynamic> package,
) async {
  final packageKey = '${package['package_key'] ?? ''}'.trim().toLowerCase();
  if (packageKey.isEmpty || _packageActionKind(package) != 'REQUEST') return;
  try {
    final technology = packageKey.startsWith('technology_');
    final result = await _callRpc(
      technology
          ? 'bridgepoint_request_technology_package_v93'
          : 'bridgepoint_request_owner_approved_package_v323',
      {'p_package_key': packageKey, 'p_note': null},
    );
    if (!context.mounted) return;
    _showInfoDialog(
      context,
      'Activation request saved',
      '${result['message'] ?? 'BridgePoint saved your request. Nothing is billed or activated automatically.'}',
    );
  } catch (e) {
    if (context.mounted) {
      _showInfoDialog(context, 'Could not save request', e.toString());
    }
  }
}

class _LivePackageCard extends StatelessWidget {
  const _LivePackageCard({required this.package});

  final Map<String, dynamic> package;

  @override
  Widget build(BuildContext context) {
    final rawModels = package['models'];
    final models = rawModels is List
        ? rawModels
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final featured = package['featured'] == true;
    final trialDays = (package['trial_days'] as num?)?.toInt();
    final type = '${package['package_type'] ?? 'standard'}';
    final action = _packageActionKind(package);
    final actionColor = _packageActionColor(package);
    final delivery = _packageDeliveryStatus(package).replaceAll('_', ' ');

    return Card(
      child: InkWell(
        onTap: () => _showPackageDetail(context, package),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: actionColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${package['package_name'] ?? 'BridgePoint Package'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (featured)
                    const _OpportunityChip(
                      label: 'FEATURED',
                      color: AppTheme.green,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${package['description'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _OpportunityChip(
                    label: _packageActionLabel(package),
                    color: actionColor,
                  ),
                  _OpportunityChip(
                    label: delivery.toUpperCase(),
                    color: delivery == 'READY' ? AppTheme.green : AppTheme.amber,
                  ),
                  _OpportunityChip(
                    label: '${models.length} MODEL${models.length == 1 ? '' : 'S'}',
                    color: AppTheme.blue,
                  ),
                  if (trialDays != null && trialDays > 0 && action == 'BUY')
                    _OpportunityChip(
                      label: '$trialDays DAY TRIAL',
                      color: AppTheme.cyan,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (models.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.panelSoft.withOpacity(.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    action == 'REQUEST'
                        ? 'Scoped BridgePoint delivery; activation is reviewed before access.'
                        : action == 'BUILDING'
                            ? 'Capability is visible for roadmap transparency; delivery is not active yet.'
                            : 'Custom intelligence model builder',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                    ),
                  ),
                )
              else
                ...models.take(4).map(
                      (model) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppTheme.green,
                              size: 14,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              if (models.length > 4)
                Text(
                  '+ ${models.length - 4} more models',
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _packagePriceSummary(package),
                      style: TextStyle(
                        color: action == 'BUILDING'
                            ? AppTheme.textMuted
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _packageIcon(String key) {
  switch (key) {
    case 'company':
      return Icons.groups_2_outlined;
    case 'homeowner':
      return Icons.cottage_outlined;
    case 'home':
      return Icons.home_work_outlined;
    case 'commercial':
      return Icons.business_outlined;
    case 'solar':
      return Icons.solar_power_outlined;
    case 'investor':
      return Icons.trending_up_rounded;
    case 'infrastructure':
      return Icons.construction_outlined;
    case 'custom_model':
      return Icons.tune_rounded;
    case 'all_intelligence':
      return Icons.all_inclusive_rounded;
    default:
      return key.startsWith('technology_')
          ? Icons.developer_board_outlined
          : Icons.inventory_2_outlined;
  }
}

void _showPackageDetail(
  BuildContext context,
  Map<String, dynamic> package,
) {
  final rawModels = package['models'];
  final models = rawModels is List
      ? rawModels
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];
  final action = _packageActionKind(package);
  final actionColor = _packageActionColor(package);
  final delivery = _packageDeliveryStatus(package).replaceAll('_', ' ');
  final monthly = package['monthly_price'] as num?;
  final yearly = package['yearly_price'] as num?;
  final trialDays = (package['trial_days'] as num?)?.toInt() ?? 0;

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _packageIcon('${package['package_key'] ?? ''}'),
                      color: actionColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${package['package_name'] ?? 'BridgePoint Package'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${package['description'] ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(label: 'MODELS', value: '${models.length}'),
                    _MiniStat(label: 'ACCESS', value: _packageActionLabel(package)),
                    _MiniStat(label: 'DELIVERY', value: delivery),
                    _MiniStat(
                      label: 'TYPE',
                      value: '${package['package_type'] ?? '—'}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: actionColor.withOpacity(.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _packageActionLabel(package),
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _packageDisclosure(package),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Included intelligence models',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (models.isEmpty)
                  Text(
                    action == 'BUY'
                        ? 'This package provides a configurable BridgePoint capability rather than a fixed model bundle.'
                        : 'Scope and model delivery are confirmed during activation review.',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  )
                else
                  ...models.map(
                    (model) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft.withOpacity(.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${model['model_name'] ?? model['model_key'] ?? 'Model'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${model['description'] ?? ''}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (action == 'BUY') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cyan.withOpacity(.16)),
                    ),
                    child: Text(
                      trialDays > 0
                          ? 'Start with a $trialDays-day free trial. Checkout and entitlement state are confirmed server-side.'
                          : 'This package is ready for self-serve checkout. Entitlement state is confirmed server-side.',
                      style: const TextStyle(
                        color: AppTheme.cyan,
                        fontSize: 10,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: monthly == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _startCheckout(context, package, 'month');
                              },
                        icon: const Icon(Icons.bolt_rounded),
                        label: Text(monthly == null
                            ? 'Monthly unavailable'
                            : 'Start monthly • \$${monthly.toStringAsFixed(0)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: yearly == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _startCheckout(context, package, 'year');
                              },
                        child: Text(yearly == null
                            ? 'Annual unavailable'
                            : 'Annual • \$${yearly.toStringAsFixed(0)}'),
                      ),
                    ),
                  ]),
                ] else if (action == 'REQUEST') ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _requestPackageActivation(context, package);
                      },
                      icon: const Icon(Icons.business_center_outlined),
                      label: Text(_packageRequestCta(package)),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Submitting a request does not create a charge or entitlement. BridgePoint owner approval and delivery review happen first.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      height: 1.4,
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.construction_rounded),
                      label: const Text('Building — not available yet'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

'''


def main() -> None:
    text = MAIN.read_text(encoding='utf-8')
    if MARKER in text:
        print('Package purchase truth v778 already present; no change.')
        return
    start_marker = 'class _LivePackageCard extends StatelessWidget {'
    end_marker = 'class _FieldModePage extends StatefulWidget {'
    start = text.find(start_marker)
    end = text.find(end_marker, start)
    if start < 0 or end < 0:
        raise SystemExit('Could not isolate current package card/detail block.')
    updated = text[:start] + replacement() + text[end:]
    MAIN.write_text(updated, encoding='utf-8')
    print('Applied server-driven package purchase/delivery truth v778.')


if __name__ == '__main__':
    main()
