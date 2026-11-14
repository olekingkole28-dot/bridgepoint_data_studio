import 'package:flutter_test/flutter_test.dart';
import 'package:bridgepoint_data_studio/v2/settings/bridgepoint_package_purchase_policy_v1.dart';

void main() {
  group('BridgePointPackagePurchasePolicyV1', () {
    Map<String, dynamic> readyPackage({
      bool checkoutReady = true,
      bool selfCheckout = true,
      String mode = 'IMMEDIATE',
      String delivery = 'READY',
      bool ownerApproval = false,
      Object? availableNow,
      Object? commerciallyRequestable,
    }) {
      return {
        'package_key': 'home',
        'configuration': {
          'purchase_mode': mode,
          'delivery_status': delivery,
          'checkout_ready': checkoutReady,
          'available_for_self_checkout': selfCheckout,
          'owner_approval_required': ownerApproval,
          if (availableNow != null) 'available_now': availableNow,
          if (commerciallyRequestable != null)
            'commercially_requestable': commerciallyRequestable,
        },
      };
    }

    test('allows immediate purchase only when every readiness gate is true', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action(readyPackage()),
        'BUY',
      );
    });

    test('does not infer self-checkout from checkout_ready alone', () {
      final package = readyPackage(selfCheckout: false);
      expect(
        BridgePointPackagePurchasePolicyV1.action(package),
        'BUILDING',
      );
      expect(
        BridgePointPackagePurchasePolicyV1.canSelfCheckout(package),
        isFalse,
      );
    });

    test('does not infer self-checkout from a Stripe-ready row alone', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action(
          readyPackage(checkoutReady: false, selfCheckout: true),
        ),
        'BUILDING',
      );
    });

    test('requires explicit immediate and ready delivery metadata', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action(
          readyPackage(mode: 'FOUNDING_EARLY_ACCESS'),
        ),
        'BUILDING',
      );
      expect(
        BridgePointPackagePurchasePolicyV1.action(
          readyPackage(delivery: 'LIMITED'),
        ),
        'BUILDING',
      );
    });

    test('routes approval-required products to a human activation request', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action(
          readyPackage(
            mode: 'MANAGED_ACTIVATION',
            selfCheckout: false,
          ),
        ),
        'REQUEST',
      );
    });

    test('routes commercially requestable products to a request', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action(
          readyPackage(
            selfCheckout: false,
            commerciallyRequestable: true,
          ),
        ),
        'REQUEST',
      );
    });

    test('does not offer a request for a package marked unavailable', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action(
          readyPackage(
            selfCheckout: false,
            commerciallyRequestable: false,
          ),
        ),
        'BUILDING',
      );
    });

    test('fails closed when package readiness metadata is missing', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action({
          'package_key': 'unknown',
          'configuration': <String, dynamic>{},
        }),
        'BUILDING',
      );
    });

    test('supports top-level normalized catalog fields', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action({
          'purchase_mode': 'IMMEDIATE',
          'delivery_status': 'READY',
          'checkout_ready': true,
          'available_for_self_checkout': true,
        }),
        'BUY',
      );
    });

    test('owner approval always blocks an otherwise ready checkout', () {
      expect(
        BridgePointPackagePurchasePolicyV1.action(
          readyPackage(ownerApproval: true),
        ),
        'REQUEST',
      );
    });
  });
}
