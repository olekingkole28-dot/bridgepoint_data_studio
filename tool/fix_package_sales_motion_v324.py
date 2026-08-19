from pathlib import Path

path=Path('lib/main.dart')
body=path.read_text(encoding='utf-8')
marker='bridgepoint-v324-contact-sales-package-ui'
if marker in body:
    print('BridgePoint v324 contact-sales package UI already applied.')
    raise SystemExit(0)
if 'bridgepoint-v324-owner-truth-customer-safe-catalog' not in body:
    raise SystemExit('v324 Owner Truth/catalog layer must run first')

purchase="final purchaseMode='${configuration['purchase_mode']??'IMMEDIATE'}'.toUpperCase();"
replacement=purchase+"final salesMotion='${configuration['sales_motion']??''}'.toUpperCase();"
count=body.count(purchase)
if count<2:
    raise SystemExit(f'Expected package purchase-mode anchors, found {count}')
body=body.replace(purchase,replacement,2)

old="""!checkoutReady
                          ? 'CHECKOUT NOT AVAILABLE YET'
                          : monthly == null && yearly == null"""
new="""!checkoutReady
                          ? technology && salesMotion=='CONTACT_SALES'
                              ? monthly != null
                                  ? 'CONTACT SALES • FROM \$${monthly.toStringAsFixed(0)} / month'
                                  : 'CONTACT SALES'
                              : 'CHECKOUT NOT AVAILABLE YET'
                          : monthly == null && yearly == null"""
if old not in body:
    raise SystemExit('Package card availability label anchor missing')
body=body.replace(old,new,1)

old_detail="""                      : checkoutReady
                        ? (technology?'Enterprise purchase is available through secure Stripe checkout. Managed or staged delivery terms are shown before payment.':'Start with the configured trial where eligible. Secure Stripe checkout activates the server-side package entitlement after successful payment.')
                        : 'Checkout is not available for this package yet.',"""
new_detail="""                      : checkoutReady
                        ? (technology?'Enterprise purchase is available through secure Stripe checkout. Managed or staged delivery terms are shown before payment.':'Start with the configured trial where eligible. Secure Stripe checkout activates the server-side package entitlement after successful payment.')
                        : technology && salesMotion=='CONTACT_SALES'
                          ? 'Contact BridgePoint to scope this enterprise deployment. Pricing shown is a starting point; activation happens only after the delivery scope is agreed.'
                          : 'Checkout is not available for this package yet.',"""
if old_detail not in body:
    raise SystemExit('Package detail availability copy anchor missing')
body=body.replace(old_detail,new_detail,1)

body+='\n// bridgepoint-v324-contact-sales-package-ui\n'
path.write_text(body,encoding='utf-8')
print('Aligned technology package UI with contact-sales policy.')
