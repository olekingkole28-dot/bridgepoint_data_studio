/// Purchase/readiness policy shared by customer package surfaces.
///
/// A package is self-checkout eligible only when the package catalog explicitly
/// marks it READY, checkout_ready, and available_for_self_checkout, and its
/// purchase mode is IMMEDIATE. Missing or malformed readiness metadata fails
/// closed; a Stripe price row alone is not a customer-facing release decision.
class BridgePointPackagePurchasePolicyV1 {
  const BridgePointPackagePurchasePolicyV1._();

  static Map<String, dynamic> _configuration(
    Map<String, dynamic> package,
  ) {
    final raw = package['configuration'];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
  }

  static dynamic _field(Map<String, dynamic> package, String key) {
    if (package[key] != null) return package[key];
    return _configuration(package)[key];
  }

  static bool _bool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  static bool? _optionalBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }

  static String _text(Map<String, dynamic> package, String key) =>
      (_field(package, key) ?? '').toString().trim().toUpperCase();

  /// Returns BUY, REQUEST, or BUILDING.
  ///
  /// Self-checkout is an explicit conjunction: IMMEDIATE + READY +
  /// checkout_ready + available_for_self_checkout, with no approval gate.
  /// Commercially requestable packages go through human activation instead.
  static String action(Map<String, dynamic> package) {
    final mode = _text(package, 'purchase_mode');
    final delivery = _text(package, 'delivery_status');
    final checkoutReady = _bool(_field(package, 'checkout_ready'));
    final selfCheckout =
        _bool(_field(package, 'available_for_self_checkout'));
    final ownerApproval =
        _bool(_field(package, 'owner_approval_required'));
    final availableNow = _optionalBool(_field(package, 'available_now'));
    final commerciallyRequestable =
        _optionalBool(_field(package, 'commercially_requestable'));

    final buyEligible = mode == 'IMMEDIATE' &&
        delivery == 'READY' &&
        checkoutReady &&
        selfCheckout &&
        !ownerApproval &&
        availableNow != false &&
        commerciallyRequestable != true;

    if (buyEligible) return 'BUY';

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

  static bool canSelfCheckout(Map<String, dynamic> package) =>
      action(package) == 'BUY';
}
